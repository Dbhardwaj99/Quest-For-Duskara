import SwiftUI

struct TownGridView: View {
    let town: Town
    let gridSize: GridSize
    let selectedCoordinate: GridCoordinate?
    let selectedBuildingID: UUID?
    let placementBuildingKind: BuildingKind?
    let tilePlacementState: (GridCoordinate) -> TilePlacementState
    let onSelect: (GridCoordinate) -> Void

    var body: some View {
        GeometryReader { proxy in
            let cell = min(74, max(56, proxy.size.width / 5.6))
            let width = cell * CGFloat(gridSize.columns)
            let height = cell * CGFloat(gridSize.rows)
            let terrainDepth = min(110, max(82, cell * 1.45))
            let contentWidth = width + terrainDepth * 2
            let contentHeight = height + terrainDepth * 2

            ScrollView([.horizontal, .vertical], showsIndicators: false) {
                ZStack {
                    BiomeBorderView(layout: town.biomeLayout, borderDepth: terrainDepth)
                        .frame(width: contentWidth, height: contentHeight)

                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(cell), spacing: 0), count: gridSize.columns), spacing: 0) {
                        ForEach(0..<(gridSize.columns * gridSize.rows), id: \.self) { index in
                            let coordinate = GridCoordinate(x: index % gridSize.columns, y: index / gridSize.columns)
                            let building = town.buildings.first { $0.coordinate == coordinate }
                            TownCellView(
                                coordinate: coordinate,
                                building: building,
                                isSelected: selectedCoordinate == coordinate || building?.id == selectedBuildingID,
                                placementState: tilePlacementState(coordinate),
                                isPlacementMode: placementBuildingKind != nil,
                                size: cell
                            )
                            .onTapGesture { onSelect(coordinate) }
                        }
                    }
                    .frame(width: width, height: height)
                    .background(Color(red: 0.34, green: 0.48, blue: 0.29).opacity(0.88), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.28), lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: .black.opacity(0.22), radius: 12, y: 8)
                }
                .frame(width: contentWidth, height: contentHeight)
                .padding(.horizontal, max(0, (proxy.size.width - contentWidth) / 2))
                .padding(.vertical, max(0, (proxy.size.height - contentHeight) / 2))
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(Color.black.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

private struct TownCellView: View {
    let coordinate: GridCoordinate
    let building: BuildingInstance?
    let isSelected: Bool
    let placementState: TilePlacementState
    let isPlacementMode: Bool
    let size: CGFloat

    var body: some View {
        ZStack {
            Rectangle()
                .fill(baseFill)
            Rectangle()
                .stroke(.black.opacity(0.13), lineWidth: 0.5)

            if let building {
                BuildingArtView(building: building)
                    .transition(.scale.combined(with: .opacity))
                    .opacity(isPlacementMode ? 0.55 : 1)
            } else {
                Circle()
                    .fill(.white.opacity(isPlacementMode ? 0.06 : 0.08))
                    .frame(width: max(8, size * 0.18), height: max(8, size * 0.18))
            }

            placementOverlay

            if isSelected && isPlacementMode == false {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.yellow, lineWidth: 3)
                    .padding(2)
            }
        }
        .frame(width: size, height: size)
        .contentShape(Rectangle())
        .animation(.snappy(duration: 0.18), value: placementState)
    }

    private var baseFill: Color {
        let normal = (coordinate.x + coordinate.y).isMultiple(of: 2) ? Color.white.opacity(0.08) : Color.black.opacity(0.05)
        guard isPlacementMode else { return normal }
        switch placementState {
        case .normal:
            return normal
        case .valid:
            return Color.green.opacity(0.20)
        case .invalid:
            return Color.red.opacity(0.20)
        }
    }

    @ViewBuilder
    private var placementOverlay: some View {
        if isPlacementMode {
            switch placementState {
            case .normal:
                EmptyView()
            case .valid:
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.green.opacity(0.9), lineWidth: 2)
                    .padding(3)
            case .invalid:
                Rectangle()
                    .fill(.black.opacity(0.22))
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.red.opacity(0.72), lineWidth: 1.5)
                    .padding(4)
            }
        }
    }
}
