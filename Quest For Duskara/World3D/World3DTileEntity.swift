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

        let baseHeight = tileHeight * heightMultiplier(for: snapshot.coordinate)
        let tile = ModelEntity(
            mesh: .generateBox(size: SIMD3<Float>(tileSize, baseHeight, tileSize), cornerRadius: tileSize * 0.045),
            materials: [material]
        )
        tile.name = root.name
        tile.position.y = -baseHeight / 2
        tile.components.set(CollisionComponent(shapes: [.generateBox(size: SIMD3<Float>(tileSize, tileHeight * 2.4, tileSize))]))
        root.addChild(tile)

        addGroundDetail(for: snapshot, to: root, tileSize: tileSize, baseHeight: baseHeight)

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
        let trunk = addBox(
            to: root,
            size: SIMD3<Float>(0.12, 0.42, 0.12) * tileSize,
            position: SIMD3<Float>(0, 0.21, 0) * tileSize,
            color: Palette.bark,
            roughness: 0.88,
            cornerRadius: tileSize * 0.018
        )
        trunk.orientation = simd_quatf(angle: -0.08, axis: SIMD3<Float>(0, 0, 1))

        let lowerCanopy = ModelEntity(
            mesh: .generateSphere(radius: tileSize * 0.24),
            materials: [material(Palette.forestMoss, roughness: 0.86)]
        )
        lowerCanopy.position = SIMD3<Float>(-tileSize * 0.02, tileSize * 0.43, 0)
        lowerCanopy.scale = SIMD3<Float>(1.10, 0.82, 0.96)
        root.addChild(lowerCanopy)

        let upperCanopy = ModelEntity(
            mesh: .generateSphere(radius: tileSize * 0.18),
            materials: [material(Palette.leafHighlight, roughness: 0.84)]
        )
        upperCanopy.position = SIMD3<Float>(tileSize * 0.05, tileSize * 0.61, -tileSize * 0.03)
        upperCanopy.scale = SIMD3<Float>(0.92, 1.05, 0.88)
        root.addChild(upperCanopy)
    }

    static func addMountain(to root: Entity, tileSize: Float) {
        let colors = [Palette.warmStone, Palette.deepStone, Palette.paleStone]
        let offsets: [SIMD3<Float>] = [
            SIMD3<Float>(-tileSize * 0.13, tileSize * 0.17, 0),
            SIMD3<Float>(tileSize * 0.13, tileSize * 0.14, tileSize * 0.07),
            SIMD3<Float>(0, tileSize * 0.25, -tileSize * 0.11)
        ]
        let sizes: [SIMD3<Float>] = [
            SIMD3<Float>(tileSize * 0.30, tileSize * 0.34, tileSize * 0.30),
            SIMD3<Float>(tileSize * 0.22, tileSize * 0.28, tileSize * 0.22),
            SIMD3<Float>(tileSize * 0.18, tileSize * 0.50, tileSize * 0.18)
        ]

        for index in offsets.indices {
            let rock = addBox(
                to: root,
                size: sizes[index],
                position: offsets[index],
                color: colors[index],
                roughness: 0.95,
                cornerRadius: tileSize * 0.018
            )
            rock.orientation = simd_quatf(angle: Float(index) * 0.48, axis: SIMD3<Float>(0, 1, 0))
        }

        addBox(
            to: root,
            size: SIMD3<Float>(0.16, 0.025, 0.14) * tileSize,
            position: SIMD3<Float>(-0.03, 0.52, -0.10) * tileSize,
            color: UIColor(red: 0.78, green: 0.76, blue: 0.68, alpha: 1),
            roughness: 0.92,
            cornerRadius: tileSize * 0.008
        )
    }

    private static func coordinate(fromName name: String) -> GridCoordinate? {
        let prefix = "world3d_tile_"
        guard name.hasPrefix(prefix) else { return nil }
        let parts = name.dropFirst(prefix.count).split(separator: "_")
        guard parts.count == 2, let x = Int(parts[0]), let y = Int(parts[1]) else { return nil }
        return GridCoordinate(x: x, y: y)
    }

    private static func addGroundDetail(for snapshot: World3DTileSnapshot, to root: Entity, tileSize: Float, baseHeight: Float) {
        guard snapshot.content != .water else {
            addWaterSheen(to: root, tileSize: tileSize)
            return
        }

        let coordinate = snapshot.coordinate
        let speckCount = stablePercent(coordinate, salt: 12) < 38 ? 3 : 2
        for index in 0..<speckCount {
            let x = jitter(coordinate, salt: 30 + index * 7) * tileSize * 0.34
            let z = jitter(coordinate, salt: 52 + index * 11) * tileSize * 0.34
            addBox(
                to: root,
                size: SIMD3<Float>(0.045 + Float(index % 2) * 0.018, 0.008, 0.028) * tileSize,
                position: SIMD3<Float>(x / tileSize, baseHeight * 0.48 / tileSize + 0.01, z / tileSize) * tileSize,
                color: stablePercent(coordinate, salt: 80 + index) < 45 ? Palette.grassLight : Palette.grassShadow,
                roughness: 0.98,
                cornerRadius: tileSize * 0.004
            )
        }
    }

    private static func addWaterSheen(to root: Entity, tileSize: Float) {
        for index in 0..<2 {
            addBox(
                to: root,
                size: SIMD3<Float>(0.38, 0.009, 0.022) * tileSize,
                position: SIMD3<Float>(0, 0.036, -0.12 + Float(index) * 0.20) * tileSize,
                color: UIColor(red: 0.60, green: 0.78, blue: 0.86, alpha: 0.42),
                roughness: 0.28,
                cornerRadius: tileSize * 0.006
            )
        }
    }

    private static func addPlacementOverlay(_ state: TilePlacementState, to root: Entity, tileSize: Float) {
        let color: UIColor
        let height: Float
        switch state {
        case .normal:
            return
        case .valid:
            color = UIColor(red: 0.80, green: 0.70, blue: 0.38, alpha: 0.50)
            height = 0.026
        case .invalid:
            color = UIColor(red: 0.30, green: 0.25, blue: 0.20, alpha: 0.58)
            height = 0.018
        }

        let overlay = ModelEntity(
            mesh: .generateBox(size: SIMD3<Float>(tileSize * 0.82, height, tileSize * 0.82), cornerRadius: tileSize * 0.04),
            materials: [material(color, roughness: 0.56)]
        )
        overlay.position.y = 0.052
        root.addChild(overlay)

        if state == .valid {
            let glint = ModelEntity(
                mesh: .generateBox(size: SIMD3<Float>(tileSize * 0.62, 0.012, tileSize * 0.07), cornerRadius: tileSize * 0.01),
                materials: [material(UIColor(red: 1.0, green: 0.87, blue: 0.48, alpha: 0.72), roughness: 0.32)]
            )
            glint.position.y = 0.075
            glint.orientation = simd_quatf(angle: 0.72, axis: SIMD3<Float>(0, 1, 0))
            root.addChild(glint)
        }
    }

    private static func addBuilding(_ kind: BuildingKind, level: Int, to root: Entity, tileSize: Float) {
        let plinthColor = UIColor(red: 0.42, green: 0.37, blue: 0.28, alpha: 1)
        addBox(to: root, size: SIMD3<Float>(0.68, 0.045, 0.62) * tileSize, position: SIMD3<Float>(0, 0.022, 0) * tileSize, color: plinthColor, roughness: 0.92, cornerRadius: tileSize * 0.025)

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
        addBox(to: root, size: SIMD3<Float>(0.46, 0.34, 0.40) * tileSize, position: SIMD3<Float>(0, 0.20, 0) * tileSize, color: Palette.plaster, roughness: 0.82, cornerRadius: tileSize * 0.025)
        let roof = addBox(to: root, size: SIMD3<Float>(0.62, 0.18, 0.54) * tileSize, position: SIMD3<Float>(0, 0.47, 0) * tileSize, color: Palette.terracotta, roughness: 0.88, cornerRadius: tileSize * 0.025)
        roof.orientation = simd_quatf(angle: 0.13, axis: SIMD3<Float>(0, 0, 1))
        addBox(to: root, size: SIMD3<Float>(0.09, 0.18, 0.09) * tileSize, position: SIMD3<Float>(0.20, 0.61, -0.08) * tileSize, color: Palette.smokeStone, roughness: 0.9, cornerRadius: tileSize * 0.01)
        addBox(to: root, size: SIMD3<Float>(0.11, 0.14, 0.035) * tileSize, position: SIMD3<Float>(-0.16, 0.24, 0.21) * tileSize, color: Palette.warmWindow, roughness: 0.42, cornerRadius: tileSize * 0.004)
        addLevelPips(level, to: root, tileSize: tileSize)
    }

    private static func addFarm(level: Int, to root: Entity, tileSize: Float) {
        for index in 0..<5 {
            let z = -0.20 + Float(index) * 0.10
            addBox(to: root, size: SIMD3<Float>(0.52, 0.035, 0.030) * tileSize, position: SIMD3<Float>(-0.03, 0.075, z) * tileSize, color: index.isMultiple(of: 2) ? Palette.cropGold : Palette.cropGreen, roughness: 0.92, cornerRadius: tileSize * 0.006)
        }
        addBox(to: root, size: SIMD3<Float>(0.22, 0.22, 0.20) * tileSize, position: SIMD3<Float>(0.22, 0.17, -0.22) * tileSize, color: Palette.barnWood, roughness: 0.86, cornerRadius: tileSize * 0.016)
        addBox(to: root, size: SIMD3<Float>(0.28, 0.08, 0.24) * tileSize, position: SIMD3<Float>(0.22, 0.31, -0.22) * tileSize, color: Palette.strawRoof, roughness: 0.92, cornerRadius: tileSize * 0.014)
        addLevelPips(level, to: root, tileSize: tileSize)
    }

    private static func addWoodMill(level: Int, to root: Entity, tileSize: Float) {
        addBox(to: root, size: SIMD3<Float>(0.46, 0.30, 0.36) * tileSize, position: SIMD3<Float>(0, 0.20, 0) * tileSize, color: Palette.timber, roughness: 0.9, cornerRadius: tileSize * 0.02)
        for index in 0..<3 {
            addBox(to: root, size: SIMD3<Float>(0.42, 0.045, 0.045) * tileSize, position: SIMD3<Float>(0, 0.14 + Float(index) * 0.095, 0.22) * tileSize, color: Palette.darkTimber, roughness: 0.94, cornerRadius: tileSize * 0.006)
        }
        addBox(to: root, size: SIMD3<Float>(0.08, 0.40, 0.08) * tileSize, position: SIMD3<Float>(-0.25, 0.27, -0.12) * tileSize, color: Palette.darkTimber, roughness: 0.92, cornerRadius: tileSize * 0.01)
        addBox(to: root, size: SIMD3<Float>(0.28, 0.055, 0.055) * tileSize, position: SIMD3<Float>(-0.25, 0.43, -0.12) * tileSize, color: Palette.cutWood, roughness: 0.9, cornerRadius: tileSize * 0.006)
        addLevelPips(level, to: root, tileSize: tileSize)
    }

    private static func addCoalMine(level: Int, to root: Entity, tileSize: Float) {
        addMountain(to: root, tileSize: tileSize * 0.76)
        addBox(to: root, size: SIMD3<Float>(0.34, 0.25, 0.10) * tileSize, position: SIMD3<Float>(0, 0.17, 0.20) * tileSize, color: Palette.mineMouth, roughness: 0.98, cornerRadius: tileSize * 0.012)
        addBox(to: root, size: SIMD3<Float>(0.46, 0.075, 0.13) * tileSize, position: SIMD3<Float>(0, 0.075, 0.31) * tileSize, color: Palette.railWood, roughness: 0.92, cornerRadius: tileSize * 0.006)
        addBox(to: root, size: SIMD3<Float>(0.08, 0.24, 0.08) * tileSize, position: SIMD3<Float>(0.24, 0.28, 0.08) * tileSize, color: Palette.smokeStone, roughness: 0.94, cornerRadius: tileSize * 0.008)
        addLevelPips(level, to: root, tileSize: tileSize)
    }

    private static func addLab(level: Int, to root: Entity, tileSize: Float) {
        addBox(to: root, size: SIMD3<Float>(0.42, 0.52, 0.36) * tileSize, position: SIMD3<Float>(0, 0.31, 0) * tileSize, color: Palette.labStone, roughness: 0.76, cornerRadius: tileSize * 0.024)
        addBox(to: root, size: SIMD3<Float>(0.16, 0.28, 0.16) * tileSize, position: SIMD3<Float>(0.18, 0.70, 0) * tileSize, color: Palette.glassGlow, roughness: 0.36, cornerRadius: tileSize * 0.018)
        addBox(to: root, size: SIMD3<Float>(0.085, 0.085, 0.45) * tileSize, position: SIMD3<Float>(-0.26, 0.44, 0) * tileSize, color: Palette.arcaneBlue, roughness: 0.38, cornerRadius: tileSize * 0.01)
        addBox(to: root, size: SIMD3<Float>(0.30, 0.030, 0.30) * tileSize, position: SIMD3<Float>(0, 0.61, 0) * tileSize, color: Palette.warmGold, roughness: 0.52, cornerRadius: tileSize * 0.006)
        addLevelPips(level, to: root, tileSize: tileSize)
    }

    private static func addBarracks(level: Int, to root: Entity, tileSize: Float) {
        addBox(to: root, size: SIMD3<Float>(0.58, 0.31, 0.44) * tileSize, position: SIMD3<Float>(0, 0.21, 0) * tileSize, color: Palette.fortifiedClay, roughness: 0.88, cornerRadius: tileSize * 0.018)
        addBox(to: root, size: SIMD3<Float>(0.68, 0.12, 0.52) * tileSize, position: SIMD3<Float>(0, 0.43, 0) * tileSize, color: Palette.slateRoof, roughness: 0.9, cornerRadius: tileSize * 0.014)
        addBox(to: root, size: SIMD3<Float>(0.08, 0.44, 0.08) * tileSize, position: SIMD3<Float>(-0.25, 0.45, -0.24) * tileSize, color: Palette.darkTimber, roughness: 0.92, cornerRadius: tileSize * 0.006)
        addBox(to: root, size: SIMD3<Float>(0.23, 0.12, 0.035) * tileSize, position: SIMD3<Float>(-0.15, 0.61, -0.24) * tileSize, color: Palette.bannerRed, roughness: 0.78, cornerRadius: tileSize * 0.004)
        addBox(to: root, size: SIMD3<Float>(0.08, 0.18, 0.04) * tileSize, position: SIMD3<Float>(0.22, 0.24, 0.23) * tileSize, color: Palette.warmWindow, roughness: 0.48, cornerRadius: tileSize * 0.004)
        addLevelPips(level, to: root, tileSize: tileSize)
    }

    @discardableResult
    private static func addBox(
        to root: Entity,
        size: SIMD3<Float>,
        position: SIMD3<Float>,
        color: UIColor,
        roughness: Float = 0.78,
        cornerRadius: Float = 0
    ) -> ModelEntity {
        let box = ModelEntity(
            mesh: .generateBox(size: size, cornerRadius: cornerRadius),
            materials: [material(color, roughness: roughness)]
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
                size: SIMD3<Float>(0.07, 0.025, 0.07) * tileSize,
                position: SIMD3<Float>(-0.18 + Float(index) * 0.11, 0.075, -0.32) * tileSize,
                color: Palette.warmGold,
                roughness: 0.52,
                cornerRadius: tileSize * 0.006
            )
        }
    }

    private static func material(_ color: UIColor, roughness: Float, metallic: Bool = false) -> SimpleMaterial {
        SimpleMaterial(color: color, roughness: MaterialScalarParameter(floatLiteral: roughness), isMetallic: metallic)
    }

    private static func heightMultiplier(for coordinate: GridCoordinate) -> Float {
        0.88 + Float(stablePercent(coordinate, salt: 5)) / 100 * 0.22
    }

    private static func stablePercent(_ coordinate: GridCoordinate, salt: Int) -> Int {
        let raw = coordinate.x * 73_856_093 ^ coordinate.y * 19_349_663 ^ salt * 83_492_791
        return abs(raw % 100)
    }

    private static func jitter(_ coordinate: GridCoordinate, salt: Int) -> Float {
        Float(stablePercent(coordinate, salt: salt) - 50) / 50
    }
}

