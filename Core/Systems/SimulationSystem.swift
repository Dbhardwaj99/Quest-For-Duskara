import Foundation

struct SimulationSystem {
    private let armyUpkeepSystem = ArmyUpkeepSystem()

    func advanceDay(state: inout GameState, balance: GameBalance) {
        state.day += 1
        state.elapsedSecondsInDay = 0

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
    func evaluateStatus(state: GameState) -> MatchStatus {
        if state.towns.first(where: \.isDuskara)?.faction == .player {
            return .victory
        }
        if state.towns.contains(where: \.isPlayerControlled) == false {
            return .defeat
        }
        return state.status
    }
}
