import SwiftUI

struct MultiplayerMenuView: View {
    @Bindable var viewModel: RoomLobbyViewModel
    let onJoinedRoom: () -> Void

    var body: some View {
        VStack(spacing: DuskaraTheme.spacingL) {
            Text("Multiplayer")
                .font(DuskaraTheme.Fonts.hero)
                .foregroundStyle(.white)
            Text("Build one realm together. Room codes invite players; they never grant access by themselves.")
                .foregroundStyle(.white.opacity(0.75))

            VStack(spacing: DuskaraTheme.spacingM) {
                TextField("Display name", text: $viewModel.displayName)
                Button("Create Private Room", action: run(viewModel.createPrivateRoom))
                    .buttonStyle(DuskaraButtonStyle(prominent: true))

                HStack {
                    TextField("ROOM CODE", text: $viewModel.inviteCode)
                        .textFieldStyle(.roundedBorder)
                    Button("Join", action: run(viewModel.joinPrivateRoom))
                }

                Button("Public Matchmaking", action: run(viewModel.joinMatchmaking))
                if viewModel.canRejoin {
                    Button("Rejoin Last Room", action: run(viewModel.rejoinLastRoom))
                }
            }
            .frame(width: 380)
            .padding(DuskaraTheme.spacingL)
            .background(DuskaraTheme.panel, in: RoundedRectangle(cornerRadius: DuskaraTheme.cornerS))

            status
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DuskaraTheme.background.ignoresSafeArea())
        .task { await viewModel.open() }
        .onChange(of: viewModel.session?.roomID) { _, roomID in if roomID != nil { onJoinedRoom() } }
        .alert("Multiplayer", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) { Button("OK") { viewModel.errorMessage = nil } } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    @ViewBuilder private var status: some View {
        switch viewModel.screenState {
        case .loading: ProgressView("Contacting Duskara…").foregroundStyle(.white)
        case .matchmaking:
            VStack {
                ProgressView("Looking for another player…")
                Button("Cancel", action: run(viewModel.cancelMatchmaking))
            }.foregroundStyle(.white)
        case .offline: Label("Offline — cached room information may be stale.", systemImage: "wifi.slash").foregroundStyle(.orange)
        case .idle where !viewModel.canRejoin: Text("No previous room is saved on this Mac.").foregroundStyle(.secondary)
        default: EmptyView()
        }
    }

    private func run(_ operation: @escaping () async -> Void) -> () -> Void { { Task { await operation() } } }
}
