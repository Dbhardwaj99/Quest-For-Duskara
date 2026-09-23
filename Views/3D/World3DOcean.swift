import RealityKit
import AppKit
import Metal

/// One continuous living ocean plane (see docs/DESIGN_LANGUAGE.md).
///
/// The mesh is a set of concentric rings around the island footprint —
/// dense near the shoreline where foam, shallows, and ripples live, sparse
/// toward the horizon. Every vertex carries its distance to the shoreline
/// in uv0.x so OceanShaders.metal can tint depth and draw foam without
/// knowing the island's shape. Waves, foam, and fresnel are entirely
/// GPU-side; the only CPU work is a short 30 Hz tick while an interaction
/// ripple is expanding.
@MainActor
final class World3DOcean {
    let entity: ModelEntity

    private var material: CustomMaterial?
    private var rippleCenter = SIMD2<Float>(0, 0)
    private var rippleStartTime: TimeInterval = 0
    private var rippleTimer: Timer?
    private let rippleDuration: TimeInterval = 1.6

    init(islandHalfExtents: SIMD2<Float>, tileSize: Float, span: Float, deepColor: NSColor, seed: Int) {
        let mesh = Self.makeRingMesh(islandHalfExtents: islandHalfExtents, tileSize: tileSize, outerRadius: span / 2, seed: seed)

        if let custom = Self.makeCustomMaterial(deepColor: deepColor) {
            material = custom
            entity = ModelEntity(mesh: mesh, materials: [custom])
        } else {
            // ponytail: no Metal library (previews, odd configs) — flat matte
            // water keeps the scene renderable, just without waves/foam.
            entity = ModelEntity(mesh: mesh, materials: [World3DRenderResources.material(deepColor, roughness: 0.6)])
        }
    }

    deinit {
        rippleTimer?.invalidate()
    }

    /// Spawn an expanding circular ripple at a world XZ position. One active
    /// ripple at a time; a new interaction restarts the ring.
    // ponytail: single ripple slot — move centers into a small texture if
    // overlapping ripples ever matter.
    func ripple(at point: SIMD2<Float>) {
        guard material != nil else { return }
        rippleCenter = point
        rippleStartTime = CACurrentMediaTime()
        guard rippleTimer == nil else { return }
        rippleTimer = Timer.scheduledTimer(withTimeInterval: 1 / 30, repeats: true) { [weak self] _ in
            let ocean = self
            Task { @MainActor in ocean?.tickRipple() }
        }
    }

    private func tickRipple() {
        guard var material else { return }
        let age = CACurrentMediaTime() - rippleStartTime
        if age >= rippleDuration {
            rippleTimer?.invalidate()
            rippleTimer = nil
            material.custom.value = .zero
        } else {
            let progress = Float(age / rippleDuration)
            // Constant expansion speed, quadratic fade.
            let radius = 0.12 + progress * 1.5
            let strength = (1 - progress) * (1 - progress)
            material.custom.value = SIMD4<Float>(rippleCenter.x, rippleCenter.y, radius, strength)
        }
        self.material = material
        entity.model?.materials = [material]
    }

    private static func makeCustomMaterial(deepColor: NSColor) -> CustomMaterial? {
        guard let device = MTLCreateSystemDefaultDevice(),
              let library = device.makeDefaultLibrary() else { return nil }
        do {
            let surface = CustomMaterial.SurfaceShader(named: "oceanSurface", in: library)
            let geometry = CustomMaterial.GeometryModifier(named: "oceanGeometry", in: library)
            var material = try CustomMaterial(surfaceShader: surface, geometryModifier: geometry, lightingModel: .lit)
            material.baseColor = .init(tint: deepColor.usingColorSpace(.deviceRGB) ?? deepColor)
            material.custom.value = .zero
            return material
        } catch {
            debugPrint("World3DOcean: custom material unavailable, falling back:", error)
            return nil
        }
    }

    // MARK: - Coastline

    /// One contour for land, beach, and foam. The plot square fits inside it;
    /// the extra headlands and coves vary by town without changing placement.
    static func coastRadius(angle: Float, islandHalfExtents: SIMD2<Float>, tileSize: Float, seed: Int) -> Float {
        let phase = Float(seed % 997) / 997 * .pi * 2
        let a = islandHalfExtents.x + tileSize * (1.22 + 0.10 * sin(phase))
        let b = islandHalfExtents.y + tileSize * (1.22 + 0.10 * cos(phase * 1.7))
        let cosA = abs(cos(angle))
        let sinA = abs(sin(angle))
        let exponent: Float = 2.05
        let superellipse = pow(pow(cosA / b, exponent) + pow(sinA / a, exponent), -1 / exponent)
        let wobble = 0.15 * sin(angle * 3 + phase)
            + 0.095 * sin(angle * 5 + phase * 0.7)
            + 0.04 * sin(angle * 8 + phase * 1.3)
        let plotEdge = 1 / max(sinA / islandHalfExtents.x, cosA / islandHalfExtents.y)
        let shape = superellipse + wobble * tileSize
        let safe = plotEdge + tileSize * 0.30
        let rounding = tileSize * 0.16
        let transition = max(0, rounding - abs(shape - safe))
        return max(shape, safe) + transition * transition / (4 * rounding)
    }

