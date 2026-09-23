import Foundation

struct GameBalance {
    var gridSize: GridSize
    var dayDuration: TimeInterval
    /// Enemy islands build, train and attack on every day divisible by this.
    var enemyTurnInterval: Int
    var baseStartingResources: [ResourceKind: Int]
    var aiReserveThreshold: Int
    var aiMinimumFoodReserve: Int
    var aiMinimumGoldReserve: Int
    var captureResourceLossRates: [ResourceKind: Double]
    var combatWinnerCasualtyRate: Double
    var garrisonDefenseBonusRate: Double
    var duskaraDefenseBonus: Int
    var defenseBonusPerStepFromDuskara: Int
    /// Each island the player holds beyond the first adds this much to every
    /// gold and skill price they pay, so a growing income never makes building
    /// free. Food is left alone: upkeep already scales it with the army.
    var priceStepPerIsland: Double
    /// Share of an island's housing capacity that moves in each day, until the
    /// Houses are full (soldiers count against them too).
    var populationGrowthRate: Double
    /// What free cities value goods at, in gold per 100 units.
    var marketValuePer100: [ResourceKind: Int]
    /// Harbor Market fee, by how many free cities trade with the player: the
    /// first partner charges the first rate, four or more the last.
    var marketFeePercents: [Int]
    var buildingDefinitions: [BuildingKind: BuildingDefinition]
    var soldierDefinitions: [SoldierKind: SoldierDefinition]

    static let duskDefault = GameBalance(
        gridSize: GridSize(columns: 3, rows: 3),
        dayDuration: 10,
        enemyTurnInterval: 10,
        baseStartingResources: [
            .gold: 1_000,
            .skill: 500,
            .food: 0,
            .people: 0,
            .soldiers: 0
        ],
        aiReserveThreshold: 12,
        aiMinimumFoodReserve: 400,
        aiMinimumGoldReserve: 800,
        captureResourceLossRates: [
            .gold: 0.50,
            .skill: 0.50,
        ],
        combatWinnerCasualtyRate: 0.25,
        garrisonDefenseBonusRate: 0.35,
        duskaraDefenseBonus: 55,
        defenseBonusPerStepFromDuskara: 4,
        priceStepPerIsland: 0.25,
        populationGrowthRate: 0.25,
        marketValuePer100: [.food: 50, .skill: 200],
        marketFeePercents: [30, 25, 20, 15],
        buildingDefinitions: [
            .house: BuildingDefinition(
                kind: .house,
                summary: "Adds people and raises population capacity.",
                // Gold only, like the Factory: an island with no skill must
                // still be able to house the workers a Factory needs.
                baseCost: [.gold: 300],
                baseProduction: [:],
                peopleRequired: 0,
                peopleOnBuild: 4,
                populationCapacity: 8,
                maxLevel: 3,
                placementRules: [.none]
            ),
            .pier: BuildingDefinition(
                kind: .pier,
                summary: "Brings in daily gold from sea trade.",
                baseCost: [.gold: 400, .skill: 200],
                baseProduction: [.gold: 100],
                peopleRequired: 2,
                peopleOnBuild: 0,
                populationCapacity: 0,
                maxLevel: 3,
                placementRules: [.onTownEdge]
            ),
            .farm: BuildingDefinition(
                kind: .farm,
                summary: "Turns labor into daily food and gold.",
                baseCost: [.gold: 400, .skill: 200],
                baseProduction: [.gold: 40, .food: 140],
                peopleRequired: 2,
                peopleOnBuild: 0,
                populationCapacity: 0,
                maxLevel: 3,
                placementRules: [.none]
            ),
            .factory: BuildingDefinition(
                kind: .factory,
                summary: "Generates technology for upgrades and soldiers.",
                // No skill cost: the Factory is what produces skill, so charging
                // it gates the only way out of having none.
                baseCost: [.gold: 500],
                baseProduction: [.skill: 70],
                peopleRequired: 3,
                peopleOnBuild: 0,
                populationCapacity: 0,
                maxLevel: 3,
                placementRules: [.none]
            ),
            .barracks: BuildingDefinition(
                kind: .barracks,
                summary: "Unlocks soldier training actions.",
                baseCost: [.gold: 800, .skill: 300],
                baseProduction: [:],
                peopleRequired: 4,
                peopleOnBuild: 0,
                populationCapacity: 0,
                // Nothing reads a Barracks' level, so upgrades only cost.
                maxLevel: 1,
                placementRules: [.none]
            )
        ],
        soldierDefinitions: [
            .archer: SoldierDefinition(
                kind: .archer,
                trainingCost: [.gold: 200, .skill: 50, .food: 100],
                power: 10,
                peopleRequired: 1,
                dailyFoodUpkeep: 20
            ),
            .knight: SoldierDefinition(
                kind: .knight,
                trainingCost: [.gold: 450, .skill: 150, .food: 250],
                power: 24,
                peopleRequired: 2,
                dailyFoodUpkeep: 40
            )
        ]
    )

    /// Gold and skill prices multiply by `priceScale(islands:)`, rounded to 10.
    func priced(forIslands islands: Int) -> GameBalance {
        let scale = priceScale(islands: islands)
        guard scale != 1 else { return self }
        func scaled(_ cost: [ResourceKind: Int]) -> [ResourceKind: Int] {
            Dictionary(uniqueKeysWithValues: cost.map { kind, amount in
                (kind, kind == .food ? amount : Int((Double(amount) * scale / 10).rounded()) * 10)
            })
        }
        var copy = self
        copy.buildingDefinitions = buildingDefinitions.mapValues { var definition = $0; definition.baseCost = scaled($0.baseCost); return definition }
        copy.soldierDefinitions = soldierDefinitions.mapValues { var definition = $0; definition.trainingCost = scaled($0.trainingCost); return definition }
        return copy
    }

    func priceScale(islands: Int) -> Double {
        1 + priceStepPerIsland * Double(max(0, islands - 1))
    }
}
