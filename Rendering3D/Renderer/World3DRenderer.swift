import RealityKit
import AppKit

@MainActor
final class World3DRenderer {
    let arView: ARView

    private let anchor = AnchorEntity(world: .zero)
    private let boardRoot = Entity()
    private let staticRoot = Entity()
    private let tileRoot = Entity()
    private let overlayRoot = Entity()

    private var selectedCoordinate: GridCoordinate?
    private var gridSize = GridSize(columns: 5, rows: 5)
    private var tileEntities: [GridCoordinate: Entity] = [:]
    private var tileSnapshots: [GridCoordinate: World3DTileSnapshot] = [:]
    private var scaffoldSignature = ""
    private var visualQuality = World3DVisualQuality.adaptive
    private var lastDiagnosticsReportTime = Date.distantPast

    private let tileSize: Float = 0.46
    private let tileGap: Float = 0.020
    private let tileHeight: Float = 0.060
    private let sun = DirectionalLight()
    // NSColor.white is grayscale-space; blend() needs RGB components.
    static let rgbWhite = NSColor(red: 1, green: 1, blue: 1, alpha: 1)

    private var palette: WorldPalette { WorldTheme.current.palette }

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
        anchor.addChild(boardRoot)
        arView.scene.anchors.append(anchor)
    }

    deinit {
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
            if let existing = tileEntities[snapshot.coordinate],
               let previous = tileSnapshots[snapshot.coordinate],
               previous.content == snapshot.content {
                World3DTileEntity.updatePlacementOverlay(snapshot.placementState, on: existing, tileSize: tileSize)
                tileSnapshots[snapshot.coordinate] = snapshot
                continue
            }

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
        }

        select(adapter.viewModel.selectedCoordinate)
        reportDiagnosticsIfNeeded()
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

    private func configureView() {
        sun.light.intensity = 5000
        sun.orientation = simd_quatf(angle: -.pi / 4.8, axis: SIMD3<Float>(1, 0, 0)) * simd_quatf(angle: .pi / 5.8, axis: SIMD3<Float>(0, 1, 0))
        anchor.addChild(sun)
        applyEnvironment()
    }

    private func applyEnvironment() {
        arView.environment.background = .color(palette.sky)
        sun.light.color = palette.sun
    }

    private func rebuildScaffold(gridSize: GridSize) {
        applyEnvironment()
        staticRoot.children.forEach { $0.removeFromParent() }
        addDuskBackdrop(for: gridSize)
        addGroundPlate(for: gridSize)
    }

    private func clearTiles() {
        tileRoot.children.forEach { $0.removeFromParent() }
        tileEntities.removeAll()
        tileSnapshots.removeAll()
    }

    private func addGroundPlate(for gridSize: GridSize) {
        let boardWidth = terrainWidth(for: gridSize)
        let boardDepth = terrainDepth(for: gridSize)

        let earth = World3DRenderResources.makeBox(
            size: SIMD3<Float>(boardWidth + 0.14, 0.32, boardDepth + 0.14),
            material: matte(palette.earth, roughness: 0.96),
            cornerRadius: 0.18
        )
        earth.position.y = -0.25
        staticRoot.addChild(earth)

        addTerrainSkirt(width: boardWidth, depth: boardDepth)
    }

    private func addTerrainSkirt(width: Float, depth: Float) {
        let sideMaterial = matte(palette.skirt, roughness: 0.98)
        let frontBackSize = SIMD3<Float>(width + 0.10, 0.24, 0.11)
        let sideSize = SIMD3<Float>(0.11, 0.24, depth + 0.10)

        let topZ = depth / 2 + 0.035
        let sideX = width / 2 + 0.035
        let y: Float = -0.205

        let front = World3DRenderResources.makeBox(size: frontBackSize, material: sideMaterial, cornerRadius: 0.035)
        front.position = SIMD3<Float>(0, y, topZ)
        staticRoot.addChild(front)

        let back = World3DRenderResources.makeBox(size: frontBackSize, material: sideMaterial, cornerRadius: 0.035)
        back.position = SIMD3<Float>(0, y, -topZ)
        staticRoot.addChild(back)

        let left = World3DRenderResources.makeBox(size: sideSize, material: sideMaterial, cornerRadius: 0.035)
        left.position = SIMD3<Float>(-sideX, y, 0)
        staticRoot.addChild(left)

        let right = World3DRenderResources.makeBox(size: sideSize, material: sideMaterial, cornerRadius: 0.035)
        right.position = SIMD3<Float>(sideX, y, 0)
        staticRoot.addChild(right)
    }

    private func addDuskBackdrop(for gridSize: GridSize) {
        let boardWidth = terrainWidth(for: gridSize)
        let boardDepth = terrainDepth(for: gridSize)
        let horizonWidth = boardWidth + tileSize * 4.4
        let horizonY = tileSize * 0.74
        let distance = tileSize * 5.5

        addOpenSea(boardWidth: boardWidth, boardDepth: boardDepth)
        addCloudCluster(center: SIMD3<Float>(-horizonWidth * 0.25, horizonY + tileSize * 0.55, -distance + 0.12), scale: 0.90)
        addCloudCluster(center: SIMD3<Float>(horizonWidth * 0.22, horizonY + tileSize * 0.78, -distance + 0.10), scale: 0.72)
        addCloudCluster(center: SIMD3<Float>(horizonWidth * 0.04, horizonY + tileSize * 0.36, -distance + 0.14), scale: 0.58)
    }

    private func addOpenSea(boardWidth: Float, boardDepth: Float) {
        // Sized independently of the board so the sea has no visible edge at
        // any yaw/zoom; the visible ground region stays inside the camera far
        // plane (28) even at max zoom-out on ultra-wide windows.
        let seaSpan = tileSize * 100
        let waterHeight: Float = 0.018
        // Surface at -0.16 keeps the earth plate/skirt band (top ~-0.085)
        // visibly above the waterline so the island reads as rising from it.
        let waterY: Float = -0.169

        let sea = World3DRenderResources.makeBox(
            size: SIMD3<Float>(seaSpan, waterHeight, seaSpan),
            material: matte(palette.waterOpen, roughness: 0.32)
        )
        sea.position.y = waterY
        staticRoot.addChild(sea)

        let islandShadow = World3DRenderResources.makeBox(
            size: SIMD3<Float>(boardWidth + tileSize * 1.5, 0.008, boardDepth + tileSize * 1.5),
            material: matte(palette.waterShadow, roughness: 0.36),
            cornerRadius: 0.42
        )
        islandShadow.position.y = waterY + waterHeight / 2 + 0.003
        staticRoot.addChild(islandShadow)

        addWaterSheen(
            width: boardWidth + tileSize * 4.5,
            depth: boardDepth + tileSize * 4.5,
            y: islandShadow.position.y + 0.006
        )
    }

    private func addWaterSheen(width: Float, depth: Float, y: Float) {
        let sheenMaterial = matte(palette.waterSheen, roughness: 0.26)
        let positions: [SIMD3<Float>] = [
            SIMD3<Float>(-width * 0.26, y, -depth * 0.40),
            SIMD3<Float>(width * 0.24, y, -depth * 0.33),
            SIMD3<Float>(-width * 0.34, y, depth * 0.36),
            SIMD3<Float>(width * 0.30, y, depth * 0.28)
        ]

        for (index, position) in positions.enumerated() {
            let sheen = World3DRenderResources.makeBox(
                size: SIMD3<Float>(tileSize * (0.48 + Float(index % 2) * 0.18), 0.006, tileSize * 0.035),
                material: sheenMaterial,
                cornerRadius: tileSize * 0.008
            )
            sheen.position = position
            sheen.orientation = simd_quatf(angle: 0.12 + Float(index) * 0.21, axis: SIMD3<Float>(0, 1, 0))
            staticRoot.addChild(sheen)
        }
    }

    private func addCloudCluster(center: SIMD3<Float>, scale: Float) {
        let cloudMaterial = matte(palette.cloud, roughness: 1.0)
        let shadowMaterial = matte(palette.cloudShadow, roughness: 1.0)
        let puffs: [(SIMD3<Float>, Float, SIMD3<Float>, SimpleMaterial)] = [
            (SIMD3<Float>(-0.20, -0.02, 0), 0.18, SIMD3<Float>(1.7, 0.46, 0.24), shadowMaterial),
            (SIMD3<Float>(-0.05, 0.03, 0), 0.22, SIMD3<Float>(1.9, 0.52, 0.24), cloudMaterial),
            (SIMD3<Float>(0.17, 0.00, 0), 0.16, SIMD3<Float>(1.6, 0.42, 0.22), cloudMaterial)
        ]

        for puff in puffs {
            let cloud = World3DRenderResources.makeSphere(
                radius: tileSize * puff.1 * scale,
                material: puff.3,
                scale: puff.2
            )
            cloud.position = center + puff.0 * (tileSize * scale)
            staticRoot.addChild(cloud)
        }
    }

    private func showSelection(at coordinate: GridCoordinate) {
        let glow = World3DRenderResources.makeBox(
            size: SIMD3<Float>(tileSize * 0.96, 0.022, tileSize * 0.96),
            material: matte(NSColor(red: 1.0, green: 0.76, blue: 0.28, alpha: 0.52), roughness: 0.34),
            cornerRadius: tileSize * 0.055
        )
        glow.name = "world3d_selection"
        glow.position = position(for: coordinate) + SIMD3<Float>(0, 0.084 + tileElevation(for: coordinate), 0)
        overlayRoot.addChild(glow)

        let inner = World3DRenderResources.makeBox(
            size: SIMD3<Float>(tileSize * 0.58, 0.012, tileSize * 0.58),
            material: matte(NSColor(red: 1.0, green: 0.88, blue: 0.46, alpha: 0.36), roughness: 0.30),
            cornerRadius: tileSize * 0.04
        )
        inner.name = "world3d_selection"
        inner.position = position(for: coordinate) + SIMD3<Float>(0, 0.102 + tileElevation(for: coordinate), 0)
        overlayRoot.addChild(inner)
    }

    private func removeSelection() {
        overlayRoot.children
            .filter { $0.name == "world3d_selection" }
            .forEach { $0.removeFromParent() }
    }

    private func position(for coordinate: GridCoordinate) -> SIMD3<Float> {
        let spacing = tileSize + tileGap
        let centeredX = Float(coordinate.x) - Float(gridSize.columns - 1) / 2
        let centeredZ = Float(coordinate.y) - Float(gridSize.rows - 1) / 2
        return SIMD3<Float>(centeredX * spacing, 0, centeredZ * spacing)
    }

    private func material(for content: World3DTileSnapshot.Content, coordinate: GridCoordinate) -> SimpleMaterial {
        switch content {
        case .water:
            let ripple = CGFloat(stablePercent(coordinate, salt: 88)) / 700
            return matte(blend(palette.tileWater, with: World3DRenderer.rgbWhite, amount: ripple), roughness: 0.30)
        default:
            let variant = CGFloat(stablePercent(coordinate, salt: 211)) / 700
            return matte(blend(palette.tileGround, with: World3DRenderer.rgbWhite, amount: variant), roughness: 0.91)
        }
    }

    private func blend(_ color: NSColor, with tint: NSColor, amount: CGFloat) -> NSColor {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        var tintRed: CGFloat = 0
        var tintGreen: CGFloat = 0
        var tintBlue: CGFloat = 0
        var tintAlpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        tint.getRed(&tintRed, green: &tintGreen, blue: &tintBlue, alpha: &tintAlpha)
        let clampedAmount = min(1, max(0, amount))
        return NSColor(
            red: red + (tintRed - red) * clampedAmount,
            green: green + (tintGreen - green) * clampedAmount,
            blue: blue + (tintBlue - blue) * clampedAmount,
            alpha: alpha
        )
    }

    private func matte(_ color: NSColor, roughness: Float, metallic: Bool = false) -> SimpleMaterial {
        World3DRenderResources.material(color, roughness: roughness, metallic: metallic)
    }

    private func tileElevation(for coordinate: GridCoordinate) -> Float {
        Float(stablePercent(coordinate, salt: 509)) / 100 * 0.018
    }

    private func terrainWidth(for gridSize: GridSize) -> Float {
        Float(gridSize.columns) * tileSize + Float(gridSize.columns - 1) * tileGap
    }

    private func terrainDepth(for gridSize: GridSize) -> Float {
        Float(gridSize.rows) * tileSize + Float(gridSize.rows - 1) * tileGap
    }

    private func updateVisualQuality() {
        let nextQuality = World3DVisualQuality.adaptive
        guard nextQuality != visualQuality else { return }
        visualQuality = nextQuality
        World3DRenderResources.configureVisualQuality(nextQuality)
        scaffoldSignature = ""
        debugPrint("World3D quality changed:", nextQuality.rawValue)
    }

    private func reportDiagnosticsIfNeeded() {
        let now = Date()
        guard now.timeIntervalSince(lastDiagnosticsReportTime) > 4 else { return }
        lastDiagnosticsReportTime = now
        World3DDiagnostics.report(entityRoot: boardRoot, terrainRoot: staticRoot, quality: visualQuality)
    }

    private func stablePercent(_ coordinate: GridCoordinate, salt: Int) -> Int {
        let raw = coordinate.x * 73_856_093 ^ coordinate.y * 19_349_663 ^ salt * 83_492_791
        return abs(raw % 100)
    }

    private func signature(townID: UUID, gridSize: GridSize, layout: TownBiomeLayout) -> String {
        let sides = BiomeSide.allCases
            .map { side in "\(side.rawValue):\(layout.biome(on: side)?.rawValue ?? "none")" }
            .joined(separator: "|")
        return "\(townID.uuidString)|\(gridSize.columns)x\(gridSize.rows)|\(sides)|\(WorldTheme.current.rawValue)"
    }
}
