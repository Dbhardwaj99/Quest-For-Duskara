import SwiftUI

struct GameView: View {
    @Bindable var viewModel: GameViewModel
    var onNewCampaign: () -> Void = {}
    @State private var isNewsPresented = false
    @State private var isCameraOrbiting = false
    /// Debug building sizes. Held here (not read straight off `BuildingScale`)
    /// so a slider edit invalidates this view and reaches the 3D scene.
    @State private var buildingScales: [BuildingKind: Float] = [:]
    /// World contrast. Held here for the same reason as `buildingScales`: the
    /// change has to be visible to SwiftUI to reach the 3D scene.
    @State private var contrast = WorldContrast.level
    @State private var isContrastPanelPresented = false
    #if DEBUG
    @State private var isBuildingSizePanelPresented = false
    #endif

    var body: some View {
        Group {
            switch viewModel.phase {
            case .setup:
                StartSetupView(viewModel: viewModel)
            case .town:
                // The world map replaces the town entirely — no popup, and
                // the 3D scene is not rendered behind it.
                if viewModel.isWorldMapPresented {
                    WorldMapView(viewModel: viewModel)
                        .transition(.opacity)
                } else {
                    townBody
                        .transition(.opacity)
                }
            case .victory:
                VictoryView(day: viewModel.state.day)
            case .defeat:
                DefeatView(day: viewModel.state.day, onNewCampaign: onNewCampaign)
            }
        }
        .animation(.smooth(duration: 0.25), value: viewModel.isWorldMapPresented)
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
                GameFeedbackToastView(message: feedback.text)
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
            TopHUDView(
                town: viewModel.activeTown,
                day: viewModel.state.day,
                progress: viewModel.dayProgress,
                income: viewModel.activeTownIncome,
                armyStrength: viewModel.activeArmyStrength,
                freePeople: viewModel.freePeople,
                capacity: viewModel.populationCapacity
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
        BottomBarView(
            onBuild: { viewModel.isBuildMenuPresented = true },
            onWorld: { viewModel.isWorldMapPresented = true },
            onNextDay: viewModel.advanceDayManually
        )
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

#Preview {
    GameView(viewModel: GameViewModel())
}
