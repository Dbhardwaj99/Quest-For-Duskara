import RealityKit
import AppKit

@MainActor
final class World3DRenderer {
    let arView: ARView

    let anchor = AnchorEntity(world: .zero)
    let boardRoot = Entity()
    let staticRoot = Entity()
    let tileRoot = Entity()
    let overlayRoot = Entity()
    let soldierRoot = Entity()
    var soldierSignature = ""

    var selectedCoordinate: GridCoordinate?
    var gridSize = GridSize(columns: 5, rows: 5)
    var tileEntities: [GridCoordinate: Entity] = [:]
    var tileSnapshots: [GridCoordinate: World3DTileSnapshot] = [:]
    var scaffoldSignature = ""
    var visualQuality = World3DVisualQuality.adaptive
    var lastQualityCheckTime = Date.distantPast
    var pendingQuality: World3DVisualQuality?
    var lastDiagnosticsReportTime = Date.distantPast
    var lastPlacementStates: [GridCoordinate: TilePlacementState] = [:]

    var ocean: World3DOcean?
    var boatCruisers: [BoatCruiser] = []
    var boatTimer: Timer?
    var boatWaterY: Float = -0.16
    var boatBaseRadius = SIMD2<Float>(2.2, 2.2)
    var pierDockPoint: SIMD3<Float>?

    let tileSize: Float = 0.46
    let tileGap: Float = 0.020
    let tileHeight: Float = 0.085
    let sun = DirectionalLight()
    let fillLight = DirectionalLight()
    // NSColor.white is grayscale-space; blend() needs RGB components.
    static let rgbWhite = NSColor(red: 1, green: 1, blue: 1, alpha: 1)

    var palette: WorldPalette { WorldTheme.current.palette }

    var cameraParent: Entity {
        anchor
    }

    init(arView: ARView) {
        self.arView = arView
        World3DRenderResources.configureVisualQuality(visualQuality)
        World3DDiagnostics.rendererDidInit()
        configureView()
        boardRoot.addChild(staticRoot)
        boardRoot.addChild(tileRoot)
        boardRoot.addChild(overlayRoot)
        boardRoot.addChild(soldierRoot)
        anchor.addChild(boardRoot)
        arView.scene.anchors.append(anchor)
    }

    deinit {
        boatTimer?.invalidate()
        Task { @MainActor in
            World3DDiagnostics.rendererDidDeinit()
        }
    }

    func render(adapter: World3DStateAdapter) {
        updateVisualQuality()
        let nextGridSize = adapter.gridSize
        let nextSignature = signature(townID: adapter.town.id, gridSize: nextGridSize, layout: adapter.town.biomeLayout)
        if nextSignature != scaffoldSignature {
            gridSize = nextGridSize
            rebuildScaffold(gridSize: nextGridSize)
            clearTiles()
            scaffoldSignature = nextSignature
        }

        let snapshots = adapter.allTileSnapshots()
        let coordinates = Set(snapshots.map(\.coordinate))
        for staleCoordinate in Set(tileEntities.keys).subtracting(coordinates) {
            tileEntities[staleCoordinate]?.removeFromParent()
            tileEntities[staleCoordinate] = nil
            tileSnapshots[staleCoordinate] = nil
        }

        for snapshot in snapshots where tileSnapshots[snapshot.coordinate] != snapshot {
            // Placement feedback lives in overlayRoot (reconciled below), so a
            // placement-state-only change never rebuilds the tile.
            if let previous = tileSnapshots[snapshot.coordinate],
               tileEntities[snapshot.coordinate] != nil,
               previous.content == snapshot.content {
                tileSnapshots[snapshot.coordinate] = snapshot
                continue
            }

            let previousContent = tileSnapshots[snapshot.coordinate]?.content
            tileEntities[snapshot.coordinate]?.removeFromParent()
            World3DDiagnostics.tileDidRebuild()
            let entity = World3DTileEntity.makeTile(
                snapshot: snapshot,
                tileSize: tileSize,
                tileHeight: tileHeight,
                material: material(for: snapshot.content, coordinate: snapshot.coordinate),
                gridSize: gridSize
            )
            entity.position = position(for: snapshot.coordinate)
            entity.position.y += tileElevation(for: snapshot.coordinate)
            tileRoot.addChild(entity)
            tileEntities[snapshot.coordinate] = entity
            tileSnapshots[snapshot.coordinate] = snapshot

            // Any real content change touches the living ocean: an expanding
            // ripple rolls out from the island, and new buildings settle into
            // place like pieces set down by hand. First render of a town has
            // no previous content, so loading stays still.
            if let previousContent, previousContent != snapshot.content {
                ocean?.ripple(at: SIMD2<Float>(entity.position.x, entity.position.z))
                if case .building = snapshot.content {
                    playSettleAnimation(on: entity)
                }
            }
        }

        updatePierDockPoint(town: adapter.town)
        updateSoldierPieces(town: adapter.town, snapshots: snapshots)
        updatePlacementOverlays(snapshots)
        select(adapter.viewModel.selectedCoordinate)
        reportDiagnosticsIfNeeded()
    }

