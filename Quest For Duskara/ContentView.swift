import SwiftUI

struct ContentView: View {
    @State private var viewModel = GameViewModel()
    @State private var path: [GameRoute] = []
    @State private var savedGameSummary = GameSaveStore().savedGameSummary()
    @State private var isWorld3DTestPresented = false

    private let saveStore = GameSaveStore()

    var body: some View {
        NavigationStack(path: $path) {
            MenuView(
                savedGameSummary: savedGameSummary,
                onStartNewGame: startNewGame,
                onLoadGame: loadGame,
                onOpenWorld3DTest: { isWorld3DTestPresented = true }
            )
            .navigationDestination(for: GameRoute.self) { route in
                switch route {
                case .game:
                    GameView(viewModel: viewModel)
                        .navigationBarBackButtonHidden()
                }
            }
        }
        .onAppear(perform: refreshSavedGameSummary)
        .fullScreenCover(isPresented: $isWorld3DTestPresented) {
            World3DTestView(sourceViewModel: viewModel)
        }
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
        guard let savedGame = try? saveStore.loadSavedGame() else {
            refreshSavedGameSummary()
            return
        }
        viewModel.stopClock()
        viewModel = GameViewModel(savedState: savedGame.state)
        openGame()
    }

    private func openGame() {
        path = [.game]
    }

    private func refreshSavedGameSummary() {
        savedGameSummary = saveStore.savedGameSummary()
    }
}

private enum GameRoute: Hashable {
    case game
}

#Preview {
    ContentView()
}
