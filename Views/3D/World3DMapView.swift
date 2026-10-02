import SwiftUI
import RealityKit
import AppKit
import QuartzCore

/// One native scene for the entire archipelago. The existing town factories
/// supply its models; resource/army ticks do not rebuild the islands.
struct World3DMapView: NSViewControllerRepresentable {
    let towns: [Town]
    let nodes: [WorldTownNode]
    let routes: [SeaRoute]
    let gridSize: GridSize
    let camera: WorldMapCamera
    let theme: WorldTheme
    let contrast: Double
    let travelDuration: Double
    var isActive = true

    func makeNSViewController(context: Context) -> World3DMapViewController {
        World3DMapViewController()
    }

    func updateNSViewController(_ controller: World3DMapViewController, context: Context) {
        controller.update(towns: towns, nodes: nodes, routes: routes, gridSize: gridSize,
                          camera: camera, theme: theme, contrast: contrast, travelDuration: travelDuration)
        controller.setActive(isActive)
    }
}

@MainActor
final class World3DMapViewController: NSViewController {
    private var renderView: World3DRenderView?
    private var builder: World3DRenderer?
    private let scene = Entity()
    private let cloudRoot = Entity()
    private let camera = PerspectiveCamera()
    private var islands: [UUID: Entity] = [:]
    private var signatures: [UUID: String] = [:]
    private var ocean: World3DOcean?
    private var environmentSignature = ""
    private var boats: [(entity: Entity, from: SIMD3<Float>, to: SIMD3<Float>, seed: Int)] = []
    private var routeSignature = ""
    private var elapsed: Float = 0
    private var pose: WorldMapCamera?
    private var travelTarget = 0.0
    private var travelProgress = 0.0
    private var travelStart = 0.0
    private var travelStartedAt: CFTimeInterval = 0
    private var travelDuration = 1.8
    private var initialYaw: Float = .pi / 4
    private var needsWarmFrame = true
    private var isActive = true

    func setActive(_ active: Bool) {
        isActive = active
        renderView?.isPaused = !active || (travelProgress == 0 && travelTarget == 0 && !needsWarmFrame)
    }

    override func loadView() { view = NSView() }

