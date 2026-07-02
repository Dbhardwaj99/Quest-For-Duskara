import Foundation

struct TerritorySystem {
    private let territoryGenerator = TerritoryGenerator()
    private let territoryOwnership = TerritoryOwnership()

    func generateTerritory(towns: [Town], nodes: [WorldTownNode], world: WorldMapState) -> TerritoryState {
        territoryOwnership.reconcile(
            territoryGenerator.generate(towns: towns, nodes: nodes, world: world),
            towns: towns
        )
    }

    func reconcileOwnership(in state: inout GameState) {
        state.territory = territoryOwnership.reconcile(state.territory, towns: state.towns)
    }
}
