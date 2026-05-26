import RealityKit
import UIKit

@MainActor
final class World3DTownViewController: UIViewController {
    private let sourceViewModel: GameViewModel
    private var adapter: World3DStateAdapter
    private var renderer: World3DRenderer?
    private let cameraController = World3DCameraController()

    init(sourceViewModel: GameViewModel) {
        self.sourceViewModel = sourceViewModel
        self.adapter = World3DStateAdapter(viewModel: sourceViewModel)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureScene()
        syncFromGameState()
    }

    func syncFromGameState() {
        guard cameraController.isInteracting == false else { return }
        renderer?.render(adapter: adapter)
    }

    private func configureScene() {
        view.backgroundColor = .black

        let arView = ARView(frame: view.bounds, cameraMode: .nonAR, automaticallyConfigureSession: false)
        arView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(arView)

        NSLayoutConstraint.activate([
            arView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            arView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            arView.topAnchor.constraint(equalTo: view.topAnchor),
            arView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        let renderer = World3DRenderer(arView: arView)
        cameraController.install(
            in: arView,
            bounds: renderer.cameraBounds(for: sourceViewModel.balance.gridSize),
            parent: renderer.cameraParent
        )
        self.renderer = renderer

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        arView.addGestureRecognizer(tap)
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard let arView = recognizer.view as? ARView, let renderer else { return }
        let location = recognizer.location(in: arView)
        guard let coordinate = renderer.coordinate(for: arView.entity(at: location)) else { return }

        sourceViewModel.selectCell(coordinate)
        renderer.render(adapter: adapter)
    }
}
