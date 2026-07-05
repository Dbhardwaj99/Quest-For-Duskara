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
    private let resourceSystem = ResourceSystem()
    private let buildingSystem = BuildingSystem()
    private let simulationSystem = SimulationSystem()
    private let worldMapSystem = WorldMapSystem()
    private let soldierTrainingSystem = SoldierTrainingSystem()
    private let transferSystem = TransferSystem()
    private let townSystem = TownSystem()
    private let timeSystem = TimeSystem()
    private let placementValidationSystem = PlacementValidationSystem()
    private let newsStore = NewsStore()
    private let saveStore = GameSaveStore()

    init() {
        let balance = GameBalance.duskDefault
        self.balance = balance
        self.state = WorldMapSystem().makeInitialState(balance: balance)
    }

    init(balance: GameBalance) {
        self.balance = balance
        self.state = WorldMapSystem().makeInitialState(balance: balance)
    }

    var startingResourceKinds: [ResourceKind] {
		[.gold, .skill]
    }
	
	var difficulty: [Difficulty] = Difficulty.allCases

    var activeTown: Town {
        state.town(id: state.activeTownID) ?? state.towns[0]
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
            try saveStore.save(state: state)
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
        state.updateTown(id: state.activeTownID) { town in
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
        var didUpgrade = false
        state.updateTown(id: state.activeTownID) { town in
            if let failure = buildingSystem.upgrade(selectedBuildingID, in: &town, balance: balance) {
                show(failure.rawValue)
            } else {
                show("Building upgraded.")
                didUpgrade = true
            }
        }
        if didUpgrade {
            saveCurrentGame()
        }
    }

    func train(_ soldier: SoldierKind) {
        guard phase == .town else { return }
        var didTrain = false
        var newsMessage: String?
        state.updateTown(id: state.activeTownID) { town in
            if let failure = soldierTrainingSystem.train(soldier, in: &town, balance: balance) {
                show(failure.rawValue)
            } else {
                show("Trained 1 \(soldier.title).")
                newsMessage = "You trained \(soldier.title) in \(town.name)"
                didTrain = true
            }
        }
        if didTrain {
            if let newsMessage {
                newsStore.record(.soldierTraining, message: newsMessage, state: &state)
            }
            saveCurrentGame()
        }
    }

    func advanceDayManually() {
        guard phase == .town else { return }
        simulationSystem.advanceDay(state: &state, balance: balance)
        sanitizePresentationState()
        saveCurrentGame()
        show("Day \(state.day) begins.")
    }

    func switchToTown(_ townID: UUID) {
        guard phase == .town else { return }
        guard state.town(id: townID)?.isPlayerControlled == true else { return }
        state.activeTownID = townID
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
        let targetWasDuskara = state.town(id: targetID)?.isDuskara == true
        let targetName = state.town(id: targetID)?.name ?? "Town"
        let won = worldMapSystem.attack(targetID: targetID, from: state.activeTownID, state: &state, balance: balance)
        if won {
            if targetWasDuskara {
                phase = .victory
                isWorldMapPresented = false
                stopClock()
                show("Duskara conquered. Victory is yours.")
                newsStore.record(.duskaraAttack, message: "You conquered Duskara", state: &state)
            } else {
                show("Town conquered.")
            }
            newsStore.record(.cityCapture, message: "You captured \(targetName)", state: &state)
            saveCurrentGame()
        } else {
            if targetWasDuskara {
                newsStore.record(.duskaraAttack, message: "You attacked Duskara but failed", state: &state)
            }
            show("Attack failed. Your committed soldiers were lost.")
            saveCurrentGame()
        }
    }

    func canAttack(_ targetID: UUID) -> Bool {
        guard phase == .town else { return false }
        return worldMapSystem.canAttack(targetID: targetID, from: state.activeTownID, in: state, balance: balance)
    }

    func effectiveDefenseStrength(for town: Town) -> Int {
        worldMapSystem.effectiveDefenseStrength(for: town, in: state, balance: balance)
    }

    func transfer(_ kind: ResourceKind, amount: Int, to destinationID: UUID) {
        let order = TransferOrder(fromTownID: state.activeTownID, toTownID: destinationID, amounts: [kind: amount])
        if let failure = transferSystem.transfer(order: order, state: &state) {
            show(failure.rawValue)
        } else {
            show("Sent \(amount) \(kind.title).")
            if let destination = state.town(id: destinationID) {
                newsStore.record(.resourceTransfer, message: "You sent \(amount) \(kind.title) to \(destination.name)", state: &state)
            }
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
        state.updateTown(id: state.activeTownID) { town in
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
                if connection.from == state.activeTownID { return connection.to }
                if connection.to == state.activeTownID { return connection.from }
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
        var didBuild = false
        var newsMessage: String?
        state.updateTown(id: state.activeTownID) { town in
            if let failure = buildingSystem.build(kind, at: coordinate, in: &town, balance: balance) {
                show(failure.rawValue)
            } else {
                selectedBuildingID = town.buildings.first(where: { $0.coordinate == coordinate })?.id
                if let selectedBuildingID {
                    buildingPresentation = .details(selectedBuildingID)
                }
                placementBuildingKind = nil
                show("Built \(kind.title).")
                newsMessage = "You built \(kind.title) in \(town.name)"
                didBuild = true
            }
        }
        if didBuild {
            if let newsMessage {
                newsStore.record(.buildingConstruction, message: newsMessage, state: &state)
            }
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
            simulationSystem.advanceDay(state: &state, balance: balance)
            sanitizePresentationState()
            saveCurrentGame()
        }
    }

    private func sanitizeActiveTownSelection() {
        if state.town(id: state.activeTownID)?.isPlayerControlled != true,
           let nextPlayerTown = state.towns.first(where: \.isPlayerControlled) {
            state.activeTownID = nextPlayerTown.id
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
