import SwiftUI

struct ContentView: View {
    @State private var viewModel = GameViewModel()
    @State private var savedGame: SavedGame?
    @State private var saveLoadError: GameSaveLoadError?
    @State private var path: [GameRoute] = []
    @AppStorage("hasSeenTutorial") private var hasSeenTutorial = false

    init() {
        do {
            _savedGame = State(initialValue: try GameSaveStore().load())
            _saveLoadError = State(initialValue: nil)
        } catch let error as GameSaveLoadError {
            _savedGame = State(initialValue: nil)
            _saveLoadError = State(initialValue: error)
        } catch {
            _savedGame = State(initialValue: nil)
            _saveLoadError = State(initialValue: .invalidData)
        }
    }

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
    }

    private func startGame() {
        let newViewModel = GameViewModel()
        saveLoadError = nil
        viewModel.stopClock()
        viewModel = newViewModel
        path = [.game]
    }

    private func continueGame() {
        guard let savedGame else { return }
        viewModel.resume(state: savedGame.state, difficulty: savedGame.difficulty)
        path = [.game]
    }
}

private enum GameRoute: Hashable {
    case game
}

#Preview {
    ContentView()
}
