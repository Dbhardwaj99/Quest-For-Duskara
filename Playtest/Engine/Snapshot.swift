import Foundation

extension PlaytestSession {
    enum View: String {
        /// Your islands in full, the rest as targets, and what you can do now.
        case brief
        /// Adds every island's stores and buildings, price tables and sea lanes.
        case full
    }

    func snapshot(_ view: View) -> JSON {
        let state = game.state
        var fields: [(String, JSON)] = [
            ("day", .int(state.day)),
            ("phase", .string(phaseName)),
            ("difficulty", .string(difficulty.rawValue)),
            ("seed", .int(seed)),
            ("enemyTurnInDays", .int(daysUntilEnemyTurn)),
            ("activeTown", .string(game.activeTown.name)),
            ("empire", empireJSON()),
            ("market", marketJSON(view)),
            ("yourTowns", .array(game.playerTowns.map(playerTownJSON))),
            ("otherTowns", .array(otherTowns.map { otherTownJSON($0, view) })),
            ("options", optionsJSON()),
            ("recentNews", .strings(state.newsEvents.prefix(view == .full ? 20 : 6).map { "day \($0.day): \($0.message)" })),
        ]
        if view == .full {
            fields.append(("prices", pricesJSON()))
            fields.append(("seaLanes", .strings(state.connections.compactMap { lane in
                guard let from = state.town(id: lane.from), let to = state.town(id: lane.to) else { return nil }
                return "\(from.name) – \(to.name)"
            }.sorted())))
        }
        return .object(fields)
    }

    /// Weakest first, Duskara last among equals.
    private var otherTowns: [Town] {
        game.state.towns.filter { $0.isPlayerControlled == false }.map { ($0, game.effectiveDefenseStrength(for: $0)) }
            .sorted { ($0.1, $0.0.name) < ($1.1, $1.0.name) }
            .map(\.0)
    }

    private func empireJSON() -> JSON {
        .object([
            ("stock", .wallet(GameRules.empireStock(game.state).amounts)),
            ("netPerDay", .wallet(game.empireIncome)),
            ("foodUpkeepPerDay", .int(game.playerTowns.reduce(0) { $0 + GameRules.dailyFood($1, balance: game.balance) })),
            ("army", .int(game.empireArmyStrength)),
            ("islands", .int(game.playerTowns.count)),
            ("priceScale", .double(game.priceScale)),
        ])
    }

    private func marketJSON(_ view: View) -> JSON {
        guard let fee = game.marketFeePercent else {
            return .object([("open", .bool(false)), ("why", .string("No island of yours with a Pier has a sea lane to a free city."))])
        }
        var fields: [(String, JSON)] = [
            ("open", .bool(true)),
            ("partners", .strings(game.tradePartners.map(\.name).sorted())),
            ("feePercent", .int(fee)),
            ("surplusFood", .int(game.surplusFood)),
        ]
        if view == .full {
            fields.append(("goldPerLot", .object([ResourceKind.food, .skill].map { kind in
                (kind.rawValue, .object([100, 1_000].flatMap { lot in
                    [("buy\(lot)", .int(game.marketPrice(of: kind, lot: lot, buying: true) ?? 0)),
                     ("sell\(lot)", .int(game.marketPrice(of: kind, lot: lot, buying: false) ?? 0))]
                }))
            })))
        }
        return .object(fields)
    }

    private func playerTownJSON(_ town: Town) -> JSON {
        let balance = game.balance
        return .object([
            ("name", .string(town.name)),
            ("active", .bool(town.id == game.state.activeTownID)),
            ("stored", .wallet(town.resources.amounts)),
            ("people", .int(town.resources[.people])),
            ("freePeople", .int(GameRules.freePeople(town, balance: balance))),
            ("housing", .int(GameRules.populationCapacity(town, balance: balance))),
            ("army", .int(town.armyStrength)),
            ("units", .units(town.soldierRoster)),
            ("foodUpkeep", .int(GameRules.dailyFood(town, balance: balance))),
            ("production", .wallet(GameRules.income(town, balance: balance))),
            ("defense", .int(game.effectiveDefenseStrength(for: town))),
            ("buildings", .strings(buildingNames(town))),
            ("emptyPlots", .strings(emptyPlots(town).map { "\($0.x),\($0.y)" })),
            ("neighbors", .strings(neighbors(of: town).map(\.name))),
        ])
    }

    private func otherTownJSON(_ town: Town, _ view: View) -> JSON {
        let neighbors = neighbors(of: town)
        var fields: [(String, JSON)] = [
            ("name", .string(town.name)),
            ("faction", .string(town.faction.rawValue)),
            ("defense", .int(game.effectiveDefenseStrength(for: town))),
            ("army", .int(town.armyStrength)),
            ("units", .units(town.soldierRoster)),
            ("bordersYou", .bool(neighbors.contains(where: \.isPlayerControlled))),
            ("neighbors", .strings(neighbors.map(\.name))),
        ]
        if view == .full {
            fields.append(("stored", .amounts(town.resources.amounts)))
            fields.append(("production", .wallet(GameRules.income(town, balance: game.balance))))
            fields.append(("buildings", .strings(buildingNames(town))))
        }
        return .object(fields)
    }

