import Foundation

extension Town {
    func isOwned(by playerID: String) -> Bool {
        ownerID == playerID
    }
}

extension GameState {
    func isHumanOwned(_ town: Town) -> Bool {
        humanPlayerIDs.contains(town.ownerID)
    }

    /// Towns the given player currently rules.
    func towns(ownedBy playerID: String) -> [Town] {
        towns.filter { $0.ownerID == playerID }
    }
}
