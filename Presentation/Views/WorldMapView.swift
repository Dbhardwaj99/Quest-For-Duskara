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
        GeometryReader { proxy in
            ZStack {
                ForEach(viewModel.state.connections) { connection in
                    Path { path in
                        path.move(to: point(for: connection.from, in: proxy.size))
                        path.addLine(to: point(for: connection.to, in: proxy.size))
                    }
                    .stroke(.white.opacity(0.20), lineWidth: 2)
                }

                ForEach(viewModel.state.worldNodes) { node in
                    if let town = viewModel.state.town(id: node.townID) {
                        WorldTownNodeView(
                            town: town,
                            isActive: node.townID == viewModel.state.activeTownID,
                            isSelected: node.townID == selectedTownID,
                            isAdjacent: viewModel.isAdjacentToActiveTown(node.townID)
                        )
                        .position(point(for: node.townID, in: proxy.size))
                        .onTapGesture { selectedTownID = node.townID }
                    }
                }
            }
        }
        .frame(height: 500)
        .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.18), lineWidth: 1))
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

    private func point(for townID: UUID, in size: CGSize) -> CGPoint {
        guard let node = viewModel.state.worldNodes.first(where: { $0.townID == townID }) else { return .zero }
        return CGPoint(x: size.width * node.x, y: size.height * node.y)
    }

    private func statusText(for town: Town) -> String {
        if town.isPlayerControlled { return "Controlled town · Army \(town.armyStrength)" }
        let defense = viewModel.effectiveDefenseStrength(for: town)
        if town.isDuskara { return "Duskara stronghold · Defense \(defense)" }
        if town.faction == .enemy { return "Enemy town · Strength \(defense)" }
        return "Neutral town · Defense \(defense)"
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

private struct WorldTownNodeView: View {
    let town: Town
    let isActive: Bool
    let isSelected: Bool
    let isAdjacent: Bool

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                Circle()
                    .fill(nodeFill)
                    .frame(width: nodeSize, height: nodeSize)
                Image(systemName: nodeIcon)
                    .font(.caption)
                    .foregroundStyle(.white)
            }
            Text(town.name)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.white.opacity(0.88))
                .lineLimit(1)
                .frame(width: 54)
        }
        .padding(5)
        .background(isSelected ? .white.opacity(0.18) : .clear, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            Circle()
                .stroke(isAdjacent ? Color.yellow.opacity(0.9) : .clear, lineWidth: 2)
                .frame(width: 42, height: 42)
                .offset(y: -8)
        )
    }

    private var nodeFill: AnyShapeStyle {
        if town.isPlayerControlled { return AnyShapeStyle(Color.green.gradient) }
        if town.isDuskara { return AnyShapeStyle(Color.purple.gradient) }
        if town.faction == .enemy { return AnyShapeStyle(Color.red.gradient) }
        return AnyShapeStyle(Color.gray.gradient)
    }

    private var nodeIcon: String {
        if town.isPlayerControlled { return "house.fill" }
        if town.isDuskara { return "crown.fill" }
        if town.faction == .enemy { return "shield.fill" }
        return "circle.fill"
    }

    private var nodeSize: CGFloat {
        if isActive { return 34 }
        return town.isDuskara ? 36 : 28
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
