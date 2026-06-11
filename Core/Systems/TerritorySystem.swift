import Foundation

struct TerritorySystem {
    private let worldGenerator = WorldGenerator()
    private let territoryGenerator = TerritoryGenerator()
    private let territoryOwnership = TerritoryOwnership()

    func ensureWorldAndTerritory(in state: inout GameState) {
        if state.world.isEmpty {
            state.world = worldGenerator.generateWorldState()
        }

        if state.worldNodes.count != state.towns.count || state.connections.isEmpty {
            let generated = worldGenerator.generate(towns: state.towns)
            state.worldNodes = generated.nodes
            state.connections = generated.connections
            if state.world.isEmpty {
                state.world = generated.world
            }
        }

        if state.territory.isEmpty
            || state.territory.algorithmVersion != TerritoryState.currentAlgorithmVersion
            || state.territory.regions.count != state.towns.count {
            state.territory = territoryGenerator.generate(
                towns: state.towns,
                nodes: state.worldNodes,
                world: state.world
            )
        }

        reconcileOwnership(in: &state)
    }

    func generateTerritory(towns: [Town], nodes: [WorldTownNode], world: WorldMapState) -> TerritoryState {
        territoryOwnership.reconcile(
            territoryGenerator.generate(towns: towns, nodes: nodes, world: world),
            towns: towns
        )
    }

    func reconcileOwnership(in state: inout GameState) {
        state.territory = territoryOwnership.reconcile(state.territory, towns: state.towns)
    }

    func neighboringTownIDs(to townID: UUID, in state: GameState) -> [UUID] {
        let ownerByCell = makeOwnerByCell(from: state.territory)
        guard let region = state.territory.region(for: townID) else { return [] }
        var neighbors = Set<UUID>()

        for cell in region.cells {
            for adjacentCell in adjacentCells(to: cell, layout: state.world.layout) {
                guard let neighborID = ownerByCell[adjacentCell], neighborID != townID else { continue }
                neighbors.insert(neighborID)
            }
        }

        return neighbors.sorted { $0.uuidString < $1.uuidString }
    }

    func strategicSnapshot(for townID: UUID, in state: GameState) -> StrategicTerritorySnapshot? {
        guard let region = state.territory.region(for: townID) else { return nil }
        let neighboringTownIDs = neighboringTownIDs(to: townID, in: state)
        let factionByTownID = Dictionary(uniqueKeysWithValues: state.towns.map { ($0.id, $0.faction) })
        let borderTownIDs = neighboringTownIDs.filter { factionByTownID[$0] != region.ownerFaction }

        return StrategicTerritorySnapshot(
            townID: townID,
            ownerFaction: region.ownerFaction,
            cellCount: region.cellCount,
            neighboringTownIDs: neighboringTownIDs,
            borderTownIDs: borderTownIDs,
            terrainMix: region.terrainMix
        )
    }

    func borderTownIDs(for faction: TownFaction, in state: GameState) -> [UUID] {
        state.territory.regions.compactMap { region in
            guard region.ownerFaction == faction else { return nil }
            let snapshot = strategicSnapshot(for: region.townID, in: state)
            return snapshot?.borderTownIDs.isEmpty == false ? region.townID : nil
        }
        .sorted { $0.uuidString < $1.uuidString }
    }

    private func makeOwnerByCell(from territory: TerritoryState) -> [MapCell: UUID] {
        var ownerByCell: [MapCell: UUID] = [:]
        for region in territory.regions {
            for cell in region.cells {
                ownerByCell[cell] = region.townID
            }
        }
        return ownerByCell
    }

    private func adjacentCells(to cell: MapCell, layout: MapLayout) -> [MapCell] {
        [
            MapCell(column: cell.column - 1, row: cell.row),
            MapCell(column: cell.column + 1, row: cell.row),
            MapCell(column: cell.column, row: cell.row - 1),
            MapCell(column: cell.column, row: cell.row + 1)
        ]
        .filter(layout.contains)
    }
}
