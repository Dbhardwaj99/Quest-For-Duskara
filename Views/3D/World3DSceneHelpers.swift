import RealityKit
import AppKit


extension World3DRenderer {
    func addCloudCluster(center: SIMD3<Float>, scale: Float) {
        // Solid, puffy cumulus: overlapping near-round spheres so clouds read
        // as sculpted cotton, not translucent pancakes.
        let cloudMaterial = matte(palette.cloud.withAlphaComponent(0.94), roughness: 1.0)
        let puffs: [(offset: SIMD3<Float>, radius: Float, scale: SIMD3<Float>)] = [
            (SIMD3<Float>(-0.24, -0.03, 0.02), 0.16, SIMD3<Float>(1.15, 0.80, 0.95)),
            (SIMD3<Float>(0.00, 0.06, 0.00), 0.22, SIMD3<Float>(1.20, 0.90, 1.00)),
            (SIMD3<Float>(0.24, -0.02, -0.03), 0.15, SIMD3<Float>(1.10, 0.78, 0.92)),
            (SIMD3<Float>(0.08, -0.06, 0.10), 0.13, SIMD3<Float>(1.25, 0.70, 1.05))
        ]

        let cluster = Entity()
        cluster.position = center
        staticRoot.addChild(cluster)
        for puff in puffs {
            let cloud = World3DRenderResources.makeSphere(
                radius: tileSize * puff.radius * scale,
                material: cloudMaterial,
                scale: puff.scale
            )
            cloud.position = puff.offset * (tileSize * scale * 2.2)
            cluster.addChild(cloud)
        }
        // The whole cluster drifts almost imperceptibly.
        addDriftAnimation(to: cluster, offset: SIMD3<Float>(tileSize * 0.18, tileSize * 0.03, 0), duration: 14)
    }

    // Subtle gold edge frame — no filled slab covering the tile.
    func showSelection(at coordinate: GridCoordinate) {
        let outline = makeTileOutline(color: NSColor(red: 1.0, green: 0.80, blue: 0.34, alpha: 0.95), thickness: 0.045)
        outline.name = "world3d_selection"
        outline.position = position(for: coordinate) + SIMD3<Float>(0, 0.050 + tileElevation(for: coordinate), 0)
        overlayRoot.addChild(outline)
    }

    func removeSelection() {
        overlayRoot.children
            .filter { $0.name == "world3d_selection" }
            .forEach { $0.removeFromParent() }
    }

    func position(for coordinate: GridCoordinate) -> SIMD3<Float> {
        let spacing = tileSize + tileGap
        let centeredX = Float(coordinate.x) - Float(gridSize.columns - 1) / 2
        let centeredZ = Float(coordinate.y) - Float(gridSize.rows - 1) / 2
        return SIMD3<Float>(centeredX * spacing, 0, centeredZ * spacing)
    }

    func material(for content: World3DTileSnapshot.Content, coordinate: GridCoordinate) -> SimpleMaterial {
        switch content {
        case .water:
            let ripple = CGFloat(stablePercent(coordinate, salt: 88)) / 700
            return matte(blend(palette.tileWater, with: World3DRenderer.rgbWhite, amount: ripple), roughness: 0.30)
        default:
            let variant = CGFloat(stablePercent(coordinate, salt: 211)) / 700
            return matte(blend(palette.tileGround, with: World3DRenderer.rgbWhite, amount: variant), roughness: 0.91)
        }
    }

    func blend(_ color: NSColor, with tint: NSColor, amount: CGFloat) -> NSColor {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        var tintRed: CGFloat = 0
        var tintGreen: CGFloat = 0
        var tintBlue: CGFloat = 0
        var tintAlpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        tint.getRed(&tintRed, green: &tintGreen, blue: &tintBlue, alpha: &tintAlpha)
        let clampedAmount = min(1, max(0, amount))
        return NSColor(
            red: red + (tintRed - red) * clampedAmount,
            green: green + (tintGreen - green) * clampedAmount,
            blue: blue + (tintBlue - blue) * clampedAmount,
            alpha: alpha
        )
    }

    func matte(_ color: NSColor, roughness: Float, metallic: Bool = false) -> SimpleMaterial {
        World3DRenderResources.material(color, roughness: roughness, metallic: metallic)
    }

    func tileElevation(for coordinate: GridCoordinate) -> Float {
        Float(stablePercent(coordinate, salt: 509)) / 100 * 0.018
    }

    func terrainWidth(for gridSize: GridSize) -> Float {
        Float(gridSize.columns) * tileSize + Float(gridSize.columns - 1) * tileGap
    }

    func terrainDepth(for gridSize: GridSize) -> Float {
        Float(gridSize.rows) * tileSize + Float(gridSize.rows - 1) * tileGap
    }

    // The FPS sample dips whenever the main run loop is busy (clicks, tile
    // placement), so quality used to flap and reset the scaffold — a full
    // scene rebuild on input, visible as lighting/water jitter. Now a switch
    // needs two consecutive readings ~12s apart, applies only to future tile
    // builds, and never rebuilds the scaffold.
    func updateVisualQuality() {
        let now = Date()
        guard now.timeIntervalSince(lastQualityCheckTime) > 12 else { return }
        lastQualityCheckTime = now

        let nextQuality = World3DVisualQuality.adaptive
        guard nextQuality != visualQuality else {
            pendingQuality = nil
            return
        }
        guard pendingQuality == nextQuality else {
            pendingQuality = nextQuality
            return
        }
        pendingQuality = nil
        visualQuality = nextQuality
        World3DRenderResources.configureVisualQuality(nextQuality)
        debugPrint("World3D quality changed:", nextQuality.rawValue)
    }

    func reportDiagnosticsIfNeeded() {
        let now = Date()
        guard now.timeIntervalSince(lastDiagnosticsReportTime) > 4 else { return }
        lastDiagnosticsReportTime = now
        World3DDiagnostics.report(entityRoot: boardRoot, terrainRoot: staticRoot, quality: visualQuality)
    }

    func stablePercent(_ coordinate: GridCoordinate, salt: Int) -> Int {
        let raw = coordinate.x * 73_856_093 ^ coordinate.y * 19_349_663 ^ salt * 83_492_791
        return abs(raw % 100)
    }

    func signature(townID: UUID, gridSize: GridSize, layout: TownBiomeLayout) -> String {
        let sides = BiomeSide.allCases
            .map { side in "\(side.rawValue):\(layout.biome(on: side)?.rawValue ?? "none")" }
            .joined(separator: "|")
        return "\(townID.uuidString)|\(gridSize.columns)x\(gridSize.rows)|\(sides)|\(WorldTheme.current.rawValue)"
    }
}
