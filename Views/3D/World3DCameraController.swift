import RealityKit
import AppKit
import QuartzCore

struct World3DCameraBounds {
    let halfWidth: Float
    let halfDepth: Float
    let focusInset: Float

    var maxTargetX: Float {
        max(0, halfWidth - focusInset)
    }

    var maxTargetZ: Float {
        max(0, halfDepth - focusInset)
    }
}

@MainActor
final class World3DCameraController: NSObject, NSGestureRecognizerDelegate {
    let camera = PerspectiveCamera()
    private weak var view: NSView?

    // Zoom tuning — `defaultDistance` is the starting zoom; min/max clamp
    // pinch zoom. Watch the "Camera zoom" console log to pick values.
    static let defaultDistance: Float = 5.2
    static let minDistance: Float = 2.7
    static let maxDistance: Float = 6.4
    static let zoomSensitivity: Float = 0.45

    private let target = SIMD3<Float>(0, 0, 0)
    private var yaw: Float = .pi / 4
    private var pitch: Float = 0.74
    private var distance: Float = World3DCameraController.defaultDistance
    private var rotateStartYaw: Float = .pi / 4
    private var rotateStartPitch: Float = 0.74
    private var pinchStartDistance: Float = World3DCameraController.defaultDistance
    private var activeGestureIDs: Set<ObjectIdentifier> = []
    private var isCoasting = false
    private var orbitSpeed: Float = 0
    // Slow cinematic showcase: one full revolution in ~75 seconds.
    private let orbitTargetSpeed: Float = 2 * .pi / 75
    private(set) var isOrbiting = false
    private var yawVelocity: Float = 0
    private var pitchVelocity: Float = 0
    private var distanceVelocity: Float = 0
    private var lastLoggedDistance: Float = World3DCameraController.defaultDistance
    private(set) var isInteracting = false
    private var isInputEnabled = true
    private var worldMapProgress: Float = 0
    private var worldMapTarget: Float = 0
    private var worldMapStartProgress: Float = 0
    private var worldMapTravelStartedAt: CFTimeInterval = 0
    private var worldMapTravelDuration: Double = 0
    var onWorldMapTravelEnded: (() -> Void)?
    var isAtTown: Bool { worldMapProgress == 0 && worldMapTarget == 0 }
    var isWorldMapCovered: Bool { worldMapTarget == 1 && worldMapProgress >= 0.72 }
    /// Fired when a gesture (and its inertia) fully ends, so the view can
    /// replay any renders skipped while interacting.
    var onInteractionEnded: (() -> Void)?

    private let minDistance = World3DCameraController.minDistance
    private let maxDistance = World3DCameraController.maxDistance
    private let minPitch: Float = 0.56
    private let maxPitch: Float = 1.02

