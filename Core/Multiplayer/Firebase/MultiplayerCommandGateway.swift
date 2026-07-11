import FirebaseFunctions
import Foundation

@MainActor
protocol RemoteGameCommandDispatching: AnyObject {
    func submit(_ action: GameAction, roomID: String) async throws -> GameActionResult
}

@MainActor
final class MultiplayerCommandGateway: RemoteGameCommandDispatching {
    private let functions: Functions

    init(functions: Functions = .functions()) { self.functions = functions }

    func submit(_ action: GameAction, roomID: String) async throws -> GameActionResult {
        let actionData = try JSONSerialization.jsonObject(with: JSONEncoder().encode(action))
        let result = try await functions.httpsCallable("submitGameAction").call([
            "roomID": roomID,
            "action": actionData
        ])
        return try JSONDecoder().decode(
            GameActionResult.self,
            from: JSONSerialization.data(withJSONObject: result.data)
        )
    }
}
