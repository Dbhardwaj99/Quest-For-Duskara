import Foundation

struct TimeSystem {
    func shouldAdvanceDay(elapsedSeconds: TimeInterval, balance: GameBalance) -> Bool {
        elapsedSeconds >= balance.dayDuration
    }

    func progress(elapsedSeconds: TimeInterval, balance: GameBalance) -> Double {
        guard balance.dayDuration > 0 else { return 0 }
        return min(1, elapsedSeconds / balance.dayDuration)
    }
}
