import Foundation

/// Immutable generated world data, written once when a match is created and
/// never patched afterwards. Everything mutable lives in MatchState.
///
/// This is an explicit wire DTO: string IDs, string enum raw values, and
/// string-keyed maps only, so the encoded form is a stable backend contract
/// independent of Swift's Dictionary/UUID/Date encoding details.
struct WorldDefinition: Codable, Equatable {
    var schemaVersion: Int
    var seed: Int
    var algorithmVersion: Int
    var templateID: String

    var mapColumns: Int
    var mapRows: Int
    var aspectRatio: Double
    var playableInset: Double

    var towns: [TownDefinition]
    var nodes: [WorldNodeDTO]
    var connections: [ConnectionDTO]
    var terrain: [TerrainTileDTO]
    var landmarks: [LandmarkDTO]
    var territories: [TerritoryDefinition]
    var territoryAlgorithmVersion: Int
}

/// Immutable identity of a town. Mutable town state lives in TownState.
struct TownDefinition: Codable, Equatable {
    var id: String
    var name: String
    var isDuskara: Bool
    /// side rawValue -> biome rawValue
    var biomeSides: [String: String]
}

struct WorldNodeDTO: Codable, Equatable {
    var townID: String
    var x: Double
    var y: Double
}

struct ConnectionDTO: Codable, Equatable {
    var from: String
    var to: String
}

struct TerrainTileDTO: Codable, Equatable {
    var column: Int
    var row: Int
    var terrain: String
}

struct LandmarkDTO: Codable, Equatable {
    var id: String
    var name: String
    var kind: String
    var x: Double
    var y: Double
}

/// Territory cells are generated once; ownership is derived from town
/// factions in MatchState, so it is deliberately absent here.
struct TerritoryDefinition: Codable, Equatable {
    var townID: String
    var anchorX: Double
    var anchorY: Double
    var cells: [MapCellDTO]
    /// terrain rawValue -> cell count
    var terrainMix: [String: Int]
}

struct MapCellDTO: Codable, Equatable {
    var column: Int
    var row: Int
}

enum ReplicationCodecError: Error, Equatable {
    case invalidUUID(String)
    case unknownRawValue(String)
    case unknownTown(String)
}

// MARK: - Domain model -> DTO

extension WorldDefinition {
    /// Captures the immutable part of a freshly generated game.
    init(state: GameState) {
        schemaVersion = SchemaVersion.current
        seed = state.world.generation.seed
        algorithmVersion = state.world.generation.algorithmVersion
        templateID = state.world.generation.templateID
        mapColumns = state.world.layout.columns
        mapRows = state.world.layout.rows
        aspectRatio = state.world.layout.aspectRatio
        playableInset = state.world.layout.playableInset
        towns = state.towns.map { town in
            TownDefinition(
                id: town.id.uuidString,
                name: town.name,
                isDuskara: town.isDuskara,
                biomeSides: Dictionary(uniqueKeysWithValues: town.biomeLayout.sides.map {
                    ($0.key.rawValue, $0.value.rawValue)
                })
            )
        }
        nodes = state.worldNodes.map { WorldNodeDTO(townID: $0.townID.uuidString, x: $0.x, y: $0.y) }
        connections = state.connections
            .map { ConnectionDTO(from: $0.from.uuidString, to: $0.to.uuidString) }
            .sorted { ($0.from, $0.to) < ($1.from, $1.to) }
        terrain = state.world.terrainTiles.map {
            TerrainTileDTO(column: $0.cell.column, row: $0.cell.row, terrain: $0.terrain.rawValue)
        }
        landmarks = state.world.landmarks.map {
            LandmarkDTO(id: $0.id.uuidString, name: $0.name, kind: $0.kind.rawValue, x: $0.position.x, y: $0.position.y)
        }
        territories = state.territory.regions.map { region in
            TerritoryDefinition(
                townID: region.townID.uuidString,
                anchorX: region.anchor.x,
                anchorY: region.anchor.y,
                cells: region.cells.map { MapCellDTO(column: $0.column, row: $0.row) },
                terrainMix: Dictionary(uniqueKeysWithValues: region.terrainMix.map { ($0.key.rawValue, $0.value) })
            )
        }
        territoryAlgorithmVersion = state.territory.algorithmVersion
    }
}

