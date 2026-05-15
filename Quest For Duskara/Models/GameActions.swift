import Foundation

struct TransferOrder: Identifiable, Equatable {
    var id = UUID()
    var fromTownID: UUID
    var toTownID: UUID
    var amounts: [ResourceKind: Int]
}
