import SwiftUI

struct BiomeBorderView: View {
    let layout: TownBiomeLayout
    var borderDepth: CGFloat = 86

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let biome = layout.biome(on: .top) {
                    BiomeTerrainStrip(biome: biome, side: .top)
                        .frame(width: proxy.size.width, height: borderDepth)
                        .position(x: proxy.size.width / 2, y: borderDepth / 2)
                }
                if let biome = layout.biome(on: .right) {
                    BiomeTerrainStrip(biome: biome, side: .right)
                        .frame(width: borderDepth, height: proxy.size.height)
                        .position(x: proxy.size.width - borderDepth / 2, y: proxy.size.height / 2)
                }
                if let biome = layout.biome(on: .bottom) {
                    BiomeTerrainStrip(biome: biome, side: .bottom)
                        .frame(width: proxy.size.width, height: borderDepth)
                        .position(x: proxy.size.width / 2, y: proxy.size.height - borderDepth / 2)
                }
                if let biome = layout.biome(on: .left) {
                    BiomeTerrainStrip(biome: biome, side: .left)
                        .frame(width: borderDepth, height: proxy.size.height)
                        .position(x: borderDepth / 2, y: proxy.size.height / 2)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

struct BiomeTerrainStrip: View {
    let biome: BiomeKind
    let side: BiomeSide

    var body: some View {
        ZStack {
            Rectangle().fill(backgroundColor)
            terrainLayer(offset: -16, opacity: 0.55, scale: 0.86)
            terrainLayer(offset: 6, opacity: 0.82, scale: 1.0)
            terrainLayer(offset: 25, opacity: 0.35, scale: 1.16)
        }
        .clipped()
    }

    private var isHorizontal: Bool {
        side == .top || side == .bottom
    }

    private var backgroundColor: Color {
        switch biome {
        case .forest:
            Color(red: 0.07, green: 0.22, blue: 0.12).opacity(0.86)
        case .mountain:
            Color(red: 0.18, green: 0.18, blue: 0.19).opacity(0.9)
        case .plains:
            Color(red: 0.42, green: 0.43, blue: 0.20).opacity(0.74)
        case .river:
            Color(red: 0.11, green: 0.34, blue: 0.46).opacity(0.74)
        }
    }

    private func terrainLayer(offset: CGFloat, opacity: Double, scale: CGFloat) -> some View {
        Group {
            if isHorizontal {
                HStack(spacing: 7) {
                    ForEach(0..<18, id: \.self) { index in
                        terrainShape(index: index, scale: scale)
                    }
                }
                .offset(y: side == .top ? offset : -offset)
            } else {
                VStack(spacing: 7) {
                    ForEach(0..<18, id: \.self) { index in
                        terrainShape(index: index, scale: scale)
                    }
                }
                .offset(x: side == .left ? offset : -offset)
            }
        }
        .opacity(opacity)
    }

    @ViewBuilder
    private func terrainShape(index: Int, scale: CGFloat) -> some View {
        switch biome {
        case .forest:
            LayeredTree(index: index)
                .frame(width: 24 * scale, height: 34 * scale)
        case .mountain:
            LayeredMountain(index: index)
                .frame(width: 34 * scale, height: 32 * scale)
        case .plains:
            Capsule()
                .fill(Color.yellow.opacity(index.isMultiple(of: 2) ? 0.38 : 0.24))
                .frame(width: 28 * scale, height: 7 * scale)
        case .river:
            Capsule()
                .fill(Color.cyan.opacity(index.isMultiple(of: 2) ? 0.48 : 0.28))
                .frame(width: 32 * scale, height: 8 * scale)
        }
    }
}

private struct LayeredTree: View {
    let index: Int

    var body: some View {
        VStack(spacing: -5) {
            Triangle()
                .fill(Color(red: 0.10, green: 0.39, blue: 0.17).opacity(index.isMultiple(of: 2) ? 0.95 : 0.72))
            Triangle()
                .fill(Color(red: 0.07, green: 0.30, blue: 0.13).opacity(0.95))
        }
    }
}

private struct LayeredMountain: View {
    let index: Int

    var body: some View {
        ZStack(alignment: .bottom) {
            Triangle()
                .fill(Color(red: 0.38, green: 0.38, blue: 0.39).opacity(index.isMultiple(of: 2) ? 0.9 : 0.66))
            Triangle()
                .fill(Color(red: 0.21, green: 0.21, blue: 0.23).opacity(0.92))
                .scaleEffect(0.72, anchor: .bottom)
                .offset(x: 8)
        }
    }
}
