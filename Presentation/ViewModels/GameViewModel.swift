import Foundation
import Observation

/// One rolling offer from a neighboring free city, shown at the Pier.
struct TradeOffer: Identifiable {
    let id = UUID()
    let cityID: UUID
    let cityName: String
    let wants: [ResourceKind: Int]
    let gives: [ResourceKind: Int]
    let expiresAt: Date
}

@MainActor
@Observable
final class GameViewModel {
    let balance: GameBalance

    var phase: GamePhase = .setup
    var state: GameState
    /// Presentation-only: which of the player's towns the UI is focused on.
    var activeTownID: UUID
    var bonusAllocation: [ResourceKind: Int] = [:]
    var selectedCoordinate: GridCoordinate?
    var selectedBuildingID: UUID?
    var placementBuildingKind: BuildingKind?
    var buildingPresentation: BuildingPresentation?
    var isBuildMenuPresented = false
    var isWorldMapPresented = false
    var feedback: GameMessage?
    var currentTradeOffer: TradeOffer?
    private var tradeCooldownUntil = Date.distantPast

    private var clockTask: Task<Void, Never>?
    private var feedbackTask: Task<Void, Never>?
    private let buildingSystem = BuildingSystem()
    private let worldMapSystem = WorldMapSystem()
    private let soldierTrainingSystem = SoldierTrainingSystem()
    private let townSystem = TownSystem()
    // Trade offers stay view-model-local until the reducer owns trade.
    private let newsStore = NewsStore()
    private let timeSystem = TimeSystem()
    private let placementValidationSystem = PlacementValidationSystem()
    private let saveStore = GameSaveStore()
    /// Single command route for every mutable gameplay action.
    private let dispatcher: GameCommandDispatching
    private let localParticipantID = "local-player"

    init(balance: GameBalance = GameBalance.duskDefault, dispatcher: GameCommandDispatching? = nil) {
        self.balance = balance
        self.dispatcher = dispatcher ?? LocalCommandDispatcher()
        let state = WorldMapSystem().makeInitialState(balance: balance)
        self.state = state
        self.activeTownID = state.towns.first(where: \.isPlayerControlled)?.id ?? state.towns[0].id
    }

    /// Builds a replicated action for the shared player empire and routes it
    /// through the dispatcher. Rejections surface as feedback.
    @discardableResult
    private func dispatch(_ payload: GameActionPayload) -> GameActionResult {
        let action = GameAction(
            participantID: localParticipantID,
            expectedRevision: dispatcher.revision,
            payload: payload
        )
        let result = dispatcher.dispatch(action, state: &state, balance: balance)
        if result.status == .rejected, let reason = result.rejectionReason {
            show(reason)
        }
        return result
    }

    var startingResourceKinds: [ResourceKind] {
		[.gold, .skill]
    }
	
	var difficulty: [Difficulty] = Difficulty.allCases

    var activeTown: Town {
        state.town(id: activeTownID) ?? state.towns[0]
    }

    var selectedBuilding: BuildingInstance? {
        guard let selectedBuildingID else { return nil }
        return activeTown.buildings.first { $0.id == selectedBuildingID }
    }

    var presentedBuilding: BuildingInstance? {
        guard let buildingPresentation else { return nil }
        return activeTown.buildings.first { $0.id == buildingPresentation.id }
    }

    var activeTownIncome: [ResourceKind: Int] {
        buildingSystem.income(for: activeTown, balance: balance)
    }

    var dayProgress: Double {
        timeSystem.progress(elapsedSeconds: state.elapsedSecondsInDay, balance: balance)
    }

    var activeArmyStrength: Int {
        activeTown.armyStrength
    }

    var empireArmyStrength: Int {
        state.towns
            .filter(\.isPlayerControlled)
            .reduce(0) { $0 + $1.armyStrength }
    }

    var freePeople: Int {
        townSystem.freePeople(in: activeTown, balance: balance)
    }

    var populationCapacity: Int {
        townSystem.populationCapacity(for: activeTown, balance: balance)
    }

    var isPlacingBuilding: Bool {
        placementBuildingKind != nil
    }

