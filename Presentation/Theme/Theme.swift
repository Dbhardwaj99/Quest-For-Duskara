import SwiftUI

enum DuskaraTheme {
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

    static let panel = Color(red: 0.95, green: 0.89, blue: 0.76)
    static let panelDark = Color(red: 0.32, green: 0.24, blue: 0.17)
    static let ink = Color(red: 0.20, green: 0.15, blue: 0.10)
    static let mutedInk = Color(red: 0.36, green: 0.29, blue: 0.21)
    static let accent = Color(red: 0.77, green: 0.45, blue: 0.23)
    static let warmGold = Color(red: 0.84, green: 0.63, blue: 0.32)
    static let moss = Color(red: 0.32, green: 0.43, blue: 0.26)
    static let glassStroke = Color.white.opacity(0.20)

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
}
