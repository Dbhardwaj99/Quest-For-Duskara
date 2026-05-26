import SwiftUI

struct GameView3D: View {
    @Bindable var viewModel: GameViewModel
    @State private var isTownViewExpanded = false

    var body: some View {
        Group {
            switch viewModel.phase {
            case .setup:
                StartSetupView(viewModel: viewModel)
            case .town:
                townBody
            }
        }
    }

    private var townBody: some View {
        ZStack(alignment: .top) {
            DuskaraTheme.worldBackdrop.ignoresSafeArea()
            mainTownLayout
                .opacity(isTownViewExpanded ? 0 : 1)
                .allowsHitTesting(isTownViewExpanded == false)

            if isTownViewExpanded {
                expandedTownViewLayout
                    .transition(.opacity.combined(with: .scale(scale: 0.985)))
                    .zIndex(5)
            }

            if let feedback = viewModel.feedback {
                Game3DFeedbackToastView(message: feedback.text)
                    .padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .animation(.snappy, value: viewModel.feedback?.id)
        .animation(.smooth(duration: 0.34), value: isTownViewExpanded)
        .sheet(isPresented: $viewModel.isBuildMenuPresented) {
            BuildMenuView(viewModel: viewModel)
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $viewModel.buildingPresentation) { presentation in
            BuildingDetailsSheetView(viewModel: viewModel, buildingID: presentation.id)
                .presentationDetents([.medium, .large])
        }
        .fullScreenCover(isPresented: $viewModel.isWorldMapPresented) {
            WorldMapView(viewModel: viewModel)
        }
    }

    private var mainTownLayout: some View {
        ZStack(alignment: .top) {
            townView3D
                .ignoresSafeArea()

            worldVignette
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                topHUD
                    .padding(.top, 8)
                Spacer(minLength: 12)
                InspectorPanelView(viewModel: viewModel)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 8)
                bottomBar
                    .padding(.bottom, 8)
            }
        }
    }

    private var expandedTownViewLayout: some View {
        ZStack(alignment: .top) {
            townView3D
                .ignoresSafeArea()

            worldVignette
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                topHUD
                    .padding(.top, 8)
                Spacer()
                bottomBar
                    .padding(.bottom, 10)
            }
        }
        .background(DuskaraTheme.worldBackdrop.ignoresSafeArea())
    }

    private var topHUD: some View {
        TopHUDView(
            town: viewModel.activeTown,
            day: viewModel.state.day,
            progress: viewModel.dayProgress,
            income: viewModel.activeTownIncome,
            armyStrength: viewModel.activeArmyStrength,
            freePeople: viewModel.freePeople,
            capacity: viewModel.populationCapacity
        )
    }

    private var townView3D: some View {
        World3DTownView(sourceViewModel: viewModel)
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
                .accessibilityLabel(isTownViewExpanded ? "Collapse 3D town view" : "Expand 3D town view")
                .padding(.top, 78)
                .padding(.trailing, 14)
            }
    }

    private var worldVignette: some View {
        ZStack {
            LinearGradient(
                colors: [.black.opacity(0.30), .clear, .black.opacity(0.24)],
                startPoint: .top,
                endPoint: .bottom
            )
            RadialGradient(
                colors: [.clear, .black.opacity(0.24)],
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

    private func toggleTownViewExpansion() {
        withAnimation(.smooth(duration: 0.34)) {
            isTownViewExpanded.toggle()
        }
    }
}

private struct Game3DFeedbackToastView: View {
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

#Preview {
    GameView3D(viewModel: GameViewModel())
}
