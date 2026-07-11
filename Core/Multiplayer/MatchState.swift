import Foundation

/// Durable lifecycle of a match. Stored server-side; presentation state like
/// GamePhase.setup never appears here.
enum MatchStatus: String, Codable, Equatable {
    case lobby
    case active
    case victory
    case defeat
    case abandoned
}

/// The replicated, mutable half of a game: everything the authoritative
/// reducer may change. Immutable world data lives in WorldDefinition, and
/// presentation-only values (active town, selection, camera, trade UI
/// timers) intentionally have no home here.
///
/// Explicit wire DTO: string IDs, string enum raw values, string-keyed maps.
struct MatchState: Codable, Equatable {
    var roomID: String
    var revision: Int
    var schemaVersion: Int
    var rulesVersion: Int
    var status: MatchStatus
    var day: Int
    /// Server timestamp (ms since epoch) of the moment the current day
    /// started. Clients render day progress from this plus ServerClock.
    var dayStartServerMillis: Int64
    var towns: [TownState]
    var news: [NewsEventDTO]
    var tradeOffers: [TradeOfferDTO]
    /// Monotonic counter behind deterministic entity-ID minting.
    var entityCounter: Int
}

struct TradeOfferDTO: Codable, Equatable {
    var id: String
    var townID: String
    var partnerID: String
    /// resource rawValue -> amount
    var wants: [String: Int]
    var gives: [String: Int]
    var expiresOnDay: Int
}

/// Mutable per-town state, keyed to a TownDefinition by id.
struct TownState: Codable, Equatable {
    var id: String
    var faction: String
    var armyStrength: Int
    /// resource rawValue -> amount
    var resources: [String: Int]
    /// soldier rawValue -> count
    var soldiers: [String: Int]
    var buildings: [BuildingState]
}

struct BuildingState: Codable, Equatable {
    var id: String
    var kind: String
    var x: Int
    var y: Int
    var level: Int
}

struct NewsEventDTO: Codable, Equatable {
    var id: String
    var day: Int
    var kind: String
    var message: String
}

// MARK: - Domain model <-> DTO

extension MatchState {
    init(
        state: GameState,
        roomID: String,
        revision: Int
    ) {
        self.roomID = roomID
        self.revision = revision
        self.schemaVersion = SchemaVersion.current
        self.rulesVersion = SchemaVersion.rules
        self.status = state.status
        self.day = state.day
        self.dayStartServerMillis = state.dayStartServerMillis
        self.towns = state.towns.map(TownState.init(town:))
        self.news = state.newsEvents.map {
            NewsEventDTO(id: $0.id.uuidString, day: $0.day, kind: $0.kind.rawValue, message: $0.message)
        }
        self.tradeOffers = state.tradeOffers.map(TradeOfferDTO.init(offer:))
        self.entityCounter = state.entityCounter
    }
}

extension TradeOfferDTO {
    init(offer: TownTradeOffer) {
        id = offer.id
        townID = offer.townID.uuidString
        partnerID = offer.partnerID.uuidString
        wants = Dictionary(uniqueKeysWithValues: offer.wants.map { ($0.key.rawValue, $0.value) })
        gives = Dictionary(uniqueKeysWithValues: offer.gives.map { ($0.key.rawValue, $0.value) })
        expiresOnDay = offer.expiresOnDay
    }

    func offer() throws -> TownTradeOffer {
        guard let town = UUID(uuidString: townID), let partner = UUID(uuidString: partnerID) else {
            throw ReplicationCodecError.invalidUUID("\(townID)/\(partnerID)")
        }
        var wantAmounts: [ResourceKind: Int] = [:]
        for (raw, amount) in wants {
            guard let kind = ResourceKind(rawValue: raw) else { throw ReplicationCodecError.unknownRawValue(raw) }
            wantAmounts[kind] = amount
        }
        var giveAmounts: [ResourceKind: Int] = [:]
        for (raw, amount) in gives {
            guard let kind = ResourceKind(rawValue: raw) else { throw ReplicationCodecError.unknownRawValue(raw) }
            giveAmounts[kind] = amount
        }
        return TownTradeOffer(id: id, townID: town, partnerID: partner, wants: wantAmounts, gives: giveAmounts, expiresOnDay: expiresOnDay)
    }
}

