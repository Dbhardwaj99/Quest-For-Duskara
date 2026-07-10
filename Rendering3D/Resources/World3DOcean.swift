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

    init(islandHalfExtents: SIMD2<Float>, span: Float, deepColor: NSColor) {
        let mesh = Self.makeRingMesh(islandHalfExtents: islandHalfExtents, outerRadius: span / 2)

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

    // MARK: - Mesh

    private static func makeRingMesh(islandHalfExtents: SIMD2<Float>, outerRadius: Float) -> MeshResource {
        // Ring offsets from the shoreline: tucked slightly under the island
        // skirt, dense through the foam/ripple band, widening to the horizon.
        var offsets: [Float] = []
        var offset: Float = -0.20
        while offset < 1.5 { offsets.append(offset); offset += 0.06 }
        while offset < 10 { offsets.append(offset); offset += 0.35 }
        while offset < outerRadius { offsets.append(offset); offset *= 1.4 }
        offsets.append(outerRadius)

        let segments = 128
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var uvs: [SIMD2<Float>] = []
        positions.reserveCapacity(offsets.count * segments)

        for ringOffset in offsets {
            for segment in 0..<segments {
                let angle = Float(segment) / Float(segments) * .pi * 2
                let direction = SIMD2<Float>(sin(angle), cos(angle))
                // Distance from center to the island rectangle's edge along
                // this direction, then push out radially by the ring offset.
                let edgeScale = 1 / max(abs(direction.x) / islandHalfExtents.x, abs(direction.y) / islandHalfExtents.y)
                let point = direction * (edgeScale + ringOffset)
                positions.append(SIMD3<Float>(point.x, 0, point.y))
                normals.append(SIMD3<Float>(0, 1, 0))
                uvs.append(SIMD2<Float>(rectDistance(point, halfExtents: islandHalfExtents), 0))
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
                let d = outer + next
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

    /// Signed distance from a point to the island rectangle (negative inside).
    private static func rectDistance(_ point: SIMD2<Float>, halfExtents: SIMD2<Float>) -> Float {
        let q = SIMD2<Float>(abs(point.x), abs(point.y)) - halfExtents
        let outside = simd_length(simd_max(q, SIMD2<Float>(0, 0)))
        let inside = min(max(q.x, q.y), 0)
        return outside + inside
    }
}
