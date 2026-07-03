import RealityKit
import AppKit
import Metal

@MainActor
final class World3DRenderer {
    let arView: ARView

    private let anchor = AnchorEntity(world: .zero)
    private let boardRoot = Entity()
    private let staticRoot = Entity()
    private let tileRoot = Entity()
    private let overlayRoot = Entity()

    private var selectedCoordinate: GridCoordinate?
    private var gridSize = GridSize(columns: 5, rows: 5)
    private var tileEntities: [GridCoordinate: Entity] = [:]
    private var tileSnapshots: [GridCoordinate: World3DTileSnapshot] = [:]
    private var scaffoldSignature = ""
    private var visualQuality = World3DVisualQuality.adaptive
    private var lastQualityCheckTime = Date.distantPast
    private var pendingQuality: World3DVisualQuality?
    private var lastDiagnosticsReportTime = Date.distantPast
    private var lastPlacementStates: [GridCoordinate: TilePlacementState] = [:]

    private var boatCruisers: [BoatCruiser] = []
    private var boatTimer: Timer?
    private var boatWaterY: Float = -0.16
    private var boatBaseRadius = SIMD2<Float>(2.2, 2.2)
    private var pierDockPoint: SIMD3<Float>?

    private let tileSize: Float = 0.46
    private let tileGap: Float = 0.020
    private let tileHeight: Float = 0.060
    private let sun = DirectionalLight()
    // NSColor.white is grayscale-space; blend() needs RGB components.
    static let rgbWhite = NSColor(red: 1, green: 1, blue: 1, alpha: 1)

    private var palette: WorldPalette { WorldTheme.current.palette }

    var cameraParent: Entity {
        anchor
    }

    init(arView: ARView) {
        self.arView = arView
        World3DRenderResources.configureVisualQuality(visualQuality)
        World3DDiagnostics.rendererDidInit()
        configureView()
        boardRoot.addChild(staticRoot)
        boardRoot.addChild(tileRoot)
        boardRoot.addChild(overlayRoot)
        anchor.addChild(boardRoot)
        arView.scene.anchors.append(anchor)
    }

    deinit {
        boatTimer?.invalidate()
        Task { @MainActor in
            World3DDiagnostics.rendererDidDeinit()
        }
    }

    func render(adapter: World3DStateAdapter) {
        updateVisualQuality()
        let nextGridSize = adapter.gridSize
        let nextSignature = signature(townID: adapter.town.id, gridSize: nextGridSize, layout: adapter.town.biomeLayout)
        if nextSignature != scaffoldSignature {
            gridSize = nextGridSize
            rebuildScaffold(gridSize: nextGridSize)
            clearTiles()
            scaffoldSignature = nextSignature
        }

        let snapshots = adapter.allTileSnapshots()
        let coordinates = Set(snapshots.map(\.coordinate))
        for staleCoordinate in Set(tileEntities.keys).subtracting(coordinates) {
            tileEntities[staleCoordinate]?.removeFromParent()
            tileEntities[staleCoordinate] = nil
            tileSnapshots[staleCoordinate] = nil
        }

        for snapshot in snapshots where tileSnapshots[snapshot.coordinate] != snapshot {
            // Placement feedback lives in overlayRoot (reconciled below), so a
            // placement-state-only change never rebuilds the tile.
            if let previous = tileSnapshots[snapshot.coordinate],
               tileEntities[snapshot.coordinate] != nil,
               previous.content == snapshot.content {
                tileSnapshots[snapshot.coordinate] = snapshot
                continue
            }

            tileEntities[snapshot.coordinate]?.removeFromParent()
            World3DDiagnostics.tileDidRebuild()
            let entity = World3DTileEntity.makeTile(
                snapshot: snapshot,
                tileSize: tileSize,
                tileHeight: tileHeight,
                material: material(for: snapshot.content, coordinate: snapshot.coordinate),
                gridSize: gridSize
            )
            entity.position = position(for: snapshot.coordinate)
            entity.position.y += tileElevation(for: snapshot.coordinate)
            tileRoot.addChild(entity)
            tileEntities[snapshot.coordinate] = entity
            tileSnapshots[snapshot.coordinate] = snapshot
        }

        updatePierDockPoint(town: adapter.town)
        updatePlacementOverlays(snapshots)
        select(adapter.viewModel.selectedCoordinate)
        reportDiagnosticsIfNeeded()
    }

