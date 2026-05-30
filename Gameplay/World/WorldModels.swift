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
    var isPlayerControlled: Bool
    var faction: TownFaction
    var isDuskara: Bool
    var enemyArmyStrength: Int
    var soldierRoster: SoldierRoster

    init(
        id: UUID = UUID(),
        name: String,
        resources: ResourceWallet = ResourceWallet(),
        buildings: [BuildingInstance] = [],
        biomeLayout: TownBiomeLayout,
        isPlayerControlled: Bool = false,
        faction: TownFaction = .neutral,
        isDuskara: Bool = false,
        enemyArmyStrength: Int = 0,
        soldierRoster: SoldierRoster = SoldierRoster()
    ) {
        self.id = id
        self.name = name
        self.resources = resources
        self.buildings = buildings
        self.biomeLayout = biomeLayout
        self.isPlayerControlled = isPlayerControlled
        self.faction = isPlayerControlled ? .player : faction
        self.isDuskara = isDuskara
        self.enemyArmyStrength = enemyArmyStrength
        self.soldierRoster = soldierRoster
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case resources
        case buildings
        case biomeLayout
        case isPlayerControlled
        case faction
        case isDuskara
        case enemyArmyStrength
        case soldierRoster
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        resources = try container.decode(ResourceWallet.self, forKey: .resources)
        buildings = try container.decode([BuildingInstance].self, forKey: .buildings)
        biomeLayout = try container.decode(TownBiomeLayout.self, forKey: .biomeLayout)
        isPlayerControlled = try container.decode(Bool.self, forKey: .isPlayerControlled)
        faction = try container.decodeIfPresent(TownFaction.self, forKey: .faction) ?? (isPlayerControlled ? .player : .neutral)
        isDuskara = try container.decodeIfPresent(Bool.self, forKey: .isDuskara) ?? false
        enemyArmyStrength = try container.decode(Int.self, forKey: .enemyArmyStrength)
        soldierRoster = try container.decode(SoldierRoster.self, forKey: .soldierRoster)
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

    var activeTown: Town? {
        towns.first { $0.id == activeTownID }
    }
}

enum GamePhase: Equatable {
    case setup
    case town
    case victory
}
