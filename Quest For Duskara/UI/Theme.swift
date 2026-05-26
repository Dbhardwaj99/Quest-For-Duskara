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
            Color(red: 0.10, green: 0.13, blue: 0.12),
            Color(red: 0.18, green: 0.23, blue: 0.18),
            Color(red: 0.31, green: 0.25, blue: 0.18)
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
}
