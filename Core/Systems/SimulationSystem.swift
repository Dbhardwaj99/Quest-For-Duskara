import Foundation

struct SimulationSystem {
    private let armyUpkeepSystem = ArmyUpkeepSystem()

    func advanceDay(state: inout GameState, balance: GameBalance) {
        state.day += 1

        let buildingSystem = BuildingSystem()
        let resourceSystem = ResourceSystem()
        for index in state.towns.indices {
            let income = buildingSystem.income(for: state.towns[index], balance: balance)
            resourceSystem.applyIncome(income, to: &state.towns[index].resources)
            armyUpkeepSystem.applyDailyUpkeep(to: &state.towns[index], balance: balance)
        }

        let enemyAI = EnemyAISystem()
        if enemyAI.shouldAct(on: state.day) {
            enemyAI.takeTurn(state: &state, balance: balance)
        }
    }

    /// Durable match outcome, derived from town ownership. The rules layer
    /// owns this; presentation reacts to it but never decides it.
    ///
    /// Multiplayer: the match ends when only one human still owns islands.
    /// Single-player: the campaign ends when the human loses every island
    /// (winner nil) or conquers Duskara.
    func evaluateOutcome(state: GameState) -> (status: MatchStatus, winnerPlayerID: String?) {
        guard state.status == .active else { return (state.status, state.winnerPlayerID) }

        if state.humanPlayerIDs.count > 1 {
            let surviving = state.humanPlayerIDs.filter { player in
                state.towns.contains { $0.ownerID == player }
            }
            if surviving.count <= 1 {
                return (.finished, surviving.first)
            }
            return (.active, nil)
        }

        guard let human = state.humanPlayerIDs.first else { return (state.status, nil) }
        if let duskara = state.towns.first(where: \.isDuskara), duskara.ownerID == human {
            return (.finished, human)
        }
        if state.towns.contains(where: { $0.ownerID == human }) == false {
            return (.finished, nil)
        }
        return (.active, nil)
    }
}