// MARK: - DTO -> domain model pieces

extension WorldDefinition {
    func mapLayout() -> MapLayout {
        MapLayout(columns: mapColumns, rows: mapRows, aspectRatio: aspectRatio, playableInset: playableInset)
    }

    func worldMapState() throws -> WorldMapState {
        WorldMapState(
            generation: WorldGenerationState(seed: seed, algorithmVersion: algorithmVersion, templateID: templateID),
            layout: mapLayout(),
            terrainTiles: try terrain.map {
                guard let kind = TerrainKind(rawValue: $0.terrain) else {
                    throw ReplicationCodecError.unknownRawValue($0.terrain)
                }
                return TerrainTile(cell: MapCell(column: $0.column, row: $0.row), terrain: kind)
            },
            landmarks: try landmarks.map {
                guard let id = UUID(uuidString: $0.id) else { throw ReplicationCodecError.invalidUUID($0.id) }
                guard let kind = WorldLandmarkKind(rawValue: $0.kind) else {
                    throw ReplicationCodecError.unknownRawValue($0.kind)
                }
                return WorldLandmark(id: id, name: $0.name, kind: kind, position: MapPoint(x: $0.x, y: $0.y))
            }
        )
    }

    func worldNodes() throws -> [WorldTownNode] {
        try nodes.map {
            guard let townID = UUID(uuidString: $0.townID) else { throw ReplicationCodecError.invalidUUID($0.townID) }
            return WorldTownNode(townID: townID, x: $0.x, y: $0.y)
        }
    }

    func townConnections() throws -> [TownConnection] {
        try connections.map {
            guard let from = UUID(uuidString: $0.from), let to = UUID(uuidString: $0.to) else {
                throw ReplicationCodecError.invalidUUID("\($0.from)-\($0.to)")
            }
            return TownConnection(from: from, to: to)
        }
    }

    func biomeLayout(for town: TownDefinition) throws -> TownBiomeLayout {
        var sides: [BiomeSide: BiomeKind] = [:]
        for (sideRaw, biomeRaw) in town.biomeSides {
            guard let side = BiomeSide(rawValue: sideRaw), let biome = BiomeKind(rawValue: biomeRaw) else {
                throw ReplicationCodecError.unknownRawValue("\(sideRaw):\(biomeRaw)")
            }
            sides[side] = biome
        }
        return TownBiomeLayout(sides: sides)
    }

    /// Territory with ownership filled in from the given towns.
    func territoryState(towns: [Town]) throws -> TerritoryState {
        let factionByID = Dictionary(uniqueKeysWithValues: towns.map { ($0.id, $0.faction) })
        let regions: [TerritoryRegion] = try territories.map { definition in
            guard let townID = UUID(uuidString: definition.townID) else {
                throw ReplicationCodecError.invalidUUID(definition.townID)
            }
            var mix: [TerrainKind: Int] = [:]
            for (raw, count) in definition.terrainMix {
                guard let kind = TerrainKind(rawValue: raw) else {
                    throw ReplicationCodecError.unknownRawValue(raw)
                }
                mix[kind] = count
            }
            return TerritoryRegion(
                townID: townID,
                ownerFaction: factionByID[townID] ?? .neutral,
                anchor: MapPoint(x: definition.anchorX, y: definition.anchorY),
                cells: definition.cells.map { MapCell(column: $0.column, row: $0.row) },
                terrainMix: mix
            )
        }
        return TerritoryState(algorithmVersion: territoryAlgorithmVersion, regions: regions)
    }
}
