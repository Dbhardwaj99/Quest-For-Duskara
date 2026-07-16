import RealityKit
import AppKit
import Combine

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
    private let camera = PerspectiveCamera()
    private weak var view: NSView?

    // Zoom tuning — `defaultDistance` is the starting zoom; min/max clamp
    // pinch zoom. Watch the "Camera zoom" console log to pick values.
    static let defaultDistance: Float = 3.0
    static let minDistance: Float = 2.4
    static let maxDistance: Float = 3.2
    static let zoomSensitivity: Float = 0.45

    private let target = SIMD3<Float>(0, 0, 0)
    private var yaw: Float = .pi / 4
    private var pitch: Float = 0.74
    private var distance: Float = World3DCameraController.defaultDistance
    private var rotateStartYaw: Float = .pi / 4
    private var rotateStartPitch: Float = 0.74
    private var pinchStartDistance: Float = World3DCameraController.defaultDistance
    private var activeGestureIDs: Set<ObjectIdentifier> = []
    private var inertiaTimer: Timer?
    private var orbitSubscription: Cancellable?
    private var orbitSpeed: Float = 0
    // Slow cinematic showcase: one full revolution in ~75 seconds.
    private let orbitTargetSpeed: Float = 2 * .pi / 75
    private(set) var isOrbiting = false
    private var yawVelocity: Float = 0
    private var pitchVelocity: Float = 0
    private var distanceVelocity: Float = 0
    private var lastLoggedDistance: Float = World3DCameraController.defaultDistance
    private(set) var isInteracting = false
    /// Fired when a gesture (and its inertia) fully ends, so the view can
    /// replay any renders skipped while interacting.
    var onInteractionEnded: (() -> Void)?

    private let minDistance = World3DCameraController.minDistance
    private let maxDistance = World3DCameraController.maxDistance
    private let minPitch: Float = 0.56
    private let maxPitch: Float = 1.02

    deinit {
        inertiaTimer?.invalidate()
        orbitSubscription?.cancel()
    }

    func install(in arView: ARView, bounds _: World3DCameraBounds, parent: Entity) {
        view = arView
        camera.camera = PerspectiveCameraComponent(near: 0.01, far: 28, fieldOfViewInDegrees: 35)
        parent.addChild(camera)
        sanitizeState()
        updateCamera()
        let rotate = NSPanGestureRecognizer(target: self, action: #selector(handleRotate(_:)))
        rotate.delegate = self
        arView.addGestureRecognizer(rotate)

        let pinch = NSMagnificationGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        pinch.delegate = self
        arView.addGestureRecognizer(pinch)
    }

    @objc private func handleRotate(_ recognizer: NSPanGestureRecognizer) {
        guard let view else { return }
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

    /// Debug-only cinematic orbit around the island. Keeps the current pitch
    /// and distance, only advancing yaw, driven by the RealityKit frame loop.
    func setOrbiting(_ enabled: Bool) {
        guard enabled != isOrbiting else { return }
        isOrbiting = enabled
        orbitSpeed = 0
        if enabled, let arView = view as? ARView {
            orbitSubscription = arView.scene.subscribe(to: SceneEvents.Update.self) { [weak self] event in
                let dt = Float(event.deltaTime)
                MainActor.assumeIsolated {
                    self?.stepOrbit(deltaTime: dt)
                }
            }
        } else {
            orbitSubscription?.cancel()
            orbitSubscription = nil
            isOrbiting = false
        }
    }

    private func stepOrbit(deltaTime dt: Float) {
        // User gestures (and their inertia) win; orbit resumes from wherever
        // the camera lands.
        guard isInteracting == false, dt > 0, dt < 1 else { return }
        // Ease angular speed up from rest so the orbit starts without a jump.
        orbitSpeed += (orbitTargetSpeed - orbitSpeed) * min(1, dt * 1.2)
        yaw += orbitSpeed * dt
        updateCamera()
    }

    private func updateCamera() {
        sanitizeState()
        logZoomIfChanged()
        let horizontalDistance = cos(pitch) * distance
        let position = target + SIMD3<Float>(
            sin(yaw) * horizontalDistance,
            sin(pitch) * distance,
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
        inertiaTimer?.invalidate()
        inertiaTimer = Timer.scheduledTimer(timeInterval: 1 / 60, target: self, selector: #selector(stepInertia(_:)), userInfo: nil, repeats: true)
    }

    private func stopInertia() {
        inertiaTimer?.invalidate()
        inertiaTimer = nil
        yawVelocity = 0
        pitchVelocity = 0
        distanceVelocity = 0
    }

    @objc private func stepInertia(_ timer: Timer) {
        let dt: Float = 1 / 60
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
