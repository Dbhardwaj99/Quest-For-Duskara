import FirebaseAuth
import Observation

@MainActor
@Observable
final class FirebaseAuthSession {
    private(set) var participantID: String?
    private(set) var isAuthenticating = false

    func authenticate() async throws -> String {
        if let user = Auth.auth().currentUser {
            participantID = user.uid
            return user.uid
        }

        isAuthenticating = true
        defer { isAuthenticating = false }
        let result = try await Auth.auth().signInAnonymously()
        participantID = result.user.uid
        return result.user.uid
    }

    /// Anonymous accounts can later link an Apple credential without changing
    /// room membership because Firebase preserves the current user UID.
    func link(credential: AuthCredential) async throws {
        guard let user = Auth.auth().currentUser else { throw AuthSessionError.notAuthenticated }
        _ = try await user.link(with: credential)
    }

    func refreshRoomClaims() async throws {
        guard let user = Auth.auth().currentUser else { throw AuthSessionError.notAuthenticated }
        _ = try await user.getIDTokenResult(forcingRefresh: true)
    }
}

enum AuthSessionError: LocalizedError {
    case notAuthenticated

    var errorDescription: String? { "Open multiplayer and sign in first." }
}
