import RealityKit
import AppKit

struct World3DTileEntity {
    private enum TemplateKind: Hashable {
        case tree
        case mountain
    }

    private struct TemplateKey: Hashable {
        let kind: TemplateKind
        let tileSizeBucket: Int
        let theme: WorldTheme
    }

    private static var templateCache: [TemplateKey: Entity] = [:]

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

    static func addTree(to root: Entity, tileSize: Float) {
        root.addChild(template(kind: .tree, tileSize: tileSize))
    }

    static func addTree(to root: Entity, tileSize: Float, coordinate: GridCoordinate) {
        let trunkOffset = SIMD3<Float>(jitter(coordinate, salt: 94) * 0.035, 0, jitter(coordinate, salt: 95) * 0.035)

        addGroundPatch(
            to: root,
            tileSize: tileSize,
            center: SIMD2<Float>(trunkOffset.x, trunkOffset.z),
            size: SIMD2<Float>(0.36, 0.30),
            color: Palette.rootSoil,
            rotation: jitter(coordinate, salt: 96) * 0.45
        )

        switch WorldTheme.current {
        case .village:
            addBroadleafTree(to: root, tileSize: tileSize, coordinate: coordinate, trunkOffset: trunkOffset)
        case .desert:
            addPalmTree(to: root, tileSize: tileSize, coordinate: coordinate, trunkOffset: trunkOffset)
        case .forest:
            addConiferTree(to: root, tileSize: tileSize, coordinate: coordinate, trunkOffset: trunkOffset, snowCapped: false)
        case .mountains:
            addConiferTree(to: root, tileSize: tileSize, coordinate: coordinate, trunkOffset: trunkOffset, snowCapped: true)
        }

        addRockCluster(to: root, tileSize: tileSize, coordinate: coordinate, center: SIMD2<Float>(-0.18, 0.22), radius: 0.13, count: 3, scale: 0.72)
        addGrassClumps(to: root, tileSize: tileSize, coordinate: coordinate, count: 5, around: SIMD2<Float>(trunkOffset.x, trunkOffset.z), radius: 0.38)
        addThemeGroundDecor(to: root, tileSize: tileSize, coordinate: coordinate, around: SIMD2<Float>(trunkOffset.x - 0.11, trunkOffset.z + 0.14))
        addLeafScatter(to: root, tileSize: tileSize, coordinate: coordinate, around: SIMD2<Float>(trunkOffset.x, trunkOffset.z))
    }

