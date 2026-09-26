import RealityKit
import AppKit

struct World3DTileEntity {
    enum TemplateKind: Hashable {
        case tree
        case mountain
    }

    struct TemplateKey: Hashable {
        let kind: TemplateKind
        let tileSizeBucket: Int
        let theme: WorldTheme
        /// Templates bake their colors in, so a contrast change is as much a
        /// different template as a different theme is.
        let contrast: Double
    }

    static var templateCache: [TemplateKey: Entity] = [:]

    static func makeTile(
        snapshot: World3DTileSnapshot,
        tileSize: Float,
        gridSize: GridSize,
        townID: UUID,
        elevationAt: @escaping (SIMD2<Float>) -> Float
    ) -> Entity {
        let root = Entity()
        // Plots are picked with plane math (World3DRenderer.coordinate(along:)),
        // so tiles carry no hit boxes.
        root.name = entityName(for: snapshot.coordinate)

        if case .building = snapshot.content {
            // The district and shared paths supply its ground detail.
        } else {
            addGroundDetail(for: snapshot, to: root, tileSize: tileSize, elevationAt: elevationAt)
        }

        switch snapshot.content {
        case .grass, .water:
            break
        case .tree:
            addTree(to: root, tileSize: tileSize, coordinate: snapshot.coordinate)
        case .mountain:
            addMountain(to: root, tileSize: tileSize, coordinate: snapshot.coordinate)
        case .building(let kind, let level):
            addBuilding(kind, level: level, to: root, tileSize: tileSize, coordinate: snapshot.coordinate, gridSize: gridSize, townID: townID, elevationAt: elevationAt)
        }

        return root
    }

    static func entityName(for coordinate: GridCoordinate) -> String {
        "world3d_tile_\(coordinate.x)_\(coordinate.y)"
    }

}
