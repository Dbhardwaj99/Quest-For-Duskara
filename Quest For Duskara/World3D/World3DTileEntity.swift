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

        addGroundDetail(for: snapshot, to: root, tileSize: tileSize)

        switch snapshot.content {
        case .grass, .water:
            break
        case .tree:
            addTree(to: root, tileSize: tileSize, coordinate: snapshot.coordinate)
        case .mountain:
            addMountain(to: root, tileSize: tileSize, coordinate: snapshot.coordinate)
        case .building(let kind, let level):
            addBuilding(kind, level: level, to: root, tileSize: tileSize, coordinate: snapshot.coordinate)
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
        addTree(to: root, tileSize: tileSize, coordinate: GridCoordinate(x: 0, y: 0))
    }

    static func addTree(to root: Entity, tileSize: Float, coordinate: GridCoordinate) {
        let lean = jitter(coordinate, salt: 91) * 0.12
        let heightScale = 0.92 + randomFloat(coordinate, salt: 92) * 0.18
        let canopyCount = 3 + stablePercent(coordinate, salt: 93) % 3
        let trunkOffset = SIMD3<Float>(jitter(coordinate, salt: 94) * 0.035, 0, jitter(coordinate, salt: 95) * 0.035)

        addGroundPatch(
            to: root,
            tileSize: tileSize,
            center: SIMD2<Float>(trunkOffset.x, trunkOffset.z),
            size: SIMD2<Float>(0.36, 0.30),
            color: Palette.rootSoil,
            rotation: jitter(coordinate, salt: 96) * 0.45
        )

        let trunk = addBox(
            to: root,
            size: SIMD3<Float>(0.13, 0.46 * heightScale, 0.12) * tileSize,
            position: SIMD3<Float>(trunkOffset.x, 0.23 * heightScale, trunkOffset.z) * tileSize,
            color: Palette.bark,
            roughness: 0.88,
            cornerRadius: tileSize * 0.018
        )
        trunk.orientation = simd_quatf(angle: lean, axis: SIMD3<Float>(0, 0, 1)) * simd_quatf(angle: -lean * 0.55, axis: SIMD3<Float>(1, 0, 0))

        addRootCluster(to: root, tileSize: tileSize, coordinate: coordinate, center: SIMD2<Float>(trunkOffset.x, trunkOffset.z))

        for index in 0..<canopyCount {
            let x = trunkOffset.x + jitter(coordinate, salt: 101 + index * 11) * 0.13
            let z = trunkOffset.z + jitter(coordinate, salt: 107 + index * 13) * 0.12
            let y = 0.43 + Float(index) * 0.07 + randomFloat(coordinate, salt: 109 + index) * 0.12
            let radius = 0.17 + randomFloat(coordinate, salt: 113 + index * 5) * 0.085
            let scale = SIMD3<Float>(
                1.08 + jitter(coordinate, salt: 117 + index) * 0.18,
                0.74 + randomFloat(coordinate, salt: 121 + index) * 0.28,
                0.94 + jitter(coordinate, salt: 125 + index) * 0.16
            )
            addCanopyBlob(
                to: root,
                tileSize: tileSize,
                radius: radius,
                position: SIMD3<Float>(x, y * heightScale, z),
                scale: scale,
                color: index.isMultiple(of: 2) ? Palette.forestMoss : Palette.leafHighlight
            )
        }

        for index in 0..<2 {
            let branch = addBox(
                to: root,
                size: SIMD3<Float>(0.16, 0.035, 0.045) * tileSize,
                position: SIMD3<Float>(trunkOffset.x + jitter(coordinate, salt: 134 + index) * 0.08, 0.34 + Float(index) * 0.08, trunkOffset.z + jitter(coordinate, salt: 139 + index) * 0.07) * tileSize,
                color: Palette.bark,
                roughness: 0.9,
                cornerRadius: tileSize * 0.008
            )
            branch.orientation = simd_quatf(angle: 0.45 + jitter(coordinate, salt: 142 + index) * 0.45, axis: SIMD3<Float>(0, 1, 0))
        }

        addRockCluster(to: root, tileSize: tileSize, coordinate: coordinate, center: SIMD2<Float>(-0.18, 0.22), radius: 0.13, count: 3, scale: 0.72)
        addGrassClumps(to: root, tileSize: tileSize, coordinate: coordinate, count: 5, around: SIMD2<Float>(trunkOffset.x, trunkOffset.z), radius: 0.38)
    }

    static func addMountain(to root: Entity, tileSize: Float) {
        addMountain(to: root, tileSize: tileSize, coordinate: GridCoordinate(x: 0, y: 0))
    }

    static func addMountain(to root: Entity, tileSize: Float, coordinate: GridCoordinate) {
        addGroundPatch(
            to: root,
            tileSize: tileSize,
            center: SIMD2<Float>(0, 0),
            size: SIMD2<Float>(0.76, 0.68),
            color: Palette.stoneDust,
            rotation: jitter(coordinate, salt: 151) * 0.45
        )

        let peakSpecs: [(SIMD3<Float>, SIMD3<Float>, UIColor, Int)] = [
            (SIMD3<Float>(-0.04, 0.32, -0.04), SIMD3<Float>(0.34, 0.64, 0.32), Palette.warmStone, 153),
            (SIMD3<Float>(0.18, 0.24, 0.08), SIMD3<Float>(0.27, 0.46, 0.25), Palette.deepStone, 157),
            (SIMD3<Float>(-0.23, 0.19, 0.10), SIMD3<Float>(0.23, 0.38, 0.24), Palette.paleStone, 161),
            (SIMD3<Float>(0.04, 0.16, -0.24), SIMD3<Float>(0.20, 0.31, 0.20), Palette.smokeStone, 167)
        ]

        for spec in peakSpecs {
            let offset = SIMD3<Float>(
                spec.0.x + jitter(coordinate, salt: spec.3) * 0.035,
                spec.0.y,
                spec.0.z + jitter(coordinate, salt: spec.3 + 1) * 0.035
            )
            let size = SIMD3<Float>(
                spec.1.x * (0.92 + randomFloat(coordinate, salt: spec.3 + 2) * 0.18),
                spec.1.y * (0.92 + randomFloat(coordinate, salt: spec.3 + 3) * 0.20),
                spec.1.z * (0.92 + randomFloat(coordinate, salt: spec.3 + 4) * 0.18)
            )
            let rock = addBox(
                to: root,
                size: size * tileSize,
                position: offset * tileSize,
                color: spec.2,
                roughness: 0.95,
                cornerRadius: tileSize * 0.02
            )
            rock.orientation = simd_quatf(angle: randomAngle(coordinate, salt: spec.3 + 5), axis: SIMD3<Float>(0, 1, 0))
        }

        addRockStrata(to: root, tileSize: tileSize, coordinate: coordinate)
        addRockCluster(to: root, tileSize: tileSize, coordinate: coordinate, center: SIMD2<Float>(0.18, -0.26), radius: 0.25, count: 6, scale: 0.95)
        addRockCluster(to: root, tileSize: tileSize, coordinate: coordinate, center: SIMD2<Float>(-0.24, 0.24), radius: 0.18, count: 4, scale: 0.78)
        addDebris(to: root, tileSize: tileSize, coordinate: coordinate, count: 5, around: SIMD2<Float>(0.03, 0.18), radius: 0.32, color: Palette.deepStone)
    }

    private static func coordinate(fromName name: String) -> GridCoordinate? {
        let prefix = "world3d_tile_"
        guard name.hasPrefix(prefix) else { return nil }
        let parts = name.dropFirst(prefix.count).split(separator: "_")
        guard parts.count == 2, let x = Int(parts[0]), let y = Int(parts[1]) else { return nil }
        return GridCoordinate(x: x, y: y)
    }

    private static func addGroundDetail(for snapshot: World3DTileSnapshot, to root: Entity, tileSize: Float) {
        guard snapshot.content != .water else {
            addWaterSheen(to: root, tileSize: tileSize, coordinate: snapshot.coordinate)
            return
        }

        let coordinate = snapshot.coordinate
        let patchColor: UIColor
        switch snapshot.content {
        case .tree:
            patchColor = Palette.rootSoil
        case .mountain:
            patchColor = Palette.stoneDust
        case .building:
            patchColor = Palette.walkedDirt
        case .grass:
            patchColor = stablePercent(coordinate, salt: 13) < 50 ? Palette.grassLight : Palette.grassShadow
        case .water:
            patchColor = Palette.grassLight
        }

        if snapshot.content == .grass {
            addGrassClumps(to: root, tileSize: tileSize, coordinate: coordinate, count: 4, around: SIMD2<Float>(0, 0), radius: 0.42)
        } else {
            addGroundPatch(
                to: root,
                tileSize: tileSize,
                center: SIMD2<Float>(jitter(coordinate, salt: 18) * 0.04, jitter(coordinate, salt: 19) * 0.04),
                size: SIMD2<Float>(0.66, 0.56),
                color: patchColor,
                rotation: randomAngle(coordinate, salt: 20) * 0.12
            )
        }

        let speckCount = 2 + stablePercent(coordinate, salt: 12) % 3
        for index in 0..<speckCount {
            let x = jitter(coordinate, salt: 30 + index * 7) * 0.36
            let z = jitter(coordinate, salt: 52 + index * 11) * 0.36
            let fleck = addBox(
                to: root,
                size: SIMD3<Float>(0.035 + Float(index % 2) * 0.014, 0.008, 0.025) * tileSize,
                position: SIMD3<Float>(x, 0.011, z) * tileSize,
                color: stablePercent(coordinate, salt: 80 + index) < 45 ? Palette.grassLight : Palette.grassShadow,
                roughness: 0.98,
                cornerRadius: tileSize * 0.004
            )
            fleck.orientation = simd_quatf(angle: randomAngle(coordinate, salt: 85 + index), axis: SIMD3<Float>(0, 1, 0))
        }
    }

    private static func addWaterSheen(to root: Entity, tileSize: Float, coordinate: GridCoordinate) {
        for index in 0..<3 {
            let sheen = addBox(
                to: root,
                size: SIMD3<Float>(0.30 + randomFloat(coordinate, salt: 201 + index) * 0.16, 0.009, 0.018) * tileSize,
                position: SIMD3<Float>(jitter(coordinate, salt: 204 + index) * 0.12, 0.036, -0.22 + Float(index) * 0.20) * tileSize,
                color: Palette.waterSheen,
                roughness: 0.28,
                cornerRadius: tileSize * 0.006
            )
            sheen.orientation = simd_quatf(angle: jitter(coordinate, salt: 208 + index) * 0.22, axis: SIMD3<Float>(0, 1, 0))
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

    private static func addBuilding(_ kind: BuildingKind, level: Int, to root: Entity, tileSize: Float, coordinate: GridCoordinate) {
        addGroundPatch(
            to: root,
            tileSize: tileSize,
            center: SIMD2<Float>(jitter(coordinate, salt: 211) * 0.025, jitter(coordinate, salt: 212) * 0.025),
            size: SIMD2<Float>(0.76, 0.68),
            color: Palette.walkedDirt,
            rotation: jitter(coordinate, salt: 213) * 0.35
		)

        let plinth = addBox(
            to: root,
            size: SIMD3<Float>(0.68, 0.045, 0.62) * tileSize,
            position: SIMD3<Float>(jitter(coordinate, salt: 214) * 0.018, 0.022, jitter(coordinate, salt: 215) * 0.018) * tileSize,
            color: Palette.plinthStone,
            roughness: 0.92,
            cornerRadius: tileSize * 0.025
        )
        plinth.orientation = simd_quatf(angle: jitter(coordinate, salt: 216) * 0.08, axis: SIMD3<Float>(0, 1, 0))

        switch kind {
        case .house:
            addHouse(level: level, to: root, tileSize: tileSize, coordinate: coordinate)
        case .farm:
            addFarm(level: level, to: root, tileSize: tileSize, coordinate: coordinate)
        case .woodMill:
            addWoodMill(level: level, to: root, tileSize: tileSize, coordinate: coordinate)
        case .coalMine:
            addCoalMine(level: level, to: root, tileSize: tileSize, coordinate: coordinate)
        case .lab:
            addLab(level: level, to: root, tileSize: tileSize, coordinate: coordinate)
        case .barracks:
            addBarracks(level: level, to: root, tileSize: tileSize, coordinate: coordinate)
        }

        addGrassClumps(to: root, tileSize: tileSize, coordinate: coordinate, count: 3, around: SIMD2<Float>(0, 0), radius: 0.43)
    }

    private static func addHouse(level: Int, to root: Entity, tileSize: Float, coordinate: GridCoordinate) {
        let bodyOffset = SIMD3<Float>(jitter(coordinate, salt: 221) * 0.025, 0, jitter(coordinate, salt: 222) * 0.02)
        addBox(to: root, size: SIMD3<Float>(0.43, 0.34, 0.38) * tileSize, position: (SIMD3<Float>(-0.04, 0.22, -0.01) + bodyOffset) * tileSize, color: Palette.plaster, roughness: 0.82, cornerRadius: tileSize * 0.025)
        let roof = addBox(to: root, size: SIMD3<Float>(0.58, 0.17, 0.50) * tileSize, position: (SIMD3<Float>(-0.055, 0.48, -0.01) + bodyOffset) * tileSize, color: Palette.terracotta, roughness: 0.88, cornerRadius: tileSize * 0.025)
        roof.orientation = simd_quatf(angle: 0.12 + jitter(coordinate, salt: 223) * 0.07, axis: SIMD3<Float>(0, 0, 1))
        let cap = addBox(to: root, size: SIMD3<Float>(0.50, 0.055, 0.55) * tileSize, position: (SIMD3<Float>(-0.08, 0.58, -0.02) + bodyOffset) * tileSize, color: Palette.roofHighlight, roughness: 0.88, cornerRadius: tileSize * 0.012)
        cap.orientation = roof.orientation

        addBox(to: root, size: SIMD3<Float>(0.20, 0.22, 0.23) * tileSize, position: SIMD3<Float>(0.24, 0.16, 0.12) * tileSize, color: Palette.sideShed, roughness: 0.86, cornerRadius: tileSize * 0.018)
        let shedRoof = addBox(to: root, size: SIMD3<Float>(0.26, 0.07, 0.28) * tileSize, position: SIMD3<Float>(0.24, 0.30, 0.12) * tileSize, color: Palette.strawRoof, roughness: 0.92, cornerRadius: tileSize * 0.012)
        shedRoof.orientation = simd_quatf(angle: -0.11, axis: SIMD3<Float>(0, 0, 1))

        let chimney = addBox(to: root, size: SIMD3<Float>(0.085, 0.20, 0.085) * tileSize, position: SIMD3<Float>(0.14 + jitter(coordinate, salt: 224) * 0.05, 0.66, -0.12) * tileSize, color: Palette.smokeStone, roughness: 0.9, cornerRadius: tileSize * 0.01)
        chimney.orientation = simd_quatf(angle: jitter(coordinate, salt: 225) * 0.09, axis: SIMD3<Float>(0, 0, 1))
        addBox(to: root, size: SIMD3<Float>(0.12, 0.03, 0.11) * tileSize, position: SIMD3<Float>(chimney.position.x / tileSize, 0.775, chimney.position.z / tileSize) * tileSize, color: Palette.deepStone, roughness: 0.9, cornerRadius: tileSize * 0.005)

        addBox(to: root, size: SIMD3<Float>(0.12, 0.13, 0.035) * tileSize, position: SIMD3<Float>(-0.21, 0.25, 0.20) * tileSize, color: Palette.warmWindow, roughness: 0.42, cornerRadius: tileSize * 0.004)
        addBox(to: root, size: SIMD3<Float>(0.11, 0.15, 0.038) * tileSize, position: SIMD3<Float>(0.05, 0.23, 0.20) * tileSize, color: Palette.doorWood, roughness: 0.84, cornerRadius: tileSize * 0.004)
        addFence(to: root, tileSize: tileSize, coordinate: coordinate, start: SIMD2<Float>(-0.35, 0.29), count: 3, horizontal: true)
        addDebris(to: root, tileSize: tileSize, coordinate: coordinate, count: 4, around: SIMD2<Float>(0.29, -0.22), radius: 0.16, color: Palette.cutWood)
        addBarrel(to: root, tileSize: tileSize, position: SIMD3<Float>(-0.31, 0.08, -0.24), salt: 226, coordinate: coordinate)
        addLevelPips(level, to: root, tileSize: tileSize)
    }

    private static func addFarm(level: Int, to root: Entity, tileSize: Float, coordinate: GridCoordinate) {
        addGroundPatch(to: root, tileSize: tileSize, center: SIMD2<Float>(-0.10, 0.06), size: SIMD2<Float>(0.58, 0.50), color: Palette.fieldDirt, rotation: jitter(coordinate, salt: 231) * 0.18)
        for index in 0..<6 {
            let z = -0.25 + Float(index) * 0.09 + jitter(coordinate, salt: 232 + index) * 0.015
            let row = addBox(to: root, size: SIMD3<Float>(0.48 + jitter(coordinate, salt: 238 + index) * 0.05, 0.035, 0.028) * tileSize, position: SIMD3<Float>(-0.12 + jitter(coordinate, salt: 244 + index) * 0.025, 0.075, z) * tileSize, color: index.isMultiple(of: 2) ? Palette.cropGold : Palette.cropGreen, roughness: 0.92, cornerRadius: tileSize * 0.006)
            row.orientation = simd_quatf(angle: jitter(coordinate, salt: 250 + index) * 0.05, axis: SIMD3<Float>(0, 1, 0))
        }
        addBox(to: root, size: SIMD3<Float>(0.23, 0.24, 0.20) * tileSize, position: SIMD3<Float>(0.23, 0.18, -0.23) * tileSize, color: Palette.barnWood, roughness: 0.86, cornerRadius: tileSize * 0.016)
        let roof = addBox(to: root, size: SIMD3<Float>(0.30, 0.09, 0.25) * tileSize, position: SIMD3<Float>(0.22, 0.335, -0.23) * tileSize, color: Palette.strawRoof, roughness: 0.92, cornerRadius: tileSize * 0.014)
        roof.orientation = simd_quatf(angle: -0.08, axis: SIMD3<Float>(0, 0, 1))
        addBox(to: root, size: SIMD3<Float>(0.12, 0.12, 0.035) * tileSize, position: SIMD3<Float>(0.23, 0.19, -0.12) * tileSize, color: Palette.doorWood, roughness: 0.84, cornerRadius: tileSize * 0.004)
        addFence(to: root, tileSize: tileSize, coordinate: coordinate, start: SIMD2<Float>(-0.39, -0.33), count: 5, horizontal: true)
        addWoodPile(to: root, tileSize: tileSize, coordinate: coordinate, center: SIMD3<Float>(0.34, 0.07, 0.21), count: 3)
        addLevelPips(level, to: root, tileSize: tileSize)
    }

    private static func addWoodMill(level: Int, to root: Entity, tileSize: Float, coordinate: GridCoordinate) {
        addBox(to: root, size: SIMD3<Float>(0.42, 0.30, 0.34) * tileSize, position: SIMD3<Float>(-0.02, 0.20, -0.01) * tileSize, color: Palette.timber, roughness: 0.9, cornerRadius: tileSize * 0.02)
        let roof = addBox(to: root, size: SIMD3<Float>(0.50, 0.10, 0.40) * tileSize, position: SIMD3<Float>(-0.04, 0.405, -0.02) * tileSize, color: Palette.darkTimber, roughness: 0.92, cornerRadius: tileSize * 0.014)
        roof.orientation = simd_quatf(angle: 0.10 + jitter(coordinate, salt: 261) * 0.06, axis: SIMD3<Float>(0, 0, 1))

        for index in 0..<3 {
            addSupportBeam(to: root, tileSize: tileSize, position: SIMD3<Float>(-0.20 + Float(index) * 0.19, 0.20, 0.20), height: 0.31, salt: 262 + index, coordinate: coordinate)
            addBox(to: root, size: SIMD3<Float>(0.38, 0.042, 0.045) * tileSize, position: SIMD3<Float>(-0.02, 0.13 + Float(index) * 0.09, 0.205) * tileSize, color: Palette.darkTimber, roughness: 0.94, cornerRadius: tileSize * 0.006)
        }

        addBox(to: root, size: SIMD3<Float>(0.42, 0.06, 0.30) * tileSize, position: SIMD3<Float>(0.18, 0.09, -0.28) * tileSize, color: Palette.sawPlatform, roughness: 0.9, cornerRadius: tileSize * 0.01)
        addBox(to: root, size: SIMD3<Float>(0.32, 0.035, 0.05) * tileSize, position: SIMD3<Float>(0.20, 0.145, -0.28) * tileSize, color: Palette.paleStone, roughness: 0.86, cornerRadius: tileSize * 0.004)
        addBox(to: root, size: SIMD3<Float>(0.055, 0.15, 0.055) * tileSize, position: SIMD3<Float>(0.00, 0.19, -0.28) * tileSize, color: Palette.darkTimber, roughness: 0.92, cornerRadius: tileSize * 0.004)

        addWheel(to: root, tileSize: tileSize, center: SIMD3<Float>(-0.30, 0.25, -0.05), coordinate: coordinate)
        addWoodPile(to: root, tileSize: tileSize, coordinate: coordinate, center: SIMD3<Float>(0.34, 0.07, 0.18), count: 5)
        addDebris(to: root, tileSize: tileSize, coordinate: coordinate, count: 5, around: SIMD2<Float>(-0.29, 0.27), radius: 0.16, color: Palette.cutWood)
        addLevelPips(level, to: root, tileSize: tileSize)
    }

    private static func addCoalMine(level: Int, to root: Entity, tileSize: Float, coordinate: GridCoordinate) {
        addGroundPatch(to: root, tileSize: tileSize, center: SIMD2<Float>(0.03, 0.04), size: SIMD2<Float>(0.74, 0.66), color: Palette.coalDust, rotation: jitter(coordinate, salt: 281) * 0.22)
        addMountain(to: root, tileSize: tileSize * 0.76, coordinate: coordinate)
        addBox(to: root, size: SIMD3<Float>(0.38, 0.27, 0.11) * tileSize, position: SIMD3<Float>(0.02, 0.18, 0.20) * tileSize, color: Palette.mineMouth, roughness: 0.98, cornerRadius: tileSize * 0.014)
        addBox(to: root, size: SIMD3<Float>(0.28, 0.18, 0.12) * tileSize, position: SIMD3<Float>(0.02, 0.14, 0.255) * tileSize, color: Palette.tunnelShadow, roughness: 1.0, cornerRadius: tileSize * 0.012)
        addSupportBeam(to: root, tileSize: tileSize, position: SIMD3<Float>(-0.18, 0.20, 0.28), height: 0.26, salt: 282, coordinate: coordinate)
        addSupportBeam(to: root, tileSize: tileSize, position: SIMD3<Float>(0.22, 0.20, 0.27), height: 0.25, salt: 283, coordinate: coordinate)
        addBox(to: root, size: SIMD3<Float>(0.45, 0.055, 0.065) * tileSize, position: SIMD3<Float>(0.02, 0.30, 0.275) * tileSize, color: Palette.railWood, roughness: 0.92, cornerRadius: tileSize * 0.006)

        addBox(to: root, size: SIMD3<Float>(0.48, 0.035, 0.045) * tileSize, position: SIMD3<Float>(0.02, 0.065, 0.36) * tileSize, color: Palette.railWood, roughness: 0.92, cornerRadius: tileSize * 0.004)
        addBox(to: root, size: SIMD3<Float>(0.48, 0.025, 0.018) * tileSize, position: SIMD3<Float>(0.02, 0.095, 0.315) * tileSize, color: Palette.deepStone, roughness: 0.88, cornerRadius: tileSize * 0.002)
        addBox(to: root, size: SIMD3<Float>(0.48, 0.025, 0.018) * tileSize, position: SIMD3<Float>(0.02, 0.095, 0.405) * tileSize, color: Palette.deepStone, roughness: 0.88, cornerRadius: tileSize * 0.002)
        addRockCluster(to: root, tileSize: tileSize, coordinate: coordinate, center: SIMD2<Float>(-0.30, -0.18), radius: 0.18, count: 5, scale: 0.82)
        addDebris(to: root, tileSize: tileSize, coordinate: coordinate, count: 6, around: SIMD2<Float>(0.23, 0.33), radius: 0.18, color: Palette.coalChunk)
        addLevelPips(level, to: root, tileSize: tileSize)
    }

    private static func addLab(level: Int, to root: Entity, tileSize: Float, coordinate: GridCoordinate) {
        addBox(to: root, size: SIMD3<Float>(0.38, 0.43, 0.34) * tileSize, position: SIMD3<Float>(-0.05, 0.265, 0.02) * tileSize, color: Palette.labStone, roughness: 0.76, cornerRadius: tileSize * 0.024)
        addBox(to: root, size: SIMD3<Float>(0.47, 0.045, 0.42) * tileSize, position: SIMD3<Float>(-0.04, 0.51, 0.02) * tileSize, color: Palette.warmGold, roughness: 0.52, cornerRadius: tileSize * 0.006)
        let tower = addBox(to: root, size: SIMD3<Float>(0.18, 0.62, 0.18) * tileSize, position: SIMD3<Float>(0.22, 0.40, -0.12) * tileSize, color: Palette.labStoneDark, roughness: 0.72, cornerRadius: tileSize * 0.02)
        tower.orientation = simd_quatf(angle: jitter(coordinate, salt: 301) * 0.05, axis: SIMD3<Float>(0, 0, 1))
        addBox(to: root, size: SIMD3<Float>(0.23, 0.055, 0.23) * tileSize, position: SIMD3<Float>(0.22, 0.735, -0.12) * tileSize, color: Palette.warmGold, roughness: 0.48, cornerRadius: tileSize * 0.007)
        addBox(to: root, size: SIMD3<Float>(0.15, 0.25, 0.15) * tileSize, position: SIMD3<Float>(0.22, 0.89, -0.12) * tileSize, color: Palette.glassGlow, roughness: 0.30, cornerRadius: tileSize * 0.018)

        addBox(to: root, size: SIMD3<Float>(0.08, 0.08, 0.46) * tileSize, position: SIMD3<Float>(-0.28, 0.42, -0.02) * tileSize, color: Palette.arcaneBlue, roughness: 0.38, cornerRadius: tileSize * 0.01)
        addBox(to: root, size: SIMD3<Float>(0.07, 0.32, 0.07) * tileSize, position: SIMD3<Float>(-0.27, 0.24, 0.24) * tileSize, color: Palette.glassGlow, roughness: 0.34, cornerRadius: tileSize * 0.012)
        addBox(to: root, size: SIMD3<Float>(0.10, 0.05, 0.10) * tileSize, position: SIMD3<Float>(-0.27, 0.43, 0.24) * tileSize, color: Palette.warmGold, roughness: 0.48, cornerRadius: tileSize * 0.005)
        for index in 0..<3 {
            let rod = addBox(to: root, size: SIMD3<Float>(0.035, 0.27 + Float(index) * 0.035, 0.035) * tileSize, position: SIMD3<Float>(-0.04 + Float(index) * 0.08, 0.20 + Float(index) * 0.035, -0.27) * tileSize, color: index.isMultiple(of: 2) ? Palette.arcaneBlue : Palette.glassGlow, roughness: 0.32, cornerRadius: tileSize * 0.006)
            rod.orientation = simd_quatf(angle: jitter(coordinate, salt: 302 + index) * 0.10, axis: SIMD3<Float>(0, 0, 1))
        }
        addDebris(to: root, tileSize: tileSize, coordinate: coordinate, count: 4, around: SIMD2<Float>(0.31, 0.26), radius: 0.14, color: Palette.warmGold)
        addLevelPips(level, to: root, tileSize: tileSize)
    }

    private static func addBarracks(level: Int, to root: Entity, tileSize: Float, coordinate: GridCoordinate) {
        addBox(to: root, size: SIMD3<Float>(0.56, 0.32, 0.42) * tileSize, position: SIMD3<Float>(-0.02, 0.22, 0.00) * tileSize, color: Palette.fortifiedClay, roughness: 0.88, cornerRadius: tileSize * 0.018)
        let roof = addBox(to: root, size: SIMD3<Float>(0.68, 0.12, 0.52) * tileSize, position: SIMD3<Float>(-0.03, 0.44, -0.01) * tileSize, color: Palette.slateRoof, roughness: 0.9, cornerRadius: tileSize * 0.014)
        roof.orientation = simd_quatf(angle: jitter(coordinate, salt: 321) * 0.05, axis: SIMD3<Float>(0, 0, 1))
        addBox(to: root, size: SIMD3<Float>(0.50, 0.045, 0.57) * tileSize, position: SIMD3<Float>(-0.05, 0.525, -0.01) * tileSize, color: Palette.roofHighlight, roughness: 0.88, cornerRadius: tileSize * 0.008)

        let corners = [SIMD3<Float>(-0.31, 0.27, -0.23), SIMD3<Float>(0.25, 0.25, -0.23), SIMD3<Float>(-0.30, 0.24, 0.22), SIMD3<Float>(0.24, 0.23, 0.21)]
        for (index, corner) in corners.enumerated() {
            addBox(to: root, size: SIMD3<Float>(0.095, 0.38 + Float(index % 2) * 0.045, 0.095) * tileSize, position: corner * tileSize, color: Palette.darkTimber, roughness: 0.92, cornerRadius: tileSize * 0.006)
        }

        addBanner(to: root, tileSize: tileSize, coordinate: coordinate, polePosition: SIMD3<Float>(-0.34, 0.48, -0.26), side: -1)
        addBanner(to: root, tileSize: tileSize, coordinate: coordinate, polePosition: SIMD3<Float>(0.28, 0.43, 0.25), side: 1)
        addBox(to: root, size: SIMD3<Float>(0.09, 0.19, 0.04) * tileSize, position: SIMD3<Float>(0.20, 0.25, 0.235) * tileSize, color: Palette.warmWindow, roughness: 0.48, cornerRadius: tileSize * 0.004)
        addBox(to: root, size: SIMD3<Float>(0.13, 0.16, 0.04) * tileSize, position: SIMD3<Float>(-0.10, 0.24, 0.235) * tileSize, color: Palette.doorWood, roughness: 0.84, cornerRadius: tileSize * 0.004)
        addWeaponRack(to: root, tileSize: tileSize, coordinate: coordinate, center: SIMD3<Float>(0.30, 0.13, -0.30))
        addTrainingProps(to: root, tileSize: tileSize, coordinate: coordinate)
        addLevelPips(level, to: root, tileSize: tileSize)
    }

    private static func addCanopyBlob(to root: Entity, tileSize: Float, radius: Float, position: SIMD3<Float>, scale: SIMD3<Float>, color: UIColor) {
        let blob = ModelEntity(
            mesh: .generateSphere(radius: tileSize * radius),
            materials: [material(color, roughness: 0.86)]
        )
        blob.position = position * tileSize
        blob.scale = scale
        root.addChild(blob)
    }

    private static func addGroundPatch(to root: Entity, tileSize: Float, center: SIMD2<Float>, size: SIMD2<Float>, color: UIColor, rotation: Float) {
        let patch = addBox(
            to: root,
            size: SIMD3<Float>(size.x, 0.010, size.y) * tileSize,
            position: SIMD3<Float>(center.x, 0.006, center.y) * tileSize,
            color: color,
            roughness: 0.98,
            cornerRadius: tileSize * 0.025
        )
        patch.orientation = simd_quatf(angle: rotation, axis: SIMD3<Float>(0, 1, 0))
    }

    private static func addGrassClumps(to root: Entity, tileSize: Float, coordinate: GridCoordinate, count: Int, around: SIMD2<Float>, radius: Float) {
        for index in 0..<count {
            let x = around.x + jitter(coordinate, salt: 401 + index * 3) * radius
            let z = around.y + jitter(coordinate, salt: 405 + index * 5) * radius
            guard abs(x) < 0.46, abs(z) < 0.46 else { continue }
            let bladeCount = 2 + stablePercent(coordinate, salt: 409 + index) % 2
            for blade in 0..<bladeCount {
                let bladeEntity = addBox(
                    to: root,
                    size: SIMD3<Float>(0.018, 0.055 + randomFloat(coordinate, salt: 412 + blade + index) * 0.035, 0.018) * tileSize,
                    position: SIMD3<Float>(x + Float(blade) * 0.018, 0.035, z + jitter(coordinate, salt: 417 + blade + index) * 0.018) * tileSize,
                    color: blade.isMultiple(of: 2) ? Palette.grassLight : Palette.grassShadow,
                    roughness: 0.96,
                    cornerRadius: tileSize * 0.003
                )
                bladeEntity.orientation = simd_quatf(angle: jitter(coordinate, salt: 421 + blade + index) * 0.28, axis: SIMD3<Float>(0, 0, 1))
            }
        }
    }

    private static func addRockCluster(to root: Entity, tileSize: Float, coordinate: GridCoordinate, center: SIMD2<Float>, radius: Float, count: Int, scale: Float) {
        for index in 0..<count {
            let x = center.x + jitter(coordinate, salt: 501 + index * 7) * radius
            let z = center.y + jitter(coordinate, salt: 507 + index * 9) * radius
            guard abs(x) < 0.47, abs(z) < 0.47 else { continue }
            let height = (0.045 + randomFloat(coordinate, salt: 513 + index) * 0.075) * scale
            let rock = addBox(
                to: root,
                size: SIMD3<Float>(height * 1.3, height, height * (1.0 + randomFloat(coordinate, salt: 519 + index) * 0.8)) * tileSize,
                position: SIMD3<Float>(x, 0.018 + height * 0.5, z) * tileSize,
                color: index.isMultiple(of: 3) ? Palette.paleStone : (index.isMultiple(of: 2) ? Palette.warmStone : Palette.deepStone),
                roughness: 0.96,
                cornerRadius: tileSize * 0.006
            )
            rock.orientation = simd_quatf(angle: randomAngle(coordinate, salt: 523 + index), axis: SIMD3<Float>(0, 1, 0))
        }
    }

    private static func addRockStrata(to root: Entity, tileSize: Float, coordinate: GridCoordinate) {
        for index in 0..<3 {
            let stratum = addBox(
                to: root,
                size: SIMD3<Float>(0.28 - Float(index) * 0.04, 0.020, 0.045) * tileSize,
                position: SIMD3<Float>(-0.05 + Float(index) * 0.08, 0.25 + Float(index) * 0.10, -0.20 + Float(index) * 0.05) * tileSize,
                color: index.isMultiple(of: 2) ? Palette.paleStone : Palette.deepStone,
                roughness: 0.92,
                cornerRadius: tileSize * 0.003
            )
            stratum.orientation = simd_quatf(angle: 0.22 + jitter(coordinate, salt: 531 + index) * 0.20, axis: SIMD3<Float>(0, 1, 0))
        }
    }

    private static func addRootCluster(to root: Entity, tileSize: Float, coordinate: GridCoordinate, center: SIMD2<Float>) {
        for index in 0..<4 {
            let rootPiece = addBox(
                to: root,
                size: SIMD3<Float>(0.15 + randomFloat(coordinate, salt: 541 + index) * 0.05, 0.025, 0.035) * tileSize,
                position: SIMD3<Float>(center.x + jitter(coordinate, salt: 545 + index) * 0.09, 0.027, center.y + jitter(coordinate, salt: 549 + index) * 0.09) * tileSize,
                color: Palette.bark,
                roughness: 0.9,
                cornerRadius: tileSize * 0.006
            )
            rootPiece.orientation = simd_quatf(angle: randomAngle(coordinate, salt: 553 + index), axis: SIMD3<Float>(0, 1, 0))
        }
    }

    private static func addDebris(to root: Entity, tileSize: Float, coordinate: GridCoordinate, count: Int, around: SIMD2<Float>, radius: Float, color: UIColor) {
        for index in 0..<count {
            let x = around.x + jitter(coordinate, salt: 601 + index * 5) * radius
            let z = around.y + jitter(coordinate, salt: 607 + index * 7) * radius
            guard abs(x) < 0.47, abs(z) < 0.47 else { continue }
            let piece = addBox(
                to: root,
                size: SIMD3<Float>(0.055 + randomFloat(coordinate, salt: 611 + index) * 0.045, 0.025, 0.030) * tileSize,
                position: SIMD3<Float>(x, 0.031, z) * tileSize,
                color: color,
                roughness: 0.92,
                cornerRadius: tileSize * 0.004
            )
            piece.orientation = simd_quatf(angle: randomAngle(coordinate, salt: 617 + index), axis: SIMD3<Float>(0, 1, 0))
        }
    }

    private static func addFence(to root: Entity, tileSize: Float, coordinate: GridCoordinate, start: SIMD2<Float>, count: Int, horizontal: Bool) {
        for index in 0..<count {
            let postPosition = horizontal
                ? SIMD3<Float>(start.x + Float(index) * 0.12, 0.095, start.y + jitter(coordinate, salt: 701 + index) * 0.012)
                : SIMD3<Float>(start.x + jitter(coordinate, salt: 701 + index) * 0.012, 0.095, start.y + Float(index) * 0.12)
            addBox(to: root, size: SIMD3<Float>(0.030, 0.16, 0.030) * tileSize, position: postPosition * tileSize, color: Palette.darkTimber, roughness: 0.92, cornerRadius: tileSize * 0.004)
        }

        let railLength = Float(max(count - 1, 1)) * 0.12 + 0.04
        let railSize = horizontal ? SIMD3<Float>(railLength, 0.026, 0.026) : SIMD3<Float>(0.026, 0.026, railLength)
        let railCenter = horizontal ? SIMD3<Float>(start.x + railLength * 0.5 - 0.02, 0.13, start.y) : SIMD3<Float>(start.x, 0.13, start.y + railLength * 0.5 - 0.02)
        let rail = addBox(to: root, size: railSize * tileSize, position: railCenter * tileSize, color: Palette.railWood, roughness: 0.92, cornerRadius: tileSize * 0.004)
        rail.orientation = simd_quatf(angle: jitter(coordinate, salt: 714) * 0.04, axis: SIMD3<Float>(0, 1, 0))
    }

    private static func addSupportBeam(to root: Entity, tileSize: Float, position: SIMD3<Float>, height: Float, salt: Int, coordinate: GridCoordinate) {
        let beam = addBox(
            to: root,
            size: SIMD3<Float>(0.055, height, 0.055) * tileSize,
            position: SIMD3<Float>(position.x, position.y, position.z) * tileSize,
            color: Palette.darkTimber,
            roughness: 0.92,
            cornerRadius: tileSize * 0.006
        )
        beam.orientation = simd_quatf(angle: jitter(coordinate, salt: salt) * 0.07, axis: SIMD3<Float>(0, 0, 1))
    }

    private static func addWoodPile(to root: Entity, tileSize: Float, coordinate: GridCoordinate, center: SIMD3<Float>, count: Int) {
        for index in 0..<count {
            let log = addBox(
                to: root,
                size: SIMD3<Float>(0.18 + randomFloat(coordinate, salt: 801 + index) * 0.07, 0.040, 0.045) * tileSize,
                position: SIMD3<Float>(center.x + jitter(coordinate, salt: 805 + index) * 0.05, center.y + Float(index % 2) * 0.045, center.z + Float(index) * 0.028) * tileSize,
                color: index.isMultiple(of: 2) ? Palette.cutWood : Palette.bark,
                roughness: 0.9,
                cornerRadius: tileSize * 0.010
            )
            log.orientation = simd_quatf(angle: 0.10 + jitter(coordinate, salt: 809 + index) * 0.18, axis: SIMD3<Float>(0, 1, 0))
        }
    }

    private static func addWheel(to root: Entity, tileSize: Float, center: SIMD3<Float>, coordinate: GridCoordinate) {
        addBox(to: root, size: SIMD3<Float>(0.055, 0.28, 0.045) * tileSize, position: center * tileSize, color: Palette.darkTimber, roughness: 0.92, cornerRadius: tileSize * 0.006)
        addBox(to: root, size: SIMD3<Float>(0.055, 0.045, 0.28) * tileSize, position: center * tileSize, color: Palette.darkTimber, roughness: 0.92, cornerRadius: tileSize * 0.006)
        let diagonalA = addBox(to: root, size: SIMD3<Float>(0.055, 0.22, 0.045) * tileSize, position: center * tileSize, color: Palette.cutWood, roughness: 0.9, cornerRadius: tileSize * 0.006)
        diagonalA.orientation = simd_quatf(angle: 0.74, axis: SIMD3<Float>(1, 0, 0))
        let diagonalB = addBox(to: root, size: SIMD3<Float>(0.055, 0.22, 0.045) * tileSize, position: center * tileSize, color: Palette.cutWood, roughness: 0.9, cornerRadius: tileSize * 0.006)
        diagonalB.orientation = simd_quatf(angle: -0.74, axis: SIMD3<Float>(1, 0, 0))
        addBox(to: root, size: SIMD3<Float>(0.075, 0.075, 0.075) * tileSize, position: center * tileSize, color: Palette.railWood, roughness: 0.88, cornerRadius: tileSize * 0.012)
    }

    private static func addBarrel(to root: Entity, tileSize: Float, position: SIMD3<Float>, salt: Int, coordinate: GridCoordinate) {
        let barrel = addBox(to: root, size: SIMD3<Float>(0.08, 0.12, 0.08) * tileSize, position: position * tileSize, color: Palette.barnWood, roughness: 0.86, cornerRadius: tileSize * 0.018)
        barrel.orientation = simd_quatf(angle: randomAngle(coordinate, salt: salt), axis: SIMD3<Float>(0, 1, 0))
        addBox(to: root, size: SIMD3<Float>(0.09, 0.014, 0.09) * tileSize, position: SIMD3<Float>(position.x, position.y + 0.065, position.z) * tileSize, color: Palette.darkTimber, roughness: 0.9, cornerRadius: tileSize * 0.004)
    }

    private static func addBanner(to root: Entity, tileSize: Float, coordinate: GridCoordinate, polePosition: SIMD3<Float>, side: Float) {
        addBox(to: root, size: SIMD3<Float>(0.045, 0.44, 0.045) * tileSize, position: polePosition * tileSize, color: Palette.darkTimber, roughness: 0.92, cornerRadius: tileSize * 0.005)
        let banner = addBox(to: root, size: SIMD3<Float>(0.21, 0.13, 0.035) * tileSize, position: SIMD3<Float>(polePosition.x + side * 0.10, polePosition.y + 0.12, polePosition.z) * tileSize, color: Palette.bannerRed, roughness: 0.78, cornerRadius: tileSize * 0.004)
        banner.orientation = simd_quatf(angle: jitter(coordinate, salt: 901 + Int(side)) * 0.07, axis: SIMD3<Float>(0, 0, 1))
        addBox(to: root, size: SIMD3<Float>(0.06, 0.06, 0.06) * tileSize, position: SIMD3<Float>(polePosition.x, polePosition.y + 0.24, polePosition.z) * tileSize, color: Palette.warmGold, roughness: 0.5, cornerRadius: tileSize * 0.01)
    }

    private static func addWeaponRack(to root: Entity, tileSize: Float, coordinate: GridCoordinate, center: SIMD3<Float>) {
        addBox(to: root, size: SIMD3<Float>(0.22, 0.035, 0.05) * tileSize, position: center * tileSize, color: Palette.darkTimber, roughness: 0.9, cornerRadius: tileSize * 0.004)
        for index in 0..<3 {
            let spear = addBox(to: root, size: SIMD3<Float>(0.024, 0.23, 0.024) * tileSize, position: SIMD3<Float>(center.x - 0.08 + Float(index) * 0.08, center.y + 0.105, center.z) * tileSize, color: Palette.railWood, roughness: 0.84, cornerRadius: tileSize * 0.003)
            spear.orientation = simd_quatf(angle: -0.14 + Float(index) * 0.10 + jitter(coordinate, salt: 931 + index) * 0.05, axis: SIMD3<Float>(0, 0, 1))
            addBox(to: root, size: SIMD3<Float>(0.04, 0.045, 0.02) * tileSize, position: SIMD3<Float>(center.x - 0.08 + Float(index) * 0.08, center.y + 0.235, center.z) * tileSize, color: Palette.paleStone, roughness: 0.74, cornerRadius: tileSize * 0.002)
        }
    }

    private static func addTrainingProps(to root: Entity, tileSize: Float, coordinate: GridCoordinate) {
        addBox(to: root, size: SIMD3<Float>(0.12, 0.13, 0.12) * tileSize, position: SIMD3<Float>(-0.32, 0.09, 0.23) * tileSize, color: Palette.strawRoof, roughness: 0.94, cornerRadius: tileSize * 0.016)
        let target = addBox(to: root, size: SIMD3<Float>(0.14, 0.14, 0.035) * tileSize, position: SIMD3<Float>(-0.32, 0.25, 0.23) * tileSize, color: Palette.bannerRed, roughness: 0.78, cornerRadius: tileSize * 0.020)
        target.orientation = simd_quatf(angle: jitter(coordinate, salt: 951) * 0.06, axis: SIMD3<Float>(0, 1, 0))
        addBox(to: root, size: SIMD3<Float>(0.07, 0.07, 0.040) * tileSize, position: SIMD3<Float>(-0.32, 0.25, 0.255) * tileSize, color: Palette.warmGold, roughness: 0.56, cornerRadius: tileSize * 0.014)
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

    private static func randomAngle(_ coordinate: GridCoordinate, salt: Int) -> Float {
        randomFloat(coordinate, salt: salt) * .pi * 2
    }

    private static func randomFloat(_ coordinate: GridCoordinate, salt: Int) -> Float {
        Float(stablePercent(coordinate, salt: salt)) / 99
    }

    private static func stablePercent(_ coordinate: GridCoordinate, salt: Int) -> Int {
        let raw = coordinate.x &* 73_856_093 ^ coordinate.y &* 19_349_663 ^ salt &* 83_492_791
        let positive = raw == Int.min ? 0 : abs(raw)
        return positive % 100
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
    static let rootSoil = UIColor(red: 0.29, green: 0.27, blue: 0.18, alpha: 1)
    static let warmStone = UIColor(red: 0.48, green: 0.47, blue: 0.41, alpha: 1)
    static let deepStone = UIColor(red: 0.34, green: 0.35, blue: 0.33, alpha: 1)
    static let paleStone = UIColor(red: 0.58, green: 0.56, blue: 0.49, alpha: 1)
    static let smokeStone = UIColor(red: 0.36, green: 0.34, blue: 0.30, alpha: 1)
    static let stoneDust = UIColor(red: 0.39, green: 0.39, blue: 0.34, alpha: 1)
    static let coalDust = UIColor(red: 0.18, green: 0.18, blue: 0.17, alpha: 1)
    static let coalChunk = UIColor(red: 0.10, green: 0.10, blue: 0.10, alpha: 1)
    static let walkedDirt = UIColor(red: 0.40, green: 0.32, blue: 0.22, alpha: 1)
    static let fieldDirt = UIColor(red: 0.34, green: 0.28, blue: 0.18, alpha: 1)
    static let plinthStone = UIColor(red: 0.42, green: 0.37, blue: 0.28, alpha: 1)
    static let plaster = UIColor(red: 0.70, green: 0.55, blue: 0.39, alpha: 1)
    static let terracotta = UIColor(red: 0.43, green: 0.20, blue: 0.16, alpha: 1)
    static let roofHighlight = UIColor(red: 0.55, green: 0.27, blue: 0.19, alpha: 1)
    static let sideShed = UIColor(red: 0.57, green: 0.42, blue: 0.28, alpha: 1)
    static let warmWindow = UIColor(red: 0.93, green: 0.70, blue: 0.36, alpha: 1)
    static let doorWood = UIColor(red: 0.28, green: 0.18, blue: 0.10, alpha: 1)
    static let cropGold = UIColor(red: 0.75, green: 0.64, blue: 0.30, alpha: 1)
    static let cropGreen = UIColor(red: 0.36, green: 0.49, blue: 0.24, alpha: 1)
    static let barnWood = UIColor(red: 0.52, green: 0.32, blue: 0.19, alpha: 1)
    static let strawRoof = UIColor(red: 0.70, green: 0.56, blue: 0.30, alpha: 1)
    static let timber = UIColor(red: 0.43, green: 0.29, blue: 0.17, alpha: 1)
    static let darkTimber = UIColor(red: 0.25, green: 0.17, blue: 0.10, alpha: 1)
    static let cutWood = UIColor(red: 0.59, green: 0.40, blue: 0.23, alpha: 1)
    static let sawPlatform = UIColor(red: 0.35, green: 0.24, blue: 0.15, alpha: 1)
    static let mineMouth = UIColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1)
    static let tunnelShadow = UIColor(red: 0.03, green: 0.03, blue: 0.03, alpha: 1)
    static let railWood = UIColor(red: 0.24, green: 0.20, blue: 0.16, alpha: 1)
    static let labStone = UIColor(red: 0.58, green: 0.64, blue: 0.64, alpha: 1)
    static let labStoneDark = UIColor(red: 0.42, green: 0.50, blue: 0.52, alpha: 1)
    static let glassGlow = UIColor(red: 0.66, green: 0.86, blue: 0.88, alpha: 1)
    static let arcaneBlue = UIColor(red: 0.24, green: 0.52, blue: 0.70, alpha: 1)
    static let warmGold = UIColor(red: 0.87, green: 0.67, blue: 0.34, alpha: 1)
    static let fortifiedClay = UIColor(red: 0.55, green: 0.34, blue: 0.29, alpha: 1)
    static let slateRoof = UIColor(red: 0.28, green: 0.31, blue: 0.29, alpha: 1)
    static let bannerRed = UIColor(red: 0.66, green: 0.22, blue: 0.17, alpha: 1)
    static let waterSheen = UIColor(red: 0.60, green: 0.78, blue: 0.86, alpha: 0.42)
}

private extension SIMD3 where Scalar == Float {
    static func * (lhs: SIMD3<Float>, rhs: Float) -> SIMD3<Float> {
        SIMD3<Float>(lhs.x * rhs, lhs.y * rhs, lhs.z * rhs)
    }

    static func + (lhs: SIMD3<Float>, rhs: SIMD3<Float>) -> SIMD3<Float> {
        SIMD3<Float>(lhs.x + rhs.x, lhs.y + rhs.y, lhs.z + rhs.z)
    }
}