    // Reconciled against the last known states: a no-op when nothing changed,
    // rebuilt from scratch when anything did — so stale overlays can never
    // outlive placement mode, and idle renders allocate nothing.
    private func updatePlacementOverlays(_ snapshots: [World3DTileSnapshot]) {
        var states: [GridCoordinate: TilePlacementState] = [:]
        for snapshot in snapshots where snapshot.placementState != .normal {
            states[snapshot.coordinate] = snapshot.placementState
        }
        guard states != lastPlacementStates else { return }
        lastPlacementStates = states

        overlayRoot.children
            .filter { $0.name == "world3d_placement" }
            .forEach { $0.removeFromParent() }

        for snapshot in snapshots where snapshot.placementState != .normal {
            let valid = snapshot.placementState == .valid
            let outline = makeTileOutline(
                color: valid
                    ? NSColor(red: 0.48, green: 0.86, blue: 0.46, alpha: 0.88)
                    : NSColor(red: 0.90, green: 0.36, blue: 0.30, alpha: 0.42),
                thickness: 0.05
            )
            outline.name = "world3d_placement"
            outline.position = position(for: snapshot.coordinate) + SIMD3<Float>(0, 0.046 + tileElevation(for: snapshot.coordinate), 0)
            overlayRoot.addChild(outline)

            if valid {
                // Barely-there glow so valid plots read at a glance without
                // hiding the tile.
                let glow = World3DRenderResources.makeBox(
                    size: SIMD3<Float>(tileSize * 0.86, 0.006, tileSize * 0.86),
                    material: matte(NSColor(red: 0.55, green: 0.88, blue: 0.50, alpha: 0.12), roughness: 0.5),
                    cornerRadius: tileSize * 0.04
                )
                glow.name = "world3d_placement"
                glow.position = outline.position
                overlayRoot.addChild(glow)
            }
        }
    }

    // Thin frame of four low bars hugging the tile's edges; the tile and
    // anything on it stay fully visible.
    private func makeTileOutline(color: NSColor, thickness: Float) -> Entity {
        let group = Entity()
        let material = matte(color, roughness: 0.5)
        let length = tileSize * 0.98
        let barThickness = tileSize * thickness
        let barHeight: Float = 0.012
        let inset = (length - barThickness) / 2
        let bars: [(SIMD3<Float>, SIMD3<Float>)] = [
            (SIMD3<Float>(length, barHeight, barThickness), SIMD3<Float>(0, 0, -inset)),
            (SIMD3<Float>(length, barHeight, barThickness), SIMD3<Float>(0, 0, inset)),
            (SIMD3<Float>(barThickness, barHeight, length), SIMD3<Float>(-inset, 0, 0)),
            (SIMD3<Float>(barThickness, barHeight, length), SIMD3<Float>(inset, 0, 0))
        ]
        for (size, barPosition) in bars {
            let bar = World3DRenderResources.makeBox(size: size, material: material, cornerRadius: barThickness * 0.3)
            bar.position = barPosition
            group.addChild(bar)
        }
        return group
    }

    func coordinate(for entity: Entity?) -> GridCoordinate? {
        World3DTileEntity.coordinate(from: entity)
    }

    func cameraBounds(for gridSize: GridSize) -> World3DCameraBounds {
        World3DCameraBounds(
            halfWidth: terrainWidth(for: gridSize) / 2,
            halfDepth: terrainDepth(for: gridSize) / 2,
            focusInset: tileSize * 1.45
        )
    }

