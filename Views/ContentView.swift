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
                            GameView(viewModel: viewModel, onNewCampaign: startGame)
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
        .onAppear {
            refreshSavedGame()
            #if DEBUG
            if CommandLine.arguments.contains("-battleSandbox") { startBattleSandbox() }
            #endif
        }
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

    #if DEBUG
    /// `-battleSandbox` drops straight into an even lane battle, saving to a
    /// scratch folder so the real save is never touched.
    private func startBattleSandbox() {
        let sandbox = GameViewModel(saveStore: GameSaveStore(directory: FileManager.default.temporaryDirectory))
        sandbox.startGame()
        var army = SoldierRoster()
        army[.archer] = 5
        army[.knight] = 2
        if CommandLine.arguments.contains("-battleCapture") { army[.archer] = 14; army[.knight] = 6 }
        if CommandLine.arguments.contains("-battleRepelled") { army[.archer] = 1; army[.knight] = 0 }
        let strength = army.armyStrength(using: sandbox.balance.soldierDefinitions)
        guard let target = sandbox.state.towns.first(where: { $0.isPlayerControlled == false }) else { return }
        let sourceID = sandbox.state.activeTownID
        for id in [sourceID, target.id] {
            sandbox.state.updateTown(id: id) {
                let isAttacker = id == sourceID
                var roster = army
                if !isAttacker { roster[.archer] = 5; roster[.knight] = 2 }
                $0.soldierRoster = roster
                $0.armyStrength = isAttacker ? strength : roster.armyStrength(using: sandbox.balance.soldierDefinitions)
            }
        }
        if CommandLine.arguments.contains("-battleBriefing") { sandbox.prepareAssault(target.id) }
        else if CommandLine.arguments.contains("-battleProfile") {
            // Allow Instruments to attach before the HUD is constructed.
            sandbox.stopClock()
            DispatchQueue.main.asyncAfter(deadline: .now()+10) { sandbox.attackTown(target.id) }
        }
        else { sandbox.attackTown(target.id) }
        viewModel.stopClock()
        viewModel = sandbox
        path = [.game]
    }
    #endif

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
