import Foundation

struct World3DTileSnapshot: Identifiable, Equatable {
    enum Content: Equatable {
        case grass
        case water
        case tree
        case mountain
        case building(BuildingKind)
    }

    var id: GridCoordinate { coordinate }
    var coordinate: GridCoordinate
    var content: Content
    var isOccupied: Bool {
        if case .grass = content { return false }
        if case .water = content { return false }
        return true
    }
}

enum World3DPlacementTool: CaseIterable {
    case building
    case tree
    case mountain
    case clear

    var title: String {
        switch self {
        case .building: "Building"
        case .tree: "Tree"
        case .mountain: "Mountain"
        case .clear: "Clear"
        }
    }
}

struct World3DStateAdapter {
    private(set) var town: Town
    private(set) var balance: GameBalance
    private var decorations: [GridCoordinate: World3DTileSnapshot.Content] = [:]
    private let buildingSystem = BuildingSystem()

    init(sourceViewModel: GameViewModel) {
        var adaptedBalance = sourceViewModel.balance
        adaptedBalance.gridSize = GridSize(columns: 9, rows: 9)
        adaptedBalance.baseStartingResources = ResourceKind.allCases.reduce(into: [:]) { totals, kind in
            totals[kind] = max(sourceViewModel.balance.baseStartingResources[kind, default: 0], 250)
        }

        var adaptedTown = sourceViewModel.activeTown
        adaptedTown.resources = ResourceWallet(adaptedBalance.baseStartingResources)
        adaptedTown.buildings = adaptedTown.buildings.filter { adaptedBalance.gridSize.contains($0.coordinate) }

        self.town = adaptedTown
        self.balance = adaptedBalance
    }

    var gridSize: GridSize { balance.gridSize }

    func tileSnapshot(at coordinate: GridCoordinate) -> World3DTileSnapshot {
        if let building = town.buildings.first(where: { $0.coordinate == coordinate }) {
            return World3DTileSnapshot(coordinate: coordinate, content: .building(building.kind))
        }

        if let decoration = decorations[coordinate] {
            return World3DTileSnapshot(coordinate: coordinate, content: decoration)
        }

        return World3DTileSnapshot(coordinate: coordinate, content: isWaterCoordinate(coordinate) ? .water : .grass)
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

    mutating func apply(_ tool: World3DPlacementTool, at coordinate: GridCoordinate) -> String {
        guard gridSize.contains(coordinate) else { return "Out of bounds" }

        switch tool {
        case .building:
            decorations[coordinate] = nil
            if let failure = buildingSystem.build(.house, at: coordinate, in: &town, balance: balance) {
                return failure.rawValue
            }
            return "Placed house at \(coordinate.x), \(coordinate.y)"
        case .tree:
            return placeDecoration(.tree, at: coordinate, label: "tree")
        case .mountain:
            return placeDecoration(.mountain, at: coordinate, label: "mountain")
        case .clear:
            town.buildings.removeAll { $0.coordinate == coordinate }
            decorations[coordinate] = nil
            return "Cleared \(coordinate.x), \(coordinate.y)"
        }
    }

    private mutating func placeDecoration(_ content: World3DTileSnapshot.Content, at coordinate: GridCoordinate, label: String) -> String {
        guard town.buildings.contains(where: { $0.coordinate == coordinate }) == false else {
            return "That plot is already occupied."
        }
        guard isWaterCoordinate(coordinate) == false else {
            return "Cannot place \(label) on water."
        }
        decorations[coordinate] = content
        return "Placed \(label) at \(coordinate.x), \(coordinate.y)"
    }

    private func isWaterCoordinate(_ coordinate: GridCoordinate) -> Bool {
        let middle = gridSize.columns / 2
        if town.biomeLayout.sides.values.contains(.river) {
            return coordinate.x == middle || (coordinate.y == gridSize.rows - 1 && abs(coordinate.x - middle) <= 1)
        }
        return coordinate.x == middle && coordinate.y > 1 && coordinate.y < gridSize.rows - 2
    }
}
