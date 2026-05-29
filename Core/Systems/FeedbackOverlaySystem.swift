import Foundation

struct FeedbackOverlaySystem {
    func text(for failure: BuildingSystem.BuildFailure, building: BuildingKind? = nil) -> String {
        switch failure {
        case .placementRule:
            if building == .woodMill { return "Wood Mills must be placed beside forest terrain." }
            if building == .coalMine { return "Coal Mines must be placed beside mountain terrain." }
            return failure.rawValue
        default:
            return failure.rawValue
        }
    }
}
