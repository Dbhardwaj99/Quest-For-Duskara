import Foundation
import Observation

struct GameMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
}

enum BuildingPresentation: Identifiable, Equatable {
    case details(UUID)
    var id: UUID {
        switch self { case let .details(id): id }
    }
}

struct TradeOffer: Identifiable {
    let id: UUID
    let cityID: UUID
    let cityName: String
    let wants: [ResourceKind: Int]
    let gives: [ResourceKind: Int]
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

    var clockTask: Task<Void, Never>?
    var feedbackTask: Task<Void, Never>?
    var lastTick = Date()
    let saveStore = GameSaveStore()

    init(balance: GameBalance = .duskDefault) {
        self.balance = balance
        state = makeNewGame(balance: balance)
    }

    let startingResourceKinds: [ResourceKind] = [.gold, .skill]
    let difficulty = Difficulty.allCases

    var activeTown: Town { state.town(id: state.activeTownID) ?? state.towns[0] }
    var activeTownIncome: [ResourceKind: Int] { GameRules.income(activeTown, balance: balance) }
    var dayProgress: Double { min(1, state.elapsedSecondsInDay / balance.dayDuration) }
    var activeArmyStrength: Int { activeTown.armyStrength }
    var empireArmyStrength: Int { state.towns.filter(\.isPlayerControlled).reduce(0) { $0 + $1.armyStrength } }
    var freePeople: Int { GameRules.freePeople(activeTown, balance: balance) }
    var populationCapacity: Int { GameRules.populationCapacity(activeTown, balance: balance) }

    func adjustBonusPresets(for mode: Difficulty) {
        bonusAllocation = mode.modeBalance
    }

    func startGame() {
        guard phase == .setup else { return }
        state.updateTown(id: state.activeTownID) {
            var resources = ResourceWallet(balance.baseStartingResources)
            resources.apply(bonusAllocation)
            $0.resources = resources
        }
        phase = .town
        lastTick = Date()
        startClock()
        saveCurrentGame()
    }

