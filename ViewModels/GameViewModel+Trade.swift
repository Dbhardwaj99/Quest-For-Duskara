import Foundation

/// Harbor Market: gold for food and skill with the free cities the player's
/// Piers reach. Prices are fixed; more partners mean a smaller fee.
extension GameViewModel {
    var tradePartners: [Town] { GameRules.tradePartners(state) }
    var isMarketOpen: Bool { tradePartners.isEmpty == false }
    var marketFeePercent: Int? { GameRules.marketFee(partners: tradePartners.count, balance: balance) }

    func marketPrice(of kind: ResourceKind, lot: Int, buying: Bool) -> Int? {
        GameRules.marketPrice(of: kind, lot: lot, buying: buying, partners: tradePartners.count, balance: balance)
    }

    /// Food above ten days of rations (never less than 1,000 kept back), in
    /// whole lots of 100.
    var surplusFood: Int {
        let upkeep = playerTowns.reduce(0) { $0 + GameRules.dailyFood($1, balance: balance) }
        let reserve = max(1_000, upkeep * 10)
        return max(0, spendingTown.resources[.food] - reserve) / 100 * 100
    }

    func canTrade(_ kind: ResourceKind, lot: Int, buying: Bool) -> Bool {
        guard let price = marketPrice(of: kind, lot: lot, buying: buying) else { return false }
        return spendingTown.resources[buying ? .gold : kind] >= (buying ? price : lot)
    }

    // ponytail: no save per trade — trades come in bursts, and the day-end
    // autosave lands within ten seconds anyway.
    func trade(_ kind: ResourceKind, lot: Int, buying: Bool) {
        guard let price = marketPrice(of: kind, lot: lot, buying: buying),
              GameRules.trade(kind, lot: lot, buying: buying, at: state.activeTownID, state: &state, balance: balance) else {
            show("Not enough to make that trade.")
            return
        }
        GameSound.trade.play()
        show(buying
             ? "Bought \(lot) \(kind.title.lowercased()) for \(price) gold."
             : "Sold \(lot) \(kind.title.lowercased()) for \(price) gold.")
    }
}
