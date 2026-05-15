import Foundation

struct SoldierTrainingSystem {
    enum TrainingFailure: String, Identifiable {
        case noBarracks = "Build a barracks before training soldiers."
        case insufficientResources = "Not enough resources to train that soldier."
        case missingDefinition = "Missing soldier definition."

        var id: String { rawValue }
    }

    func train(_ kind: SoldierKind, in town: inout Town, balance: GameBalance) -> TrainingFailure? {
        guard town.buildings.contains(where: { $0.kind == .barracks }) else { return .noBarracks }
        guard let definition = balance.soldierDefinitions[kind] else { return .missingDefinition }
        guard town.resources.canAfford(definition.trainingCost) else { return .insufficientResources }
        _ = town.resources.spend(definition.trainingCost)
        town.soldierRoster.add(kind, count: 1)
        town.resources.add(.soldiers, amount: 1)
        return nil
    }
}
