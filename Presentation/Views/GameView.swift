import SwiftUI

struct GameView: View {
    @Bindable var viewModel: GameViewModel
    @State private var isTownViewExpanded = false
    @State private var isNewsPresented = false

    var body: some View {
        Group {
            switch viewModel.phase {
            case .setup:
                StartSetupView(viewModel: viewModel)
            case .town:
                townBody
            case .victory:
                VictoryView(day: viewModel.state.day)
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

            townControls
                .zIndex(2)

            if isNewsPresented {
                NewsFeedPanel(events: viewModel.state.newsEvents, onClose: { isNewsPresented = false })
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
        .animation(.smooth(duration: 0.34), value: isTownViewExpanded)
        .animation(.snappy, value: isNewsPresented)
        .background(DuskaraTheme.worldBackdrop.ignoresSafeArea())
        .sheet(isPresented: $viewModel.isBuildMenuPresented) {
            BuildMenuView(viewModel: viewModel)
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $viewModel.buildingPresentation) { presentation in
            BuildingDetailsSheetView(viewModel: viewModel, buildingID: presentation.id)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $viewModel.isWorldMapPresented) {
            WorldMapView(viewModel: viewModel)
        }
    }

    private var townControls: some View {
        VStack(spacing: 0) {
            topHUD
                .padding(.top, 8)
            Spacer(minLength: isTownViewExpanded ? 0 : 12)
            placementCancelButton
                .padding(.bottom, 8)
            bottomBar
                .padding(.bottom, isTownViewExpanded ? 10 : 8)
        }
    }

    private var topHUD: some View {
        HStack(alignment: .top, spacing: 8) {
            TopHUDView(
                town: viewModel.activeTown,
                day: viewModel.state.day,
                progress: viewModel.dayProgress,
                income: viewModel.activeTownIncome,
                armyStrength: viewModel.activeArmyStrength,
                freePeople: viewModel.freePeople,
                capacity: viewModel.populationCapacity
            )
            Button {
                isNewsPresented.toggle()
            } label: {
                Image(systemName: "newspaper.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white.opacity(0.94))
                    .frame(width: 38, height: 38)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.20), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("World news")

            themeCycleButton
        }
        .padding(.horizontal, 8)
    }

    // ponytail: temporary theme-cycling test button; remove once theme selection has a real home
    private var themeCycleButton: some View {
        Button {
            ThemeManager.shared.cycle()
        } label: {
            VStack(spacing: 1) {
                Image(systemName: "paintpalette.fill")
                    .font(.system(size: 13, weight: .bold))
                Text(ThemeManager.shared.theme.displayName)
                    .font(.system(size: 7, weight: .heavy))
            }
            .foregroundStyle(.white.opacity(0.94))
            .frame(width: 44, height: 38)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.20), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Cycle world theme")
    }

    private var townView3D: some View {
        World3DTownView(sourceViewModel: viewModel)
            .id(viewModel.state.activeTownID)
            .background(DuskaraTheme.worldBackdrop)
            .overlay(alignment: .topTrailing) {
                Button(action: toggleTownViewExpansion) {
                    Image(systemName: isTownViewExpanded ? "xmark" : "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white.opacity(0.94))
                        .frame(width: 38, height: 38)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.20), lineWidth: 1))
                        .shadow(color: .black.opacity(0.28), radius: 12, y: 6)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isTownViewExpanded ? "Collapse town view" : "Expand town view")
                .padding(.top, 78)
                .padding(.trailing, 14)
            }
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
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().stroke(DuskaraTheme.glassStroke, lineWidth: 1))
                    .shadow(color: .black.opacity(0.28), radius: 14, y: 7)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .accessibilityLabel("Cancel building placement")
        }
    }

    private func toggleTownViewExpansion() {
        withAnimation(.smooth(duration: 0.34)) {
            isTownViewExpanded.toggle()
        }
    }
}

private struct VictoryView: View {
    let day: Int

    var body: some View {
        VStack(spacing: 12) {
            Text("Victory")
                .font(.largeTitle.weight(.black))
                .foregroundStyle(.white)
            Text("Duskara fell on Day \(day).")
                .font(.headline.weight(.semibold))
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
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
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
                    .font(.headline.weight(.heavy))
                Spacer()
                Button("Close", action: onClose)
                    .font(.caption.weight(.bold))
            }
            if events.isEmpty {
                Text("No world events yet.")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(events) { event in
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Day \(event.day)")
                                    .font(.caption.weight(.heavy))
                                    .foregroundStyle(.secondary)
                                Text(event.message)
                                    .font(.subheadline.weight(.semibold))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .frame(maxHeight: 260)
            }
        }
        .padding(14)
        .background(DuskaraTheme.panel, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.20), lineWidth: 1))
        .shadow(color: .black.opacity(0.24), radius: 18, y: 8)
    }
}

#Preview {
    GameView(viewModel: GameViewModel())
}
