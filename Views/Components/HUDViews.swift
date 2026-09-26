import SwiftUI

struct TopHUDView: View {
    let town: Town
    let day: Int
    let progress: Double
    /// When `progress` was sampled and how much of a day passes per second, so
    /// the dial and bar can glide on between the once-a-second ticks.
    var progressSampledAt = Date.distantPast
    var progressPerSecond = 0.0
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

            // The native bar only holds its exact spot in the layout; the
            // gliding fill is drawn by DayClockLayer on top of it.
            ProgressView(value: 0)
                .hidden()
                .overlay {
                    DayClockLayer(style: .bar, progress: progress, sampledAt: progressSampledAt, perSecond: progressPerSecond)
                        .accessibilityLabel("Day progress")
                        .accessibilityValue(Text(progress, format: .percent.precision(.fractionLength(0))))
                }

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

    private var dayDial: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.16), lineWidth: 4)
            DayClockLayer(style: .ring, progress: progress, sampledAt: progressSampledAt, perSecond: progressPerSecond)
            Image(systemName: "sun.max.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(DuskaraTheme.warmGold)
        }
        .frame(width: 34, height: 34)
    }
}

/// The day clock's moving fill, animated by Core Animation. Ticks land once a
/// second, so on each one the render server glides the fill to where the
/// next tick will land — no stepping in tenths, and no SwiftUI redraws in
/// between (any SwiftUI animation or timeline here re-rendered the whole
/// window's view graph every frame, at the display's full 120 Hz).
private struct DayClockLayer: NSViewRepresentable {
    enum Style { case ring, bar }

    let style: Style
    let progress: Double
    let sampledAt: Date
    let perSecond: Double

    func makeNSView(context: Context) -> DayClockLayerView {
        DayClockLayerView(style: style)
    }

    func updateNSView(_ view: DayClockLayerView, context: Context) {
        view.show(progress: progress, sampledAt: sampledAt, perSecond: perSecond)
    }
}

private final class DayClockLayerView: NSView {
    private let style: DayClockLayer.Style
    private let track = CAShapeLayer()
    private let fill = CAShapeLayer()
    private var shownSample: (progress: Double, sampledAt: Date)?

    init(style: DayClockLayer.Style) {
        self.style = style
        super.init(frame: .zero)
        wantsLayer = true
        for shape in [track, fill] {
            shape.fillColor = nil
            shape.lineCap = .round
            layer?.addSublayer(shape)
        }
        fill.strokeEnd = 0
        fill.strokeColor = NSColor(DuskaraTheme.warmGold).cgColor
        switch style {
        case .ring:
            // Same stroke as the SwiftUI arc it replaces.
            fill.lineWidth = 4
            track.isHidden = true
        case .bar:
            // Matched to the native tinted bar it stands in for: its
            // 0.72-scaled thickness and its faint track.
            fill.lineWidth = 5.6
            track.lineWidth = 5.6
            track.strokeColor = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.075)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        let path = CGMutablePath()
        switch style {
        case .ring:
            // From twelve o'clock, clockwise (this layer's y points up).
            let radius = min(bounds.width, bounds.height) / 2
            path.addArc(center: CGPoint(x: bounds.midX, y: bounds.midY), radius: radius,
                        startAngle: .pi / 2, endAngle: .pi / 2 - 2 * .pi, clockwise: true)
        case .bar:
            let inset = fill.lineWidth / 2
            path.move(to: CGPoint(x: inset, y: bounds.midY))
            path.addLine(to: CGPoint(x: max(inset, bounds.width - inset), y: bounds.midY))
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for shape in [track, fill] {
            shape.frame = bounds
            shape.path = path
        }
        CATransaction.commit()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        let scale = window?.backingScaleFactor ?? 2
        track.contentsScale = scale
        fill.contentsScale = scale
    }

    func show(progress: Double, sampledAt: Date, perSecond: Double) {
        // SwiftUI updates for all sorts of reasons; only a new tick restarts the glide.
        guard shownSample?.progress != progress || shownSample?.sampledAt != sampledAt else { return }
        shownSample = (progress, sampledAt)

        let elapsed = min(1, max(0, Date().timeIntervalSince(sampledAt)))
        let from = min(1, max(0, progress + elapsed * perSecond))
        let to = min(1, max(0, progress + perSecond))
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        fill.strokeEnd = to
        CATransaction.commit()
        fill.removeAnimation(forKey: "glide")
        guard to > from else { return }

        let glide = CABasicAnimation(keyPath: "strokeEnd")
        glide.fromValue = from
        glide.toValue = to
        glide.duration = 1 - elapsed
        glide.timingFunction = CAMediaTimingFunction(name: .linear)
        glide.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        fill.add(glide, forKey: "glide")
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
