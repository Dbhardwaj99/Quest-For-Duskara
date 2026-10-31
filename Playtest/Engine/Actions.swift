import Foundation

/// Each action does what its button does: it is refused when the app would
/// grey the button out or hide it, and otherwise calls the same GameViewModel
/// method the button calls. Prices are checked against what the shared
/// stockpile actually paid.
extension PlaytestSession {
    func execute(_ command: PlaytestCommand) -> Outcome {
        switch command {
        case .state: Outcome(ok: true, message: "")
        case let .build(kind, plot): build(kind, at: plot)
        case let .upgrade(plot): upgrade(at: plot)
        case let .demolish(plot): demolish(at: plot)
        case let .train(kind, count): train(kind, count: count)
        case let .switchTo(name): switchTo(name)
        case let .trade(kind, lot, buying, times): trade(kind, lot: lot, buying: buying, times: times)
        case .sellSurplusFood: sellSurplusFood()
        case let .send(name, all): move(name, all: all, sending: true)
        case let .pull(name, all): move(name, all: all, sending: false)
        case .pullAll: pullAll()
        case let .attack(name, plan, rally): attack(name, plan: plan, rally: rally)
        case let .scout(name, plan): scout(name, plan: plan)
        case let .endDay(count): endDays(count)
        }
    }

    // MARK: - Town

    private func build(_ kind: BuildingKind, at plot: GridCoordinate) -> Outcome {
        let town = game.activeTown
        // The build menu leaves the Pier out once the island has one, and greys
        // out a card the shared stockpile can't pay for.
        if kind == .pier, town.buildings.contains(where: { $0.kind == .pier }) {
            return .blocked("\(town.name) already has a Pier, so the build menu doesn't offer one.")
        }
        let cost = game.playerBalance.buildingDefinitions[kind]?.cost(for: 1) ?? [:]
        let missing = game.shortfall(for: cost)
        guard missing.isEmpty else { return .blocked("The \(kind.title) card is greyed out: need \(shortfallText(missing)).") }
        return run(paying: cost) {
            game.place(kind, at: plot)
        } succeeded: {
            town.buildings.contains { $0.coordinate == plot } == false
                && game.activeTown.buildings.contains { $0.coordinate == plot && $0.kind == kind }
        }
    }

    private func upgrade(at plot: GridCoordinate) -> Outcome {
        guard let building = building(at: plot) else { return .blocked("No building on plot \(plot.x),\(plot.y) of \(game.activeTown.name).") }
        guard let definition = game.balance.buildingDefinitions[building.kind], building.level < definition.maxLevel else {
            return .blocked("That \(building.kind.title) is at its top level, so its sheet has no Upgrade button.")
        }
        let cost = game.upgradeCost(building)
        guard game.canUpgrade(building) else {
            return .blocked("The Upgrade button is greyed out: need \(shortfallText(game.shortfall(for: cost))).")
        }
        game.selectedBuildingID = building.id
        return run(paying: cost) {
            game.upgradeSelectedBuilding()
        } succeeded: {
            game.activeTown.buildings.first { $0.id == building.id }?.level == building.level + 1
        }
    }

    private func demolish(at plot: GridCoordinate) -> Outcome {
        guard let building = building(at: plot) else { return .blocked("No building on plot \(plot.x),\(plot.y) of \(game.activeTown.name).") }
        let refund = (game.playerBalance.buildingDefinitions[building.kind]?.cost(for: 1)[.gold] ?? 0) / 2
        game.selectedBuildingID = building.id
        return run(paying: [:], receiving: [.gold: refund]) {
            game.demolishSelectedBuilding()
        } succeeded: {
            game.activeTown.buildings.contains { $0.id == building.id } == false
        }
    }

    private func train(_ kind: SoldierKind, count: Int) -> Outcome {
        guard game.activeTown.buildings.contains(where: { $0.kind == .barracks }) else {
            return .blocked("\(game.activeTown.name) has no Barracks, so there is nowhere to train.")
        }
        var trained = 0
        var stop: Outcome?
        var violations: [String] = []
        while trained < count, stop == nil {
            if let reason = game.trainingUnavailableReason(for: kind) {
                stop = .blocked("The Train button is greyed out: \(reason)")
                break
            }
            let cost = game.playerBalance.soldierDefinitions[kind]?.trainingCost ?? [:]
            let before = game.activeTown.soldierRoster[kind]
            let step = run(paying: cost) { game.train(kind) } succeeded: { game.activeTown.soldierRoster[kind] == before + 1 }
            violations += step.violations
            if step.ok { trained += 1 } else { stop = step }
        }
        var outcome = Outcome(ok: trained == count, message: "Trained \(trained) of \(count) \(kind.rawValue)\(count == 1 ? "" : "s").")
        if let stop, trained < count { outcome.message += " " + stop.message; outcome.blocked = stop.blocked && trained == 0 }
        outcome.details = [("trained", .int(trained))]
        outcome.violations = violations
        return outcome
    }

