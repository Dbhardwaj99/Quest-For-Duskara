/// How much of a tile each crafted building model spans. The models are
/// authored at wildly different scales in Blender, so this is the one knob that
/// makes them read as a consistent set on the board.
///
/// `overrides` is written by the debug size panel (main actor) and read during
/// main-thread rendering — the same contract as `WorldTheme.current`.
enum BuildingScale {
    /// Deliberately below the old 0.7: buildings were crowding their plots and
    /// swamping the tile they stand on.
    static let standard: Float = 0.52
    static let range: ClosedRange<Float> = 0.15...1.0

    nonisolated(unsafe) static var overrides: [BuildingKind: Float] = [:]

    static func scale(for kind: BuildingKind) -> Float {
        overrides[kind] ?? standard
    }
}
