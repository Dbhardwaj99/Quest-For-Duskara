import SwiftUI

struct GameView: View {
    @Bindable var viewModel: GameViewModel
    @State private var isTownGridExpanded = false

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
                .opacity(isTownGridExpanded ? 0 : 1)
                .allowsHitTesting(isTownGridExpanded == false)

            if isTownGridExpanded {
                expandedTownGridLayout
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(5)
            }

            if let feedback = viewModel.feedback {
                FeedbackToastView(message: feedback.text)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .animation(.snappy, value: viewModel.feedback?.id)
        .animation(.snappy(duration: 0.32), value: isTownGridExpanded)
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
            townGrid
                .frame(maxWidth: .infinity)
                .frame(height: 500)
                .padding(.horizontal, 8)

            InspectorPanelView(viewModel: viewModel)
                .frame(minHeight: 84)

            bottomBar
        }
    }

    private var expandedTownGridLayout: some View {
        ZStack(alignment: .bottom) {
            DuskaraTheme.background.ignoresSafeArea()
            VStack(spacing: 10) {
                topHUD
                townGrid
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

    private var townGrid: some View {
        TownGridView(
            town: viewModel.activeTown,
            gridSize: viewModel.balance.gridSize,
            selectedCoordinate: viewModel.selectedCoordinate,
            selectedBuildingID: viewModel.selectedBuildingID,
            placementBuildingKind: viewModel.placementBuildingKind,
            tilePlacementState: viewModel.tilePlacementState,
            onSelect: viewModel.selectCell
        )
        .overlay(alignment: .topTrailing) {
            Button(action: toggleTownGridExpansion) {
                Image(systemName: isTownGridExpanded ? "xmark" : "arrow.up.left.and.arrow.down.right")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                    .background(.black.opacity(0.62), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isTownGridExpanded ? "Collapse town grid" : "Expand town grid")
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

    private func toggleTownGridExpansion() {
        withAnimation(.snappy(duration: 0.32)) {
            isTownGridExpanded.toggle()
        }
    }
}

private struct FeedbackToastView: View {
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
    GameView(viewModel: GameViewModel())
}
