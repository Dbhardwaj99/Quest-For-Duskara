import Foundation

extension GameState {
    mutating func updateTown(id: UUID, _ update: (inout Town) -> Void) {
        guard let index = towns.firstIndex(where: { $0.id == id }) else { return }
        update(&towns[index])
    }

    func town(id: UUID) -> Town? {
        towns.first { $0.id == id }
    }
}
