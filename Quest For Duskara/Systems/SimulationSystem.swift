import Foundation

struct SimulationSystem {
    func advanceDay(state: inout GameState, balance: GameBalance) {
        state.day += 1
        state.elapsedSecondsInDay = 0

        let buildingSystem = BuildingSystem()
        let resourceSystem = ResourceSystem()
        for index in state.towns.indices {
            let income = buildingSystem.income(for: state.towns[index], balance: balance)
            resourceSystem.applyIncome(income, to: &state.towns[index].resources)
        }
    }
}
