import Foundation

struct TerritoryOwnership {
    func reconcile(_ territory: TerritoryState, towns: [Town]) -> TerritoryState {
        let factionByTownID = Dictionary(uniqueKeysWithValues: towns.map { ($0.id, $0.faction) })
        let regions = territory.regions.map { region in
            TerritoryRegion(
                townID: region.townID,
                ownerFaction: factionByTownID[region.townID] ?? region.ownerFaction,
                anchor: region.anchor,
                cells: region.cells,
                terrainMix: region.terrainMix
            )
        }
        return TerritoryState(algorithmVersion: territory.algorithmVersion, regions: regions)
    }
}
