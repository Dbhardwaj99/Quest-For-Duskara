import RealityKit
import UIKit

struct World3DTileEntity {
    static func makeTile(
        snapshot: World3DTileSnapshot,
        tileSize: Float,
        tileHeight: Float,
        material: SimpleMaterial
    ) -> Entity {
        let root = Entity()
        root.name = entityName(for: snapshot.coordinate)

        let tile = ModelEntity(
            mesh: .generateBox(size: SIMD3<Float>(tileSize, tileHeight, tileSize)),
            materials: [material]
        )
        tile.name = root.name
        tile.position.y = -tileHeight / 2
        tile.components.set(CollisionComponent(shapes: [.generateBox(size: SIMD3<Float>(tileSize, tileHeight * 2, tileSize))]))
        root.addChild(tile)

        switch snapshot.content {
        case .grass, .water:
            break
        case .tree:
            addTree(to: root, tileSize: tileSize)
        case .mountain:
            addMountain(to: root, tileSize: tileSize)
        case .building(let kind):
            addBuilding(kind, to: root, tileSize: tileSize)
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

    private static func coordinate(fromName name: String) -> GridCoordinate? {
        let prefix = "world3d_tile_"
        guard name.hasPrefix(prefix) else { return nil }
        let parts = name.dropFirst(prefix.count).split(separator: "_")
        guard parts.count == 2, let x = Int(parts[0]), let y = Int(parts[1]) else { return nil }
        return GridCoordinate(x: x, y: y)
    }

    private static func addTree(to root: Entity, tileSize: Float) {
        let trunk = ModelEntity(
            mesh: .generateBox(size: SIMD3<Float>(tileSize * 0.16, tileSize * 0.42, tileSize * 0.16)),
            materials: [SimpleMaterial(color: UIColor(red: 0.38, green: 0.22, blue: 0.11, alpha: 1), roughness: 0.75, isMetallic: false)]
        )
        trunk.position.y = tileSize * 0.19
        root.addChild(trunk)

        let canopy = ModelEntity(
            mesh: .generateSphere(radius: tileSize * 0.24),
            materials: [SimpleMaterial(color: UIColor(red: 0.16, green: 0.43, blue: 0.20, alpha: 1), roughness: 0.8, isMetallic: false)]
        )
        canopy.position.y = tileSize * 0.48
        root.addChild(canopy)
    }

    private static func addMountain(to root: Entity, tileSize: Float) {
        let colors = [
            UIColor(red: 0.43, green: 0.43, blue: 0.40, alpha: 1),
            UIColor(red: 0.34, green: 0.35, blue: 0.34, alpha: 1),
            UIColor(red: 0.52, green: 0.51, blue: 0.47, alpha: 1)
        ]
        let offsets: [SIMD3<Float>] = [
            SIMD3<Float>(-tileSize * 0.12, tileSize * 0.16, 0),
            SIMD3<Float>(tileSize * 0.12, tileSize * 0.12, tileSize * 0.07),
            SIMD3<Float>(0, tileSize * 0.22, -tileSize * 0.10)
        ]
        let sizes: [SIMD3<Float>] = [
            SIMD3<Float>(tileSize * 0.28, tileSize * 0.32, tileSize * 0.28),
            SIMD3<Float>(tileSize * 0.22, tileSize * 0.24, tileSize * 0.22),
            SIMD3<Float>(tileSize * 0.18, tileSize * 0.44, tileSize * 0.18)
        ]

        for index in offsets.indices {
            let rock = ModelEntity(
                mesh: .generateBox(size: sizes[index]),
                materials: [SimpleMaterial(color: colors[index], roughness: 0.92, isMetallic: false)]
            )
            rock.position = offsets[index]
            rock.orientation = simd_quatf(angle: Float(index) * 0.45, axis: SIMD3<Float>(0, 1, 0))
            root.addChild(rock)
        }
    }

    private static func addBuilding(_ kind: BuildingKind, to root: Entity, tileSize: Float) {
        let bodyColor: UIColor
        switch kind {
        case .house: bodyColor = UIColor(red: 0.70, green: 0.48, blue: 0.30, alpha: 1)
        case .farm: bodyColor = UIColor(red: 0.73, green: 0.62, blue: 0.32, alpha: 1)
        case .woodMill: bodyColor = UIColor(red: 0.48, green: 0.31, blue: 0.18, alpha: 1)
        case .coalMine: bodyColor = UIColor(red: 0.30, green: 0.31, blue: 0.33, alpha: 1)
        case .lab: bodyColor = UIColor(red: 0.52, green: 0.62, blue: 0.72, alpha: 1)
        case .barracks: bodyColor = UIColor(red: 0.58, green: 0.34, blue: 0.32, alpha: 1)
        }

        let body = ModelEntity(
            mesh: .generateBox(size: SIMD3<Float>(tileSize * 0.48, tileSize * 0.38, tileSize * 0.42)),
            materials: [SimpleMaterial(color: bodyColor, roughness: 0.72, isMetallic: false)]
        )
        body.position.y = tileSize * 0.19
        root.addChild(body)

        let roof = ModelEntity(
            mesh: .generateBox(size: SIMD3<Float>(tileSize * 0.58, tileSize * 0.15, tileSize * 0.52)),
            materials: [SimpleMaterial(color: UIColor(red: 0.37, green: 0.14, blue: 0.12, alpha: 1), roughness: 0.78, isMetallic: false)]
        )
        roof.position.y = tileSize * 0.49
        roof.orientation = simd_quatf(angle: 0.18, axis: SIMD3<Float>(0, 0, 1))
        root.addChild(roof)
    }
}
