import RealityKit
import AppKit


extension World3DRenderer {
    func configureView() {
        // Overcast-afternoon lighting: a softened warm sun with real (gentle)
        // shadows so geometry creates the depth textures never will, plus a
        // cool fill from the opposite side to keep contrast low.
        sun.light.intensity = 2800
        // ponytail: shadows double draw calls; drop maximumDistance or gate
        // on visual quality if low-end FPS ever suffers.
        sun.shadow = DirectionalLightComponent.Shadow(maximumDistance: 6, depthBias: 4)
        sun.orientation = simd_quatf(angle: -.pi / 4.8, axis: SIMD3<Float>(1, 0, 0)) * simd_quatf(angle: .pi / 5.8, axis: SIMD3<Float>(0, 1, 0))
        anchor.addChild(sun)

        fillLight.light.intensity = 1800
        fillLight.light.color = NSColor(red: 0.80, green: 0.86, blue: 0.93, alpha: 1)
        fillLight.orientation = simd_quatf(angle: -.pi / 3.6, axis: SIMD3<Float>(1, 0, 0)) * simd_quatf(angle: .pi + .pi / 5.8, axis: SIMD3<Float>(0, 1, 0))
        anchor.addChild(fillLight)
        applyEnvironment()
    }

    func applyEnvironment() {
        arView.environment.background = .color(palette.sky)
        sun.light.color = palette.sun
    }

    func rebuildScaffold(gridSize: GridSize) {
        applyEnvironment()
        staticRoot.children.forEach { $0.removeFromParent() }
        addDuskBackdrop(for: gridSize)
        addGroundPlate(for: gridSize)
    }

    func clearTiles() {
        tileRoot.children.forEach { $0.removeFromParent() }
        tileEntities.removeAll()
        tileSnapshots.removeAll()
        lastPlacementStates.removeAll()
        overlayRoot.children
            .filter { $0.name == "world3d_placement" }
            .forEach { $0.removeFromParent() }
    }

    func addGroundPlate(for gridSize: GridSize) {
        let boardWidth = terrainWidth(for: gridSize)
        let boardDepth = terrainDepth(for: gridSize)

        // Dark soil core under the tiles: a thin visible band between the
        // grass overhang and the sand, like a cut through real earth.
        let soil = World3DRenderResources.makeBox(
            size: SIMD3<Float>(boardWidth - 0.02, 0.22, boardDepth - 0.02),
            material: matte(palette.rootSoil, roughness: 0.97),
            cornerRadius: 0.10
        )
        soil.position.y = -0.16
        staticRoot.addChild(soil)

        // Organic sand mound with a wobbling coastline; the shape is shared
        // with World3DOcean so shader foam hugs the actual shore.
        let beach = World3DOcean.makeBeach(
            islandHalfExtents: SIMD2<Float>(boardWidth / 2, boardDepth / 2),
            tileSize: tileSize,
            material: matte(palette.skirt, roughness: 0.97)
        )
        staticRoot.addChild(beach)
    }

    func addDuskBackdrop(for gridSize: GridSize) {
        let boardWidth = terrainWidth(for: gridSize)
        let boardDepth = terrainDepth(for: gridSize)
        addOpenSea(boardWidth: boardWidth, boardDepth: boardDepth)

        // A few translucent clouds scattered around the island at varied
        // heights and depths — not a row on the horizon.
        addCloudCluster(center: SIMD3<Float>(-boardWidth * 0.95, tileSize * 2.6, -boardDepth * 0.55), scale: 0.80)
        addCloudCluster(center: SIMD3<Float>(boardWidth * 0.80, tileSize * 3.1, boardDepth * 0.40), scale: 0.60)
        addCloudCluster(center: SIMD3<Float>(boardWidth * 0.30, tileSize * 2.2, -boardDepth * 1.10), scale: 0.48)
    }

    func addOpenSea(boardWidth: Float, boardDepth: Float) {
        // Sized independently of the board so the sea has no visible edge at
        // any yaw/zoom; the visible ground region stays inside the camera far
        // plane (28) even at max zoom-out on ultra-wide windows.
        let seaSpan = tileSize * 100
        // Surface at -0.16 keeps the earth plate/skirt band (top ~-0.085)
        // visibly above the waterline so the island reads as rising from it.
        let surfaceY: Float = -0.16

        // One continuous living plane: Gerstner-style waves, depth coloring,
        // fresnel, shore foam, and interaction ripples all live in
        // OceanShaders.metal — no water tiles, no textures.
        let ocean = World3DOcean(
            islandHalfExtents: SIMD2<Float>(boardWidth / 2, boardDepth / 2),
            tileSize: tileSize,
            span: seaSpan,
            deepColor: palette.waterDeep
        )
        ocean.entity.position.y = surfaceY
        staticRoot.addChild(ocean.entity)
        self.ocean = ocean

        spawnBoats(boardWidth: boardWidth, boardDepth: boardDepth, waterY: surfaceY + 0.012)
        addOceanDecor(surfaceY: surfaceY)
        addBirds(boardWidth: boardWidth)
    }

