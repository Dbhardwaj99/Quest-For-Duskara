import Foundation

struct MapPoint: Codable, Equatable, Hashable {
    var x: Double
    var y: Double
}

struct MapCell: Codable, Equatable, Hashable {
    var column: Int
    var row: Int

    var id: String {
        "\(column)-\(row)"
    }

    func center(in layout: MapLayout) -> MapPoint {
        MapPoint(
            x: (Double(column) + 0.5) / Double(max(1, layout.columns)),
            y: (Double(row) + 0.5) / Double(max(1, layout.rows))
        )
    }
}

struct MapLayout: Codable, Equatable {
    var columns: Int
    var rows: Int
    var aspectRatio: Double
    var playableInset: Double

    static let standard = MapLayout(columns: 58, rows: 40, aspectRatio: 1.45, playableInset: 0.09)
    static let legacy = MapLayout(columns: 28, rows: 20, aspectRatio: 1.35, playableInset: 0.065)

    var cellWidth: Double {
        1.0 / Double(max(1, columns))
    }

    var cellHeight: Double {
        1.0 / Double(max(1, rows))
    }

    func contains(_ cell: MapCell) -> Bool {
        cell.column >= 0 && cell.column < columns && cell.row >= 0 && cell.row < rows
    }
}

struct WorldGenerationState: Codable, Equatable {
    var seed: Int
    var algorithmVersion: Int
    var templateID: String

    static let empty = WorldGenerationState(seed: 0, algorithmVersion: 0, templateID: "none")
}

struct WorldMapState: Codable, Equatable {
    var generation: WorldGenerationState
    var layout: MapLayout
    var terrainTiles: [TerrainTile]
    var landmarks: [WorldLandmark]

    static let empty = WorldMapState(
        generation: .empty,
        layout: .legacy,
        terrainTiles: [],
        landmarks: []
    )

    var isEmpty: Bool {
        terrainTiles.isEmpty
    }
}

enum WorldLandmarkKind: String, Codable, Equatable, CaseIterable {
    case ancientRuin
    case forestShrine
    case mountainGate
    case coastalHarbor
    case desertObelisk

    var title: String {
        switch self {
        case .ancientRuin: return "Ancient Ruin"
        case .forestShrine: return "Forest Shrine"
        case .mountainGate: return "Mountain Gate"
        case .coastalHarbor: return "Coastal Harbor"
        case .desertObelisk: return "Desert Obelisk"
        }
    }
}

struct WorldLandmark: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var kind: WorldLandmarkKind
    var position: MapPoint

    init(
        id: UUID = UUID(),
        name: String,
        kind: WorldLandmarkKind,
        position: MapPoint
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.position = position
    }
}
