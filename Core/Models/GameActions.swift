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

    /// True when this client is the simulation authority (local
    /// single-player). Only the authority may initiate ticks: when false,
    /// the client never dispatches advanceDay — the server owns time.
    var isLocalAuthority: Bool { get }

    /// `nowMillis` is authoritative time: the server injects its own clock;
    /// local play passes the ServerClock reading.
    func dispatch(_ action: GameAction, state: inout GameState, balance: GameBalance, nowMillis: Int64) -> GameActionResult
}

/// Applies actions to a locally owned GameState through the shared
/// GameReducer. Kept working forever: it powers offline campaigns and the
/// reducer contract tests.
@MainActor
final class LocalCommandDispatcher: GameCommandDispatching {
    private(set) var revision = 0

    let isLocalAuthority = true

    private let reducer = GameReducer()

    func dispatch(_ action: GameAction, state: inout GameState, balance: GameBalance, nowMillis: Int64) -> GameActionResult {
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
        if let failure = reducer.reduce(action.payload, participantID: action.participantID, state: &state, balance: balance, nowMillis: nowMillis) {
            return rejected(action, failure)
        }

        revision += 1
        let patch = GameStatePatch(actionID: action.actionID, revision: revision, before: before, after: state)
        return GameActionResult(actionID: action.actionID, status: .accepted, revision: revision, rejectionReason: nil, patch: patch)
    }

    private func rejected(_ action: GameAction, _ reason: String) -> GameActionResult {
        GameActionResult(actionID: action.actionID, status: .rejected, revision: revision, rejectionReason: reason, patch: nil)
    }
}
