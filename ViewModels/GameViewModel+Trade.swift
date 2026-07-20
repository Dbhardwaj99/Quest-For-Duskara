import Foundation

extension GameViewModel {
    var currentTradeOffer: TradeOffer? {
        guard let offer = state.tradeOffers.first(where: { $0.townID == state.activeTownID }),
              let partner = state.town(id: offer.partnerTownID) else { return nil }
        return TradeOffer(
            id: offer.id,
            cityID: partner.id,
            cityName: partner.name,
            wants: offer.wants,
            gives: offer.gives
        )
    }

    var tradeOfferSecondsRemaining: Int {
        currentTradeOffer == nil ? 0 : max(0, Int(balance.dayDuration - state.elapsedSecondsInDay))
    }

    var tradeCooldownSecondsRemaining: Int {
        currentTradeOffer == nil ? max(0, Int(balance.dayDuration - state.elapsedSecondsInDay)) : 0
    }

    var tradePartners: [Town] {
        state.connections.compactMap { connection -> UUID? in
            if connection.from == state.activeTownID { return connection.to }
            if connection.to == state.activeTownID { return connection.from }
            return nil
        }.compactMap(state.town).filter { !$0.isPlayerControlled }
    }

    var hasTradePartners: Bool { !tradePartners.isEmpty }

    var canAcceptCurrentTrade: Bool {
        currentTradeOffer.map { activeTown.resources.canAfford($0.wants) } ?? false
    }

    func acceptTradeOffer() {
        guard let offer = currentTradeOffer, activeTown.resources.canAfford(offer.wants) else {
            show("Not enough resources for this trade.")
            return
        }
        state.updateTown(id: state.activeTownID) {
            _ = $0.resources.spend(offer.wants)
            $0.resources.apply(offer.gives)
        }
        state.tradeOffers.removeAll { $0.id == offer.id }
        state.addNews(.resourceTransfer, "You traded with \(offer.cityName)")
        show("Trade completed with \(offer.cityName).")
        saveCurrentGame()
    }

    func declineTradeOffer() {
        guard let offer = currentTradeOffer else { return }
        state.tradeOffers.removeAll { $0.id == offer.id }
        show("Declined \(offer.cityName)'s offer.")
    }
}
