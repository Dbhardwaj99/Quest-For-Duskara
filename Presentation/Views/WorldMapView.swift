import SwiftUI

/// Full-screen world map. The map itself fills the window and pans under
/// fixed floating overlays (header, legend, selected-town panel).
struct WorldMapView: View {
    @Bindable var viewModel: GameViewModel
    @State private var selectedTownID: UUID?
    @State private var transferKind: ResourceKind = .gold
    @State private var transferAmount = 10
    @State private var panOffset: CGSize = .zero
    @State private var dragStartOffset: CGSize?

    /// How much larger than the window the terrain renders, so there is room to pan.
    private let mapOverscan: CGFloat = 1.3
    /// Open ocean around the terrain, so edge islands never touch the map border.
    private let oceanPadding: CGFloat = 110

    var body: some View {
        ZStack {
            // Only the map itself extends under the title bar; the floating
            // controls stay inside the safe area so they are never cropped.
            GeometryReader { proxy in
                ZStack {
                    seaBackground
                    mapViewport(container: proxy.size)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
            .ignoresSafeArea()

            header
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(14)
            legend
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(14)
            selectedTownPanel
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 16)
        }
        .onAppear {
            selectedTownID = viewModel.state.activeTownID
        }
        .onChange(of: viewModel.state.activeTownID) { _, activeTownID in
            selectedTownID = activeTownID
        }
    }

    // Flat tropical sea with faint cartoon wave arcs — same design language
    // as the 3D town's water.
    private var seaBackground: some View {
        ZStack {
            Color(red: 0.28, green: 0.56, blue: 0.62)
            Canvas { context, size in
                let spacing: CGFloat = 58
                var row = 0
                var y: CGFloat = spacing * 0.4
                while y < size.height + spacing {
                    var x: CGFloat = (row.isMultiple(of: 2) ? 0 : spacing / 2) - spacing
                    while x < size.width + spacing {
                        var arc = Path()
                        arc.addArc(
                            center: CGPoint(x: x, y: y),
                            radius: spacing * 0.24,
                            startAngle: .degrees(25),
                            endAngle: .degrees(155),
                            clockwise: false
                        )
                        context.stroke(arc, with: .color(.white.opacity(0.09)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        x += spacing
                    }
                    y += spacing * 0.75
                    row += 1
                }
            }
        }
    }

    // MARK: - Pannable map

    // Window-sized, clipped viewport; the larger map (terrain + a ring of
    // open ocean) pans inside it.
    private func mapViewport(container: CGSize) -> some View {
        let terrain = terrainSize(in: container)
        let outer = CGSize(width: terrain.width + oceanPadding * 2, height: terrain.height + oceanPadding * 2)
        return TerritoryRenderer(
            world: viewModel.state.world,
            territory: viewModel.state.territory,
            towns: viewModel.state.towns,
            nodes: viewModel.state.worldNodes,
            connections: viewModel.state.connections,
            activeTownID: viewModel.state.activeTownID,
            selectedTownID: selectedTownID,
            onSelectTown: { selectedTownID = $0 }
        )
        .frame(width: terrain.width, height: terrain.height)
        .frame(width: outer.width, height: outer.height)
        .offset(panOffset)
        .frame(width: container.width, height: container.height)
        .clipped()
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onChanged { value in
                    let start = dragStartOffset ?? panOffset
                    dragStartOffset = start
                    panOffset = clampedOffset(
                        CGSize(width: start.width + value.translation.width, height: start.height + value.translation.height),
                        mapSize: outer,
                        container: container
                    )
                }
                .onEnded { _ in dragStartOffset = nil }
        )
    }

    private func terrainSize(in container: CGSize) -> CGSize {
        let aspect = viewModel.state.world.layout.aspectRatio
        let width = max(container.width, container.height * aspect) * mapOverscan
        return CGSize(width: width, height: width / aspect)
    }

    private func clampedOffset(_ offset: CGSize, mapSize: CGSize, container: CGSize) -> CGSize {
        let maxX = max(0, (mapSize.width - container.width) / 2)
        let maxY = max(0, (mapSize.height - container.height) / 2)
        return CGSize(
            width: min(maxX, max(-maxX, offset.width)),
            height: min(maxY, max(-maxY, offset.height))
        )
    }

    // MARK: - Floating overlays

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("World Map")
                    .font(.title3.weight(.black))
                    .foregroundStyle(DuskaraTheme.ink)
                Text("Empire power \(viewModel.empireArmyStrength) · Active: \(viewModel.activeTown.name)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DuskaraTheme.mutedInk)
            }
            Button {
                viewModel.isWorldMapPresented = false
            } label: {
                Label("Town", systemImage: "chevron.backward")
            }
            .buttonStyle(DuskaraButtonStyle(prominent: true))
            .fixedSize()
            .accessibilityLabel("Return to town")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(DuskaraTheme.hudFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(DuskaraTheme.glassStroke, lineWidth: 1))
        .shadow(color: .black.opacity(0.30), radius: 14, y: 7)
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Territories")
                .font(.caption2.weight(.black))
                .foregroundStyle(DuskaraTheme.ink)
            HStack(spacing: 8) {
                LegendSwatch(color: TownFaction.player.mapColor, title: "You")
                LegendSwatch(color: TownFaction.neutral.mapColor, title: "Neutral")
                LegendSwatch(color: TownFaction.enemy.mapColor, title: "Enemy")
                LegendSwatch(color: TownFaction.duskara.mapColor, title: "Duskara")
            }
        }
        .padding(10)
        .background(DuskaraTheme.hudFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(DuskaraTheme.glassStroke, lineWidth: 1))
        .shadow(color: .black.opacity(0.30), radius: 12, y: 6)
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
                            .foregroundStyle(DuskaraTheme.mutedInk)
                        if town.isPlayerControlled {
                            Text(town.specializationSummary)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(specializationColor(for: town))
                        }
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

                // Friendly towns show their stockpile; enemy towns reveal
                // only their soldier count (already in the status line).
                if town.isPlayerControlled {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(ResourceKind.allCases) { kind in
                                ResourcePill(kind: kind, amount: kind == .soldiers ? town.armyStrength : town.resources[kind])
                            }
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
            .frame(maxWidth: 480)
            .background(DuskaraTheme.hudFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(DuskaraTheme.glassStroke, lineWidth: 1))
            .shadow(color: .black.opacity(0.30), radius: 16, y: 8)
        }
    }

