import Foundation

struct OccupationSystem {
    func applyCapturePenalties(to town: inout Town, balance: GameBalance) {
        for (kind, rate) in balance.captureResourceLossRates {
            let current = town.resources[kind]
            let remaining = Int((Double(current) * (1 - rate)).rounded(.down))
            town.resources[kind] = max(0, remaining)
        }
    }
}
