import SwiftUI

struct ContentView: View {
    @State private var viewModel = GameViewModel()
    @State private var savedState = try? GameSaveStore().load()
    @State private var path: [GameRoute] = []
    @AppStorage("hasSeenTutorial") private var hasSeenTutorial = false

    var body: some View {
        ZStack {
            NavigationStack(path: $path) {
                MenuView(
                    canContinue: savedState != nil,
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
        newViewModel.saveCurrentGame()
        viewModel.stopClock()
        viewModel = newViewModel
        path = [.game]
    }

    private func continueGame() {
        guard let savedState else { return }
        viewModel.stopClock()
        viewModel = GameViewModel(resuming: savedState)
        path = [.game]
    }
}

private enum GameRoute: Hashable {
    case game
}

#Preview {
    ContentView()
}
