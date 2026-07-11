import Foundation

/// Client view of authoritative server time. The client never uses its own
/// wall clock for gameplay decisions; it only renders progress derived from
/// server timestamps plus a measured offset.
struct ServerClock: Equatable {
    /// serverNow - localNow, in milliseconds. Zero until a sync happens
    /// (single-player runs entirely on the local clock).
    private(set) var offsetMillis: Int64 = 0

    mutating func synchronize(serverNowMillis: Int64, localNow: Date = Date()) {
        offsetMillis = serverNowMillis - Int64(localNow.timeIntervalSince1970 * 1000)
    }

    func nowMillis(localNow: Date = Date()) -> Int64 {
        Int64(localNow.timeIntervalSince1970 * 1000) + offsetMillis
    }

    /// Seconds of server time elapsed since a server timestamp, clamped to
    /// zero so a stale offset never yields negative progress.
    func secondsElapsed(since serverMillis: Int64, localNow: Date = Date()) -> TimeInterval {
        max(0, TimeInterval(nowMillis(localNow: localNow) - serverMillis) / 1000)
    }
}
