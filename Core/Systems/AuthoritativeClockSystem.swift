import Foundation

/// Bridges ServerClock and the day cycle: the client renders progress and
/// decides when to request a day advance purely from the replicated
/// dayStartServerMillis, never from a locally accumulated counter.
struct AuthoritativeClockSystem {
    var clock = ServerClock()
    private let timeSystem = TimeSystem()

    func elapsedSeconds(in state: GameState, localNow: Date = Date()) -> TimeInterval {
        guard state.dayStartServerMillis > 0 else { return 0 }
        return clock.secondsElapsed(since: state.dayStartServerMillis, localNow: localNow)
    }

    func progress(in state: GameState, balance: GameBalance, localNow: Date = Date()) -> Double {
        timeSystem.progress(elapsedSeconds: elapsedSeconds(in: state, localNow: localNow), balance: balance)
    }

    func secondsRemainingInDay(in state: GameState, balance: GameBalance, localNow: Date = Date()) -> Int {
        guard state.dayStartServerMillis > 0 else { return 0 }
        return max(0, Int((balance.dayDuration - elapsedSeconds(in: state, localNow: localNow)).rounded(.up)))
    }

    /// True when at least one full day has elapsed; callers dispatch
    /// advance-day actions repeatedly until this turns false, which also
    /// catches up cleanly after suspension.
    func shouldAdvanceDay(in state: GameState, balance: GameBalance, localNow: Date = Date()) -> Bool {
        state.dayStartServerMillis > 0
            && timeSystem.shouldAdvanceDay(elapsedSeconds: elapsedSeconds(in: state, localNow: localNow), balance: balance)
    }
}
