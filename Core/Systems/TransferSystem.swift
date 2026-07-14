import Foundation

struct TransferSystem {
    enum TransferFailure: String, Identifiable {
        case sourceNotOwned = "Source town is not controlled."
        case destinationNotOwned = "Destination town is not controlled."
        case insufficientResources = "The source town cannot send that much."
        case sameTown = "Choose two different towns."

        var id: String { rawValue }
    }

    func transfer(order: TransferOrder, state: inout GameState, balance: GameBalance, actingPlayerID: String) -> TransferFailure? {
        guard order.fromTownID != order.toTownID else { return .sameTown }
        guard let fromIndex = state.towns.firstIndex(where: { $0.id == order.fromTownID }) else { return .sourceNotOwned }
        guard let toIndex = state.towns.firstIndex(where: { $0.id == order.toTownID }) else { return .destinationNotOwned }
        guard state.towns[fromIndex].isOwned(by: actingPlayerID) else { return .sourceNotOwned }
        guard state.towns[toIndex].isOwned(by: actingPlayerID) else { return .destinationNotOwned }
        if let soldiers = order.amounts[.soldiers], soldiers > 0 {
            return transferSoldiers(soldiers, fromIndex: fromIndex, toIndex: toIndex, state: &state, balance: balance)
        }
        guard state.towns[fromIndex].resources.canAfford(order.amounts) else { return .insufficientResources }

        _ = state.towns[fromIndex].resources.spend(order.amounts)
        state.towns[toIndex].resources.apply(order.amounts)
        return nil
    }

    /// Moves whole roster units (strongest first) whose power fits the
    /// requested amount; the roster is the canonical army source. Strength
    /// not represented by units (legacy garrisons from old saves) moves as a
    /// raw number so old campaigns keep working.
    private func transferSoldiers(
        _ requested: Int,
        fromIndex: Int,
        toIndex: Int,
        state: inout GameState,
        balance: GameBalance
    ) -> TransferFailure? {
        let definitions = balance.soldierDefinitions
        let source = state.towns[fromIndex]
        guard source.armyStrength >= requested else { return .insufficientResources }

        var moved = source.soldierRoster.fitting(power: requested, using: definitions)
        var movedPower = moved.armyStrength(using: definitions)
        let legacyPool = max(0, source.armyStrength - source.soldierRoster.armyStrength(using: definitions))
        let legacyMoved = min(requested - movedPower, legacyPool)

        if movedPower == 0, legacyMoved == 0 {
            // Nothing decomposable fits (e.g. asking 15 from a knight-only
            // garrison): move one weakest available unit so the order always
            // makes progress.
            guard let weakest = SoldierRoster.kindsByPowerDescending(using: definitions)
                .reversed()
                .first(where: { source.soldierRoster[$0] > 0 }) else { return .insufficientResources }
            moved.add(weakest, count: 1)
            movedPower = definitions[weakest]?.power ?? 0
        }

        state.towns[fromIndex].soldierRoster.subtract(moved)
        state.towns[fromIndex].armyStrength -= movedPower + legacyMoved
        state.towns[toIndex].soldierRoster.merge(moved)
        state.towns[toIndex].armyStrength += movedPower + legacyMoved
        state.towns[fromIndex].resources[.soldiers] = state.towns[fromIndex].armyStrength
        state.towns[toIndex].resources[.soldiers] = state.towns[toIndex].armyStrength
        return nil
    }
}
