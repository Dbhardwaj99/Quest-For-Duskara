import Foundation

struct SoldierTrainingSystem {
    enum TrainingFailure: String, Identifiable {
        case noBarracks = "Build a barracks before training soldiers."
        case insufficientResources = "Not enough resources to train that soldier."
        case insufficientPeople = "Not enough free people to train that soldier."
        case militaryCapReached = "Army size is at the population cap for this town."
        case missingDefinition = "Missing soldier definition."

        var id: String { rawValue }
    }

    private let townSystem = TownSystem()

    func train(_ kind: SoldierKind, in town: inout Town, balance: GameBalance) -> TrainingFailure? {
        guard town.buildings.contains(where: { $0.kind == .barracks }) else { return .noBarracks }
        guard let definition = balance.soldierDefinitions[kind] else { return .missingDefinition }
        guard town.resources.canAfford(definition.trainingCost) else { return .insufficientResources }
        guard townSystem.freePeople(in: town, balance: balance) >= definition.peopleRequired else {
            return .insufficientPeople
        }
        guard townSystem.canAddMilitary(
            peopleRequired: definition.peopleRequired,
            in: town,
            balance: balance
        ) else {
            return .militaryCapReached
        }

        _ = town.resources.spend(definition.trainingCost)
        town.resources.add(.people, amount: -definition.peopleRequired)
        town.soldierRoster.add(kind, count: 1)
        syncArmyStrength(&town, balance: balance)
        return nil
    }

    func trainingUnavailableReason(
        for kind: SoldierKind,
        in town: Town,
        balance: GameBalance
    ) -> String? {
        if let failure = trainValidationFailure(for: kind, in: town, balance: balance) {
            return failure.rawValue
        }
        return nil
    }

    func canTrain(_ kind: SoldierKind, in town: Town, balance: GameBalance) -> Bool {
        trainValidationFailure(for: kind, in: town, balance: balance) == nil
    }

    func syncArmyStrength(_ town: inout Town, balance: GameBalance) {
        let rosterStrength = town.soldierRoster.armyStrength(using: balance.soldierDefinitions)
        if rosterStrength > 0 {
            town.armyStrength = rosterStrength
        }
        town.resources[.soldiers] = town.armyStrength
    }

    private func trainValidationFailure(
        for kind: SoldierKind,
        in town: Town,
        balance: GameBalance
    ) -> TrainingFailure? {
        guard town.buildings.contains(where: { $0.kind == .barracks }) else { return .noBarracks }
        guard let definition = balance.soldierDefinitions[kind] else { return .missingDefinition }
        guard town.resources.canAfford(definition.trainingCost) else { return .insufficientResources }
        guard townSystem.freePeople(in: town, balance: balance) >= definition.peopleRequired else {
            return .insufficientPeople
        }
        guard townSystem.canAddMilitary(
            peopleRequired: definition.peopleRequired,
            in: town,
            balance: balance
        ) else {
            return .militaryCapReached
        }
        return nil
    }
}
