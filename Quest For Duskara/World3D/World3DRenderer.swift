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
    private var gridSize = GridSize(columns: 8, rows: 8)
    private var tileEntities: [GridCoordinate: Entity] = [:]
    private var tileSnapshots: [GridCoordinate: World3DTileSnapshot] = [:]
    private var scaffoldSignature = ""

    private let tileSize: Float = 0.46
    private let tileGap: Float = 0.035
    private let tileHeight: Float = 0.055

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
            tileEntities[snapshot.coordinate]?.removeFromParent()
            let entity = World3DTileEntity.makeTile(
                snapshot: snapshot,
                tileSize: tileSize,
                tileHeight: tileHeight,
                material: material(for: snapshot.content, coordinate: snapshot.coordinate)
            )
            entity.position = position(for: snapshot.coordinate)
            tileRoot.addChild(entity)
            tileEntities[snapshot.coordinate] = entity
            tileSnapshots[snapshot.coordinate] = snapshot
        }

        select(adapter.viewModel.selectedCoordinate)
    }

    func coordinate(for entity: Entity?) -> GridCoordinate? {
        World3DTileEntity.coordinate(from: entity)
    }

    func select(_ coordinate: GridCoordinate?) {
        selectedCoordinate = coordinate
        removeSelection()
        if let coordinate, gridSize.contains(coordinate) {
            showSelection(at: coordinate)
        }
    }

    private func configureView() {
        arView.cameraMode = .nonAR
        arView.automaticallyConfigureSession = false
        arView.environment.background = .color(UIColor(red: 0.08, green: 0.11, blue: 0.14, alpha: 1))

        let sun = DirectionalLight()
        sun.light.intensity = 3400
        sun.light.color = .white
        sun.orientation = simd_quatf(angle: -.pi / 4, axis: SIMD3<Float>(1, 0, 0)) * simd_quatf(angle: .pi / 5, axis: SIMD3<Float>(0, 1, 0))
        anchor.addChild(sun)

        let fill = PointLight()
        fill.light.intensity = 760
        fill.light.color = UIColor(red: 0.62, green: 0.75, blue: 1.0, alpha: 1)
        fill.position = SIMD3<Float>(-2.8, 2.8, 2.4)
        anchor.addChild(fill)
    }

    private func rebuildScaffold(layout: TownBiomeLayout, gridSize: GridSize) {
        staticRoot.children.forEach { $0.removeFromParent() }
        addPedestal(for: gridSize)
        addTerrainRing(layout: layout, gridSize: gridSize)
    }

    private func clearTiles() {
        tileRoot.children.forEach { $0.removeFromParent() }
        tileEntities.removeAll()
        tileSnapshots.removeAll()
    }

    private func addPedestal(for gridSize: GridSize) {
        let boardWidth = fullBoardWidth(for: gridSize)
        let boardDepth = fullBoardDepth(for: gridSize)

        let base = ModelEntity(
            mesh: .generateBox(size: SIMD3<Float>(boardWidth + 0.22, 0.18, boardDepth + 0.22)),
            materials: [SimpleMaterial(color: UIColor(red: 0.24, green: 0.25, blue: 0.23, alpha: 1), roughness: 0.85, isMetallic: false)]
        )
        base.position.y = -0.16
        staticRoot.addChild(base)

        let shadow = ModelEntity(
            mesh: .generateBox(size: SIMD3<Float>(boardWidth + 0.56, 0.025, boardDepth + 0.56)),
            materials: [SimpleMaterial(color: UIColor.black.withAlphaComponent(0.36), roughness: 1, isMetallic: false)]
        )
        shadow.position.y = -0.27
        staticRoot.addChild(shadow)
    }

    private func addTerrainRing(layout: TownBiomeLayout, gridSize: GridSize) {
        for y in -1...gridSize.rows {
            for x in -1...gridSize.columns {
                guard gridSize.contains(GridCoordinate(x: x, y: y)) == false else { continue }
                let coordinate = GridCoordinate(x: x, y: y)
                let biome = terrainBiome(at: coordinate, layout: layout, gridSize: gridSize)
                let root = Entity()
                root.name = "world3d_terrain_\(x)_\(y)"
                root.position = position(for: coordinate)

                let tile = ModelEntity(
                    mesh: .generateBox(size: SIMD3<Float>(tileSize, tileHeight, tileSize)),
                    materials: [terrainMaterial(for: biome, coordinate: coordinate)]
                )
                tile.position.y = -tileHeight / 2
                root.addChild(tile)

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
        let rareMixThreshold = hasAlternateNeighbor ? 18 : 7
        return stablePercent(coordinate, salt: 41) < rareMixThreshold ? alternateBiome : primaryBiome
    }

    private func addTerrainDecoration(for biome: BiomeKind, to root: Entity, coordinate: GridCoordinate) {
        switch biome {
        case .forest:
            let count = stablePercent(coordinate, salt: 7) < 34 ? 2 : 1
            for index in 0..<count {
                let cluster = Entity()
                cluster.position = terrainDecorationOffset(coordinate, index: index)
                World3DTileEntity.addTree(to: cluster, tileSize: tileSize * (count == 1 ? 0.88 : 0.68))
                root.addChild(cluster)
            }
        case .mountain:
            let cluster = Entity()
            cluster.position = terrainDecorationOffset(coordinate, index: 0)
            World3DTileEntity.addMountain(to: cluster, tileSize: tileSize * 0.88)
            root.addChild(cluster)
        case .plains:
            if stablePercent(coordinate, salt: 19) < 18 {
                let cluster = Entity()
                cluster.position = terrainDecorationOffset(coordinate, index: 0)
                World3DTileEntity.addTree(to: cluster, tileSize: tileSize * 0.55)
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
        if coordinate.y == -1 { sides.append(.top) }
        if coordinate.y == gridSize.rows { sides.append(.bottom) }
        if coordinate.x == -1 { sides.append(.left) }
        if coordinate.x == gridSize.columns { sides.append(.right) }
        return sides.isEmpty ? [.top] : sides
    }

    private func terrainDecorationOffset(_ coordinate: GridCoordinate, index: Int) -> SIMD3<Float> {
        let xJitter = Float(stablePercent(coordinate, salt: 101 + index * 17) - 50) / 50 * tileSize * 0.16
        let zJitter = Float(stablePercent(coordinate, salt: 149 + index * 13) - 50) / 50 * tileSize * 0.16
        let splitOffset = index == 0 ? -tileSize * 0.09 : tileSize * 0.09
        return SIMD3<Float>(xJitter + (index == 0 ? splitOffset : -splitOffset), 0, zJitter + splitOffset)
    }

    private func showSelection(at coordinate: GridCoordinate) {
        let marker = ModelEntity(
            mesh: .generateBox(size: SIMD3<Float>(tileSize * 1.05, 0.03, tileSize * 1.05)),
            materials: [SimpleMaterial(color: UIColor.systemYellow.withAlphaComponent(0.62), roughness: 0.35, isMetallic: false)]
        )
        marker.name = "world3d_selection"
        marker.position = position(for: coordinate) + SIMD3<Float>(0, 0.055, 0)
        overlayRoot.addChild(marker)
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
            return SimpleMaterial(color: UIColor(red: 0.12, green: 0.42, blue: 0.70, alpha: 1), roughness: 0.35, isMetallic: false)
        default:
            let shade: CGFloat = (coordinate.x + coordinate.y).isMultiple(of: 2) ? 0.36 : 0.40
            return SimpleMaterial(color: UIColor(red: 0.18, green: shade, blue: 0.19, alpha: 1), roughness: 0.78, isMetallic: false)
        }
    }

    private func terrainMaterial(for biome: BiomeKind, coordinate: GridCoordinate) -> SimpleMaterial {
        let variant = CGFloat(stablePercent(coordinate, salt: 211)) / 1000
        switch biome {
        case .forest:
            return SimpleMaterial(color: UIColor(red: 0.09 + variant, green: 0.28 + variant, blue: 0.13, alpha: 1), roughness: 0.84, isMetallic: false)
        case .mountain:
            return SimpleMaterial(color: UIColor(red: 0.36 + variant, green: 0.37 + variant, blue: 0.34 + variant, alpha: 1), roughness: 0.92, isMetallic: false)
        case .plains:
            return SimpleMaterial(color: UIColor(red: 0.34 + variant, green: 0.43 + variant, blue: 0.22, alpha: 1), roughness: 0.86, isMetallic: false)
        case .river:
            return SimpleMaterial(color: UIColor(red: 0.10, green: 0.34 + variant, blue: 0.58 + variant, alpha: 1), roughness: 0.38, isMetallic: false)
        }
    }

    private func fullBoardWidth(for gridSize: GridSize) -> Float {
        Float(gridSize.columns + 2) * tileSize + Float(gridSize.columns + 1) * tileGap
    }

    private func fullBoardDepth(for gridSize: GridSize) -> Float {
        Float(gridSize.rows + 2) * tileSize + Float(gridSize.rows + 1) * tileGap
    }

    private func stablePercent(_ coordinate: GridCoordinate, salt: Int) -> Int {
        let raw = coordinate.x * 73_856_093 ^ coordinate.y * 19_349_663 ^ salt * 83_492_791
        return abs(raw % 100)
    }

    private func signature(gridSize: GridSize, layout: TownBiomeLayout) -> String {
        let sides = BiomeSide.allCases
            .map { side in "\(side.rawValue):\(layout.biome(on: side)?.rawValue ?? "none")" }
            .joined(separator: "|")
        return "\(gridSize.columns)x\(gridSize.rows)|\(sides)"
    }
}