    func select(_ coordinate: GridCoordinate?) {
        guard selectedCoordinate != coordinate else { return }
        selectedCoordinate = coordinate
        removeSelection()
        if let coordinate, gridSize.contains(coordinate) {
            showSelection(at: coordinate)
        }
    }

    private func configureView() {
        sun.light.intensity = 4500
        sun.orientation = simd_quatf(angle: -.pi / 4.8, axis: SIMD3<Float>(1, 0, 0)) * simd_quatf(angle: .pi / 5.8, axis: SIMD3<Float>(0, 1, 0))
        anchor.addChild(sun)
        applyEnvironment()
    }

    private func applyEnvironment() {
        arView.environment.background = .color(palette.sky)
        sun.light.color = palette.sun
    }

    private func rebuildScaffold(gridSize: GridSize) {
        applyEnvironment()
        staticRoot.children.forEach { $0.removeFromParent() }
        addDuskBackdrop(for: gridSize)
        addGroundPlate(for: gridSize)
    }

    private func clearTiles() {
        tileRoot.children.forEach { $0.removeFromParent() }
        tileEntities.removeAll()
        tileSnapshots.removeAll()
        lastPlacementStates.removeAll()
        overlayRoot.children
            .filter { $0.name == "world3d_placement" }
            .forEach { $0.removeFromParent() }
    }

    private func addGroundPlate(for gridSize: GridSize) {
        let boardWidth = terrainWidth(for: gridSize)
        let boardDepth = terrainDepth(for: gridSize)

        let earth = World3DRenderResources.makeBox(
            size: SIMD3<Float>(boardWidth + 0.14, 0.32, boardDepth + 0.14),
            material: matte(palette.earth, roughness: 0.96),
            cornerRadius: 0.18
        )
        earth.position.y = -0.25
        staticRoot.addChild(earth)

        addTerrainSkirt(width: boardWidth, depth: boardDepth)
    }

    private func addTerrainSkirt(width: Float, depth: Float) {
        let sideMaterial = matte(palette.skirt, roughness: 0.98)
        let frontBackSize = SIMD3<Float>(width + 0.10, 0.24, 0.11)
        let sideSize = SIMD3<Float>(0.11, 0.24, depth + 0.10)

        let topZ = depth / 2 + 0.035
        let sideX = width / 2 + 0.035
        let y: Float = -0.205

        let front = World3DRenderResources.makeBox(size: frontBackSize, material: sideMaterial, cornerRadius: 0.035)
        front.position = SIMD3<Float>(0, y, topZ)
        staticRoot.addChild(front)

        let back = World3DRenderResources.makeBox(size: frontBackSize, material: sideMaterial, cornerRadius: 0.035)
        back.position = SIMD3<Float>(0, y, -topZ)
        staticRoot.addChild(back)

        let left = World3DRenderResources.makeBox(size: sideSize, material: sideMaterial, cornerRadius: 0.035)
        left.position = SIMD3<Float>(-sideX, y, 0)
        staticRoot.addChild(left)

        let right = World3DRenderResources.makeBox(size: sideSize, material: sideMaterial, cornerRadius: 0.035)
        right.position = SIMD3<Float>(sideX, y, 0)
        staticRoot.addChild(right)
    }

    private func addDuskBackdrop(for gridSize: GridSize) {
        let boardWidth = terrainWidth(for: gridSize)
        let boardDepth = terrainDepth(for: gridSize)
        addOpenSea(boardWidth: boardWidth, boardDepth: boardDepth)

        // A few translucent clouds scattered around the island at varied
        // heights and depths — not a row on the horizon.
        addCloudCluster(center: SIMD3<Float>(-boardWidth * 0.95, tileSize * 2.6, -boardDepth * 0.55), scale: 0.80)
        addCloudCluster(center: SIMD3<Float>(boardWidth * 0.80, tileSize * 3.1, boardDepth * 0.40), scale: 0.60)
        addCloudCluster(center: SIMD3<Float>(boardWidth * 0.30, tileSize * 2.2, -boardDepth * 1.10), scale: 0.48)
    }

