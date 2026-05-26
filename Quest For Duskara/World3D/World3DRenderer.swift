import RealityKit
import UIKit

@MainActor
final class World3DRenderer {
    let arView: ARView

    private let anchor = AnchorEntity(world: .zero)
    private let boardRoot = Entity()
    private var selectedCoordinate: GridCoordinate?
    private var gridSize = GridSize(columns: 9, rows: 9)

    private let tileSize: Float = 0.46
    private let tileGap: Float = 0.035
    private let tileHeight: Float = 0.055

    init(arView: ARView) {
        self.arView = arView
        configureView()
        anchor.addChild(boardRoot)
        arView.scene.anchors.append(anchor)
    }

    func render(adapter: World3DStateAdapter) {
        gridSize = adapter.gridSize
        clearBoard()
        addPedestal(for: gridSize)

        for snapshot in adapter.allTileSnapshots() {
            let entity = World3DTileEntity.makeTile(
                snapshot: snapshot,
                tileSize: tileSize,
                tileHeight: tileHeight,
                material: material(for: snapshot.content, coordinate: snapshot.coordinate)
            )
            entity.position = position(for: snapshot.coordinate)
            boardRoot.addChild(entity)
        }

        addBiomeEdgeHints(layout: adapter.town.biomeLayout, gridSize: adapter.gridSize)
        if let selectedCoordinate {
            showSelection(at: selectedCoordinate)
        }
    }

    func coordinate(for entity: Entity?) -> GridCoordinate? {
        World3DTileEntity.coordinate(from: entity)
    }

    func select(_ coordinate: GridCoordinate?) {
        selectedCoordinate = coordinate
        removeSelection()
        if let coordinate {
            showSelection(at: coordinate)
        }
    }

    private func configureView() {
        arView.cameraMode = .nonAR
        arView.automaticallyConfigureSession = false
        arView.environment.background = .color(UIColor(red: 0.08, green: 0.11, blue: 0.14, alpha: 1))

        let sun = DirectionalLight()
        sun.light.intensity = 3200
        sun.light.color = .white
        sun.orientation = simd_quatf(angle: -.pi / 4, axis: SIMD3<Float>(1, 0, 0)) * simd_quatf(angle: .pi / 5, axis: SIMD3<Float>(0, 1, 0))
        anchor.addChild(sun)

        let fill = PointLight()
        fill.light.intensity = 700
        fill.light.color = UIColor(red: 0.62, green: 0.75, blue: 1.0, alpha: 1)
        fill.position = SIMD3<Float>(-2.8, 2.8, 2.4)
        anchor.addChild(fill)
    }

    private func clearBoard() {
        for child in boardRoot.children {
            child.removeFromParent()
        }
    }

    private func addPedestal(for gridSize: GridSize) {
        let boardWidth = Float(gridSize.columns) * tileSize + Float(gridSize.columns - 1) * tileGap
        let boardDepth = Float(gridSize.rows) * tileSize + Float(gridSize.rows - 1) * tileGap

        let base = ModelEntity(
            mesh: .generateBox(size: SIMD3<Float>(boardWidth + 0.34, 0.18, boardDepth + 0.34)),
            materials: [SimpleMaterial(color: UIColor(red: 0.24, green: 0.25, blue: 0.23, alpha: 1), roughness: 0.85, isMetallic: false)]
        )
        base.position.y = -0.16
        boardRoot.addChild(base)

        let shadow = ModelEntity(
            mesh: .generateBox(size: SIMD3<Float>(boardWidth + 0.7, 0.025, boardDepth + 0.7)),
            materials: [SimpleMaterial(color: UIColor.black.withAlphaComponent(0.36), roughness: 1, isMetallic: false)]
        )
        shadow.position.y = -0.27
        boardRoot.addChild(shadow)
    }

    private func addBiomeEdgeHints(layout: TownBiomeLayout, gridSize: GridSize) {
        let boardWidth = Float(gridSize.columns) * tileSize + Float(gridSize.columns - 1) * tileGap
        let boardDepth = Float(gridSize.rows) * tileSize + Float(gridSize.rows - 1) * tileGap
        let thickness: Float = 0.08
        let inset: Float = 0.08

        for side in BiomeSide.allCases {
            guard let biome = layout.biome(on: side) else { continue }
            let size: SIMD3<Float>
            let position: SIMD3<Float>
            switch side {
            case .top:
                size = SIMD3<Float>(boardWidth, thickness, 0.14)
                position = SIMD3<Float>(0, 0.025, -boardDepth / 2 - inset)
            case .right:
                size = SIMD3<Float>(0.14, thickness, boardDepth)
                position = SIMD3<Float>(boardWidth / 2 + inset, 0.025, 0)
            case .bottom:
                size = SIMD3<Float>(boardWidth, thickness, 0.14)
                position = SIMD3<Float>(0, 0.025, boardDepth / 2 + inset)
            case .left:
                size = SIMD3<Float>(0.14, thickness, boardDepth)
                position = SIMD3<Float>(-boardWidth / 2 - inset, 0.025, 0)
            }

            let edge = ModelEntity(
                mesh: .generateBox(size: size),
                materials: [SimpleMaterial(color: color(for: biome), roughness: 0.82, isMetallic: false)]
            )
            edge.position = position
            boardRoot.addChild(edge)
        }
    }

    private func showSelection(at coordinate: GridCoordinate) {
        let marker = ModelEntity(
            mesh: .generateBox(size: SIMD3<Float>(tileSize * 1.05, 0.03, tileSize * 1.05)),
            materials: [SimpleMaterial(color: UIColor.systemYellow.withAlphaComponent(0.62), roughness: 0.35, isMetallic: false)]
        )
        marker.name = "world3d_selection"
        marker.position = position(for: coordinate) + SIMD3<Float>(0, 0.055, 0)
        boardRoot.addChild(marker)
    }

    private func removeSelection() {
        boardRoot.children
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

    private func color(for biome: BiomeKind) -> UIColor {
        switch biome {
        case .forest:
            return UIColor(red: 0.08, green: 0.32, blue: 0.14, alpha: 1)
        case .mountain:
            return UIColor(red: 0.40, green: 0.40, blue: 0.38, alpha: 1)
        case .plains:
            return UIColor(red: 0.50, green: 0.58, blue: 0.28, alpha: 1)
        case .river:
            return UIColor(red: 0.10, green: 0.36, blue: 0.62, alpha: 1)
        }
    }
}
