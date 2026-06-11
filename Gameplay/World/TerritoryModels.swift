import Foundation

struct TerritoryState: Codable, Equatable {
    var algorithmVersion: Int
    var regions: [TerritoryRegion]

    static let currentAlgorithmVersion = 1
    static let empty = TerritoryState(algorithmVersion: 0, regions: [])

    var isEmpty: Bool {
        regions.isEmpty
    }

    func region(for townID: UUID) -> TerritoryRegion? {
        regions.first { $0.townID == townID }
    }
}

struct TerritoryRegion: Identifiable, Codable, Equatable {
    var townID: UUID
    var ownerFaction: TownFaction
    var anchor: MapPoint
    var cells: [MapCell]
    var terrainMix: [TerrainKind: Int]

    var id: UUID {
        townID
    }

    var cellCount: Int {
        cells.count
    }
}

struct TerritoryAdjacency: Codable, Equatable, Hashable {
    var townID: UUID
    var neighboringTownID: UUID
}

struct StrategicTerritorySnapshot: Equatable {
    var townID: UUID
    var ownerFaction: TownFaction
    var cellCount: Int
    var neighboringTownIDs: [UUID]
    var borderTownIDs: [UUID]
    var terrainMix: [TerrainKind: Int]
}
