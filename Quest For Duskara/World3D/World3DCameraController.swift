import RealityKit
import UIKit

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
final class World3DCameraController: NSObject, UIGestureRecognizerDelegate {
    private let camera = PerspectiveCamera()
    private weak var view: UIView?

    private let target = SIMD3<Float>(0, 0, 0)
    private var yaw: Float = .pi / 4
    private var pitch: Float = 0.74
    private var distance: Float = 6.6
    private var rotateStartYaw: Float = .pi / 4
    private var rotateStartPitch: Float = 0.74
    private var pinchStartDistance: Float = 6.6
    private var activeGestureIDs: Set<ObjectIdentifier> = []
    private var inertiaDisplayLink: CADisplayLink?
    private var yawVelocity: Float = 0
    private var pitchVelocity: Float = 0
    private var distanceVelocity: Float = 0
    private(set) var isInteracting = false

    private let minDistance: Float = 3.2
    private let maxDistance: Float = 8.86
    private let minPitch: Float = 0.56
    private let maxPitch: Float = 1.02

    deinit {
        inertiaDisplayLink?.invalidate()
    }

    func install(in arView: ARView, bounds _: World3DCameraBounds, parent: Entity) {
        view = arView
        camera.camera = PerspectiveCameraComponent(near: 0.01, far: 28, fieldOfViewInDegrees: 35)
        parent.addChild(camera)
        sanitizeState()
        updateCamera()
        let rotate = UIPanGestureRecognizer(target: self, action: #selector(handleRotate(_:)))
        rotate.maximumNumberOfTouches = 1
        rotate.delegate = self
        arView.addGestureRecognizer(rotate)

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        pinch.delegate = self
        arView.addGestureRecognizer(pinch)
    }

    @objc private func handleRotate(_ recognizer: UIPanGestureRecognizer) {
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

    @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        switch recognizer.state {
        case .began:
            beginInteraction(recognizer)
            pinchStartDistance = distance
        case .changed:
            let scale = max(0.35, min(2.8, safeFloat(Float(recognizer.scale), fallback: 1)))
            distance = pinchStartDistance / scale
            distanceVelocity = -pinchStartDistance * safeFloat(Float(recognizer.velocity), fallback: 0) / (scale * scale)
            sanitizeState()
            updateCamera()
        default:
            endInteraction(recognizer)
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }

    private func updateCamera() {
        sanitizeState()
        let horizontalDistance = cos(pitch) * distance
        let position = target + SIMD3<Float>(
            sin(yaw) * horizontalDistance,
            sin(pitch) * distance,
            cos(yaw) * horizontalDistance
        )
        let lookTarget = target + SIMD3<Float>(0, 0.02, 0)
        camera.look(at: lookTarget, from: position, relativeTo: nil)
    }

    private func beginInteraction(_ recognizer: UIGestureRecognizer) {
        stopInertia()
        activeGestureIDs.insert(ObjectIdentifier(recognizer))
        isInteracting = true
    }

    private func endInteraction(_ recognizer: UIGestureRecognizer) {
        activeGestureIDs.remove(ObjectIdentifier(recognizer))
        guard activeGestureIDs.isEmpty else { return }

        if hasMeaningfulVelocity {
            startInertia()
        } else {
            isInteracting = false
            updateCamera()
        }
    }

    private func startInertia() {
        isInteracting = true
        inertiaDisplayLink?.invalidate()
        let displayLink = CADisplayLink(target: self, selector: #selector(stepInertia(_:)))
        displayLink.add(to: .main, forMode: .common)
        inertiaDisplayLink = displayLink
    }

    private func stopInertia() {
        inertiaDisplayLink?.invalidate()
        inertiaDisplayLink = nil
        yawVelocity = 0
        pitchVelocity = 0
        distanceVelocity = 0
    }

    @objc private func stepInertia(_ displayLink: CADisplayLink) {
        let dt = min(1 / 30, max(1 / 120, Float(displayLink.targetTimestamp - displayLink.timestamp)))
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
        distance = min(maxDistance, max(minDistance, safeFloat(distance, fallback: 6.6)))
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

}
