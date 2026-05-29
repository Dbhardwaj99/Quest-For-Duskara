import SwiftUI

struct ContentView: View {
    @State private var viewModel = GameViewModel()
    @State private var path: [GameRoute] = []
    @State private var savedGameSummary = GameSaveStore().savedGameSummary()

    private let saveStore = GameSaveStore()

    var body: some View {
        NavigationStack(path: $path) {
            MenuView(
                savedGameSummary: savedGameSummary,
                onStartGame: startGame,
                onLoadGame: loadGame,
                onOpenAssetGallery: openAssetGallery
            )
            .navigationDestination(for: GameRoute.self) { route in
                switch route {
                case .game:
                    GameView(viewModel: viewModel)
                        .navigationBarBackButtonHidden()
                case .assetGallery:
                    World3DAssetGalleryView()
                }
            }
        }
        .onAppear(perform: refreshSavedGameSummary)
    }

    private func startGame() {
        let newViewModel = GameViewModel()
        newViewModel.saveCurrentGame()
        viewModel.stopClock()
        viewModel = newViewModel
        refreshSavedGameSummary()
        openGame()
    }

    private func loadGame() {
        guard loadSavedGameIntoViewModel() else { return }
        openGame()
    }

    @discardableResult
    private func loadSavedGameIntoViewModel() -> Bool {
        guard let savedGame = try? saveStore.loadSavedGame() else {
            refreshSavedGameSummary()
            return false
        }
        viewModel.stopClock()
        viewModel = GameViewModel(savedState: savedGame.state)
        refreshSavedGameSummary()
        return true
    }

    private func openGame() {
        path = [.game]
    }

    private func openAssetGallery() {
        path = [.assetGallery]
    }

    private func refreshSavedGameSummary() {
        savedGameSummary = saveStore.savedGameSummary()
    }
}

private enum GameRoute: Hashable {
    case game
    case assetGallery
}

#Preview {
    ContentView()
}
