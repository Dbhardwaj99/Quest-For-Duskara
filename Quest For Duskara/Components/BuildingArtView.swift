import SwiftUI

struct BuildingArtView: View {
    let building: BuildingInstance

    var body: some View {
        ZStack {
            base
            roof
            details
            VStack {
                Spacer()
                HStack(spacing: 1) {
                    ForEach(0..<building.level, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 7))
                            .foregroundStyle(.yellow)
                    }
                }
                .padding(.bottom, 2)
            }
        }
        .padding(4)
    }

    private var base: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(building.kind.color.gradient)
            .frame(width: 28 + CGFloat(building.level * 3), height: 24 + CGFloat(building.level * 3))
            .offset(y: 5)
            .shadow(color: .black.opacity(0.18), radius: 2, y: 2)
    }

    private var roof: some View {
        Triangle()
            .fill(Color(red: 0.38, green: 0.17, blue: 0.12))
            .frame(width: 36 + CGFloat(building.level * 4), height: 18 + CGFloat(building.level * 2))
            .offset(y: -8)
    }

    @ViewBuilder
    private var details: some View {
        switch building.kind {
        case .house:
            HStack(spacing: 5) {
                window
                if building.level > 1 { window }
                if building.level > 2 { window }
            }
            .offset(y: 6)
        case .farm:
            VStack(spacing: 2) {
                Image(systemName: "leaf.fill").font(.caption2)
                Rectangle().fill(.yellow.opacity(0.7)).frame(width: 28, height: 3)
            }
            .foregroundStyle(.white.opacity(0.9))
            .offset(y: 4)
        case .woodMill:
            Image(systemName: "fanblades.fill")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.85))
                .rotationEffect(.degrees(Double(building.level) * 12))
        case .coalMine:
            Image(systemName: "mountain.2.fill")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.86))
                .offset(y: 4)
        case .lab:
            Image(systemName: "sparkles")
                .font(.title3)
                .foregroundStyle(.white)
                .offset(y: 3)
        case .barracks:
            Image(systemName: "shield.lefthalf.filled")
                .font(.title3)
                .foregroundStyle(.white)
                .offset(y: 4)
        }
    }

    private var window: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(Color.yellow.opacity(0.82))
            .frame(width: 5, height: 7)
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
