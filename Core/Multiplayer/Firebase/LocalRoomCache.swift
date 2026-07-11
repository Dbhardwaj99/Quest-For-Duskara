import Foundation

struct CachedRoomState: Codable, Equatable {
    var roomID: String
    var checkpoint: MatchState?
    var lastAppliedRevision: Int
    var pendingActions: [GameAction]
}

final class LocalRoomCache {
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "QuestForDuskara/multiplayer-room.json")
    }

    func load() -> CachedRoomState? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(CachedRoomState.self, from: data)
    }

    func save(_ value: CachedRoomState) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(value).write(to: fileURL, options: .atomic)
    }

    func update(roomID: String, checkpoint: MatchState? = nil, pending: [GameAction]? = nil) throws {
        let current = load()
        let state = checkpoint ?? current?.checkpoint
        try save(CachedRoomState(
            roomID: roomID,
            checkpoint: state,
            lastAppliedRevision: state?.revision ?? current?.lastAppliedRevision ?? 0,
            pendingActions: pending ?? current?.pendingActions ?? []
        ))
    }

    func clear() { try? FileManager.default.removeItem(at: fileURL) }
}
