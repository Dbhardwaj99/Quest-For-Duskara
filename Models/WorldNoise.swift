import Foundation

/// Deterministic hash noise shared by world, terrain, and territory generation.
enum WorldNoise {
    /// Stable pseudo-random value in [0, 1) for a grid cell.
    static func value(seed: Int, column: Int, row: Int, salt: Int) -> Double {
        var value = UInt64(bitPattern: Int64(seed))
        value = value &+ UInt64(bitPattern: Int64(column &+ 31)) &* 0x9E3779B185EBCA87
        value = value ^ (UInt64(bitPattern: Int64(row &+ 17)) &* 0xC2B2AE3D27D4EB4F)
        value = value &+ UInt64(bitPattern: Int64(salt &+ 101)) &* 0x165667B19E3779F9
        value ^= value >> 33
        value &*= 0xFF51AFD7ED558CCD
        value ^= value >> 33
        value &*= 0xC4CEB9FE1A85EC53
        value ^= value >> 33
        return Double(value % 10_000) / 10_000.0
    }

    /// Stable pseudo-random value in [-0.5, 0.5) keyed by an index.
    static func signedValue(seed: Int, index: Int, salt: Int) -> Double {
        value(seed: seed, column: index, row: index &* 7, salt: salt) - 0.5
    }
}
