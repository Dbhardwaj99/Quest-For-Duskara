import RealityKit
import AppKit


extension World3DTileEntity {
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

    static func template(kind: TemplateKind, tileSize: Float) -> Entity {
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

    static func coordinate(fromName name: String) -> GridCoordinate? {
        let prefix = "world3d_tile_"
        guard name.hasPrefix(prefix) else { return nil }
        let parts = name.dropFirst(prefix.count).split(separator: "_")
        guard parts.count == 2, let x = Int(parts[0]), let y = Int(parts[1]) else { return nil }
        return GridCoordinate(x: x, y: y)
    }

    static func addGroundDetail(for snapshot: World3DTileSnapshot, to root: Entity, tileSize: Float) {
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

    static func addWaterSheen(to root: Entity, tileSize: Float, coordinate: GridCoordinate) {
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
    static func addAmbientDrift(to entity: Entity, offset: SIMD3<Float>, scaleTo: Float = 1, duration: TimeInterval) {
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
    static func addChimneySmoke(to root: Entity, tileSize: Float, above top: SIMD3<Float>) {
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
    static func addSheep(to root: Entity, tileSize: Float, at spot: SIMD2<Float>, wander: SIMD2<Float>, duration: TimeInterval, yaw: Float) {
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

}
