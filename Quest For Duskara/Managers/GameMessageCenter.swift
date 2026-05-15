import Foundation

struct GameMessage: Identifiable, Equatable {
    var id = UUID()
    var text: String
}
