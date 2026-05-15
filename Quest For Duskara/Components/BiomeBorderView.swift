import SwiftUI

struct BiomeBorderView: View {
    let layout: TownBiomeLayout

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                border(for: .top, in: proxy.size)
                border(for: .right, in: proxy.size)
                border(for: .bottom, in: proxy.size)
                border(for: .left, in: proxy.size)
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func border(for side: BiomeSide, in size: CGSize) -> some View {
        if let biome = layout.biome(on: side) {
            switch side {
            case .top:
                strip(biome: biome, horizontal: true)
                    .frame(width: size.width, height: 38)
                    .position(x: size.width / 2, y: 19)
            case .right:
                strip(biome: biome, horizontal: false)
                    .frame(width: 38, height: size.height)
                    .position(x: size.width - 19, y: size.height / 2)
            case .bottom:
                strip(biome: biome, horizontal: true)
                    .frame(width: size.width, height: 38)
                    .position(x: size.width / 2, y: size.height - 19)
            case .left:
                strip(biome: biome, horizontal: false)
                    .frame(width: 38, height: size.height)
                    .position(x: 19, y: size.height / 2)
            }
        }
    }

    private func strip(biome: BiomeKind, horizontal: Bool) -> some View {
        ZStack {
            Rectangle().fill(color(for: biome).opacity(0.45))
            if horizontal {
                HStack(spacing: 8) { icons(for: biome) }
            } else {
                VStack(spacing: 8) { icons(for: biome) }
            }
        }
    }

    private func icons(for biome: BiomeKind) -> some View {
        ForEach(0..<8, id: \.self) { index in
            icon(for: biome, index: index)
        }
    }

    @ViewBuilder
    private func icon(for biome: BiomeKind, index: Int) -> some View {
        switch biome {
        case .forest:
            Triangle()
                .fill(Color.green.opacity(index.isMultiple(of: 2) ? 0.85 : 0.65))
                .frame(width: 18, height: 24)
        case .mountain:
            Triangle()
                .fill(Color.gray.opacity(index.isMultiple(of: 2) ? 0.90 : 0.68))
                .frame(width: 24, height: 24)
        case .plains:
            Capsule()
                .fill(Color.yellow.opacity(0.45))
                .frame(width: 20, height: 6)
        case .river:
            Capsule()
                .fill(Color.cyan.opacity(0.7))
                .frame(width: 22, height: 7)
        }
    }

    private func color(for biome: BiomeKind) -> Color {
        switch biome {
        case .forest: Color(red: 0.14, green: 0.38, blue: 0.20)
        case .mountain: Color(red: 0.34, green: 0.33, blue: 0.33)
        case .plains: Color(red: 0.59, green: 0.55, blue: 0.28)
        case .river: Color(red: 0.18, green: 0.44, blue: 0.58)
        }
    }
}
