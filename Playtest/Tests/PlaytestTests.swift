import Foundation
import Testing
@testable import DuskaraPlaytest

struct PlaytestTests {
    @Test func sameSeedAndCommandsReplayTheSameCampaign() {
        let commands = ["build farm 0 0", "build house 2 0", "end-day 4", "build factory 0 1", "end-day 12"]
        let first = PlaytestSession(seed: 7, difficulty: .medium)
        let second = PlaytestSession(seed: 7, difficulty: .medium)
        for command in commands {
            _ = first.perform(command)
            _ = second.perform(command)
        }
        #expect(first.snapshot(.full).rendered(pretty: false) == second.snapshot(.full).rendered(pretty: false))
        #expect(first.game.state.day == 17)
    }

    @Test func buildingChargesThePriceTheMenuShows() {
        let session = PlaytestSession(seed: 3, difficulty: .medium)
        let before = GameRules.empireStock(session.game.state)
        let outcome = session.apply("build farm 0 0")
        #expect(outcome.ok)
        #expect(outcome.violations.isEmpty)
        let after = GameRules.empireStock(session.game.state)
        #expect(before[.gold] - after[.gold] == 400)
        #expect(before[.skill] - after[.skill] == 200)
        #expect(session.game.activeTown.buildings.contains { $0.kind == .farm && $0.coordinate == GridCoordinate(x: 0, y: 0) })
    }

    @Test func actionsTheAppWouldNotOfferAreBlocked() {
        let session = PlaytestSession(seed: 3, difficulty: .medium)
        #expect(session.apply("build pier 0 0").blocked)
        #expect(session.apply("train archer").blocked)
        #expect(session.apply("pull-all").blocked)
        #expect(session.apply("upgrade 0 0").blocked)
        #expect(session.apply("dance").ok == false)
        #expect(session.log == ["build pier 0 0", "train archer", "pull-all", "upgrade 0 0"])
    }

    @Test func sessionFilesRoundTrip() throws {
        let session = PlaytestSession(seed: 11, difficulty: .hard)
        _ = session.perform("build farm 0 0; end-day 3")
        _ = session.perform("end-day 3")
        let data = try JSONEncoder().encode(session.file)
        let restored = PlaytestSession(file: try JSONDecoder().decode(SessionFile.self, from: data))
        #expect(restored.snapshot(.full).rendered(pretty: false) == session.snapshot(.full).rendered(pretty: false))
        #expect(restored.log == session.log)
    }

    @Test func scoutingChangesNothingAndAttackingSettlesTheBattle() {
        let session = PlaytestSession(seed: 42, difficulty: .easy)
        for command in ["build farm 0 0", "build house 2 0", "build house 0 1", "end-day 4", "upgrade 1 1",
                        "end-day 3", "build barracks 2 1", "end-day 2", "train archer 4"] {
            #expect(session.apply(command).ok, "\(command)")
        }
        let before = session.snapshot(.full).rendered(pretty: false)
        let scout = session.apply("scout green-hollow weakest")
        #expect(session.snapshot(.full).rendered(pretty: false) == before)
        let attack = session.apply("attack green-hollow weakest")
        #expect(attack.detail("outcome") == scout.detail("outcome"))
        #expect(attack.violations.isEmpty)
        #expect(session.game.state.towns.first { $0.name == "Green Hollow" }?.isPlayerControlled == (scout.detail("outcome") == "captured"))
    }

    @Test func battlePlansParse() throws {
        #expect(try BattlePlan.parse([]).name == "focus:1")
        #expect(try BattlePlan.parse(["order:knight@0,archer@2", "withdraw:30"]).name == "order:knight@0,archer@2 withdraw:30")
        #expect(throws: PlaytestCommand.ParseError.self) { try BattlePlan.parse(["focus:3"]) }
    }

    @Test(arguments: Strategy.allCases)
    func botsPlayWithoutBreakingARule(_ strategy: Strategy) async {
        for seed in 1...3 {
            let (result, _) = await Simulation.play(seed: seed, difficulty: .medium, strategy: strategy, maxDays: 150)
            let violations = result.stats.issues.filter { $0.severity == "violation" }.map(\.message)
            #expect(violations.isEmpty, "\(strategy.rawValue) seed \(seed): \(violations)")
        }
    }
}
