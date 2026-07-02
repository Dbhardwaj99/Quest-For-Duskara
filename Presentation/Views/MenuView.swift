import SwiftUI

struct MenuView: View {
    let onStartGame: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 48) {
            VStack(alignment: .leading, spacing: DuskaraTheme.spacingM) {
                Text("Quest for Duskara")
                    .font(.largeTitle.weight(.black))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                Text("Build, train, and sail before dusk claims the isles.")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.white.opacity(0.78))
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: DuskaraTheme.spacingM) {
                Button(action: onStartGame) {
                    Label("Start Game", systemImage: "sparkles")
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
        .background(DuskaraTheme.background.ignoresSafeArea())
    }
}

#Preview {
    MenuView(onStartGame: { })
}
