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
        tileGap: Float,
        tileHeight: Float,
        gridSize: GridSize,
        townID: UUID
    ) -> Entity {
        let root = Entity()
        root.name = entityName(for: snapshot.coordinate)
        // Plot hit targets stay in the RealityKit scene, but their boxes are
        // invisible. The only visible ground is the continuous island mesh.
        let hitTarget = Entity()
        hitTarget.name = root.name
        hitTarget.position.y = -tileHeight * 0.25
        hitTarget.components.set(CollisionComponent(shapes: [World3DRenderResources.collisionBox(
            size: SIMD3<Float>(tileSize + tileGap, tileHeight, tileSize + tileGap)
        )]))
        root.addChild(hitTarget)

        if case .building = snapshot.content {
            // The district and shared paths supply its ground detail.
        } else {
            addGroundDetail(for: snapshot, to: root, tileSize: tileSize)
        }

        switch snapshot.content {
        case .grass, .water:
            break
        case .tree:
            addTree(to: root, tileSize: tileSize, coordinate: snapshot.coordinate)
        case .mountain:
            addMountain(to: root, tileSize: tileSize, coordinate: snapshot.coordinate)
        case .building(let kind, let level):
            addBuilding(kind, level: level, to: root, tileSize: tileSize, coordinate: snapshot.coordinate, gridSize: gridSize, townID: townID)
        }

        return root
    }

    static func entityName(for coordinate: GridCoordinate) -> String {
        "world3d_tile_\(coordinate.x)_\(coordinate.y)"
    }

    static func coordinate(from entity: Entity?) -> GridCoordinate? {
        var cursor = entity
        while let current = cursor {
            if let coordinate = coordinate(fromName: current.name) {
                return coordinate
            }
            cursor = current.parent
        }
        return nil
    }

}
