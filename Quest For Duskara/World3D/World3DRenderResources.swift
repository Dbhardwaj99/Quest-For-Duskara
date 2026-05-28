import RealityKit
import UIKit

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
            if ratio < 0.018 {
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
    private static var materialCache: [MaterialKey: SimpleMaterial] = [:]
    private static var collisionBoxes: [SIMD3<Float>: ShapeResource] = [:]

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

    static func material(_ color: UIColor, roughness: Float, metallic: Bool = false) -> SimpleMaterial {
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
    init(color: UIColor, roughness: Float, metallic: Bool) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        self.red = Int((red * 255).rounded())
        self.green = Int((green * 255).rounded())
        self.blue = Int((blue * 255).rounded())
        self.alpha = Int((alpha * 255).rounded())
        self.roughness = Int((roughness * 1000).rounded())
        self.metallic = metallic
    }
}

private extension SIMD3 where Scalar == Float {
    static func * (lhs: SIMD3<Float>, rhs: SIMD3<Float>) -> SIMD3<Float> {
        SIMD3<Float>(lhs.x * rhs.x, lhs.y * rhs.y, lhs.z * rhs.z)
    }
}
