import Foundation

extension Town {
    var isPlayerControlled: Bool {
        faction == .player
    }

    mutating func setFaction(_ newFaction: TownFaction) {
        faction = newFaction
    }
}
