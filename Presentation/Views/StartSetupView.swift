import SwiftUI

struct StartSetupView: View {
    @Bindable var viewModel: GameViewModel

    var body: some View {
        HStack(alignment: .center, spacing: 44) {
            VStack(alignment: .leading, spacing: DuskaraTheme.spacingM) {
                Text("Quest for Duskara")
                    .font(DuskaraTheme.Fonts.hero)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                Text("Found your first settlement by choosing a starting stockpile.")
                    .font(DuskaraTheme.Fonts.bodyLarge)
                    .foregroundStyle(.white.opacity(0.78))
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .center, spacing: DuskaraTheme.spacingM) {
                Text("Choose Difficulty")
                    .font(DuskaraTheme.Fonts.heading)
                    .foregroundStyle(DuskaraTheme.ink)

                ForEach(viewModel.difficulty) { mode in
                    DifficultyRow(
                        resourceKinds: viewModel.startingResourceKinds,
                        difficulty: mode,
                        onSelected: {
                            viewModel.adjustBonusPresets(for: mode)
                            viewModel.startGame()
                        }
                    )
                }
            }
            .padding(DuskaraTheme.spacingL)
            .background(DuskaraTheme.panel, in: RoundedRectangle(cornerRadius: DuskaraTheme.cornerS))
            .frame(width: 420)
        }
        .padding(.horizontal, 64)
        .frame(maxWidth: DuskaraTheme.maxContentWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DuskaraTheme.background.ignoresSafeArea())
    }
}

private struct DifficultyRow: View {
    let resourceKinds: [ResourceKind]
    let difficulty: Difficulty
    let onSelected: () -> Void

    var body: some View {
        Button(action: onSelected) {
            VStack(alignment: .leading, spacing: DuskaraTheme.spacingS) {
                Text(difficulty.title)
                    .font(DuskaraTheme.Fonts.heading)
                    .foregroundStyle(.white)
                Text(difficulty.description)
                    .font(DuskaraTheme.Fonts.caption)
                    .foregroundStyle(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    ForEach(resourceKinds) { kind in
                        HStack(spacing: 4) {
                            ResourcePill(kind: kind, amount: nil)
                            Text("+\(difficulty.modeBalance[kind] ?? 0)")
                                .font(DuskaraTheme.Fonts.numberSmall)
                                .foregroundStyle(.white.opacity(0.92))
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(DifficultyRowStyle())
        .accessibilityLabel("Start on \(difficulty.title)")
    }
}

private struct DifficultyRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(DuskaraTheme.spacingM)
            .background(
                LinearGradient(
                    colors: [DuskaraTheme.accent, Color(red: 0.55, green: 0.30, blue: 0.18)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: DuskaraTheme.cornerM)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DuskaraTheme.cornerM)
                    .stroke(.white.opacity(0.22), lineWidth: 1)
            )
            .shadow(color: .black.opacity(configuration.isPressed ? 0.10 : 0.18), radius: configuration.isPressed ? 4 : 9, y: configuration.isPressed ? 2 : 5)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .animation(.smooth(duration: 0.16), value: configuration.isPressed)
    }
}