    nonisolated static func seed(for townID: UUID) -> Int {
        townID.uuidString.utf8.reduce(0) { ($0 &* 31 &+ Int($1)) % 1_000_003 }
    }

    /// Flat where plots sit, then gently falling to an exposed soil edge.
    static func makeLand(islandHalfExtents: SIMD2<Float>, tileSize: Float, seed: Int, grass: RealityKit.Material, soil: RealityKit.Material) -> Entity {
        let segments = 160
        let root = Entity()
        var topPositions = [SIMD3<Float>(0, 0.004, 0)]
        var topNormals = [SIMD3<Float>(0, 1, 0)]
        for fraction in [Float(0.40), 0.72, 0.97, 1.0] {
            for segment in 0..<segments {
                let angle = Float(segment) / Float(segments) * .pi * 2
                let radius = coastRadius(angle: angle, islandHalfExtents: islandHalfExtents, tileSize: tileSize, seed: seed) - tileSize * 0.23
                let point = SIMD2<Float>(sin(angle), cos(angle)) * radius * fraction
                topPositions.append(SIMD3<Float>(point.x, fraction == 1 ? -0.055 : 0.004, point.y))
                topNormals.append(SIMD3<Float>(0, 1, 0))
            }
        }
        var topIndices: [UInt32] = []
        for segment in 0..<segments {
            let next = (segment + 1) % segments
            topIndices.append(contentsOf: [0, UInt32(1 + segment), UInt32(1 + next)])
        }
        for ring in 0..<3 {
            let start = 1 + ring * segments
            let outer = start + segments
            for segment in 0..<segments {
                let next = (segment + 1) % segments
                topIndices.append(contentsOf: [UInt32(start + segment), UInt32(outer + segment), UInt32(start + next),
                                               UInt32(start + next), UInt32(outer + segment), UInt32(outer + next)])
            }
        }
        var top = MeshDescriptor(name: "world3d_island_land")
        top.positions = MeshBuffer(topPositions)
        top.normals = MeshBuffer(topNormals)
        top.primitives = .triangles(topIndices)
        root.addChild(ModelEntity(mesh: try! MeshResource.generate(from: [top]), materials: [grass]))

        var soilPositions: [SIMD3<Float>] = []
        var soilNormals: [SIMD3<Float>] = []
        for (extra, y) in [(Float(0), Float(-0.055)), (tileSize * 0.035, Float(-0.12))] {
            for segment in 0..<segments {
                let angle = Float(segment) / Float(segments) * .pi * 2
                let radius = coastRadius(angle: angle, islandHalfExtents: islandHalfExtents, tileSize: tileSize, seed: seed) - tileSize * 0.23 + extra
                let direction = SIMD2<Float>(sin(angle), cos(angle))
                let point = direction * radius
                soilPositions.append(SIMD3<Float>(point.x, y, point.y))
                soilNormals.append(simd_normalize(SIMD3<Float>(direction.x, 0.35, direction.y)))
            }
        }
        var soilIndices: [UInt32] = []
        for segment in 0..<segments {
            let next = (segment + 1) % segments
            soilIndices.append(contentsOf: [UInt32(segment), UInt32(segments + segment), UInt32(next),
                                            UInt32(next), UInt32(segments + segment), UInt32(segments + next)])
        }
        var side = MeshDescriptor(name: "world3d_island_soil")
        side.positions = MeshBuffer(soilPositions)
        side.normals = MeshBuffer(soilNormals)
        side.primitives = .triangles(soilIndices)
        root.addChild(ModelEntity(mesh: try! MeshResource.generate(from: [side]), materials: [soil]))
        return root
    }