    private func switchTo(_ name: String) -> Outcome {
        guard let town = town(named: name) else { return unknownTown(name) }
        guard town.isPlayerControlled else { return .blocked("\(town.name) isn't yours.") }
        game.switchToTown(town.id)
        return Outcome(ok: game.state.activeTownID == town.id, message: "\(town.name) is the active island.")
    }

    // MARK: - Harbor Market

    private func trade(_ kind: ResourceKind, lot: Int, buying: Bool, times: Int) -> Outcome {
        guard game.isMarketOpen else {
            return .blocked("The Harbor Market is closed: none of your islands with a Pier has a sea lane to a free city.")
        }
        var done = 0
        var stop: Outcome?
        var violations: [String] = []
        var gold = 0
        while done < times, stop == nil {
            guard game.canTrade(kind, lot: lot, buying: buying), let price = game.marketPrice(of: kind, lot: lot, buying: buying) else {
                stop = .blocked("That trade button is greyed out: not enough \(buying ? "gold" : kind.rawValue).")
                break
            }
            let before = GameRules.empireStock(game.state)[kind]
            let step = run(paying: buying ? [.gold: price] : [kind: lot], receiving: buying ? [kind: lot] : [.gold: price]) {
                game.trade(kind, lot: lot, buying: buying)
            } succeeded: {
                GameRules.empireStock(game.state)[kind] != before
            }
            violations += step.violations
            if step.ok { done += 1; gold += buying ? -price : price } else { stop = step }
        }
        let verb = buying ? "Bought" : "Sold"
        var outcome = Outcome(ok: done == times, message: "\(verb) \(done) × \(lot) \(kind.rawValue); gold \(gold >= 0 ? "+" : "")\(gold).")
        if let stop, done < times { outcome.message += " " + stop.message; outcome.blocked = stop.blocked && done == 0 }
        outcome.details = [("gold", .int(gold))]
        outcome.violations = violations
        if done > 0 { stats.trades += done; stats.marketGold += gold }
        return outcome
    }

    private func sellSurplusFood() -> Outcome {
        guard game.isMarketOpen else { return .blocked("The Harbor Market is closed.") }
        let lot = game.surplusFood
        guard lot > 0, let price = game.marketPrice(of: .food, lot: lot, buying: false) else {
            return .blocked("No surplus food: the market keeps ten days of rations, and never less than 1,000.")
        }
        let outcome = run(paying: [.food: lot], receiving: [.gold: price]) {
            game.trade(.food, lot: lot, buying: false)
        } succeeded: {
            game.surplusFood < lot
        }
        if outcome.ok { stats.trades += 1; stats.marketGold += price }
        return outcome
    }

    // MARK: - Troops

    private func move(_ name: String, all: Bool, sending: Bool) -> Outcome {
        guard game.transferDestinations.isEmpty == false else {
            return .blocked("The Troops button only appears once you hold a second island.")
        }
        guard let town = town(named: name) else { return unknownTown(name) }
        guard game.transferDestinations.contains(where: { $0.id == town.id }) else {
            return .blocked("\(town.name) isn't one of your other islands.")
        }
        let source = sending ? game.activeTown : town
        let destination = sending ? town : game.activeTown
        guard source.armyStrength > 0 else { return .blocked("\(source.name) has no troops to move.") }
        return conservingArmy {
            game.moveTroops(from: source.id, to: destination.id, fraction: all ? 1 : 0.5)
        } moved: {
            (game.state.town(id: destination.id)?.armyStrength ?? 0) - destination.armyStrength
        }
    }

    private func pullAll() -> Outcome {
        guard game.transferDestinations.contains(where: { $0.armyStrength > 0 }) else {
            return .blocked("None of your other islands has troops to pull.")
        }
        let before = game.activeArmyStrength
        return conservingArmy { game.pullAllTroops() } moved: { game.activeArmyStrength - before }
    }

    private func conservingArmy(_ action: () -> Void, moved: () -> Int) -> Outcome {
        let empire = game.empireArmyStrength
        game.feedback = nil
        action()
        let power = moved()
        var outcome = Outcome(ok: power > 0, message: game.feedback?.text ?? "")
        outcome.details = [("movedPower", .int(power))]
        if game.empireArmyStrength != empire {
            outcome.violations.append("Moving troops changed the empire's army from \(empire) to \(game.empireArmyStrength).")
        }
        return outcome
    }

