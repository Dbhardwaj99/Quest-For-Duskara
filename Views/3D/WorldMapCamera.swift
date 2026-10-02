import Foundation
import simd

/// Shared by the RealityKit camera and SwiftUI labels: every overlay follows
/// the same perspective projection while flying, panning, and zooming.
struct WorldMapCamera {
    let size: CGSize
    let aspectRatio: Double
    let activePoint: SIMD2<Float>
    var travelProgress: Double = 1
    var initialYaw: Float = .pi / 4

    static let fieldOfView: Float = 35
    static let yaw: Float = .pi / 4
    static let mapPitch: Float = 0.86
    static let worldWidth: Float = 30

    var worldDepth: Float {
        let aspect = aspectRatio.isFinite && aspectRatio > 0 ? aspectRatio : 1.45
        return Self.worldWidth / Float(aspect) / sin(Self.mapPitch)
    }
    private var mapRight: SIMD3<Float> { SIMD3(cos(Self.yaw), 0, -sin(Self.yaw)) }
    private var mapAlong: SIMD3<Float> { SIMD3(sin(Self.yaw), 0, cos(Self.yaw)) }
    var yaw: Float {
        let delta = atan2(sin(Self.yaw - initialYaw), cos(Self.yaw - initialYaw))
        return initialYaw + delta * progress
    }
    var right: SIMD3<Float> { SIMD3(cos(yaw), 0, -sin(yaw)) }
    var along: SIMD3<Float> { SIMD3(sin(yaw), 0, cos(yaw)) }
    var progress: Float { Float(min(1, max(0, travelProgress))) }
    var pitch: Float { 1.20 + (Self.mapPitch - 1.20) * progress }
    var up: SIMD3<Float> { -along * sin(pitch) + SIMD3(0, cos(pitch), 0) }
    var towardCamera: SIMD3<Float> { along * cos(pitch) + SIMD3(0, sin(pitch), 0) }
    var focus: SIMD3<Float> { position(x: activePoint.x, y: activePoint.y) * (1 - progress) + SIMD3(0, 0.02, 0) }
    var distance: Float {
        let tanHalf = tan(Self.fieldOfView * .pi / 360)
        let viewportAspect = max(0.2, Float(size.width / max(1, size.height)))
        let halfWidth = Self.worldWidth / 2 + 2.1
        let halfDepth = worldDepth / 2 + 2.1
        let fit = halfDepth * cos(Self.mapPitch)
            + max(halfWidth / viewportAspect, halfDepth * sin(Self.mapPitch)) / tanHalf
        return 14 + (fit - 14) * progress
    }
    var eye: SIMD3<Float> { focus + towardCamera * distance }

    func position(x: Float, y: Float) -> SIMD3<Float> {
        mapRight * ((x - 0.5) * Self.worldWidth) + mapAlong * ((y - 0.5) * worldDepth)
    }

    func point(x: Double, y: Double, height: Float = 0) -> CGPoint {
        project(position(x: Float(x), y: Float(y)) + SIMD3(0, height, 0))
    }

    func project(_ position: SIMD3<Float>) -> CGPoint {
        let delta = position - focus
        let depth = max(0.01, distance - simd_dot(delta, towardCamera))
        let halfHeight = depth * tan(Self.fieldOfView * .pi / 360)
        let pixels = Float(size.height) / (2 * halfHeight)
        return CGPoint(x: size.width / 2 + CGFloat(simd_dot(delta, right) * pixels),
                       y: size.height / 2 - CGFloat(simd_dot(delta, up) * pixels))
    }
}

/// The map's close camera starts at the town's current heading.
@MainActor
enum WorldMapFlightPose {
    static var yaw: Float = .pi / 4
}
