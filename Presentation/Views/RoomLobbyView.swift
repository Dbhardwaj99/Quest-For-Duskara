import SwiftUI

struct RoomLobbyView: View {
    @Bindable var viewModel: RoomLobbyViewModel
    let onCampaignReady: () -> Void
    let onLeave: () -> Void

    var body: some View {
        VStack(spacing: DuskaraTheme.spacingL) {
            Text("Cooperative Lobby").font(DuskaraTheme.Fonts.hero).foregroundStyle(.white)
            if let room = viewModel.session {
                if let code = room.inviteCode {
                    Text(code).font(.system(size: 34, weight: .bold, design: .monospaced)).textSelection(.enabled)
                    Text("Share this code with your teammate.").foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(room.participants) { participant in
                        HStack {
                            Image(systemName: viewModel.onlineParticipantIDs.contains(participant.id) ? "circle.fill" : "circle")
                                .foregroundStyle(viewModel.onlineParticipantIDs.contains(participant.id) ? .green : .secondary)
                            Text(participant.displayName)
                            if participant.role == .owner { Text("Owner").font(.caption).foregroundStyle(.secondary) }
                            Spacer()
                            Image(systemName: viewModel.readyParticipantIDs.contains(participant.id) ? "checkmark.circle.fill" : "circle")
                        }
                    }
                }
                .frame(width: 420)
                .padding()
                .background(DuskaraTheme.panel, in: RoundedRectangle(cornerRadius: DuskaraTheme.cornerS))

                HStack {
                    Button(viewModel.localIsReady ? "Not Ready" : "Ready", action: run(viewModel.toggleReady))
                    if viewModel.isOwner {
                        Button("Start Campaign", action: run(viewModel.startRoom))
                            .buttonStyle(DuskaraButtonStyle(prominent: true))
                    }
                    Button("Leave", role: .destructive) { Task { await viewModel.leaveRoom(); onLeave() } }
                }
                if room.status == .active { Button("Join Campaign", action: onCampaignReady).buttonStyle(DuskaraButtonStyle(prominent: true)) }
            } else {
                ContentUnavailableView("Room unavailable", systemImage: "person.2.slash")
            }
            if viewModel.isStale { Label("Showing stale cached lobby data", systemImage: "clock.badge.exclamationmark").foregroundStyle(.orange) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DuskaraTheme.background.ignoresSafeArea())
        .onChange(of: viewModel.session?.status) { _, status in if status == .active { onCampaignReady() } }
    }

    private func run(_ operation: @escaping () async -> Void) -> () -> Void { { Task { await operation() } } }
}
