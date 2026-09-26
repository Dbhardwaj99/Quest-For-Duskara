import RealityKit
import AppKit

enum World3DRenderResources {
    enum BoxDetail: Hashable {
        case sharp
        case soft
        case rounded
        case hero

        init(cornerRadius: Float, maxDimension: Float) {
            guard cornerRadius > 0, maxDimension > 0 else {
                self = .sharp
                return
            }

            let ratio = cornerRadius / maxDimension
            if maxDimension < 0.052 || ratio < 0.018 {
                self = .sharp
            } else if ratio < 0.055 {
                self = .soft
            } else if ratio < 0.12 {
                self = .rounded
            } else {
                self = .hero
            }
        }

        var cornerRadius: Float {
            switch self {
            case .sharp: 0
            case .soft: 0.035
            case .rounded: 0.075
            case .hero: 0.13
            }
        }
    }

    fileprivate struct MaterialKey: Hashable {
        let red: Int
        let green: Int
        let blue: Int
        let alpha: Int
        let roughness: Int
        let metallic: Bool
    }

    private static var boxMeshes: [BoxDetail: MeshResource] = [:]
    private static var sphereMeshes: [Int: MeshResource] = [:]
    private static var unitConeMesh: MeshResource?
    private static var unitCylinderMesh: MeshResource?
    private static var materialCache: [MaterialKey: SimpleMaterial] = [:]
    private(set) static var visualQuality: World3DVisualQuality = .high

    static var cachedMaterialCount: Int {
        materialCache.count
    }

    static func configureVisualQuality(_ quality: World3DVisualQuality) {
        visualQuality = quality
    }

    static func makeBox(
        size: SIMD3<Float>,
        material: SimpleMaterial,
        cornerRadius: Float = 0
    ) -> ModelEntity {
        let detail = BoxDetail(cornerRadius: cornerRadius, maxDimension: max(size.x, max(size.y, size.z)))
        let entity = ModelEntity(mesh: boxMesh(detail: detail), materials: [material])
        entity.scale = size
        return entity
    }

    static func makeSphere(
        radius: Float,
        material: SimpleMaterial,
        scale: SIMD3<Float> = SIMD3<Float>(repeating: 1)
    ) -> ModelEntity {
        // Detail by size: RealityKit's sphere is 8k triangles whatever its
        // size. These keep every outline within a fraction of a pixel of a
        // true circle even at the closest camera zoom.
        let reach = radius * max(scale.x, max(scale.y, scale.z))
        let segments = reach <= 0.02 ? 24 : (reach <= 0.06 ? 40 : 64)
        let entity = ModelEntity(mesh: sphereMesh(segments: segments), materials: [material])
        entity.scale = SIMD3<Float>(repeating: radius * 2) * scale
        return entity
    }

    static func makeCone(
        radius: Float,
        height: Float,
        material: SimpleMaterial
    ) -> ModelEntity {
        let mesh: MeshResource
        if let cached = unitConeMesh {
            mesh = cached
        } else {
            mesh = MeshResource.generateCone(height: 1, radius: 0.5)
            unitConeMesh = mesh
        }
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.scale = SIMD3<Float>(radius * 2, height, radius * 2)
        return entity
    }

    static func makeCylinder(
        radius: Float,
        height: Float,
        material: SimpleMaterial
    ) -> ModelEntity {
        let mesh: MeshResource
        if let cached = unitCylinderMesh {
            mesh = cached
        } else {
            mesh = MeshResource.generateCylinder(height: 1, radius: 0.5)
            unitCylinderMesh = mesh
        }
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.scale = SIMD3<Float>(radius * 2, height, radius * 2)
        return entity
    }

    static func material(_ color: NSColor, roughness: Float, metallic: Bool = false) -> SimpleMaterial {
        let key = MaterialKey(color: color, roughness: roughness, metallic: metallic)
        if let cached = materialCache[key] {
            return cached
        }

        let material = SimpleMaterial(
            color: color,
            roughness: MaterialScalarParameter(floatLiteral: roughness),
            isMetallic: metallic
        )
        materialCache[key] = material
        return material
    }

    private static func boxMesh(detail: BoxDetail) -> MeshResource {
        if let cached = boxMeshes[detail] {
            return cached
        }

        let mesh = detail == .sharp
            ? MeshResource.generateBox(size: SIMD3<Float>(repeating: 1))
            : roundedBoxMesh(cornerRadius: detail.cornerRadius)
        boxMeshes[detail] = mesh
        return mesh
    }

    private static func sphereMesh(segments: Int) -> MeshResource {
        if let cached = sphereMeshes[segments] {
            return cached
        }

        let mesh = uvSphereMesh(segments: segments)
        sphereMeshes[segments] = mesh
        return mesh
    }

