import SwiftUI
import AppKit

enum DuskaraTheme {
    /// One project-wide font: Avenir Next Condensed suits the boxy low-poly
    /// look. Every gameplay view reads through these so the face and scale
    /// stay consistent. Number fonts use monospaced digits so changing
    /// amounts and timers don't jitter.
    enum Fonts {
        private static func face(_ name: String, _ size: CGFloat, fallback: Font.Weight) -> Font {
            NSFont(name: name, size: size) != nil
                ? .custom(name, fixedSize: size)
                : .system(size: size, weight: fallback)
        }

        /// Menu/setup hero titles.
        static let hero = face("AvenirNextCondensed-Heavy", 34, fallback: .black)
        static let title = face("AvenirNextCondensed-Heavy", 26, fallback: .heavy)
        static let heading = face("AvenirNextCondensed-Bold", 18, fallback: .bold)
        /// Long-form copy: taglines, tutorial pages.
        static let bodyLarge = face("AvenirNextCondensed-Medium", 17, fallback: .medium)
        static let subheading = face("AvenirNextCondensed-DemiBold", 15, fallback: .semibold)
        static let body = face("AvenirNextCondensed-Medium", 14, fallback: .medium)
        static let caption = face("AvenirNextCondensed-DemiBold", 12, fallback: .semibold)
        /// Tiny badges and micro-labels (pill symbols, status chips).
        static let label = face("AvenirNextCondensed-DemiBold", 10, fallback: .semibold)
        /// Key amounts: HUD metrics, resource pill values.
        static let number = face("AvenirNextCondensed-Bold", 16, fallback: .bold).monospacedDigit()
        /// Secondary amounts: income deltas, timers.
        static let numberSmall = face("AvenirNextCondensed-Bold", 11, fallback: .bold).monospacedDigit()
    }

    static let background = LinearGradient(
        colors: [
            Color(red: 0.14, green: 0.19, blue: 0.18),
            Color(red: 0.23, green: 0.29, blue: 0.23),
            Color(red: 0.35, green: 0.28, blue: 0.20)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static let worldBackdrop = LinearGradient(
        colors: [
            Color(red: 0.31, green: 0.41, blue: 0.52),
            Color(red: 0.39, green: 0.49, blue: 0.56),
            Color(red: 0.61, green: 0.45, blue: 0.32)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Dark warm panels + parchment text: readable over any world backdrop.
    static let panel = Color(red: 0.16, green: 0.13, blue: 0.10)
    static let panelDark = Color(red: 0.10, green: 0.08, blue: 0.06)
    static let ink = Color(red: 0.95, green: 0.91, blue: 0.82)
    static let mutedInk = Color(red: 0.74, green: 0.68, blue: 0.58)
    static let accent = Color(red: 0.82, green: 0.48, blue: 0.24)
    static let warmGold = Color(red: 0.90, green: 0.70, blue: 0.36)
    static let moss = Color(red: 0.32, green: 0.43, blue: 0.26)
    static let glassStroke = Color.white.opacity(0.14)
    /// Shared translucent fill for floating HUD panels over the 3D world.
    static let hudFill = Color(red: 0.13, green: 0.11, blue: 0.09).opacity(0.86)
    /// Lighter glass fill for the top HUD so it reads as an in-game overlay,
    /// distinct from the solid building sheets.
    static let hudGlassFill = Color(red: 0.19, green: 0.16, blue: 0.12).opacity(0.60)
    /// Solid backdrop for sheets, and the card fill that sits on it. Explicit
    /// colors (not .primary/.secondary) so contrast holds in either appearance.
    static let sheetBackground = Color(red: 0.15, green: 0.13, blue: 0.10)
    static let card = Color(red: 0.23, green: 0.20, blue: 0.16)

    // Layout scale — shared by every screen so spacing stays consistent.
    static let spacingS: CGFloat = 8
    static let spacingM: CGFloat = 12
    static let spacingL: CGFloat = 16
    static let spacingXL: CGFloat = 24
    static let cornerS: CGFloat = 8
    static let cornerM: CGFloat = 12
    static let cornerL: CGFloat = 18

    /// Menus and setup screens are landscape-first on macOS.
    static let maxContentWidth: CGFloat = 920
    /// The in-game HUD should use the window without covering the whole board.
    static let maxHUDWidth: CGFloat = 860
    /// The top HUD docks in the top-left corner instead of spanning the window.
    static let maxTopHUDWidth: CGFloat = 430
}
