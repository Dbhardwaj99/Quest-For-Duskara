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

    private let tileSize: Float = 0.46
    private let tileGap: Float = 0.020
    private let tileHeight: Float = 0.060
    private let terrainRingDepth = 1

    var cameraParent: Entity {
        anchor
    }

    init(arView: ARView) {
        self.arView = arView
        configureView()
        boardRoot.addChild(staticRoot)
        boardRoot.addChild(tileRoot)
        boardRoot.addChild(overlayRoot)
        anchor.addChild(boardRoot)
        arView.scene.anchors.append(anchor)
    }

    func render(adapter: World3DStateAdapter) {
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
        arView.environment.background = .color(UIColor(red: 0.11, green: 0.13, blue: 0.12, alpha: 1))
        arView.renderOptions.insert(.disableDepthOfField)
        arView.renderOptions.insert(.disableMotionBlur)

        let sun = DirectionalLight()
        sun.light.intensity = 4300
        sun.light.color = UIColor(red: 1.0, green: 0.82, blue: 0.58, alpha: 1)
        sun.orientation = simd_quatf(angle: -.pi / 4.8, axis: SIMD3<Float>(1, 0, 0)) * simd_quatf(angle: .pi / 5.8, axis: SIMD3<Float>(0, 1, 0))
        anchor.addChild(sun)

        let warmFill = PointLight()
        warmFill.light.intensity = 360
        warmFill.light.color = UIColor(red: 1.0, green: 0.66, blue: 0.42, alpha: 1)
        warmFill.position = SIMD3<Float>(1.4, 1.8, -1.8)
        anchor.addChild(warmFill)
    }

    private func rebuildScaffold(layout: TownBiomeLayout, gridSize: GridSize) {
        staticRoot.children.forEach { $0.removeFromParent() }
        addGroundPlate(for: gridSize)
        addTerrainRing(layout: layout, gridSize: gridSize)
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
            material: matte(UIColor(red: 0.22, green: 0.24, blue: 0.18, alpha: 1), roughness: 0.96),
            cornerRadius: 0.18
        )
        earth.position.y = -0.25
        staticRoot.addChild(earth)

        addTerrainSkirt(width: boardWidth, depth: boardDepth)
    }

    private func addTerrainSkirt(width: Float, depth: Float) {
        let sideMaterial = matte(UIColor(red: 0.15, green: 0.13, blue: 0.09, alpha: 1), roughness: 0.98)
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
                addTerrainDecoration(for: biome, to: root, coordinate: coordinate)
                staticRoot.addChild(root)
            }
        }
    }

    private func terrainBiome(at coordinate: GridCoordinate, layout: TownBiomeLayout, gridSize: GridSize) -> BiomeKind {
        let primarySide = primarySide(for: coordinate, gridSize: gridSize)
        let primaryBiome = layout.biome(on: primarySide) ?? .plains
        guard primaryBiome == .forest || primaryBiome == .mountain else { return primaryBiome }

        let alternateBiome: BiomeKind = primaryBiome == .forest ? .mountain : .forest
        let nearbySides = sidesTouching(coordinate, gridSize: gridSize)
        let hasAlternateNeighbor = nearbySides.contains { layout.biome(on: $0) == alternateBiome }
        let rareMixThreshold = hasAlternateNeighbor ? 20 : 8
        return stablePercent(coordinate, salt: 41) < rareMixThreshold ? alternateBiome : primaryBiome
    }

    private func addTerrainTexture(for biome: BiomeKind, to root: Entity, coordinate: GridCoordinate) {
        let count = biome == .river ? 2 : 3
        for index in 0..<count {
            let tint: UIColor
            switch biome {
            case .forest:
                tint = stablePercent(coordinate, salt: 300 + index) < 50
                    ? UIColor(red: 0.12, green: 0.23, blue: 0.13, alpha: 1)
                    : UIColor(red: 0.20, green: 0.31, blue: 0.18, alpha: 1)
            case .mountain:
                tint = UIColor(red: 0.48, green: 0.46, blue: 0.39, alpha: 1)
            case .plains:
                tint = UIColor(red: 0.39, green: 0.47, blue: 0.27, alpha: 1)
            case .river:
                tint = UIColor(red: 0.48, green: 0.68, blue: 0.75, alpha: 0.56)
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

    private func addTerrainDecoration(for biome: BiomeKind, to root: Entity, coordinate: GridCoordinate) {
        switch biome {
        case .forest:
            let count = stablePercent(coordinate, salt: 7) < 45 ? 3 : 2
            for index in 0..<count {
                let cluster = Entity()
                cluster.position = terrainDecorationOffset(coordinate, index: index)
                cluster.orientation = simd_quatf(angle: jitter(coordinate, salt: 600 + index) * 0.18, axis: SIMD3<Float>(0, 0, 1))
                World3DTileEntity.addTree(to: cluster, tileSize: tileSize * (count == 2 ? 0.66 : 0.52))
                root.addChild(cluster)
            }
        case .mountain:
            let count = stablePercent(coordinate, salt: 23) < 38 ? 2 : 1
            for index in 0..<count {
                let cluster = Entity()
                cluster.position = terrainDecorationOffset(coordinate, index: index)
                World3DTileEntity.addMountain(to: cluster, tileSize: tileSize * (count == 1 ? 0.92 : 0.68))
                root.addChild(cluster)
            }
        case .plains:
            if stablePercent(coordinate, salt: 19) < 28 {
                let cluster = Entity()
                cluster.position = terrainDecorationOffset(coordinate, index: 0)
                World3DTileEntity.addTree(to: cluster, tileSize: tileSize * 0.48)
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

    private func showSelection(at coordinate: GridCoordinate) {
        let glow = World3DRenderResources.makeBox(
            size: SIMD3<Float>(tileSize * 0.96, 0.022, tileSize * 0.96),
            material: matte(UIColor(red: 0.98, green: 0.78, blue: 0.36, alpha: 0.50), roughness: 0.36),
            cornerRadius: tileSize * 0.055
        )
        glow.name = "world3d_selection"
        glow.position = position(for: coordinate) + SIMD3<Float>(0, 0.084 + tileElevation(for: coordinate), 0)
        overlayRoot.addChild(glow)

        let inner = World3DRenderResources.makeBox(
            size: SIMD3<Float>(tileSize * 0.58, 0.012, tileSize * 0.58),
            material: matte(UIColor(red: 1.0, green: 0.88, blue: 0.54, alpha: 0.34), roughness: 0.32),
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
            return matte(UIColor(red: 0.14 + ripple, green: 0.36 + ripple, blue: 0.47 + ripple, alpha: 1), roughness: 0.34)
        default:
            let variant = CGFloat(stablePercent(coordinate, salt: 211)) / 900
            let warm = CGFloat(stablePercent(coordinate, salt: 67)) / 1400
            return matte(UIColor(red: 0.27 + warm, green: 0.39 + variant, blue: 0.22 + warm, alpha: 1), roughness: 0.90)
        }
    }

    private func terrainMaterial(for biome: BiomeKind, coordinate: GridCoordinate) -> SimpleMaterial {
        let variant = CGFloat(stablePercent(coordinate, salt: 211)) / 1100
        switch biome {
        case .forest:
            return matte(UIColor(red: 0.10 + variant, green: 0.24 + variant, blue: 0.13, alpha: 1), roughness: 0.92)
        case .mountain:
            return matte(UIColor(red: 0.39 + variant, green: 0.38 + variant, blue: 0.34 + variant, alpha: 1), roughness: 0.96)
        case .plains:
            return matte(UIColor(red: 0.32 + variant, green: 0.42 + variant, blue: 0.24, alpha: 1), roughness: 0.92)
        case .river:
            return matte(UIColor(red: 0.12, green: 0.33 + variant, blue: 0.46 + variant, alpha: 1), roughness: 0.32)
        }
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
        let tileCount = gridSize.columns + terrainRingDepth * 2
        return Float(tileCount) * tileSize + Float(tileCount - 1) * tileGap
    }

    private func terrainDepth(for gridSize: GridSize) -> Float {
        let tileCount = gridSize.rows + terrainRingDepth * 2
        return Float(tileCount) * tileSize + Float(tileCount - 1) * tileGap
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
