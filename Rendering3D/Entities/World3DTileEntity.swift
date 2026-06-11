import RealityKit
import UIKit

struct World3DTileEntity {
    private enum TemplateKind: Hashable {
        case tree
        case mountain
    }

    private struct TemplateKey: Hashable {
        let kind: TemplateKind
        let tileSizeBucket: Int
    }

    private static let placementOverlayName = "world3d_placement_overlay"
    private static var templateCache: [TemplateKey: Entity] = [:]

    static func makeTile(
        snapshot: World3DTileSnapshot,
        tileSize: Float,
        tileHeight: Float,
        material: SimpleMaterial
    ) -> Entity {
        let root = Entity()
        root.name = entityName(for: snapshot.coordinate)

        let baseHeight = tileHeight * heightMultiplier(for: snapshot.coordinate)
        let tile = World3DRenderResources.makeBox(
            size: SIMD3<Float>(tileSize, baseHeight, tileSize),
            material: material,
            cornerRadius: tileSize * 0.045
        )
        tile.name = root.name
        tile.position.y = -baseHeight / 2
        tile.components.set(CollisionComponent(shapes: [World3DRenderResources.collisionBox(size: SIMD3<Float>(tileSize, tileHeight * 2.4, tileSize))]))
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

    static func updatePlacementOverlay(_ state: TilePlacementState, on root: Entity, tileSize: Float) {
        root.children
            .filter { $0.name == placementOverlayName }
            .forEach { $0.removeFromParent() }
        addPlacementOverlay(state, to: root, tileSize: tileSize)
    }

    static func addTree(to root: Entity, tileSize: Float) {
        root.addChild(template(kind: .tree, tileSize: tileSize))
    }

    static func addDistantTree(to root: Entity, tileSize: Float) {
        addDistantForestMass(to: root, tileSize: tileSize, coordinate: GridCoordinate(x: 0, y: 0), edgeWeight: 0.72)
    }

    static func addDistantForestMass(to root: Entity, tileSize: Float, coordinate: GridCoordinate, edgeWeight: Float) {
        let heightScale: Float = 0.60
        addGroundPatch(
            to: root,
            tileSize: tileSize,
            center: SIMD2<Float>(jitter(coordinate, salt: 71) * 0.05, jitter(coordinate, salt: 72) * 0.04),
            size: SIMD2<Float>(0.62 + edgeWeight * 0.20, 0.48 + edgeWeight * 0.16),
            color: Palette.rootSoil,
            rotation: jitter(coordinate, salt: 73) * 0.42
        )

        let trunkCount = World3DRenderResources.visualQuality == .low ? 2 : 3
        for index in 0..<trunkCount {
            let x = -0.16 + Float(index) * 0.16 + jitter(coordinate, salt: 74 + index) * 0.045
            let height = (0.38 + randomFloat(coordinate, salt: 78 + index) * 0.20 + edgeWeight * 0.13) * heightScale
            let trunk = addBox(
                to: root,
                size: SIMD3<Float>(0.10, height, 0.10) * tileSize,
                position: SIMD3<Float>(x, height * 0.5, jitter(coordinate, salt: 82 + index) * 0.05) * tileSize,
                color: Palette.bark,
                roughness: 0.88,
                cornerRadius: tileSize * 0.006
            )
            trunk.orientation = simd_quatf(angle: jitter(coordinate, salt: 86 + index) * 0.10, axis: SIMD3<Float>(0, 0, 1))
        }

        let canopyCount: Int
        switch World3DRenderResources.visualQuality {
        case .low:
            canopyCount = 5
        case .medium:
            canopyCount = 6
        case .high:
            canopyCount = 7
        }

        for index in 0..<canopyCount {
            let layer = Float(index) / Float(max(canopyCount - 1, 1))
            let x = -0.32 + layer * 0.64 + jitter(coordinate, salt: 90 + index) * 0.09
            let z = jitter(coordinate, salt: 96 + index) * (0.10 + edgeWeight * 0.05)
            let y = (0.36 + (index.isMultiple(of: 2) ? 0.10 : 0.0) + randomFloat(coordinate, salt: 102 + index) * 0.22 + edgeWeight * 0.15) * heightScale
            let radius = 0.20 + randomFloat(coordinate, salt: 108 + index) * 0.085 + edgeWeight * 0.050
            addCanopyBlob(
                to: root,
                tileSize: tileSize,
                radius: radius,
                position: SIMD3<Float>(x, y, z),
                scale: SIMD3<Float>(1.48 + edgeWeight * 0.30, (0.64 + randomFloat(coordinate, salt: 112 + index) * 0.18) * heightScale, 1.12),
                color: forestMassColor(index: index, coordinate: coordinate)
            )
        }

        addBox(
            to: root,
            size: SIMD3<Float>(0.78 + edgeWeight * 0.22, 0.090, 0.22 + edgeWeight * 0.10) * tileSize,
            position: SIMD3<Float>(jitter(coordinate, salt: 118) * 0.04, 0.13 * heightScale, 0.02 + edgeWeight * 0.05) * tileSize,
            color: Palette.forestDeep,
            roughness: 0.94,
            cornerRadius: tileSize * 0.006
        )
    }

    static func addTree(to root: Entity, tileSize: Float, coordinate: GridCoordinate) {
        let lean = jitter(coordinate, salt: 91) * 0.12
        let heightScale = 0.92 + randomFloat(coordinate, salt: 92) * 0.18
        let canopyCount = detailCount(5 + stablePercent(coordinate, salt: 93) % 4, minimum: 3)
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
            let y = 0.36 + Float(index) * 0.055 + randomFloat(coordinate, salt: 109 + index) * 0.12
            let radius = 0.14 + randomFloat(coordinate, salt: 113 + index * 5) * 0.090
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

        for index in 0..<detailCount(3, minimum: 1) {
            let side: Float = index.isMultiple(of: 2) ? -1 : 1
            addCanopyBlob(
                to: root,
                tileSize: tileSize,
                radius: 0.13 + randomFloat(coordinate, salt: 128 + index) * 0.045,
                position: SIMD3<Float>(
                    trunkOffset.x + side * (0.12 + randomFloat(coordinate, salt: 129 + index) * 0.08),
                    (0.38 + Float(index) * 0.06) * heightScale,
                    trunkOffset.z + jitter(coordinate, salt: 130 + index) * 0.16
                ),
                scale: SIMD3<Float>(1.15, 0.62, 0.92),
                color: index == 1 ? Palette.leafHighlight : Palette.forestDeep
            )
        }

        for index in 0..<detailCount(2, minimum: 1) {
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
        addMushrooms(to: root, tileSize: tileSize, coordinate: coordinate, around: SIMD2<Float>(trunkOffset.x - 0.11, trunkOffset.z + 0.14))
        addLeafScatter(to: root, tileSize: tileSize, coordinate: coordinate, around: SIMD2<Float>(trunkOffset.x, trunkOffset.z))
    }

    static func addMountain(to root: Entity, tileSize: Float) {
        root.addChild(template(kind: .mountain, tileSize: tileSize))
    }

    static func addDistantMountain(to root: Entity, tileSize: Float) {
        addDistantMountainMass(to: root, tileSize: tileSize, coordinate: GridCoordinate(x: 0, y: 0), edgeWeight: 0.72)
    }

    static func addDistantMountainMass(to root: Entity, tileSize: Float, coordinate: GridCoordinate, edgeWeight: Float) {
        let heightScale: Float = 0.80
        addGroundPatch(
            to: root,
            tileSize: tileSize,
            center: SIMD2<Float>(jitter(coordinate, salt: 141) * 0.03, jitter(coordinate, salt: 142) * 0.04),
            size: SIMD2<Float>(0.82 + edgeWeight * 0.14, 0.72 + edgeWeight * 0.14),
            color: Palette.stoneDust,
            rotation: jitter(coordinate, salt: 143) * 0.28
        )

        let specs: [(SIMD3<Float>, SIMD3<Float>, UIColor, Int)] = [
            (SIMD3<Float>(-0.12, (0.44 + edgeWeight * 0.11) * heightScale, -0.05), SIMD3<Float>(0.48, (0.88 + edgeWeight * 0.20) * heightScale, 0.38), Palette.warmStone, 151),
            (SIMD3<Float>(0.22, (0.34 + edgeWeight * 0.08) * heightScale, 0.08), SIMD3<Float>(0.38, (0.66 + edgeWeight * 0.15) * heightScale, 0.32), Palette.deepStone, 157),
            (SIMD3<Float>(-0.34, 0.25 * heightScale, 0.10), SIMD3<Float>(0.32, 0.50 * heightScale, 0.28), Palette.paleStone, 163),
            (SIMD3<Float>(0.03, 0.21 * heightScale, -0.30), SIMD3<Float>(0.58, 0.30 * heightScale, 0.22), Palette.smokeStone, 169)
        ]
        let count = World3DRenderResources.visualQuality == .low ? 3 : specs.count
        for spec in specs.prefix(count) {
            let rock = addBox(
                to: root,
                size: SIMD3<Float>(
                    spec.1.x * (0.94 + randomFloat(coordinate, salt: spec.3) * 0.14),
                    spec.1.y * (0.94 + randomFloat(coordinate, salt: spec.3 + 1) * 0.16),
                    spec.1.z * (0.94 + randomFloat(coordinate, salt: spec.3 + 2) * 0.12)
                ) * tileSize,
                position: SIMD3<Float>(
                    spec.0.x + jitter(coordinate, salt: spec.3 + 3) * 0.035,
                    spec.0.y,
                    spec.0.z + jitter(coordinate, salt: spec.3 + 4) * 0.035
                ) * tileSize,
                color: spec.2,
                roughness: 0.96,
                cornerRadius: tileSize * 0.010
            )
            rock.orientation = simd_quatf(angle: jitter(coordinate, salt: spec.3 + 5) * 0.22, axis: SIMD3<Float>(0, 1, 0))
        }

        addBox(
            to: root,
            size: SIMD3<Float>(0.82 + edgeWeight * 0.24, 0.052, 0.080) * tileSize,
            position: SIMD3<Float>(0.02, (0.30 + edgeWeight * 0.09) * heightScale, -0.20) * tileSize,
            color: Palette.paleStone,
            roughness: 0.90,
            cornerRadius: tileSize * 0.003
        )
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

        addJaggedPeak(to: root, tileSize: tileSize, coordinate: coordinate, base: SIMD3<Float>(-0.06, 0.66, -0.04), salt: 171, color: Palette.paleStone)
        addJaggedPeak(to: root, tileSize: tileSize, coordinate: coordinate, base: SIMD3<Float>(0.18, 0.47, 0.08), salt: 177, color: Palette.smokeStone)
        addRockStrata(to: root, tileSize: tileSize, coordinate: coordinate)
        addMountainCracks(to: root, tileSize: tileSize, coordinate: coordinate)
        addRockCluster(to: root, tileSize: tileSize, coordinate: coordinate, center: SIMD2<Float>(0.18, -0.26), radius: 0.25, count: 6, scale: 0.95)
        addRockCluster(to: root, tileSize: tileSize, coordinate: coordinate, center: SIMD2<Float>(-0.24, 0.24), radius: 0.18, count: 4, scale: 0.78)
        addDebris(to: root, tileSize: tileSize, coordinate: coordinate, count: 5, around: SIMD2<Float>(0.03, 0.18), radius: 0.32, color: Palette.deepStone)
    }

    private static func template(kind: TemplateKind, tileSize: Float) -> Entity {
        let key = TemplateKey(kind: kind, tileSizeBucket: Int((tileSize * 10_000).rounded()))
        if let cached = templateCache[key] {
            return cached.clone(recursive: true)
        }

        let root = Entity()
        let coordinate = GridCoordinate(x: 0, y: 0)
        switch kind {
        case .tree:
            addTree(to: root, tileSize: tileSize, coordinate: coordinate)
        case .mountain:
            addMountain(to: root, tileSize: tileSize, coordinate: coordinate)
        }

        templateCache[key] = root
        return root.clone(recursive: true)
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
            color = UIColor(red: 0.93, green: 0.70, blue: 0.28, alpha: 0.52)
            height = 0.026
        case .invalid:
            color = UIColor(red: 0.25, green: 0.24, blue: 0.25, alpha: 0.58)
            height = 0.018
        }

        let overlay = World3DRenderResources.makeBox(
            size: SIMD3<Float>(tileSize * 0.82, height, tileSize * 0.82),
            material: material(color, roughness: 0.56),
            cornerRadius: tileSize * 0.04
        )
        overlay.name = placementOverlayName
        overlay.position.y = 0.052
        root.addChild(overlay)

        if state == .valid {
            let glint = World3DRenderResources.makeBox(
                size: SIMD3<Float>(tileSize * 0.62, 0.012, tileSize * 0.07),
                material: material(UIColor(red: 1.0, green: 0.84, blue: 0.34, alpha: 0.74), roughness: 0.30),
                cornerRadius: tileSize * 0.01
            )
            glint.name = placementOverlayName
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
        case .factory:
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
        addRoofSlats(to: root, tileSize: tileSize, coordinate: coordinate, center: SIMD3<Float>(-0.07, 0.575, -0.02) + bodyOffset, width: 0.54, depth: 0.48, count: 4, color: Palette.terracottaDark)
        addTimberFrame(to: root, tileSize: tileSize, center: SIMD3<Float>(-0.04, 0.25, 0.19) + bodyOffset, width: 0.40, height: 0.27, color: Palette.darkTimber)

        addBox(to: root, size: SIMD3<Float>(0.20, 0.22, 0.23) * tileSize, position: SIMD3<Float>(0.24, 0.16, 0.12) * tileSize, color: Palette.sideShed, roughness: 0.86, cornerRadius: tileSize * 0.018)
        let shedRoof = addBox(to: root, size: SIMD3<Float>(0.26, 0.07, 0.28) * tileSize, position: SIMD3<Float>(0.24, 0.30, 0.12) * tileSize, color: Palette.strawRoof, roughness: 0.92, cornerRadius: tileSize * 0.012)
        shedRoof.orientation = simd_quatf(angle: -0.11, axis: SIMD3<Float>(0, 0, 1))

        let chimney = addBox(to: root, size: SIMD3<Float>(0.085, 0.20, 0.085) * tileSize, position: SIMD3<Float>(0.14 + jitter(coordinate, salt: 224) * 0.05, 0.66, -0.12) * tileSize, color: Palette.smokeStone, roughness: 0.9, cornerRadius: tileSize * 0.01)
        chimney.orientation = simd_quatf(angle: jitter(coordinate, salt: 225) * 0.09, axis: SIMD3<Float>(0, 0, 1))
        addBox(to: root, size: SIMD3<Float>(0.12, 0.03, 0.11) * tileSize, position: SIMD3<Float>(chimney.position.x / tileSize, 0.775, chimney.position.z / tileSize) * tileSize, color: Palette.deepStone, roughness: 0.9, cornerRadius: tileSize * 0.005)

        addBox(to: root, size: SIMD3<Float>(0.12, 0.13, 0.035) * tileSize, position: SIMD3<Float>(-0.21, 0.25, 0.20) * tileSize, color: Palette.warmWindow, roughness: 0.42, cornerRadius: tileSize * 0.004)
        addShutters(to: root, tileSize: tileSize, center: SIMD3<Float>(-0.21, 0.25, 0.225))
        addBox(to: root, size: SIMD3<Float>(0.11, 0.15, 0.038) * tileSize, position: SIMD3<Float>(0.05, 0.23, 0.20) * tileSize, color: Palette.doorWood, roughness: 0.84, cornerRadius: tileSize * 0.004)
        addFence(to: root, tileSize: tileSize, coordinate: coordinate, start: SIMD2<Float>(-0.35, 0.29), count: 3, horizontal: true)
        addDebris(to: root, tileSize: tileSize, coordinate: coordinate, count: 4, around: SIMD2<Float>(0.29, -0.22), radius: 0.16, color: Palette.cutWood)
        addBarrel(to: root, tileSize: tileSize, position: SIMD3<Float>(-0.31, 0.08, -0.24), salt: 226, coordinate: coordinate)
        addCrate(to: root, tileSize: tileSize, position: SIMD3<Float>(0.31, 0.065, -0.12), coordinate: coordinate, salt: 227)
        addLantern(to: root, tileSize: tileSize, position: SIMD3<Float>(-0.01, 0.31, 0.225), coordinate: coordinate, salt: 228)
        addLevelPips(level, to: root, tileSize: tileSize)
    }

    private static func addFarm(level: Int, to root: Entity, tileSize: Float, coordinate: GridCoordinate) {
        addGroundPatch(to: root, tileSize: tileSize, center: SIMD2<Float>(-0.10, 0.06), size: SIMD2<Float>(0.58, 0.50), color: Palette.fieldDirt, rotation: jitter(coordinate, salt: 231) * 0.18)
        for index in 0..<6 {
            let z = -0.25 + Float(index) * 0.09 + jitter(coordinate, salt: 232 + index) * 0.015
            let row = addBox(to: root, size: SIMD3<Float>(0.48 + jitter(coordinate, salt: 238 + index) * 0.05, 0.035, 0.028) * tileSize, position: SIMD3<Float>(-0.12 + jitter(coordinate, salt: 244 + index) * 0.025, 0.075, z) * tileSize, color: index.isMultiple(of: 2) ? Palette.cropGold : Palette.cropGreen, roughness: 0.92, cornerRadius: tileSize * 0.006)
            row.orientation = simd_quatf(angle: jitter(coordinate, salt: 250 + index) * 0.05, axis: SIMD3<Float>(0, 1, 0))
            addBox(to: root, size: SIMD3<Float>(0.035, 0.065 + randomFloat(coordinate, salt: 255 + index) * 0.05, 0.035) * tileSize, position: SIMD3<Float>(0.10 + jitter(coordinate, salt: 260 + index) * 0.08, 0.105, z + 0.018) * tileSize, color: index.isMultiple(of: 2) ? Palette.cropGold : Palette.cropGreen, roughness: 0.94, cornerRadius: tileSize * 0.006)
        }
        addBox(to: root, size: SIMD3<Float>(0.23, 0.24, 0.20) * tileSize, position: SIMD3<Float>(0.23, 0.18, -0.23) * tileSize, color: Palette.barnWood, roughness: 0.86, cornerRadius: tileSize * 0.016)
        let roof = addBox(to: root, size: SIMD3<Float>(0.30, 0.09, 0.25) * tileSize, position: SIMD3<Float>(0.22, 0.335, -0.23) * tileSize, color: Palette.strawRoof, roughness: 0.92, cornerRadius: tileSize * 0.014)
        roof.orientation = simd_quatf(angle: -0.08, axis: SIMD3<Float>(0, 0, 1))
        addRoofSlats(to: root, tileSize: tileSize, coordinate: coordinate, center: SIMD3<Float>(0.22, 0.35, -0.23), width: 0.27, depth: 0.21, count: 3, color: Palette.strawShadow)
        addTimberFrame(to: root, tileSize: tileSize, center: SIMD3<Float>(0.23, 0.19, -0.125), width: 0.20, height: 0.20, color: Palette.darkTimber)
        addBox(to: root, size: SIMD3<Float>(0.12, 0.12, 0.035) * tileSize, position: SIMD3<Float>(0.23, 0.19, -0.12) * tileSize, color: Palette.doorWood, roughness: 0.84, cornerRadius: tileSize * 0.004)
        addFence(to: root, tileSize: tileSize, coordinate: coordinate, start: SIMD2<Float>(-0.39, -0.33), count: 5, horizontal: true)
        addFence(to: root, tileSize: tileSize, coordinate: coordinate, start: SIMD2<Float>(0.39, -0.24), count: 4, horizontal: false)
        addWoodPile(to: root, tileSize: tileSize, coordinate: coordinate, center: SIMD3<Float>(0.34, 0.07, 0.21), count: 3)
        addScarecrow(to: root, tileSize: tileSize, coordinate: coordinate, position: SIMD3<Float>(-0.34, 0.11, 0.20))
        addCart(to: root, tileSize: tileSize, coordinate: coordinate, center: SIMD3<Float>(0.33, 0.075, 0.03))
        addSack(to: root, tileSize: tileSize, position: SIMD3<Float>(0.05, 0.055, 0.31), coordinate: coordinate, salt: 271)
        addLevelPips(level, to: root, tileSize: tileSize)
    }

    private static func addWoodMill(level: Int, to root: Entity, tileSize: Float, coordinate: GridCoordinate) {
        addBox(to: root, size: SIMD3<Float>(0.42, 0.30, 0.34) * tileSize, position: SIMD3<Float>(-0.02, 0.20, -0.01) * tileSize, color: Palette.timber, roughness: 0.9, cornerRadius: tileSize * 0.02)
        let roof = addBox(to: root, size: SIMD3<Float>(0.50, 0.10, 0.40) * tileSize, position: SIMD3<Float>(-0.04, 0.405, -0.02) * tileSize, color: Palette.darkTimber, roughness: 0.92, cornerRadius: tileSize * 0.014)
        roof.orientation = simd_quatf(angle: 0.10 + jitter(coordinate, salt: 261) * 0.06, axis: SIMD3<Float>(0, 0, 1))
        addRoofSlats(to: root, tileSize: tileSize, coordinate: coordinate, center: SIMD3<Float>(-0.04, 0.43, -0.02), width: 0.48, depth: 0.36, count: 4, color: Palette.cutWood)
        addBox(to: root, size: SIMD3<Float>(0.25, 0.20, 0.24) * tileSize, position: SIMD3<Float>(0.24, 0.16, 0.03) * tileSize, color: Palette.timber, roughness: 0.9, cornerRadius: tileSize * 0.014)
        let leanRoof = addBox(to: root, size: SIMD3<Float>(0.30, 0.07, 0.28) * tileSize, position: SIMD3<Float>(0.25, 0.30, 0.03) * tileSize, color: Palette.darkTimber, roughness: 0.92, cornerRadius: tileSize * 0.010)
        leanRoof.orientation = simd_quatf(angle: -0.12, axis: SIMD3<Float>(0, 0, 1))

        for index in 0..<3 {
            addSupportBeam(to: root, tileSize: tileSize, position: SIMD3<Float>(-0.20 + Float(index) * 0.19, 0.20, 0.20), height: 0.31, salt: 262 + index, coordinate: coordinate)
            addBox(to: root, size: SIMD3<Float>(0.38, 0.042, 0.045) * tileSize, position: SIMD3<Float>(-0.02, 0.13 + Float(index) * 0.09, 0.205) * tileSize, color: Palette.darkTimber, roughness: 0.94, cornerRadius: tileSize * 0.006)
        }

        addBox(to: root, size: SIMD3<Float>(0.42, 0.06, 0.30) * tileSize, position: SIMD3<Float>(0.18, 0.09, -0.28) * tileSize, color: Palette.sawPlatform, roughness: 0.9, cornerRadius: tileSize * 0.01)
        addBox(to: root, size: SIMD3<Float>(0.32, 0.035, 0.05) * tileSize, position: SIMD3<Float>(0.20, 0.145, -0.28) * tileSize, color: Palette.paleStone, roughness: 0.86, cornerRadius: tileSize * 0.004)
        addBox(to: root, size: SIMD3<Float>(0.055, 0.15, 0.055) * tileSize, position: SIMD3<Float>(0.00, 0.19, -0.28) * tileSize, color: Palette.darkTimber, roughness: 0.92, cornerRadius: tileSize * 0.004)
        addSawBlade(to: root, tileSize: tileSize, coordinate: coordinate, center: SIMD3<Float>(0.08, 0.20, -0.28))

        addWheel(to: root, tileSize: tileSize, center: SIMD3<Float>(-0.30, 0.25, -0.05), coordinate: coordinate)
        addWoodPile(to: root, tileSize: tileSize, coordinate: coordinate, center: SIMD3<Float>(0.34, 0.07, 0.18), count: 5)
        addDebris(to: root, tileSize: tileSize, coordinate: coordinate, count: 5, around: SIMD2<Float>(-0.29, 0.27), radius: 0.16, color: Palette.cutWood)
        addCrate(to: root, tileSize: tileSize, position: SIMD3<Float>(-0.31, 0.06, 0.18), coordinate: coordinate, salt: 276)
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
        addLantern(to: root, tileSize: tileSize, position: SIMD3<Float>(0.02, 0.235, 0.34), coordinate: coordinate, salt: 284)
        addWinch(to: root, tileSize: tileSize, coordinate: coordinate, center: SIMD3<Float>(-0.28, 0.24, 0.20))

        addBox(to: root, size: SIMD3<Float>(0.48, 0.035, 0.045) * tileSize, position: SIMD3<Float>(0.02, 0.065, 0.36) * tileSize, color: Palette.railWood, roughness: 0.92, cornerRadius: tileSize * 0.004)
        addBox(to: root, size: SIMD3<Float>(0.48, 0.025, 0.018) * tileSize, position: SIMD3<Float>(0.02, 0.095, 0.315) * tileSize, color: Palette.deepStone, roughness: 0.88, cornerRadius: tileSize * 0.002)
        addBox(to: root, size: SIMD3<Float>(0.48, 0.025, 0.018) * tileSize, position: SIMD3<Float>(0.02, 0.095, 0.405) * tileSize, color: Palette.deepStone, roughness: 0.88, cornerRadius: tileSize * 0.002)
        addMineCart(to: root, tileSize: tileSize, coordinate: coordinate, center: SIMD3<Float>(0.25, 0.095, 0.36))
        addRockCluster(to: root, tileSize: tileSize, coordinate: coordinate, center: SIMD2<Float>(-0.30, -0.18), radius: 0.18, count: 5, scale: 0.82)
        addDebris(to: root, tileSize: tileSize, coordinate: coordinate, count: 6, around: SIMD2<Float>(0.23, 0.33), radius: 0.18, color: Palette.coalChunk)
        addPickaxe(to: root, tileSize: tileSize, coordinate: coordinate, center: SIMD3<Float>(-0.36, 0.10, 0.03))
        addLevelPips(level, to: root, tileSize: tileSize)
    }

    private static func addLab(level: Int, to root: Entity, tileSize: Float, coordinate: GridCoordinate) {
        addBox(to: root, size: SIMD3<Float>(0.38, 0.43, 0.34) * tileSize, position: SIMD3<Float>(-0.05, 0.265, 0.02) * tileSize, color: Palette.labStone, roughness: 0.76, cornerRadius: tileSize * 0.024)
        addBox(to: root, size: SIMD3<Float>(0.47, 0.045, 0.42) * tileSize, position: SIMD3<Float>(-0.04, 0.51, 0.02) * tileSize, color: Palette.warmGold, roughness: 0.52, cornerRadius: tileSize * 0.006)
        let tower = addBox(to: root, size: SIMD3<Float>(0.18, 0.62, 0.18) * tileSize, position: SIMD3<Float>(0.22, 0.40, -0.12) * tileSize, color: Palette.labStoneDark, roughness: 0.72, cornerRadius: tileSize * 0.02)
        tower.orientation = simd_quatf(angle: jitter(coordinate, salt: 301) * 0.05, axis: SIMD3<Float>(0, 0, 1))
        addBox(to: root, size: SIMD3<Float>(0.23, 0.055, 0.23) * tileSize, position: SIMD3<Float>(0.22, 0.735, -0.12) * tileSize, color: Palette.warmGold, roughness: 0.48, cornerRadius: tileSize * 0.007)
        addBox(to: root, size: SIMD3<Float>(0.15, 0.25, 0.15) * tileSize, position: SIMD3<Float>(0.22, 0.89, -0.12) * tileSize, color: Palette.glassGlow, roughness: 0.30, cornerRadius: tileSize * 0.018)
        addBox(to: root, size: SIMD3<Float>(0.10, 0.19, 0.10) * tileSize, position: SIMD3<Float>(-0.27, 0.63, 0.03) * tileSize, color: Palette.smokeStone, roughness: 0.88, cornerRadius: tileSize * 0.010)
        addBox(to: root, size: SIMD3<Float>(0.52, 0.09, 0.46) * tileSize, position: SIMD3<Float>(-0.05, 0.57, 0.02) * tileSize, color: Palette.slateRoof, roughness: 0.88, cornerRadius: tileSize * 0.012)
        addRoofSlats(to: root, tileSize: tileSize, coordinate: coordinate, center: SIMD3<Float>(-0.05, 0.59, 0.02), width: 0.48, depth: 0.40, count: 3, color: Palette.arcaneBlue)

        addBox(to: root, size: SIMD3<Float>(0.08, 0.08, 0.46) * tileSize, position: SIMD3<Float>(-0.28, 0.42, -0.02) * tileSize, color: Palette.arcaneBlue, roughness: 0.38, cornerRadius: tileSize * 0.01)
        addBox(to: root, size: SIMD3<Float>(0.07, 0.32, 0.07) * tileSize, position: SIMD3<Float>(-0.27, 0.24, 0.24) * tileSize, color: Palette.glassGlow, roughness: 0.34, cornerRadius: tileSize * 0.012)
        addBox(to: root, size: SIMD3<Float>(0.10, 0.05, 0.10) * tileSize, position: SIMD3<Float>(-0.27, 0.43, 0.24) * tileSize, color: Palette.warmGold, roughness: 0.48, cornerRadius: tileSize * 0.005)
        for index in 0..<3 {
            let rod = addBox(to: root, size: SIMD3<Float>(0.035, 0.27 + Float(index) * 0.035, 0.035) * tileSize, position: SIMD3<Float>(-0.04 + Float(index) * 0.08, 0.20 + Float(index) * 0.035, -0.27) * tileSize, color: index.isMultiple(of: 2) ? Palette.arcaneBlue : Palette.glassGlow, roughness: 0.32, cornerRadius: tileSize * 0.006)
            rod.orientation = simd_quatf(angle: jitter(coordinate, salt: 302 + index) * 0.10, axis: SIMD3<Float>(0, 0, 1))
        }
        addDebris(to: root, tileSize: tileSize, coordinate: coordinate, count: 4, around: SIMD2<Float>(0.31, 0.26), radius: 0.14, color: Palette.warmGold)
        addAlchemyProps(to: root, tileSize: tileSize, coordinate: coordinate)
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
        addBox(to: root, size: SIMD3<Float>(0.22, 0.10, 0.18) * tileSize, position: SIMD3<Float>(-0.31, 0.53, -0.23) * tileSize, color: Palette.darkTimber, roughness: 0.92, cornerRadius: tileSize * 0.006)
        addBox(to: root, size: SIMD3<Float>(0.27, 0.045, 0.22) * tileSize, position: SIMD3<Float>(-0.31, 0.61, -0.23) * tileSize, color: Palette.slateRoof, roughness: 0.9, cornerRadius: tileSize * 0.006)

        addBanner(to: root, tileSize: tileSize, coordinate: coordinate, polePosition: SIMD3<Float>(-0.34, 0.48, -0.26), side: -1)
        addBanner(to: root, tileSize: tileSize, coordinate: coordinate, polePosition: SIMD3<Float>(0.28, 0.43, 0.25), side: 1)
        addBox(to: root, size: SIMD3<Float>(0.09, 0.19, 0.04) * tileSize, position: SIMD3<Float>(0.20, 0.25, 0.235) * tileSize, color: Palette.warmWindow, roughness: 0.48, cornerRadius: tileSize * 0.004)
        addBox(to: root, size: SIMD3<Float>(0.13, 0.16, 0.04) * tileSize, position: SIMD3<Float>(-0.10, 0.24, 0.235) * tileSize, color: Palette.doorWood, roughness: 0.84, cornerRadius: tileSize * 0.004)
        addWeaponRack(to: root, tileSize: tileSize, coordinate: coordinate, center: SIMD3<Float>(0.30, 0.13, -0.30))
        addTrainingProps(to: root, tileSize: tileSize, coordinate: coordinate)
        addShieldRack(to: root, tileSize: tileSize, coordinate: coordinate, center: SIMD3<Float>(-0.33, 0.19, -0.03))
        addFirePit(to: root, tileSize: tileSize, coordinate: coordinate, center: SIMD3<Float>(0.32, 0.04, 0.09))
        addLevelPips(level, to: root, tileSize: tileSize)
    }

    private static func addCanopyBlob(to root: Entity, tileSize: Float, radius: Float, position: SIMD3<Float>, scale: SIMD3<Float>, color: UIColor) {
        let blob = World3DRenderResources.makeSphere(
            radius: tileSize * radius,
            material: material(color, roughness: 0.86),
            scale: scale
        )
        blob.position = position * tileSize
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
        for index in 0..<detailCount(count, minimum: 1) {
            let x = around.x + jitter(coordinate, salt: 401 + index * 3) * radius
            let z = around.y + jitter(coordinate, salt: 405 + index * 5) * radius
            guard abs(x) < 0.46, abs(z) < 0.46 else { continue }
            let bladeCount = detailCount(2 + stablePercent(coordinate, salt: 409 + index) % 2, minimum: 1)
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
        for index in 0..<detailCount(count, minimum: 1) {
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
        for index in 0..<detailCount(3, minimum: 1) {
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
        for index in 0..<detailCount(4, minimum: 1) {
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
        for index in 0..<detailCount(count, minimum: 1) {
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
        for index in 0..<detailCount(3, minimum: 1) {
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

    private static func addMushrooms(to root: Entity, tileSize: Float, coordinate: GridCoordinate, around: SIMD2<Float>) {
        for index in 0..<3 {
            let x = around.x + jitter(coordinate, salt: 961 + index) * 0.08
            let z = around.y + jitter(coordinate, salt: 967 + index) * 0.08
            guard abs(x) < 0.46, abs(z) < 0.46 else { continue }
            addBox(to: root, size: SIMD3<Float>(0.018, 0.045, 0.018) * tileSize, position: SIMD3<Float>(x, 0.034, z) * tileSize, color: Palette.plaster, roughness: 0.88, cornerRadius: tileSize * 0.004)
            addBox(to: root, size: SIMD3<Float>(0.045, 0.022, 0.045) * tileSize, position: SIMD3<Float>(x, 0.066, z) * tileSize, color: Palette.mushroomCap, roughness: 0.82, cornerRadius: tileSize * 0.010)
        }
    }

    private static func addLeafScatter(to root: Entity, tileSize: Float, coordinate: GridCoordinate, around: SIMD2<Float>) {
        for index in 0..<detailCount(5, minimum: 2) {
            let x = around.x + jitter(coordinate, salt: 971 + index) * 0.28
            let z = around.y + jitter(coordinate, salt: 977 + index) * 0.28
            guard abs(x) < 0.46, abs(z) < 0.46 else { continue }
            let leaf = addBox(to: root, size: SIMD3<Float>(0.040, 0.007, 0.022) * tileSize, position: SIMD3<Float>(x, 0.017, z) * tileSize, color: index.isMultiple(of: 2) ? Palette.leafHighlight : Palette.forestDeep, roughness: 0.95, cornerRadius: tileSize * 0.004)
            leaf.orientation = simd_quatf(angle: randomAngle(coordinate, salt: 981 + index), axis: SIMD3<Float>(0, 1, 0))
        }
    }

    private static func addJaggedPeak(to root: Entity, tileSize: Float, coordinate: GridCoordinate, base: SIMD3<Float>, salt: Int, color: UIColor) {
        for index in 0..<detailCount(3, minimum: 1) {
            let width = 0.17 - Float(index) * 0.035
            let height = 0.18 - Float(index) * 0.035
            let peak = addBox(
                to: root,
                size: SIMD3<Float>(width, height, width * 0.82) * tileSize,
                position: SIMD3<Float>(base.x + jitter(coordinate, salt: salt + index) * 0.025, base.y + Float(index) * 0.075, base.z + jitter(coordinate, salt: salt + 4 + index) * 0.025) * tileSize,
                color: index.isMultiple(of: 2) ? color : Palette.deepStone,
                roughness: 0.96,
                cornerRadius: tileSize * 0.010
            )
            peak.orientation = simd_quatf(angle: 0.26 + jitter(coordinate, salt: salt + 8 + index) * 0.16, axis: SIMD3<Float>(0, 0, 1)) * simd_quatf(angle: randomAngle(coordinate, salt: salt + 12 + index), axis: SIMD3<Float>(0, 1, 0))
        }
    }

    private static func addMountainCracks(to root: Entity, tileSize: Float, coordinate: GridCoordinate) {
        for index in 0..<detailCount(4, minimum: 1) {
            let crack = addBox(
                to: root,
                size: SIMD3<Float>(0.018, 0.16 - Float(index) * 0.018, 0.020) * tileSize,
                position: SIMD3<Float>(-0.18 + Float(index) * 0.12, 0.27 + Float(index % 2) * 0.12, 0.155 - Float(index) * 0.08) * tileSize,
                color: Palette.crackShadow,
                roughness: 0.98,
                cornerRadius: tileSize * 0.002
            )
            crack.orientation = simd_quatf(angle: -0.24 + jitter(coordinate, salt: 991 + index) * 0.28, axis: SIMD3<Float>(0, 0, 1)) * simd_quatf(angle: jitter(coordinate, salt: 995 + index) * 0.35, axis: SIMD3<Float>(0, 1, 0))
        }
    }

    private static func addRoofSlats(to root: Entity, tileSize: Float, coordinate: GridCoordinate, center: SIMD3<Float>, width: Float, depth: Float, count: Int, color: UIColor) {
        for index in 0..<detailCount(count, minimum: 1) {
            let z = center.z - depth * 0.42 + Float(index) * (depth / Float(max(count - 1, 1)))
            let slat = addBox(
                to: root,
                size: SIMD3<Float>(width - Float(index % 2) * 0.035, 0.018, 0.024) * tileSize,
                position: SIMD3<Float>(center.x + jitter(coordinate, salt: 1001 + index) * 0.018, center.y + Float(index % 2) * 0.006, z) * tileSize,
                color: color,
                roughness: 0.90,
                cornerRadius: tileSize * 0.004
            )
            slat.orientation = simd_quatf(angle: jitter(coordinate, salt: 1008 + index) * 0.06, axis: SIMD3<Float>(0, 1, 0))
        }
    }

    private static func addTimberFrame(to root: Entity, tileSize: Float, center: SIMD3<Float>, width: Float, height: Float, color: UIColor) {
        let z = center.z
        let postHeight = height
        addBox(to: root, size: SIMD3<Float>(0.026, postHeight, 0.026) * tileSize, position: SIMD3<Float>(center.x - width * 0.46, center.y, z) * tileSize, color: color, roughness: 0.92, cornerRadius: tileSize * 0.003)
        addBox(to: root, size: SIMD3<Float>(0.026, postHeight, 0.026) * tileSize, position: SIMD3<Float>(center.x + width * 0.46, center.y, z) * tileSize, color: color, roughness: 0.92, cornerRadius: tileSize * 0.003)
        addBox(to: root, size: SIMD3<Float>(width, 0.024, 0.026) * tileSize, position: SIMD3<Float>(center.x, center.y + height * 0.42, z) * tileSize, color: color, roughness: 0.92, cornerRadius: tileSize * 0.003)
        addBox(to: root, size: SIMD3<Float>(width * 0.78, 0.024, 0.026) * tileSize, position: SIMD3<Float>(center.x, center.y - height * 0.30, z) * tileSize, color: color, roughness: 0.92, cornerRadius: tileSize * 0.003)
        let diagonal = addBox(to: root, size: SIMD3<Float>(0.024, height * 0.72, 0.026) * tileSize, position: SIMD3<Float>(center.x, center.y + height * 0.02, z + 0.002) * tileSize, color: color, roughness: 0.92, cornerRadius: tileSize * 0.003)
        diagonal.orientation = simd_quatf(angle: 0.55, axis: SIMD3<Float>(0, 0, 1))
    }

    private static func addShutters(to root: Entity, tileSize: Float, center: SIMD3<Float>) {
        addBox(to: root, size: SIMD3<Float>(0.026, 0.14, 0.024) * tileSize, position: SIMD3<Float>(center.x - 0.078, center.y, center.z) * tileSize, color: Palette.darkTimber, roughness: 0.88, cornerRadius: tileSize * 0.003)
        addBox(to: root, size: SIMD3<Float>(0.026, 0.14, 0.024) * tileSize, position: SIMD3<Float>(center.x + 0.078, center.y, center.z) * tileSize, color: Palette.darkTimber, roughness: 0.88, cornerRadius: tileSize * 0.003)
    }

    private static func addLantern(to root: Entity, tileSize: Float, position: SIMD3<Float>, coordinate: GridCoordinate, salt: Int) {
        addBox(to: root, size: SIMD3<Float>(0.020, 0.070, 0.020) * tileSize, position: position * tileSize, color: Palette.darkTimber, roughness: 0.84, cornerRadius: tileSize * 0.003)
        let glow = addBox(to: root, size: SIMD3<Float>(0.055, 0.060, 0.042) * tileSize, position: SIMD3<Float>(position.x, position.y - 0.055, position.z) * tileSize, color: Palette.lanternGlow, roughness: 0.36, cornerRadius: tileSize * 0.010)
        glow.orientation = simd_quatf(angle: jitter(coordinate, salt: salt) * 0.12, axis: SIMD3<Float>(0, 1, 0))
    }

    private static func addCrate(to root: Entity, tileSize: Float, position: SIMD3<Float>, coordinate: GridCoordinate, salt: Int) {
        let crate = addBox(to: root, size: SIMD3<Float>(0.105, 0.095, 0.105) * tileSize, position: position * tileSize, color: Palette.cutWood, roughness: 0.90, cornerRadius: tileSize * 0.008)
        crate.orientation = simd_quatf(angle: randomAngle(coordinate, salt: salt), axis: SIMD3<Float>(0, 1, 0))
        addBox(to: root, size: SIMD3<Float>(0.118, 0.018, 0.018) * tileSize, position: SIMD3<Float>(position.x, position.y + 0.008, position.z) * tileSize, color: Palette.darkTimber, roughness: 0.92, cornerRadius: tileSize * 0.002)
    }

    private static func addSack(to root: Entity, tileSize: Float, position: SIMD3<Float>, coordinate: GridCoordinate, salt: Int) {
        let sack = addBox(to: root, size: SIMD3<Float>(0.11, 0.09, 0.095) * tileSize, position: position * tileSize, color: Palette.sackCloth, roughness: 0.95, cornerRadius: tileSize * 0.020)
        sack.orientation = simd_quatf(angle: randomAngle(coordinate, salt: salt), axis: SIMD3<Float>(0, 1, 0))
        addBox(to: root, size: SIMD3<Float>(0.055, 0.018, 0.055) * tileSize, position: SIMD3<Float>(position.x, position.y + 0.055, position.z) * tileSize, color: Palette.railWood, roughness: 0.9, cornerRadius: tileSize * 0.004)
    }

    private static func addScarecrow(to root: Entity, tileSize: Float, coordinate: GridCoordinate, position: SIMD3<Float>) {
        addBox(to: root, size: SIMD3<Float>(0.026, 0.25, 0.026) * tileSize, position: position * tileSize, color: Palette.railWood, roughness: 0.90, cornerRadius: tileSize * 0.003)
        let arm = addBox(to: root, size: SIMD3<Float>(0.20, 0.024, 0.024) * tileSize, position: SIMD3<Float>(position.x, position.y + 0.08, position.z) * tileSize, color: Palette.railWood, roughness: 0.90, cornerRadius: tileSize * 0.003)
        arm.orientation = simd_quatf(angle: jitter(coordinate, salt: 1021) * 0.08, axis: SIMD3<Float>(0, 0, 1))
        addBox(to: root, size: SIMD3<Float>(0.085, 0.07, 0.030) * tileSize, position: SIMD3<Float>(position.x, position.y + 0.105, position.z + 0.010) * tileSize, color: Palette.bannerRed, roughness: 0.82, cornerRadius: tileSize * 0.004)
        addBox(to: root, size: SIMD3<Float>(0.095, 0.026, 0.070) * tileSize, position: SIMD3<Float>(position.x, position.y + 0.165, position.z) * tileSize, color: Palette.strawRoof, roughness: 0.94, cornerRadius: tileSize * 0.006)
    }

    private static func addCart(to root: Entity, tileSize: Float, coordinate: GridCoordinate, center: SIMD3<Float>) {
        let tray = addBox(to: root, size: SIMD3<Float>(0.20, 0.070, 0.13) * tileSize, position: center * tileSize, color: Palette.barnWood, roughness: 0.88, cornerRadius: tileSize * 0.008)
        tray.orientation = simd_quatf(angle: jitter(coordinate, salt: 1031) * 0.18, axis: SIMD3<Float>(0, 1, 0))
        addBox(to: root, size: SIMD3<Float>(0.035, 0.060, 0.035) * tileSize, position: SIMD3<Float>(center.x - 0.085, center.y - 0.020, center.z + 0.075) * tileSize, color: Palette.darkTimber, roughness: 0.90, cornerRadius: tileSize * 0.010)
        addBox(to: root, size: SIMD3<Float>(0.035, 0.060, 0.035) * tileSize, position: SIMD3<Float>(center.x + 0.085, center.y - 0.020, center.z + 0.075) * tileSize, color: Palette.darkTimber, roughness: 0.90, cornerRadius: tileSize * 0.010)
    }

    private static func addSawBlade(to root: Entity, tileSize: Float, coordinate: GridCoordinate, center: SIMD3<Float>) {
        for index in 0..<4 {
            let tooth = addBox(to: root, size: SIMD3<Float>(0.028, 0.16, 0.018) * tileSize, position: center * tileSize, color: Palette.paleStone, roughness: 0.70, cornerRadius: tileSize * 0.002)
            tooth.orientation = simd_quatf(angle: Float(index) * .pi / 4 + jitter(coordinate, salt: 1041) * 0.08, axis: SIMD3<Float>(0, 0, 1))
        }
        addBox(to: root, size: SIMD3<Float>(0.050, 0.050, 0.026) * tileSize, position: center * tileSize, color: Palette.warmGold, roughness: 0.56, cornerRadius: tileSize * 0.010)
    }

    private static func addWinch(to root: Entity, tileSize: Float, coordinate: GridCoordinate, center: SIMD3<Float>) {
        addSupportBeam(to: root, tileSize: tileSize, position: SIMD3<Float>(center.x - 0.07, center.y, center.z), height: 0.22, salt: 1051, coordinate: coordinate)
        addSupportBeam(to: root, tileSize: tileSize, position: SIMD3<Float>(center.x + 0.07, center.y, center.z), height: 0.22, salt: 1052, coordinate: coordinate)
        addBox(to: root, size: SIMD3<Float>(0.19, 0.040, 0.040) * tileSize, position: SIMD3<Float>(center.x, center.y + 0.10, center.z) * tileSize, color: Palette.railWood, roughness: 0.90, cornerRadius: tileSize * 0.006)
        addBox(to: root, size: SIMD3<Float>(0.050, 0.090, 0.050) * tileSize, position: SIMD3<Float>(center.x, center.y + 0.10, center.z) * tileSize, color: Palette.coalChunk, roughness: 0.82, cornerRadius: tileSize * 0.008)
    }

    private static func addMineCart(to root: Entity, tileSize: Float, coordinate: GridCoordinate, center: SIMD3<Float>) {
        let cart = addBox(to: root, size: SIMD3<Float>(0.22, 0.10, 0.14) * tileSize, position: center * tileSize, color: Palette.deepStone, roughness: 0.80, cornerRadius: tileSize * 0.010)
        cart.orientation = simd_quatf(angle: jitter(coordinate, salt: 1061) * 0.08, axis: SIMD3<Float>(0, 1, 0))
        addBox(to: root, size: SIMD3<Float>(0.18, 0.045, 0.10) * tileSize, position: SIMD3<Float>(center.x, center.y + 0.07, center.z) * tileSize, color: Palette.coalChunk, roughness: 0.70, cornerRadius: tileSize * 0.012)
        addBox(to: root, size: SIMD3<Float>(0.040, 0.045, 0.035) * tileSize, position: SIMD3<Float>(center.x - 0.07, center.y - 0.06, center.z + 0.06) * tileSize, color: Palette.railWood, roughness: 0.86, cornerRadius: tileSize * 0.009)
        addBox(to: root, size: SIMD3<Float>(0.040, 0.045, 0.035) * tileSize, position: SIMD3<Float>(center.x + 0.07, center.y - 0.06, center.z + 0.06) * tileSize, color: Palette.railWood, roughness: 0.86, cornerRadius: tileSize * 0.009)
    }

    private static func addPickaxe(to root: Entity, tileSize: Float, coordinate: GridCoordinate, center: SIMD3<Float>) {
        let handle = addBox(to: root, size: SIMD3<Float>(0.026, 0.22, 0.026) * tileSize, position: center * tileSize, color: Palette.railWood, roughness: 0.88, cornerRadius: tileSize * 0.003)
        handle.orientation = simd_quatf(angle: -0.62 + jitter(coordinate, salt: 1071) * 0.10, axis: SIMD3<Float>(0, 0, 1))
        let head = addBox(to: root, size: SIMD3<Float>(0.16, 0.028, 0.020) * tileSize, position: SIMD3<Float>(center.x + 0.055, center.y + 0.085, center.z) * tileSize, color: Palette.paleStone, roughness: 0.76, cornerRadius: tileSize * 0.003)
        head.orientation = handle.orientation
    }

    private static func addAlchemyProps(to root: Entity, tileSize: Float, coordinate: GridCoordinate) {
        addBox(to: root, size: SIMD3<Float>(0.16, 0.07, 0.16) * tileSize, position: SIMD3<Float>(0.30, 0.075, 0.10) * tileSize, color: Palette.cauldron, roughness: 0.78, cornerRadius: tileSize * 0.020)
        addBox(to: root, size: SIMD3<Float>(0.10, 0.035, 0.10) * tileSize, position: SIMD3<Float>(0.30, 0.13, 0.10) * tileSize, color: Palette.glassGlow, roughness: 0.30, cornerRadius: tileSize * 0.016)
        for index in 0..<3 {
            let bottle = addBox(to: root, size: SIMD3<Float>(0.040, 0.075, 0.040) * tileSize, position: SIMD3<Float>(-0.32 + Float(index) * 0.055, 0.075, -0.28) * tileSize, color: index.isMultiple(of: 2) ? Palette.arcaneBlue : Palette.potionPurple, roughness: 0.34, cornerRadius: tileSize * 0.010)
            bottle.orientation = simd_quatf(angle: jitter(coordinate, salt: 1081 + index) * 0.10, axis: SIMD3<Float>(0, 1, 0))
        }
    }

    private static func addShieldRack(to root: Entity, tileSize: Float, coordinate: GridCoordinate, center: SIMD3<Float>) {
        addBox(to: root, size: SIMD3<Float>(0.025, 0.24, 0.030) * tileSize, position: center * tileSize, color: Palette.darkTimber, roughness: 0.92, cornerRadius: tileSize * 0.003)
        for index in 0..<2 {
            let shield = addBox(to: root, size: SIMD3<Float>(0.075, 0.095, 0.025) * tileSize, position: SIMD3<Float>(center.x + Float(index) * 0.075, center.y + 0.04, center.z) * tileSize, color: index.isMultiple(of: 2) ? Palette.bannerRed : Palette.warmGold, roughness: 0.70, cornerRadius: tileSize * 0.014)
            shield.orientation = simd_quatf(angle: jitter(coordinate, salt: 1091 + index) * 0.08, axis: SIMD3<Float>(0, 1, 0))
        }
    }

    private static func addFirePit(to root: Entity, tileSize: Float, coordinate: GridCoordinate, center: SIMD3<Float>) {
        addRockCluster(to: root, tileSize: tileSize, coordinate: coordinate, center: SIMD2<Float>(center.x, center.z), radius: 0.055, count: 5, scale: 0.35)
        addBox(to: root, size: SIMD3<Float>(0.060, 0.080, 0.040) * tileSize, position: SIMD3<Float>(center.x, center.y + 0.06, center.z) * tileSize, color: Palette.lanternGlow, roughness: 0.38, cornerRadius: tileSize * 0.010)
        let flame = addBox(to: root, size: SIMD3<Float>(0.035, 0.11, 0.035) * tileSize, position: SIMD3<Float>(center.x, center.y + 0.10, center.z) * tileSize, color: Palette.bannerRed, roughness: 0.58, cornerRadius: tileSize * 0.008)
        flame.orientation = simd_quatf(angle: 0.32 + jitter(coordinate, salt: 1101) * 0.08, axis: SIMD3<Float>(0, 0, 1))
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
        let box = World3DRenderResources.makeBox(
            size: size,
            material: material(color, roughness: roughness),
            cornerRadius: cornerRadius
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
        World3DRenderResources.material(color, roughness: roughness, metallic: metallic)
    }

    private static func forestMassColor(index: Int, coordinate: GridCoordinate) -> UIColor {
        if index.isMultiple(of: 3) {
            return Palette.forestDeep
        }
        return stablePercent(coordinate, salt: 122 + index) < 48 ? Palette.forestMoss : Palette.leafHighlight
    }

    private static func detailCount(_ count: Int, minimum: Int) -> Int {
        let scaled = Int((Float(count) * World3DRenderResources.visualQuality.microDetailMultiplier).rounded())
        return min(count, max(minimum, scaled))
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
    static let grassLight = UIColor(red: 0.42, green: 0.52, blue: 0.29, alpha: 1)
    static let grassShadow = UIColor(red: 0.22, green: 0.35, blue: 0.25, alpha: 1)
    static let forestMoss = UIColor(red: 0.14, green: 0.31, blue: 0.23, alpha: 1)
    static let forestDeep = UIColor(red: 0.08, green: 0.21, blue: 0.18, alpha: 1)
    static let leafHighlight = UIColor(red: 0.29, green: 0.42, blue: 0.20, alpha: 1)
    static let bark = UIColor(red: 0.30, green: 0.21, blue: 0.15, alpha: 1)
    static let rootSoil = UIColor(red: 0.27, green: 0.26, blue: 0.20, alpha: 1)
    static let warmStone = UIColor(red: 0.52, green: 0.49, blue: 0.41, alpha: 1)
    static let deepStone = UIColor(red: 0.30, green: 0.34, blue: 0.36, alpha: 1)
    static let paleStone = UIColor(red: 0.61, green: 0.57, blue: 0.48, alpha: 1)
    static let smokeStone = UIColor(red: 0.34, green: 0.36, blue: 0.36, alpha: 1)
    static let stoneDust = UIColor(red: 0.39, green: 0.40, blue: 0.37, alpha: 1)
    static let coalDust = UIColor(red: 0.16, green: 0.17, blue: 0.18, alpha: 1)
    static let coalChunk = UIColor(red: 0.08, green: 0.09, blue: 0.10, alpha: 1)
    static let walkedDirt = UIColor(red: 0.39, green: 0.32, blue: 0.24, alpha: 1)
    static let fieldDirt = UIColor(red: 0.33, green: 0.28, blue: 0.20, alpha: 1)
    static let plinthStone = UIColor(red: 0.40, green: 0.37, blue: 0.31, alpha: 1)
    static let plaster = UIColor(red: 0.69, green: 0.55, blue: 0.41, alpha: 1)
    static let terracotta = UIColor(red: 0.48, green: 0.22, blue: 0.16, alpha: 1)
    static let terracottaDark = UIColor(red: 0.34, green: 0.14, blue: 0.11, alpha: 1)
    static let roofHighlight = UIColor(red: 0.59, green: 0.31, blue: 0.21, alpha: 1)
    static let sideShed = UIColor(red: 0.55, green: 0.42, blue: 0.30, alpha: 1)
    static let warmWindow = UIColor(red: 0.98, green: 0.64, blue: 0.25, alpha: 1)
    static let doorWood = UIColor(red: 0.27, green: 0.18, blue: 0.12, alpha: 1)
    static let cropGold = UIColor(red: 0.70, green: 0.61, blue: 0.31, alpha: 1)
    static let cropGreen = UIColor(red: 0.35, green: 0.48, blue: 0.26, alpha: 1)
    static let barnWood = UIColor(red: 0.49, green: 0.31, blue: 0.21, alpha: 1)
    static let strawRoof = UIColor(red: 0.68, green: 0.56, blue: 0.34, alpha: 1)
    static let strawShadow = UIColor(red: 0.50, green: 0.42, blue: 0.25, alpha: 1)
    static let timber = UIColor(red: 0.40, green: 0.29, blue: 0.19, alpha: 1)
    static let darkTimber = UIColor(red: 0.23, green: 0.17, blue: 0.12, alpha: 1)
    static let cutWood = UIColor(red: 0.55, green: 0.39, blue: 0.25, alpha: 1)
    static let sawPlatform = UIColor(red: 0.32, green: 0.24, blue: 0.17, alpha: 1)
    static let mineMouth = UIColor(red: 0.07, green: 0.08, blue: 0.09, alpha: 1)
    static let tunnelShadow = UIColor(red: 0.025, green: 0.030, blue: 0.035, alpha: 1)
    static let railWood = UIColor(red: 0.23, green: 0.20, blue: 0.17, alpha: 1)
    static let labStone = UIColor(red: 0.48, green: 0.58, blue: 0.55, alpha: 1)
    static let labStoneDark = UIColor(red: 0.32, green: 0.43, blue: 0.43, alpha: 1)
    static let glassGlow = UIColor(red: 0.45, green: 0.72, blue: 0.70, alpha: 1)
    static let arcaneBlue = UIColor(red: 0.20, green: 0.45, blue: 0.50, alpha: 1)
    static let warmGold = UIColor(red: 0.74, green: 0.59, blue: 0.31, alpha: 1)
    static let fortifiedClay = UIColor(red: 0.53, green: 0.34, blue: 0.30, alpha: 1)
    static let slateRoof = UIColor(red: 0.27, green: 0.31, blue: 0.32, alpha: 1)
    static let bannerRed = UIColor(red: 0.62, green: 0.22, blue: 0.18, alpha: 1)
    static let waterSheen = UIColor(red: 0.48, green: 0.68, blue: 0.69, alpha: 0.40)
    static let mushroomCap = UIColor(red: 0.68, green: 0.27, blue: 0.22, alpha: 1)
    static let crackShadow = UIColor(red: 0.16, green: 0.18, blue: 0.18, alpha: 1)
    static let lanternGlow = UIColor(red: 1.0, green: 0.58, blue: 0.20, alpha: 1)
    static let sackCloth = UIColor(red: 0.60, green: 0.49, blue: 0.34, alpha: 1)
    static let cauldron = UIColor(red: 0.18, green: 0.24, blue: 0.23, alpha: 1)
    static let potionPurple = UIColor(red: 0.43, green: 0.35, blue: 0.60, alpha: 1)
}

private extension SIMD3 where Scalar == Float {
    static func * (lhs: SIMD3<Float>, rhs: Float) -> SIMD3<Float> {
        SIMD3<Float>(lhs.x * rhs, lhs.y * rhs, lhs.z * rhs)
    }

    static func + (lhs: SIMD3<Float>, rhs: SIMD3<Float>) -> SIMD3<Float> {
        SIMD3<Float>(lhs.x + rhs.x, lhs.y + rhs.y, lhs.z + rhs.z)
    }
}
