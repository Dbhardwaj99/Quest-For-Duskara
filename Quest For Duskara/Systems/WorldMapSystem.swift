import Foundation

struct WorldMapSystem {
    func makeInitialState(balance: GameBalance) -> GameState {
        var towns = makeTowns(balance: balance)
        towns[0].isPlayerControlled = true
        towns[0].resources = ResourceWallet(balance.baseStartingResources)

        let nodes = towns.enumerated().map { index, town in
            WorldTownNode(townID: town.id, x: nodePosition(for: index).0, y: nodePosition(for: index).1)
        }
        let connections = makeConnections(townIDs: towns.map(\.id))

        return GameState(
            day: 1,
            elapsedSecondsInDay: 0,
            towns: towns,
            worldNodes: nodes,
            connections: connections,
            activeTownID: towns[0].id
        )
    }

    func adjacentTownIDs(to townID: UUID, in state: GameState) -> [UUID] {
        state.connections.compactMap { connection in
            if connection.from == townID { return connection.to }
            if connection.to == townID { return connection.from }
            return nil
        }
    }

    func canAttack(targetID: UUID, from sourceID: UUID, in state: GameState) -> Bool {
        guard state.towns.first(where: { $0.id == sourceID })?.isPlayerControlled == true else { return false }
        guard state.towns.first(where: { $0.id == targetID })?.isPlayerControlled == false else { return false }
        return state.connections.contains { $0.connects(sourceID, targetID) }
    }

    func attack(targetID: UUID, from sourceID: UUID, state: inout GameState, balance: GameBalance) -> Bool {
        guard canAttack(targetID: targetID, from: sourceID, in: state) else { return false }
        guard let source = state.towns.first(where: { $0.id == sourceID }) else { return false }
        let playerPower = source.soldierRoster.armyStrength(using: balance.soldierDefinitions)
        guard let targetIndex = state.towns.firstIndex(where: { $0.id == targetID }) else { return false }
        guard playerPower > state.towns[targetIndex].enemyArmyStrength else { return false }
        state.towns[targetIndex].isPlayerControlled = true
        state.towns[targetIndex].enemyArmyStrength = 0
        return true
    }

    private func makeTowns(balance: GameBalance) -> [Town] {
        let layouts: [TownBiomeLayout] = [
            TownBiomeLayout(sides: [.left: .forest, .right: .mountain, .top: .forest, .bottom: .mountain]),
            TownBiomeLayout(sides: [.left: .forest, .top: .forest, .right: .plains, .bottom: .mountain]),
            TownBiomeLayout(sides: [.left: .mountain, .right: .mountain, .top: .plains, .bottom: .plains]),
            TownBiomeLayout(sides: [.left: .forest, .right: .forest, .top: .forest, .bottom: .plains]),
            TownBiomeLayout(sides: [.left: .plains, .right: .mountain, .top: .mountain, .bottom: .river])
        ]
        let names = [
            "Duskara", "Green Hollow", "Ironridge", "Mosswatch", "Ashbarrow", "Pinefall", "Stonewake", "Rivergate", "Brindle Keep", "Oakmere",
            "Frostford", "Briarwall", "Greyfen", "Sunreach", "Valehold", "Cinder Pass", "Deepwood", "Crownhill", "Hearthglen", "Moonford",
            "Redspire", "Westmere", "Northbarrow", "Dawnfield", "Elderwick"
        ]

        return names.enumerated().map { index, name in
            let layout = layouts[index % layouts.count]
            let resources = ResourceWallet([
                .gold: 60 + index * 6,
                .wood: layout.sides.values.contains(.forest) ? 120 : 50,
                .coal: layout.sides.values.contains(.mountain) ? 110 : 45,
                .tech: 20 + index,
                .food: 30,
                .people: 4,
                .soldiers: 0
            ])
            return Town(
                name: name,
                resources: resources,
                buildings: starterBuildings(for: index, balance: balance),
                biomeLayout: layout,
                isPlayerControlled: false,
                enemyArmyStrength: 25 + index * 8
            )
        }
    }

    private func starterBuildings(for index: Int, balance: GameBalance) -> [BuildingInstance] {
        let center = GridCoordinate(x: balance.gridSize.columns / 2, y: balance.gridSize.rows / 2)
        var buildings = [BuildingInstance(kind: .house, coordinate: center)]
        if index % 2 == 0 {
            buildings.append(BuildingInstance(kind: .farm, coordinate: GridCoordinate(x: center.x, y: center.y + 1)))
        }
        return buildings
    }

    private func nodePosition(for index: Int) -> (Double, Double) {
        let column = index / 5
        let row = index % 5
        let x = 0.08 + Double(column) * 0.18
        let yOffsets = [0.12, 0.30, 0.48, 0.66, 0.84]
        let drift = column.isMultiple(of: 2) ? 0.0 : 0.06
        return (min(0.94, x), min(0.90, yOffsets[row] + drift))
    }

    private func makeConnections(townIDs: [UUID]) -> [TownConnection] {
        var connections: Set<TownConnection> = []
        for index in townIDs.indices {
            if index + 5 < townIDs.count {
                connections.insert(TownConnection(from: townIDs[index], to: townIDs[index + 5]))
            }
            if index % 5 < 4 && index + 1 < townIDs.count {
                connections.insert(TownConnection(from: townIDs[index], to: townIDs[index + 1]))
            }
            if index % 5 < 4 && index + 6 < townIDs.count {
                connections.insert(TownConnection(from: townIDs[index], to: townIDs[index + 6]))
            }
        }
        return Array(connections)
    }
}