    /// What the active island can do right now, as the app's buttons stand.
    private func optionsJSON() -> JSON {
        let town = game.activeTown
        let prices = game.playerBalance
        var fields: [(String, JSON)] = []

        fields.append(("build", .strings(BuildingKind.allCases.compactMap { kind -> String? in
            if kind == .pier, town.buildings.contains(where: { $0.kind == .pier }) { return nil }
            guard let definition = prices.buildingDefinitions[kind] else { return nil }
            let cost = definition.cost(for: 1)
            let head = "\(kind.rawValue) (\(priceText(cost)), \(definition.peopleRequired) workers)"
            let missing = game.shortfall(for: cost)
            if missing.isEmpty == false { return "\(head): need \(shortfallText(missing))" }
            let plots = GameRules.validCoordinates(for: kind, in: game.spendingTown, balance: prices)
                .sorted { ($0.y, $0.x) < ($1.y, $1.x) }
            if plots.isEmpty {
                let free = GameRules.freePeople(town, balance: game.balance)
                return free < definition.peopleRequired ? "\(head): need \(definition.peopleRequired - free) more free people" : "\(head): no plot fits"
            }
            return "\(head) at " + plots.map { "\($0.x),\($0.y)" }.joined(separator: " | ")
        })))

        fields.append(("upgrade", .strings(town.buildings.sorted { ($0.coordinate.y, $0.coordinate.x) < ($1.coordinate.y, $1.coordinate.x) }
            .compactMap { building -> String? in
                guard let definition = game.balance.buildingDefinitions[building.kind], building.level < definition.maxLevel else { return nil }
                let cost = game.upgradeCost(building)
                let head = "\(building.kind.rawValue) @\(building.coordinate.x),\(building.coordinate.y) to L\(building.level + 1) (\(priceText(cost)))"
                return game.canUpgrade(building) ? head : "\(head): need \(shortfallText(game.shortfall(for: cost)))"
            })))

        if town.buildings.contains(where: { $0.kind == .barracks }) {
            fields.append(("train", .strings(SoldierKind.allCases.compactMap { kind in
                guard let definition = prices.soldierDefinitions[kind] else { return nil }
                let head = "\(kind.rawValue) (\(priceText(definition.trainingCost)), power \(definition.power), eats \(definition.dailyFoodUpkeep)/day)"
                return game.trainingUnavailableReason(for: kind).map { "\(head): \($0)" } ?? head
            })))
        } else {
            fields.append(("train", .strings(["Build a Barracks on this island to train soldiers."])))
        }

        if game.isMarketOpen {
            var trades: [String] = []
            for kind in [ResourceKind.food, .skill] {
                for lot in [100, 1_000] {
                    for buying in [false, true] where game.canTrade(kind, lot: lot, buying: buying) {
                        let price = game.marketPrice(of: kind, lot: lot, buying: buying) ?? 0
                        trades.append("\(buying ? "buy" : "sell") \(kind.rawValue) \(lot) (\(buying ? "-" : "+")\(price)g)")
                    }
                }
            }
            if game.surplusFood > 0 {
                trades.append("sell-surplus (\(game.surplusFood) food, +\(game.marketPrice(of: .food, lot: game.surplusFood, buying: false) ?? 0)g)")
            }
            fields.append(("trade", .strings(trades)))
        }

        let power = game.activeArmyStrength
        fields.append(("attack", .strings(power > 0
            ? otherTowns.map { target in
                let defense = game.effectiveDefenseStrength(for: target)
                return "\(target.name): your \(power) vs defense \(defense) (\(BattleBriefing.odds(power: power, defense: defense)))"
            }
            : ["\(town.name) has no army."])))
        if game.transferDestinations.contains(where: { $0.armyStrength > 0 }) {
            fields.append(("rally", .string("rally-attack or pull-all adds \(game.empireArmyStrength - power) power from your other islands.")))
        }
        return .object(fields)
    }

    private func pricesJSON() -> JSON {
        let prices = game.playerBalance
        return .object([
            ("buildings", .object(BuildingKind.allCases.compactMap { kind in
                guard let definition = prices.buildingDefinitions[kind] else { return nil }
                return (kind.rawValue, .object((1...definition.maxLevel).map { level in
                    (level == 1 ? "build" : "toLevel\(level)", .string(priceText(definition.cost(for: level))))
                }))
            })),
            ("soldiers", .object(SoldierKind.allCases.compactMap { kind in
                prices.soldierDefinitions[kind].map { (kind.rawValue, .string(priceText($0.trainingCost))) }
            })),
        ])
    }

    private func buildingNames(_ town: Town) -> [String] {
        town.buildings.sorted { ($0.coordinate.y, $0.coordinate.x) < ($1.coordinate.y, $1.coordinate.x) }
            .map { "\($0.kind.rawValue) L\($0.level) @\($0.coordinate.x),\($0.coordinate.y)" }
    }

    private func emptyPlots(_ town: Town) -> [GridCoordinate] {
        let grid = game.balance.gridSize
        return (0..<grid.rows).flatMap { y in
            (0..<grid.columns).map { GridCoordinate(x: $0, y: y) }
        }.filter { plot in town.buildings.contains { $0.coordinate == plot } == false }
    }
}