    private static func addBroadleafTree(to root: Entity, tileSize: Float, coordinate: GridCoordinate, trunkOffset: SIMD3<Float>) {
        let lean = jitter(coordinate, salt: 91) * 0.12
        let heightScale = 0.92 + randomFloat(coordinate, salt: 92) * 0.18
        let canopyCount = detailCount(5 + stablePercent(coordinate, salt: 93) % 4, minimum: 3)

        let trunk = addCylinder(
            to: root,
            radius: 0.062 * tileSize,
            height: 0.46 * heightScale * tileSize,
            position: SIMD3<Float>(trunkOffset.x, 0.23 * heightScale, trunkOffset.z) * tileSize,
            color: Palette.bark,
            roughness: 0.88
        )
        trunk.orientation = simd_quatf(angle: lean, axis: SIMD3<Float>(0, 0, 1)) * simd_quatf(angle: -lean * 0.55, axis: SIMD3<Float>(1, 0, 0))

        addRootCluster(to: root, tileSize: tileSize, coordinate: coordinate, center: SIMD2<Float>(trunkOffset.x, trunkOffset.z))

        for index in 0..<canopyCount {
            let x = trunkOffset.x + jitter(coordinate, salt: 101 + index * 11) * 0.13
            let z = trunkOffset.z + jitter(coordinate, salt: 107 + index * 13) * 0.12
            let y = 0.36 + Float(index) * 0.055 + randomFloat(coordinate, salt: 109 + index) * 0.12
            let radius = 0.17 + randomFloat(coordinate, salt: 113 + index * 5) * 0.10
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
                radius: 0.155 + randomFloat(coordinate, salt: 128 + index) * 0.05,
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
    }

    private static func addConiferTree(to root: Entity, tileSize: Float, coordinate: GridCoordinate, trunkOffset: SIMD3<Float>, snowCapped: Bool) {
        let heightScale = 0.90 + randomFloat(coordinate, salt: 92) * 0.24
        let lean = jitter(coordinate, salt: 91) * 0.06

        let trunk = addCylinder(
            to: root,
            radius: 0.048 * tileSize,
            height: 0.26 * heightScale * tileSize,
            position: SIMD3<Float>(trunkOffset.x, 0.13 * heightScale, trunkOffset.z) * tileSize,
            color: Palette.bark,
            roughness: 0.90
        )
        trunk.orientation = simd_quatf(angle: lean, axis: SIMD3<Float>(0, 0, 1))

        addRootCluster(to: root, tileSize: tileSize, coordinate: coordinate, center: SIMD2<Float>(trunkOffset.x, trunkOffset.z))

        let tiers: [(radius: Float, height: Float, centerY: Float)] = [
            (0.26, 0.30, 0.30),
            (0.20, 0.26, 0.47),
            (0.14, 0.24, 0.63)
        ]
        for (index, tier) in tiers.enumerated() {
            let wobble = SIMD3<Float>(
                jitter(coordinate, salt: 101 + index * 7) * 0.022,
                0,
                jitter(coordinate, salt: 105 + index * 9) * 0.022
            )
            addCone(
                to: root,
                radius: tier.radius * (0.94 + randomFloat(coordinate, salt: 111 + index) * 0.14) * tileSize,
                height: tier.height * heightScale * tileSize,
                position: (SIMD3<Float>(trunkOffset.x, tier.centerY * heightScale, trunkOffset.z) + wobble) * tileSize,
                color: index.isMultiple(of: 2) ? Palette.forestMoss : Palette.forestDeep,
                roughness: 0.90
            )
        }

        if snowCapped {
            addCone(
                to: root,
                radius: 0.085 * tileSize,
                height: 0.17 * heightScale * tileSize,
                position: SIMD3<Float>(trunkOffset.x, 0.755 * heightScale, trunkOffset.z) * tileSize,
                color: Palette.peakCap,
                roughness: 0.82
            )
        } else {
            addCone(
                to: root,
                radius: 0.080 * tileSize,
                height: 0.18 * heightScale * tileSize,
                position: SIMD3<Float>(trunkOffset.x, 0.755 * heightScale, trunkOffset.z) * tileSize,
                color: Palette.leafHighlight,
                roughness: 0.90
            )
        }
    }

    private static func addPalmTree(to root: Entity, tileSize: Float, coordinate: GridCoordinate, trunkOffset: SIMD3<Float>) {
        let heightScale = 0.92 + randomFloat(coordinate, salt: 92) * 0.20
        let leanX = jitter(coordinate, salt: 91) * 0.06 + 0.045

        let lower = addCylinder(
            to: root,
            radius: 0.042 * tileSize,
            height: 0.30 * heightScale * tileSize,
            position: SIMD3<Float>(trunkOffset.x, 0.15 * heightScale, trunkOffset.z) * tileSize,
            color: Palette.bark,
            roughness: 0.92
        )
        lower.orientation = simd_quatf(angle: -leanX * 1.6, axis: SIMD3<Float>(0, 0, 1))
        let upper = addCylinder(
            to: root,
            radius: 0.035 * tileSize,
            height: 0.26 * heightScale * tileSize,
            position: SIMD3<Float>(trunkOffset.x + leanX, 0.41 * heightScale, trunkOffset.z) * tileSize,
            color: Palette.bark,
            roughness: 0.92
        )
        upper.orientation = simd_quatf(angle: -leanX * 2.6, axis: SIMD3<Float>(0, 0, 1))

        let crown = SIMD3<Float>(trunkOffset.x + leanX * 1.7, 0.55 * heightScale, trunkOffset.z)
        let frondCount = detailCount(6, minimum: 4)
        for index in 0..<frondCount {
            let yaw = Float(index) / Float(frondCount) * .pi * 2 + jitter(coordinate, salt: 121 + index) * 0.25
            let reach: Float = 0.095
            let frond = addBox(
                to: root,
                size: SIMD3<Float>(0.24, 0.018, 0.075) * tileSize,
                position: (crown + SIMD3<Float>(cos(yaw) * reach, 0.015, sin(yaw) * reach)) * tileSize,
                color: index.isMultiple(of: 2) ? Palette.frond : Palette.forestMoss,
                roughness: 0.90,
                cornerRadius: tileSize * 0.010
            )
            frond.orientation = simd_quatf(angle: -yaw, axis: SIMD3<Float>(0, 1, 0)) * simd_quatf(angle: -0.42, axis: SIMD3<Float>(0, 0, 1))
        }

        for index in 0..<2 {
            let coconut = World3DRenderResources.makeSphere(
                radius: 0.026 * tileSize,
                material: material(Palette.doorWood, roughness: 0.88)
            )
            coconut.position = (crown + SIMD3<Float>(jitter(coordinate, salt: 131 + index) * 0.04, -0.028, jitter(coordinate, salt: 134 + index) * 0.04)) * tileSize
            root.addChild(coconut)
        }

        addCactus(to: root, tileSize: tileSize, coordinate: coordinate, position: SIMD2<Float>(-0.26, 0.20), salt: 141)
    }

    private static func addCactus(to root: Entity, tileSize: Float, coordinate: GridCoordinate, position: SIMD2<Float>, salt: Int) {
        let height = (0.12 + randomFloat(coordinate, salt: salt) * 0.06)
        addCylinder(
            to: root,
            radius: 0.030 * tileSize,
            height: height * tileSize,
            position: SIMD3<Float>(position.x, height * 0.5 + 0.01, position.y) * tileSize,
            color: Palette.cactus,
            roughness: 0.86
        )
        let armSide: Float = jitter(coordinate, salt: salt + 1) > 0 ? 1 : -1
        addBox(
            to: root,
            size: SIMD3<Float>(0.045, 0.020, 0.020) * tileSize,
            position: SIMD3<Float>(position.x + armSide * 0.035, height * 0.55, position.y) * tileSize,
            color: Palette.cactus,
            roughness: 0.86,
            cornerRadius: tileSize * 0.006
        )
        addCylinder(
            to: root,
            radius: 0.017 * tileSize,
            height: 0.065 * tileSize,
            position: SIMD3<Float>(position.x + armSide * 0.055, height * 0.55 + 0.030, position.y) * tileSize,
            color: Palette.cactus,
            roughness: 0.86
        )
    }

    static func addMountain(to root: Entity, tileSize: Float) {
        root.addChild(template(kind: .mountain, tileSize: tileSize))
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

        // Peaks are cones: (x, z, base radius, height, color, salt, capped)
        let peakSpecs: [(Float, Float, Float, Float, NSColor, Int, Bool)] = [
            (-0.04, -0.04, 0.295, 0.74, Palette.warmStone, 153, true),
            (0.18, 0.08, 0.220, 0.52, Palette.deepStone, 157, true),
            (-0.23, 0.10, 0.170, 0.38, Palette.paleStone, 161, false),
            (0.04, -0.24, 0.190, 0.30, Palette.smokeStone, 167, false)
        ]

        for spec in peakSpecs {
            let x = spec.0 + jitter(coordinate, salt: spec.5) * 0.030
            let z = spec.1 + jitter(coordinate, salt: spec.5 + 1) * 0.030
            let radius = spec.2 * (0.92 + randomFloat(coordinate, salt: spec.5 + 2) * 0.16)
            let height = spec.3 * (0.92 + randomFloat(coordinate, salt: spec.5 + 3) * 0.18)
            addCone(
                to: root,
                radius: radius * tileSize,
                height: height * tileSize,
                position: SIMD3<Float>(x, height * 0.5, z) * tileSize,
                color: spec.4,
                roughness: 0.95
            )

            if spec.6 {
                // Cap covers the top ~28% of the peak; radius matches the cone at that height.
                let capHeight = height * 0.28
                let capRadius = radius * 0.28 * 1.12
                addCone(
                    to: root,
                    radius: capRadius * tileSize,
                    height: capHeight * tileSize,
                    position: SIMD3<Float>(x, height - capHeight * 0.5 + 0.004, z) * tileSize,
                    color: Palette.peakCap,
                    roughness: 0.82
                )
            }
        }

        addRockCluster(to: root, tileSize: tileSize, coordinate: coordinate, center: SIMD2<Float>(0.18, -0.26), radius: 0.25, count: 6, scale: 0.95)
        addRockCluster(to: root, tileSize: tileSize, coordinate: coordinate, center: SIMD2<Float>(-0.24, 0.24), radius: 0.18, count: 4, scale: 0.78)
        addDebris(to: root, tileSize: tileSize, coordinate: coordinate, count: 5, around: SIMD2<Float>(0.03, 0.18), radius: 0.32, color: Palette.deepStone)
    }

    private static func template(kind: TemplateKind, tileSize: Float) -> Entity {
        let key = TemplateKey(kind: kind, tileSizeBucket: Int((tileSize * 10_000).rounded()), theme: WorldTheme.current)
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
        let patchColor: NSColor
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

    // Gentle autoreversing loop used by ambient details (smoke, animals,
    // boats). GPU-side, so no per-frame CPU work.
    private static func addAmbientDrift(to entity: Entity, offset: SIMD3<Float>, scaleTo: Float = 1, duration: TimeInterval) {
        var to = entity.transform
        to.translation += offset
        to.scale *= SIMD3<Float>(repeating: scaleTo)
        let animation = FromToByAnimation<Transform>(
            from: entity.transform,
            to: to,
            duration: duration,
            timing: .easeInOut,
            bindTarget: .transform,
            repeatMode: .autoReverse
        )
        if let resource = try? AnimationResource.generate(with: animation) {
            entity.playAnimation(resource.repeat())
        }
    }

    // Two soft translucent puffs rising above a chimney (tile units).
    private static func addChimneySmoke(to root: Entity, tileSize: Float, above top: SIMD3<Float>) {
        for index in 0..<2 {
            let puff = World3DRenderResources.makeSphere(
                radius: (0.024 + Float(index) * 0.011) * tileSize,
                material: material(NSColor(red: 0.93, green: 0.93, blue: 0.95, alpha: 0.34 - CGFloat(index) * 0.08), roughness: 1.0)
            )
            puff.position = (top + SIMD3<Float>(Float(index) * 0.022, 0.035 + Float(index) * 0.065, 0)) * tileSize
            root.addChild(puff)
            addAmbientDrift(
                to: puff,
                offset: SIMD3<Float>(0.014, 0.055, 0.010) * tileSize,
                scaleTo: 1.35,
                duration: 2.6 + Double(index) * 1.1
            )
        }
    }

    // A grazing sheep slowly wandering back and forth (tile units).
    private static func addSheep(to root: Entity, tileSize: Float, at spot: SIMD2<Float>, wander: SIMD2<Float>, duration: TimeInterval, yaw: Float) {
        let sheep = Entity()
        addBox(
            to: sheep,
            size: SIMD3<Float>(0.070, 0.052, 0.098) * tileSize,
            position: SIMD3<Float>(0, 0.045, 0) * tileSize,
            color: NSColor(red: 0.93, green: 0.91, blue: 0.85, alpha: 1),
            roughness: 0.95,
            cornerRadius: tileSize * 0.02
        )
        addBox(
            to: sheep,
            size: SIMD3<Float>(0.034, 0.034, 0.040) * tileSize,
            position: SIMD3<Float>(0, 0.052, 0.060) * tileSize,
            color: Palette.darkTimber,
            roughness: 0.92,
            cornerRadius: tileSize * 0.008
        )
        sheep.position = SIMD3<Float>(spot.x, 0.012, spot.y) * tileSize
        sheep.orientation = simd_quatf(angle: yaw, axis: SIMD3<Float>(0, 1, 0))
        root.addChild(sheep)
        addAmbientDrift(to: sheep, offset: SIMD3<Float>(wander.x, 0, wander.y) * tileSize, duration: duration)
    }

    private static func addBuilding(_ kind: BuildingKind, level: Int, to root: Entity, tileSize: Float, coordinate: GridCoordinate, gridSize: GridSize) {
        // Handcrafted Blender models (Assets/building_*.usdz) are the primary
        // visuals; the procedural builders below stay as a fallback so a
        // missing or broken asset can never leave an empty tile.
        if let crafted = makeCraftedBuilding(kind, tileSize: tileSize, coordinate: coordinate, gridSize: gridSize) {
            if kind != .pier {
                addGroundPatch(
                    to: root,
                    tileSize: tileSize,
                    center: SIMD2<Float>(jitter(coordinate, salt: 211) * 0.02, jitter(coordinate, salt: 212) * 0.02),
                    size: SIMD2<Float>(0.82, 0.76),
                    color: Palette.walkedDirt,
                    rotation: jitter(coordinate, salt: 213) * 0.35
                )
            }
            root.addChild(crafted)
            addLevelPips(level, to: root, tileSize: tileSize)
            return
        }

        // The pier is shoreline furniture, not a plinth building: it lays its
        // own boardwalk instead of the stone platform.
        guard kind != .pier else {
            addPier(level: level, to: root, tileSize: tileSize, coordinate: coordinate, gridSize: gridSize)
            return
        }

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
        case .pier:
            break
        case .farm:
            addFarm(level: level, to: root, tileSize: tileSize, coordinate: coordinate)
        case .factory:
            addFactory(level: level, to: root, tileSize: tileSize, coordinate: coordinate)
        case .barracks:
            addBarracks(level: level, to: root, tileSize: tileSize, coordinate: coordinate)
        }

        addGrassClumps(to: root, tileSize: tileSize, coordinate: coordinate, count: 3, around: SIMD2<Float>(0, 0), radius: 0.43)
    }

    private static func makeCraftedBuilding(_ kind: BuildingKind, tileSize: Float, coordinate: GridCoordinate, gridSize: GridSize) -> Entity? {
        guard let building = try? Entity.load(named: "building_\(kind.rawValue)") else { return nil }
        building.scale = SIMD3<Float>(repeating: tileSize * 0.7)
        applyCraftedPalette(to: building)
        playCraftedAnimations(in: building)
        if kind == .pier {
            let yaw = shorelineYaw(for: coordinate, gridSize: gridSize)
            building.orientation = simd_quatf(angle: yaw, axis: SIMD3<Float>(0, 1, 0))
            building.position = SIMD3<Float>(sin(yaw), 0, cos(yaw)) * (tileSize * 0.5)
        }
        return building
    }

    private static func applyCraftedPalette(to building: Entity) {
        func recolor(_ entity: Entity, inheritedColor: NSColor) {
            let color = craftedColor(for: entity.name, fallback: inheritedColor)
            if var model = entity.components[ModelComponent.self] {
                model.materials = model.materials.map { _ in material(color, roughness: 0.88) }
                entity.components.set(model)
            }
            entity.children.forEach { recolor($0, inheritedColor: color) }
        }

        recolor(building, inheritedColor: Palette.plaster)
    }

    private static func craftedColor(for name: String, fallback: NSColor) -> NSColor {
        let name = name.lowercased()
        if name.contains("glow") || name.contains("lantern") || name.contains("gold") { return Palette.warmGold }
        if name.contains("straw") || name.contains("hay") { return Palette.strawRoof }
        if name.contains("slate") || name.contains("vault") || name.contains("keep_roof") { return Palette.slateRoof }
        if name.contains("terracotta") || name.contains("dusty") || name.contains("roof") || name.contains("shutter") { return Palette.terracotta }
        if name.contains("teal") || name.contains("workshop") { return Palette.labStone }
        if name.contains("fortified") || name.contains("keep") { return Palette.fortifiedClay }
        if name.contains("crop") || name.contains("field") || name.contains("plant") || name.contains("sage") { return Palette.cropGreen }
        if name.contains("timber") || name.contains("wood") || name.contains("plank") || name.contains("barrel") || name.contains("crate") || name.contains("rail") { return Palette.timber }
        if name.contains("stone") || name.contains("plinth") || name.contains("step") || name.contains("wall") { return Palette.plinthStone }
        if name.contains("plaster") || name.contains("cream") { return Palette.plaster }
        return fallback
    }

    private static func playCraftedAnimations(in entity: Entity) {
        entity.availableAnimations.forEach { entity.playAnimation($0.repeat()) }
        entity.children.forEach { playCraftedAnimations(in: $0) }
    }

    private static func addHouse(level: Int, to root: Entity, tileSize: Float, coordinate: GridCoordinate) {
        let bodyOffset = SIMD3<Float>(jitter(coordinate, salt: 221) * 0.025, 0, jitter(coordinate, salt: 222) * 0.02)
        addBox(to: root, size: SIMD3<Float>(0.46, 0.34, 0.40) * tileSize, position: (SIMD3<Float>(-0.04, 0.22, -0.01) + bodyOffset) * tileSize, color: Palette.plaster, roughness: 0.82, cornerRadius: tileSize * 0.05)
        // Oversized roof with a deep overhang — the silhouette carries the charm.
        let roof = addBox(to: root, size: SIMD3<Float>(0.70, 0.21, 0.60) * tileSize, position: (SIMD3<Float>(-0.055, 0.50, -0.01) + bodyOffset) * tileSize, color: Palette.terracotta, roughness: 0.88, cornerRadius: tileSize * 0.07)
        roof.orientation = simd_quatf(angle: 0.10 + jitter(coordinate, salt: 223) * 0.06, axis: SIMD3<Float>(0, 0, 1))
        let cap = addBox(to: root, size: SIMD3<Float>(0.58, 0.065, 0.66) * tileSize, position: (SIMD3<Float>(-0.08, 0.615, -0.02) + bodyOffset) * tileSize, color: Palette.roofHighlight, roughness: 0.88, cornerRadius: tileSize * 0.03)
        cap.orientation = roof.orientation
        addRidgeBeam(to: root, tileSize: tileSize, center: SIMD3<Float>(-0.08, 0.66, -0.02) + bodyOffset, length: 0.58, color: Palette.terracottaDark, orientation: roof.orientation)
        addEaveStrips(to: root, tileSize: tileSize, center: SIMD3<Float>(-0.055, 0.415, -0.01) + bodyOffset, width: 0.68, depth: 0.58, orientation: roof.orientation)
        addBox(to: root, size: SIMD3<Float>(0.50, 0.055, 0.44) * tileSize, position: (SIMD3<Float>(-0.04, 0.062, -0.01) + bodyOffset) * tileSize, color: Palette.plinthStone, roughness: 0.94, cornerRadius: tileSize * 0.02)
        addTimberFrame(to: root, tileSize: tileSize, center: SIMD3<Float>(-0.04, 0.25, 0.20) + bodyOffset, width: 0.42, height: 0.27, color: Palette.darkTimber)

        addBox(to: root, size: SIMD3<Float>(0.21, 0.22, 0.24) * tileSize, position: SIMD3<Float>(0.25, 0.16, 0.12) * tileSize, color: Palette.sideShed, roughness: 0.86, cornerRadius: tileSize * 0.035)
        let shedRoof = addBox(to: root, size: SIMD3<Float>(0.29, 0.085, 0.32) * tileSize, position: SIMD3<Float>(0.25, 0.305, 0.12) * tileSize, color: Palette.strawRoof, roughness: 0.92, cornerRadius: tileSize * 0.035)
        shedRoof.orientation = simd_quatf(angle: -0.11, axis: SIMD3<Float>(0, 0, 1))

        let chimney = addBox(to: root, size: SIMD3<Float>(0.10, 0.22, 0.10) * tileSize, position: SIMD3<Float>(0.14 + jitter(coordinate, salt: 224) * 0.05, 0.68, -0.12) * tileSize, color: Palette.smokeStone, roughness: 0.9, cornerRadius: tileSize * 0.02)
        chimney.orientation = simd_quatf(angle: jitter(coordinate, salt: 225) * 0.09, axis: SIMD3<Float>(0, 0, 1))
        addBox(to: root, size: SIMD3<Float>(0.13, 0.035, 0.13) * tileSize, position: SIMD3<Float>(chimney.position.x / tileSize, 0.805, chimney.position.z / tileSize) * tileSize, color: Palette.deepStone, roughness: 0.9, cornerRadius: tileSize * 0.01)
        addChimneySmoke(to: root, tileSize: tileSize, above: SIMD3<Float>(chimney.position.x / tileSize, 0.83, chimney.position.z / tileSize))

        addBox(to: root, size: SIMD3<Float>(0.14, 0.15, 0.035) * tileSize, position: SIMD3<Float>(-0.21, 0.26, 0.21) * tileSize, color: Palette.warmWindow, roughness: 0.42, cornerRadius: tileSize * 0.012)
        addShutters(to: root, tileSize: tileSize, center: SIMD3<Float>(-0.21, 0.26, 0.235))
        addBox(to: root, size: SIMD3<Float>(0.13, 0.18, 0.038) * tileSize, position: SIMD3<Float>(0.05, 0.225, 0.21) * tileSize, color: Palette.doorWood, roughness: 0.84, cornerRadius: tileSize * 0.014)
        addDoorFrame(to: root, tileSize: tileSize, center: SIMD3<Float>(0.05, 0.225, 0.217), width: 0.13, height: 0.18)
        addEntryStep(to: root, tileSize: tileSize, center: SIMD3<Float>(0.05, 0.030, 0.27), width: 0.16)
        addWindowFrame(to: root, tileSize: tileSize, center: SIMD3<Float>(-0.10, 0.27, -0.205) + bodyOffset, width: 0.10, height: 0.11)
        addWindowFrame(to: root, tileSize: tileSize, center: SIMD3<Float>(-0.26, 0.27, -0.06) + bodyOffset, width: 0.10, height: 0.10, sideways: true)
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
        addBox(to: root, size: SIMD3<Float>(0.28, 0.05, 0.25) * tileSize, position: SIMD3<Float>(0.23, 0.045, -0.23) * tileSize, color: Palette.plinthStone, roughness: 0.94, cornerRadius: tileSize * 0.02)
        addBox(to: root, size: SIMD3<Float>(0.25, 0.24, 0.22) * tileSize, position: SIMD3<Float>(0.23, 0.18, -0.23) * tileSize, color: Palette.barnWood, roughness: 0.86, cornerRadius: tileSize * 0.04)
        for corner in [SIMD2<Float>(0.125, -0.325), SIMD2<Float>(0.335, -0.325), SIMD2<Float>(0.125, -0.135), SIMD2<Float>(0.335, -0.135)] {
            addBox(to: root, size: SIMD3<Float>(0.028, 0.24, 0.028) * tileSize, position: SIMD3<Float>(corner.x, 0.18, corner.y) * tileSize, color: Palette.darkTimber, roughness: 0.92, cornerRadius: tileSize * 0.003)
        }
        let roof = addBox(to: root, size: SIMD3<Float>(0.37, 0.11, 0.31) * tileSize, position: SIMD3<Float>(0.22, 0.345, -0.23) * tileSize, color: Palette.strawRoof, roughness: 0.92, cornerRadius: tileSize * 0.05)
        roof.orientation = simd_quatf(angle: -0.08, axis: SIMD3<Float>(0, 0, 1))
        addRidgeBeam(to: root, tileSize: tileSize, center: SIMD3<Float>(0.22, 0.412, -0.23), length: 0.30, color: Palette.strawShadow, orientation: roof.orientation)
        addEaveStrips(to: root, tileSize: tileSize, center: SIMD3<Float>(0.22, 0.295, -0.23), width: 0.36, depth: 0.30, orientation: roof.orientation)
        addTimberFrame(to: root, tileSize: tileSize, center: SIMD3<Float>(0.23, 0.19, -0.115), width: 0.20, height: 0.20, color: Palette.darkTimber)
        addBox(to: root, size: SIMD3<Float>(0.14, 0.14, 0.035) * tileSize, position: SIMD3<Float>(0.23, 0.19, -0.11) * tileSize, color: Palette.doorWood, roughness: 0.84, cornerRadius: tileSize * 0.012)
        addDoorFrame(to: root, tileSize: tileSize, center: SIMD3<Float>(0.23, 0.19, -0.103), width: 0.14, height: 0.14)
        addEntryStep(to: root, tileSize: tileSize, center: SIMD3<Float>(0.23, 0.028, -0.055), width: 0.16)
        addWindowFrame(to: root, tileSize: tileSize, center: SIMD3<Float>(0.35, 0.21, -0.28), width: 0.08, height: 0.08, sideways: true)
        addFence(to: root, tileSize: tileSize, coordinate: coordinate, start: SIMD2<Float>(-0.39, -0.33), count: 5, horizontal: true)
        addFence(to: root, tileSize: tileSize, coordinate: coordinate, start: SIMD2<Float>(0.39, -0.24), count: 4, horizontal: false)
        addWoodPile(to: root, tileSize: tileSize, coordinate: coordinate, center: SIMD3<Float>(0.34, 0.07, 0.21), count: 3)
        addScarecrow(to: root, tileSize: tileSize, coordinate: coordinate, position: SIMD3<Float>(-0.34, 0.11, 0.20))
        addCart(to: root, tileSize: tileSize, coordinate: coordinate, center: SIMD3<Float>(0.33, 0.075, 0.03))
        addSack(to: root, tileSize: tileSize, position: SIMD3<Float>(0.05, 0.055, 0.31), coordinate: coordinate, salt: 271)
        addSheep(to: root, tileSize: tileSize, at: SIMD2<Float>(-0.26, 0.27), wander: SIMD2<Float>(0.11, -0.04), duration: 7.5, yaw: 1.4 + jitter(coordinate, salt: 272) * 0.4)
        addSheep(to: root, tileSize: tileSize, at: SIMD2<Float>(-0.02, 0.30), wander: SIMD2<Float>(-0.08, 0.03), duration: 9.5, yaw: -1.7 + jitter(coordinate, salt: 273) * 0.4)
        addLevelPips(level, to: root, tileSize: tileSize)
    }

    private static func addPier(level: Int, to root: Entity, tileSize: Float, coordinate: GridCoordinate, gridSize: GridSize) {
        // Built pointing +z, then the whole group turns toward the nearest
        // board edge so the dock always reaches out over the sea.
        let dock = Entity()
        dock.orientation = simd_quatf(angle: shorelineYaw(for: coordinate, gridSize: gridSize), axis: SIMD3<Float>(0, 1, 0))
        root.addChild(dock)

        addGroundPatch(to: dock, tileSize: tileSize, center: SIMD2<Float>(0, 0.06), size: SIMD2<Float>(0.46, 0.56), color: Palette.walkedDirt, rotation: jitter(coordinate, salt: 341) * 0.2)

        // Boardwalk built from individual chunky planks laid slightly uneven,
        // so the dock reads as hand-nailed rather than extruded.
        let plankCount = 7
        for index in 0..<plankCount {
            let z = 0.02 + Float(index) * 0.145 + jitter(coordinate, salt: 343 + index) * 0.018
            let plank = addBox(
                to: dock,
                size: SIMD3<Float>(0.30 + jitter(coordinate, salt: 380 + index) * 0.02, 0.045, 0.125) * tileSize,
                position: SIMD3<Float>(jitter(coordinate, salt: 386 + index) * 0.012, 0.088 + Float(index % 2) * 0.006, z) * tileSize,
                color: index.isMultiple(of: 2) ? Palette.cutWood : Palette.barnWood,
                roughness: 0.88,
                cornerRadius: tileSize * 0.016
            )
            plank.orientation = simd_quatf(angle: jitter(coordinate, salt: 392 + index) * 0.04, axis: SIMD3<Float>(0, 1, 0))
        }

        // Support posts: thick rounded piles, short pairs over the shore,
        // longer ones reaching down to the waterline at the far end.
        let postSpecs: [(z: Float, height: Float, centerY: Float)] = [
            (0.16, 0.30, -0.05),
            (0.52, 0.34, -0.08),
            (0.86, 0.54, -0.16)
        ]
        for (index, spec) in postSpecs.enumerated() {
            for side in [Float(-1), 1] {
                let post = addCylinder(to: dock, radius: 0.040 * tileSize, height: spec.height * tileSize, position: SIMD3<Float>(side * 0.14, spec.centerY, spec.z) * tileSize, color: Palette.darkTimber, roughness: 0.92)
                post.orientation = simd_quatf(angle: jitter(coordinate, salt: 351 + index) * 0.07 * side, axis: SIMD3<Float>(0, 0, 1))
            }
        }

        // Mooring post rising above the deck at the far end.
        addCylinder(to: dock, radius: 0.042 * tileSize, height: 0.18 * tileSize, position: SIMD3<Float>(0.14, 0.17, 0.86) * tileSize, color: Palette.railWood, roughness: 0.90)

        // Moored rowing boat floating beside the deck's end; grouped so the
        // whole boat bobs gently on the water as one piece.
        let boatCenter = SIMD3<Float>(-0.30, -0.30, 0.80)
        let boat = Entity()
        boat.position = boatCenter * tileSize
        boat.orientation = simd_quatf(angle: 0.10 + jitter(coordinate, salt: 361) * 0.10, axis: SIMD3<Float>(0, 1, 0))
        dock.addChild(boat)
        addBox(to: boat, size: SIMD3<Float>(0.17, 0.065, 0.34) * tileSize, position: .zero, color: Palette.doorWood, roughness: 0.86, cornerRadius: tileSize * 0.022)
        addBox(to: boat, size: SIMD3<Float>(0.19, 0.020, 0.36) * tileSize, position: SIMD3<Float>(0, 0.042, 0) * tileSize, color: Palette.barnWood, roughness: 0.86, cornerRadius: tileSize * 0.024)
        addBox(to: boat, size: SIMD3<Float>(0.15, 0.016, 0.045) * tileSize, position: SIMD3<Float>(0, 0.030, 0.02) * tileSize, color: Palette.cutWood, roughness: 0.88, cornerRadius: tileSize * 0.004)
        addCylinder(to: boat, radius: 0.012 * tileSize, height: 0.30 * tileSize, position: SIMD3<Float>(0, 0.19, -0.06) * tileSize, color: Palette.bark, roughness: 0.90)
        addAmbientDrift(to: boat, offset: SIMD3<Float>(0, 0.014, 0) * tileSize, duration: 2.4)

        // Mooring rope sagging from the deck post down to the boat.
        let rope = addBox(to: dock, size: SIMD3<Float>(0.17, 0.012, 0.012) * tileSize, position: SIMD3<Float>(-0.075, -0.05, 0.83) * tileSize, color: Palette.sackCloth, roughness: 0.95, cornerRadius: tileSize * 0.003)
        rope.orientation = simd_quatf(angle: 0.9, axis: SIMD3<Float>(0, 0, 1))

        // Shore-side props.
        addLantern(to: dock, tileSize: tileSize, position: SIMD3<Float>(-0.125, 0.20, 0.16), coordinate: coordinate, salt: 364)
        addCrate(to: dock, tileSize: tileSize, position: SIMD3<Float>(0.27, 0.065, -0.06), coordinate: coordinate, salt: 365)
        addBarrel(to: dock, tileSize: tileSize, position: SIMD3<Float>(-0.29, 0.08, -0.10), salt: 366, coordinate: coordinate)
        addGrassClumps(to: root, tileSize: tileSize, coordinate: coordinate, count: 3, around: SIMD2<Float>(0, -0.28), radius: 0.16)
        addLevelPips(level, to: root, tileSize: tileSize)
    }

    private static func shorelineYaw(for coordinate: GridCoordinate, gridSize: GridSize) -> Float {
        let left = coordinate.x
        let right = gridSize.columns - 1 - coordinate.x
        let top = coordinate.y
        let bottom = gridSize.rows - 1 - coordinate.y
        let minimum = min(left, right, top, bottom)
        // Row 0 renders at -z (back of the board), the last row at +z.
        if bottom == minimum { return 0 }
        if top == minimum { return .pi }
        if right == minimum { return .pi / 2 }
        return -.pi / 2
    }

    private static func addFactory(level: Int, to root: Entity, tileSize: Float, coordinate: GridCoordinate) {
        // Heavy stone base course
        addBox(to: root, size: SIMD3<Float>(0.54, 0.10, 0.48) * tileSize, position: SIMD3<Float>(-0.04, 0.05, 0.02) * tileSize, color: Palette.smokeStone, roughness: 0.92, cornerRadius: tileSize * 0.03)
        // Workshop hall
        addBox(to: root, size: SIMD3<Float>(0.46, 0.36, 0.40) * tileSize, position: SIMD3<Float>(-0.05, 0.27, 0.02) * tileSize, color: Palette.labStone, roughness: 0.80, cornerRadius: tileSize * 0.05)
        addBox(to: root, size: SIMD3<Float>(0.49, 0.045, 0.43) * tileSize, position: SIMD3<Float>(-0.05, 0.46, 0.02) * tileSize, color: Palette.warmGold, roughness: 0.52, cornerRadius: tileSize * 0.015)
        // Gabled slate roof with a generous overhang
        let roof = addBox(to: root, size: SIMD3<Float>(0.64, 0.13, 0.56) * tileSize, position: SIMD3<Float>(-0.05, 0.545, 0.02) * tileSize, color: Palette.slateRoof, roughness: 0.88, cornerRadius: tileSize * 0.05)
        roof.orientation = simd_quatf(angle: jitter(coordinate, salt: 301) * 0.04, axis: SIMD3<Float>(0, 0, 1))
        addRidgeBeam(to: root, tileSize: tileSize, center: SIMD3<Float>(-0.05, 0.625, 0.02), length: 0.56, color: Palette.slateRoof, orientation: roof.orientation)
        addEaveStrips(to: root, tileSize: tileSize, center: SIMD3<Float>(-0.05, 0.475, 0.02), width: 0.58, depth: 0.46, orientation: roof.orientation)
        // Smokestack with vent glow
        addBox(to: root, size: SIMD3<Float>(0.15, 0.50, 0.15) * tileSize, position: SIMD3<Float>(0.22, 0.38, -0.13) * tileSize, color: Palette.smokeStone, roughness: 0.88, cornerRadius: tileSize * 0.012)
        addBox(to: root, size: SIMD3<Float>(0.19, 0.05, 0.19) * tileSize, position: SIMD3<Float>(0.22, 0.645, -0.13) * tileSize, color: Palette.deepStone, roughness: 0.88, cornerRadius: tileSize * 0.008)
        addBox(to: root, size: SIMD3<Float>(0.10, 0.07, 0.10) * tileSize, position: SIMD3<Float>(0.22, 0.70, -0.13) * tileSize, color: Palette.arcaneBlue, roughness: 0.38, cornerRadius: tileSize * 0.012)
        addChimneySmoke(to: root, tileSize: tileSize, above: SIMD3<Float>(0.22, 0.76, -0.13))
        // Wall pipe and side flue
        addBox(to: root, size: SIMD3<Float>(0.08, 0.08, 0.42) * tileSize, position: SIMD3<Float>(-0.28, 0.40, 0.00) * tileSize, color: Palette.arcaneBlue, roughness: 0.38, cornerRadius: tileSize * 0.01)
        addBox(to: root, size: SIMD3<Float>(0.09, 0.30, 0.09) * tileSize, position: SIMD3<Float>(-0.27, 0.17, 0.24) * tileSize, color: Palette.smokeStone, roughness: 0.88, cornerRadius: tileSize * 0.010)
        // Door, frames, step
        addBox(to: root, size: SIMD3<Float>(0.12, 0.17, 0.035) * tileSize, position: SIMD3<Float>(-0.02, 0.15, 0.212) * tileSize, color: Palette.doorWood, roughness: 0.84, cornerRadius: tileSize * 0.004)
        addDoorFrame(to: root, tileSize: tileSize, center: SIMD3<Float>(-0.02, 0.15, 0.218), width: 0.12, height: 0.17)
        addEntryStep(to: root, tileSize: tileSize, center: SIMD3<Float>(-0.02, 0.028, 0.285), width: 0.17)
        addWindowFrame(to: root, tileSize: tileSize, center: SIMD3<Float>(0.13, 0.31, 0.212), width: 0.10, height: 0.11)
        addWindowFrame(to: root, tileSize: tileSize, center: SIMD3<Float>(-0.10, 0.31, -0.172), width: 0.10, height: 0.11)
        // Yard props
        addCrate(to: root, tileSize: tileSize, position: SIMD3<Float>(0.31, 0.065, 0.22), coordinate: coordinate, salt: 305)
        addBarrel(to: root, tileSize: tileSize, position: SIMD3<Float>(-0.31, 0.08, -0.26), salt: 306, coordinate: coordinate)
        addWoodPile(to: root, tileSize: tileSize, coordinate: coordinate, center: SIMD3<Float>(0.33, 0.07, 0.02), count: 3)
        addDebris(to: root, tileSize: tileSize, coordinate: coordinate, count: 4, around: SIMD2<Float>(0.31, 0.30), radius: 0.12, color: Palette.warmGold)
        addLevelPips(level, to: root, tileSize: tileSize)
    }

    private static func addBarracks(level: Int, to root: Entity, tileSize: Float, coordinate: GridCoordinate) {
        addBox(to: root, size: SIMD3<Float>(0.62, 0.06, 0.48) * tileSize, position: SIMD3<Float>(-0.02, 0.05, 0.00) * tileSize, color: Palette.deepStone, roughness: 0.94, cornerRadius: tileSize * 0.02)
        addBox(to: root, size: SIMD3<Float>(0.58, 0.32, 0.44) * tileSize, position: SIMD3<Float>(-0.02, 0.22, 0.00) * tileSize, color: Palette.fortifiedClay, roughness: 0.88, cornerRadius: tileSize * 0.05)
        let roof = addBox(to: root, size: SIMD3<Float>(0.76, 0.15, 0.58) * tileSize, position: SIMD3<Float>(-0.03, 0.455, -0.01) * tileSize, color: Palette.slateRoof, roughness: 0.9, cornerRadius: tileSize * 0.06)
        roof.orientation = simd_quatf(angle: jitter(coordinate, salt: 321) * 0.05, axis: SIMD3<Float>(0, 0, 1))
        addBox(to: root, size: SIMD3<Float>(0.56, 0.05, 0.64) * tileSize, position: SIMD3<Float>(-0.05, 0.545, -0.01) * tileSize, color: Palette.roofHighlight, roughness: 0.88, cornerRadius: tileSize * 0.02)
        addRidgeBeam(to: root, tileSize: tileSize, center: SIMD3<Float>(-0.05, 0.585, -0.01), length: 0.52, color: Palette.slateRoof, orientation: roof.orientation)
        addEaveStrips(to: root, tileSize: tileSize, center: SIMD3<Float>(-0.03, 0.375, -0.01), width: 0.78, depth: 0.56, orientation: roof.orientation)

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
        addDoorFrame(to: root, tileSize: tileSize, center: SIMD3<Float>(-0.10, 0.24, 0.242), width: 0.13, height: 0.16)
        addEntryStep(to: root, tileSize: tileSize, center: SIMD3<Float>(-0.10, 0.028, 0.305), width: 0.18)
        addWindowFrame(to: root, tileSize: tileSize, center: SIMD3<Float>(0.08, 0.27, -0.215), width: 0.10, height: 0.10)
        addWeaponRack(to: root, tileSize: tileSize, coordinate: coordinate, center: SIMD3<Float>(0.30, 0.13, -0.30))
        addTrainingProps(to: root, tileSize: tileSize, coordinate: coordinate)
        addShieldRack(to: root, tileSize: tileSize, coordinate: coordinate, center: SIMD3<Float>(-0.33, 0.19, -0.03))
        addFirePit(to: root, tileSize: tileSize, coordinate: coordinate, center: SIMD3<Float>(0.32, 0.04, 0.09))
        addLevelPips(level, to: root, tileSize: tileSize)
    }

    private static func addCanopyBlob(to root: Entity, tileSize: Float, radius: Float, position: SIMD3<Float>, scale: SIMD3<Float>, color: NSColor) {
        let blob = World3DRenderResources.makeSphere(
            radius: tileSize * radius,
            material: material(color, roughness: 0.86),
            scale: scale
        )
        blob.position = position * tileSize
        root.addChild(blob)
    }

    private static func addGroundPatch(to root: Entity, tileSize: Float, center: SIMD2<Float>, size: SIMD2<Float>, color: NSColor, rotation: Float) {
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
                // Oversized, softly rounded tufts — toy grass, not turf.
                let bladeEntity = addBox(
                    to: root,
                    size: SIMD3<Float>(0.032, 0.075 + randomFloat(coordinate, salt: 412 + blade + index) * 0.05, 0.032) * tileSize,
                    position: SIMD3<Float>(x + Float(blade) * 0.026, 0.042, z + jitter(coordinate, salt: 417 + blade + index) * 0.024) * tileSize,
                    color: blade.isMultiple(of: 2) ? Palette.grassLight : Palette.grassShadow,
                    roughness: 0.96,
                    cornerRadius: tileSize * 0.012
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

    private static func addDebris(to root: Entity, tileSize: Float, coordinate: GridCoordinate, count: Int, around: SIMD2<Float>, radius: Float, color: NSColor) {
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

    private static func addBarrel(to root: Entity, tileSize: Float, position: SIMD3<Float>, salt: Int, coordinate: GridCoordinate) {
        let barrel = addBox(to: root, size: SIMD3<Float>(0.08, 0.12, 0.08) * tileSize, position: position * tileSize, color: Palette.barnWood, roughness: 0.86, cornerRadius: tileSize * 0.018)
        barrel.orientation = simd_quatf(angle: randomAngle(coordinate, salt: salt), axis: SIMD3<Float>(0, 1, 0))
        addBox(to: root, size: SIMD3<Float>(0.09, 0.014, 0.09) * tileSize, position: SIMD3<Float>(position.x, position.y + 0.065, position.z) * tileSize, color: Palette.darkTimber, roughness: 0.9, cornerRadius: tileSize * 0.004)
    }

    private static func addBanner(to root: Entity, tileSize: Float, coordinate: GridCoordinate, polePosition: SIMD3<Float>, side: Float) {
        addBox(to: root, size: SIMD3<Float>(0.045, 0.44, 0.045) * tileSize, position: polePosition * tileSize, color: Palette.darkTimber, roughness: 0.92, cornerRadius: tileSize * 0.005)
        let banner = addBox(to: root, size: SIMD3<Float>(0.21, 0.13, 0.035) * tileSize, position: SIMD3<Float>(polePosition.x + side * 0.10, polePosition.y + 0.12, polePosition.z) * tileSize, color: Palette.bannerRed, roughness: 0.78, cornerRadius: tileSize * 0.004)
        banner.orientation = simd_quatf(angle: jitter(coordinate, salt: 901 + Int(side)) * 0.07, axis: SIMD3<Float>(0, 0, 1))
        // Gentle sway so flags never sit perfectly still.
        addAmbientDrift(to: banner, offset: SIMD3<Float>(0, 0.006, side * 0.012) * tileSize, duration: 2.8 + Double(side) * 0.4)
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

    private static func addThemeGroundDecor(to root: Entity, tileSize: Float, coordinate: GridCoordinate, around: SIMD2<Float>) {
        switch WorldTheme.current {
        case .desert:
            let x = around.x + jitter(coordinate, salt: 961) * 0.08
            let z = around.y + jitter(coordinate, salt: 967) * 0.08
            guard abs(x) < 0.44, abs(z) < 0.44 else { return }
            addCactus(to: root, tileSize: tileSize, coordinate: coordinate, position: SIMD2<Float>(x, z), salt: 968)
        case .mountains:
            // Snow patches instead of mushrooms.
            for index in 0..<2 {
                let x = around.x + jitter(coordinate, salt: 961 + index) * 0.10
                let z = around.y + jitter(coordinate, salt: 967 + index) * 0.10
                guard abs(x) < 0.44, abs(z) < 0.44 else { continue }
                addGroundPatch(
                    to: root,
                    tileSize: tileSize,
                    center: SIMD2<Float>(x, z),
                    size: SIMD2<Float>(0.14, 0.10),
                    color: Palette.peakCap,
                    rotation: randomAngle(coordinate, salt: 971 + index)
                )
            }
        case .village, .forest:
            for index in 0..<3 {
                let x = around.x + jitter(coordinate, salt: 961 + index) * 0.08
                let z = around.y + jitter(coordinate, salt: 967 + index) * 0.08
                guard abs(x) < 0.46, abs(z) < 0.46 else { continue }
                addCylinder(to: root, radius: 0.011 * tileSize, height: 0.045 * tileSize, position: SIMD3<Float>(x, 0.034, z) * tileSize, color: Palette.plaster, roughness: 0.88)
                addCone(to: root, radius: 0.026 * tileSize, height: 0.032 * tileSize, position: SIMD3<Float>(x, 0.068, z) * tileSize, color: Palette.mushroomCap, roughness: 0.82)
            }
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

    private static func addTimberFrame(to root: Entity, tileSize: Float, center: SIMD3<Float>, width: Float, height: Float, color: NSColor) {
        let z = center.z
        let postHeight = height
        addBox(to: root, size: SIMD3<Float>(0.026, postHeight, 0.026) * tileSize, position: SIMD3<Float>(center.x - width * 0.46, center.y, z) * tileSize, color: color, roughness: 0.92, cornerRadius: tileSize * 0.003)
        addBox(to: root, size: SIMD3<Float>(0.026, postHeight, 0.026) * tileSize, position: SIMD3<Float>(center.x + width * 0.46, center.y, z) * tileSize, color: color, roughness: 0.92, cornerRadius: tileSize * 0.003)
        addBox(to: root, size: SIMD3<Float>(width, 0.024, 0.026) * tileSize, position: SIMD3<Float>(center.x, center.y + height * 0.42, z) * tileSize, color: color, roughness: 0.92, cornerRadius: tileSize * 0.003)
        addBox(to: root, size: SIMD3<Float>(width * 0.78, 0.024, 0.026) * tileSize, position: SIMD3<Float>(center.x, center.y - height * 0.30, z) * tileSize, color: color, roughness: 0.92, cornerRadius: tileSize * 0.003)
        let diagonal = addBox(to: root, size: SIMD3<Float>(0.024, height * 0.72, 0.026) * tileSize, position: SIMD3<Float>(center.x, center.y + height * 0.02, z + 0.002) * tileSize, color: color, roughness: 0.92, cornerRadius: tileSize * 0.003)
        diagonal.orientation = simd_quatf(angle: 0.55, axis: SIMD3<Float>(0, 0, 1))
    }

    /// Two posts + lintel around a door opening on a z-facing wall.
    private static func addDoorFrame(to root: Entity, tileSize: Float, center: SIMD3<Float>, width: Float, height: Float) {
        for side: Float in [-1, 1] {
            addBox(to: root, size: SIMD3<Float>(0.028, height + 0.02, 0.030) * tileSize, position: SIMD3<Float>(center.x + side * (width * 0.5 + 0.016), center.y, center.z) * tileSize, color: Palette.darkTimber, roughness: 0.9, cornerRadius: tileSize * 0.003)
        }
        addBox(to: root, size: SIMD3<Float>(width + 0.09, 0.028, 0.030) * tileSize, position: SIMD3<Float>(center.x, center.y + height * 0.5 + 0.014, center.z) * tileSize, color: Palette.darkTimber, roughness: 0.9, cornerRadius: tileSize * 0.003)
    }

    /// Pane + posts + sill; `sideways` puts the pane on an x-facing wall.
    private static func addWindowFrame(to root: Entity, tileSize: Float, center: SIMD3<Float>, width: Float, height: Float, sideways: Bool = false) {
        let paneSize = sideways ? SIMD3<Float>(0.032, height, width) : SIMD3<Float>(width, height, 0.032)
        addBox(to: root, size: paneSize * tileSize, position: center * tileSize, color: Palette.warmWindow, roughness: 0.42, cornerRadius: tileSize * 0.004)
        let lateral: SIMD3<Float> = sideways ? SIMD3<Float>(0, 0, 1) : SIMD3<Float>(1, 0, 0)
        for side: Float in [-1, 1] {
            addBox(to: root, size: SIMD3<Float>(0.024, height + 0.03, 0.024) * tileSize, position: (center + lateral * (side * (width * 0.5 + 0.014))) * tileSize, color: Palette.timber, roughness: 0.9, cornerRadius: tileSize * 0.003)
        }
        let sillSize = sideways ? SIMD3<Float>(0.034, 0.022, width + 0.07) : SIMD3<Float>(width + 0.07, 0.022, 0.034)
        addBox(to: root, size: sillSize * tileSize, position: SIMD3<Float>(center.x, center.y - height * 0.5 - 0.012, center.z) * tileSize, color: Palette.darkTimber, roughness: 0.9, cornerRadius: tileSize * 0.003)
    }

    /// Two stacked stone slabs forming a stoop in front of a door.
    private static func addEntryStep(to root: Entity, tileSize: Float, center: SIMD3<Float>, width: Float) {
        addBox(to: root, size: SIMD3<Float>(width, 0.030, 0.10) * tileSize, position: center * tileSize, color: Palette.plinthStone, roughness: 0.94, cornerRadius: tileSize * 0.006)
        addBox(to: root, size: SIMD3<Float>(width * 0.78, 0.028, 0.062) * tileSize, position: SIMD3<Float>(center.x, center.y + 0.026, center.z - 0.022) * tileSize, color: Palette.warmStone, roughness: 0.94, cornerRadius: tileSize * 0.006)
    }

    /// Beam running the roof peak along x.
    private static func addRidgeBeam(to root: Entity, tileSize: Float, center: SIMD3<Float>, length: Float, color: NSColor, orientation: simd_quatf? = nil) {
        let beam = addBox(to: root, size: SIMD3<Float>(length, 0.034, 0.050) * tileSize, position: center * tileSize, color: color, roughness: 0.88, cornerRadius: tileSize * 0.008)
        if let orientation { beam.orientation = orientation }
    }

    /// Thin strips under the front/back roof overhangs.
    private static func addEaveStrips(to root: Entity, tileSize: Float, center: SIMD3<Float>, width: Float, depth: Float, orientation: simd_quatf? = nil) {
        for side: Float in [-1, 1] {
            let eave = addBox(to: root, size: SIMD3<Float>(width, 0.024, 0.032) * tileSize, position: SIMD3<Float>(center.x, center.y, center.z + side * depth * 0.5) * tileSize, color: Palette.darkTimber, roughness: 0.9, cornerRadius: tileSize * 0.004)
            if let orientation { eave.orientation = orientation }
        }
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
    private static func addCone(
        to root: Entity,
        radius: Float,
        height: Float,
        position: SIMD3<Float>,
        color: NSColor,
        roughness: Float = 0.92
    ) -> ModelEntity {
        let cone = World3DRenderResources.makeCone(
            radius: radius,
            height: height,
            material: material(color, roughness: roughness)
        )
        cone.position = position
        root.addChild(cone)
        return cone
    }

    @discardableResult
    private static func addCylinder(
        to root: Entity,
        radius: Float,
        height: Float,
        position: SIMD3<Float>,
        color: NSColor,
        roughness: Float = 0.9
    ) -> ModelEntity {
        let cylinder = World3DRenderResources.makeCylinder(
            radius: radius,
            height: height,
            material: material(color, roughness: roughness)
        )
        cylinder.position = position
        root.addChild(cylinder)
        return cylinder
    }

    @discardableResult
    private static func addBox(
        to root: Entity,
        size: SIMD3<Float>,
        position: SIMD3<Float>,
        color: NSColor,
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

    private static func material(_ color: NSColor, roughness: Float, metallic: Bool = false) -> SimpleMaterial {
        World3DRenderResources.material(color, roughness: roughness, metallic: metallic)
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

/// Theme-driven colors; all asset builders read through this so a theme
/// switch recolors every environmental asset on the next rebuild.
private var Palette: WorldPalette { WorldTheme.current.palette }

private extension SIMD3 where Scalar == Float {
    static func * (lhs: SIMD3<Float>, rhs: Float) -> SIMD3<Float> {
        SIMD3<Float>(lhs.x * rhs, lhs.y * rhs, lhs.z * rhs)
    }

    static func + (lhs: SIMD3<Float>, rhs: SIMD3<Float>) -> SIMD3<Float> {
        SIMD3<Float>(lhs.x + rhs.x, lhs.y + rhs.y, lhs.z + rhs.z)
    }
}
