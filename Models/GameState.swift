import Foundation

enum TownFaction: String, Codable, Equatable {
    case player
    case neutral
    case enemy
    case duskara
}

struct Town: Identifiable, Codable, Equatable {
    var id = UUID()
    var realmID = UUID()
    var name: String
    var resources = ResourceWallet()
    var buildings: [BuildingInstance] = []
    var biomeLayout: TownBiomeLayout
    var faction: TownFaction = .neutral
    var isDuskara = false
    var armyStrength = 0
    var soldierRoster = SoldierRoster()

    var isPlayerControlled: Bool { faction == .player }

    var forestSideCount: Int {
        biomeLayout.sides.values.filter { $0 == .forest }.count
    }

    var mountainSideCount: Int {
        biomeLayout.sides.values.filter { $0 == .mountain }.count
    }

    var specializationSummary: String {
        if forestSideCount >= 3 { return "Wood-rich settlement" }
        if mountainSideCount >= 3 { return "Coal-rich settlement" }
        return "Balanced settlement"
    }

    mutating func setFaction(_ faction: TownFaction) {
        self.faction = faction
    }
}

struct WorldTownNode: Identifiable, Codable, Equatable {
    var id: UUID { townID }
    var townID: UUID
    var x: Double
    var y: Double
}

struct TownConnection: Identifiable, Codable, Equatable, Hashable {
    var from: UUID
    var to: UUID
    var id: String { "\(from.uuidString)-\(to.uuidString)" }

    func contains(_ townID: UUID) -> Bool {
        from == townID || to == townID
    }

    func connects(_ lhs: UUID, _ rhs: UUID) -> Bool {
        (from == lhs && to == rhs) || (from == rhs && to == lhs)
    }
}

struct GameState: Codable, Equatable {
    var day: Int
    var elapsedSecondsInDay: TimeInterval
    var towns: [Town]
    var worldNodes: [WorldTownNode]
    var connections: [TownConnection]
    var world: WorldMapState
    var territory: TerritoryState
    var activeTownID: UUID
    var newsEvents: [NewsEvent] = []
    var tradeOffers: [TownTradeOffer] = []

    var activeTown: Town? {
        towns.first { $0.id == activeTownID }
    }
}

enum GamePhase: Equatable {
    case setup
    case town
    case victory
}
