import SwiftUI

extension ResourceKind {
    var color: Color {
        switch self {
        case .gold: Color(red: 0.93, green: 0.67, blue: 0.22)
        case .wood: Color(red: 0.45, green: 0.27, blue: 0.13)
        case .coal: Color(red: 0.18, green: 0.19, blue: 0.21)
        case .tech: Color(red: 0.34, green: 0.54, blue: 0.82)
        case .food: Color(red: 0.45, green: 0.70, blue: 0.36)
        case .people: Color(red: 0.74, green: 0.47, blue: 0.33)
        case .soldiers: Color(red: 0.68, green: 0.18, blue: 0.18)
        }
    }
}

extension BuildingKind {
    var color: Color {
        switch self {
        case .house: Color(red: 0.75, green: 0.39, blue: 0.25)
        case .farm: Color(red: 0.55, green: 0.67, blue: 0.27)
        case .woodMill: Color(red: 0.42, green: 0.27, blue: 0.15)
        case .coalMine: Color(red: 0.25, green: 0.25, blue: 0.29)
        case .lab: Color(red: 0.34, green: 0.49, blue: 0.78)
        case .barracks: Color(red: 0.63, green: 0.22, blue: 0.20)
        }
    }
}
