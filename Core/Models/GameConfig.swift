import Foundation

struct GameBalance {
    var gridSize: GridSize
    var dayDuration: TimeInterval
    var baseStartingResources: [ResourceKind: Int]
    var bonusPool: Int
    var aiReserveThreshold: Int
    var aiMinimumFoodReserve: Int
    var aiMinimumGoldReserve: Int
    var captureResourceLossRates: [ResourceKind: Double]
    var combatWinnerCasualtyRate: Double
    var garrisonDefenseBonusRate: Double
    var importantCityDefenseBonus: Int
    var duskaraDefenseBonus: Int
    var defenseBonusPerStepFromDuskara: Int
    var buildingDefinitions: [BuildingKind: BuildingDefinition]
    var soldierDefinitions: [SoldierKind: SoldierDefinition]

    static let duskDefault = GameBalance(
        gridSize: GridSize(columns: 3, rows: 3),
        dayDuration: 60,
        baseStartingResources: [
            .gold: 100,
            .skill: 50,
            .food: 0,
            .people: 0,
            .soldiers: 0
        ],
        bonusPool: 100,
        aiReserveThreshold: 12,
        aiMinimumFoodReserve: 40,
        aiMinimumGoldReserve: 80,
        captureResourceLossRates: [
            .gold: 0.50,
            .skill: 0.50,
            .tech: 0.50
        ],
        combatWinnerCasualtyRate: 0.25,
        garrisonDefenseBonusRate: 0.35,
        importantCityDefenseBonus: 18,
        duskaraDefenseBonus: 55,
        defenseBonusPerStepFromDuskara: 4,
        buildingDefinitions: [
            .house: BuildingDefinition(
                kind: .house,
                summary: "Adds people and raises population capacity.",
				baseCost: [.gold: 25, .skill: 10],
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
                baseCost: [.gold: 35, .skill: 20],
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
                baseCost: [.gold: 30, .skill: 10],
				baseProduction: [:],
                peopleRequired: 2,
                peopleOnBuild: 0,
                populationCapacity: 0,
                maxLevel: 3,
                placementRules: [.adjacentToBiome(.forest)]
            ),
            .coalMine: BuildingDefinition(
                kind: .coalMine,
                summary: "Extracts coal when built beside mountain terrain.",
                baseCost: [.gold: 35, .skill: 10],
				baseProduction: [:],
                peopleRequired: 2,
                peopleOnBuild: 0,
                populationCapacity: 0,
                maxLevel: 3,
                placementRules: [.adjacentToBiome(.mountain)]
            ),
            .lab: BuildingDefinition(
                kind: .lab,
                summary: "Generates technology for upgrades and soldiers.",
                baseCost: [.gold: 45, .skill: 10],
                baseProduction: [.skill: 7],
                peopleRequired: 3,
                peopleOnBuild: 0,
                populationCapacity: 0,
                maxLevel: 3,
                placementRules: [.none]
            ),
            .barracks: BuildingDefinition(
                kind: .barracks,
                summary: "Unlocks soldier training actions.",
                baseCost: [.gold: 60, .skill: 30],
                baseProduction: [:],
                peopleRequired: 4,
                peopleOnBuild: 0,
                populationCapacity: 0,
                maxLevel: 3,
                placementRules: [.none]
            )
        ],
        soldierDefinitions: [
            .archer: SoldierDefinition(
                kind: .archer,
                trainingCost: [.gold: 20, .skill: 5, .food: 10],
                power: 10,
                peopleRequired: 1,
                dailyFoodUpkeep: 2
            ),
            .knight: SoldierDefinition(
                kind: .knight,
                trainingCost: [.gold: 45, .skill: 15, .food: 25],
                power: 20,
                peopleRequired: 2,
                dailyFoodUpkeep: 4
            )
        ]
    )
}