    var currentDayLabel: String {
        saveStore.dayLabel(for: state.day)
    }

    func saveCurrentGame() {
        do {
            try saveStore.save(state: state, revision: dispatcher.revision)
        } catch {
            show("Could not save game.")
        }
    }

    func stopClock() {
        clockTask?.cancel()
        feedbackTask?.cancel()
    }

	func adjustBonusPresets(for mode: Difficulty) {
		bonusAllocation = mode.modebalance
	}

    func startGame() {
        guard phase == .setup else { return }
        state.updateTown(id: activeTownID) { town in
            var resources = ResourceWallet(balance.baseStartingResources)
            resources.apply(bonusAllocation)
            town.resources = resources
        }
        phase = .town
        startClock()
        saveCurrentGame()
    }

    func selectCell(_ coordinate: GridCoordinate) {
        guard phase == .town else { return }
        selectedCoordinate = coordinate

        if let placementBuildingKind {
            place(placementBuildingKind, at: coordinate)
            return
        }

        if let building = activeTown.buildings.first(where: { $0.coordinate == coordinate }) {
            selectedBuildingID = building.id
            buildingPresentation = .details(building.id)
            isBuildMenuPresented = false
        } else {
            selectedBuildingID = nil
            buildingPresentation = nil
        }
    }

    func beginPlacement(for kind: BuildingKind) {
        guard phase == .town else { return }
        placementBuildingKind = kind
        selectedBuildingID = nil
        selectedCoordinate = nil
        isBuildMenuPresented = false
        show("Choose a highlighted plot for \(kind.title).")
    }

    func cancelPlacement() {
        placementBuildingKind = nil
        selectedCoordinate = nil
        selectedBuildingID = nil
        buildingPresentation = nil
        show("Placement cancelled.")
    }

    func tilePlacementState(for coordinate: GridCoordinate) -> TilePlacementState {
        guard let kind = placementBuildingKind else { return .normal }
        return placementValidationSystem.canPlace(kind, on: coordinate, in: activeTown, balance: balance) == nil ? .valid : .invalid
    }

    func build(_ kind: BuildingKind) {
        guard phase == .town else { return }
        guard let coordinate = selectedCoordinate else {
            beginPlacement(for: kind)
            return
        }
        place(kind, at: coordinate)
    }

    func upgradeSelectedBuilding() {
        guard phase == .town else { return }
        guard let selectedBuildingID else { return }
        let result = dispatch(.upgradeBuilding(townID: activeTownID.uuidString, buildingID: selectedBuildingID.uuidString))
        if result.status == .accepted {
            show("Building upgraded.")
            saveCurrentGame()
        }
    }

    func train(_ soldier: SoldierKind) {
        guard phase == .town else { return }
        let result = dispatch(.trainSoldier(townID: activeTownID.uuidString, soldier: soldier.rawValue))
        if result.status == .accepted {
            show("Trained 1 \(soldier.title).")
            saveCurrentGame()
        }
    }

    func advanceDayManually() {
        guard phase == .town else { return }
        let result = dispatch(.advanceDay)
        if result.status == .accepted {
            sanitizePresentationState()
            reactToMatchStatus()
            saveCurrentGame()
            show("Day \(state.day) begins.")
        }
    }

    func switchToTown(_ townID: UUID) {
        guard phase == .town else { return }
        guard state.town(id: townID)?.isPlayerControlled == true else { return }
        activeTownID = townID
        selectedCoordinate = nil
        selectedBuildingID = nil
        buildingPresentation = nil
        placementBuildingKind = nil
        isWorldMapPresented = false
        // Offers belong to the town that received them.
        currentTradeOffer = nil
        saveCurrentGame()
    }

    func attackTown(_ targetID: UUID) {
        guard phase == .town else { return }
        let result = dispatch(.attack(fromTownID: activeTownID.uuidString, targetTownID: targetID.uuidString))
        if result.status == .accepted {
            if state.status == .victory {
                reactToMatchStatus()
            } else {
                show("Town conquered.")
            }
            saveCurrentGame()
        }
    }

