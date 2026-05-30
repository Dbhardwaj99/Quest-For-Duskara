import Foundation

struct EnemyAISystem {
    private let turnsBetweenActions = 20

    func shouldAct(on day: Int) -> Bool {
        day.isMultiple(of: turnsBetweenActions)
    }

    func takeTurn(state: inout GameState, balance: GameBalance) {
        let enemyTownIDs = state.towns
            .filter { $0.faction == .enemy }
            .map(\.id)

        for townID in enemyTownIDs {
            trainSoldier(in: townID, state: &state, balance: balance)
            attackBestAdjacentTarget(from: townID, state: &state, balance: balance)
        }

        if state.town(id: state.activeTownID)?.isPlayerControlled != true,
           let nextPlayerTown = state.towns.first(where: \.isPlayerControlled) {
            state.activeTownID = nextPlayerTown.id
        }
    }

    private func trainSoldier(in townID: UUID, state: inout GameState, balance: GameBalance) {
        guard let townIndex = state.towns.firstIndex(where: { $0.id == townID }) else { return }
        let trainingOrder: [SoldierKind] = [.knight, .archer]

        for soldier in trainingOrder {
            guard let definition = balance.soldierDefinitions[soldier] else { continue }
            if state.towns[townIndex].resources.spend(definition.trainingCost) {
                state.towns[townIndex].enemyArmyStrength += definition.power
                state.towns[townIndex].resources.add(.soldiers, amount: 1)
                return
            }
        }
    }

    private func attackBestAdjacentTarget(from sourceID: UUID, state: inout GameState, balance: GameBalance) {
        guard let sourceIndex = state.towns.firstIndex(where: { $0.id == sourceID }) else { return }
        let sourceStrength = state.towns[sourceIndex].enemyArmyStrength
        let adjacentIDs = adjacentTownIDs(to: sourceID, in: state)
        let duskaraNode = state.worldNodes.first { node in
            state.town(id: node.townID)?.isDuskara == true
        }

        let targets = adjacentIDs.compactMap { targetID -> AttackCandidate? in
            guard let target = state.town(id: targetID), target.faction != .enemy else { return nil }
            let defense = defenseStrength(of: target, balance: balance)
            guard sourceStrength > defense else { return nil }
            return AttackCandidate(
                townID: targetID,
                defense: defense,
                distanceToDuskara: distance(from: targetID, to: duskaraNode, in: state),
                isDuskara: target.isDuskara
            )
        }

        guard let target = targets.sorted(by: targetPriority).first,
              let targetIndex = state.towns.firstIndex(where: { $0.id == target.townID }) else { return }

        state.towns[targetIndex].isPlayerControlled = false
        state.towns[targetIndex].faction = .enemy
        state.towns[targetIndex].enemyArmyStrength = max(15, sourceStrength / 2)
        state.towns[targetIndex].soldierRoster = SoldierRoster()
        state.towns[sourceIndex].enemyArmyStrength = max(10, sourceStrength - max(10, target.defense / 2))
    }

    private func targetPriority(_ lhs: AttackCandidate, _ rhs: AttackCandidate) -> Bool {
        if lhs.isDuskara != rhs.isDuskara { return lhs.isDuskara }
        if lhs.distanceToDuskara != rhs.distanceToDuskara { return lhs.distanceToDuskara < rhs.distanceToDuskara }
        return lhs.defense < rhs.defense
    }

    private func defenseStrength(of town: Town, balance: GameBalance) -> Int {
        if town.isPlayerControlled {
            return town.soldierRoster.armyStrength(using: balance.soldierDefinitions)
        }
        return town.enemyArmyStrength
    }

    private func adjacentTownIDs(to townID: UUID, in state: GameState) -> [UUID] {
        state.connections.compactMap { connection in
            if connection.from == townID { return connection.to }
            if connection.to == townID { return connection.from }
            return nil
        }
    }

    private func distance(from townID: UUID, to targetNode: WorldTownNode?, in state: GameState) -> Double {
        guard let sourceNode = state.worldNodes.first(where: { $0.townID == townID }), let targetNode else { return 0 }
        return abs(sourceNode.x - targetNode.x) + abs(sourceNode.y - targetNode.y)
    }

    private struct AttackCandidate {
        var townID: UUID
        var defense: Int
        var distanceToDuskara: Double
        var isDuskara: Bool
    }
}