    private func statusText(for town: Town) -> String {
        if town.isPlayerControlled { return "Controlled town · Army \(town.armyStrength)" }
        if town.isDuskara { return "Duskara stronghold · Soldiers \(town.armyStrength)" }
        if town.faction == .enemy { return "Enemy town · Soldiers \(town.armyStrength)" }
        return "Neutral town · Soldiers \(town.armyStrength)"
    }

    private func availableTransferAmount(for kind: ResourceKind) -> Int {
        kind == .soldiers ? viewModel.activeTown.armyStrength : viewModel.activeTown.resources[kind]
    }

    private func specializationColor(for town: Town) -> Color {
        if town.forestSideCount >= 3 { return Color(red: 0.55, green: 0.80, blue: 0.45) }
        if town.mountainSideCount >= 3 { return Color(red: 0.75, green: 0.77, blue: 0.80) }
        return DuskaraTheme.mutedInk
    }
}

private struct LegendSwatch: View {
    let color: Color
    let title: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(DuskaraTheme.mutedInk)
        }
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
                .foregroundStyle(DuskaraTheme.mutedInk)
            Text("Available \(kind.title): \(available)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(DuskaraTheme.mutedInk)
            HStack(spacing: 10) {
                Picker("Resource", selection: $kind) {
                    ForEach(ResourceKind.allCases.filter { $0 != .people }) { resource in
                        Text(resource.title).tag(resource)
                    }
                }
                .pickerStyle(.menu)

                Stepper("\(amount)", value: $amount, in: 1...max(1, min(100, available)), step: kind == .soldiers ? 1 : 10)
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(DuskaraTheme.ink)

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
