/// How much of a tile each crafted building model spans. The models are
/// authored at wildly different scales in Blender, so this is the one knob that
/// makes them read as a consistent set on the board.
///
/// `overrides` is written by the debug size panel (main actor) and read during
/// main-thread rendering — the same contract as `WorldTheme.current`.
enum BuildingScale {
    /// Dialled in per kind against the real board rather than shared: the Pier
    /// and Farm need most of their plot to read, while the House swamped it.
    static let defaults: [BuildingKind: Float] = [
        .house: 0.65,
        .pier: 0.86,
        .farm: 0.87,
        .factory: 0.72,
        .barracks: 0.75
    ]
    static let range: ClosedRange<Float> = 0.15...1.0

    nonisolated(unsafe) static var overrides: [BuildingKind: Float] = [:]

    static func standard(for kind: BuildingKind) -> Float {
        defaults[kind] ?? 0.75
    }

    static func scale(for kind: BuildingKind) -> Float {
        overrides[kind] ?? standard(for: kind)
    }
}
