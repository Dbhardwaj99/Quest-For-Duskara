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

    init(islandHalfExtents: SIMD2<Float>, tileSize: Float, span: Float, deepColor: NSColor) {
        let mesh = Self.makeRingMesh(islandHalfExtents: islandHalfExtents, tileSize: tileSize, outerRadius: span / 2)

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

    /// The island's organic shoreline: a superellipse (rounded square) around
    /// the board with layered sine wobble so the beach width varies and the
    /// land reads as grown, not stamped. Shared by the beach mound and the
    /// ocean mesh so shader foam always hugs the actual coast.
    static func coastRadius(angle: Float, islandHalfExtents: SIMD2<Float>, tileSize: Float) -> Float {
        let a = islandHalfExtents.x + tileSize * 0.62
        let b = islandHalfExtents.y + tileSize * 0.62
        let cosA = abs(cos(angle))
        let sinA = abs(sin(angle))
        let exponent: Float = 3.2
        let superellipse = pow(pow(cosA / b, exponent) + pow(sinA / a, exponent), -1 / exponent)
        let wobble = 0.16 * sin(angle * 3 + 1.7) + 0.11 * sin(angle * 5 + 0.6) + 0.06 * sin(angle * 8 + 3.1)
        return superellipse + wobble * tileSize
    }

    /// The sandy beach mound the board sits on: radial rings from just under
    /// the tiles, sloping gently to the waterline and on below the surface.
    /// Replaces the old rectangular plate skirt.
    static func makeBeach(islandHalfExtents: SIMD2<Float>, tileSize: Float, material: RealityKit.Material) -> ModelEntity {
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
                let coast = coastRadius(angle: angle, islandHalfExtents: islandHalfExtents, tileSize: tileSize)
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

    private static func makeRingMesh(islandHalfExtents: SIMD2<Float>, tileSize: Float, outerRadius: Float) -> MeshResource {
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
                let coast = coastRadius(angle: angle, islandHalfExtents: islandHalfExtents, tileSize: tileSize)
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
