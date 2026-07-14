import Foundation

/// Pure, deterministic rules engine: owns production, upkeep, AI, trade,
/// combat, capture, news and victory. The authoritative server runs this
/// exact logic (mirrored in TypeScript, contract-tested against the same
/// fixtures); the client runs it only for local campaigns.
///
/// Determinism contract:
/// - all randomness comes from DeterministicRandom seeded by the world seed
/// - all persistent IDs are minted here from the entity counter
/// - `nowMillis` is authoritative server time supplied by the caller
struct GameReducer {
    private let buildingSystem = BuildingSystem()
    private let soldierTrainingSystem = SoldierTrainingSystem()
    private let transferSystem = TransferSystem()
    private let worldMapSystem = WorldMapSystem()
    private let simulationSystem = SimulationSystem()
    private let newsStore = NewsStore()

    /// Applies a payload on behalf of `participantID` (the acting player).
    /// On failure the state is untouched and a user-facing message is
    /// returned.
    func reduce(
        _ payload: GameActionPayload,
        participantID: String,
        state: inout GameState,
        balance: GameBalance,
        nowMillis: Int64
    ) -> String? {
        let before = state
        if let failure = apply(payload, participantID: participantID, to: &state, balance: balance, nowMillis: nowMillis) {
            state = before
            return failure
        }
        normalizeMintedIDs(before: before, state: &state)
        let outcome = simulationSystem.evaluateOutcome(state: state)
        state.status = outcome.status
        state.winnerPlayerID = outcome.winnerPlayerID
        return nil
    }

