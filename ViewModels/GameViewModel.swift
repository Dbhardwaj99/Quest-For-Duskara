import Foundation
import Observation

struct GameMessage: Identifiable, Equatable {
    enum Tone { case info, success, danger }

    let id = UUID()
    let text: String
    var detail: String? = nil
    var tone: Tone = .info
}

enum BuildingPresentation: Identifiable, Equatable {
    case details(UUID)
    var id: UUID {
        switch self { case let .details(id): id }
    }
}

@MainActor
@Observable
final class GameViewModel {
    let balance: GameBalance
    var phase: GamePhase = .setup
    var state: GameState
    var selectedDifficulty: Difficulty = .medium
    var bonusAllocation: [ResourceKind: Int] = [:]
    var selectedCoordinate: GridCoordinate?
    var selectedBuildingID: UUID?
    var placementBuildingKind: BuildingKind?
    var buildingPresentation: BuildingPresentation?
    var isBuildMenuPresented = false
    /// The empty plot whose click opened the build menu, if one did.
    var buildPlot: GridCoordinate?
    var isWorldMapPresented = false
    var isTroopsPresented = false
    var isMarketPresented = false
    var feedback: GameMessage?
    /// The lane battle being fought, as it stood when the army landed. The
    /// battle scene owns the live copy — mirroring every frame here would
    /// re-render the whole window — and hands it back to `finishAssault`.
    var assault: LaneBattle?
    var battleBriefing: BattleBriefing?
    var battleReport: BattleReport?
    var isBattlePresented: Bool { assault != nil || battleBriefing != nil || battleReport != nil }

    var clockTask: Task<Void, Never>?
    var feedbackTask: Task<Void, Never>?
    var lastTick = Date()
    let saveStore: GameSaveStore

    /// `saveStore` is swappable so tests don't overwrite the player's real save.
    init(balance: GameBalance = .duskDefault, saveStore: GameSaveStore = GameSaveStore()) {
        self.balance = balance
        self.saveStore = saveStore
        state = makeNewGame(balance: balance)
    }

    init(resuming state: GameState, difficulty: Difficulty, saveStore: GameSaveStore = GameSaveStore()) {
        balance = .duskDefault
        self.saveStore = saveStore
        self.state = state
        resume(state: state, difficulty: difficulty)
    }

    func resume(state: GameState, difficulty: Difficulty) {
        stopClock()
        self.state = state
        selectedDifficulty = difficulty
        phase = .town
        bonusAllocation = [:]
        selectedCoordinate = nil
        selectedBuildingID = nil
        placementBuildingKind = nil
        buildingPresentation = nil
        isBuildMenuPresented = false
        buildPlot = nil
        isWorldMapPresented = false
        isTroopsPresented = false
        isMarketPresented = false
        feedback = nil
        assault = nil
        battleBriefing = nil; battleReport = nil
        lastTick = Date()
        startClock()
    }

    let startingResourceKinds: [ResourceKind] = [.gold, .skill]
    let difficulty = Difficulty.allCases

    var activeTown: Town { state.town(id: state.activeTownID) ?? state.towns[0] }
    var playerTowns: [Town] { state.towns.filter(\.isPlayerControlled) }
    /// Prices the player pays right now: every island held beyond the first
    /// raises gold and skill costs.
    var playerBalance: GameBalance { balance.priced(forIslands: playerTowns.count) }
    var priceScale: Double { balance.priceScale(islands: playerTowns.count) }
    /// The active island as if the empire's whole shared stock sat in it —
    /// what affordability and the HUD read, since spending draws on every island.
    var spendingTown: Town {
        var town = activeTown
        let stock = GameRules.empireStock(state)
        for kind in GameRules.sharedKinds { town.resources[kind] = stock[kind] }
        return town
    }
    /// Net change per day across the empire; food is what's left once the army has eaten.
    var empireIncome: [ResourceKind: Int] {
        playerTowns.reduce(into: [:]) { total, town in
            for (kind, amount) in GameRules.income(town, balance: balance) { total[kind, default: 0] += amount }
            total[.food, default: 0] -= GameRules.dailyFood(town, balance: balance)
        }
    }
    var dayProgress: Double { min(1, state.elapsedSecondsInDay / balance.dayDuration) }
    var activeArmyStrength: Int { activeTown.armyStrength }
    var empireArmyStrength: Int { playerTowns.reduce(0) { $0 + $1.armyStrength } }
    var freePeople: Int { GameRules.freePeople(activeTown, balance: balance) }
    var populationCapacity: Int { GameRules.populationCapacity(activeTown, balance: balance) }
    /// Seconds until enemy islands next build, train and attack.
    var secondsUntilRaid: Int {
        let daysLeft = balance.enemyTurnInterval - state.day % balance.enemyTurnInterval
        return max(0, Int((Double(daysLeft) * balance.dayDuration - state.elapsedSecondsInDay).rounded(.up)))
    }