    func install(in view: NSView, bounds _: World3DCameraBounds, parent: Entity) {
        self.view = view
        camera.camera = PerspectiveCameraComponent(near: 0.01, far: 28, fieldOfViewInDegrees: 35)
        parent.addChild(camera)
        sanitizeState()
        updateCamera()
        let rotate = NSPanGestureRecognizer(target: self, action: #selector(handleRotate(_:)))
        rotate.delegate = self
        view.addGestureRecognizer(rotate)

        let pinch = NSMagnificationGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        pinch.delegate = self
        view.addGestureRecognizer(pinch)
    }

    /// Called once per rendered frame: coasts after a flick and advances the
    /// debug orbit, both paced by the (≤ 60 fps) render loop.
    func advance(by deltaTime: Float) {
        guard deltaTime > 0, deltaTime < 1 else { return }
        advanceWorldMapTravel(at: CACurrentMediaTime())
        guard isInputEnabled, isAtTown else { return }
        if isCoasting {
            stepInertia(deltaTime)
        }
        if isOrbiting {
            stepOrbit(deltaTime: deltaTime)
        }
    }

    @objc private func handleRotate(_ recognizer: NSPanGestureRecognizer) {
        guard isInputEnabled, let view else { return }
        switch recognizer.state {
        case .began:
            beginInteraction(recognizer)
            rotateStartYaw = yaw
            rotateStartPitch = pitch
        case .changed:
            let translation = recognizer.translation(in: view)
            let velocity = recognizer.velocity(in: view)
            yaw = rotateStartYaw - safeFloat(Float(translation.x), fallback: 0) * 0.0056
            pitch = rotateStartPitch + safeFloat(Float(translation.y), fallback: 0) * 0.0042
            yawVelocity = -safeFloat(Float(velocity.x), fallback: 0) * 0.0056
            pitchVelocity = safeFloat(Float(velocity.y), fallback: 0) * 0.0042
            sanitizeState()
            updateCamera()
        default:
            endInteraction(recognizer)
        }
    }

    @objc private func handlePinch(_ recognizer: NSMagnificationGestureRecognizer) {
        guard isInputEnabled else { return }
        switch recognizer.state {
        case .began:
            beginInteraction(recognizer)
            pinchStartDistance = distance
        case .changed:
            let scale = max(0.35, min(2.8, safeFloat(1 + Float(recognizer.magnification) * Self.zoomSensitivity, fallback: 1)))
            distance = pinchStartDistance / scale
            distanceVelocity = 0
            sanitizeState()
            updateCamera()
        default:
            endInteraction(recognizer)
        }
    }

    func gestureRecognizer(_ gestureRecognizer: NSGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: NSGestureRecognizer) -> Bool {
        true
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: NSGestureRecognizer) -> Bool {
        isInputEnabled
    }

    func setInputEnabled(_ enabled: Bool) {
        guard enabled != isInputEnabled else { return }
        isInputEnabled = enabled
        if enabled == false {
            stopInertia()
            activeGestureIDs.removeAll()
            isInteracting = false
            onInteractionEnded?()
        }
    }

    /// Camera travel is an offset from the saved town pose, so descending
    /// restores exactly the player's previous rotation, pitch and zoom.
    func setWorldMapProgress(_ progress: Float, duration: Double) {
        let progress = min(1, max(0, safeFloat(progress, fallback: 0)))
        guard progress != worldMapTarget || duration == 0 && progress != worldMapProgress else { return }
        let now = CACurrentMediaTime()
        // Catch up while paused before reversing, so descent shares the same
        // starting progress as the cloud and map compositing animation.
        advanceWorldMapTravel(at: now)
        worldMapStartProgress = worldMapProgress
        worldMapTarget = progress
        worldMapTravelStartedAt = now
        worldMapTravelDuration = max(0, duration)
        if worldMapTravelDuration == 0 {
            worldMapProgress = progress
            updateCamera()
        }
    }

    private func advanceWorldMapTravel(at time: CFTimeInterval) {
        guard worldMapProgress != worldMapTarget else { return }
        let elapsed = worldMapTravelDuration > 0 ? min(1, max(0, (time - worldMapTravelStartedAt) / worldMapTravelDuration)) : 1
        let t = Float(elapsed)
        let eased = t * t * (3 - 2 * t)
        worldMapProgress = elapsed >= 1 ? worldMapTarget : worldMapStartProgress + (worldMapTarget - worldMapStartProgress) * eased
        updateCamera()
        if elapsed >= 1 { onWorldMapTravelEnded?() }
    }

    /// Debug-only cinematic orbit around the island. Keeps the current pitch
    /// and distance, only advancing yaw, driven by the render loop.
    func setOrbiting(_ enabled: Bool) {
        guard enabled != isOrbiting else { return }
        isOrbiting = enabled
        orbitSpeed = 0
    }

    private func stepOrbit(deltaTime dt: Float) {
        // User gestures (and their inertia) win; orbit resumes from wherever
        // the camera lands.
        guard isInteracting == false else { return }
        // Ease angular speed up from rest so the orbit starts without a jump.
        orbitSpeed += (orbitTargetSpeed - orbitSpeed) * min(1, dt * 1.2)
        yaw += orbitSpeed * dt
        updateCamera()
    }

    private func updateCamera() {
        sanitizeState()
        WorldMapFlightPose.yaw = yaw
        logZoomIfChanged()
        let t = min(1, worldMapProgress / 0.36)
        let rise = t * t * (3 - 2 * t)
        let travelDistance = distance + (14 - distance) * rise
        let travelPitch = pitch + (1.20 - pitch) * rise
        let horizontalDistance = cos(travelPitch) * travelDistance
        let position = target + SIMD3<Float>(
            sin(yaw) * horizontalDistance,
            sin(travelPitch) * travelDistance,
            cos(yaw) * horizontalDistance
        )
        let lookTarget = target + SIMD3<Float>(0, 0.02, 0)
        camera.look(at: lookTarget, from: position, relativeTo: nil)
    }

    private func beginInteraction(_ recognizer: NSGestureRecognizer) {
        stopInertia()
        activeGestureIDs.insert(ObjectIdentifier(recognizer))
        isInteracting = true
    }

    private func endInteraction(_ recognizer: NSGestureRecognizer) {
        activeGestureIDs.remove(ObjectIdentifier(recognizer))
        guard activeGestureIDs.isEmpty else { return }

        if hasMeaningfulVelocity {
            startInertia()
        } else {
            isInteracting = false
            updateCamera()
            onInteractionEnded?()
        }
    }

    private func startInertia() {
        isInteracting = true
        isCoasting = true
    }

    private func stopInertia() {
        isCoasting = false
        yawVelocity = 0
        pitchVelocity = 0
        distanceVelocity = 0
    }

    private func stepInertia(_ dt: Float) {
        yaw += yawVelocity * dt
        pitch += pitchVelocity * dt
        distance += distanceVelocity * dt
        sanitizeState()
        updateCamera()

        let decay = pow(Float(0.055), dt)
        yawVelocity *= decay
        pitchVelocity *= decay
        distanceVelocity *= decay

        if hasMeaningfulVelocity == false {
            stopInertia()
            isInteracting = false
            updateCamera()
            onInteractionEnded?()
        }
    }

    private var hasMeaningfulVelocity: Bool {
        abs(yawVelocity) > 0.035
            || abs(pitchVelocity) > 0.025
            || abs(distanceVelocity) > 0.040
    }

    private func sanitizeState() {
        yaw = normalizedAngle(safeFloat(yaw, fallback: .pi / 4))
        pitch = min(maxPitch, max(minPitch, safeFloat(pitch, fallback: 0.74)))
        distance = min(maxDistance, max(minDistance, safeFloat(distance, fallback: Self.defaultDistance)))
    }

    private func normalizedAngle(_ value: Float) -> Float {
        guard value.isFinite else { return .pi / 4 }
        let twoPi = Float.pi * 2
        var angle = value.truncatingRemainder(dividingBy: twoPi)
        if angle < -.pi {
            angle += twoPi
        } else if angle > .pi {
            angle -= twoPi
        }
        return angle
    }

    private func safeFloat(_ value: Float, fallback: Float) -> Float {
        value.isFinite ? value : fallback
    }

    private func logZoomIfChanged() {
        guard abs(distance - lastLoggedDistance) > 0.01 else { return }
        lastLoggedDistance = distance
        let percent = (maxDistance - distance) / (maxDistance - minDistance) * 100
        print(String(format: "Camera zoom: distance=%.2f (%.0f%% zoomed in, min=%.2f max=%.2f)", distance, percent, minDistance, maxDistance))
    }

}
