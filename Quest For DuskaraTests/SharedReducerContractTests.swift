import Foundation
import Testing

@MainActor
@Suite("Shared reducer contract")
struct SharedReducerContractTests {
    private struct Fixture: Decodable {
        struct Expected: Decodable { var revision: Int; var gold: Int; var skill: Int; var updatedTownCount: Int }
        var action: GameAction
        var expected: Expected
    }

    @Test func swiftReducerMatchesSharedFixture() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appending(path: "SharedFixtures/reducer-contract.json")
        let fixture = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
        let dispatcher = LocalCommandDispatcher()
        var state = TestFixtures.state(towns: [TestFixtures.town(1, resources: [.gold: 100, .skill: 100, .food: 0, .people: 10])])
        let result = dispatcher.dispatch(fixture.action, state: &state, balance: .duskDefault, nowMillis: 1000)
        #expect(result.revision == fixture.expected.revision)
        #expect(state.towns[0].resources[.gold] == fixture.expected.gold)
        #expect(state.towns[0].resources[.skill] == fixture.expected.skill)
        #expect(result.patch?.updatedTowns.count == fixture.expected.updatedTownCount)
    }
}
