import SwiftUI

struct DuskaraButtonStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DuskaraTheme.Fonts.subheading)
            .foregroundStyle(prominent ? .white : DuskaraTheme.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(buttonFill, in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(prominent ? 0.22 : 0.34), lineWidth: 1))
            .shadow(color: .black.opacity(configuration.isPressed ? 0.10 : 0.18), radius: configuration.isPressed ? 4 : 9, y: configuration.isPressed ? 2 : 5)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .scaleEffect(configuration.isPressed ? 0.965 : 1)
            .animation(.smooth(duration: 0.16), value: configuration.isPressed)
    }

    private var buttonFill: AnyShapeStyle {
        if prominent {
            AnyShapeStyle(LinearGradient(
                colors: [DuskaraTheme.accent, Color(red: 0.55, green: 0.30, blue: 0.18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
        } else {
            AnyShapeStyle(LinearGradient(
                colors: [Color(red: 0.33, green: 0.28, blue: 0.22), Color(red: 0.24, green: 0.20, blue: 0.15)],
                startPoint: .top,
                endPoint: .bottom
            ))
        }
    }
}