    // MARK: - War

    private func attack(_ name: String, plan: BattlePlan, rally: Bool) -> Outcome {
        guard let target = town(named: name) else { return unknownTown(name) }
        guard target.isPlayerControlled == false else { return .blocked("\(target.name) is already yours.") }
        if rally {
            guard game.canRallyAndAttack(target.id) else { return .blocked("None of your other islands has troops to rally.") }
            game.rallyAndAttack(target.id)
        } else {
            guard game.canAttack(target.id) else { return .blocked("\(game.activeTown.name) has no army to send.") }
            game.prepareAssault(target.id)
        }
        guard let briefing = game.battleBriefing else { return Outcome(ok: false, message: "No battle briefing opened.") }
        let source = game.activeTown
        game.confirmAssault()
        guard let landed = game.assault else { return Outcome(ok: false, message: "The army never landed.") }
        let fought = plan.fight(landed)
        let empireBefore = game.empireArmyStrength
        game.feedback = nil
        game.finishAssault(fought)
        let report = game.battleReport
        game.dismissBattleReport()

        let captured = fought.outcome == .captured
        var outcome = Outcome(ok: true, message: report.map { "\($0.title) at \(target.name)." } ?? "The battle ended.")
        if game.phase == .victory { outcome.message += " Duskara has fallen: the campaign is won." }
        outcome.details = battleDetails(briefing.power, briefing.defense, landed, fought, plan)
        if let report, captured {
            outcome.details.append(("plunder", .amounts(report.plunder, GameRules.sharedKinds)))
        }

        // Whoever survived either holds the new island or sailed home.
        let survivors = fought.survivors(.attacker).armyStrength(using: game.balance.soldierDefinitions)
        let expected = empireBefore - (source.armyStrength - survivors)
        if game.empireArmyStrength != expected {
            outcome.violations.append("After the battle the empire's army is \(game.empireArmyStrength); \(survivors) power survived it, so it should be \(expected).")
        }
        stats.battle(fought.outcome, day: game.state.day, lost: source.armyStrength - survivors)
        return outcome
    }

    private func scout(_ name: String, plan: BattlePlan) -> Outcome {
        guard let target = town(named: name) else { return unknownTown(name) }
        guard target.isPlayerControlled == false else { return .blocked("\(target.name) is already yours.") }
        guard let battle = GameRules.assault(target.id, from: game.state.activeTownID, in: game.state, balance: game.balance) else {
            return .blocked("\(game.activeTown.name) has no army to send.")
        }
        let fought = plan.fight(battle)
        var outcome = Outcome(ok: true, message: "Dry run against \(target.name): nothing changed.")
        outcome.details = battleDetails(game.activeArmyStrength, game.effectiveDefenseStrength(for: target), battle, fought, plan)
        return outcome
    }

    private func battleDetails(_ power: Int, _ defense: Int, _ landed: LaneBattle, _ fought: LaneBattle, _ plan: BattlePlan) -> [(String, JSON)] {
        let result: String = switch fought.outcome {
        case .captured: "captured"
        case .repelled: "repelled"
        case .withdrew: "withdrew"
        case nil: "unfinished"
        }
        return [
            ("outcome", .string(result)),
            ("plan", .string(plan.name)),
            ("seconds", .double(fought.elapsed)),
            ("odds", .string(BattleBriefing.odds(power: power, defense: defense))),
            ("power", .int(power)),
            ("defense", .int(defense)),
            ("gate", .string("\(Int(max(0, fought.gateHealth).rounded(.up))) of \(Int(landed.gateMaxHealth))")),
            ("attackers", .units(landed.survivors(.attacker))),
            ("attackersLeft", .units(fought.survivors(.attacker))),
            ("defenders", .units(landed.survivors(.defender))),
            ("defendersLeft", .units(fought.survivors(.defender))),
        ]
    }

    // MARK: - Time

    private func endDays(_ count: Int) -> Outcome {
        let start = GameRules.empireStock(game.state)
        let firstDay = game.state.day
        var events: [JSON] = []
        var violations: [String] = []
        for _ in 0..<count where isPlaying {
            let day = endDay()
            violations += day.violations
            if let json = day.json { events.append(json) }
        }
        let end = GameRules.empireStock(game.state)
        var outcome = Outcome(ok: true, message: "Day \(game.state.day).")
        if game.phase == .defeat { outcome.message += " Your last island has fallen: the campaign is lost." }
        outcome.details = [
            ("daysPassed", .int(game.state.day - firstDay)),
            ("stockChange", .wallet(Dictionary(uniqueKeysWithValues: GameRules.sharedKinds.map { ($0, end[$0] - start[$0]) }))),
            ("events", .array(events)),
        ]
        outcome.violations = violations
        return outcome
    }

