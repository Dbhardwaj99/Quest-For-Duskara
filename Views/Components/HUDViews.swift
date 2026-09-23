import SwiftUI

struct TopHUDView: View {
    let town: Town
    let day: Int
    let progress: Double
    let income: [ResourceKind: Int]
    let armyStrength: Int
    let freePeople: Int
    let capacity: Int
    /// Every island the player holds; more than one turns the name into a switcher.
    var islands: [Town] = []
    var onSelectIsland: (UUID) -> Void = { _ in }
    var secondsUntilRaid: Int?

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    islandName
                    HStack(spacing: 12) {
                        HUDMetric(systemImage: "sun.max.fill", value: "Day \(day)")
                        HUDMetric(systemImage: "shield.fill", value: "\(armyStrength)")
                        HUDMetric(systemImage: "person.2.fill", value: "\(freePeople)/\(capacity)")
                        if let secondsUntilRaid {
                            HUDMetric(systemImage: "flame.fill", value: "\(secondsUntilRaid)s")
                                .help("Enemy islands build, train and attack in \(secondsUntilRaid) seconds")
                        }
                    }
                }
                Spacer(minLength: 10)
                dayDial
            }

            ProgressView(value: progress)
                .tint(DuskaraTheme.warmGold)
                .scaleEffect(x: 1, y: 0.72)
                .animation(dayAnimation, value: progress)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(ResourceKind.allCases) { kind in
                        ResourcePill(kind: kind, amount: town.resources[kind], income: income[kind], tick: day)
                    }
                }
                .padding(.vertical, 1)
            }
            // The day's gains float up out of the pills.
            .scrollClipDisabled()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(DuskaraTheme.hudGlassFill, in: UnevenRoundedRectangle(cornerRadii: .init(topLeading: 18, bottomLeading: 14, bottomTrailing: 18, topTrailing: 14)))
        .overlay(
            UnevenRoundedRectangle(cornerRadii: .init(topLeading: 18, bottomLeading: 14, bottomTrailing: 18, topTrailing: 14))
                .stroke(DuskaraTheme.glassStroke, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.28), radius: 18, x: 0, y: 10)
    }

    @ViewBuilder
    private var islandName: some View {
        let title = Text(town.name)
            .font(DuskaraTheme.Fonts.heading)
            .foregroundStyle(.white.opacity(0.96))
        if islands.count > 1 {
            Menu {
                ForEach(islands) { island in
                    Button(island.name) { onSelectIsland(island.id) }
                        .disabled(island.id == town.id)
                }
            } label: {
                title
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Switch island")
            .accessibilityLabel("Switch island, now \(town.name)")
        } else {
            title
        }
    }

    /// Ticks land once a second, so a ten-second day would step round in
    /// tenths; ease across each second instead, and snap back at dawn.
    private var dayAnimation: Animation? { progress < 0.1 ? nil : .linear(duration: 1) }

    private var dayDial: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.16), lineWidth: 4)
            Circle()
                .trim(from: 0, to: min(1, max(0, progress)))
                .stroke(DuskaraTheme.warmGold, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: "sun.max.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(DuskaraTheme.warmGold)
        }
        .frame(width: 34, height: 34)
        .animation(dayAnimation, value: progress)
    }
}
// Icon stays small and dim; the number carries the weight.
private struct HUDMetric: View {
    let systemImage: String
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.60))
            Text(value)
                .font(DuskaraTheme.Fonts.number)
                .foregroundStyle(.white.opacity(0.94))
                .contentTransition(.numericText())
        }
    }
}

struct BottomBarView: View {
    @Bindable var viewModel: GameViewModel

    // Compact floating panel: the buttons hug their labels instead of
    // stretching across the window.
    var body: some View {
        HStack(spacing: 8) {
            Button { viewModel.openBuildMenu() } label: {
                Label("Build", systemImage: "hammer.fill")
            }
            .buttonStyle(DuskaraButtonStyle())

            // Hidden until a second island is held: there is nowhere to move
            // troops before then.
            if viewModel.transferDestinations.isEmpty == false {
                Button { viewModel.isTroopsPresented = true } label: {
                    Label("Troops", systemImage: "shield.lefthalf.filled")
                }
                .buttonStyle(DuskaraButtonStyle())
                .accessibilityLabel("Move troops between islands")
                .popover(isPresented: $viewModel.isTroopsPresented, arrowEdge: .top) {
                    TroopsView(viewModel: viewModel)
                }
            }

            if viewModel.isMarketOpen {
                Button { viewModel.isMarketPresented = true } label: {
                    Label("Trade", systemImage: "sailboat.fill")
                }
                .buttonStyle(DuskaraButtonStyle())
                .accessibilityLabel("Open the Harbor Market")
                .popover(isPresented: $viewModel.isMarketPresented, arrowEdge: .top) {
                    MarketView(viewModel: viewModel)
                        .padding(DuskaraTheme.spacingL)
                        .frame(width: 400)
                        .background(DuskaraTheme.sheetBackground)
                        .environment(\.colorScheme, .dark)
                }
            }

            Button(action: viewModel.advanceDayManually) {
                Label("Next", systemImage: "forward.end.fill")
            }
            .buttonStyle(DuskaraButtonStyle())

            Button { viewModel.isWorldMapPresented = true } label: {
                Label("World", systemImage: "map.fill")
            }
            .buttonStyle(DuskaraButtonStyle(prominent: true))
        }
        .fixedSize()
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(DuskaraTheme.hudFill, in: Capsule())
        .overlay(Capsule().stroke(DuskaraTheme.glassStroke, lineWidth: 1))
        .shadow(color: .black.opacity(0.28), radius: 18, y: 10)
    }
}