    private func addOpenSea(boardWidth: Float, boardDepth: Float) {
        // Sized independently of the board so the sea has no visible edge at
        // any yaw/zoom; the visible ground region stays inside the camera far
        // plane (28) even at max zoom-out on ultra-wide windows.
        let seaSpan = tileSize * 100
        let waterHeight: Float = 0.018
        // Surface at -0.16 keeps the earth plate/skirt band (top ~-0.085)
        // visibly above the waterline so the island reads as rising from it.
        let waterY: Float = -0.169

        let sea = World3DRenderResources.makeBox(
            size: SIMD3<Float>(seaSpan, waterHeight, seaSpan),
            material: matte(palette.waterOpen, roughness: 0.68)
        )
        sea.position.y = waterY
        staticRoot.addChild(sea)

        let surfaceY = waterY + waterHeight / 2

        // Stylized cartoon water: one static plane with faint ripple arcs
        // plus a very subtle translucent copy drifting on top. Kept low
        // contrast so the sea reads calm, not scaly.
        if let waveTexture = makeCartoonWaveTexture() {
            let planeMesh = MeshResource.generatePlane(width: seaSpan, depth: seaSpan)
            let tiles = SIMD2<Float>(repeating: seaSpan / (tileSize * 2.2))

            let surface = ModelEntity(mesh: planeMesh, materials: [waveMaterial(texture: waveTexture, tiles: tiles, opacity: 1)])
            surface.position.y = surfaceY + 0.001
            staticRoot.addChild(surface)

            let drift = ModelEntity(mesh: planeMesh, materials: [waveMaterial(texture: waveTexture, tiles: tiles * 1.27, opacity: 0.14)])
            drift.position.y = surfaceY + 0.004
            staticRoot.addChild(drift)
            addDriftAnimation(to: drift, offset: SIMD3<Float>(tileSize * 0.6, 0, tileSize * 0.4), duration: 9)
        }

        let islandShadow = World3DRenderResources.makeBox(
            size: SIMD3<Float>(boardWidth + tileSize * 1.5, 0.008, boardDepth + tileSize * 1.5),
            material: matte(palette.waterShadow, roughness: 0.60),
            cornerRadius: 0.42
        )
        islandShadow.position.y = surfaceY + 0.006
        staticRoot.addChild(islandShadow)

        addWaterSheen(
            width: boardWidth + tileSize * 4.5,
            depth: boardDepth + tileSize * 4.5,
            y: islandShadow.position.y + 0.006
        )

        spawnBoats(boardWidth: boardWidth, boardDepth: boardDepth, waterY: surfaceY + 0.012)
    }

    private func addWaterSheen(width: Float, depth: Float, y: Float) {
        let sheenMaterial = matte(palette.waterSheen, roughness: 0.26)
        let positions: [SIMD3<Float>] = [
            SIMD3<Float>(-width * 0.26, y, -depth * 0.40),
            SIMD3<Float>(width * 0.24, y, -depth * 0.33),
            SIMD3<Float>(-width * 0.34, y, depth * 0.36),
            SIMD3<Float>(width * 0.30, y, depth * 0.28)
        ]

        for (index, position) in positions.enumerated() {
            let sheen = World3DRenderResources.makeBox(
                size: SIMD3<Float>(tileSize * (0.48 + Float(index % 2) * 0.18), 0.006, tileSize * 0.035),
                material: sheenMaterial,
                cornerRadius: tileSize * 0.008
            )
            sheen.position = position
            sheen.orientation = simd_quatf(angle: 0.12 + Float(index) * 0.21, axis: SIMD3<Float>(0, 1, 0))
            staticRoot.addChild(sheen)
            addDriftAnimation(
                to: sheen,
                offset: SIMD3<Float>(tileSize * 0.14, 0, tileSize * (0.05 + Float(index % 3) * 0.04)),
                duration: 2.6 + Double(index) * 0.7
            )
        }
    }

