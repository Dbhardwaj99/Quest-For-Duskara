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
    }

    static var templateCache: [TemplateKey: Entity] = [:]

    static func makeTile(
        snapshot: World3DTileSnapshot,
        tileSize: Float,
        tileHeight: Float,
        material: SimpleMaterial,
        gridSize: GridSize
    ) -> Entity {
        let root = Entity()
        root.name = entityName(for: snapshot.coordinate)

        let baseHeight = tileHeight * heightMultiplier(for: snapshot.coordinate)
        if snapshot.content == .water {
            let tile = World3DRenderResources.makeBox(
                size: SIMD3<Float>(tileSize, baseHeight, tileSize),
                material: material,
                cornerRadius: tileSize * 0.10
            )
            tile.name = root.name
            tile.position.y = -baseHeight / 2
            tile.components.set(CollisionComponent(shapes: [World3DRenderResources.collisionBox(size: SIMD3<Float>(tileSize, tileHeight * 2.4, tileSize))]))
            root.addChild(tile)
        } else {
            // Carved-earth tile: a pillowy grass cap slightly overhanging a
            // narrower soil base, so every tile reads as a lump of land
            // rather than a machined prism.
            let soil = World3DRenderResources.makeBox(
                size: SIMD3<Float>(tileSize * 0.94, baseHeight, tileSize * 0.94),
                // Qualified: the `material` parameter shadows the helper here.
                material: World3DRenderResources.material(Palette.fieldDirt, roughness: 0.97),
                cornerRadius: tileSize * 0.05
            )
            soil.name = root.name
            soil.position.y = -baseHeight / 2 - 0.014
            root.addChild(soil)

            let cap = World3DRenderResources.makeBox(
                size: SIMD3<Float>(tileSize, 0.05, tileSize),
                material: material,
                cornerRadius: tileSize * 0.13
            )
            cap.name = root.name
            cap.position.y = -0.025
            cap.components.set(CollisionComponent(shapes: [World3DRenderResources.collisionBox(size: SIMD3<Float>(tileSize, tileHeight * 2.4, tileSize))]))
            root.addChild(cap)
        }

        addGroundDetail(for: snapshot, to: root, tileSize: tileSize)

        switch snapshot.content {
        case .grass, .water:
            break
        case .tree:
            addTree(to: root, tileSize: tileSize, coordinate: snapshot.coordinate)
        case .mountain:
            addMountain(to: root, tileSize: tileSize, coordinate: snapshot.coordinate)
        case .building(let kind, let level):
            addBuilding(kind, level: level, to: root, tileSize: tileSize, coordinate: snapshot.coordinate, gridSize: gridSize)
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
