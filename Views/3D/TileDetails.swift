import RealityKit
import AppKit


extension World3DTileEntity {
    static func addCanopyBlob(to root: Entity, tileSize: Float, radius: Float, position: SIMD3<Float>, scale: SIMD3<Float>, color: NSColor) {
        let blob = World3DRenderResources.makeSphere(
            radius: tileSize * radius,
            material: material(color, roughness: 0.86),
            scale: scale
        )
        blob.position = position * tileSize
        root.addChild(blob)
    }

    static func addGroundPatch(to root: Entity, tileSize: Float, center: SIMD2<Float>, size: SIMD2<Float>, color: NSColor, rotation: Float) {
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

    static func addGrassClumps(to root: Entity, tileSize: Float, coordinate: GridCoordinate, count: Int, around: SIMD2<Float>, radius: Float) {
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

    static func addRockCluster(to root: Entity, tileSize: Float, coordinate: GridCoordinate, center: SIMD2<Float>, radius: Float, count: Int, scale: Float) {
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

    static func addRootCluster(to root: Entity, tileSize: Float, coordinate: GridCoordinate, center: SIMD2<Float>) {
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

    static func addDebris(to root: Entity, tileSize: Float, coordinate: GridCoordinate, count: Int, around: SIMD2<Float>, radius: Float, color: NSColor) {
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

    static func addFence(to root: Entity, tileSize: Float, coordinate: GridCoordinate, start: SIMD2<Float>, count: Int, horizontal: Bool) {
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

    static func addSupportBeam(to root: Entity, tileSize: Float, position: SIMD3<Float>, height: Float, salt: Int, coordinate: GridCoordinate) {
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

    static func addWoodPile(to root: Entity, tileSize: Float, coordinate: GridCoordinate, center: SIMD3<Float>, count: Int) {
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

    static func addBarrel(to root: Entity, tileSize: Float, position: SIMD3<Float>, salt: Int, coordinate: GridCoordinate) {
        let barrel = addBox(to: root, size: SIMD3<Float>(0.08, 0.12, 0.08) * tileSize, position: position * tileSize, color: Palette.barnWood, roughness: 0.86, cornerRadius: tileSize * 0.018)
        barrel.orientation = simd_quatf(angle: randomAngle(coordinate, salt: salt), axis: SIMD3<Float>(0, 1, 0))
        addBox(to: root, size: SIMD3<Float>(0.09, 0.014, 0.09) * tileSize, position: SIMD3<Float>(position.x, position.y + 0.065, position.z) * tileSize, color: Palette.darkTimber, roughness: 0.9, cornerRadius: tileSize * 0.004)
    }

    static func addBanner(to root: Entity, tileSize: Float, coordinate: GridCoordinate, polePosition: SIMD3<Float>, side: Float) {
        addBox(to: root, size: SIMD3<Float>(0.045, 0.44, 0.045) * tileSize, position: polePosition * tileSize, color: Palette.darkTimber, roughness: 0.92, cornerRadius: tileSize * 0.005)
        let banner = addBox(to: root, size: SIMD3<Float>(0.21, 0.13, 0.035) * tileSize, position: SIMD3<Float>(polePosition.x + side * 0.10, polePosition.y + 0.12, polePosition.z) * tileSize, color: Palette.bannerRed, roughness: 0.78, cornerRadius: tileSize * 0.004)
        banner.orientation = simd_quatf(angle: jitter(coordinate, salt: 901 + Int(side)) * 0.07, axis: SIMD3<Float>(0, 0, 1))
        // Gentle sway so flags never sit perfectly still.
        addAmbientDrift(to: banner, offset: SIMD3<Float>(0, 0.006, side * 0.012) * tileSize, duration: 2.8 + Double(side) * 0.4)
        addBox(to: root, size: SIMD3<Float>(0.06, 0.06, 0.06) * tileSize, position: SIMD3<Float>(polePosition.x, polePosition.y + 0.24, polePosition.z) * tileSize, color: Palette.warmGold, roughness: 0.5, cornerRadius: tileSize * 0.01)
    }

    static func addWeaponRack(to root: Entity, tileSize: Float, coordinate: GridCoordinate, center: SIMD3<Float>) {
        addBox(to: root, size: SIMD3<Float>(0.22, 0.035, 0.05) * tileSize, position: center * tileSize, color: Palette.darkTimber, roughness: 0.9, cornerRadius: tileSize * 0.004)
        for index in 0..<detailCount(3, minimum: 1) {
            let spear = addBox(to: root, size: SIMD3<Float>(0.024, 0.23, 0.024) * tileSize, position: SIMD3<Float>(center.x - 0.08 + Float(index) * 0.08, center.y + 0.105, center.z) * tileSize, color: Palette.railWood, roughness: 0.84, cornerRadius: tileSize * 0.003)
            spear.orientation = simd_quatf(angle: -0.14 + Float(index) * 0.10 + jitter(coordinate, salt: 931 + index) * 0.05, axis: SIMD3<Float>(0, 0, 1))
            addBox(to: root, size: SIMD3<Float>(0.04, 0.045, 0.02) * tileSize, position: SIMD3<Float>(center.x - 0.08 + Float(index) * 0.08, center.y + 0.235, center.z) * tileSize, color: Palette.paleStone, roughness: 0.74, cornerRadius: tileSize * 0.002)
        }
    }

    static func addTrainingProps(to root: Entity, tileSize: Float, coordinate: GridCoordinate) {
        addBox(to: root, size: SIMD3<Float>(0.12, 0.13, 0.12) * tileSize, position: SIMD3<Float>(-0.32, 0.09, 0.23) * tileSize, color: Palette.strawRoof, roughness: 0.94, cornerRadius: tileSize * 0.016)
        let target = addBox(to: root, size: SIMD3<Float>(0.14, 0.14, 0.035) * tileSize, position: SIMD3<Float>(-0.32, 0.25, 0.23) * tileSize, color: Palette.bannerRed, roughness: 0.78, cornerRadius: tileSize * 0.020)
        target.orientation = simd_quatf(angle: jitter(coordinate, salt: 951) * 0.06, axis: SIMD3<Float>(0, 1, 0))
        addBox(to: root, size: SIMD3<Float>(0.07, 0.07, 0.040) * tileSize, position: SIMD3<Float>(-0.32, 0.25, 0.255) * tileSize, color: Palette.warmGold, roughness: 0.56, cornerRadius: tileSize * 0.014)
    }

}