    /// Unit sphere with `segments` around and half that pole to pole — the
    /// same angular step both ways (RealityKit's doubles it top to bottom).
    private static func uvSphereMesh(segments: Int) -> MeshResource {
        let rings = segments / 2
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        for ring in 0...rings {
            let theta = Float(ring) / Float(rings) * .pi
            for segment in 0...segments {
                let phi = Float(segment) / Float(segments) * 2 * .pi
                let normal = SIMD3<Float>(sin(theta) * sin(phi), cos(theta), sin(theta) * cos(phi))
                normals.append(normal)
                positions.append(normal * 0.5)
            }
        }
        var indices: [UInt32] = []
        for ring in 0..<rings {
            for segment in 0..<segments {
                let a = UInt32(ring * (segments + 1) + segment)
                let b = a + UInt32(segments + 1)
                indices.append(contentsOf: [a, b, a + 1, a + 1, b, b + 1])
            }
        }
        var descriptor = MeshDescriptor(name: "world3d_sphere")
        descriptor.positions = MeshBuffer(positions)
        descriptor.normals = MeshBuffer(normals)
        descriptor.primitives = .triangles(indices)
        return try! MeshResource.generate(from: [descriptor])
    }

    /// Unit box with rounded edges and corners: each surface point is the
    /// inner box's nearest point pushed out by `cornerRadius`. Eight segments
    /// per quarter arc hold every edge within a fraction of a pixel of a true
    /// arc at the closest zoom; RealityKit's own rounded box spends 13k
    /// triangles on the same shape.
    private static func roundedBoxMesh(cornerRadius radius: Float) -> MeshResource {
        let inner = 0.5 - radius
        let band = 4 // grid lines per rounded band: each face holds half an edge's quarter arc
        // Face grid lines, spaced evenly in angle through the rounded bands.
        var stops: [Float] = []
        for step in 0...band {
            stops.append(-inner - radius * tan(Float(band - step) / Float(band) * .pi / 4))
        }
        for step in 0...band {
            stops.append(inner + radius * tan(Float(step) / Float(band) * .pi / 4))
        }

        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        for axis in 0..<3 {
            for side: Float in [-1, 1] {
                let u = (axis + 1) % 3, v = (axis + 2) % 3
                let base = UInt32(positions.count)
                for su in stops {
                    for sv in stops {
                        var point = SIMD3<Float>(repeating: 0)
                        point[axis] = side * 0.5
                        point[u] = su
                        point[v] = sv
                        let core = simd_clamp(point, SIMD3(repeating: -inner), SIMD3(repeating: inner))
                        let normal = simd_normalize(point - core)
                        normals.append(normal)
                        positions.append(core + normal * radius)
                    }
                }
                // (u, v, axis) is right-handed, so counterclockwise in (u, v)
                // faces +axis; flip the winding for the -axis face.
                let count = UInt32(stops.count)
                for i in 0..<(count - 1) {
                    for j in 0..<(count - 1) {
                        let a = base + i * count + j, b = a + count, c = b + 1, d = a + 1
                        indices.append(contentsOf: side > 0 ? [a, b, c, a, c, d] : [a, c, b, a, d, c])
                    }
                }
            }
        }
        var descriptor = MeshDescriptor(name: "world3d_rounded_box")
        descriptor.positions = MeshBuffer(positions)
        descriptor.normals = MeshBuffer(normals)
        descriptor.primitives = .triangles(indices)
        return try! MeshResource.generate(from: [descriptor])
    }
}

private extension World3DRenderResources.MaterialKey {
    init(color: NSColor, roughness: Float, metallic: Bool) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        // getRed raises on non-RGB colorspaces (grayscale, catalog), and
        // only at runtime — convert first so a stray NSColor(white:) can
        // never crash the scene build.
        let rgb = color.usingColorSpace(.deviceRGB) ?? color
        rgb.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        self.red = Self.quantized(red)
        self.green = Self.quantized(green)
        self.blue = Self.quantized(blue)
        self.alpha = Int((alpha * 255).rounded())
        self.roughness = Int((roughness * 20).rounded()) * 50
        self.metallic = metallic
    }

    private static func quantized(_ component: CGFloat) -> Int {
        let value = Int((component * 255).rounded())
        return (value / 10) * 10
    }
}

private extension SIMD3 where Scalar == Float {
    static func * (lhs: SIMD3<Float>, rhs: SIMD3<Float>) -> SIMD3<Float> {
        SIMD3<Float>(lhs.x * rhs.x, lhs.y * rhs.y, lhs.z * rhs.z)
    }
}
