import Foundation

struct FeedbackOverlaySystem {
    func text(for failure: BuildingSystem.BuildFailure, building: BuildingKind? = nil) -> String {
        switch failure {
        case .placementRule:
            return failure.rawValue
        default:
            return failure.rawValue
        }
    }
}
