import RealityKit
import UIKit

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
    private let terrainRingDepth = 1
    private let duskDepthTint = UIColor(red: 0.23, green: 0.28, blue: 0.36, alpha: 1)

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
        let nextSignature = signature(gridSize: nextGridSize, layout: adapter.town.biomeLayout)
        if nextSignature != scaffoldSignature {
            gridSize = nextGridSize
            rebuildScaffold(layout: adapter.town.biomeLayout, gridSize: nextGridSize)
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
                material: material(for: snapshot.content, coordinate: snapshot.coordinate)
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
        arView.cameraMode = .nonAR
        arView.automaticallyConfigureSession = false
        arView.environment.background = .color(UIColor(red: 0.18, green: 0.22, blue: 0.27, alpha: 1))
        arView.renderOptions.insert(.disableDepthOfField)
        arView.renderOptions.insert(.disableMotionBlur)

        let sun = DirectionalLight()
        sun.light.intensity = 5000
        sun.light.color = UIColor(red: 1.0, green: 0.78, blue: 0.50, alpha: 1)
        sun.orientation = simd_quatf(angle: -.pi / 4.8, axis: SIMD3<Float>(1, 0, 0)) * simd_quatf(angle: .pi / 5.8, axis: SIMD3<Float>(0, 1, 0))
        anchor.addChild(sun)
    }

    private func rebuildScaffold(layout: TownBiomeLayout, gridSize: GridSize) {
        staticRoot.children.forEach { $0.removeFromParent() }
        addDuskBackdrop(for: gridSize)
        addGroundPlate(for: gridSize)
        addTerrainRing(layout: layout, gridSize: gridSize)
        addBiomeBackdrop(layout: layout, gridSize: gridSize)
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
            material: matte(UIColor(red: 0.20, green: 0.23, blue: 0.19, alpha: 1), roughness: 0.96),
            cornerRadius: 0.18
        )
        earth.position.y = -0.25
        staticRoot.addChild(earth)

        addTerrainSkirt(width: boardWidth, depth: boardDepth)
    }

    private func addTerrainSkirt(width: Float, depth: Float) {
        let sideMaterial = matte(UIColor(red: 0.13, green: 0.13, blue: 0.12, alpha: 1), roughness: 0.98)
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
        let horizonDepth = boardDepth + tileSize * 4.4
        let horizonHeight = tileSize * 1.25
        let horizonY = tileSize * 0.22
        let distance = max(boardWidth, boardDepth) * 0.58 + tileSize * 1.35

        let skyBand = matte(UIColor(red: 0.24, green: 0.30, blue: 0.38, alpha: 1), roughness: 1.0)
        let violetBand = matte(UIColor(red: 0.23, green: 0.25, blue: 0.36, alpha: 1), roughness: 1.0)
        let warmHorizon = matte(UIColor(red: 0.39, green: 0.32, blue: 0.24, alpha: 1), roughness: 1.0)
        let groundHaze = matte(UIColor(red: 0.17, green: 0.22, blue: 0.22, alpha: 1), roughness: 1.0)

        let back = World3DRenderResources.makeBox(size: SIMD3<Float>(horizonWidth, horizonHeight, 0.06), material: skyBand, cornerRadius: 0.04)
        back.position = SIMD3<Float>(0, horizonY, -distance)
        staticRoot.addChild(back)

        let backGlow = World3DRenderResources.makeBox(size: SIMD3<Float>(horizonWidth * 0.72, tileSize * 0.38, 0.065), material: warmHorizon, cornerRadius: 0.05)
        backGlow.position = SIMD3<Float>(0, tileSize * 0.05, -distance + 0.035)
        staticRoot.addChild(backGlow)

        let frontDepth = World3DRenderResources.makeBox(size: SIMD3<Float>(horizonWidth, tileSize * 0.72, 0.055), material: groundHaze, cornerRadius: 0.04)
        frontDepth.position = SIMD3<Float>(0, -tileSize * 0.05, distance)
        staticRoot.addChild(frontDepth)

        let left = World3DRenderResources.makeBox(size: SIMD3<Float>(0.06, horizonHeight * 0.86, horizonDepth), material: violetBand, cornerRadius: 0.04)
        left.position = SIMD3<Float>(-distance, horizonY * 0.9, 0)
        staticRoot.addChild(left)

        let right = World3DRenderResources.makeBox(size: SIMD3<Float>(0.06, horizonHeight * 0.86, horizonDepth), material: skyBand, cornerRadius: 0.04)
        right.position = SIMD3<Float>(distance, horizonY * 0.9, 0)
        staticRoot.addChild(right)

        let tableShadow = World3DRenderResources.makeBox(
            size: SIMD3<Float>(boardWidth + tileSize * 1.6, 0.035, boardDepth + tileSize * 1.6),
            material: matte(UIColor(red: 0.10, green: 0.13, blue: 0.14, alpha: 1), roughness: 1.0),
            cornerRadius: 0.42
        )
        tableShadow.position.y = -0.43
        staticRoot.addChild(tableShadow)
    }

    private func addTerrainRing(layout: TownBiomeLayout, gridSize: GridSize) {
        let rangeX = -terrainRingDepth..<(gridSize.columns + terrainRingDepth)
        let rangeY = -terrainRingDepth..<(gridSize.rows + terrainRingDepth)

        for y in rangeY {
            for x in rangeX {
                guard gridSize.contains(GridCoordinate(x: x, y: y)) == false else { continue }
                let coordinate = GridCoordinate(x: x, y: y)
                let biome = terrainBiome(at: coordinate, layout: layout, gridSize: gridSize)
                let root = Entity()
                root.name = "world3d_terrain_\(x)_\(y)"
                root.position = position(for: coordinate)
                root.position.y = terrainElevation(for: biome, coordinate: coordinate)

                let tileScale = terrainTileScale(coordinate)
                let tile = World3DRenderResources.makeBox(
                    size: SIMD3<Float>(tileSize * tileScale.x, tileHeight * tileScale.y, tileSize * tileScale.z),
                    material: terrainMaterial(for: biome, coordinate: coordinate),
                    cornerRadius: tileSize * 0.055
                )
                tile.position.y = -tileHeight * tileScale.y / 2
                root.addChild(tile)

                addTerrainTexture(for: biome, to: root, coordinate: coordinate)
                addTerrainDecoration(for: biome, to: root, coordinate: coordinate, gridSize: gridSize)
                staticRoot.addChild(root)
            }
        }
    }

    private func terrainBiome(at coordinate: GridCoordinate, layout: TownBiomeLayout, gridSize: GridSize) -> BiomeKind {
        let primarySide = primarySide(for: coordinate, gridSize: gridSize)
        return layout.biome(on: primarySide) ?? .plains
    }

    private func addTerrainTexture(for biome: BiomeKind, to root: Entity, coordinate: GridCoordinate) {
        let count = min(biome == .river ? 2 : 3, visualQuality.terrainTextureCount)
        for index in 0..<count {
            let tint: UIColor
            switch biome {
            case .forest:
                tint = stablePercent(coordinate, salt: 300 + index) < 50
                    ? atmosphericColor(UIColor(red: 0.10, green: 0.22, blue: 0.18, alpha: 1), coordinate: coordinate, strength: 0.18)
                    : atmosphericColor(UIColor(red: 0.24, green: 0.34, blue: 0.18, alpha: 1), coordinate: coordinate, strength: 0.12)
            case .mountain:
                tint = atmosphericColor(UIColor(red: 0.48, green: 0.46, blue: 0.40, alpha: 1), coordinate: coordinate, strength: 0.22)
            case .plains:
                tint = atmosphericColor(UIColor(red: 0.43, green: 0.49, blue: 0.28, alpha: 1), coordinate: coordinate, strength: 0.08)
            case .river:
                tint = atmosphericColor(UIColor(red: 0.34, green: 0.56, blue: 0.61, alpha: 0.56), coordinate: coordinate, strength: 0.10)
            }

            let fleck = World3DRenderResources.makeBox(
                size: SIMD3<Float>(tileSize * 0.18, 0.008, tileSize * 0.035),
                material: matte(tint, roughness: biome == .river ? 0.30 : 0.96),
                cornerRadius: tileSize * 0.006
            )
            fleck.position = SIMD3<Float>(
                jitter(coordinate, salt: 351 + index * 13) * tileSize * 0.28,
                0.012,
                jitter(coordinate, salt: 405 + index * 17) * tileSize * 0.28
            )
            fleck.orientation = simd_quatf(angle: jitter(coordinate, salt: 433 + index) * 1.5, axis: SIMD3<Float>(0, 1, 0))
            root.addChild(fleck)
        }
    }

    private func addTerrainDecoration(for biome: BiomeKind, to root: Entity, coordinate: GridCoordinate, gridSize: GridSize) {
        let edgeWeight = terrainEdgeWeight(for: coordinate, gridSize: gridSize)
        switch biome {
        case .forest:
            let baseCount = stablePercent(coordinate, salt: 7) < 72 ? 2 : 1
            let count = terrainDetailCount(baseCount)
            for index in 0..<count {
                let cluster = Entity()
                cluster.position = terrainDecorationOffset(coordinate, index: index)
                cluster.orientation = simd_quatf(angle: jitter(coordinate, salt: 600 + index) * 0.18, axis: SIMD3<Float>(0, 0, 1))
                World3DTileEntity.addDistantForestMass(
                    to: cluster,
                    tileSize: tileSize * (count == 1 ? 0.96 : 0.72),
                    coordinate: coordinate,
                    edgeWeight: edgeWeight
                )
                root.addChild(cluster)
            }
        case .mountain:
            let baseCount = stablePercent(coordinate, salt: 23) < 46 ? 2 : 1
            let count = terrainDetailCount(baseCount)
            for index in 0..<count {
                let cluster = Entity()
                cluster.position = terrainDecorationOffset(coordinate, index: index)
                World3DTileEntity.addDistantMountainMass(
                    to: cluster,
                    tileSize: tileSize * (count == 1 ? 1.16 : 0.84),
                    coordinate: coordinate,
                    edgeWeight: edgeWeight
                )
                root.addChild(cluster)
            }
        case .plains:
            if stablePercent(coordinate, salt: 19) < Int(20 * visualQuality.terrainDecorationMultiplier) {
                let cluster = Entity()
                cluster.position = terrainDecorationOffset(coordinate, index: 0)
                World3DTileEntity.addDistantForestMass(to: cluster, tileSize: tileSize * 0.48, coordinate: coordinate, edgeWeight: 0.28)
                root.addChild(cluster)
            }
        case .river:
            break
        }
    }

    private func primarySide(for coordinate: GridCoordinate, gridSize: GridSize) -> BiomeSide {
        if coordinate.y == -1 && coordinate.x >= 0 && coordinate.x < gridSize.columns { return .top }
        if coordinate.y == gridSize.rows && coordinate.x >= 0 && coordinate.x < gridSize.columns { return .bottom }
        if coordinate.x == -1 && coordinate.y >= 0 && coordinate.y < gridSize.rows { return .left }
        if coordinate.x == gridSize.columns && coordinate.y >= 0 && coordinate.y < gridSize.rows { return .right }

        let sides = sidesTouching(coordinate, gridSize: gridSize)
        let index = stablePercent(coordinate, salt: 3) % max(1, sides.count)
        return sides[index]
    }

    private func sidesTouching(_ coordinate: GridCoordinate, gridSize: GridSize) -> [BiomeSide] {
        var sides: [BiomeSide] = []
        if coordinate.y < 0 { sides.append(.top) }
        if coordinate.y >= gridSize.rows { sides.append(.bottom) }
        if coordinate.x < 0 { sides.append(.left) }
        if coordinate.x >= gridSize.columns { sides.append(.right) }
        return sides.isEmpty ? [.top] : sides
    }

    private func terrainDecorationOffset(_ coordinate: GridCoordinate, index: Int) -> SIMD3<Float> {
        let xJitter = jitter(coordinate, salt: 101 + index * 17) * tileSize * 0.22
        let zJitter = jitter(coordinate, salt: 149 + index * 13) * tileSize * 0.22
        let splitOffset = Float(index - 1) * tileSize * 0.12
        return SIMD3<Float>(xJitter + splitOffset, 0.02, zJitter - splitOffset * 0.55)
    }

    private func addBiomeBackdrop(layout: TownBiomeLayout, gridSize: GridSize) {
        for side in BiomeSide.allCases {
            let biome = layout.biome(on: side) ?? .plains
            let segments = backdropSegmentCount(for: side, gridSize: gridSize, biome: biome)
            for index in 0..<segments {
                let coordinate = backdropCoordinate(for: side, index: index, segments: segments, gridSize: gridSize)
                let edgeWeight = backdropEdgeWeight(for: side, coordinate: coordinate)
                let root = Entity()
                root.name = "world3d_backdrop_\(side.rawValue)_\(index)"
                root.position = position(for: coordinate)
                root.position.y = backdropElevation(for: biome, coordinate: coordinate)
                root.orientation = backdropOrientation(for: side, coordinate: coordinate)

                addBackdropBase(for: biome, to: root, coordinate: coordinate, side: side)
                switch biome {
                case .forest:
                    World3DTileEntity.addDistantForestMass(
                        to: root,
                        tileSize: tileSize * backdropScale(for: side, index: index, segments: segments) * (0.98 + edgeWeight * 0.12),
                        coordinate: coordinate,
                        edgeWeight: edgeWeight
                    )
                    addSecondaryBackdropMassIfNeeded(
                        biome: biome,
                        to: root,
                        side: side,
                        coordinate: coordinate,
                        index: index,
                        segments: segments,
                        edgeWeight: edgeWeight
                    )
                case .mountain:
                    World3DTileEntity.addDistantMountainMass(
                        to: root,
                        tileSize: tileSize * backdropScale(for: side, index: index, segments: segments) * (1.18 + edgeWeight * 0.18),
                        coordinate: coordinate,
                        edgeWeight: edgeWeight
                    )
                    addSecondaryBackdropMassIfNeeded(
                        biome: biome,
                        to: root,
                        side: side,
                        coordinate: coordinate,
                        index: index,
                        segments: segments,
                        edgeWeight: edgeWeight
                    )
                case .plains:
                    if stablePercent(coordinate, salt: 733) < 68 {
                        World3DTileEntity.addDistantForestMass(
                            to: root,
                            tileSize: tileSize * 0.56,
                            coordinate: coordinate,
                            edgeWeight: 0.34
                        )
                    }
                case .river:
                    addRiverBackdrop(to: root, coordinate: coordinate)
                }

                staticRoot.addChild(root)
            }
        }
    }

    private func addBackdropBase(for biome: BiomeKind, to root: Entity, coordinate: GridCoordinate, side: BiomeSide) {
        let scale = backdropScale(for: side, index: stablePercent(coordinate, salt: 739) % 4, segments: 4)
        let size = SIMD3<Float>(tileSize * 0.92 * scale, tileHeight * 0.68, tileSize * 0.62 * scale)
        let base = World3DRenderResources.makeBox(
            size: size,
            material: terrainMaterial(for: biome, coordinate: coordinate),
            cornerRadius: tileSize * 0.030
        )
        base.position.y = -tileHeight * 0.36
        root.addChild(base)
    }

    private func addRiverBackdrop(to root: Entity, coordinate: GridCoordinate) {
        let water = World3DRenderResources.makeBox(
            size: SIMD3<Float>(tileSize * 0.92, tileHeight * 0.22, tileSize * 0.30),
            material: terrainMaterial(for: .river, coordinate: coordinate),
            cornerRadius: tileSize * 0.020
        )
        water.position.y = 0.010
        water.orientation = simd_quatf(angle: jitter(coordinate, salt: 751) * 0.28, axis: SIMD3<Float>(0, 1, 0))
        root.addChild(water)
    }

    private func addSecondaryBackdropMassIfNeeded(
        biome: BiomeKind,
        to root: Entity,
        side: BiomeSide,
        coordinate: GridCoordinate,
        index: Int,
        segments: Int,
        edgeWeight: Float
    ) {
        let mountainDensityThreshold = side == .top ? 80 : 34
        if biome == .mountain {
            guard stablePercent(coordinate, salt: 761) < mountainDensityThreshold else { return }
        } else {
            guard side == .top || stablePercent(coordinate, salt: 761) < 42 else { return }
        }
        guard visualQuality != .low || side == .top else { return }

        let layer = Entity()
        let lateral = jitter(coordinate, salt: 763) * tileSize * 0.18
        layer.position = SIMD3<Float>(lateral, 0.018 + edgeWeight * 0.018, -tileSize * (0.18 + edgeWeight * 0.10))
        layer.orientation = simd_quatf(angle: jitter(coordinate, salt: 767) * 0.10, axis: SIMD3<Float>(0, 1, 0))

        let scale = backdropScale(for: side, index: index, segments: segments)
        switch biome {
        case .forest:
            World3DTileEntity.addDistantForestMass(
                to: layer,
                tileSize: tileSize * scale * 0.76,
                coordinate: GridCoordinate(x: coordinate.x + 11, y: coordinate.y - 7),
                edgeWeight: min(1.25, edgeWeight + 0.12)
            )
        case .mountain:
            World3DTileEntity.addDistantMountainMass(
                to: layer,
                tileSize: tileSize * scale * 0.88,
                coordinate: GridCoordinate(x: coordinate.x + 13, y: coordinate.y - 5),
                edgeWeight: min(1.25, edgeWeight + 0.18)
            )
        case .plains, .river:
            return
        }
        root.addChild(layer)
    }

    private func showSelection(at coordinate: GridCoordinate) {
        let glow = World3DRenderResources.makeBox(
            size: SIMD3<Float>(tileSize * 0.96, 0.022, tileSize * 0.96),
            material: matte(UIColor(red: 1.0, green: 0.76, blue: 0.28, alpha: 0.52), roughness: 0.34),
            cornerRadius: tileSize * 0.055
        )
        glow.name = "world3d_selection"
        glow.position = position(for: coordinate) + SIMD3<Float>(0, 0.084 + tileElevation(for: coordinate), 0)
        overlayRoot.addChild(glow)

        let inner = World3DRenderResources.makeBox(
            size: SIMD3<Float>(tileSize * 0.58, 0.012, tileSize * 0.58),
            material: matte(UIColor(red: 1.0, green: 0.88, blue: 0.46, alpha: 0.36), roughness: 0.30),
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
            let ripple = CGFloat(stablePercent(coordinate, salt: 88)) / 900
            return matte(UIColor(red: 0.10 + ripple, green: 0.31 + ripple, blue: 0.40 + ripple, alpha: 1), roughness: 0.30)
        default:
            let variant = CGFloat(stablePercent(coordinate, salt: 211)) / 900
            let warm = CGFloat(stablePercent(coordinate, salt: 67)) / 1400
            return matte(UIColor(red: 0.29 + warm, green: 0.40 + variant, blue: 0.24 + warm, alpha: 1), roughness: 0.91)
        }
    }

    private func terrainMaterial(for biome: BiomeKind, coordinate: GridCoordinate) -> SimpleMaterial {
        let variant = CGFloat(stablePercent(coordinate, salt: 211)) / 1100
        let coolVariant = CGFloat(stablePercent(coordinate, salt: 619)) / 1500
        switch biome {
        case .forest:
            let base = UIColor(red: 0.10 + coolVariant, green: 0.24 + variant, blue: 0.17 + coolVariant, alpha: 1)
            return matte(atmosphericColor(base, coordinate: coordinate, strength: 0.20), roughness: 0.93)
        case .mountain:
            let base = UIColor(red: 0.38 + variant, green: 0.39 + variant, blue: 0.38 + coolVariant, alpha: 1)
            return matte(atmosphericColor(base, coordinate: coordinate, strength: 0.28), roughness: 0.97)
        case .plains:
            let base = UIColor(red: 0.35 + variant, green: 0.44 + variant, blue: 0.25, alpha: 1)
            return matte(atmosphericColor(base, coordinate: coordinate, strength: 0.10), roughness: 0.92)
        case .river:
            let base = UIColor(red: 0.09, green: 0.31 + variant, blue: 0.40 + variant, alpha: 1)
            return matte(atmosphericColor(base, coordinate: coordinate, strength: 0.12), roughness: 0.30)
        }
    }

    private func atmosphericColor(_ color: UIColor, coordinate: GridCoordinate, strength: CGFloat) -> UIColor {
        let distance = max(abs(coordinate.x - (gridSize.columns - 1) / 2), abs(coordinate.y - (gridSize.rows - 1) / 2))
        let depth = min(1, CGFloat(max(0, distance - max(gridSize.columns, gridSize.rows) / 2)) / 2)
        return blend(color, with: duskDepthTint, amount: depth * strength)
    }

    private func blend(_ color: UIColor, with tint: UIColor, amount: CGFloat) -> UIColor {
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
        return UIColor(
            red: red + (tintRed - red) * clampedAmount,
            green: green + (tintGreen - green) * clampedAmount,
            blue: blue + (tintBlue - blue) * clampedAmount,
            alpha: alpha
        )
    }

    private func matte(_ color: UIColor, roughness: Float, metallic: Bool = false) -> SimpleMaterial {
        World3DRenderResources.material(color, roughness: roughness, metallic: metallic)
    }

    private func terrainElevation(for biome: BiomeKind, coordinate: GridCoordinate) -> Float {
        let base = tileElevation(for: coordinate)
        switch biome {
        case .mountain:
            return base + 0.030
        case .forest:
            return base + 0.012
        case .plains, .river:
            return base
        }
    }

    private func tileElevation(for coordinate: GridCoordinate) -> Float {
        Float(stablePercent(coordinate, salt: 509)) / 100 * 0.018
    }

    private func terrainTileScale(_ coordinate: GridCoordinate) -> SIMD3<Float> {
        SIMD3<Float>(
            0.98 + Float(stablePercent(coordinate, salt: 30)) / 100 * 0.16,
            0.92 + Float(stablePercent(coordinate, salt: 31)) / 100 * 0.42,
            0.98 + Float(stablePercent(coordinate, salt: 32)) / 100 * 0.16
        )
    }

    private func terrainWidth(for gridSize: GridSize) -> Float {
        let tileCount = gridSize.columns + terrainRingDepth * 2 + 2
        return Float(tileCount) * tileSize + Float(tileCount - 1) * tileGap
    }

    private func terrainDepth(for gridSize: GridSize) -> Float {
        let tileCount = gridSize.rows + terrainRingDepth * 2 + 2
        return Float(tileCount) * tileSize + Float(tileCount - 1) * tileGap
    }

    private func updateVisualQuality() {
        let nextQuality = World3DVisualQuality.adaptive
        guard nextQuality != visualQuality else { return }
        visualQuality = nextQuality
        World3DRenderResources.configureVisualQuality(nextQuality)
        scaffoldSignature = ""
        debugPrint("World3D quality changed:", nextQuality.rawValue)
    }

    private func terrainDetailCount(_ count: Int) -> Int {
        max(1, Int((Float(count) * visualQuality.terrainDecorationMultiplier).rounded()))
    }

    private func reportDiagnosticsIfNeeded() {
        let now = Date()
        guard now.timeIntervalSince(lastDiagnosticsReportTime) > 4 else { return }
        lastDiagnosticsReportTime = now
        World3DDiagnostics.report(entityRoot: boardRoot, terrainRoot: staticRoot, quality: visualQuality)
    }

    private func terrainEdgeWeight(for coordinate: GridCoordinate, gridSize: GridSize) -> Float {
        let sideCount = Float(sidesTouching(coordinate, gridSize: gridSize).count)
        let cornerBonus: Float = sideCount > 1 ? 0.22 : 0
        let rhythm = Float(stablePercent(coordinate, salt: 727)) / 100 * 0.18
        let backEdgeBonus: Float = coordinate.y < 0 ? 0.16 : 0
        return min(1.2, 0.72 + cornerBonus + rhythm + backEdgeBonus)
    }

    private func backdropSegmentCount(for side: BiomeSide, gridSize: GridSize, biome: BiomeKind) -> Int {
        let length = side == .top || side == .bottom ? gridSize.columns : gridSize.rows
        let backEdgeBonus = side == .top ? 2 : 0
        let count: Int
        switch visualQuality {
        case .low:
            count = min(length + backEdgeBonus, 4)
        case .medium:
            count = min(length + backEdgeBonus, 6)
        case .high:
            count = length + backEdgeBonus
        }
        guard biome == .mountain else { return count }
        return max(1, Int((Float(count) * 0.8).rounded()))
    }

    private func backdropCoordinate(for side: BiomeSide, index: Int, segments: Int, gridSize: GridSize) -> GridCoordinate {
        let length = side == .top || side == .bottom ? gridSize.columns : gridSize.rows
        let sourceIndex: Int
        if segments <= 1 {
            sourceIndex = length / 2
        } else {
            sourceIndex = Int((Float(index) / Float(segments - 1) * Float(length + 1)).rounded()) - 1
        }

        switch side {
        case .top:
            return GridCoordinate(x: sourceIndex, y: -2)
        case .bottom:
            return GridCoordinate(x: sourceIndex, y: gridSize.rows + 1)
        case .left:
            return GridCoordinate(x: -2, y: sourceIndex)
        case .right:
            return GridCoordinate(x: gridSize.columns + 1, y: sourceIndex)
        }
    }

    private func backdropOrientation(for side: BiomeSide, coordinate: GridCoordinate) -> simd_quatf {
        let jitterAngle = jitter(coordinate, salt: 743) * 0.12
        let baseAngle: Float
        switch side {
        case .top:
            baseAngle = 0
        case .bottom:
            baseAngle = .pi
        case .left:
            baseAngle = -.pi / 2
        case .right:
            baseAngle = .pi / 2
        }
        return simd_quatf(angle: baseAngle + jitterAngle, axis: SIMD3<Float>(0, 1, 0))
    }

    private func backdropScale(for side: BiomeSide, index: Int, segments: Int) -> Float {
        let edgeBias: Float
        if segments <= 1 {
            edgeBias = 1
        } else {
            let t = Float(index) / Float(segments - 1)
            edgeBias = 1 - abs(t - 0.5) * 0.22
        }

        let sideBias: Float = side == .top ? 1.18 : (side == .left ? 1.04 : 0.98)
        return edgeBias * sideBias
    }

    private func backdropEdgeWeight(for side: BiomeSide, coordinate: GridCoordinate) -> Float {
        let sideWeight: Float = side == .top ? 1.18 : 0.98
        let rhythm = Float(stablePercent(coordinate, salt: 771)) / 100 * 0.18
        return min(1.25, sideWeight + rhythm)
    }

    private func backdropElevation(for biome: BiomeKind, coordinate: GridCoordinate) -> Float {
        switch biome {
        case .forest:
            return 0.016 + Float(stablePercent(coordinate, salt: 747)) / 100 * 0.012
        case .mountain:
            return 0.040 + Float(stablePercent(coordinate, salt: 748)) / 100 * 0.018
        case .plains:
            return 0.006
        case .river:
            return -0.004
        }
    }

    private func stablePercent(_ coordinate: GridCoordinate, salt: Int) -> Int {
        let raw = coordinate.x * 73_856_093 ^ coordinate.y * 19_349_663 ^ salt * 83_492_791
        return abs(raw % 100)
    }

    private func jitter(_ coordinate: GridCoordinate, salt: Int) -> Float {
        Float(stablePercent(coordinate, salt: salt) - 50) / 50
    }

    private func signature(gridSize: GridSize, layout: TownBiomeLayout) -> String {
        let sides = BiomeSide.allCases
            .map { side in "\(side.rawValue):\(layout.biome(on: side)?.rawValue ?? "none")" }
            .joined(separator: "|")
        return "\(gridSize.columns)x\(gridSize.rows)|\(sides)"
    }
}
