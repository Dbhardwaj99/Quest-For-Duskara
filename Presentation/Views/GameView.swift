import SwiftUI

struct GameView: View {
    @Bindable var viewModel: GameViewModel
    @State private var isNewsPresented = false

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

            townControls
                .zIndex(2)

            if isNewsPresented {
                NewsFeedPanel(events: viewModel.state.newsEvents, onClose: { isNewsPresented = false })
                    .frame(maxWidth: DuskaraTheme.maxTopHUDWidth)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 74)
                    .padding(.horizontal, 14)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(8)
            }

            if let feedback = viewModel.feedback {
                GameFeedbackToastView(message: feedback.text)
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .animation(.snappy, value: viewModel.feedback?.id)
        .animation(.snappy, value: isNewsPresented)
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

    private var townView3D: some View {
        World3DTownView(sourceViewModel: viewModel)
            .id(viewModel.activeTownID)
            .background(DuskaraTheme.worldBackdrop)
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

private struct VictoryView: View {
    let day: Int

    var body: some View {
        VStack(spacing: 12) {
            Text("Victory")
                .font(DuskaraTheme.Fonts.title)
                .foregroundStyle(.white)
            Text("Duskara fell on Day \(day).")
                .font(DuskaraTheme.Fonts.heading)
                .foregroundStyle(.white.opacity(0.82))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DuskaraTheme.background.ignoresSafeArea())
    }
}

private struct GameFeedbackToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(DuskaraTheme.Fonts.subheading)
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(DuskaraTheme.hudFill, in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.20), lineWidth: 1))
            .shadow(color: .black.opacity(0.26), radius: 14, y: 7)
            .padding(.horizontal, 18)
    }
}

private struct NewsFeedPanel: View {
    let events: [NewsEvent]
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("World News")
                    .font(DuskaraTheme.Fonts.heading)
                    .foregroundStyle(DuskaraTheme.ink)
                Spacer()
                Button("Close", action: onClose)
                    .font(DuskaraTheme.Fonts.caption)
                    .foregroundStyle(DuskaraTheme.warmGold)
                    .buttonStyle(.plain)
            }
            if events.isEmpty {
                Text("No world events yet.")
                    .font(DuskaraTheme.Fonts.body)
                    .foregroundStyle(DuskaraTheme.mutedInk)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(events) { event in
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Day \(event.day)")
                                    .font(DuskaraTheme.Fonts.caption)
                                    .foregroundStyle(DuskaraTheme.mutedInk)
                                Text(event.message)
                                    .font(DuskaraTheme.Fonts.body)
                                    .foregroundStyle(DuskaraTheme.ink)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .frame(maxHeight: 260)
            }
        }
        .padding(14)
        .background(DuskaraTheme.hudFill, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.20), lineWidth: 1))
        .shadow(color: .black.opacity(0.24), radius: 18, y: 8)
    }
}

#Preview {
    GameView(viewModel: GameViewModel())
}
