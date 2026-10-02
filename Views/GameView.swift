import SwiftUI

struct GameView: View {
    @Bindable var viewModel: GameViewModel
    var onNewCampaign: () -> Void = {}
    @State private var isNewsPresented = false
    @State private var isCameraOrbiting = false
    @State private var worldTravelProgress = 0.0
    @State private var isWorldTraveling = false
    @State private var worldTravelID = UUID()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Debug building sizes. Held here (not read straight off `BuildingScale`)
    /// so a slider edit invalidates this view and reaches the 3D scene.
    @State private var buildingScales: [BuildingKind: Float] = [:]
    /// World contrast. Held here for the same reason as `buildingScales`: the
    /// change has to be visible to SwiftUI to reach the 3D scene.
    @State private var contrast = WorldContrast.level
    @State private var isContrastPanelPresented = false
    @AppStorage(GameSound.mutedKey) private var isSoundMuted = false
    #if DEBUG
    @State private var isBuildingSizePanelPresented = false
    #endif

    var body: some View {
        ZStack {
            Group {
            switch viewModel.phase {
            case .setup:
                StartSetupView(viewModel: viewModel)
            case .town:
                ZStack {
                    townBody
                        .allowsHitTesting(viewModel.isWorldMapPresented == false && isWorldTraveling == false && !viewModel.isBattlePresented)
                        .accessibilityHidden(viewModel.isWorldMapPresented || isWorldTraveling || viewModel.isBattlePresented)
                    WorldMapView(
                        viewModel: viewModel,
                        theme: ThemeManager.shared.theme,
                        contrast: contrast,
                        travelProgress: worldTravelProgress,
                        travelDuration: reduceMotion ? 0 : 1.8
                    )
                    .modifier(WorldTravelOpacity(progress: worldTravelProgress, start: reduceMotion ? 0 : 0.36, end: reduceMotion ? 1 : 0.64))
                    .allowsHitTesting(viewModel.isWorldMapPresented && isWorldTraveling == false && !viewModel.isBattlePresented)
                    .accessibilityHidden(viewModel.isWorldMapPresented == false || isWorldTraveling || viewModel.isBattlePresented)
                    if reduceMotion == false {
                        WorldTravelClouds(progress: worldTravelProgress)
                            .ignoresSafeArea()
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
            case .victory:
                VictoryView(day: viewModel.state.day, islands: viewModel.playerTowns.count, onNewCampaign: onNewCampaign)
            case .defeat:
                DefeatView(day: viewModel.state.day, onNewCampaign: onNewCampaign)
            }
            }
            .disabled(viewModel.isBattlePresented)
            .accessibilityHidden(viewModel.isBattlePresented)
            if let assault = viewModel.assault {
                LaneBattleView(
                    battle: assault,
                    attackerName: viewModel.state.town(id: assault.sourceID)?.name ?? "",
                    targetTown: viewModel.state.town(id: assault.targetID) ?? viewModel.activeTown,
                    onFinish: viewModel.finishAssault
                )
                .transition(.opacity)
            }
            if let briefing = viewModel.battleBriefing {
                BattleBriefingView(briefing: briefing, onAttack: viewModel.confirmAssault, onCancel: viewModel.cancelAssault)
            }
            if let report = viewModel.battleReport {
                BattleReportView(report: report, onContinue: viewModel.dismissBattleReport)
            }
        }
        .animation(reduceMotion ? nil : .smooth(duration: 0.25), value: viewModel.isBattlePresented)
        .onChange(of: viewModel.isWorldMapPresented, initial: true) { _, presented in
            guard worldTravelProgress != (presented ? 1 : 0) else { return }
            if presented {
                isCameraOrbiting = false
                isNewsPresented = false
                isContrastPanelPresented = false
            }
            let travelID = UUID()
            worldTravelID = travelID
            isWorldTraveling = true
            withAnimation(.timingCurve(1.0 / 3, 0, 2.0 / 3, 1, duration: reduceMotion ? 0.22 : 1.8)) {
                worldTravelProgress = presented ? 1 : 0
            } completion: {
                if worldTravelID == travelID { isWorldTraveling = false }
            }
        }
    }

    private var townBody: some View {
        ZStack(alignment: .top) {
            DuskaraTheme.worldBackdrop.ignoresSafeArea()

            townView3D
                .ignoresSafeArea()
                .zIndex(0)

            worldVignette
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .zIndex(1)

            // Orbit is a look-at-the-world mode, so the whole interface gets out
            // of the way. The orbit button goes with it, which would strand the
            // player — so while it runs, a click anywhere is the way out.
            // ponytail: an invisible catcher rather than per-control hiding; it
            // also parks the camera drag gesture, which orbit is driving anyway.
            if isCameraOrbiting {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { isCameraOrbiting = false }
                    .ignoresSafeArea()
                    .zIndex(2)
                    .accessibilityLabel("Stop camera orbit")
            } else {
                townControls
                    .modifier(WorldTravelOpacity(progress: worldTravelProgress, start: 0, end: 0.22, reversed: true))
                    .zIndex(2)
            }

            if isNewsPresented, isCameraOrbiting == false {
                NewsFeedPanel(events: viewModel.state.newsEvents, onClose: { isNewsPresented = false })
                    .frame(maxWidth: DuskaraTheme.maxTopHUDWidth)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 74)
                    .padding(.horizontal, 14)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(8)
            }

            if let feedback = viewModel.feedback, isCameraOrbiting == false {
                GameFeedbackToastView(message: feedback)
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .animation(.snappy, value: viewModel.feedback?.id)
        .animation(.snappy, value: isNewsPresented)
        .animation(.smooth(duration: 0.3), value: isCameraOrbiting)
        // Esc as well as the click, since that is what a full-bleed mode trains
        // you to reach for. It needs key focus, so the click stays the guarantee.
        .onExitCommand { isCameraOrbiting = false }
        .background(DuskaraTheme.worldBackdrop.ignoresSafeArea())
        .sheet(isPresented: $viewModel.isBuildMenuPresented) {
            // macOS sheets ignore presentation detents, so size them explicitly.
            BuildMenuView(viewModel: viewModel)
                .frame(minWidth: 430, idealWidth: 460, maxWidth: 520, minHeight: 520, idealHeight: 640)
        }
        .sheet(item: $viewModel.buildingPresentation) { presentation in
            BuildingDetailsSheetView(viewModel: viewModel, buildingID: presentation.id)
                .frame(minWidth: 430, idealWidth: 460, maxWidth: 520, minHeight: 480, idealHeight: 620)
        }
    }

    private var townControls: some View {
        ZStack {
            topHUD
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            placementCancelButton
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 10)
            bottomBar
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 14)
                .padding(.bottom, 12)
        }
    }

    // The HUD docks in the top-left corner instead of stretching across the
    // whole window.
    private var topHUD: some View {
        HStack(alignment: .top, spacing: DuskaraTheme.spacingS) {
            // Gold, food and skill show the empire's shared stock; people and
            // soldiers are the active island's own.
            TopHUDView(
                town: viewModel.spendingTown,
                day: viewModel.state.day,
                progress: viewModel.dayProgress,
                progressSampledAt: viewModel.lastTick,
                progressPerSecond: 1 / viewModel.balance.dayDuration,
                income: viewModel.empireIncome,
                armyStrength: viewModel.activeArmyStrength,
                freePeople: viewModel.freePeople,
                capacity: viewModel.populationCapacity,
                islands: viewModel.playerTowns,
                onSelectIsland: viewModel.switchToTown,
                secondsUntilRaid: viewModel.secondsUntilRaid
            )
            .frame(maxWidth: DuskaraTheme.maxTopHUDWidth)
            Button {
                isNewsPresented.toggle()
            } label: {
                Image(systemName: "newspaper.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white.opacity(0.94))
                    .frame(width: 38, height: 38)
                    .background(DuskaraTheme.hudFill, in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.20), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("World news")

            Button {
                isSoundMuted.toggle()
            } label: {
                Image(systemName: isSoundMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.94))
                    .frame(width: 38, height: 38)
                    .background(DuskaraTheme.hudFill, in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.20), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isSoundMuted ? "Turn sound on" : "Mute sound")

            themeCycleButton
            contrastButton

            #if DEBUG
            debugOrbitButton
            debugBuildingSizeButton
            #endif
        }
        .padding(.leading, DuskaraTheme.spacingM)
        .padding(.top, 10)
    }

    private var themeCycleButton: some View {
        Button {
            ThemeManager.shared.cycle()
        } label: {
            VStack(spacing: 1) {
                Image(systemName: "paintpalette.fill")
                    .font(.system(size: 13, weight: .bold))
                Text(ThemeManager.shared.theme.displayName)
                    .font(DuskaraTheme.Fonts.label)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(.white.opacity(0.94))
            .frame(width: 44, height: 38)
            .background(DuskaraTheme.hudFill, in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.20), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Cycle world theme")
    }

    private var contrastButton: some View {
        Button {
            isContrastPanelPresented.toggle()
        } label: {
            Image(systemName: "circle.righthalf.filled")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white.opacity(0.94))
                .frame(width: 38, height: 38)
                .background(DuskaraTheme.hudFill, in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.20), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Adjust world contrast")
        .popover(isPresented: $isContrastPanelPresented, arrowEdge: .bottom) {
            contrastPanel
        }
    }

    private var contrastPanel: some View {
        VStack(alignment: .leading, spacing: DuskaraTheme.spacingM) {
            HStack {
                Text("Contrast")
                    .font(DuskaraTheme.Fonts.heading)
                Spacer()
                Text(String(format: "%.2f", contrast))
                    .font(DuskaraTheme.Fonts.numberSmall)
                    .foregroundStyle(DuskaraTheme.warmGold)
            }

            // Stepped, not continuous: every distinct value rebuilds the board
            // and mints a material per color, so a free drag would thrash both.
            Slider(
                value: Binding(get: { contrast }, set: setContrast),
                in: WorldContrast.range,
                step: WorldContrast.step
            )

            HStack {
                Text("Flat")
                Spacer()
                Text("Vivid")
            }
            .font(DuskaraTheme.Fonts.label)
            .foregroundStyle(DuskaraTheme.mutedInk)

            Button("Reset") { setContrast(WorldContrast.standard) }
                .font(DuskaraTheme.Fonts.caption)
        }
        .foregroundStyle(DuskaraTheme.ink)
        .padding(DuskaraTheme.spacingL)
        .frame(width: 250)
    }

    private func setContrast(_ newValue: Double) {
        contrast = newValue
        WorldContrast.level = newValue
    }

    #if DEBUG
    private var debugOrbitButton: some View {
        Button {
            isCameraOrbiting.toggle()
        } label: {
            VStack(spacing: 1) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 13, weight: .bold))
                Text("Orbit")
                    .font(DuskaraTheme.Fonts.label)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(.white.opacity(isCameraOrbiting ? 1 : 0.94))
            .frame(width: 44, height: 38)
            .background(isCameraOrbiting ? DuskaraTheme.warmGold.opacity(0.4) : DuskaraTheme.hudFill, in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.20), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isCameraOrbiting ? "Stop camera orbit" : "Start camera orbit")
    }

    private var debugBuildingSizeButton: some View {
        Button {
            isBuildingSizePanelPresented.toggle()
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white.opacity(0.94))
                .frame(width: 38, height: 38)
                .background(DuskaraTheme.hudFill, in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.20), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Adjust building sizes")
        .popover(isPresented: $isBuildingSizePanelPresented, arrowEdge: .bottom) {
            BuildingSizeDebugPanel(scales: $buildingScales)
        }
    }
    #endif

    private var townView3D: some View {
        World3DTownView(
            sourceViewModel: viewModel,
            isActive: !viewModel.isBattlePresented && (reduceMotion == false || viewModel.isWorldMapPresented == false || isWorldTraveling),
            isInputEnabled: isWorldTraveling == false && viewModel.isWorldMapPresented == false && !viewModel.isBattlePresented,
            worldMapProgress: reduceMotion ? 0 : worldTravelProgress,
            travelDuration: reduceMotion ? 0 : 1.8,
            startsAboveTown: reduceMotion == false && isWorldTraveling && worldTravelProgress == 0,
            isCameraOrbiting: isCameraOrbiting,
            buildingScales: buildingScales,
            contrast: contrast
        )
        .id(viewModel.state.activeTownID)
    }

    private var worldVignette: some View {
        ZStack {
            LinearGradient(
                colors: [.black.opacity(0.18), .clear, .black.opacity(0.16)],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [.clear, Color(red: 0.08, green: 0.10, blue: 0.14).opacity(0.18)],
                center: .center,
                startRadius: 120,
                endRadius: 620
            )
        }
    }

    private var bottomBar: some View {
        BottomBarView(viewModel: viewModel)
    }

    @ViewBuilder
    private var placementCancelButton: some View {
        if let kind = viewModel.placementBuildingKind {
            Button(action: viewModel.cancelPlacement) {
                Label("Cancel \(kind.title)", systemImage: "xmark.circle.fill")
                    .font(DuskaraTheme.Fonts.subheading)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(DuskaraTheme.hudFill, in: Capsule())
                    .overlay(Capsule().stroke(DuskaraTheme.glassStroke, lineWidth: 1))
                    .shadow(color: .black.opacity(0.28), radius: 14, y: 7)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .accessibilityLabel("Cancel building placement")
        }
    }
}

/// Interpolate only the compositing layer. Native scene updates receive a
/// target once and animate their cameras on the existing display link.
private struct WorldTravelOpacity: AnimatableModifier {
    var progress: Double
    let start: Double
    let end: Double
    var reversed = false

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let opacity = worldTravelEase(progress, from: start, to: end)
        content.opacity(reversed ? 1 - opacity : opacity)
    }
}

private func worldTravelEase(_ progress: Double, from start: Double, to end: Double) -> Double {
    let t = min(1, max(0, (progress - start) / (end - start)))
    return t * t * (3 - 2 * t)
}

/// Sculpted cloud banks pass at two depths; gaps keep the sea visible during
/// the handoff, with a soft blue underside instead of an opaque white wipe.
private struct WorldTravelClouds: View, Animatable {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        Canvas { context, size in
            let appear = worldTravelEase(progress, from: 0.10, to: 0.35)
            let disappear = 1 - worldTravelEase(progress, from: 0.66, to: 0.94)
            guard appear * disappear > 0.001 else { return }
            context.opacity = appear * disappear
            for layer in 0..<2 {
                let depth = Double(layer)
                let scale = 0.65 + progress * (1.05 + depth * 0.6)
                for index in 0..<9 {
                    let column = index % 3
                    let row = index / 3
                    let x = (Double(column) - 1) * 0.48 + (layer == 0 ? -0.08 : 0.09)
                    let y = (Double(row) - 1) * 0.48 + (layer == 0 ? 0.08 : -0.10)
                    let center = CGPoint(
                        x: size.width * (0.5 + x * scale),
                        y: size.height * (0.5 + y * scale + (progress - 0.5) * (0.20 + depth * 0.14))
                    )
                    let width = size.width * (0.33 + depth * 0.09) * scale
                    let height = size.height * (0.27 + depth * 0.06) * scale
                    var cloud = Path()
                    for puff in 0..<5 {
                        let t = Double(puff) / 4
                        let puffHeight = height * (puff == 2 ? 1 : 0.70)
                        cloud.addEllipse(in: CGRect(
                            x: center.x + (t - 0.5) * width * 0.72 - width * 0.22,
                            y: center.y - puffHeight * 0.5 + (puff.isMultiple(of: 2) ? -height * 0.07 : height * 0.10),
                            width: width * 0.48,
                            height: puffHeight
                        ))
                    }
                    var bank = context
                    bank.opacity *= layer == 0 ? 0.90 : 0.98
                    bank.fill(cloud, with: .linearGradient(
                        Gradient(colors: [Color(red: 1, green: 0.99, blue: 0.94), Color(red: 0.83, green: 0.91, blue: 0.93)]),
                        startPoint: CGPoint(x: center.x, y: center.y - height * 0.5),
                        endPoint: CGPoint(x: center.x, y: center.y + height * 0.5)
                    ))
                }
            }
        }
    }
}

#Preview {
    GameView(viewModel: GameViewModel())
}
