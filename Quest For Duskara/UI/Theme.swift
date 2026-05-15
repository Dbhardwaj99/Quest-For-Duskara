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

    static let panel = Color(red: 0.95, green: 0.89, blue: 0.76)
    static let panelDark = Color(red: 0.32, green: 0.24, blue: 0.17)
    static let ink = Color(red: 0.20, green: 0.15, blue: 0.10)
    static let accent = Color(red: 0.77, green: 0.45, blue: 0.23)
}