    private func apply(
        _ payload: GameActionPayload,
        participantID: String,
        to state: inout GameState,
        balance: GameBalance,
        nowMillis: Int64
    ) -> String? {
        switch payload {
        case let .build(townIDString, kindString, x, y):
            guard let townID = UUID(uuidString: townIDString), let kind = BuildingKind(rawValue: kindString) else {
                return "Malformed command."
            }
            guard let index = state.towns.firstIndex(where: { $0.id == townID }), state.towns[index].isOwned(by: participantID) else {
                return "That town is not under your control."
            }
            if let failure = buildingSystem.build(kind, at: GridCoordinate(x: x, y: y), in: &state.towns[index], balance: balance) {
                return failure.rawValue
            }
            newsStore.record(.buildingConstruction, message: "You built \(kind.title) in \(state.towns[index].name)", state: &state)
            return nil

        case let .upgradeBuilding(townIDString, buildingIDString):
            guard let townID = UUID(uuidString: townIDString), let buildingID = UUID(uuidString: buildingIDString) else {
                return "Malformed command."
            }
            guard let index = state.towns.firstIndex(where: { $0.id == townID }), state.towns[index].isOwned(by: participantID) else {
                return "That town is not under your control."
            }
            if let failure = buildingSystem.upgrade(buildingID, in: &state.towns[index], balance: balance) {
                return failure.rawValue
            }
            return nil

        case let .trainSoldier(townIDString, soldierString):
            guard let townID = UUID(uuidString: townIDString), let soldier = SoldierKind(rawValue: soldierString) else {
                return "Malformed command."
            }
            guard let index = state.towns.firstIndex(where: { $0.id == townID }), state.towns[index].isOwned(by: participantID) else {
                return "That town is not under your control."
            }
            if let failure = soldierTrainingSystem.train(soldier, in: &state.towns[index], balance: balance) {
                return failure.rawValue
            }
            newsStore.record(.soldierTraining, message: "You trained \(soldier.title) in \(state.towns[index].name)", state: &state)
            return nil

        case let .transferResources(fromString, toString, amountStrings):
            guard let fromID = UUID(uuidString: fromString), let toID = UUID(uuidString: toString) else {
                return "Malformed command."
            }
            var amounts: [ResourceKind: Int] = [:]
            for (raw, amount) in amountStrings {
                guard let kind = ResourceKind(rawValue: raw), amount > 0 else { return "Malformed command." }
                amounts[kind] = amount
            }
            let order = TransferOrder(fromTownID: fromID, toTownID: toID, amounts: amounts)
            if let failure = transferSystem.transfer(order: order, state: &state, balance: balance, actingPlayerID: participantID) {
                return failure.rawValue
            }
            if let destination = state.town(id: toID) {
                for (kind, amount) in amounts.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
                    newsStore.record(.resourceTransfer, message: "You sent \(amount) \(kind.title) to \(destination.name)", state: &state)
                }
            }
            return nil

        case let .attack(fromString, targetString):
            guard let fromID = UUID(uuidString: fromString), let targetID = UUID(uuidString: targetString) else {
                return "Malformed command."
            }
            let targetWasDuskara = state.town(id: targetID)?.isDuskara == true
            let targetName = state.town(id: targetID)?.name ?? "Town"
            guard worldMapSystem.attack(targetID: targetID, from: fromID, state: &state, balance: balance, actingPlayerID: participantID) else {
                return "Attack failed. Your committed soldiers were lost."
            }
            if targetWasDuskara {
                newsStore.record(.duskaraAttack, message: "You conquered Duskara", state: &state)
            }
            newsStore.record(.cityCapture, message: "You captured \(targetName)", state: &state)
            return nil

        case let .acceptTrade(townIDString, offerID):
            guard let townID = UUID(uuidString: townIDString) else { return "Malformed command." }
            guard let townIndex = state.towns.firstIndex(where: { $0.id == townID }), state.towns[townIndex].isOwned(by: participantID) else {
                return "That town is not under your control."
            }
            guard let offerIndex = state.tradeOffers.firstIndex(where: { $0.id == offerID && $0.townID == townID }) else {
                return "That trade ship has already sailed."
            }
            let offer = state.tradeOffers[offerIndex]
            guard state.towns[townIndex].resources.canAfford(offer.wants) else {
                return "Not enough resources for this trade."
            }
            _ = state.towns[townIndex].resources.spend(offer.wants)
            state.towns[townIndex].resources.apply(offer.gives)
            state.tradeOffers.remove(at: offerIndex)
            let partnerName = state.towns(ownedBy: offer.partnerPlayerID).first?.name ?? "a free city"
            newsStore.record(.resourceTransfer, message: "You traded with \(partnerName)", state: &state)
            return nil

        case let .declineTrade(townIDString, offerID):
            guard let townID = UUID(uuidString: townIDString) else { return "Malformed command." }
            guard state.towns.first(where: { $0.id == townID })?.isOwned(by: participantID) == true else {
                return "That town is not under your control."
            }
            guard let offerIndex = state.tradeOffers.firstIndex(where: { $0.id == offerID && $0.townID == townID }) else {
                return "That trade ship has already sailed."
            }
            state.tradeOffers.remove(at: offerIndex)
            return nil

        case .advanceDay:
            simulationSystem.advanceDay(state: &state, balance: balance)
            // Keep the authoritative cadence when catching up (start +
            // duration), but let a manual early advance start the new day
            // immediately.
            let scheduledStart = state.dayStartServerMillis + Int64(balance.dayDuration * 1000)
            state.dayStartServerMillis = state.dayStartServerMillis > 0 ? min(nowMillis, scheduledStart) : nowMillis
            regenerateTradeOffers(state: &state, balance: balance)
            return nil
        }
    }

    // MARK: - Seeded daily trade events

    /// One offer per human-owned town with a pier, seeded by (world seed,
    /// day, town), valid until the next day. Partners are the AI players
    /// ruling connected islands; the offer references their server-assigned
    /// player ID, never a locally fabricated identity.
    func regenerateTradeOffers(state: inout GameState, balance: GameBalance) {
        state.tradeOffers.removeAll { $0.expiresOnDay <= state.day }

        let pierTowns = state.towns
            .filter { state.isHumanOwned($0) && $0.buildings.contains { $0.kind == .pier } }
            .sorted { $0.id.uuidString < $1.id.uuidString }

        for town in pierTowns where state.tradeOffers.contains(where: { $0.townID == town.id }) == false {
            let partners = state.connections
                .compactMap { connection -> UUID? in
                    if connection.from == town.id { return connection.to }
                    if connection.to == town.id { return connection.from }
                    return nil
                }
                .compactMap { state.town(id: $0) }
                .filter { state.isHumanOwned($0) == false }
                .sorted { $0.id.uuidString < $1.id.uuidString }

            var rng = DeterministicRandom(
                seed: state.world.generation.seed,
                stream: state.day &* 31 &+ DeterministicRandom.stableHash(town.id.uuidString)
            )
            guard let partner = rng.pick(partners) else { continue }

            let tradable: [ResourceKind] = [.gold, .food, .skill]
            let ranges: [ResourceKind: ClosedRange<Int>] = [.gold: 15...45, .food: 10...32, .skill: 8...26]
            guard let wantKind = rng.pick(tradable) else { continue }
            let giveOptions = tradable.filter { $0 != wantKind }
            guard let giveKind = rng.pick(giveOptions) else { continue }

            var gives = [giveKind: rng.int(in: ranges[giveKind] ?? 10...20)]
            // Every fourth ship or so sweetens the deal with a second resource.
            if rng.next(upperBound: 4) == 0, let extra = giveOptions.first(where: { $0 != giveKind }) {
                gives[extra] = rng.int(in: 5...14)
            }

            state.tradeOffers.append(TownTradeOffer(
                id: "trade-\(state.day)-\(town.id.uuidString)",
                townID: town.id,
                partnerPlayerID: partner.ownerID,
                wants: [wantKind: rng.int(in: ranges[wantKind] ?? 10...20)],
                gives: gives,
                expiresOnDay: state.day + 1
            ))
        }
    }

    // MARK: - Deterministic ID minting

    /// Any entity created during this step by a Core system (buildings from
    /// player or AI construction, news events) gets its client-random UUID
    /// replaced with one minted from the world seed and the replicated
    /// entity counter, so every replica produces identical IDs.
    private func normalizeMintedIDs(before: GameState, state: inout GameState) {
        let knownBuildings = Set(before.towns.flatMap { $0.buildings.map(\.id) })
        for townIndex in state.towns.indices {
            for buildingIndex in state.towns[townIndex].buildings.indices
            where knownBuildings.contains(state.towns[townIndex].buildings[buildingIndex].id) == false {
                state.towns[townIndex].buildings[buildingIndex].id = mintID(state: &state)
            }
        }
        let knownNews = Set(before.newsEvents.map(\.id))
        for newsIndex in state.newsEvents.indices
        where knownNews.contains(state.newsEvents[newsIndex].id) == false {
            state.newsEvents[newsIndex].id = mintID(state: &state)
        }
    }

    private func mintID(state: inout GameState) -> UUID {
        var rng = DeterministicRandom(seed: state.world.generation.seed, stream: 0x1D_0000 &+ state.entityCounter)
        state.entityCounter += 1
        return rng.uuid()
    }
}
