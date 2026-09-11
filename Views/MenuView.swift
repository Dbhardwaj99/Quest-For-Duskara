import SwiftUI

struct MenuView: View {
    let canContinue: Bool
    let saveRecoveryMessage: String?
    let onStartGame: () -> Void
    let onContinueGame: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 48) {
            VStack(alignment: .leading, spacing: DuskaraTheme.spacingM) {
                Text("Quest for Duskara")
                    .font(DuskaraTheme.Fonts.hero)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                Text("Build, train, and sail before dusk claims the isles.")
                    .font(DuskaraTheme.Fonts.bodyLarge)
                    .foregroundStyle(.white.opacity(0.78))
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: DuskaraTheme.spacingM) {
                if let saveRecoveryMessage {
                    Text(saveRecoveryMessage)
                        .font(DuskaraTheme.Fonts.body)
                        .foregroundStyle(.white.opacity(0.78))
                }

                if canContinue {
                    Button(action: onContinueGame) {
                        Label("Continue Game", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(DuskaraButtonStyle(prominent: true))
                }

                Button(action: onStartGame) {
                    Label(saveRecoveryMessage == nil ? "Start Game" : "Start New Campaign", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DuskaraButtonStyle(prominent: true))
            }
            .padding(DuskaraTheme.spacingL)
            .background(DuskaraTheme.panel, in: RoundedRectangle(cornerRadius: DuskaraTheme.cornerS))
            .frame(width: 360)
        }
        .padding(.horizontal, 64)
        .frame(maxWidth: DuskaraTheme.maxContentWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(HomeBackgroundView())
    }
}

#Preview {
    MenuView(canContinue: true, saveRecoveryMessage: nil, onStartGame: { }, onContinueGame: { })
}
