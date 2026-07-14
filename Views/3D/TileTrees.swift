import RealityKit
import AppKit


extension World3DTileEntity {
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

    static func addBroadleafTree(to root: Entity, tileSize: Float, coordinate: GridCoordinate, trunkOffset: SIMD3<Float>) {
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

    static func addConiferTree(to root: Entity, tileSize: Float, coordinate: GridCoordinate, trunkOffset: SIMD3<Float>, snowCapped: Bool) {
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

    static func addPalmTree(to root: Entity, tileSize: Float, coordinate: GridCoordinate, trunkOffset: SIMD3<Float>) {
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

    static func addCactus(to root: Entity, tileSize: Float, coordinate: GridCoordinate, position: SIMD2<Float>, salt: Int) {
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

}
