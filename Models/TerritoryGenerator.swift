import Foundation

struct TerritoryGenerator {
    func generate(towns: [Town], nodes: [WorldTownNode], world: WorldMapState) -> TerritoryState {
        guard towns.isEmpty == false, nodes.isEmpty == false, world.terrainTiles.isEmpty == false else {
            return .empty
        }

        let nodeByTownID = Dictionary(uniqueKeysWithValues: nodes.map { ($0.townID, $0) })
        let landTiles = world.terrainTiles.filter { $0.terrain.isLand }
        let terrainByCell = Dictionary(uniqueKeysWithValues: landTiles.map { ($0.cell, $0.terrain) })
        let townEntries = towns.enumerated().compactMap { index, town -> TownEntry? in
            guard let node = nodeByTownID[town.id] else { return nil }
            return TownEntry(index: index, town: town, node: node)
        }
        guard townEntries.isEmpty == false else { return .empty }

        // Only land belongs to a town; open sea stays unowned.
        var ownerByCell: [MapCell: UUID] = [:]
        for tile in landTiles {
            ownerByCell[tile.cell] = closestTown(to: tile.cell, entries: townEntries, layout: world.layout, seed: world.generation.seed).town.id
        }

        ensureEveryTownOwnsAtLeastOneCell(entries: townEntries, landTiles: landTiles, world: world, ownerByCell: &ownerByCell)

        var cellsByTownID: [UUID: [MapCell]] = [:]
        for (cell, townID) in ownerByCell {
            cellsByTownID[townID, default: []].append(cell)
        }

        let regions = townEntries.map { entry in
            let cells = (cellsByTownID[entry.town.id] ?? [])
                .sorted { lhs, rhs in
                    lhs.row == rhs.row ? lhs.column < rhs.column : lhs.row < rhs.row
                }
            let terrainMix = cells.reduce(into: [TerrainKind: Int]()) { result, cell in
                if let terrain = terrainByCell[cell] {
                    result[terrain, default: 0] += 1
                }
            }
            return TerritoryRegion(
                townID: entry.town.id,
                ownerFaction: entry.town.faction,
                anchor: MapPoint(x: entry.node.x, y: entry.node.y),
                cells: cells,
                terrainMix: terrainMix
            )
        }

        return TerritoryState(
            algorithmVersion: TerritoryState.currentAlgorithmVersion,
            regions: regions
        )
    }

    private func ensureEveryTownOwnsAtLeastOneCell(
        entries: [TownEntry],
        landTiles: [TerrainTile],
        world: WorldMapState,
        ownerByCell: inout [MapCell: UUID]
    ) {
        for entry in entries where ownerByCell.values.contains(entry.town.id) == false {
            guard let nearestCell = landTiles.min(by: { lhs, rhs in
                distanceSquared(from: lhs.cell.center(in: world.layout), to: MapPoint(x: entry.node.x, y: entry.node.y), aspectRatio: world.layout.aspectRatio)
                    < distanceSquared(from: rhs.cell.center(in: world.layout), to: MapPoint(x: entry.node.x, y: entry.node.y), aspectRatio: world.layout.aspectRatio)
            })?.cell else {
                continue
            }
            ownerByCell[nearestCell] = entry.town.id
        }
    }

    private func closestTown(
        to cell: MapCell,
        entries: [TownEntry],
        layout: MapLayout,
        seed: Int
    ) -> TownEntry {
        let point = cell.center(in: layout)
        return entries.min { lhs, rhs in
            score(point: point, cell: cell, entry: lhs, layout: layout, seed: seed)
                < score(point: point, cell: cell, entry: rhs, layout: layout, seed: seed)
        } ?? entries[0]
    }

    private func score(
        point: MapPoint,
        cell: MapCell,
        entry: TownEntry,
        layout: MapLayout,
        seed: Int
    ) -> Double {
        let anchor = MapPoint(x: entry.node.x, y: entry.node.y)
        let wobble = (WorldNoise.value(seed: seed, column: cell.column, row: cell.row, salt: entry.index + 101) - 0.5) * 0.004
        return distanceSquared(from: point, to: anchor, aspectRatio: layout.aspectRatio) + wobble
    }

    private func distanceSquared(from lhs: MapPoint, to rhs: MapPoint, aspectRatio: Double) -> Double {
        let dx = (lhs.x - rhs.x) * aspectRatio
        let dy = lhs.y - rhs.y
        return dx * dx + dy * dy
    }

    private struct TownEntry {
        var index: Int
        var town: Town
        var node: WorldTownNode
    }
}
