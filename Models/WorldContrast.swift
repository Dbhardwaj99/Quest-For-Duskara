/// The one colour curve every world colour passes through, and the player-facing
/// knob that scales it. At `neutral` this is the plain pastel pass: gently
/// desaturated and lifted so the world reads as calm painted wood. Turning it up
/// pushes saturation and spreads brightness away from mid-grey — bluer water,
/// greener grass, buildings that pop off the tile they stand on.
///
/// Tune the look here, never per-colour.
enum WorldContrast {
    /// The point where the curve is the plain pastel pass and nothing more.
    /// Not the default — the world ships punchier than neutral.
    static let neutral = 1.0
    static let standard = 1.35
    static let range: ClosedRange<Double> = 0.4...1.8

    /// The renderer caches materials by colour, so the slider steps instead of
    /// sliding freely — a continuous drag would mint a material per frame.
    static let step = 0.05

    /// Written from the HUD slider (main actor), read during main-thread
    /// rendering — the same contract as `WorldTheme.current`.
    nonisolated(unsafe) static var level = standard

    /// `pastel` is the desaturation the painted-wood look depends on. Deep
    /// water passes 1 to opt out of it while still answering to the knob.
    static func adjust(
        saturation: Double,
        brightness: Double,
        pastel: Double = 0.76,
        level: Double = level
    ) -> (saturation: Double, brightness: Double) {
        // Lift scales with existing brightness so dark accents (timber, mine
        // mouths) keep their depth instead of washing out.
        let lifted = brightness * 1.06
        return (
            clamped(saturation * pastel * level),
            // Contrast pivots on mid-grey: darks sink, lights rise.
            clamped(0.5 + (lifted - 0.5) * level)
        )
    }

    private static func clamped(_ value: Double) -> Double {
        min(1, max(0, value))
    }
}
