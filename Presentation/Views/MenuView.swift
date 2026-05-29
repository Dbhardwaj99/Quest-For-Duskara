import SwiftUI

struct MenuView: View {
    let savedGameSummary: SavedGameSummary?
    let onStartGame: () -> Void
    let onLoadGame: () -> Void
    let onOpenAssetGallery: () -> Void

    @State private var isStartConfirmationPresented = false
    @State private var isLoadConfirmationPresented = false

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 28)

            VStack(spacing: 8) {
                Text("Quest for Duskara")
                    .font(.largeTitle.weight(.black))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text("Build, train, and expand before dusk claims the map.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.78))
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                Button(action: startGameTapped) {
                    Label("Start Game", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DuskaraButtonStyle(prominent: true))

                Button(action: { isLoadConfirmationPresented = true }) {
                    Label("Load Game", systemImage: "tray.and.arrow.down.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DuskaraButtonStyle())
                .disabled(savedGameSummary == nil)
                .opacity(savedGameSummary == nil ? 0.55 : 1)

                Button(action: onOpenAssetGallery) {
                    Label("Asset Gallery", systemImage: "cube.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DuskaraButtonStyle())
            }
            .padding(16)
            .background(DuskaraTheme.panel, in: RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 18)

            Spacer(minLength: 28)
        }
        .background(DuskaraTheme.background.ignoresSafeArea())
        .alert("Overwrite Saved Game?", isPresented: $isStartConfirmationPresented) {
            Button("Start Game", role: .destructive, action: onStartGame)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Starting a new game will overwrite your existing save.")
        }
        .alert("Load Saved Game?", isPresented: $isLoadConfirmationPresented) {
            Button("Load Game", action: onLoadGame)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Saved game: \(savedGameSummary?.dayLabel ?? "Unknown Day")")
        }
    }

    private func startGameTapped() {
        if savedGameSummary == nil {
            onStartGame()
        } else {
            isStartConfirmationPresented = true
        }
    }
}

#Preview {
    MenuView(
        savedGameSummary: SavedGameSummary(dayLabel: "Day 3"),
        onStartGame: { },
        onLoadGame: { },
        onOpenAssetGallery: { }
    )
}
