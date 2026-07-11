import Foundation

/// SplitMix64: tiny, fast, and trivially portable, so the TypeScript reducer
/// can reproduce the exact same stream with BigInt math. All gameplay
/// randomness and all persistent ID minting flow through this type; nothing
/// in the rules layer may call SystemRandomNumberGenerator.
struct DeterministicRandom {
    private var state: UInt64

    init(seed: Int, stream: Int = 0) {
        state = UInt64(bitPattern: Int64(seed)) &+ (UInt64(bitPattern: Int64(stream)) &* 0x9E3779B97F4A7C15)
    }

    mutating func nextUInt64() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    /// Uniform value in [0, upperBound) via modulo. The slight modulo bias is
    /// irrelevant for gameplay and keeps the TS port one line.
    mutating func next(upperBound: Int) -> Int {
        guard upperBound > 0 else { return 0 }
        return Int(nextUInt64() % UInt64(upperBound))
    }

    mutating func int(in range: ClosedRange<Int>) -> Int {
        range.lowerBound + next(upperBound: range.upperBound - range.lowerBound + 1)
    }

    mutating func pick<T>(_ elements: [T]) -> T? {
        guard elements.isEmpty == false else { return nil }
        return elements[next(upperBound: elements.count)]
    }

    /// RFC 4122 version-4-shaped UUID from the deterministic stream.
    mutating func uuid() -> UUID {
        let high = nextUInt64()
        let low = nextUInt64()
        var bytes = [UInt8]()
        bytes.reserveCapacity(16)
        for shift in stride(from: 56, through: 0, by: -8) {
            bytes.append(UInt8(truncatingIfNeeded: high >> UInt64(shift)))
        }
        for shift in stride(from: 56, through: 0, by: -8) {
            bytes.append(UInt8(truncatingIfNeeded: low >> UInt64(shift)))
        }
        bytes[6] = (bytes[6] & 0x0F) | 0x40
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    /// Stable 64-bit hash of a string (FNV-1a), for deriving per-entity
    /// streams from IDs. Also portable to TS with BigInt.
    static func stableHash(_ string: String) -> Int {
        var hash: UInt64 = 0xCBF29CE484222325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100000001B3
        }
        return Int(bitPattern: UInt(truncatingIfNeeded: hash))
    }
}
