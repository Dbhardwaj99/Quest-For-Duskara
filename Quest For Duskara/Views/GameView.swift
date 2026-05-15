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
        .alert(item: $viewModel.message) { message in
            Alert(title: Text(message.text))
        }
    }

    private var townBody: some View {
        ZStack {
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
                    onSelect: viewModel.selectCell
                )
                .frame(maxWidth: .infinity)
                .frame(height: 470)
                .padding(.horizontal, 8)

                InspectorPanelView(viewModel: viewModel)
                    .frame(minHeight: 140)

                BottomBarView(
                    onBuild: { viewModel.isBuildMenuPresented = true },
                    onWorld: { viewModel.isWorldMapPresented = true },
                    onNextDay: viewModel.advanceDayManually
                )
            }
        }
        .sheet(isPresented: $viewModel.isBuildMenuPresented) {
            BuildMenuView(viewModel: viewModel)
                .presentationDetents([.medium, .large])
        }
        .fullScreenCover(isPresented: $viewModel.isWorldMapPresented) {
            WorldMapView(viewModel: viewModel)
        }
    }
}

#Preview {
    GameView(viewModel: GameViewModel())
}
