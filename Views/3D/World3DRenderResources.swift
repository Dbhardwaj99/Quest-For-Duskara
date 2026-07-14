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
