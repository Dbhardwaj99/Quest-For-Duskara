import Foundation

enum BuildingPresentation: Identifiable, Equatable {
    case details(UUID)

    var id: UUID {
        switch self {
        case .details(let id): id
        }
    }
}
