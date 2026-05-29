import Foundation

struct TransferSystem {
    enum TransferFailure: String, Identifiable {
        case sourceNotOwned = "Source town is not controlled."
        case destinationNotOwned = "Destination town is not controlled."
        case insufficientResources = "The source town cannot send that much."
        case sameTown = "Choose two different towns."

        var id: String { rawValue }
    }

    func transfer(order: TransferOrder, state: inout GameState) -> TransferFailure? {
        guard order.fromTownID != order.toTownID else { return .sameTown }
        guard let fromIndex = state.towns.firstIndex(where: { $0.id == order.fromTownID }) else { return .sourceNotOwned }
        guard let toIndex = state.towns.firstIndex(where: { $0.id == order.toTownID }) else { return .destinationNotOwned }
        guard state.towns[fromIndex].isPlayerControlled else { return .sourceNotOwned }
        guard state.towns[toIndex].isPlayerControlled else { return .destinationNotOwned }
        guard state.towns[fromIndex].resources.canAfford(order.amounts) else { return .insufficientResources }

        _ = state.towns[fromIndex].resources.spend(order.amounts)
        state.towns[toIndex].resources.apply(order.amounts)
        return nil
    }
}