    /// Mirrors the durable match status (owned by the rules layer) into
    /// presentation state.
    private func reactToMatchStatus() {
        guard state.status == .victory, phase != .victory else { return }
        phase = .victory
        isWorldMapPresented = false
        stopClock()
        show("Duskara conquered. Victory is yours.")
    }

    func canAttack(_ targetID: UUID) -> Bool {
        guard phase == .town else { return false }
        return worldMapSystem.canAttack(targetID: targetID, from: activeTownID, in: state, balance: balance)
    }

    func effectiveDefenseStrength(for town: Town) -> Int {
        worldMapSystem.effectiveDefenseStrength(for: town, in: state, balance: balance)
    }

    func transfer(_ kind: ResourceKind, amount: Int, to destinationID: UUID) {
        let result = dispatch(.transferResources(
            fromTownID: activeTownID.uuidString,
            toTownID: destinationID.uuidString,
            amounts: [kind.rawValue: amount]
        ))
        if result.status == .accepted {
            show("Sent \(amount) \(kind.title).")
            saveCurrentGame()
        }
    }

    // MARK: - Harbor trade

    var tradeOfferSecondsRemaining: Int {
        guard let offer = currentTradeOffer else { return 0 }
        return max(0, Int(offer.expiresAt.timeIntervalSinceNow.rounded()))
    }

    var tradeCooldownSecondsRemaining: Int {
        max(0, Int(tradeCooldownUntil.timeIntervalSinceNow.rounded()))
    }

    var hasTradePartners: Bool {
        tradePartners.isEmpty == false
    }

    var canAcceptCurrentTrade: Bool {
        guard let offer = currentTradeOffer else { return false }
        return activeTown.resources.canAfford(offer.wants)
    }

    func acceptTradeOffer() {
        guard let offer = currentTradeOffer else { return }
        guard activeTown.resources.canAfford(offer.wants) else {
            show("Not enough resources for this trade.")
            return
        }
        state.updateTown(id: activeTownID) { town in
            _ = town.resources.spend(offer.wants)
            for (kind, amount) in offer.gives {
                town.resources.add(kind, amount: amount)
            }
        }
        currentTradeOffer = nil
        tradeCooldownUntil = Date().addingTimeInterval(60)
        newsStore.record(.resourceTransfer, message: "You traded with \(offer.cityName)", state: &state)
        show("Trade completed with \(offer.cityName).")
        saveCurrentGame()
    }

    func declineTradeOffer() {
        guard let offer = currentTradeOffer else { return }
        currentTradeOffer = nil
        tradeCooldownUntil = Date().addingTimeInterval(60)
        show("Declined \(offer.cityName)'s offer.")
    }

    /// Free (neutral) cities connected to the active town by a sea lane.
    private var tradePartners: [Town] {
        state.connections
            .compactMap { connection -> UUID? in
                if connection.from == activeTownID { return connection.to }
                if connection.to == activeTownID { return connection.from }
                return nil
            }
            .compactMap { state.town(id: $0) }
            .filter { $0.faction == .neutral }
    }

    private func updateTradeOffers() {
        let now = Date()
        if let offer = currentTradeOffer {
            let partnerStillFree = state.town(id: offer.cityID)?.faction == .neutral
            guard now >= offer.expiresAt || partnerStillFree == false else { return }
            // An ignored offer expires; a fresh one arrives right away.
            currentTradeOffer = nil
        }
        guard now >= tradeCooldownUntil else { return }
        guard activeTown.buildings.contains(where: { $0.kind == .pier }) else { return }
        currentTradeOffer = makeTradeOffer()
    }

