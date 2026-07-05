import RealityKit
import AppKit

enum World3DVisualQuality: String {
    case low
    case medium
    case high

    static var adaptive: World3DVisualQuality {
        adaptive(recentFPS: World3DDiagnostics.lastFPS)
    }

    static func adaptive(recentFPS: Double) -> World3DVisualQuality {
        let thermalQuality: World3DVisualQuality
        switch ProcessInfo.processInfo.thermalState {
        case .serious, .critical:
            thermalQuality = .low
        case .fair:
            thermalQuality = .medium
        case .nominal:
            thermalQuality = .high
        @unknown default:
            thermalQuality = .medium
        }

        if ProcessInfo.processInfo.physicalMemory < 3_500_000_000 {
            return lower(thermalQuality, .medium)
        }

        guard recentFPS > 1 else { return thermalQuality }
        if recentFPS < 42 {
            return .low
        }
        if recentFPS < 54 {
            return lower(thermalQuality, .medium)
        }
        return thermalQuality
    }

    private static func lower(_ lhs: World3DVisualQuality, _ rhs: World3DVisualQuality) -> World3DVisualQuality {
        lhs.rank <= rhs.rank ? lhs : rhs
    }

    private var rank: Int {
        switch self {
        case .low: 0
        case .medium: 1
        case .high: 2
        }
    }

    var terrainTextureCount: Int {
        switch self {
        case .low: 1
        case .medium: 2
        case .high: 3
        }
    }

    var terrainDecorationMultiplier: Float {
        switch self {
        case .low: 0.38
        case .medium: 0.62
        case .high: 0.78
        }
    }

    var microDetailMultiplier: Float {
        switch self {
        case .low: 0.46
        case .medium: 0.68
        case .high: 0.82
        }
    }
}

@MainActor
enum World3DDiagnostics {
    private(set) static var rendererInitCount = 0
    private(set) static var rendererDeinitCount = 0
    private(set) static var activeARViewCount = 0
    private(set) static var tileRebuildCount = 0
    private(set) static var lastFPS: Double = 0

    static func rendererDidInit() {
        rendererInitCount += 1
        logLifecycle("renderer init")
    }

    static func rendererDidDeinit() {
        rendererDeinitCount += 1
        logLifecycle("renderer deinit")
    }

    static func arViewDidAppear() {
        activeARViewCount += 1
        logLifecycle("ARView active")
    }

    static func arViewDidDisappear() {
        activeARViewCount = max(0, activeARViewCount - 1)
        logLifecycle("ARView inactive")
    }

    static func tileDidRebuild() {
        tileRebuildCount += 1
    }

    static func recordFPS(_ fps: Double) {
        lastFPS = fps
    }

    static func report(entityRoot: Entity, terrainRoot: Entity, quality: World3DVisualQuality) {
        let total = countEntities(in: entityRoot)
        let models = countModelEntities(in: entityRoot)
        let terrain = countEntities(in: terrainRoot)
        debugPrint(
            "World3D diagnostics:",
            "quality=\(quality.rawValue)",
            "entities=\(total)",
            "modelEntities=\(models)",
            "estimatedDrawCalls=\(models)",
            "materials=\(World3DRenderResources.cachedMaterialCount)",
            "terrainEntities=\(terrain)",
            "tileRebuilds=\(tileRebuildCount)",
            "fps=\(String(format: "%.1f", lastFPS))",
            "thermal=\(ProcessInfo.processInfo.thermalState)"
        )
    }

    private static func logLifecycle(_ event: String) {
        debugPrint(
            "World3D lifecycle:",
            event,
            "rendererInit=\(rendererInitCount)",
            "rendererDeinit=\(rendererDeinitCount)",
            "activeARViews=\(activeARViewCount)"
        )
    }

    private static func countEntities(in entity: Entity) -> Int {
        1 + entity.children.reduce(0) { $0 + countEntities(in: $1) }
    }

    private static func countModelEntities(in entity: Entity) -> Int {
        (entity is ModelEntity ? 1 : 0) + entity.children.reduce(0) { $0 + countModelEntities(in: $1) }
    }
}

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
