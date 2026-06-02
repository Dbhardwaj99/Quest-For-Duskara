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

    init(savedState: GameState) {
        let balance = GameBalance.duskDefault
        self.balance = balance
        self.state = savedState
        normalizeBuildingsToCurrentGrid()
        sanitizeActiveTownSelection()
        self.phase = savedState.towns.contains { $0.isDuskara && $0.isPlayerControlled } ? .victory : .town
        if phase == .town {
            startClock()
        }
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
        guard phase == .setup else { return }
        guard remainingBonus == 0 else {
            show("Distribute the full bonus pool before founding your settlement.")
            return
        }
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
        return worldMapSystem.canAttack(targetID: targetID, from: state.activeTownID, in: state)
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
            if let destination = state.town(id: destinationID) {
                newsStore.record(.resourceTransfer, message: "You sent \(amount) \(kind.title) to \(destination.name)", state: &state)
            }
            saveCurrentGame()
        }
    }

    func canTrain(_ soldier: SoldierKind) -> Bool {
        trainingUnavailableReason(for: soldier) == nil
    }

    func trainingUnavailableReason(for soldier: SoldierKind) -> String? {
        guard activeTown.buildings.contains(where: { $0.kind == .barracks }) else {
            return SoldierTrainingSystem.TrainingFailure.noBarracks.rawValue
        }
        guard let definition = balance.soldierDefinitions[soldier] else {
            return SoldierTrainingSystem.TrainingFailure.missingDefinition.rawValue
        }
        let missing = definition.trainingCost.positiveEntries.compactMap { kind, amount -> String? in
            let available = activeTown.resources[kind]
            guard available < amount else { return nil }
            return "Need \(amount - available) more \(kind.title)"
        }
        return missing.isEmpty ? nil : missing.joined(separator: ", ")
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
        var didBuild = false
        var newsMessage: String?
        state.updateTown(id: state.activeTownID) { town in
            if let failure = buildingSystem.build(kind, at: coordinate, in: &town, balance: balance) {
                show(feedbackOverlaySystem.text(for: failure, building: kind))
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

    private func normalizeBuildingsToCurrentGrid() {
        for townIndex in state.towns.indices {
            var occupied: Set<GridCoordinate> = []
            for buildingIndex in state.towns[townIndex].buildings.indices {
                let coordinate = state.towns[townIndex].buildings[buildingIndex].coordinate
                if balance.gridSize.contains(coordinate), occupied.contains(coordinate) == false {
                    occupied.insert(coordinate)
                } else if let replacement = nearestOpenCoordinate(to: coordinate, occupied: occupied) {
                    state.towns[townIndex].buildings[buildingIndex].coordinate = replacement
                    occupied.insert(replacement)
                }
            }
        }
    }

    private func nearestOpenCoordinate(to coordinate: GridCoordinate, occupied: Set<GridCoordinate>) -> GridCoordinate? {
        let clampedX = min(max(0, coordinate.x), balance.gridSize.columns - 1)
        let clampedY = min(max(0, coordinate.y), balance.gridSize.rows - 1)
        let clamped = GridCoordinate(x: clampedX, y: clampedY)
        if occupied.contains(clamped) == false {
            return clamped
        }

        var best: GridCoordinate?
        var bestDistance = Int.max
        for y in 0..<balance.gridSize.rows {
            for x in 0..<balance.gridSize.columns {
                let candidate = GridCoordinate(x: x, y: y)
                guard occupied.contains(candidate) == false else { continue }
                let distance = abs(candidate.x - coordinate.x) + abs(candidate.y - coordinate.y)
                if distance < bestDistance {
                    best = candidate
                    bestDistance = distance
                }
            }
        }
        return best
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
