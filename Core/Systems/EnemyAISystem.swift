import Foundation

struct EnemyAISystem {
    private let turnsBetweenActions = 20
    private let newsStore = NewsStore()
    private let soldierTrainingSystem = SoldierTrainingSystem()
    private let buildingSystem = BuildingSystem()
    private let placementValidationSystem = PlacementValidationSystem()
    private let armyUpkeepSystem = ArmyUpkeepSystem()
    private let worldMapSystem = WorldMapSystem()

    private let infrastructurePriority: [BuildingKind] = [.house, .pier, .farm, .barracks, .factory]

    func shouldAct(on day: Int) -> Bool {
        day.isMultiple(of: turnsBetweenActions)
    }

    func takeTurn(state: inout GameState, balance: GameBalance) {
        let aiTownIDs = state.towns
            .filter { state.isHumanOwned($0) == false }
            .map(\.id)

        for townID in aiTownIDs {
            developInfrastructure(in: townID, state: &state, balance: balance)
            trainSoldier(in: townID, state: &state, balance: balance)
            attackBestAdjacentTarget(from: townID, state: &state, balance: balance)
        }
        // The active town is presentation state; GameViewModel re-picks one
        // when the player loses theirs.
    }

    private func developInfrastructure(in townID: UUID, state: inout GameState, balance: GameBalance) {
        guard let townIndex = state.towns.firstIndex(where: { $0.id == townID }) else { return }

        for kind in infrastructurePriority {
            if state.towns[townIndex].buildings.contains(where: { $0.kind == kind }) {
                continue
            }
            guard let coordinate = preferredCoordinate(
                for: kind,
                in: state.towns[townIndex],
                balance: balance
            ) else {
                continue
            }
            if buildingSystem.build(kind, at: coordinate, in: &state.towns[townIndex], balance: balance) == nil {
                newsStore.record(
                    .buildingConstruction,
                    message: "\(state.towns[townIndex].name) built a \(kind.title)",
                    state: &state
                )
                return
            }
        }
    }

    private func preferredCoordinate(
        for kind: BuildingKind,
        in town: Town,
        balance: GameBalance
    ) -> GridCoordinate? {
        let valid = placementValidationSystem.validCoordinates(for: kind, in: town, balance: balance)
        guard valid.isEmpty == false else { return nil }
        let center = GridCoordinate(x: balance.gridSize.columns / 2, y: balance.gridSize.rows / 2)
        // Explicit (distance, y, x) ordering: Set iteration is unordered, so
        // ties must break deterministically for the replicated reducer.
        return valid.min { lhs, rhs in
            let lhsDistance = abs(lhs.x - center.x) + abs(lhs.y - center.y)
            let rhsDistance = abs(rhs.x - center.x) + abs(rhs.y - center.y)
            return (lhsDistance, lhs.y, lhs.x) < (rhsDistance, rhs.y, rhs.x)
        }
    }

    private func trainSoldier(in townID: UUID, state: inout GameState, balance: GameBalance) {
        guard let townIndex = state.towns.firstIndex(where: { $0.id == townID }) else { return }
        guard state.towns[townIndex].buildings.contains(where: { $0.kind == .barracks }) else { return }

        let trainingOrder: [SoldierKind] = [.archer, .knight]
        for soldier in trainingOrder {
            if soldierTrainingSystem.train(soldier, in: &state.towns[townIndex], balance: balance) == nil {
                newsStore.record(
                    .soldierTraining,
                    message: "\(state.towns[townIndex].name) trained a \(soldier.title)",
                    state: &state
                )
                return
            }
        }
    }

    private func attackBestAdjacentTarget(from sourceID: UUID, state: inout GameState, balance: GameBalance) {
        guard let sourceIndex = state.towns.firstIndex(where: { $0.id == sourceID }) else { return }
        let sourceTown = state.towns[sourceIndex]
        guard armyUpkeepSystem.hasStableEconomy(for: sourceTown, balance: balance) else { return }

        let sourceStrength = sourceTown.armyStrength
        guard sourceStrength > balance.aiReserveThreshold else { return }

        let adjacentIDs = adjacentTownIDs(to: sourceID, in: state)
        let duskaraNode = state.worldNodes.first { node in
            state.town(id: node.townID)?.isDuskara == true
        }

        let targets = adjacentIDs.compactMap { targetID -> AttackCandidate? in
            guard let target = state.town(id: targetID), target.ownerID != sourceTown.ownerID else { return nil }
            let defense = worldMapSystem.effectiveDefenseStrength(for: target, in: state, balance: balance)
            guard sourceStrength > defense + balance.aiReserveThreshold else { return nil }
            return AttackCandidate(
                townID: targetID,
                defense: defense,
                distanceToDuskara: distance(from: targetID, to: duskaraNode, in: state),
                isDuskara: target.isDuskara
            )
        }

        guard let target = targets.sorted(by: targetPriority).first,
              let targetIndex = state.towns.firstIndex(where: { $0.id == target.townID }) else { return }

        let committedStrength = sourceStrength - balance.aiReserveThreshold
        let sourceName = state.towns[sourceIndex].name
        let targetName = state.towns[targetIndex].name
        let targetIsDuskara = state.towns[targetIndex].isDuskara
        let didCapture = worldMapSystem.resolveAttack(
            sourceIndex: sourceIndex,
            targetIndex: targetIndex,
            attackerID: sourceTown.ownerID,
            committedStrength: committedStrength,
            state: &state,
            balance: balance
        )
        if didCapture {
            newsStore.record(.cityCapture, message: "\(sourceName) captured \(targetName)", state: &state)
            if targetIsDuskara {
                newsStore.record(.duskaraAttack, message: "\(sourceName) breached Duskara", state: &state)
            }
        }
    }

    private func targetPriority(_ lhs: AttackCandidate, _ rhs: AttackCandidate) -> Bool {
        if lhs.isDuskara != rhs.isDuskara { return lhs.isDuskara }
        if lhs.distanceToDuskara != rhs.distanceToDuskara { return lhs.distanceToDuskara < rhs.distanceToDuskara }
        if lhs.defense != rhs.defense { return lhs.defense < rhs.defense }
        // Stable final tie-break so equal candidates sort identically on
        // every replica.
        return lhs.townID.uuidString < rhs.townID.uuidString
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
