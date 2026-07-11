import Foundation

struct TransferOrder: Identifiable, Equatable {
    var id = UUID()
    var fromTownID: UUID
    var toTownID: UUID
    var amounts: [ResourceKind: Int]
}

/// The single route for every mutable gameplay command. GameViewModel never
/// applies rules itself: it builds a GameAction and dispatches it here.
/// Single-player uses LocalCommandDispatcher; multiplayer swaps in a gateway
/// that submits the same actions to the server.
@MainActor
protocol GameCommandDispatching: AnyObject {
    /// Revision of the last accepted action, mirrored into new actions as
    /// their expectedRevision.
    var revision: Int { get }

    func dispatch(_ action: GameAction, state: inout GameState, balance: GameBalance) -> GameActionResult
}

/// Applies actions to a locally owned GameState with the same validation
/// order the server reducer uses. Kept working forever: it powers offline
/// campaigns and the reducer contract tests.
@MainActor
final class LocalCommandDispatcher: GameCommandDispatching {
    private(set) var revision = 0

    private let buildingSystem = BuildingSystem()
    private let soldierTrainingSystem = SoldierTrainingSystem()
    private let transferSystem = TransferSystem()
    private let worldMapSystem = WorldMapSystem()
    private let simulationSystem = SimulationSystem()
    private let newsStore = NewsStore()

    func dispatch(_ action: GameAction, state: inout GameState, balance: GameBalance) -> GameActionResult {
        guard action.schemaVersion == SchemaVersion.current, action.rulesVersion == SchemaVersion.rules else {
            return rejected(action, "This command needs a newer version of the game.")
        }
        guard action.expectedRevision == revision else {
            return rejected(action, "Out of date. Try again.")
        }
        guard state.status == .active else {
            return rejected(action, "The campaign is already decided.")
        }

        let before = state
        if let failure = apply(action.payload, to: &state, balance: balance) {
            state = before
            return rejected(action, failure)
        }

        state.status = simulationSystem.evaluateStatus(state: state)
        revision += 1
        let patch = GameStatePatch(actionID: action.actionID, revision: revision, before: before, after: state)
        return GameActionResult(actionID: action.actionID, status: .accepted, revision: revision, rejectionReason: nil, patch: patch)
    }

    private func rejected(_ action: GameAction, _ reason: String) -> GameActionResult {
        GameActionResult(actionID: action.actionID, status: .rejected, revision: revision, rejectionReason: reason, patch: nil)
    }

    /// Returns a user-facing failure message, or nil when applied.
    private func apply(_ payload: GameActionPayload, to state: inout GameState, balance: GameBalance) -> String? {
        switch payload {
        case let .build(townIDString, kindString, x, y):
            guard let townID = UUID(uuidString: townIDString), let kind = BuildingKind(rawValue: kindString) else {
                return "Malformed command."
            }
            guard let index = state.towns.firstIndex(where: { $0.id == townID }), state.towns[index].isPlayerControlled else {
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
            guard let index = state.towns.firstIndex(where: { $0.id == townID }), state.towns[index].isPlayerControlled else {
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
            guard let index = state.towns.firstIndex(where: { $0.id == townID }), state.towns[index].isPlayerControlled else {
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
            if let failure = transferSystem.transfer(order: order, state: &state) {
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
            guard worldMapSystem.attack(targetID: targetID, from: fromID, state: &state, balance: balance) else {
                return "Attack failed. Your committed soldiers were lost."
            }
            if targetWasDuskara {
                newsStore.record(.duskaraAttack, message: "You conquered Duskara", state: &state)
            }
            newsStore.record(.cityCapture, message: "You captured \(targetName)", state: &state)
            return nil

        case .advanceDay:
            simulationSystem.advanceDay(state: &state, balance: balance)
            return nil
        }
    }
}
