import RealityKit
import AppKit


extension World3DTileEntity {
    @discardableResult
    static func addCone(
        to root: Entity,
        radius: Float,
        height: Float,
        position: SIMD3<Float>,
        color: NSColor,
        roughness: Float = 0.92
    ) -> ModelEntity {
        let cone = World3DRenderResources.makeCone(
            radius: radius,
            height: height,
            material: material(color, roughness: roughness)
        )
        cone.position = position
        root.addChild(cone)
        return cone
    }

    @discardableResult
    static func addCylinder(
        to root: Entity,
        radius: Float,
        height: Float,
        position: SIMD3<Float>,
        color: NSColor,
        roughness: Float = 0.9
    ) -> ModelEntity {
        let cylinder = World3DRenderResources.makeCylinder(
            radius: radius,
            height: height,
            material: material(color, roughness: roughness)
        )
        cylinder.position = position
        root.addChild(cylinder)
        return cylinder
    }

    @discardableResult
    static func addBox(
        to root: Entity,
        size: SIMD3<Float>,
        position: SIMD3<Float>,
        color: NSColor,
        roughness: Float = 0.78,
        cornerRadius: Float = 0
    ) -> ModelEntity {
        let box = World3DRenderResources.makeBox(
            size: size,
            material: material(color, roughness: roughness),
            cornerRadius: cornerRadius
        )
        box.position = position
        root.addChild(box)
        return box
    }

    static func addLevelPips(_ level: Int, to root: Entity, tileSize: Float) {
        guard level > 1 else { return }
        for index in 0..<min(level, 4) {
            addBox(
                to: root,
                size: SIMD3<Float>(0.07, 0.025, 0.07) * tileSize,
                position: SIMD3<Float>(-0.18 + Float(index) * 0.11, 0.075, -0.32) * tileSize,
                color: Palette.warmGold,
                roughness: 0.52,
                cornerRadius: tileSize * 0.006
            )
        }
    }

    static func material(_ color: NSColor, roughness: Float, metallic: Bool = false) -> SimpleMaterial {
        World3DRenderResources.material(color, roughness: roughness, metallic: metallic)
    }

    static func detailCount(_ count: Int, minimum: Int) -> Int {
        let scaled = Int((Float(count) * World3DRenderResources.visualQuality.microDetailMultiplier).rounded())
        return min(count, max(minimum, scaled))
    }

    static func heightMultiplier(for coordinate: GridCoordinate) -> Float {
        0.88 + Float(stablePercent(coordinate, salt: 5)) / 100 * 0.22
    }

    static func randomAngle(_ coordinate: GridCoordinate, salt: Int) -> Float {
        randomFloat(coordinate, salt: salt) * .pi * 2
    }

    static func randomFloat(_ coordinate: GridCoordinate, salt: Int) -> Float {
        Float(stablePercent(coordinate, salt: salt)) / 99
    }

    static func stablePercent(_ coordinate: GridCoordinate, salt: Int) -> Int {
        let raw = coordinate.x &* 73_856_093 ^ coordinate.y &* 19_349_663 ^ salt &* 83_492_791
        let positive = raw == Int.min ? 0 : abs(raw)
        return positive % 100
    }

    static func jitter(_ coordinate: GridCoordinate, salt: Int) -> Float {
        Float(stablePercent(coordinate, salt: salt) - 50) / 50
    }
}
/// Theme-driven colors; all asset builders read through this so a theme
/// switch recolors every environmental asset on the next rebuild.
var Palette: WorldPalette { WorldTheme.current.palette }

extension SIMD3 where Scalar == Float {
    static func * (lhs: SIMD3<Float>, rhs: Float) -> SIMD3<Float> {
        SIMD3<Float>(lhs.x * rhs, lhs.y * rhs, lhs.z * rhs)
    }

    static func + (lhs: SIMD3<Float>, rhs: SIMD3<Float>) -> SIMD3<Float> {
        SIMD3<Float>(lhs.x + rhs.x, lhs.y + rhs.y, lhs.z + rhs.z)
    }
}
