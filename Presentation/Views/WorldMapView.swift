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
    @State private var zoomScale: CGFloat = 1
    @State private var magnifyStartScale: CGFloat?

    /// How much larger than the window the terrain renders, so there is room to pan.
    private let mapOverscan: CGFloat = 1.3
    /// Open ocean around the terrain, so edge islands never touch the map border.
    private let oceanPadding: CGFloat = 110
    private let maxZoom: CGFloat = 2.6

    var body: some View {
        ZStack {
            // Only the map itself extends under the title bar; the floating
            // controls stay inside the safe area so they are never cropped.
            GeometryReader { proxy in
                ZStack {
                    // Open sea backdrop for the ring beyond the pannable map.
                    Color(red: 0.28, green: 0.56, blue: 0.62)
                    mapViewport(container: proxy.size)
                    mapVignette
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
            CompassRose()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(18)
            zoomControls
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(14)
            selectedTownPanel
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 16)
        }
        .onAppear {
            selectedTownID = viewModel.activeTownID
        }
        .onChange(of: viewModel.activeTownID) { _, activeTownID in
            selectedTownID = activeTownID
        }
    }

    // Soft edge falloff over the whole viewport gives the map depth without
    // touching the terrain itself.
    private var mapVignette: some View {
        RadialGradient(
            colors: [.clear, .black.opacity(0.20)],
            center: .center,
            startRadius: 280,
            endRadius: 950
        )
        .allowsHitTesting(false)
    }

    // MARK: - Pannable, zoomable map

    // Window-sized, clipped viewport; the larger map (sea + terrain + a ring
    // of open ocean) pans and zooms inside it. The displayed offset is always
    // clamped, so zooming out can never strand the map off-center.
    private func mapViewport(container: CGSize) -> some View {
        let terrain = terrainSize(in: container)
        let outer = CGSize(width: terrain.width + oceanPadding * 2, height: terrain.height + oceanPadding * 2)
        let scaled = CGSize(width: outer.width * zoomScale, height: outer.height * zoomScale)
        return ZStack {
            SeaWavesLayer()
            TerritoryRenderer(
                world: viewModel.state.world,
                territory: viewModel.state.territory,
                towns: viewModel.state.towns,
                nodes: viewModel.state.worldNodes,
                connections: viewModel.state.connections,
                activeTownID: viewModel.activeTownID,
                selectedTownID: selectedTownID,
                markerScale: 1 / sqrt(zoomScale),
                onSelectTown: { selectedTownID = $0 }
            )
            .frame(width: terrain.width, height: terrain.height)
        }
        .frame(width: outer.width, height: outer.height)
        .scaleEffect(zoomScale)
        .offset(clampedOffset(panOffset, mapSize: scaled, container: container))
        .frame(width: container.width, height: container.height)
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            stepZoom(zoomScale >= maxZoom - 0.05 ? 1 : min(maxZoom, zoomScale * 1.6))
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    let start = dragStartOffset ?? panOffset
                    dragStartOffset = start
                    panOffset = clampedOffset(
                        CGSize(width: start.width + value.translation.width, height: start.height + value.translation.height),
                        mapSize: scaled,
                        container: container
                    )
                }
                .onEnded { _ in dragStartOffset = nil }
        )
        .simultaneousGesture(
            MagnifyGesture()
                .onChanged { value in
                    let start = magnifyStartScale ?? zoomScale
                    magnifyStartScale = start
                    zoomScale = min(maxZoom, max(1, start * value.magnification))
                }
                .onEnded { _ in
                    magnifyStartScale = nil
                    panOffset = clampedOffset(panOffset, mapSize: CGSize(width: outer.width * zoomScale, height: outer.height * zoomScale), container: container)
                }
        )
    }

    private var zoomControls: some View {
        VStack(spacing: 0) {
            zoomButton(systemImage: "plus", disabled: zoomScale >= maxZoom - 0.01) {
                stepZoom(min(maxZoom, zoomScale * 1.35))
            }
            Divider()
                .overlay(DuskaraTheme.glassStroke)
                .frame(width: 24)
            zoomButton(systemImage: "minus", disabled: zoomScale <= 1.01) {
                stepZoom(max(1, zoomScale / 1.35))
            }
        }
        .background(DuskaraTheme.hudFill, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(DuskaraTheme.glassStroke, lineWidth: 1))
        .shadow(color: .black.opacity(0.30), radius: 12, y: 6)
    }

    private func zoomButton(systemImage: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white.opacity(disabled ? 0.35 : 0.92))
                .frame(width: 36, height: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .accessibilityLabel(systemImage == "plus" ? "Zoom in" : "Zoom out")
    }

    private func stepZoom(_ target: CGFloat) {
        withAnimation(.smooth(duration: 0.28)) {
            zoomScale = target
        }
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
                    .font(DuskaraTheme.Fonts.heading)
                    .foregroundStyle(DuskaraTheme.ink)
                Text("Empire power \(viewModel.empireArmyStrength) · Active: \(viewModel.activeTown.name)")
                    .font(DuskaraTheme.Fonts.caption)
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
                .font(DuskaraTheme.Fonts.caption)
                .foregroundStyle(DuskaraTheme.ink)
            HStack(spacing: 8) {
                LegendSwatch(color: TownFaction.player.mapColor, title: "You")
                LegendSwatch(color: TownFaction.neutral.mapColor, title: "Neutral")
                LegendSwatch(color: TownFaction.enemy.mapColor, title: "Enemy")
                LegendSwatch(color: TownFaction.duskara.mapColor, title: "Duskara")
            }
            HStack(spacing: 4) {
                HStack(spacing: 2) {
                    ForEach(0..<3) { _ in
                        Capsule()
                            .fill(Color(red: 0.94, green: 0.78, blue: 0.42))
                            .frame(width: 5, height: 2)
                    }
                }
                Text("Trade route")
                    .font(DuskaraTheme.Fonts.label)
                    .foregroundStyle(DuskaraTheme.mutedInk)
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
                            .font(DuskaraTheme.Fonts.heading)
                            .foregroundStyle(DuskaraTheme.ink)
                        Text(statusText(for: town))
                            .font(DuskaraTheme.Fonts.caption)
                            .foregroundStyle(DuskaraTheme.mutedInk)
                        if town.isPlayerControlled {
                            Text(town.specializationSummary)
                                .font(DuskaraTheme.Fonts.label)
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

                if town.isPlayerControlled && town.id != viewModel.activeTownID {
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

// Cartoon wave arcs living inside the pannable/zoomable map content, so the
// sea moves with the terrain instead of sitting behind it as a fixed sheet.
// Row phase and radius wobble slightly so the grid doesn't read as a grid.
private struct SeaWavesLayer: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 58
            var row = 0
            var y: CGFloat = spacing * 0.4
            while y < size.height + spacing {
                let wobble = sin(CGFloat(row) * 2.17)
                var x: CGFloat = (row.isMultiple(of: 2) ? 0 : spacing / 2) + wobble * spacing * 0.22 - spacing
                var column = 0
                while x < size.width + spacing {
                    defer {
                        x += spacing * (0.86 + 0.28 * abs(sin(CGFloat(row * 7 + column) * 1.31)))
                        column += 1
                    }
                    // Occasional missing arc keeps the swell irregular.
                    if (row * 13 + column * 7) % 5 == 0 { continue }
                    var arc = Path()
                    arc.addArc(
                        center: CGPoint(x: x, y: y + wobble * 4),
                        radius: spacing * (0.20 + 0.07 * abs(wobble)),
                        startAngle: .degrees(25),
                        endAngle: .degrees(155),
                        clockwise: false
                    )
                    context.stroke(
                        arc,
                        with: .color(.white.opacity(row.isMultiple(of: 3) ? 0.06 : 0.09)),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                }
                y += spacing * 0.75
                row += 1
            }
        }
        .allowsHitTesting(false)
    }
}

// Decorative eight-point compass rose, bottom-left, in the parchment style
// of the HUD.
private struct CompassRose: View {
    var body: some View {
        ZStack {
            CompassStar(innerRatio: 0.20)
                .fill(.white.opacity(0.22))
                .rotationEffect(.degrees(45))
                .frame(width: 34, height: 34)
            CompassStar(innerRatio: 0.24)
                .fill(.white.opacity(0.55))
                .frame(width: 46, height: 46)
            Text("N")
                .font(DuskaraTheme.Fonts.label)
                .foregroundStyle(.white.opacity(0.75))
                .offset(y: -32)
        }
        .frame(width: 56, height: 72, alignment: .bottom)
        .shadow(color: .black.opacity(0.35), radius: 3, y: 2)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct CompassStar: Shape {
    var innerRatio: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * innerRatio
        for index in 0..<8 {
            let angle = CGFloat(index) * .pi / 4 - .pi / 2
            let radius = index.isMultiple(of: 2) ? outerRadius : innerRadius
            let point = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
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
                .font(DuskaraTheme.Fonts.label)
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
                .font(DuskaraTheme.Fonts.caption)
                .foregroundStyle(DuskaraTheme.mutedInk)
            Text("Available \(kind.title): \(available)")
                .font(DuskaraTheme.Fonts.numberSmall)
                .foregroundStyle(DuskaraTheme.mutedInk)
            HStack(spacing: 10) {
                Picker("Resource", selection: $kind) {
                    ForEach(ResourceKind.allCases.filter { $0 != .people }) { resource in
                        Text(resource.title).tag(resource)
                    }
                }
                .pickerStyle(.menu)

                Stepper("\(amount)", value: $amount, in: 1...max(1, min(100, available)), step: kind == .soldiers ? 1 : 10)
                    .font(DuskaraTheme.Fonts.numberSmall)
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