    private func makeTradeOffer() -> TradeOffer? {
        guard let partner = tradePartners.randomElement() else { return nil }
        let tradable: [ResourceKind] = [.gold, .food, .skill]
        let amounts: [ResourceKind: ClosedRange<Int>] = [.gold: 15...45, .food: 10...32, .skill: 8...26]

        guard let wantKind = tradable.randomElement() else { return nil }
        let giveOptions = tradable.filter { $0 != wantKind }
        guard let giveKind = giveOptions.randomElement() else { return nil }

        var gives = [giveKind: Int.random(in: amounts[giveKind] ?? 10...20)]
        // Every fourth ship or so sweetens the deal with a second resource.
        if Int.random(in: 0..<4) == 0, let extra = giveOptions.first(where: { $0 != giveKind }) {
            gives[extra] = Int.random(in: 5...14)
        }

        return TradeOffer(
            cityID: partner.id,
            cityName: partner.name,
            wants: [wantKind: Int.random(in: amounts[wantKind] ?? 10...20)],
            gives: gives,
            expiresAt: Date().addingTimeInterval(60)
        )
    }

    func canTrain(_ soldier: SoldierKind) -> Bool {
        trainingUnavailableReason(for: soldier) == nil
    }

    func trainingUnavailableReason(for soldier: SoldierKind) -> String? {
        soldierTrainingSystem.trainingUnavailableReason(for: soldier, in: activeTown, balance: balance)
    }

    func definition(for kind: BuildingKind) -> BuildingDefinition? {
        balance.buildingDefinitions[kind]
    }

    func definition(for kind: SoldierKind) -> SoldierDefinition? {
        balance.soldierDefinitions[kind]
    }

    func buildingIncome(_ building: BuildingInstance) -> [ResourceKind: Int] {
        buildingSystem.production(for: building, in: activeTown, balance: balance)
    }

    func upgradeCost(_ building: BuildingInstance) -> [ResourceKind: Int] {
        guard let definition = balance.buildingDefinitions[building.kind] else { return [:] }
        return definition.cost(for: building.level + 1)
    }

    func canUpgrade(_ building: BuildingInstance) -> Bool {
        guard let definition = balance.buildingDefinitions[building.kind] else { return false }
        return building.level < definition.maxLevel && activeTown.resources.canAfford(definition.cost(for: building.level + 1))
    }

    private func place(_ kind: BuildingKind, at coordinate: GridCoordinate) {
        let result = dispatch(.build(townID: activeTownID.uuidString, kind: kind.rawValue, x: coordinate.x, y: coordinate.y))
        if result.status == .accepted {
            selectedBuildingID = activeTown.buildings.first(where: { $0.coordinate == coordinate })?.id
            if let selectedBuildingID {
                buildingPresentation = .details(selectedBuildingID)
            }
            placementBuildingKind = nil
            show("Built \(kind.title).")
            saveCurrentGame()
        }
    }

    private func startClock() {
        clockTask?.cancel()
        clockTask = Task { [weak self] in
            while Task.isCancelled == false {
                try? await Task.sleep(for: .seconds(1))
                self?.tickSecond()
            }
        }
    }

    private func tickSecond() {
        guard phase == .town else { return }
        state.elapsedSecondsInDay += 1
        updateTradeOffers()
        if timeSystem.shouldAdvanceDay(elapsedSeconds: state.elapsedSecondsInDay, balance: balance) {
            let result = dispatch(.advanceDay)
            if result.status == .accepted {
                sanitizePresentationState()
                reactToMatchStatus()
                saveCurrentGame()
            }
        }
    }

    private func sanitizeActiveTownSelection() {
        if state.town(id: activeTownID)?.isPlayerControlled != true,
           let nextPlayerTown = state.towns.first(where: \.isPlayerControlled) {
            activeTownID = nextPlayerTown.id
        }
    }

    private func sanitizePresentationState() {
        sanitizeActiveTownSelection()
        if let selectedBuildingID,
           activeTown.buildings.contains(where: { $0.id == selectedBuildingID }) == false {
            self.selectedBuildingID = nil
        }
        if let buildingPresentation,
           activeTown.buildings.contains(where: { $0.id == buildingPresentation.id }) == false {
            self.buildingPresentation = nil
        }
    }

    private func show(_ text: String) {
        let message = GameMessage(text: text)
        feedback = message
        feedbackTask?.cancel()
        feedbackTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.2))
            guard Task.isCancelled == false else { return }
            if self?.feedback?.id == message.id {
                self?.feedback = nil
            }
        }
    }
}
