import SwiftUI

/// Full-screen world map. The map itself fills the window and pans under
/// fixed floating overlays (header, legend, compass, and zoom controls).
struct WorldMapView: View {
    @Bindable var viewModel: GameViewModel
    @State var selectedTownID: UUID?
    @State var panOffset: CGSize = .zero
    @State var dragStartOffset: CGSize?
    @State var zoomScale: CGFloat = 1
    @State var magnifyStartScale: CGFloat?

    /// How much larger than the window the terrain renders, so there is room to pan.
    let mapOverscan: CGFloat = 1.15
    /// Open ocean around the terrain, so edge islands never touch the map border.
    let oceanPadding: CGFloat = 80
    let maxZoom: CGFloat = 2.6

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
            GeometryReader { proxy in
                zoomControls(minZoom: minimumZoom(in: proxy.size))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(14)
            }
        }
    }

    // Soft edge falloff over the whole viewport gives the map depth without
    // touching the terrain itself.
    var mapVignette: some View {
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
    func mapViewport(container: CGSize) -> some View {
        let terrain = terrainSize(in: container)
        let outer = CGSize(width: terrain.width + oceanPadding * 2, height: terrain.height + oceanPadding * 2)
        let minZoom = mapFitScale(
            container: container,
            map: outer
        )
        let scaled = CGSize(width: outer.width * zoomScale, height: outer.height * zoomScale)
        return ZStack {
            SeaWavesLayer()
            TerritoryRenderer(
                world: viewModel.state.world,
                territory: viewModel.state.territory,
                towns: viewModel.state.towns,
                nodes: viewModel.state.worldNodes,
                connections: viewModel.state.connections,
                activeTownID: viewModel.state.activeTownID,
                selectedTownID: selectedTownID,
                markerScale: 1 / sqrt(zoomScale),
                onSelectTown: { selectedTownID = $0 },
                canActOnTown: { townID in
                    viewModel.state.town(id: townID)?.isPlayerControlled == true || viewModel.canAttack(townID)
                },
                onActOnTown: { townID in
                    if viewModel.state.town(id: townID)?.isPlayerControlled == true {
                        viewModel.switchToTown(townID)
                    } else {
                        viewModel.attackTown(townID)
                    }
                }
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
            stepZoom(zoomScale >= maxZoom - 0.05 ? minZoom : min(maxZoom, zoomScale * 1.6))
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
                    zoomScale = min(maxZoom, max(minZoom, start * value.magnification))
                }
                .onEnded { _ in
                    magnifyStartScale = nil
                    panOffset = clampedOffset(panOffset, mapSize: CGSize(width: outer.width * zoomScale, height: outer.height * zoomScale), container: container)
                }
        )
    }

    func zoomControls(minZoom: CGFloat) -> some View {
        VStack(spacing: 0) {
            zoomButton(systemImage: "plus", disabled: zoomScale >= maxZoom - 0.01) {
                stepZoom(min(maxZoom, zoomScale * 1.35))
            }
            Divider()
                .overlay(DuskaraTheme.glassStroke)
                .frame(width: 24)
            zoomButton(systemImage: "minus", disabled: zoomScale <= minZoom + 0.01) {
                stepZoom(max(minZoom, zoomScale / 1.35))
            }
        }
        .background(DuskaraTheme.hudFill, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(DuskaraTheme.glassStroke, lineWidth: 1))
        .shadow(color: .black.opacity(0.30), radius: 12, y: 6)
    }

    func zoomButton(systemImage: String, disabled: Bool, action: @escaping () -> Void) -> some View {
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

    func stepZoom(_ target: CGFloat) {
        withAnimation(.smooth(duration: 0.28)) {
            zoomScale = target
        }
    }

    func terrainSize(in container: CGSize) -> CGSize {
        let aspect = viewModel.state.world.layout.aspectRatio
        let width = max(container.width, container.height * aspect) * mapOverscan
        return CGSize(width: width, height: width / aspect)
    }

    func minimumZoom(in container: CGSize) -> CGFloat {
        let terrain = terrainSize(in: container)
        return mapFitScale(
            container: container,
            map: CGSize(width: terrain.width + oceanPadding * 2, height: terrain.height + oceanPadding * 2)
        )
    }

    func clampedOffset(_ offset: CGSize, mapSize: CGSize, container: CGSize) -> CGSize {
        let maxX = max(0, (mapSize.width - container.width) / 2)
        let maxY = max(0, (mapSize.height - container.height) / 2)
        return CGSize(
            width: min(maxX, max(-maxX, offset.width)),
            height: min(maxY, max(-maxY, offset.height))
        )
    }

    // MARK: - Floating overlays
}

func mapFitScale(container: CGSize, map: CGSize) -> CGFloat {
    min(1, min(container.width / map.width, container.height / map.height))
}