private enum Palette {
    static let grassLight = UIColor(red: 0.40, green: 0.51, blue: 0.30, alpha: 1)
    static let grassShadow = UIColor(red: 0.24, green: 0.37, blue: 0.22, alpha: 1)
    static let forestMoss = UIColor(red: 0.16, green: 0.32, blue: 0.19, alpha: 1)
    static let leafHighlight = UIColor(red: 0.24, green: 0.43, blue: 0.24, alpha: 1)
    static let bark = UIColor(red: 0.33, green: 0.22, blue: 0.13, alpha: 1)
    static let warmStone = UIColor(red: 0.48, green: 0.47, blue: 0.41, alpha: 1)
    static let deepStone = UIColor(red: 0.34, green: 0.35, blue: 0.33, alpha: 1)
    static let paleStone = UIColor(red: 0.58, green: 0.56, blue: 0.49, alpha: 1)
    static let smokeStone = UIColor(red: 0.36, green: 0.34, blue: 0.30, alpha: 1)
    static let plaster = UIColor(red: 0.70, green: 0.55, blue: 0.39, alpha: 1)
    static let terracotta = UIColor(red: 0.43, green: 0.20, blue: 0.16, alpha: 1)
    static let warmWindow = UIColor(red: 0.93, green: 0.70, blue: 0.36, alpha: 1)
    static let cropGold = UIColor(red: 0.75, green: 0.64, blue: 0.30, alpha: 1)
    static let cropGreen = UIColor(red: 0.36, green: 0.49, blue: 0.24, alpha: 1)
    static let barnWood = UIColor(red: 0.52, green: 0.32, blue: 0.19, alpha: 1)
    static let strawRoof = UIColor(red: 0.70, green: 0.56, blue: 0.30, alpha: 1)
    static let timber = UIColor(red: 0.43, green: 0.29, blue: 0.17, alpha: 1)
    static let darkTimber = UIColor(red: 0.25, green: 0.17, blue: 0.10, alpha: 1)
    static let cutWood = UIColor(red: 0.59, green: 0.40, blue: 0.23, alpha: 1)
    static let mineMouth = UIColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1)
    static let railWood = UIColor(red: 0.24, green: 0.20, blue: 0.16, alpha: 1)
    static let labStone = UIColor(red: 0.58, green: 0.64, blue: 0.64, alpha: 1)
    static let glassGlow = UIColor(red: 0.66, green: 0.86, blue: 0.88, alpha: 1)
    static let arcaneBlue = UIColor(red: 0.24, green: 0.52, blue: 0.70, alpha: 1)
    static let warmGold = UIColor(red: 0.87, green: 0.67, blue: 0.34, alpha: 1)
    static let fortifiedClay = UIColor(red: 0.55, green: 0.34, blue: 0.29, alpha: 1)
    static let slateRoof = UIColor(red: 0.28, green: 0.31, blue: 0.29, alpha: 1)
    static let bannerRed = UIColor(red: 0.66, green: 0.22, blue: 0.17, alpha: 1)
}

private extension SIMD3 where Scalar == Float {
    static func * (lhs: SIMD3<Float>, rhs: Float) -> SIMD3<Float> {
        SIMD3<Float>(lhs.x * rhs, lhs.y * rhs, lhs.z * rhs)
    }
}
