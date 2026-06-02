import Foundation

enum TownFaction: String, Codable, Equatable {
    case player
    case neutral
    case enemy
    case duskara
}

struct Town: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var resources: ResourceWallet
    var buildings: [BuildingInstance]
    var biomeLayout: TownBiomeLayout
    var faction: TownFaction
    var isDuskara: Bool
    var armyStrength: Int
    var soldierRoster: SoldierRoster

    init(
        id: UUID = UUID(),
        name: String,
        resources: ResourceWallet = ResourceWallet(),
        buildings: [BuildingInstance] = [],
        biomeLayout: TownBiomeLayout,
        faction: TownFaction = .neutral,
        isDuskara: Bool = false,
        armyStrength: Int = 0,
        soldierRoster: SoldierRoster = SoldierRoster()
    ) {
        self.id = id
        self.name = name
        self.resources = resources
        self.buildings = buildings
        self.biomeLayout = biomeLayout
        self.faction = faction
        self.isDuskara = isDuskara
        self.armyStrength = armyStrength
        self.soldierRoster = soldierRoster
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case resources
        case buildings
        case biomeLayout
        case faction
        case isDuskara
        case armyStrength
        case soldierRoster
        case isPlayerControlled
        case enemyArmyStrength
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        resources = try container.decode(ResourceWallet.self, forKey: .resources)
        buildings = try container.decode([BuildingInstance].self, forKey: .buildings)
        biomeLayout = try container.decode(TownBiomeLayout.self, forKey: .biomeLayout)
        isDuskara = try container.decodeIfPresent(Bool.self, forKey: .isDuskara) ?? false
        soldierRoster = try container.decodeIfPresent(SoldierRoster.self, forKey: .soldierRoster) ?? SoldierRoster()

        if let decodedFaction = try container.decodeIfPresent(TownFaction.self, forKey: .faction) {
            faction = decodedFaction
        } else if try container.decodeIfPresent(Bool.self, forKey: .isPlayerControlled) == true {
            faction = .player
        } else {
            faction = .neutral
        }

        let legacyEnemyStrength = try container.decodeIfPresent(Int.self, forKey: .enemyArmyStrength) ?? 0
        armyStrength = try container.decodeIfPresent(Int.self, forKey: .armyStrength)
            ?? (faction == .player ? resources[.soldiers] : legacyEnemyStrength)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(resources, forKey: .resources)
        try container.encode(buildings, forKey: .buildings)
        try container.encode(biomeLayout, forKey: .biomeLayout)
        try container.encode(faction, forKey: .faction)
        try container.encode(isDuskara, forKey: .isDuskara)
        try container.encode(armyStrength, forKey: .armyStrength)
        try container.encode(soldierRoster, forKey: .soldierRoster)
    }

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
    var activeTownID: UUID
    var newsEvents: [NewsEvent]

    init(
        day: Int,
        elapsedSecondsInDay: TimeInterval,
        towns: [Town],
        worldNodes: [WorldTownNode],
        connections: [TownConnection],
        activeTownID: UUID,
        newsEvents: [NewsEvent] = []
    ) {
        self.day = day
        self.elapsedSecondsInDay = elapsedSecondsInDay
        self.towns = towns
        self.worldNodes = worldNodes
        self.connections = connections
        self.activeTownID = activeTownID
        self.newsEvents = newsEvents
    }

    enum CodingKeys: String, CodingKey {
        case day
        case elapsedSecondsInDay
        case towns
        case worldNodes
        case connections
        case activeTownID
        case newsEvents
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        day = try container.decode(Int.self, forKey: .day)
        elapsedSecondsInDay = try container.decode(TimeInterval.self, forKey: .elapsedSecondsInDay)
        towns = try container.decode([Town].self, forKey: .towns)
        worldNodes = try container.decode([WorldTownNode].self, forKey: .worldNodes)
        connections = try container.decode([TownConnection].self, forKey: .connections)
        activeTownID = try container.decode(UUID.self, forKey: .activeTownID)
        newsEvents = try container.decodeIfPresent([NewsEvent].self, forKey: .newsEvents) ?? []
    }

    var activeTown: Town? {
        towns.first { $0.id == activeTownID }
    }
}

enum GamePhase: Equatable {
    case setup
    case town
    case victory
}
