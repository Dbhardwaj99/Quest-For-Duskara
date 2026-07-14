import Foundation

struct World3DTileSnapshot: Identifiable, Equatable {
    enum Content: Equatable {
        case grass
        case water
        case tree
        case mountain
        case building(BuildingKind, level: Int)
    }

    var id: GridCoordinate { coordinate }
    var coordinate: GridCoordinate
    var content: Content
    var placementState: TilePlacementState
}

enum World3DDecorationKind: CaseIterable {
    case tree
    case mountain

    var title: String {
        switch self {
        case .tree: "Tree"
        case .mountain: "Mountain"
        }
    }

    var content: World3DTileSnapshot.Content {
        switch self {
        case .tree: .tree
        case .mountain: .mountain
        }
    }
}

@MainActor
struct World3DStateAdapter {
    let viewModel: GameViewModel
    private(set) var decorations: [GridCoordinate: World3DTileSnapshot.Content] = [:]

    init(viewModel: GameViewModel) {
        self.viewModel = viewModel
    }

    var town: Town { viewModel.activeTown }
    var balance: GameBalance { viewModel.balance }
    var gridSize: GridSize { balance.gridSize }

    func tileSnapshot(at coordinate: GridCoordinate) -> World3DTileSnapshot {
        let content: World3DTileSnapshot.Content
        if let building = town.buildings.first(where: { $0.coordinate == coordinate }) {
            content = .building(building.kind, level: building.level)
        } else if let decoration = decorations[coordinate] {
            content = decoration
        } else {
            content = .grass
        }

        return World3DTileSnapshot(
            coordinate: coordinate,
            content: content,
            placementState: viewModel.tilePlacementState(for: coordinate)
        )
    }

    func allTileSnapshots() -> [World3DTileSnapshot] {
        var tiles: [World3DTileSnapshot] = []
        for y in 0..<gridSize.rows {
            for x in 0..<gridSize.columns {
                tiles.append(tileSnapshot(at: GridCoordinate(x: x, y: y)))
            }
        }
        return tiles
    }

    mutating func placeDecoration(_ decoration: World3DDecorationKind, at coordinate: GridCoordinate) -> String {
        guard gridSize.contains(coordinate) else { return "Out of bounds" }
        guard town.buildings.contains(where: { $0.coordinate == coordinate }) == false else {
            return "That plot already has a building."
        }
        decorations[coordinate] = decoration.content
        return "Placed \(decoration.title.lowercased()) at \(coordinate.x), \(coordinate.y)."
    }

    mutating func clearDecoration(at coordinate: GridCoordinate) -> String {
        guard gridSize.contains(coordinate) else { return "Out of bounds" }
        if decorations.removeValue(forKey: coordinate) == nil {
            return "No decoration to clear at \(coordinate.x), \(coordinate.y)."
        }
        return "Cleared decoration at \(coordinate.x), \(coordinate.y)."
    }
}
