import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel = GameViewModel()
    @State private var savedGame: SavedGame?
    @State private var saveLoadError: GameSaveLoadError?
    @State private var path: [GameRoute] = []
    @AppStorage("hasSeenTutorial") private var hasSeenTutorial = false

    var body: some View {
        ZStack {
            NavigationStack(path: $path) {
                MenuView(
                    canContinue: savedGame != nil,
                    saveRecoveryMessage: saveLoadError?.recoveryMessage,
                    onStartGame: startGame,
                    onContinueGame: continueGame
                )
                    .navigationDestination(for: GameRoute.self) { route in
                        switch route {
                        case .game:
                            GameView(viewModel: viewModel)
                                .navigationBarBackButtonHidden()
                        }
                    }
            }

            if hasSeenTutorial == false {
                TutorialView(onFinish: { hasSeenTutorial = true })
                    .zIndex(1)
                    .transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.3), value: hasSeenTutorial)
        .onAppear(perform: refreshSavedGame)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshSavedGame() }
        }
    }

    private func startGame() {
        let newViewModel = GameViewModel()
        saveLoadError = nil
        viewModel.stopClock()
        viewModel = newViewModel
        path = [.game]
    }

    private func continueGame() {
        refreshSavedGame()
        guard let savedGame else { return }
        viewModel.resume(state: savedGame.state, difficulty: savedGame.difficulty)
        path = [.game]
    }

    private func refreshSavedGame() {
        do {
            savedGame = try GameSaveStore().load()
            saveLoadError = nil
        } catch let error as GameSaveLoadError {
            savedGame = nil
            saveLoadError = error
        } catch {
            savedGame = nil
            saveLoadError = .invalidData
        }
    }
}

private enum GameRoute: Hashable {
    case game
}

#Preview {
    ContentView()
}
