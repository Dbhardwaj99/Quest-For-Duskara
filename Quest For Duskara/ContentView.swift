import SwiftUI

struct ContentView: View {
    @State private var viewModel = GameViewModel()

    var body: some View {
        GameView(viewModel: viewModel)
    }
}

#Preview {
    ContentView()
}
