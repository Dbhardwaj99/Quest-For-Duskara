import Foundation

func makeNewGame(balance: GameBalance) -> GameState {
    let layouts = [
        TownBiomeLayout(sides: [.left: .forest, .right: .mountain, .top: .forest, .bottom: .mountain]),
        TownBiomeLayout(sides: [.left: .forest, .top: .forest, .right: .forest, .bottom: .mountain]),
        TownBiomeLayout(sides: [.left: .mountain, .right: .mountain, .top: .mountain, .bottom: .mountain]),
        TownBiomeLayout(sides: [.left: .forest, .right: .forest, .top: .forest, .bottom: .forest]),
        TownBiomeLayout(sides: [.left: .mountain, .right: .forest, .top: .mountain, .bottom: .forest]),
        TownBiomeLayout(sides: [.left: .forest, .right: .mountain, .top: .mountain, .bottom: .mountain])
    ]
    let names = [
        "Hearthglen", "Green Hollow", "Ironridge", "Mosswatch", "Ashbarrow", "Pinefall", "Stonewake", "Rivergate", "Brindle Keep", "Oakmere",
        "Frostford", "Briarwall", "Duskwatch", "Sunreach", "Valehold", "Cinder Pass", "Deepwood", "Crownhill", "Greyfen", "Moonford",
        "Westmere", "Northbarrow", "Dawnfield", "Elderwick", "Foxgrove", "Highmere", "Willowdeep", "Amberfall", "Ravenford", "Thornwatch",
        "Glasswater", "Kingsford", "Mistvale", "Barrowmere", "Emberwick", "Wolfscar", "Blackfen", "Grimhaven", "Redspire", "Duskara"
    ]
    let enemies: Set<String> = ["Wolfscar", "Blackfen", "Grimhaven", "Redspire"]
    let center = GridCoordinate(x: balance.gridSize.columns / 2, y: balance.gridSize.rows / 2)
    let shoreline = GridCoordinate(x: center.x, y: balance.gridSize.rows - 1)

    var towns = names.enumerated().map { index, name in
        Town(
            name: name,
            resources: ResourceWallet([.gold: 60 + index * 6, .skill: 20 + index, .food: 30, .people: 4]),
            buildings: [
                BuildingInstance(kind: .house, coordinate: center),
                BuildingInstance(kind: .pier, coordinate: shoreline)
            ],
            biomeLayout: layouts[index % layouts.count],
            faction: name == "Duskara" ? .duskara : (enemies.contains(name) ? .enemy : .neutral),
            isDuskara: name == "Duskara"
        )
    }
    towns[0].faction = .player
    towns[0].resources = ResourceWallet(balance.baseStartingResources)

    let generated = WorldGenerator().generate(towns: towns)
    if let duskara = towns.first(where: \.isDuskara)?.id {
        let distances = GameRules.graphDistances(from: duskara, connections: generated.connections)
        let maxDistance = max(distances.values.max() ?? 1, 1)
        for index in towns.indices where towns[index].isPlayerControlled == false {
            let distance = distances[towns[index].id] ?? maxDistance
            let variation = index % 6
            let strength = towns[index].isDuskara ? 180
                : distance <= 1 ? 35 + variation * 5
                : distance <= max(2, maxDistance / 2) ? 20 + min(15, variation * 3)
                : distance < maxDistance ? 10 + min(10, variation * 2)
                : 3 + min(5, variation)
            towns[index].soldierRoster = SoldierRoster.decompose(strength: strength, using: balance.soldierDefinitions)
            towns[index].armyStrength = towns[index].soldierRoster.armyStrength(using: balance.soldierDefinitions)
            towns[index].resources[.soldiers] = towns[index].armyStrength
        }
    }

    let territory = TerritoryGenerator().generate(towns: towns, nodes: generated.nodes, world: generated.world)
    return GameState(
        day: 1,
        elapsedSecondsInDay: 0,
        towns: towns,
        worldNodes: generated.nodes,
        connections: generated.connections,
        world: generated.world,
        territory: territory,
        activeTownID: towns[0].id
    )
}
