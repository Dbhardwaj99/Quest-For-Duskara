import Foundation

struct Town: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var resources: ResourceWallet
    var buildings: [BuildingInstance]
    var biomeLayout: TownBiomeLayout
    var isPlayerControlled: Bool
    var enemyArmyStrength: Int
    var soldierRoster: SoldierRoster

    init(
        id: UUID = UUID(),
        name: String,
        resources: ResourceWallet = ResourceWallet(),
        buildings: [BuildingInstance] = [],
        biomeLayout: TownBiomeLayout,
        isPlayerControlled: Bool = false,
        enemyArmyStrength: Int = 0,
        soldierRoster: SoldierRoster = SoldierRoster()
    ) {
        self.id = id
        self.name = name
        self.resources = resources
        self.buildings = buildings
        self.biomeLayout = biomeLayout
        self.isPlayerControlled = isPlayerControlled
        self.enemyArmyStrength = enemyArmyStrength
        self.soldierRoster = soldierRoster
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
}
