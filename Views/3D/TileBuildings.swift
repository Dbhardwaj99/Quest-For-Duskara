import RealityKit
import AppKit


extension World3DTileEntity {
    static func addHouse(level: Int, to root: Entity, tileSize: Float, coordinate: GridCoordinate) {
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

    static func addFarm(level: Int, to root: Entity, tileSize: Float, coordinate: GridCoordinate) {
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

    static func addPier(level: Int, to root: Entity, tileSize: Float, coordinate: GridCoordinate, gridSize: GridSize) {
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

    static func shorelineYaw(for coordinate: GridCoordinate, gridSize: GridSize) -> Float {
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

    static func addFactory(level: Int, to root: Entity, tileSize: Float, coordinate: GridCoordinate) {
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

    static func addBarracks(level: Int, to root: Entity, tileSize: Float, coordinate: GridCoordinate) {
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

}
