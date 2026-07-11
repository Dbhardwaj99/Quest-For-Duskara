import FirebaseAuth
import FirebaseAppCheck
import FirebaseCore
import FirebaseDatabase
import FirebaseFirestore
import FirebaseFunctions

enum FirebaseBootstrap {
    static func configureIfNeeded() {
        if FirebaseApp.app() == nil {
#if DEBUG
            AppCheck.setAppCheckProviderFactory(AppCheckDebugProviderFactory())
#endif
            FirebaseApp.configure()
        }

        guard ProcessInfo.processInfo.environment["FIREBASE_EMULATOR"] == "1" else { return }
        Auth.auth().useEmulator(withHost: "127.0.0.1", port: 9099)
        Firestore.firestore().useEmulator(withHost: "127.0.0.1", port: 8080)
        Database.database().useEmulator(withHost: "127.0.0.1", port: 9000)
        Functions.functions().useEmulator(withHost: "127.0.0.1", port: 5001)
    }
}
