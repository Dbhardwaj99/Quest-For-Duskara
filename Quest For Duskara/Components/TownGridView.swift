import SwiftUI

struct TownGridView: View {
    let town: Town
    let gridSize: GridSize
    let selectedCoordinate: GridCoordinate?
    let selectedBuildingID: UUID?
    let onSelect: (GridCoordinate) -> Void

    var body: some View {
        GeometryReader { proxy in
            let cell = min(proxy.size.width / CGFloat(gridSize.columns), proxy.size.height / CGFloat(gridSize.rows))
            let width = cell * CGFloat(gridSize.columns)
            let height = cell * CGFloat(gridSize.rows)

            ZStack {
                BiomeBorderView(layout: town.biomeLayout)
                    .frame(width: width + 70, height: height + 70)

                LazyVGrid(columns: Array(repeating: GridItem(.fixed(cell), spacing: 0), count: gridSize.columns), spacing: 0) {
                    ForEach(0..<(gridSize.columns * gridSize.rows), id: \.self) { index in
                        let coordinate = GridCoordinate(x: index % gridSize.columns, y: index / gridSize.columns)
                        TownCellView(
                            coordinate: coordinate,
                            building: town.buildings.first { $0.coordinate == coordinate },
                            isSelected: selectedCoordinate == coordinate || town.buildings.first(where: { $0.coordinate == coordinate })?.id == selectedBuildingID,
                            size: cell
                        )
                        .onTapGesture { onSelect(coordinate) }
                    }
                }
                .frame(width: width, height: height)
                .background(Color(red: 0.34, green: 0.48, blue: 0.29).opacity(0.82), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.24), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .clipped()
    }
}

private struct TownCellView: View {
    let coordinate: GridCoordinate
    let building: BuildingInstance?
    let isSelected: Bool
    let size: CGFloat

    var body: some View {
        ZStack {
            Rectangle()
                .fill((coordinate.x + coordinate.y).isMultiple(of: 2) ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
            Rectangle()
                .stroke(.black.opacity(0.13), lineWidth: 0.5)
            if let building {
                BuildingArtView(building: building)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Circle()
                    .fill(.white.opacity(0.08))
                    .frame(width: max(8, size * 0.18), height: max(8, size * 0.18))
            }
            if isSelected {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.yellow, lineWidth: 3)
                    .padding(2)
            }
        }
        .frame(width: size, height: size)
        .contentShape(Rectangle())
    }
}
