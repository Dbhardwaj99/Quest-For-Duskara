import Foundation

struct TransferOrder {
    var fromTownID: UUID
    var toTownID: UUID
    var amounts: [ResourceKind: Int]
}

struct NewsEvent: Identifiable, Codable, Equatable {
    enum Kind: String, Codable {
        case cityCapture, duskaraAttack, soldierTraining, buildingConstruction, resourceTransfer
    }

    var id = UUID()
    var day: Int
    var kind: Kind
    var message: String
}

struct TownTradeOffer: Identifiable, Codable, Equatable {
    var id = UUID()
    var townID: UUID
    var partnerTownID: UUID
    var wants: [ResourceKind: Int]
    var gives: [ResourceKind: Int]
}

extension GameState {
    mutating func updateTown(id: UUID, _ update: (inout Town) -> Void) {
        guard let index = towns.firstIndex(where: { $0.id == id }) else { return }
        update(&towns[index])
    }

    func town(id: UUID) -> Town? {
        towns.first { $0.id == id }
    }

    mutating func addNews(_ kind: NewsEvent.Kind, _ message: String) {
        newsEvents.insert(NewsEvent(day: day, kind: kind, message: message), at: 0)
        if newsEvents.count > 40 { newsEvents.removeLast(newsEvents.count - 40) }
    }
}

extension GameRules {
    enum TransferFailure: String {
        case sourceNotOwned = "Source town is not controlled."
        case destinationNotOwned = "Destination town is not controlled."
        case insufficientResources = "The source town cannot send that much."
        case sameTown = "Choose two different towns."
    }

    static func transfer(_ order: TransferOrder, state: inout GameState, balance: GameBalance) -> TransferFailure? {
        guard order.fromTownID != order.toTownID else { return .sameTown }
        guard let from = state.towns.firstIndex(where: { $0.id == order.fromTownID }),
              state.towns[from].isPlayerControlled else { return .sourceNotOwned }
        guard let to = state.towns.firstIndex(where: { $0.id == order.toTownID }),
              state.towns[to].isPlayerControlled else { return .destinationNotOwned }
        if let soldiers = order.amounts[.soldiers], soldiers > 0 {
            return transferSoldiers(soldiers, from: from, to: to, state: &state, balance: balance)
        }
        guard state.towns[from].resources.spend(order.amounts) else { return .insufficientResources }
        state.towns[to].resources.apply(order.amounts)
        return nil
    }

    private static func transferSoldiers(
        _ requested: Int,
        from: Int,
        to: Int,
        state: inout GameState,
        balance: GameBalance
    ) -> TransferFailure? {
        let source = state.towns[from]
        guard source.armyStrength >= requested else { return .insufficientResources }
        var moved = source.soldierRoster.fitting(power: requested, using: balance.soldierDefinitions)
        var movedPower = moved.armyStrength(using: balance.soldierDefinitions)
        let legacy = max(0, source.armyStrength - source.soldierRoster.armyStrength(using: balance.soldierDefinitions))
        let movedLegacy = min(requested - movedPower, legacy)
        if movedPower == 0, movedLegacy == 0 {
            guard let weakest = SoldierRoster.kindsByPowerDescending(using: balance.soldierDefinitions)
                .reversed().first(where: { source.soldierRoster[$0] > 0 }) else { return .insufficientResources }
            moved.add(weakest, count: 1)
            movedPower = balance.soldierDefinitions[weakest]?.power ?? 0
        }
        state.towns[from].soldierRoster.subtract(moved)
        state.towns[from].armyStrength -= movedPower + movedLegacy
        state.towns[to].soldierRoster.merge(moved)
        state.towns[to].armyStrength += movedPower + movedLegacy
        state.towns[from].resources[.soldiers] = state.towns[from].armyStrength
        state.towns[to].resources[.soldiers] = state.towns[to].armyStrength
        return nil
    }

    static func advanceDay(state: inout GameState, balance: GameBalance) {
        state.day += 1
        state.elapsedSecondsInDay = 0
        for index in state.towns.indices {
            state.towns[index].resources.apply(income(state.towns[index], balance: balance))
            applyUpkeep(to: &state.towns[index], balance: balance)
        }
        if state.day.isMultiple(of: 20) { runEnemyTurn(state: &state, balance: balance) }
        makeTradeOffers(state: &state)
    }

    static func makeTradeOffers(state: inout GameState) {
        state.tradeOffers.removeAll()
        for town in state.towns where town.isPlayerControlled && town.buildings.contains(where: { $0.kind == .pier }) {
            let partnerIDs = state.connections.compactMap { connection -> UUID? in
                if connection.from == town.id { return connection.to }
                if connection.to == town.id { return connection.from }
                return nil
            }
            guard let partner = partnerIDs.compactMap(state.town).filter({ !$0.isPlayerControlled }).randomElement() else { continue }
            let resources: [ResourceKind] = [.gold, .food, .skill]
            guard let wanted = resources.randomElement(),
                  let offered = resources.filter({ $0 != wanted }).randomElement() else { continue }
            let ranges: [ResourceKind: ClosedRange<Int>] = [.gold: 15...45, .food: 10...32, .skill: 8...26]
            state.tradeOffers.append(TownTradeOffer(
                townID: town.id,
                partnerTownID: partner.id,
                wants: [wanted: Int.random(in: ranges[wanted] ?? 10...20)],
                gives: [offered: Int.random(in: ranges[offered] ?? 10...20)]
            ))
        }
    }
}
