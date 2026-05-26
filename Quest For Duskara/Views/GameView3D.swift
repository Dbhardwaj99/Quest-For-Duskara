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
            DuskaraTheme.background.ignoresSafeArea()
            mainTownLayout
                .opacity(isTownViewExpanded ? 0 : 1)
                .allowsHitTesting(isTownViewExpanded == false)

            if isTownViewExpanded {
                expandedTownViewLayout
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(5)
            }

            if let feedback = viewModel.feedback {
                Game3DFeedbackToastView(message: feedback.text)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .animation(.snappy, value: viewModel.feedback?.id)
        .animation(.snappy(duration: 0.32), value: isTownViewExpanded)
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
        VStack(spacing: 10) {
            topHUD
            townView3D
                .frame(maxWidth: .infinity)
                .frame(height: 500)
                .padding(.horizontal, 8)

            InspectorPanelView(viewModel: viewModel)
                .frame(minHeight: 84)

            bottomBar
        }
    }

    private var expandedTownViewLayout: some View {
        ZStack(alignment: .bottom) {
            DuskaraTheme.background.ignoresSafeArea()
            VStack(spacing: 10) {
                topHUD
                townView3D
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 78)
            }
            bottomBar
                .padding(.horizontal, 8)
                .padding(.bottom, 10)
                .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 10)
        }
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
            .background(Color.black.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.28), lineWidth: 1))
            .overlay(alignment: .topTrailing) {
                Button(action: toggleTownViewExpansion) {
                    Image(systemName: isTownViewExpanded ? "xmark" : "arrow.up.left.and.arrow.down.right")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(.black.opacity(0.62), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isTownViewExpanded ? "Collapse 3D town view" : "Expand 3D town view")
                .padding(10)
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
        withAnimation(.snappy(duration: 0.32)) {
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
            .background(.black.opacity(0.76), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.16), lineWidth: 1))
            .padding(.horizontal, 18)
    }
}

#Preview {
    GameView3D(viewModel: GameViewModel())
}
