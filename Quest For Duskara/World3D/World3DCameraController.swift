import RealityKit
import UIKit

@MainActor
final class World3DCameraController: NSObject, UIGestureRecognizerDelegate {
    private let camera = PerspectiveCamera()
    private weak var view: UIView?

    private var target = SIMD3<Float>(0, 0, 0)
    private var yaw: Float = .pi / 4
    private var pitch: Float = 0.74
    private var distance: Float = 6.6
    private var rotateStartYaw: Float = .pi / 4
    private var rotateStartPitch: Float = 0.74
    private var panStartTarget = SIMD3<Float>(0, 0, 0)
    private var pinchStartDistance: Float = 6.6
    private var boardRadius: Float = 2.4
    private(set) var isInteracting = false

    private let minDistance: Float = 3.2
    private let maxDistance: Float = 9.2
    private let minPitch: Float = 0.48
    private let maxPitch: Float = 1.08

    func install(in arView: ARView, gridSize: GridSize) {
        view = arView
        boardRadius = max(Float(gridSize.columns), Float(gridSize.rows)) * 0.30
        camera.camera.fieldOfViewInDegrees = 35
        arView.scene.anchors.first?.addChild(camera)
        updateCamera(animated: false)
        let rotate = UIPanGestureRecognizer(target: self, action: #selector(handleRotate(_:)))
        rotate.maximumNumberOfTouches = 1
        rotate.delegate = self
        arView.addGestureRecognizer(rotate)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.minimumNumberOfTouches = 2
        pan.maximumNumberOfTouches = 2
        pan.delegate = self
        arView.addGestureRecognizer(pan)

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        pinch.delegate = self
        arView.addGestureRecognizer(pinch)
    }

    @objc private func handleRotate(_ recognizer: UIPanGestureRecognizer) {
        guard let view else { return }
        switch recognizer.state {
        case .began:
            isInteracting = true
            rotateStartYaw = yaw
            rotateStartPitch = pitch
        case .changed:
            let translation = recognizer.translation(in: view)
            yaw = rotateStartYaw - Float(translation.x) * 0.0056
            pitch = min(maxPitch, max(minPitch, rotateStartPitch + Float(translation.y) * 0.0042))
            updateCamera(animated: false)
        default:
            isInteracting = false
            updateCamera(animated: true)
        }
    }

    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        guard let view else { return }
        switch recognizer.state {
        case .began:
            isInteracting = true
            panStartTarget = target
        case .changed:
            let translation = recognizer.translation(in: view)
            let right = SIMD3<Float>(cos(yaw), 0, -sin(yaw))
            let forward = SIMD3<Float>(sin(yaw), 0, cos(yaw))
            let scale = max(0.003, distance * 0.0007)
            let nextTarget = panStartTarget - right * Float(translation.x) * scale + forward * Float(translation.y) * scale
            target = clampedTarget(nextTarget)
            updateCamera(animated: false)
        default:
            isInteracting = false
            updateCamera(animated: true)
        }
    }

    @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        switch recognizer.state {
        case .began:
            isInteracting = true
            pinchStartDistance = distance
        case .changed:
            distance = min(maxDistance, max(minDistance, pinchStartDistance / Float(recognizer.scale)))
            updateCamera(animated: false)
        default:
            isInteracting = false
            updateCamera(animated: true)
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }

    private func updateCamera(animated: Bool) {
        let horizontalDistance = cos(pitch) * distance
        let position = target + SIMD3<Float>(
            sin(yaw) * horizontalDistance,
            sin(pitch) * distance,
            cos(yaw) * horizontalDistance
        )
        let lookTarget = target + SIMD3<Float>(0, 0.02, 0)
        if animated {
            camera.move(to: Transform(matrix: lookAtTransform(from: position, to: lookTarget)), relativeTo: nil, duration: 0.22, timingFunction: .easeInOut)
        } else {
            camera.look(at: lookTarget, from: position, relativeTo: nil)
        }
    }

    private func clampedTarget(_ value: SIMD3<Float>) -> SIMD3<Float> {
        SIMD3<Float>(
            min(boardRadius, max(-boardRadius, value.x)),
            0,
            min(boardRadius, max(-boardRadius, value.z))
        )
    }

    private func lookAtTransform(from position: SIMD3<Float>, to target: SIMD3<Float>) -> simd_float4x4 {
        let forward = normalize(target - position)
        let right = normalize(cross(SIMD3<Float>(0, 1, 0), forward))
        let up = cross(forward, right)
        return simd_float4x4(columns: (
            SIMD4<Float>(right.x, right.y, right.z, 0),
            SIMD4<Float>(up.x, up.y, up.z, 0),
            SIMD4<Float>(forward.x, forward.y, forward.z, 0),
            SIMD4<Float>(position.x, position.y, position.z, 1)
        ))
    }
}
