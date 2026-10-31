import Foundation

/// The balance tables the game runs on, read from the same GameBalance the app
/// uses, with the arithmetic a playtester would otherwise redo by hand.
enum RulesReport {
    static func json(_ balance: GameBalance = .duskDefault) -> JSON {
        let startingPlots: [BuildingKind] = [.house, .pier]
        return .object([
            ("time", .object([
                ("secondsPerDayInTheApp", .double(balance.dayDuration)),
                ("enemyTurnEveryDays", .int(balance.enemyTurnInterval)),
                ("note", .string("In the app a day passes every \(Int(balance.dayDuration)) seconds of real time. Here a day passes only on end-day.")),
            ])),
            ("start", .object([
                ("board", .string("\(balance.gridSize.columns) × \(balance.gridSize.rows) plots per island; plots on the outer ring are the shore.")),
                ("buildings", .string("Every island starts with a House in the centre (1,1) and a Pier on the shore (1,2).")),
                ("people", .int(GameRules.startingPeople(for: startingPlots, balance: balance))),
                ("stockByDifficulty", .object(Difficulty.allCases.map { difficulty in
                    var stock = ResourceWallet(balance.baseStartingResources)
                    stock.apply(difficulty.modeBalance)
                    return (difficulty.rawValue, .wallet(stock.amounts))
                })),
            ])),
            ("population", .object([
                ("growthPerDay", .string("\(Int(balance.populationGrowthRate * 100))% of housing moves in each day (at least 1) until people plus soldiers fill the Houses.")),
                ("workers", .string("Each building needs workers from the island's people; free people = people − workers.")),
            ])),
            ("buildings", .object(BuildingKind.allCases.compactMap { kind in
                guard let definition = balance.buildingDefinitions[kind] else { return nil }
                return (kind.rawValue, .object([
                    ("summary", .string(definition.summary)),
                    ("workers", .int(definition.peopleRequired)),
                    ("shoreOnly", .bool(definition.placementRules.contains(.onTownEdge))),
                    ("onePerIsland", .bool(kind == .pier)),
                    ("levels", .array((1...definition.maxLevel).map { level in
                        let cost = definition.cost(for: level)
                        let production = definition.production(for: level)
                        var fields: [(String, JSON)] = [
                            ("level", .int(level)),
                            (level == 1 ? "buildCost" : "upgradeCost", .amounts(cost)),
                            ("producesPerDay", .amounts(production)),
                        ]
                        if definition.populationCapacity > 0 { fields.append(("housing", .int(definition.populationCapacity(for: level)))) }
                        if definition.peopleOnBuild > 0 { fields.append(("peopleArrive", .int(definition.peopleOnBuild(for: level)))) }
                        if let gold = production[.gold], gold > 0 {
                            fields.append(("daysToRepayGold", .double(Double(cost[.gold] ?? 0) / Double(gold))))
                        }
                        return .object(fields)
                    })),
                ]))
            })),
            ("soldiers", .object(SoldierKind.allCases.compactMap { kind in
                guard let definition = balance.soldierDefinitions[kind] else { return nil }
                let stats = LaneBattle.stats(kind)
                return (kind.rawValue, .object([
                    ("cost", .amounts(definition.trainingCost)),
                    ("power", .int(definition.power)),
                    ("people", .int(definition.peopleRequired)),
                    ("foodPerDay", .int(definition.dailyFoodUpkeep)),
                    ("goldPerPower", .double(Double(definition.trainingCost[.gold] ?? 0) / Double(definition.power))),
                    ("foodPerDayPerPower", .double(Double(definition.dailyFoodUpkeep) / Double(definition.power))),
                    ("laneBattle", .object([
                        ("health", .double(stats.health)),
                        ("damage", .double(stats.damage)),
                        ("secondsBetweenHits", .double(stats.interval)),
                        ("range", .double(stats.range)),
                        ("speed", .double(stats.speed)),
                        ("commandCost", .double(stats.cost)),
                    ])),
                ]))
            })),
            ("priceScaleByIslandsHeld", .object((1...15).map { ("\($0)", .double(balance.priceScale(islands: $0))) })),
            ("priceNote", .string("Gold and skill prices (buildings, upgrades, soldiers) multiply by the scale, rounded to 10. Food prices don't scale. Demolishing refunds half the current gold price of a level-1 building.")),
            ("market", .object([
                ("goldValuePer100", .amounts(balance.marketValuePer100)),
                ("feePercentByPartners", .strings(balance.marketFeePercents.enumerated().map { "\($0.offset + 1)\($0.offset == balance.marketFeePercents.count - 1 ? "+" : ""): \($0.element)%" })),
                ("partners", .string("A free (neutral) city with a sea lane to one of your islands that has a Pier. Capturing a partner closes its route.")),
                ("pricing", .string("Buying pays value plus the fee (rounded up); selling earns value minus the fee (rounded down).")),
            ])),
            ("combat", .object([
                ("defense", .string("Garrison strength + \(Int(balance.garrisonDefenseBonusRate * 100))% of it + \(balance.duskaraDefenseBonus) for Duskara + \(balance.defenseBonusPerStepFromDuskara) per sea-lane step closer to Duskara than the farthest island.")),
                ("playerAttacks", .string("The active island lands its whole army and fights a lane battle against the garrison and gate. Any island can be attacked; no sea lane is needed.")),
                ("capture", .string("Survivors garrison the captured island and the attacking island is left empty. The captured island keeps its buildings and people, and loses \(balance.captureResourceLossRates.map { "\(Int($0.value * 100))% of its \($0.key.rawValue)" }.sorted().joined(separator: " and ")).")),
                ("laneBattle", .object([
                    ("lanes", .int(LaneBattle.lanes)),
                    ("timeLimitSeconds", .double(LaneBattle.timeLimit)),
                    ("command", .string("Starts at \(Int(LaneBattle.startingCommand)), +\(Int(LaneBattle.commandPerSecond))/s, max \(Int(LaneBattle.maxCommand)); landing a unit costs its command cost.")),
                    ("gateHealth", .string("\(Int(LaneBattle.gateBase)) + \(Int(LaneBattle.gatePerFortification)) per point of fortification (defense minus garrison).")),
                    ("tower", .string("Shoots the attacker nearest the gate every \(LaneBattle.towerInterval)s for \(LaneBattle.towerDamagePerFortification) × fortification.")),
                    ("defenders", .string("A third of the garrison starts on the lines; one more reinforces the most pressed lane every \(LaneBattle.reinforceInterval)s.")),
                    ("outcomes", .string("captured: the gate breaks. repelled: time runs out or every attacker falls. withdrew: the attacker retreats and survivors sail home.")),
                ])),
            ])),
            ("enemy", .object([
                ("who", .string("Every island you don't hold acts, free (neutral) cities included. Only your islands pay food upkeep.")),
                ("turn", .string("On each day divisible by \(balance.enemyTurnInterval), every such island builds the first missing of House, Pier, Farm, Barracks, Factory (or adds housing when it lacks workers), trains one Archer (else a Knight) if it has a Barracks, then may attack.")),
                ("attacks", .string("An island attacks a neighbour of another realm when it has at least \(balance.aiMinimumFoodReserve) food, \(balance.aiMinimumGoldReserve) gold and a food surplus, and its army beats the target's defense by more than \(balance.aiReserveThreshold). It prefers Duskara, then the weakest. It keeps \(balance.aiReserveThreshold) strength home. These fights auto-resolve: no lane battle; the winner loses \(Int(balance.combatWinnerCasualtyRate * 100))% of its margin.")),
            ])),
            ("victory", .string("Capture Duskara. You lose when your last island falls.")),
        ])
    }
}
