import Foundation

struct NewsEvent: Identifiable, Codable, Equatable {
    enum Kind: String, Codable {
        case cityCapture
        case duskaraAttack
        case soldierTraining
        case buildingConstruction
        case resourceTransfer
    }

    var id = UUID()
    var day: Int
    var kind: Kind
    var message: String
}

struct NewsStore {
    private let historyLimit = 40

    func record(_ kind: NewsEvent.Kind, message: String, state: inout GameState) {
        state.newsEvents.insert(NewsEvent(day: state.day, kind: kind, message: message), at: 0)
        if state.newsEvents.count > historyLimit {
            state.newsEvents.removeLast(state.newsEvents.count - historyLimit)
        }
    }
}
