import SwiftUI

struct ContentView: View {
    @State private var viewModel = GameViewModel()
    @State private var path: [GameRoute] = []
    @State private var multiplayer = RoomLobbyViewModel()
    @AppStorage("hasSeenTutorial") private var hasSeenTutorial = false

    var body: some View {
        ZStack {
            NavigationStack(path: $path) {
                MenuView(onStartGame: startGame, onMultiplayer: { path = [.multiplayer] })
                    .navigationDestination(for: GameRoute.self) { route in
                        switch route {
                        case .game:
                            GameView(viewModel: viewModel)
                                .navigationBarBackButtonHidden()
                        case .multiplayer:
                            MultiplayerMenuView(viewModel: multiplayer, onJoinedRoom: { path.append(.lobby) })
                        case .lobby:
                            RoomLobbyView(
                                viewModel: multiplayer,
                                onCampaignReady: joinCampaign,
                                onLeave: { path = [.multiplayer] }
                            )
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

    private func joinCampaign() {
        guard path.last != .game, let roomID = multiplayer.session?.roomID else { return }
        Task {
            do {
                let replication = RoomReplicationService()
                try await replication.start(roomID: roomID)
                viewModel.stopClock()
                viewModel = GameViewModel(replication: replication)
                path.append(.game)
            } catch {
                multiplayer.errorMessage = error.localizedDescription
            }
        }
    }
}

private enum GameRoute: Hashable {
    case game
    case multiplayer
    case lobby
}

#Preview {
    ContentView()
}
