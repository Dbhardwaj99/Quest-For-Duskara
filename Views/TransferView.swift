import SwiftUI

/// Move resources from the active town to another the player holds. Sending is
/// always *from* the active town — `GameViewModel.transfer` fixes the source —
/// so this only ever picks a destination, a resource, and an amount.
struct TransferView: View {
    @Bindable var viewModel: GameViewModel
    @State private var destinationID: UUID?
    @State private var kind: ResourceKind = .gold
    @State private var amount = 0

    private var available: Int { viewModel.availableToSend(kind) }
    private var canSend: Bool { destinationID != nil && amount > 0 && amount <= available }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DuskaraTheme.spacingL) {
                    Text("Sending from \(viewModel.activeTown.name).")
                        .font(DuskaraTheme.Fonts.subheading)
                        .foregroundStyle(DuskaraTheme.ink)

                    section("Destination") {
                        ForEach(viewModel.transferDestinations) { town in
                            destinationRow(town)
                        }
                    }

                    section("Resource") {
                        HStack(spacing: 6) {
                            ForEach(GameRules.transferableKinds) { resource in
                                resourceChip(resource)
                            }
                        }
                    }

                    section("Amount") {
                        if available > 0 {
                            HStack {
                                Text("\(amount)")
                                    .font(DuskaraTheme.Fonts.number)
                                    .foregroundStyle(DuskaraTheme.warmGold)
                                Text("of \(available)")
                                    .font(DuskaraTheme.Fonts.caption)
                                    .foregroundStyle(DuskaraTheme.mutedInk)
                                Spacer()
                                Button("All") { amount = available }
                                    .font(DuskaraTheme.Fonts.caption)
                            }
                            Slider(
                                value: Binding(
                                    get: { Double(amount) },
                                    set: { amount = Int($0.rounded()) }
                                ),
                                in: 0...Double(available),
                                step: 1
                            )
                        } else {
                            Text("\(viewModel.activeTown.name) has no \(kind.title.lowercased()) to send.")
                                .font(DuskaraTheme.Fonts.caption)
                                .foregroundStyle(DuskaraTheme.mutedInk)
                        }
                    }
                }
                .padding(DuskaraTheme.spacingL)
            }
            .background(DuskaraTheme.sheetBackground)
            .navigationTitle("Send Resources")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { viewModel.isTransferPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        if let destinationID {
                            viewModel.transfer(kind, amount: amount, to: destinationID)
                            viewModel.isTransferPresented = false
                        }
                    }
                    .disabled(canSend == false)
                }
            }
        }
        // A resource the town has less of must not carry the previous amount
        // through as an over-send the rules would then reject.
        .onChange(of: kind) { amount = min(amount, available) }
        .onAppear { destinationID = destinationID ?? viewModel.transferDestinations.first?.id }
    }

    private func section(
        _ title: String,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: DuskaraTheme.spacingS) {
            Text(title)
                .font(DuskaraTheme.Fonts.caption)
                .foregroundStyle(DuskaraTheme.mutedInk)
            content()
        }
    }

    private func destinationRow(_ town: Town) -> some View {
        let isSelected = town.id == destinationID
        return Button {
            destinationID = town.id
        } label: {
            HStack {
                Text(town.name)
                    .font(DuskaraTheme.Fonts.body)
                    .foregroundStyle(DuskaraTheme.ink)
                Spacer()
                Text("\(town.resources[kind]) \(kind.title)")
                    .font(DuskaraTheme.Fonts.numberSmall)
                    .foregroundStyle(DuskaraTheme.mutedInk)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(DuskaraTheme.accent)
                }
            }
            .padding(DuskaraTheme.spacingM)
            .frame(maxWidth: .infinity)
            .background(
                isSelected ? DuskaraTheme.accent.opacity(0.22) : DuskaraTheme.card,
                in: RoundedRectangle(cornerRadius: DuskaraTheme.cornerS)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DuskaraTheme.cornerS)
                    .stroke(isSelected ? DuskaraTheme.accent : .white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Send to \(town.name)")
    }

    private func resourceChip(_ resource: ResourceKind) -> some View {
        let isSelected = resource == kind
        return Button {
            kind = resource
        } label: {
            Text(resource.title)
                .font(DuskaraTheme.Fonts.caption)
                .foregroundStyle(isSelected ? .white : DuskaraTheme.mutedInk)
                .padding(.horizontal, DuskaraTheme.spacingM)
                .padding(.vertical, 7)
                .background(
                    isSelected ? DuskaraTheme.accent : DuskaraTheme.card,
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
    }
}
