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
    private static var collisionBoxes: [SIMD3<Float>: ShapeResource] = [:]
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
        let entity = ModelEntity(mesh: sphereMesh(segmentBudget: 12), materials: [material])
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

    static func collisionBox(size: SIMD3<Float>) -> ShapeResource {
        if let cached = collisionBoxes[size] {
            return cached
        }
        let shape = ShapeResource.generateBox(size: size)
        collisionBoxes[size] = shape
        return shape
    }

    private static func boxMesh(detail: BoxDetail) -> MeshResource {
        if let cached = boxMeshes[detail] {
            return cached
        }

        let mesh = MeshResource.generateBox(
            size: SIMD3<Float>(repeating: 1),
            cornerRadius: detail.cornerRadius
        )
        boxMeshes[detail] = mesh
        return mesh
    }

    private static func sphereMesh(segmentBudget: Int) -> MeshResource {
        if let cached = sphereMeshes[segmentBudget] {
            return cached
        }

        let mesh = MeshResource.generateSphere(radius: 0.5)
        sphereMeshes[segmentBudget] = mesh
        return mesh
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
