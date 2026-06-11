import SwiftUI

struct WorldMapView: View {
    @Bindable var viewModel: GameViewModel
    @State private var selectedTownID: UUID?
    @State private var transferKind: ResourceKind = .gold
    @State private var transferAmount = 10

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.13, blue: 0.16), Color(red: 0.20, green: 0.25, blue: 0.18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {
                header
                mapCanvas
                selectedTownPanel
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
        }
        .onAppear {
            selectedTownID = viewModel.state.activeTownID
        }
        .onChange(of: viewModel.state.activeTownID) { _, activeTownID in
            selectedTownID = activeTownID
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("World Map")
                    .font(.title2.weight(.black))
                    .foregroundStyle(.white)
                Text("Empire power \(viewModel.empireArmyStrength) · Active: \(viewModel.activeTown.name)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))
            }
            Spacer()
            Button {
                viewModel.isWorldMapPresented = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
            }
            .foregroundStyle(.white)
        }
    }

    private var mapCanvas: some View {
        let adjacentIDs = Set(viewModel.state.worldNodes.map(\.townID).filter { viewModel.isAdjacentToActiveTown($0) })

        return TerritoryRenderer(
            world: viewModel.state.world,
            territory: viewModel.state.territory,
            towns: viewModel.state.towns,
            nodes: viewModel.state.worldNodes,
            connections: viewModel.state.connections,
            activeTownID: viewModel.state.activeTownID,
            selectedTownID: selectedTownID,
            adjacentTownIDs: adjacentIDs,
            onSelectTown: { selectedTownID = $0 }
        )
        .frame(height: 540)
        .overlay(alignment: .bottomTrailing) {
            Text("\(viewModel.state.towns.count) cities · \(viewModel.state.world.terrainTiles.count) terrain sectors")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.66))
                .padding(8)
                .background(.black.opacity(0.26), in: Capsule())
                .padding(10)
        }
    }

    @ViewBuilder
    private var selectedTownPanel: some View {
        if let selectedTownID, let town = viewModel.state.town(id: selectedTownID) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(town.name)
                            .font(.headline.weight(.heavy))
                            .foregroundStyle(DuskaraTheme.ink)
                        Text(statusText(for: town))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(town.specializationSummary)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(specializationColor(for: town))
                        Text(territoryText(for: town))
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if town.isPlayerControlled {
                        Button("Visit") { viewModel.switchToTown(town.id) }
                            .buttonStyle(DuskaraButtonStyle(prominent: true))
                            .frame(width: 96)
                    } else {
                        Button("Attack") { viewModel.attackTown(town.id) }
                            .buttonStyle(DuskaraButtonStyle(prominent: true))
                            .frame(width: 104)
                            .disabled(!viewModel.canAttack(town.id))
                            .opacity(viewModel.canAttack(town.id) ? 1 : 0.45)
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(ResourceKind.allCases) { kind in
                            ResourcePill(kind: kind, amount: kind == .soldiers ? town.armyStrength : town.resources[kind])
                        }
                    }
                }

                if town.isPlayerControlled && town.id != viewModel.state.activeTownID {
                    TransferPanel(
                        kind: $transferKind,
                        amount: $transferAmount,
                        available: availableTransferAmount(for: transferKind),
                        onSend: { viewModel.transfer(transferKind, amount: transferAmount, to: town.id) }
                    )
                }
            }
            .padding(14)
            .background(DuskaraTheme.panel, in: RoundedRectangle(cornerRadius: 8))
            .padding(.bottom, 10)
        }
    }

    private func statusText(for town: Town) -> String {
        if town.isPlayerControlled { return "Controlled town · Army \(town.armyStrength)" }
        let defense = viewModel.effectiveDefenseStrength(for: town)
        if town.isDuskara { return "Duskara stronghold · Defense \(defense)" }
        if town.faction == .enemy { return "Enemy town · Strength \(defense)" }
        return "Neutral town · Defense \(defense)"
    }

    private func territoryText(for town: Town) -> String {
        guard let region = viewModel.state.territory.region(for: town.id) else {
            return "Territory survey pending"
        }
        let dominantTerrain = region.terrainMix.max { lhs, rhs in lhs.value < rhs.value }?.key.title ?? "Mixed"
        return "Territory \(region.cellCount) sectors · Dominant \(dominantTerrain)"
    }

    private func availableTransferAmount(for kind: ResourceKind) -> Int {
        kind == .soldiers ? viewModel.activeTown.armyStrength : viewModel.activeTown.resources[kind]
    }

    private func specializationColor(for town: Town) -> Color {
        if town.forestSideCount >= 3 { return .green }
        if town.mountainSideCount >= 3 { return .gray }
        return .secondary
    }
}

private struct TransferPanel: View {
    @Binding var kind: ResourceKind
    @Binding var amount: Int
    let available: Int
    let onSend: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Transfer from active town")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            Text("Available \(kind.title): \(available)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                Picker("Resource", selection: $kind) {
                    ForEach(ResourceKind.allCases.filter { $0 != .people }) { resource in
                        Text(resource.title).tag(resource)
                    }
                }
                .pickerStyle(.menu)

                Stepper("\(amount)", value: $amount, in: 1...max(1, min(100, available)), step: kind == .soldiers ? 1 : 10)
                    .font(.caption.monospacedDigit().weight(.semibold))

                Button("Send", action: onSend)
                    .buttonStyle(DuskaraButtonStyle(prominent: true))
                    .frame(width: 88)
                    .disabled(available <= 0 || amount > available)
                    .opacity(available <= 0 || amount > available ? 0.45 : 1)
            }
        }
        .onChange(of: kind) { _, _ in
            amount = min(max(1, amount), max(1, available))
        }
        .onChange(of: available) { _, available in
            amount = min(max(1, amount), max(1, available))
        }
    }
}