    func adjustBonusPresets(for mode: Difficulty) {
        selectedDifficulty = mode
        bonusAllocation = mode.modeBalance
    }

    func startGame() {
        guard phase == .setup else { return }
        state.updateTown(id: state.activeTownID) {
            var resources = ResourceWallet(balance.baseStartingResources)
            resources.apply(bonusAllocation)
            // Difficulty tops up the balance table, and neither has people in
            // it — those came with the town's founding buildings, so they carry
            // across rather than being reset to the table's zero.
            resources[.people] = $0.resources[.people]
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
            openBuildMenu(for: coordinate)
        }
    }

    func openBuildMenu(for plot: GridCoordinate? = nil) {
        buildPlot = plot
        isBuildMenuPresented = true
    }

    /// From the build menu: straight onto the plot that opened it when the
    /// building fits there, otherwise the player picks a highlighted plot.
    func chooseFromBuildMenu(_ kind: BuildingKind) {
        if let buildPlot, GameRules.placementFailure(for: kind, at: buildPlot, in: spendingTown, balance: playerBalance) == nil {
            isBuildMenuPresented = false
            place(kind, at: buildPlot)
        } else {
            beginPlacement(for: kind)
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
        return GameRules.placementFailure(for: kind, at: coordinate, in: spendingTown, balance: playerBalance) == nil ? .valid : .invalid
    }

    func upgradeSelectedBuilding() {
        guard let selectedBuildingID,
              let building = activeTown.buildings.first(where: { $0.id == selectedBuildingID }) else { return }
        let prices = playerBalance
        GameRules.supply(upgradeCost(building), to: state.activeTownID, state: &state, balance: balance)
        var changed = false
        state.updateTown(id: state.activeTownID) {
            if let failure = GameRules.upgrade(selectedBuildingID, in: &$0, balance: prices) {
                show(failure.rawValue)
            } else {
                changed = true
                show("Building upgraded.")
            }
        }
        if changed {
            GameSound.build.play()
            saveCurrentGame()
        }
    }

    func demolishSelectedBuilding() {
        guard let selectedBuildingID,
              let building = activeTown.buildings.first(where: { $0.id == selectedBuildingID }) else { return }
        let prices = playerBalance
        state.updateTown(id: state.activeTownID) { GameRules.demolish(selectedBuildingID, in: &$0, balance: prices) }
        self.selectedBuildingID = nil
        selectedCoordinate = nil
        buildingPresentation = nil
        show("Demolished \(building.kind.title).")
        saveCurrentGame()
    }

    func train(_ soldier: SoldierKind) {
        let prices = playerBalance
        GameRules.supply(prices.soldierDefinitions[soldier]?.trainingCost ?? [:], to: state.activeTownID, state: &state, balance: balance)
        var changed = false
        state.updateTown(id: state.activeTownID) {
            if let failure = GameRules.train(soldier, in: &$0, balance: prices) {
                show(failure.rawValue)
            } else {
                changed = true
                show("Trained 1 \(soldier.title).")
            }
        }
        if changed {
            GameSound.train.play()
            state.addNews(.soldierTraining, "You trained \(soldier.title) in \(activeTown.name)")
            saveCurrentGame()
        }
    }

    func advanceDayManually() {
        guard phase == .town, !isBattlePresented else { return }
        show("Day \(state.day + 1) begins.")
        endDay(carry: 0)
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

    /// Lands the active island's whole army for a lane battle; the clock stands
    /// still until `finishAssault` settles it.
    func attackTown(_ targetID: UUID) {
        guard assault == nil else { return }
        guard let battle = GameRules.assault(targetID, from: state.activeTownID, in: state, balance: balance) else {
            show("\(activeTown.name) has no army to send.", tone: .danger)
            return
        }
        assault = battle
    }

    func prepareAssault(_ targetID: UUID) {
        guard !isBattlePresented,
              let battle = GameRules.assault(targetID, from: state.activeTownID, in: state, balance: balance),
              let target = state.town(id: targetID) else { return }
        battleBriefing = BattleBriefing(battle: battle, source: activeTown, target: target,
                                       power: activeArmyStrength, defense: effectiveDefenseStrength(for: target))
        lastTick = Date()
    }

    func confirmAssault() {
        guard let briefing = battleBriefing else { return }
        battleBriefing = nil
        attackTown(briefing.target.id)
    }

    func cancelAssault() { battleBriefing = nil; lastTick = Date() }
    func dismissBattleReport() { battleReport = nil; lastTick = Date() }

    func finishAssault(_ battle: LaneBattle) {
        guard let initial = assault, battle.outcome != nil,
              battle.sourceID == initial.sourceID, battle.targetID == initial.targetID,
              let target = state.town(id: battle.targetID) else { return }
        let captured = GameRules.conclude(battle, state: &state, balance: balance)
        let plunder: [ResourceKind: Int] = captured ? Dictionary(uniqueKeysWithValues:
            GameRules.sharedKinds.map { ($0, state.town(id: battle.targetID)?.resources[$0] ?? 0) }) : [:]
        battleReport = BattleReport(initial: initial, result: battle, townName: target.name, plunder: plunder)
        assault = nil
        lastTick = Date()
        if captured {
            GameSound.battleVictory.play()
            state.addNews(.cityCapture, "You captured \(target.name)")
            if target.isDuskara {
                state.addNews(.duskaraAttack, "You conquered Duskara")
                phase = .victory
                isWorldMapPresented = false
                stopClock()
            }
        } else {
            GameSound.battleDefeat.play()
            state.addNews(.cityCapture, battle.outcome == .withdrew
                          ? "You withdrew from \(target.name)" : "Your assault on \(target.name) was repelled")
        }
        saveCurrentGame()
    }

    /// Any army can sail; whether it wins is down to the battle.
    func canAttack(_ targetID: UUID) -> Bool {
        state.town(id: targetID)?.isPlayerControlled == false && activeArmyStrength > 0
    }

    func effectiveDefenseStrength(for town: Town) -> Int {
        GameRules.defense(town, in: state, balance: balance)
    }

    /// Other islands have troops that could join the assault.
    func canRallyAndAttack(_ targetID: UUID) -> Bool {
        state.town(id: targetID)?.isPlayerControlled == false
            && transferDestinations.contains { $0.armyStrength > 0 }
    }

    func rallyAndAttack(_ targetID: UUID) {
        rallyTroops()
        prepareAssault(targetID)
    }

    /// Islands a troop move could reach: everything the player holds except
    /// the active one. Empty until a second island is taken, which is what
    /// hides the Troops button — there is nowhere to move before then.
    var transferDestinations: [Town] {
        state.towns.filter { $0.isPlayerControlled && $0.id != state.activeTownID }
    }

    /// Moves `fraction` of one island's army to another in whole units — at
    /// least one — and reports the power that actually moved.
    func moveTroops(from sourceID: UUID, to destinationID: UUID, fraction: Double) {
        guard let source = state.town(id: sourceID), let destination = state.town(id: destinationID),
              source.armyStrength > 0 else { return }
        let requested = max(1, Int((Double(source.armyStrength) * fraction).rounded()))
        let order = TransferOrder(fromTownID: sourceID, toTownID: destinationID, amounts: [.soldiers: requested])
        if let failure = GameRules.transfer(order, state: &state, balance: balance) {
            show(failure.rawValue)
            return
        }
        let moved = (state.town(id: destinationID)?.armyStrength ?? 0) - destination.armyStrength
        show("Moved \(moved) power to \(destination.name).")
        state.addNews(.resourceTransfer, "You moved \(moved) power from \(source.name) to \(destination.name)")
        saveCurrentGame()
    }

    func pullAllTroops() {
        let before = activeArmyStrength
        rallyTroops()
        let gathered = activeArmyStrength - before
        guard gathered > 0 else { return }
        show("Gathered \(gathered) power in \(activeTown.name).")
        saveCurrentGame()
    }

    private func rallyTroops() {
        for town in transferDestinations where town.armyStrength > 0 {
            let order = TransferOrder(fromTownID: town.id, toTownID: state.activeTownID, amounts: [.soldiers: town.armyStrength])
            _ = GameRules.transfer(order, state: &state, balance: balance)
        }
    }

    func definition(for kind: BuildingKind) -> BuildingDefinition? { playerBalance.buildingDefinitions[kind] }
    func definition(for kind: SoldierKind) -> SoldierDefinition? { playerBalance.soldierDefinitions[kind] }
    func buildingIncome(_ building: BuildingInstance) -> [ResourceKind: Int] {
        GameRules.production(building, in: activeTown, balance: balance)
    }
    func upgradeCost(_ building: BuildingInstance) -> [ResourceKind: Int] {
        playerBalance.buildingDefinitions[building.kind]?.cost(for: building.level + 1) ?? [:]
    }
    func canUpgrade(_ building: BuildingInstance) -> Bool {
        guard let definition = balance.buildingDefinitions[building.kind] else { return false }
        return building.level < definition.maxLevel && shortfall(for: upgradeCost(building)).isEmpty
    }
    func trainingUnavailableReason(for soldier: SoldierKind) -> String? {
        GameRules.trainingFailure(for: soldier, in: spendingTown, balance: playerBalance)?.rawValue
    }
    /// What the shared stockpile still lacks to pay `cost`; empty when it can.
    func shortfall(for cost: [ResourceKind: Int]) -> [ResourceKind: Int] {
        let stock = spendingTown.resources
        return cost.reduce(into: [:]) { missing, entry in
            let gap = entry.value - stock[entry.key]
            if gap > 0 { missing[entry.key] = gap }
        }
    }

    func saveCurrentGame() {
        do { try saveStore.save(state: state, difficulty: selectedDifficulty) }
        catch { show("Could not save game.") }
    }

    func stopClock() {
        clockTask?.cancel()
        feedbackTask?.cancel()
    }

    func place(_ kind: BuildingKind, at coordinate: GridCoordinate) {
        let prices = playerBalance
        GameRules.supply(prices.buildingDefinitions[kind]?.cost(for: 1) ?? [:], to: state.activeTownID, state: &state, balance: balance)
        var changed = false
        state.updateTown(id: state.activeTownID) {
            if let failure = GameRules.build(kind, at: coordinate, in: &$0, balance: prices) {
                show(failure.rawValue)
            } else {
                selectedBuildingID = $0.buildings.first(where: { $0.coordinate == coordinate })?.id
                if let selectedBuildingID { buildingPresentation = .details(selectedBuildingID) }
                placementBuildingKind = nil
                buildPlot = nil
                changed = true
                show("Built \(kind.title).")
            }
        }
        if changed {
            GameSound.build.play()
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
        // The day stands still while an assault is fought.
        guard !isBattlePresented else {
            lastTick = now
            return
        }
        state.elapsedSecondsInDay += max(0, now.timeIntervalSince(lastTick))
        lastTick = now
        while phase == .town, state.elapsedSecondsInDay >= balance.dayDuration {
            endDay(carry: state.elapsedSecondsInDay - balance.dayDuration)
        }
    }

    /// Rolls the day over, then tells the player about any island raiders took
    /// — it happens off-screen, so the news feed alone was easy to miss.
    private func endDay(carry: TimeInterval) {
        let held = Set(playerTowns.map(\.id))
        GameRules.advanceDay(state: &state, balance: balance)
        state.elapsedSecondsInDay = carry
        if let lost = state.towns.first(where: { held.contains($0.id) && $0.isPlayerControlled == false }) {
            GameSound.failure.play()
            show("\(lost.name) has fallen", detail: "Raiders took the island and everything stored there.", tone: .danger)
        }
        sanitizeSelection()
        saveCurrentGame()
    }

    func sanitizeSelection() {
        // Enemy captures are the only way the player loses towns, and every
        // one of them lands here via advanceDay — so this is the single place
        // that can notice the empire is gone.
        guard state.towns.contains(where: \.isPlayerControlled) else {
            concedeCampaign()
            return
        }
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

    /// Terminal loss. Sheets are dismissed explicitly because a day can roll
    /// over — and the last town fall — while the build menu is open.
    private func concedeCampaign() {
        guard phase == .town else { return }
        phase = .defeat
        isWorldMapPresented = false
        isBuildMenuPresented = false
        isTroopsPresented = false
        isMarketPresented = false
        buildingPresentation = nil
        placementBuildingKind = nil
        stopClock()
    }

    func show(_ text: String, detail: String? = nil, tone: GameMessage.Tone = .info) {
        let message = GameMessage(text: text, detail: detail, tone: tone)
        feedback = message
        feedbackTask?.cancel()
        feedbackTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(detail == nil ? 2.2 : 4))
            if self?.feedback?.id == message.id { self?.feedback = nil }
        }
    }
}