    private struct DayReport {
        var day: Int
        var news: [String] = []
        var message: String?
        var hungry = false
        var armyChange = 0
        var lost: [String] = []
        var violations: [String] = []

        var json: JSON? {
            guard news.isEmpty == false || hungry || armyChange != 0 || lost.isEmpty == false || violations.isEmpty == false else {
                return nil
            }
            var fields: [(String, JSON)] = [("day", .int(day))]
            if let message { fields.append(("message", .string(message))) }
            if hungry { fields.append(("hunger", .string("Not enough food for the army: unfed soldiers left."))) }
            if armyChange != 0 { fields.append(("armyChange", .int(armyChange))) }
            if lost.isEmpty == false { fields.append(("islandsLost", .strings(lost))) }
            if news.isEmpty == false { fields.append(("news", .strings(news))) }
            return .object(fields)
        }
    }

    /// One press of the app's Next button, checked against the day's ledger:
    /// income in, the army's food out.
    private func endDay() -> DayReport {
        let balance = game.balance
        let held = game.playerTowns
        let income = held.reduce(into: [ResourceKind: Int]()) { total, town in
            for (kind, amount) in GameRules.income(town, balance: balance) { total[kind, default: 0] += amount }
        }
        let upkeep = held.reduce(0) { $0 + GameRules.dailyFood($1, balance: balance) }
        let before = GameRules.empireStock(game.state)
        let army = Dictionary(uniqueKeysWithValues: held.map { ($0.id, $0.armyStrength) })

        game.feedback = nil
        game.advanceDayManually()

        var report = DayReport(day: game.state.day)
        if let feedback = game.feedback, feedback.text.hasPrefix("Day ") == false {
            report.message = feedback.detail.map { "\(feedback.text) \($0)" } ?? feedback.text
        }
        report.news = takeNews().map(\.message)
        report.hungry = before[.food] + income[.food, default: 0] < upkeep
        let kept = held.filter { game.state.town(id: $0.id)?.isPlayerControlled == true }
        report.lost = held.filter { town in kept.contains { $0.id == town.id } == false }.map(\.name)
        report.armyChange = kept.reduce(0) { $0 + (game.state.town(id: $1.id)?.armyStrength ?? 0) - (army[$1.id] ?? 0) }
        if report.hungry { stats.hungerLosses += max(0, -report.armyChange) }
        stats.islandsLost += report.lost.count

        guard report.lost.isEmpty else { return report }
        let after = GameRules.empireStock(game.state)
        for kind in [ResourceKind.gold, .skill] where after[kind] - before[kind] != income[kind, default: 0] {
            report.violations.append("Day \(report.day): \(kind.rawValue) changed by \(after[kind] - before[kind]), but the islands produce \(income[kind, default: 0]).")
        }
        let fedFood = income[.food, default: 0] - upkeep
        if report.hungry == false, after[.food] - before[.food] != fedFood {
            report.violations.append("Day \(report.day): food changed by \(after[.food] - before[.food]); production minus the army's rations is \(fedFood).")
        }
        return report
    }

    // MARK: - Helpers

    /// Runs one app action and checks the shared stockpile moved by exactly
    /// the price the app showed for it.
    private func run(
        paying cost: [ResourceKind: Int],
        receiving gain: [ResourceKind: Int] = [:],
        _ action: () -> Void,
        succeeded: () -> Bool
    ) -> Outcome {
        let before = GameRules.empireStock(game.state)
        game.feedback = nil
        action()
        var outcome = Outcome(ok: succeeded(), message: game.feedback?.text ?? "")
        guard outcome.ok else { return outcome }
        let after = GameRules.empireStock(game.state)
        for kind in GameRules.sharedKinds {
            let expected = gain[kind, default: 0] - cost[kind, default: 0]
            let actual = after[kind] - before[kind]
            if actual != expected {
                outcome.violations.append("Ledger: \(outcome.message) moved \(kind.rawValue) by \(actual), but its price was \(expected).")
            }
        }
        return outcome
    }

    private func building(at plot: GridCoordinate) -> BuildingInstance? {
        game.activeTown.buildings.first { $0.coordinate == plot }
    }

    private func unknownTown(_ name: String) -> Outcome {
        Outcome(ok: false, message: "No town called \"\(name)\". Towns: \(game.state.towns.map(\.name).joined(separator: ", ")).")
    }
}
