import Foundation
import simd

// Run from the repository root:
// swiftc Views/3D/WorldMapCamera.swift Tools/check_world_map_camera.swift -o /tmp/check_world_map_camera && /tmp/check_world_map_camera
@main
struct CheckWorldMapCamera {
    static func matrixProjection(_ point: SIMD3<Float>, camera: WorldMapCamera) -> CGPoint {
        // Independent right-handed look-at and perspective matrices.
        let back = simd_normalize(camera.eye - camera.focus)
        let right = simd_normalize(simd_cross(SIMD3<Float>(0, 1, 0), back))
        let up = simd_cross(back, right)
        let view = simd_float4x4(columns: (
            SIMD4(right.x, up.x, back.x, 0),
            SIMD4(right.y, up.y, back.y, 0),
            SIMD4(right.z, up.z, back.z, 0),
            SIMD4(-simd_dot(right, camera.eye), -simd_dot(up, camera.eye), -simd_dot(back, camera.eye), 1)
        ))
        let f = 1 / tan(WorldMapCamera.fieldOfView * .pi / 360)
        let near: Float = 0.05, far: Float = 300
        let perspective = simd_float4x4(columns: (
            SIMD4(f / Float(camera.size.width / camera.size.height), 0, 0, 0),
            SIMD4(0, f, 0, 0),
            SIMD4(0, 0, -(far + near) / (far - near), -1),
            SIMD4(0, 0, -2 * far * near / (far - near), 0)
        ))
        let clip = perspective * view * SIMD4(point, 1)
        return CGPoint(x: camera.size.width * CGFloat(clip.x / clip.w + 1) / 2,
                       y: camera.size.height * CGFloat(1 - clip.y / clip.w) / 2)
    }

    static func main() {
        let sizes = [CGSize(width: 1440, height: 900), CGSize(width: 720, height: 1280),
                     CGSize(width: 2560, height: 720), CGSize(width: 800, height: 800)]
        let active = SIMD2<Float>(0.18, 0.72)
        var comparisons = 0
        for size in sizes {
            for progress in [-1.0, 0, 0.27, 0.5, 1, 2] {
                let camera = WorldMapCamera(size: size, aspectRatio: 1.45,
                                            activePoint: active, travelProgress: progress)
                assert(camera.progress == Float(min(1, max(0, progress))), "Travel must clamp at both endpoints")
                assert(abs(simd_dot(camera.right, camera.up)) < 0.00001, "Camera axes must be orthogonal")
                assert(abs(simd_length(camera.up) - 1) < 0.00001, "Camera up must be normalized")
                assert(simd_length(simd_cross(camera.right, camera.up) - camera.towardCamera) < 0.00001,
                       "Camera axes must agree with a right-handed look-at transform")
                for x: Float in [0, 0.18, 0.5, 1] {
                    for y: Float in [0, 0.72, 0.5, 1] {
                        for height: Float in [0, 0.8] {
                            let point = camera.position(x: x, y: y) + SIMD3<Float>(0, height, 0)
                            // Points behind the close camera have no visible projection.
                            guard simd_dot(camera.eye - point, camera.towardCamera) > 0.01 else { continue }
                            let projected = camera.project(point)
                            let expected = matrixProjection(point, camera: camera)
                            assert(hypot(projected.x - expected.x, projected.y - expected.y) < 0.02,
                                   "Labels must match the scene camera at every travel progress")
                            comparisons += 1
                        }
                    }
                }
                if camera.progress == 0 {
                    let center = camera.point(x: Double(active.x), y: Double(active.y), height: 0.02)
                    assert(hypot(center.x - size.width / 2, center.y - size.height / 2) < 0.001,
                           "Close camera must center the active town")
                }
                if camera.progress == 1 {
                    // Native 5x5 towns have a conservative 2.2-unit coast radius;
                    // generator nodes stay inside the 0.09 playable inset.
                    for x: Float in [0.09, 0.91] {
                        for y: Float in [0.09, 0.91] {
                            for angle in 0..<16 {
                                let radians = Float(angle) / 16 * .pi * 2
                                let islandEdge = camera.position(x: x, y: y) + SIMD3<Float>(cos(radians) * 2.2, 0.8, sin(radians) * 2.2)
                                let point = camera.project(islandEdge)
                                assert(point.x >= 0 && point.x <= size.width && point.y >= 0 && point.y <= size.height,
                                       "Native islands and their building height must fit at playable map edges")
                            }
                        }
                    }
                    // The map boundary plus its island margin must fit; this catches
                    // missing perspective depth and portrait/ultrawide aspect handling.
                    for x: Float in [0, 1] {
                        for y: Float in [0, 1] {
                            for dx: Float in [-2.1, 2.1] {
                                for dy: Float in [-2.1, 2.1] {
                                    let point = camera.project(camera.position(x: x, y: y) + camera.right * dx + camera.along * dy)
                                    assert(point.x >= -1 && point.x <= size.width + 1 && point.y >= -1 && point.y <= size.height + 1,
                                           "Full archipelago and island margin must stay inside the viewport: size \(size), point \(point), node \(x),\(y), offset \(dx),\(dy)")
                                }
                            }
                        }
                    }
                }
            }
        }
        // A rotated town may enter the map from either side of the angle wrap.
        // Island placement must stay fixed while only the camera heading changes.
        let settled = WorldMapCamera(size: sizes[0], aspectRatio: 1.45, activePoint: active)
        for heading: Float in [-.pi + 0.05, .pi - 0.05, .pi / 4] {
            var camera = WorldMapCamera(size: sizes[0], aspectRatio: 1.45, activePoint: active,
                                        travelProgress: 0, initialYaw: heading)
            assert(abs(atan2(sin(camera.yaw - heading), cos(camera.yaw - heading))) < 0.00001,
                   "Close map camera must retain the town heading")
            assert(abs(camera.distance - 14) < 0.00001 && abs(camera.pitch - 1.20) < 0.00001,
                   "Close map camera must match the town's above-clouds pose")
            assert(camera.position(x: active.x, y: active.y) == settled.position(x: active.x, y: active.y),
                   "Camera rotation must never rotate the physical island layout")
            camera.travelProgress = 0.5
            let point = camera.position(x: 0.4, y: 0.6) + SIMD3<Float>(0, 0.3, 0)
            let actual = camera.project(point), expected = matrixProjection(point, camera: camera)
            assert(hypot(actual.x - expected.x, actual.y - expected.y) < 0.02, "Rotated flight must use the same native projection")
            camera.travelProgress = 1
            assert(simd_length(camera.eye - settled.eye) < 0.0001,
                   "Every town heading must settle on the identical full-map camera")
        }
        for size in [CGSize(width: 0, height: 0), CGSize(width: 1, height: 1), CGSize(width: 0, height: 900),
                     CGSize(width: 1440, height: 0)] {
            for aspect in [0.0, -1, Double.nan, Double.infinity, 1.45] {
                let camera = WorldMapCamera(size: size, aspectRatio: aspect, activePoint: active)
                let point = camera.point(x: 0.5, y: 0.5)
                assert(camera.distance.isFinite && camera.eye.x.isFinite && camera.eye.y.isFinite && camera.eye.z.isFinite,
                       "Transient viewport/layout edges must leave the native camera finite")
                assert(point.x.isFinite && point.y.isFinite, "Transient viewport/layout edges must leave overlays finite")
            }
        }
        print("World map camera checks passed: \(comparisons) independent projections; viewport fit, town focus, basis, travel clamp, and zero-size/layout edges.")
    }
}