    // Reconciled against the last known states: a no-op when nothing changed,
    // rebuilt from scratch when anything did — so stale overlays can never
    // outlive placement mode, and idle renders allocate nothing.
    func updatePlacementOverlays(_ snapshots: [World3DTileSnapshot]) {
        var states: [GridCoordinate: TilePlacementState] = [:]
        for snapshot in snapshots where snapshot.placementState != .normal {
            states[snapshot.coordinate] = snapshot.placementState
        }
        guard states != lastPlacementStates else { return }
        lastPlacementStates = states

        overlayRoot.children
            .filter { $0.name == "world3d_placement" }
            .forEach { $0.removeFromParent() }

        for snapshot in snapshots where snapshot.placementState != .normal {
            let valid = snapshot.placementState == .valid
            let outline = makeTileOutline(
                color: valid
                    ? NSColor(red: 0.48, green: 0.86, blue: 0.46, alpha: 0.88)
                    : NSColor(red: 0.90, green: 0.36, blue: 0.30, alpha: 0.42),
                thickness: 0.05
            )
            outline.name = "world3d_placement"
            outline.position = position(for: snapshot.coordinate) + SIMD3<Float>(0, 0.046 + tileElevation(for: snapshot.coordinate), 0)
            overlayRoot.addChild(outline)

            if valid {
                // Barely-there glow so valid plots read at a glance without
                // hiding the tile.
                let glow = World3DRenderResources.makeBox(
                    size: SIMD3<Float>(tileSize * 0.86, 0.006, tileSize * 0.86),
                    material: matte(NSColor(red: 0.55, green: 0.88, blue: 0.50, alpha: 0.12), roughness: 0.5),
                    cornerRadius: tileSize * 0.04
                )
                glow.name = "world3d_placement"
                glow.position = outline.position
                overlayRoot.addChild(glow)
            }
        }
    }

    // Thin frame of four low bars hugging the tile's edges; the tile and
    // anything on it stay fully visible.
    func makeTileOutline(color: NSColor, thickness: Float) -> Entity {
        let group = Entity()
        let material = matte(color, roughness: 0.5)
        let length = tileSize * 0.98
        let barThickness = tileSize * thickness
        let barHeight: Float = 0.012
        let inset = (length - barThickness) / 2
        let bars: [(SIMD3<Float>, SIMD3<Float>)] = [
            (SIMD3<Float>(length, barHeight, barThickness), SIMD3<Float>(0, 0, -inset)),
            (SIMD3<Float>(length, barHeight, barThickness), SIMD3<Float>(0, 0, inset)),
            (SIMD3<Float>(barThickness, barHeight, length), SIMD3<Float>(-inset, 0, 0)),
            (SIMD3<Float>(barThickness, barHeight, length), SIMD3<Float>(inset, 0, 0))
        ]
        for (size, barPosition) in bars {
            let bar = World3DRenderResources.makeBox(size: size, material: material, cornerRadius: barThickness * 0.3)
            bar.position = barPosition
            group.addChild(bar)
        }
        return group
    }

    func coordinate(for entity: Entity?) -> GridCoordinate? {
        World3DTileEntity.coordinate(from: entity)
    }

    func cameraBounds(for gridSize: GridSize) -> World3DCameraBounds {
        World3DCameraBounds(
            halfWidth: terrainWidth(for: gridSize) / 2,
            halfDepth: terrainDepth(for: gridSize) / 2,
            focusInset: tileSize * 1.45
        )
    }

    func select(_ coordinate: GridCoordinate?) {
        guard selectedCoordinate != coordinate else { return }
        selectedCoordinate = coordinate
        removeSelection()
        if let coordinate, gridSize.contains(coordinate) {
            showSelection(at: coordinate)
        }
    }

}