    /// A sandy shelf falling from the clay land edge to the waterline.
    static func makeBeach(islandHalfExtents: SIMD2<Float>, tileSize: Float, material: RealityKit.Material, seed: Int) -> ModelEntity {
        // (inward fraction from the coast toward the board, y height)
        let profile: [(inset: Float, y: Float)] = [
            (1.00, -0.078),
            (0.55, -0.105),
            (0.22, -0.135),
            (0.00, -0.152),
            (-0.45, -0.34)
        ]
        let segments = 160
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var uvs: [SIMD2<Float>] = []

        for stop in profile {
            for segment in 0..<segments {
                let angle = Float(segment) / Float(segments) * .pi * 2
                let direction = SIMD2<Float>(sin(angle), cos(angle))
                let coast = coastRadius(angle: angle, islandHalfExtents: islandHalfExtents, tileSize: tileSize, seed: seed)
                let inner = min(islandHalfExtents.x, islandHalfExtents.y) * 0.55
                let radius = stop.inset >= 0
                    ? inner + (coast - inner) * (1 - stop.inset)
                    : coast - stop.inset * tileSize
                let point = direction * radius
                positions.append(SIMD3<Float>(point.x, stop.y, point.y))
                // Tilt normals outward as the slope steepens so the mound
                // shades like sculpted clay rather than a flat sticker.
                let tilt: Float = stop.inset > 0.5 ? 0.12 : (stop.inset >= 0 ? 0.35 : 0.9)
                normals.append(simd_normalize(SIMD3<Float>(direction.x * tilt, 1, direction.y * tilt)))
                uvs.append(SIMD2<Float>(0, 0))
            }
        }

        var indices: [UInt32] = []
        for ring in 0..<(profile.count - 1) {
            let inner = UInt32(ring * segments)
            let outer = UInt32((ring + 1) * segments)
            for segment in 0..<segments {
                let next = UInt32((segment + 1) % segments)
                indices.append(contentsOf: [
                    inner + UInt32(segment), outer + UInt32(segment), inner + next,
                    inner + next, outer + UInt32(segment), outer + next
                ])
            }
        }

        var descriptor = MeshDescriptor(name: "world3d_beach")
        descriptor.positions = MeshBuffer(positions)
        descriptor.normals = MeshBuffer(normals)
        descriptor.textureCoordinates = MeshBuffer(uvs)
        descriptor.primitives = .triangles(indices)
        return ModelEntity(mesh: try! MeshResource.generate(from: [descriptor]), materials: [material])
    }

    // MARK: - Mesh

    private static func makeRingMesh(islandHalfExtents: SIMD2<Float>, tileSize: Float, outerRadius: Float, seed: Int) -> MeshResource {
        // Ring offsets from the shoreline: tucked slightly under the beach,
        // dense through the foam/ripple band, widening to the horizon.
        var offsets: [Float] = []
        var offset: Float = -0.30
        while offset < 1.5 { offsets.append(offset); offset += 0.06 }
        while offset < 10 { offsets.append(offset); offset += 0.35 }
        while offset < outerRadius { offsets.append(offset); offset *= 1.4 }
        offsets.append(outerRadius)

        let segments = 160
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var uvs: [SIMD2<Float>] = []
        positions.reserveCapacity(offsets.count * segments)

        for ringOffset in offsets {
            for segment in 0..<segments {
                let angle = Float(segment) / Float(segments) * .pi * 2
                let direction = SIMD2<Float>(sin(angle), cos(angle))
                let coast = coastRadius(angle: angle, islandHalfExtents: islandHalfExtents, tileSize: tileSize, seed: seed)
                let point = direction * (coast + ringOffset)
                positions.append(SIMD3<Float>(point.x, 0, point.y))
                normals.append(SIMD3<Float>(0, 1, 0))
                // uv0.x = distance past the shoreline; drives foam, shallows,
                // and wave fade in OceanShaders.metal.
                uvs.append(SIMD2<Float>(ringOffset, 0))
            }
        }

        var indices: [UInt32] = []
        indices.reserveCapacity((offsets.count - 1) * segments * 6)
        for ring in 0..<(offsets.count - 1) {
            let inner = UInt32(ring * segments)
            let outer = UInt32((ring + 1) * segments)
            for segment in 0..<segments {
                let next = UInt32((segment + 1) % segments)
                let a = inner + UInt32(segment)
                let b = inner + next
                let c = outer + UInt32(segment)
                let d = outer + UInt32(next)
                indices.append(contentsOf: [a, c, b, b, c, d])
            }
        }

        var descriptor = MeshDescriptor(name: "world3d_ocean")
        descriptor.positions = MeshBuffer(positions)
        descriptor.normals = MeshBuffer(normals)
        descriptor.textureCoordinates = MeshBuffer(uvs)
        descriptor.primitives = .triangles(indices)
        // Force-unwrap is safe: the descriptor is a well-formed static grid.
        return try! MeshResource.generate(from: [descriptor])
    }
}