    func selectCell(_ coordinate: GridCoordinate) {
        guard phase == .town else { return }
        selectedCoordinate = coordinate
        if let placementBuildingKind {
            place(placementBuildingKind, at: coordinate)
        } else if let building = activeTown.buildings.first(where: { $0.coordinate == coordinate }) {
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
        return GameRules.placementFailure(for: kind, at: coordinate, in: activeTown, balance: balance) == nil ? .valid : .invalid
    }

    func upgradeSelectedBuilding() {
        guard let selectedBuildingID else { return }
        var changed = false
        state.updateTown(id: state.activeTownID) {
            if let failure = GameRules.upgrade(selectedBuildingID, in: &$0, balance: balance) {
                show(failure.rawValue)
            } else {
                changed = true
                show("Building upgraded.")
            }
        }
        if changed { saveCurrentGame() }
    }

    func train(_ soldier: SoldierKind) {
        var changed = false
        state.updateTown(id: state.activeTownID) {
            if let failure = GameRules.train(soldier, in: &$0, balance: balance) {
                show(failure.rawValue)
            } else {
                changed = true
                show("Trained 1 \(soldier.title).")
            }
        }
        if changed {
            state.addNews(.soldierTraining, "You trained \(soldier.title) in \(activeTown.name)")
            saveCurrentGame()
        }
    }

    func advanceDayManually() {
        GameRules.advanceDay(state: &state, balance: balance)
        sanitizeSelection()
        saveCurrentGame()
        show("Day \(state.day) begins.")
    }

    func switchToTown(_ townID: UUID) {
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
        let wasDuskara = state.town(id: targetID)?.isDuskara == true
        let name = state.town(id: targetID)?.name ?? "Town"
        if GameRules.attack(targetID, from: state.activeTownID, state: &state, balance: balance) {
            state.addNews(.cityCapture, "You captured \(name)")
            if wasDuskara {
                state.addNews(.duskaraAttack, "You conquered Duskara")
                phase = .victory
                isWorldMapPresented = false
                stopClock()
                show("Duskara conquered. Victory is yours.")
            } else {
                show("Town conquered.")
            }
        } else {
            if wasDuskara { state.addNews(.duskaraAttack, "You attacked Duskara but failed") }
            show("Attack failed. Your committed soldiers were lost.")
        }
        saveCurrentGame()
    }

    func canAttack(_ targetID: UUID) -> Bool {
        GameRules.canAttack(targetID, from: state.activeTownID, in: state, balance: balance)
    }

    func effectiveDefenseStrength(for town: Town) -> Int {
        GameRules.defense(town, in: state, balance: balance)
    }

    func transfer(_ kind: ResourceKind, amount: Int, to destinationID: UUID) {
        let order = TransferOrder(fromTownID: state.activeTownID, toTownID: destinationID, amounts: [kind: amount])
        if let failure = GameRules.transfer(order, state: &state, balance: balance) {
            show(failure.rawValue)
        } else {
            show("Sent \(amount) \(kind.title).")
            if let town = state.town(id: destinationID) {
                state.addNews(.resourceTransfer, "You sent \(amount) \(kind.title) to \(town.name)")
            }
            saveCurrentGame()
        }
    }

    func definition(for kind: BuildingKind) -> BuildingDefinition? { balance.buildingDefinitions[kind] }
    func definition(for kind: SoldierKind) -> SoldierDefinition? { balance.soldierDefinitions[kind] }
    func buildingIncome(_ building: BuildingInstance) -> [ResourceKind: Int] {
        GameRules.production(building, in: activeTown, balance: balance)
    }
    func upgradeCost(_ building: BuildingInstance) -> [ResourceKind: Int] {
        balance.buildingDefinitions[building.kind]?.cost(for: building.level + 1) ?? [:]
    }
    func canUpgrade(_ building: BuildingInstance) -> Bool {
        guard let definition = balance.buildingDefinitions[building.kind] else { return false }
        return building.level < definition.maxLevel
            && activeTown.resources.canAfford(definition.cost(for: building.level + 1))
    }
    func trainingUnavailableReason(for soldier: SoldierKind) -> String? {
        GameRules.trainingFailure(for: soldier, in: activeTown, balance: balance)?.rawValue
    }

    func saveCurrentGame() {
        do { try saveStore.save(state: state) }
        catch { show("Could not save game.") }
    }

    func stopClock() {
        clockTask?.cancel()
        feedbackTask?.cancel()
    }

    func place(_ kind: BuildingKind, at coordinate: GridCoordinate) {
        var changed = false
        state.updateTown(id: state.activeTownID) {
            if let failure = GameRules.build(kind, at: coordinate, in: &$0, balance: balance) {
                show(failure.rawValue)
            } else {
                selectedBuildingID = $0.buildings.first(where: { $0.coordinate == coordinate })?.id
                if let selectedBuildingID { buildingPresentation = .details(selectedBuildingID) }
                placementBuildingKind = nil
                changed = true
                show("Built \(kind.title).")
            }
        }
        if changed {
            state.addNews(.buildingConstruction, "You built \(kind.title) in \(activeTown.name)")
            saveCurrentGame()
        }
    }

    func startClock() {
        clockTask?.cancel()
        clockTask = Task { [weak self] in
            while Task.isCancelled == false {
                try? await Task.sleep(for: .seconds(1))
                self?.tick()
            }
        }
    }

    func tick() {
        guard phase == .town else { return }
        let now = Date()
        state.elapsedSecondsInDay += max(0, now.timeIntervalSince(lastTick))
        lastTick = now
        while state.elapsedSecondsInDay >= balance.dayDuration {
            let carry = state.elapsedSecondsInDay - balance.dayDuration
            GameRules.advanceDay(state: &state, balance: balance)
            state.elapsedSecondsInDay = carry
            sanitizeSelection()
            saveCurrentGame()
        }
    }

    func sanitizeSelection() {
        if state.town(id: state.activeTownID)?.isPlayerControlled != true,
           let next = state.towns.first(where: \.isPlayerControlled) {
            state.activeTownID = next.id
        }
        if let selectedBuildingID,
           activeTown.buildings.contains(where: { $0.id == selectedBuildingID }) == false {
            self.selectedBuildingID = nil
            buildingPresentation = nil
        }
    }

    func show(_ text: String) {
        let message = GameMessage(text: text)
        feedback = message
        feedbackTask?.cancel()
        feedbackTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.2))
            if self?.feedback?.id == message.id { self?.feedback = nil }
        }
    }
}
