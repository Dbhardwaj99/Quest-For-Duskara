import RealityKit
import AppKit
import Observation

@MainActor
final class World3DTownViewController: NSViewController {
    private let sourceViewModel: GameViewModel
    private var adapter: World3DStateAdapter
    private var renderer: World3DRenderer?
    private var renderView: World3DRenderView?
    private let cameraController = World3DCameraController()
    private var didCountActiveARView = false

    init(sourceViewModel: GameViewModel) {
        self.sourceViewModel = sourceViewModel
        self.adapter = World3DStateAdapter(viewModel: sourceViewModel)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureScene()
        syncFromGameState()
        observePlacementState()
    }

    // SwiftUI's representable update only re-fires if the last sync actually
    // read the model — a sync skipped mid-gesture reads nothing, dropping the
    // dependency and stranding placement overlays after Cancel. Observing the
    // placement state directly guarantees a render on every change.
    private func observePlacementState() {
        withObservationTracking { [weak self] in
            _ = self?.sourceViewModel.placementBuildingKind
            _ = self?.sourceViewModel.selectedCoordinate
        } onChange: { [weak self] in
            let controller = self
            Task { @MainActor in
                guard let controller else { return }
                controller.syncFromGameState()
                controller.observePlacementState()
            }
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        guard didCountActiveARView == false else { return }
        didCountActiveARView = true
        World3DDiagnostics.arViewDidAppear()
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        guard didCountActiveARView else { return }
        didCountActiveARView = false
        World3DDiagnostics.arViewDidDisappear()
    }

    deinit {
        if didCountActiveARView {
            Task { @MainActor in
                World3DDiagnostics.arViewDidDisappear()
            }
        }
    }

    func setCameraOrbiting(_ enabled: Bool) {
        cameraController.setOrbiting(enabled)
    }

    /// Stops drawing while something else covers the town (the world map).
    func setActive(_ active: Bool) {
        renderView?.isPaused = !active
    }

    func applyBuildingScales() {
        renderer?.applyBuildingScales()
    }

    func syncFromGameState() {
        guard cameraController.isInteracting == false else { return }
        renderer?.render(adapter: adapter)
    }

    private func configureScene() {
        let renderView: World3DRenderView
        do {
            renderView = World3DRenderView(renderer: try RealityRenderer())
        } catch {
            // ponytail: no Metal/RealityKit renderer means no town view; the
            // HUD and world map still work.
            debugPrint("World3D: renderer unavailable:", error)
            return
        }
        renderView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(renderView)

        NSLayoutConstraint.activate([
            renderView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            renderView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            renderView.topAnchor.constraint(equalTo: view.topAnchor),
            renderView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        let renderer = World3DRenderer(renderView: renderView)
        cameraController.install(
            in: renderView,
            bounds: renderer.cameraBounds(for: sourceViewModel.balance.gridSize),
            parent: renderer.cameraParent
        )
        renderView.renderer.activeCamera = cameraController.camera
        renderView.onFrame = { [weak cameraController] deltaTime in
            cameraController?.advance(by: deltaTime)
        }
        cameraController.onInteractionEnded = { [weak self] in
            self?.syncFromGameState()
        }
        self.renderer = renderer
        self.renderView = renderView

        let tap = NSClickGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        renderView.addGestureRecognizer(tap)
    }

    @objc private func handleTap(_ recognizer: NSClickGestureRecognizer) {
        guard let renderView, let renderer,
              let ray = renderView.ray(through: recognizer.location(in: renderView)),
              let coordinate = renderer.coordinate(along: ray) else { return }

        sourceViewModel.selectCell(coordinate)
        renderer.render(adapter: adapter)
    }
}