    // Two or three gulls gliding slow circles above the island at staggered
    // heights — silhouette only, no flapping, no per-frame CPU.
    func addBirds(boardWidth: Float) {
        let plumage = NSColor(red: 0.36, green: 0.42, blue: 0.53, alpha: 1)
        for index in 0..<3 {
            let bird = Entity()
            for side: Float in [-1, 1] {
                let wing = World3DRenderResources.makeBox(
                    size: SIMD3<Float>(tileSize * 0.085, 0.006, tileSize * 0.024),
                    material: matte(plumage, roughness: 0.9),
                    cornerRadius: 0.002
                )
                wing.position.x = side * tileSize * 0.042
                wing.orientation = simd_quatf(angle: side * 0.38, axis: SIMD3<Float>(0, 0, 1))
                bird.addChild(wing)
            }
            let radius = boardWidth * (0.65 + Float(index) * 0.30)
            let height = tileSize * (2.1 + Float(index) * 0.55)
            bird.position = SIMD3<Float>(radius, height, 0)
            staticRoot.addChild(bird)

            let orbit = OrbitAnimation(
                duration: 34 + Double(index) * 11,
                axis: SIMD3<Float>(0, 1, 0),
                startTransform: Transform(translation: bird.position),
                spinClockwise: index.isMultiple(of: 2),
                orientToPath: true,
                rotationCount: 1,
                bindTarget: .transform
            )
            if let resource = try? AnimationResource.generate(with: orbit) {
                bird.playAnimation(resource.repeat())
            }
        }
    }

    // Decorative-only props: no collision components, so taps and gameplay
    // ignore them. Near props sit inside the boat lanes' inner ring, distant
    // islets outside the outer ring, and everything avoids the +z corridor
    // boats use to reach the pier.
    func addOceanDecor(surfaceY: Float) {
        let sand = matte(palette.skirt, roughness: 0.95)

        // Distant low islets with a single palm — depth for the horizon.
        let isletSpecs: [(angle: Float, radius: Float, size: Float)] = [
            (0.9, 4.6, 1.0),
            (2.6, 5.4, 1.35),
            (-1.9, 5.0, 0.85),
            (-2.8, 4.4, 0.7)
        ]
        for spec in isletSpecs {
            let islet = Entity()
            islet.position = SIMD3<Float>(sin(spec.angle) * spec.radius, surfaceY, cos(spec.angle) * spec.radius)
            staticRoot.addChild(islet)

            let mound = World3DRenderResources.makeSphere(
                radius: tileSize * 0.42 * spec.size,
                material: sand,
                scale: SIMD3<Float>(1.6, 0.28, 1.2)
            )
            islet.addChild(mound)

            let trunk = World3DRenderResources.makeCylinder(
                radius: tileSize * 0.022 * spec.size,
                height: tileSize * 0.26 * spec.size,
                material: matte(palette.bark, roughness: 0.9)
            )
            trunk.position = SIMD3<Float>(tileSize * 0.08, tileSize * 0.16 * spec.size, 0)
            islet.addChild(trunk)

            let canopy = World3DRenderResources.makeSphere(
                radius: tileSize * 0.12 * spec.size,
                material: matte(palette.frond, roughness: 0.9),
                scale: SIMD3<Float>(1.5, 0.6, 1.5)
            )
            canopy.position = SIMD3<Float>(tileSize * 0.08, tileSize * 0.30 * spec.size, 0)
            islet.addChild(canopy)
        }

        // Rounded boulders breaking the surface between the island and the
        // sea lanes — each a small cluster of two soft domes.
        let rockSpecs: [(angle: Float, radius: Float, scale: Float)] = [
            (0.8, 1.62, 1.0),
            (2.1, 1.88, 0.75),
            (-1.1, 1.70, 0.85),
            (-2.4, 1.92, 1.15)
        ]
        for (index, spec) in rockSpecs.enumerated() {
            let center = SIMD3<Float>(sin(spec.angle) * spec.radius, surfaceY - tileSize * 0.02, cos(spec.angle) * spec.radius)
            let stone = matte(index.isMultiple(of: 2) ? palette.deepStone : palette.warmStone, roughness: 0.96)
            let rock = World3DRenderResources.makeSphere(
                radius: tileSize * 0.09 * spec.scale,
                material: stone,
                scale: SIMD3<Float>(1.25, 0.85, 1.05)
            )
            rock.position = center
            staticRoot.addChild(rock)

            let companion = World3DRenderResources.makeSphere(
                radius: tileSize * 0.055 * spec.scale,
                material: stone,
                scale: SIMD3<Float>(1.1, 0.75, 1.2)
            )
            companion.position = center + SIMD3<Float>(tileSize * 0.09, -tileSize * 0.01, tileSize * 0.04) * spec.scale
            staticRoot.addChild(companion)
        }
    }

}
