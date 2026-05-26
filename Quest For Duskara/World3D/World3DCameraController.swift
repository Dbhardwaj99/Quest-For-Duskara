import RealityKit
import UIKit

@MainActor
final class World3DCameraController: NSObject, UIGestureRecognizerDelegate {
    private let camera = PerspectiveCamera()
    private weak var view: UIView?

    private var yaw: Float = .pi / 4
    private var pitch: Float = 0.78
    private var distance: Float = 6.2
    private var panStartYaw: Float = .pi / 4
    private var panStartPitch: Float = 0.78
    private var pinchStartDistance: Float = 6.2

    private let minDistance: Float = 3.4
    private let maxDistance: Float = 9.2
    private let minPitch: Float = 0.38
    private let maxPitch: Float = 1.18

    func install(in arView: ARView) {
        view = arView
        camera.camera.fieldOfViewInDegrees = 42
        arView.scene.anchors.first?.addChild(camera)
        updateCamera()

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.maximumNumberOfTouches = 1
        pan.delegate = self
        arView.addGestureRecognizer(pan)

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        pinch.delegate = self
        arView.addGestureRecognizer(pinch)
    }

    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        guard let view else { return }
        switch recognizer.state {
        case .began:
            panStartYaw = yaw
            panStartPitch = pitch
        case .changed:
            let translation = recognizer.translation(in: view)
            yaw = panStartYaw - Float(translation.x) * 0.008
            pitch = min(maxPitch, max(minPitch, panStartPitch + Float(translation.y) * 0.006))
            updateCamera()
        default:
            break
        }
    }

    @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        switch recognizer.state {
        case .began:
            pinchStartDistance = distance
        case .changed:
            distance = min(maxDistance, max(minDistance, pinchStartDistance / Float(recognizer.scale)))
            updateCamera()
        default:
            break
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }

    private func updateCamera() {
        let horizontalDistance = cos(pitch) * distance
        let position = SIMD3<Float>(
            sin(yaw) * horizontalDistance,
            sin(pitch) * distance,
            cos(yaw) * horizontalDistance
        )
        camera.look(at: SIMD3<Float>(0, 0, 0), from: position, relativeTo: nil)
    }
}
