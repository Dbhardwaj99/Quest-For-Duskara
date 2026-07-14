import Foundation

struct TerritoryOwnership {
    func reconcile(_ territory: TerritoryState, towns: [Town]) -> TerritoryState {
        let ownerByTownID = Dictionary(uniqueKeysWithValues: towns.map { ($0.id, $0.ownerID) })
        let regions = territory.regions.map { region in
            TerritoryRegion(
                townID: region.townID,
                ownerID: ownerByTownID[region.townID] ?? region.ownerID,
                anchor: region.anchor,
                cells: region.cells,
                terrainMix: region.terrainMix
            )
        }
        return TerritoryState(algorithmVersion: territory.algorithmVersion, regions: regions)
    }
}
