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
                onStartNewGame: startNewGame,
                onLoadGame: loadGame,
                onPlay2D: openGame,
                onPlay3D: openGame3D,
                onOpenAssetGallery: openAssetGallery
            )
            .navigationDestination(for: GameRoute.self) { route in
                switch route {
                case .game2D:
                    GameView(viewModel: viewModel)
                        .navigationBarBackButtonHidden()
                case .game3D:
                    GameView3D(viewModel: viewModel)
                        .navigationBarBackButtonHidden()
                case .assetGallery:
                    World3DAssetGalleryView()
                }
            }
        }
        .onAppear(perform: refreshSavedGameSummary)
    }

    private func startNewGame() {
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

    private func openGame3D() {
        if viewModel.phase == .setup {
            _ = loadSavedGameIntoViewModel()
        }
        path = [.game3D]
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
        path = [.game2D]
    }

    private func openAssetGallery() {
        path = [.assetGallery]
    }

    private func refreshSavedGameSummary() {
        savedGameSummary = saveStore.savedGameSummary()
    }
}

private enum GameRoute: Hashable {
    case game2D
    case game3D
    case assetGallery
}

#Preview {
    ContentView()
}
