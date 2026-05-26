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
        case .building(let kind, let level):
            addBuilding(kind, level: level, to: root, tileSize: tileSize)
        }

        addPlacementOverlay(snapshot.placementState, to: root, tileSize: tileSize)
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

    static func addTree(to root: Entity, tileSize: Float) {
        let trunk = ModelEntity(
            mesh: .generateBox(size: SIMD3<Float>(tileSize * 0.15, tileSize * 0.40, tileSize * 0.15)),
            materials: [SimpleMaterial(color: UIColor(red: 0.38, green: 0.22, blue: 0.11, alpha: 1), roughness: 0.75, isMetallic: false)]
        )
        trunk.position.y = tileSize * 0.19
        root.addChild(trunk)

        let lowerCanopy = ModelEntity(
            mesh: .generateSphere(radius: tileSize * 0.23),
            materials: [SimpleMaterial(color: UIColor(red: 0.15, green: 0.39, blue: 0.18, alpha: 1), roughness: 0.8, isMetallic: false)]
        )
        lowerCanopy.position.y = tileSize * 0.42
        root.addChild(lowerCanopy)

        let upperCanopy = ModelEntity(
            mesh: .generateSphere(radius: tileSize * 0.17),
            materials: [SimpleMaterial(color: UIColor(red: 0.20, green: 0.50, blue: 0.22, alpha: 1), roughness: 0.82, isMetallic: false)]
        )
        upperCanopy.position.y = tileSize * 0.60
        root.addChild(upperCanopy)
    }

    static func addMountain(to root: Entity, tileSize: Float) {
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

    private static func coordinate(fromName name: String) -> GridCoordinate? {
        let prefix = "world3d_tile_"
        guard name.hasPrefix(prefix) else { return nil }
        let parts = name.dropFirst(prefix.count).split(separator: "_")
        guard parts.count == 2, let x = Int(parts[0]), let y = Int(parts[1]) else { return nil }
        return GridCoordinate(x: x, y: y)
    }

    private static func addPlacementOverlay(_ state: TilePlacementState, to root: Entity, tileSize: Float) {
        let color: UIColor
        switch state {
        case .normal:
            return
        case .valid:
            color = UIColor.systemGreen.withAlphaComponent(0.42)
        case .invalid:
            color = UIColor.systemRed.withAlphaComponent(0.38)
        }

        let overlay = ModelEntity(
            mesh: .generateBox(size: SIMD3<Float>(tileSize * 0.94, 0.018, tileSize * 0.94)),
            materials: [SimpleMaterial(color: color, roughness: 0.45, isMetallic: false)]
        )
        overlay.position.y = 0.036
        root.addChild(overlay)
    }

    private static func addBuilding(_ kind: BuildingKind, level: Int, to root: Entity, tileSize: Float) {
        switch kind {
        case .house:
            addHouse(level: level, to: root, tileSize: tileSize)
        case .farm:
            addFarm(level: level, to: root, tileSize: tileSize)
        case .woodMill:
            addWoodMill(level: level, to: root, tileSize: tileSize)
        case .coalMine:
            addCoalMine(level: level, to: root, tileSize: tileSize)
        case .lab:
            addLab(level: level, to: root, tileSize: tileSize)
        case .barracks:
            addBarracks(level: level, to: root, tileSize: tileSize)
        }
    }

    private static func addHouse(level: Int, to root: Entity, tileSize: Float) {
        addBox(to: root, size: SIMD3<Float>(0.48, 0.34, 0.42) * tileSize, position: SIMD3<Float>(0, 0.17, 0) * tileSize, color: UIColor(red: 0.70, green: 0.48, blue: 0.30, alpha: 1))
        let roof = addBox(to: root, size: SIMD3<Float>(0.60, 0.16, 0.52) * tileSize, position: SIMD3<Float>(0, 0.43, 0) * tileSize, color: UIColor(red: 0.38, green: 0.14, blue: 0.11, alpha: 1))
        roof.orientation = simd_quatf(angle: 0.16, axis: SIMD3<Float>(0, 0, 1))
        addLevelPips(level, to: root, tileSize: tileSize)
    }

    private static func addFarm(level: Int, to root: Entity, tileSize: Float) {
        let cropColor = UIColor(red: 0.78, green: 0.66, blue: 0.22, alpha: 1)
        for index in 0..<4 {
            let x = (Float(index) - 1.5) * tileSize * 0.12
            addBox(to: root, size: SIMD3<Float>(0.045, 0.15, 0.56) * tileSize, position: SIMD3<Float>(x / tileSize, 0.075, 0) * tileSize, color: cropColor)
        }
        addBox(to: root, size: SIMD3<Float>(0.22, 0.22, 0.20) * tileSize, position: SIMD3<Float>(0.22, 0.11, -0.18) * tileSize, color: UIColor(red: 0.58, green: 0.36, blue: 0.20, alpha: 1))
        addLevelPips(level, to: root, tileSize: tileSize)
    }

    private static func addWoodMill(level: Int, to root: Entity, tileSize: Float) {
        addBox(to: root, size: SIMD3<Float>(0.46, 0.28, 0.38) * tileSize, position: SIMD3<Float>(0, 0.14, 0) * tileSize, color: UIColor(red: 0.46, green: 0.29, blue: 0.16, alpha: 1))
        for index in 0..<3 {
            addBox(to: root, size: SIMD3<Float>(0.40, 0.08, 0.08) * tileSize, position: SIMD3<Float>(0, 0.07 + Float(index) * 0.10, 0.25) * tileSize, color: UIColor(red: 0.32, green: 0.18, blue: 0.08, alpha: 1))
        }
        addBox(to: root, size: SIMD3<Float>(0.08, 0.38, 0.08) * tileSize, position: SIMD3<Float>(-0.25, 0.19, -0.12) * tileSize, color: UIColor(red: 0.24, green: 0.14, blue: 0.07, alpha: 1))
        addLevelPips(level, to: root, tileSize: tileSize)
    }

    private static func addCoalMine(level: Int, to root: Entity, tileSize: Float) {
        addMountain(to: root, tileSize: tileSize * 0.82)
        addBox(to: root, size: SIMD3<Float>(0.30, 0.24, 0.08) * tileSize, position: SIMD3<Float>(0, 0.12, 0.19) * tileSize, color: UIColor(red: 0.07, green: 0.07, blue: 0.08, alpha: 1))
        addBox(to: root, size: SIMD3<Float>(0.40, 0.08, 0.12) * tileSize, position: SIMD3<Float>(0, 0.05, 0.30) * tileSize, color: UIColor(red: 0.18, green: 0.16, blue: 0.14, alpha: 1))
        addLevelPips(level, to: root, tileSize: tileSize)
    }

    private static func addLab(level: Int, to root: Entity, tileSize: Float) {
        addBox(to: root, size: SIMD3<Float>(0.42, 0.56, 0.38) * tileSize, position: SIMD3<Float>(0, 0.28, 0) * tileSize, color: UIColor(red: 0.56, green: 0.66, blue: 0.76, alpha: 1))
        addBox(to: root, size: SIMD3<Float>(0.18, 0.28, 0.18) * tileSize, position: SIMD3<Float>(0.18, 0.70, 0) * tileSize, color: UIColor(red: 0.74, green: 0.90, blue: 0.96, alpha: 1))
        addBox(to: root, size: SIMD3<Float>(0.10, 0.10, 0.46) * tileSize, position: SIMD3<Float>(-0.26, 0.42, 0) * tileSize, color: UIColor(red: 0.24, green: 0.48, blue: 0.78, alpha: 1))
        addLevelPips(level, to: root, tileSize: tileSize)
    }

    private static func addBarracks(level: Int, to root: Entity, tileSize: Float) {
        addBox(to: root, size: SIMD3<Float>(0.58, 0.30, 0.44) * tileSize, position: SIMD3<Float>(0, 0.15, 0) * tileSize, color: UIColor(red: 0.58, green: 0.34, blue: 0.32, alpha: 1))
        addBox(to: root, size: SIMD3<Float>(0.66, 0.11, 0.52) * tileSize, position: SIMD3<Float>(0, 0.36, 0) * tileSize, color: UIColor(red: 0.23, green: 0.25, blue: 0.24, alpha: 1))
        addBox(to: root, size: SIMD3<Float>(0.08, 0.42, 0.08) * tileSize, position: SIMD3<Float>(-0.24, 0.42, -0.24) * tileSize, color: UIColor(red: 0.18, green: 0.18, blue: 0.18, alpha: 1))
        addBox(to: root, size: SIMD3<Float>(0.22, 0.12, 0.04) * tileSize, position: SIMD3<Float>(-0.15, 0.58, -0.24) * tileSize, color: UIColor(red: 0.85, green: 0.18, blue: 0.14, alpha: 1))
        addLevelPips(level, to: root, tileSize: tileSize)
    }

    @discardableResult
    private static func addBox(to root: Entity, size: SIMD3<Float>, position: SIMD3<Float>, color: UIColor) -> ModelEntity {
        let box = ModelEntity(
            mesh: .generateBox(size: size),
            materials: [SimpleMaterial(color: color, roughness: 0.76, isMetallic: false)]
        )
        box.position = position
        root.addChild(box)
        return box
    }

    private static func addLevelPips(_ level: Int, to root: Entity, tileSize: Float) {
        guard level > 1 else { return }
        for index in 0..<min(level, 4) {
            addBox(
                to: root,
                size: SIMD3<Float>(0.08, 0.035, 0.08) * tileSize,
                position: SIMD3<Float>(-0.18 + Float(index) * 0.12, 0.03, -0.30) * tileSize,
                color: UIColor.systemYellow
            )
        }
    }
}

private extension SIMD3 where Scalar == Float {
    static func * (lhs: SIMD3<Float>, rhs: Float) -> SIMD3<Float> {
        SIMD3<Float>(lhs.x * rhs, lhs.y * rhs, lhs.z * rhs)
    }
}
