import SwiftUI

struct GameView: View {
    @Bindable var viewModel: GameViewModel

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
            VStack(spacing: 10) {
                TopHUDView(
                    town: viewModel.activeTown,
                    day: viewModel.state.day,
                    progress: viewModel.dayProgress,
                    income: viewModel.activeTownIncome,
                    armyStrength: viewModel.activeArmyStrength,
                    freePeople: viewModel.freePeople,
                    capacity: viewModel.populationCapacity
                )
                TownGridView(
                    town: viewModel.activeTown,
                    gridSize: viewModel.balance.gridSize,
                    selectedCoordinate: viewModel.selectedCoordinate,
                    selectedBuildingID: viewModel.selectedBuildingID,
                    placementBuildingKind: viewModel.placementBuildingKind,
                    tilePlacementState: viewModel.tilePlacementState,
                    onSelect: viewModel.selectCell
                )
                .frame(maxWidth: .infinity)
                .frame(height: 500)
                .padding(.horizontal, 8)

                InspectorPanelView(viewModel: viewModel)
                    .frame(minHeight: 84)

                BottomBarView(
                    onBuild: { viewModel.isBuildMenuPresented = true },
                    onWorld: { viewModel.isWorldMapPresented = true },
                    onNextDay: viewModel.advanceDayManually
                )
            }

            if let feedback = viewModel.feedback {
                FeedbackToastView(message: feedback.text)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .animation(.snappy, value: viewModel.feedback?.id)
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