    // MARK: - Boats

    // A boat that cruises waypoint-to-waypoint around the coastline and
    // occasionally puts in at the town pier. Legs are single transform
    // animations; a 1 Hz timer only picks the next waypoint, so the cost is
    // negligible.
    private struct BoatCruiser {
        let entity: Entity
        let speed: Float          // world units per second
        let radiusScale: Float
        var angle: Float          // current position angle around the island
        var nextLegAt: Date
        var isVisitingDock = false
        var lastDockTime = Date.distantPast
    }

    private func spawnBoats(boardWidth: Float, boardDepth: Float, waterY: Float) {
        boatCruisers.removeAll()
        boatWaterY = waterY
        boatBaseRadius = SIMD2<Float>(
            boardWidth / 2 + tileSize * 2.3,
            boardDepth / 2 + tileSize * 2.3
        )

        // Two small boats and one larger trader, each with its own pace,
        // route radius, and starting point.
        let specs: [(scale: Float, speed: Float, angle: Float, radiusScale: Float)] = [
            (1.0, 0.075, 0.6, 1.0),
            (0.85, 0.060, 2.8, 1.18),
            (1.55, 0.048, 4.5, 1.45)
        ]
        for spec in specs {
            let boat = makeBoat(scale: spec.scale)
            boat.position = cruiseWaypoint(angle: spec.angle, radiusScale: spec.radiusScale)
            staticRoot.addChild(boat)
            boatCruisers.append(BoatCruiser(
                entity: boat,
                speed: spec.speed,
                radiusScale: spec.radiusScale,
                angle: spec.angle,
                nextLegAt: Date().addingTimeInterval(Double.random(in: 0...2))
            ))
        }

        if boatTimer == nil {
            boatTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                let renderer = self
                Task { @MainActor in renderer?.tickBoats() }
            }
        }
    }

    private func tickBoats() {
        let now = Date()
        for index in boatCruisers.indices where now >= boatCruisers[index].nextLegAt {
            startNextLeg(boatIndex: index, now: now)
        }
    }

    private func startNextLeg(boatIndex: Int, now: Date) {
        var boat = boatCruisers[boatIndex]
        var dwell = TimeInterval(Float.random(in: 0.5...2.5))
        let target: SIMD3<Float>

        if boat.isVisitingDock {
            // Done at the pier; head back out and resume the route.
            boat.isVisitingDock = false
            boat.angle += Float.random(in: 0.5...0.85)
            target = cruiseWaypoint(angle: boat.angle, radiusScale: boat.radiusScale)
        } else if let dock = pierDockPoint,
                  now.timeIntervalSince(boat.lastDockTime) > 45,
                  abs(angleDelta(atan2(dock.x, dock.z) - boat.angle)) < 0.55,
                  Int.random(in: 0..<3) == 0 {
            // Passing the pier side of the island: put in for a short stop.
            target = dock
            dwell = TimeInterval(Float.random(in: 4...9))
            boat.isVisitingDock = true
            boat.lastDockTime = now
        } else {
            boat.angle += Float.random(in: 0.45...0.8)
            target = cruiseWaypoint(angle: boat.angle, radiusScale: boat.radiusScale)
        }

        let current = boat.entity.position
        let duration = TimeInterval(max(2, simd_distance(current, target) / boat.speed))
        var transform = boat.entity.transform
        transform.translation = target
        transform.rotation = simd_quatf(angle: atan2(target.x - current.x, target.z - current.z), axis: SIMD3<Float>(0, 1, 0))
        boat.entity.move(to: transform, relativeTo: boat.entity.parent, duration: duration, timingFunction: .easeInOut)
        boat.nextLegAt = now.addingTimeInterval(duration + dwell)
        boatCruisers[boatIndex] = boat
    }

    // Waypoints sit on a jittered ellipse around the island; the minimum
    // radius keeps every leg's straight line clear of the coastline.
    private func cruiseWaypoint(angle: Float, radiusScale: Float) -> SIMD3<Float> {
        let jitter = Float.random(in: 0.94...1.14)
        return SIMD3<Float>(
            sin(angle) * boatBaseRadius.x * radiusScale * jitter,
            boatWaterY,
            cos(angle) * boatBaseRadius.y * radiusScale * jitter
        )
    }

    private func updatePierDockPoint(town: Town) {
        guard let pier = town.buildings.first(where: { $0.kind == .pier }) else {
            pierDockPoint = nil
            return
        }
        let center = position(for: pier.coordinate)
        // Same nearest-edge priority the pier model uses to face the sea.
        let left = pier.coordinate.x
        let right = gridSize.columns - 1 - pier.coordinate.x
        let top = pier.coordinate.y
        let bottom = gridSize.rows - 1 - pier.coordinate.y
        let minimum = min(left, right, top, bottom)
        let outward: SIMD3<Float>
        if bottom == minimum {
            outward = SIMD3<Float>(0, 0, 1)
        } else if top == minimum {
            outward = SIMD3<Float>(0, 0, -1)
        } else if right == minimum {
            outward = SIMD3<Float>(1, 0, 0)
        } else {
            outward = SIMD3<Float>(-1, 0, 0)
        }
        var point = center + outward * (tileSize * 1.75)
        point.y = boatWaterY
        pierDockPoint = point
    }

    private func angleDelta(_ value: Float) -> Float {
        var delta = value.truncatingRemainder(dividingBy: .pi * 2)
        if delta > .pi { delta -= .pi * 2 }
        if delta < -.pi { delta += .pi * 2 }
        return delta
    }

    private func makeBoat(scale: Float) -> Entity {
        let boat = Entity()
        // Hull and rig live on an inner bobber so the boat rocks gently
        // while the outer entity travels.
        let bobber = Entity()
        boat.addChild(bobber)

        let hull = World3DRenderResources.makeBox(
            size: SIMD3<Float>(tileSize * 0.16, tileSize * 0.055, tileSize * 0.38) * scale,
            material: matte(NSColor(red: 0.44, green: 0.31, blue: 0.22, alpha: 1), roughness: 0.86),
            cornerRadius: tileSize * 0.02 * scale
        )
        bobber.addChild(hull)

        let mast = World3DRenderResources.makeCylinder(
            radius: tileSize * 0.012 * scale,
            height: tileSize * 0.30 * scale,
            material: matte(NSColor(red: 0.42, green: 0.30, blue: 0.22, alpha: 1), roughness: 0.90)
        )
        mast.position.y = tileSize * 0.17 * scale
        bobber.addChild(mast)

        let sail = World3DRenderResources.makeBox(
            size: SIMD3<Float>(tileSize * 0.016, tileSize * 0.20, tileSize * 0.15) * scale,
            material: matte(NSColor(red: 0.94, green: 0.92, blue: 0.86, alpha: 1), roughness: 0.92),
            cornerRadius: tileSize * 0.008
        )
        sail.position = SIMD3<Float>(0, tileSize * 0.19, tileSize * 0.075) * scale
        bobber.addChild(sail)

        addDriftAnimation(
            to: bobber,
            offset: SIMD3<Float>(0, 0.010 * scale, 0),
            duration: Double.random(in: 2.2...3.4)
        )
        return boat
    }

    // Slow autoreversing drift; GPU-side, so no per-frame CPU work.
    private func addDriftAnimation(to entity: Entity, offset: SIMD3<Float>, duration: TimeInterval) {
        var to = entity.transform
        to.translation += offset
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

    private func waveMaterial(texture: TextureResource, tiles: SIMD2<Float>, opacity: Float) -> PhysicallyBasedMaterial {
        let sampler = MTLSamplerDescriptor()
        sampler.sAddressMode = .repeat
        sampler.tAddressMode = .repeat
        sampler.minFilter = .linear
        sampler.magFilter = .linear
        sampler.mipFilter = .linear

        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: .white, texture: .init(texture, sampler: .init(sampler)))
        // High roughness + low specular keep the sun from flaring off the
        // water at glancing camera angles.
        material.roughness = 0.62
        material.specular = 0.15
        material.metallic = 0.0
        material.textureCoordinateTransform = .init(scale: tiles)
        if opacity < 1 {
            material.blending = .transparent(opacity: .init(floatLiteral: opacity))
        }
        return material
    }

    // One texture per theme for the app's lifetime; regenerating it on every
    // scaffold rebuild (town switches) wasted CPU and allocations.
    private static var waveTextureCache: [WorldTheme: TextureResource] = [:]

    // Hand-drawn-style tiling texture: water base with offset rows of pale
    // wave arcs, matching the flat-color cartoon look of the tiles.
    private func makeCartoonWaveTexture() -> TextureResource? {
        if let cached = Self.waveTextureCache[WorldTheme.current] {
            return cached
        }
        let size = 256
        guard let context = CGContext(
            data: nil,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        let base = palette.waterOpen.usingColorSpace(.deviceRGB) ?? palette.waterOpen
        context.setFillColor(base.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: size, height: size))

        // Single faint stroke pass: sparse thin arcs a touch lighter than
        // the base color, so the water shimmers instead of looking scaled.
        let arcColor = blend(base, with: World3DRenderer.rgbWhite, amount: 0.13)
        context.setLineCap(.round)
        context.setStrokeColor(arcColor.cgColor)
        context.setLineWidth(2.5)

        let rows = 5
        let rowHeight = CGFloat(size) / CGFloat(rows)
        let waveSpacing: CGFloat = CGFloat(size) / 5
        for row in 0..<rows {
            let y = rowHeight * (CGFloat(row) + 0.5)
            let xOffset = row.isMultiple(of: 2) ? 0 : waveSpacing / 2
            var x = -waveSpacing + xOffset
            while x < CGFloat(size) + waveSpacing {
                context.addArc(
                    center: CGPoint(x: x, y: y),
                    radius: waveSpacing * 0.24,
                    startAngle: .pi * 0.15,
                    endAngle: .pi * 0.85,
                    clockwise: false
                )
                context.strokePath()
                x += waveSpacing
            }
        }

        guard let image = context.makeImage() else { return nil }
        let texture = try? TextureResource(image: image, options: .init(semantic: .color))
        Self.waveTextureCache[WorldTheme.current] = texture
        return texture
    }

    private func addCloudCluster(center: SIMD3<Float>, scale: Float) {
        // Slightly translucent so the clouds blend into the sky.
        let cloudMaterial = matte(palette.cloud.withAlphaComponent(0.70), roughness: 1.0)
        let puffs: [(SIMD3<Float>, Float, SIMD3<Float>, SimpleMaterial)] = [
            (SIMD3<Float>(-0.12, -0.01, 0), 0.17, SIMD3<Float>(1.7, 0.46, 0.30), cloudMaterial),
            (SIMD3<Float>(0.02, 0.03, 0.02), 0.22, SIMD3<Float>(1.9, 0.52, 0.32), cloudMaterial),
            (SIMD3<Float>(0.15, 0.00, -0.01), 0.15, SIMD3<Float>(1.6, 0.42, 0.28), cloudMaterial)
        ]

        for puff in puffs {
            let cloud = World3DRenderResources.makeSphere(
                radius: tileSize * puff.1 * scale,
                material: puff.3,
                scale: puff.2
            )
            cloud.position = center + puff.0 * (tileSize * scale)
            staticRoot.addChild(cloud)
        }
    }

    // Subtle gold edge frame — no filled slab covering the tile.
    private func showSelection(at coordinate: GridCoordinate) {
        let outline = makeTileOutline(color: NSColor(red: 1.0, green: 0.80, blue: 0.34, alpha: 0.95), thickness: 0.045)
        outline.name = "world3d_selection"
        outline.position = position(for: coordinate) + SIMD3<Float>(0, 0.050 + tileElevation(for: coordinate), 0)
        overlayRoot.addChild(outline)
    }

    private func removeSelection() {
        overlayRoot.children
            .filter { $0.name == "world3d_selection" }
            .forEach { $0.removeFromParent() }
    }

    private func position(for coordinate: GridCoordinate) -> SIMD3<Float> {
        let spacing = tileSize + tileGap
        let centeredX = Float(coordinate.x) - Float(gridSize.columns - 1) / 2
        let centeredZ = Float(coordinate.y) - Float(gridSize.rows - 1) / 2
        return SIMD3<Float>(centeredX * spacing, 0, centeredZ * spacing)
    }

    private func material(for content: World3DTileSnapshot.Content, coordinate: GridCoordinate) -> SimpleMaterial {
        switch content {
        case .water:
            let ripple = CGFloat(stablePercent(coordinate, salt: 88)) / 700
            return matte(blend(palette.tileWater, with: World3DRenderer.rgbWhite, amount: ripple), roughness: 0.30)
        default:
            let variant = CGFloat(stablePercent(coordinate, salt: 211)) / 700
            return matte(blend(palette.tileGround, with: World3DRenderer.rgbWhite, amount: variant), roughness: 0.91)
        }
    }

    private func blend(_ color: NSColor, with tint: NSColor, amount: CGFloat) -> NSColor {
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

    private func matte(_ color: NSColor, roughness: Float, metallic: Bool = false) -> SimpleMaterial {
        World3DRenderResources.material(color, roughness: roughness, metallic: metallic)
    }

    private func tileElevation(for coordinate: GridCoordinate) -> Float {
        Float(stablePercent(coordinate, salt: 509)) / 100 * 0.018
    }

    private func terrainWidth(for gridSize: GridSize) -> Float {
        Float(gridSize.columns) * tileSize + Float(gridSize.columns - 1) * tileGap
    }

    private func terrainDepth(for gridSize: GridSize) -> Float {
        Float(gridSize.rows) * tileSize + Float(gridSize.rows - 1) * tileGap
    }

    // The FPS sample dips whenever the main run loop is busy (clicks, tile
    // placement), so quality used to flap and reset the scaffold — a full
    // scene rebuild on input, visible as lighting/water jitter. Now a switch
    // needs two consecutive readings ~12s apart, applies only to future tile
    // builds, and never rebuilds the scaffold.
    private func updateVisualQuality() {
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

    private func reportDiagnosticsIfNeeded() {
        let now = Date()
        guard now.timeIntervalSince(lastDiagnosticsReportTime) > 4 else { return }
        lastDiagnosticsReportTime = now
        World3DDiagnostics.report(entityRoot: boardRoot, terrainRoot: staticRoot, quality: visualQuality)
    }

    private func stablePercent(_ coordinate: GridCoordinate, salt: Int) -> Int {
        let raw = coordinate.x * 73_856_093 ^ coordinate.y * 19_349_663 ^ salt * 83_492_791
        return abs(raw % 100)
    }

    private func signature(townID: UUID, gridSize: GridSize, layout: TownBiomeLayout) -> String {
        let sides = BiomeSide.allCases
            .map { side in "\(side.rawValue):\(layout.biome(on: side)?.rawValue ?? "none")" }
            .joined(separator: "|")
        return "\(townID.uuidString)|\(gridSize.columns)x\(gridSize.rows)|\(sides)|\(WorldTheme.current.rawValue)"
    }
}