    override func viewDidLoad() {
        super.viewDidLoad()
        do {
            let renderView = World3DRenderView(renderer: try RealityRenderer())
            renderView.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(renderView)
            NSLayoutConstraint.activate([
                renderView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                renderView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                renderView.topAnchor.constraint(equalTo: view.topAnchor),
                renderView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
            let builder = World3DRenderer(renderView: renderView)
            builder.anchor.addChild(scene)
            scene.addChild(cloudRoot)
            builder.anchor.addChild(camera)
            builder.sun.shadow = DirectionalLightComponent.Shadow(maximumDistance: 80, depthBias: 2)
            camera.camera = PerspectiveCameraComponent(near: 0.05, far: 1000, fieldOfViewInDegrees: WorldMapCamera.fieldOfView)
            renderView.renderer.activeCamera = camera
            renderView.onFrame = { [weak self] dt in
                self?.advanceCamera(at: CACurrentMediaTime())
                self?.advanceBoats(dt)
            }
            self.renderView = renderView
            self.builder = builder
        } catch {
            debugPrint("World map: RealityKit renderer unavailable:", error)
        }
    }

    func update(towns: [Town], nodes: [WorldTownNode], routes: [SeaRoute], gridSize: GridSize,
                camera pose: WorldMapCamera, theme: WorldTheme, contrast: Double, travelDuration: Double) {
        _ = view // Preserve the first update even before AppKit loads the view.
        guard let builder, let renderView else { return }
        self.pose = pose
        if travelTarget != pose.travelProgress {
            advanceCamera(at: CACurrentMediaTime())
            travelStart = travelProgress
            travelStartedAt = CACurrentMediaTime()
            self.travelDuration = travelDuration
            travelTarget = pose.travelProgress
            initialYaw = WorldMapFlightPose.yaw
        }
        if travelDuration == 0 { travelProgress = travelTarget }
        renderView.isPaused = !isActive || (travelProgress == 0 && travelTarget == 0 && !needsWarmFrame)
        let nodeByID = Dictionary(uniqueKeysWithValues: nodes.map { ($0.townID, $0) })
        let liveIDs = Set(nodeByID.keys)
        for id in Set(islands.keys).subtracting(liveIDs) {
            islands.removeValue(forKey: id)?.removeFromParent()
            signatures[id] = nil
        }
        for town in towns {
            guard let node = nodeByID[town.id] else { continue }
            let signature = builder.signature(townID: town.id, gridSize: gridSize, layout: town.biomeLayout)
                + "|\(town.faction.rawValue)|" + town.buildings.map {
                    "\($0.coordinate.x),\($0.coordinate.y),\($0.kind.rawValue),\($0.level)"
                }.sorted().joined(separator: "|")
            if signatures[town.id] != signature {
                needsWarmFrame = true
                islands[town.id]?.removeFromParent()
                let island = builder.makeMapIsland(town: town, gridSize: gridSize)
                scene.addChild(island)
                islands[town.id] = island
                signatures[town.id] = signature
            }
            islands[town.id]?.position = pose.position(x: Float(node.x), y: Float(node.y))
        }

        let environment = "\(theme.rawValue)|\(contrast)|\(gridSize.columns)x\(gridSize.rows)|\(pose.aspectRatio)|"
            + nodes.map { "\($0.townID):\($0.x),\($0.y)" }.joined(separator: "|")
        if environmentSignature != environment {
            needsWarmFrame = true
            environmentSignature = environment
            ocean?.entity.removeFromParent()
            let halfExtents = SIMD2<Float>(builder.terrainWidth(for: gridSize) / 2, builder.terrainDepth(for: gridSize) / 2)
            let shorelines = nodes.map { node in
                let center = pose.position(x: Float(node.x), y: Float(node.y))
                return WorldOceanIsland(center: SIMD2(center.x, center.z), halfExtents: halfExtents,
                                        seed: World3DOcean.seed(for: node.townID))
            }
            let ocean = World3DOcean(islands: shorelines, tileSize: builder.tileSize,
                                    span: SIMD2(48, 48), deepColor: theme.palette.waterDeep)
            ocean.entity.position.y = -0.16
            scene.addChild(ocean.entity)
            self.ocean = ocean
            builder.applyEnvironment()
            // Native puffy clouds at the perimeter leave settlements readable.
            cloudRoot.children.forEach { $0.removeFromParent() }
            for (index, point) in [SIMD2<Float>(-0.12, -0.03), SIMD2(1.12, 0.07), SIMD2(-0.13, 1.16), SIMD2(1.16, 1.11)].enumerated() {
                var center = pose.position(x: point.x, y: point.y)
                center.y = 2.2 + Float(index % 2) * 0.8
                builder.addCloudCluster(center: center, scale: 5 + Float(index) * 0.5)
            }
            for cloud in Array(builder.staticRoot.children) {
                for puff in cloud.children { puff.position *= 0.60 }
                cloudRoot.addChild(cloud)
            }
        }
        let routesKey = environment + routes.filter(\.hasShip).map(\.id).joined(separator: "|")
        if routeSignature != routesKey {
            routeSignature = routesKey
            boats.forEach { $0.entity.removeFromParent() }
            boats = routes.filter(\.hasShip).map { route in
                let boat = builder.makeBoat(scale: route.isTrade ? 2.3 : 1.8)
                scene.addChild(boat)
                return (boat, pose.position(x: Float(route.from.x), y: Float(route.from.y)),
                        pose.position(x: Float(route.to.x), y: Float(route.to.y)), route.seed)
            }
            advanceBoats(0)
        }
    }

    private func advanceCamera(at time: CFTimeInterval) {
        guard isActive, var pose, let renderView, renderView.bounds.width > 0, renderView.bounds.height > 0 else { return }
        if travelProgress != travelTarget {
            let t = min(1, max(0, (time - travelStartedAt) / max(0.001, travelDuration)))
            let eased = t * t * (3 - 2 * t)
            travelProgress = travelStart + (travelTarget - travelStart) * eased
            if t == 1 { travelProgress = travelTarget }
        }
        // The two cameras meet above the same island before the map recedes.
        let local = min(1, max(0, (travelProgress - 0.58) / 0.42))
        pose.travelProgress = local * local * (3 - 2 * local)
        pose.initialYaw = initialYaw
        if needsWarmFrame && travelProgress == 0 {
            pose.travelProgress = 1
            needsWarmFrame = false
        }
        camera.look(at: pose.focus, from: pose.eye, relativeTo: nil)
        // One hidden full-map frame warms all materials before first reveal.
        renderView.isPaused = travelProgress == 0 && travelTarget == 0
    }

    private func advanceBoats(_ dt: Float) {
        elapsed += dt
        for boat in boats {
            let period = Float(24 + boat.seed % 7 * 3)
            let phase = (elapsed / period + Float(boat.seed % 100) / 100).truncatingRemainder(dividingBy: 1)
            let outbound = phase < 0.5
            let delta = boat.to - boat.from
            let length = simd_length(delta)
            guard length > 0.001 else { continue }
            // Stop outside the actual island footprint, including short lanes.
            let inset = min(0.42, 1.8 / length)
            let linear = outbound ? phase * 2 : 2 - phase * 2
            let eased = linear * linear * (3 - 2 * linear)
            let t = inset + eased * (1 - 2 * inset)
            let side = simd_normalize(SIMD3<Float>(-delta.z, 0, delta.x))
            let bend = side * min(1.0, simd_length(delta) * 0.12) * (boat.seed.isMultiple(of: 2) ? 1 : -1)
            boat.entity.position = SeaRoute.worldPoint(at: t, from: boat.from, to: boat.to, seed: boat.seed) + SIMD3(0, -0.14, 0)
            let heading = delta + bend * (4 - 8 * t)
            boat.entity.orientation = simd_quatf(angle: atan2(heading.x, heading.z) + (outbound ? 0 : .pi), axis: SIMD3(0, 1, 0))
        }
    }
}
