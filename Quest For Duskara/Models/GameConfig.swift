import Foundation

struct GameBalance {
    var gridSize: GridSize
    var dayDuration: TimeInterval
    var baseStartingResources: [ResourceKind: Int]
    var bonusPool: Int
    var buildingDefinitions: [BuildingKind: BuildingDefinition]
    var soldierDefinitions: [SoldierKind: SoldierDefinition]

    static let duskDefault = GameBalance(
        gridSize: GridSize(columns: 7, rows: 9),
        dayDuration: 60,
        baseStartingResources: [
            .gold: 100,
            .wood: 100,
            .coal: 100,
            .tech: 50,
            .food: 0,
            .people: 0,
            .soldiers: 0
        ],
        bonusPool: 100,
        buildingDefinitions: [
            .house: BuildingDefinition(
                kind: .house,
                summary: "Adds people and raises population capacity.",
                baseCost: [.gold: 25, .wood: 30, .coal: 10],
                baseProduction: [:],
                peopleRequired: 0,
                peopleOnBuild: 4,
                populationCapacity: 8,
                maxLevel: 3,
                placementRules: [.none]
            ),
            .farm: BuildingDefinition(
                kind: .farm,
                summary: "Turns labor into daily food and gold.",
                baseCost: [.gold: 35, .wood: 35, .coal: 10],
                baseProduction: [.gold: 8, .food: 14],
                peopleRequired: 2,
                peopleOnBuild: 0,
                populationCapacity: 0,
                maxLevel: 3,
                placementRules: [.none]
            ),
            .woodMill: BuildingDefinition(
                kind: .woodMill,
                summary: "Harvests wood when built beside a forest edge.",
                baseCost: [.gold: 30, .wood: 20, .coal: 12],
                baseProduction: [.wood: 18],
                peopleRequired: 2,
                peopleOnBuild: 0,
                populationCapacity: 0,
                maxLevel: 3,
                placementRules: [.adjacentToBiome(.forest)]
            ),
            .coalMine: BuildingDefinition(
                kind: .coalMine,
                summary: "Extracts coal when built beside mountain terrain.",
                baseCost: [.gold: 35, .wood: 25, .coal: 10],
                baseProduction: [.coal: 16],
                peopleRequired: 2,
                peopleOnBuild: 0,
                populationCapacity: 0,
                maxLevel: 3,
                placementRules: [.adjacentToBiome(.mountain)]
            ),
            .lab: BuildingDefinition(
                kind: .lab,
                summary: "Generates technology for upgrades and soldiers.",
                baseCost: [.gold: 45, .wood: 25, .coal: 25],
                baseProduction: [.tech: 7],
                peopleRequired: 3,
                peopleOnBuild: 0,
                populationCapacity: 0,
                maxLevel: 3,
                placementRules: [.none]
            ),
            .barracks: BuildingDefinition(
                kind: .barracks,
                summary: "Unlocks soldier training actions.",
                baseCost: [.gold: 60, .wood: 40, .coal: 30],
                baseProduction: [:],
                peopleRequired: 4,
                peopleOnBuild: 0,
                populationCapacity: 0,
                maxLevel: 3,
                placementRules: [.none]
            )
        ],
        soldierDefinitions: [
            .archer: SoldierDefinition(kind: .archer, trainingCost: [.gold: 20, .tech: 5, .food: 10], power: 10),
            .knight: SoldierDefinition(kind: .knight, trainingCost: [.gold: 45, .tech: 15, .food: 25], power: 20)
        ]
    )
}
