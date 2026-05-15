import Foundation
import Observation

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
    private let feedbackOverlaySystem = FeedbackOverlaySystem()

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
        [.gold, .wood, .coal, .tech]
    }

    var remainingBonus: Int {
        balance.bonusPool - bonusAllocation.values.reduce(0, +)
    }

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
        activeTown.soldierRoster.armyStrength(using: balance.soldierDefinitions)
    }

    var empireArmyStrength: Int {
        state.towns
            .filter(\.isPlayerControlled)
            .reduce(0) { $0 + $1.soldierRoster.armyStrength(using: balance.soldierDefinitions) }
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

    func startingTotal(for kind: ResourceKind) -> Int {
        balance.baseStartingResources[kind, default: 0] + bonusAllocation[kind, default: 0]
    }

    func adjustBonus(for kind: ResourceKind, by delta: Int) {
        let current = bonusAllocation[kind, default: 0]
        let next = max(0, current + delta)
        let spentWithoutKind = bonusAllocation.values.reduce(0, +) - current
        bonusAllocation[kind] = min(next, balance.bonusPool - spentWithoutKind)
    }

    func startGame() {
        guard remainingBonus == 0 else {
            show("Distribute the full bonus pool before founding Duskara.")
            return
        }
        state.updateTown(id: state.activeTownID) { town in
            var resources = ResourceWallet(balance.baseStartingResources)
            resources.apply(bonusAllocation)
            town.resources = resources
        }
        phase = .town
        startClock()
    }

    func selectCell(_ coordinate: GridCoordinate) {
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
        }
    }

    func beginPlacement(for kind: BuildingKind) {
        placementBuildingKind = kind
        selectedBuildingID = nil
        selectedCoordinate = nil
        isBuildMenuPresented = false
        show("Choose a highlighted plot for \(kind.title).")
    }

    func cancelPlacement() {
        placementBuildingKind = nil
        selectedCoordinate = nil
        show("Placement cancelled.")
    }

    func tilePlacementState(for coordinate: GridCoordinate) -> TilePlacementState {
        guard let kind = placementBuildingKind else { return .normal }
        return placementValidationSystem.canPlace(kind, on: coordinate, in: activeTown, balance: balance) == nil ? .valid : .invalid
    }

    func build(_ kind: BuildingKind) {
        guard let coordinate = selectedCoordinate else {
            beginPlacement(for: kind)
            return
        }
        place(kind, at: coordinate)
    }

    func upgradeSelectedBuilding() {
        guard let selectedBuildingID else { return }
        state.updateTown(id: state.activeTownID) { town in
            if let failure = buildingSystem.upgrade(selectedBuildingID, in: &town, balance: balance) {
                show(failure.rawValue)
            } else {
                show("Building upgraded.")
            }
        }
    }

    func train(_ soldier: SoldierKind) {
        state.updateTown(id: state.activeTownID) { town in
            if let failure = soldierTrainingSystem.train(soldier, in: &town, balance: balance) {
                show(failure.rawValue)
            } else {
                show("Trained 1 \(soldier.title).")
            }
        }
    }

    func advanceDayManually() {
        simulationSystem.advanceDay(state: &state, balance: balance)
        show("Day \(state.day) begins.")
    }

    func switchToTown(_ townID: UUID) {
        guard state.town(id: townID)?.isPlayerControlled == true else { return }
        state.activeTownID = townID
        selectedCoordinate = nil
        selectedBuildingID = nil
        placementBuildingKind = nil
        isWorldMapPresented = false
    }

    func attackTown(_ targetID: UUID) {
        let won = worldMapSystem.attack(targetID: targetID, from: state.activeTownID, state: &state, balance: balance)
        if won {
            show("Town conquered.")
        } else {
            show("Only adjacent weaker towns can be conquered.")
        }
    }

    func canAttack(_ targetID: UUID) -> Bool {
        worldMapSystem.canAttack(targetID: targetID, from: state.activeTownID, in: state)
    }

    func isAdjacentToActiveTown(_ targetID: UUID) -> Bool {
        worldMapSystem.adjacentTownIDs(to: state.activeTownID, in: state).contains(targetID)
    }

    func transfer(_ kind: ResourceKind, amount: Int, to destinationID: UUID) {
        let order = TransferOrder(fromTownID: state.activeTownID, toTownID: destinationID, amounts: [kind: amount])
        if let failure = transferSystem.transfer(order: order, state: &state) {
            show(failure.rawValue)
        } else {
            show("Sent \(amount) \(kind.title).")
        }
    }

    func definition(for kind: BuildingKind) -> BuildingDefinition? {
        balance.buildingDefinitions[kind]
    }

    func definition(for kind: SoldierKind) -> SoldierDefinition? {
        balance.soldierDefinitions[kind]
    }

    func buildingIncome(_ building: BuildingInstance) -> [ResourceKind: Int] {
        balance.buildingDefinitions[building.kind]?.production(for: building.level) ?? [:]
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
        state.updateTown(id: state.activeTownID) { town in
            if let failure = buildingSystem.build(kind, at: coordinate, in: &town, balance: balance) {
                show(feedbackOverlaySystem.text(for: failure, building: kind))
            } else {
                selectedBuildingID = town.buildings.first(where: { $0.coordinate == coordinate })?.id
                placementBuildingKind = nil
                show("Built \(kind.title).")
            }
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
        if timeSystem.shouldAdvanceDay(elapsedSeconds: state.elapsedSecondsInDay, balance: balance) {
            simulationSystem.advanceDay(state: &state, balance: balance)
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