extension TownState {
    init(town: Town) {
        id = town.id.uuidString
        faction = town.faction.rawValue
        armyStrength = town.armyStrength
        resources = Dictionary(uniqueKeysWithValues: town.resources.amounts.map { ($0.key.rawValue, $0.value) })
        soldiers = Dictionary(uniqueKeysWithValues: town.soldierRoster.counts.map { ($0.key.rawValue, $0.value) })
        buildings = town.buildings.map {
            BuildingState(id: $0.id.uuidString, kind: $0.kind.rawValue, x: $0.coordinate.x, y: $0.coordinate.y, level: $0.level)
        }
    }
}

extension GameState {
    /// Reassembles the local working model from the replication boundary.
    init(world: WorldDefinition, match: MatchState) throws {
        let definitionsByID = Dictionary(uniqueKeysWithValues: world.towns.map { ($0.id, $0) })
        let towns: [Town] = try match.towns.map { townState in
            guard let definition = definitionsByID[townState.id] else {
                throw ReplicationCodecError.unknownTown(townState.id)
            }
            guard let id = UUID(uuidString: townState.id) else {
                throw ReplicationCodecError.invalidUUID(townState.id)
            }
            guard let faction = TownFaction(rawValue: townState.faction) else {
                throw ReplicationCodecError.unknownRawValue(townState.faction)
            }
            var wallet = ResourceWallet()
            for (raw, amount) in townState.resources {
                guard let kind = ResourceKind(rawValue: raw) else {
                    throw ReplicationCodecError.unknownRawValue(raw)
                }
                wallet[kind] = amount
            }
            var roster = SoldierRoster()
            for (raw, count) in townState.soldiers {
                guard let kind = SoldierKind(rawValue: raw) else {
                    throw ReplicationCodecError.unknownRawValue(raw)
                }
                roster[kind] = count
            }
            let buildings: [BuildingInstance] = try townState.buildings.map { building in
                guard let buildingID = UUID(uuidString: building.id) else {
                    throw ReplicationCodecError.invalidUUID(building.id)
                }
                guard let kind = BuildingKind(rawValue: building.kind) else {
                    throw ReplicationCodecError.unknownRawValue(building.kind)
                }
                return BuildingInstance(
                    id: buildingID,
                    kind: kind,
                    coordinate: GridCoordinate(x: building.x, y: building.y),
                    level: building.level
                )
            }
            return Town(
                id: id,
                name: definition.name,
                resources: wallet,
                buildings: buildings,
                biomeLayout: try world.biomeLayout(for: definition),
                faction: faction,
                isDuskara: definition.isDuskara,
                armyStrength: townState.armyStrength,
                soldierRoster: roster
            )
        }

        let newsEvents: [NewsEvent] = try match.news.map { dto in
            guard let id = UUID(uuidString: dto.id) else { throw ReplicationCodecError.invalidUUID(dto.id) }
            guard let kind = NewsEvent.Kind(rawValue: dto.kind) else {
                throw ReplicationCodecError.unknownRawValue(dto.kind)
            }
            return NewsEvent(id: id, day: dto.day, kind: kind, message: dto.message)
        }

        self.init(
            day: match.day,
            dayStartServerMillis: match.dayStartServerMillis,
            towns: towns,
            worldNodes: try world.worldNodes(),
            connections: try world.townConnections(),
            world: try world.worldMapState(),
            territory: try world.territoryState(towns: towns),
            status: match.status,
            newsEvents: newsEvents,
            tradeOffers: try match.tradeOffers.map { try $0.offer() },
            entityCounter: match.entityCounter
        )
    }
}
