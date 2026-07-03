import RealityKit
import AppKit

@MainActor
final class World3DTownViewController: NSViewController {
    private let sourceViewModel: GameViewModel
    private var adapter: World3DStateAdapter
    private var renderer: World3DRenderer?
    private let cameraController = World3DCameraController()
    private var fpsTimer: Timer?
    private var fpsFrameCount = 0
    private var fpsStartTime: TimeInterval = 0
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
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        guard didCountActiveARView == false else { return }
        didCountActiveARView = true
        World3DDiagnostics.arViewDidAppear()
        startFPSReporting()
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        guard didCountActiveARView else { return }
        didCountActiveARView = false
        stopFPSReporting()
        World3DDiagnostics.arViewDidDisappear()
    }

    deinit {
        fpsTimer?.invalidate()
        if didCountActiveARView {
            Task { @MainActor in
                World3DDiagnostics.arViewDidDisappear()
            }
        }
    }

    func syncFromGameState() {
        guard cameraController.isInteracting == false else { return }
        renderer?.render(adapter: adapter)
    }

    private func configureScene() {
        let arView = ARView(frame: view.bounds)
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
        cameraController.onInteractionEnded = { [weak self] in
            self?.syncFromGameState()
        }
        self.renderer = renderer

        let tap = NSClickGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        arView.addGestureRecognizer(tap)
    }

    private func startFPSReporting() {
        fpsTimer?.invalidate()
        fpsFrameCount = 0
        fpsStartTime = ProcessInfo.processInfo.systemUptime
        fpsTimer = Timer.scheduledTimer(timeInterval: 1 / 60, target: self, selector: #selector(stepFPS(_:)), userInfo: nil, repeats: true)
    }

    private func stopFPSReporting() {
        fpsTimer?.invalidate()
        fpsTimer = nil
    }

    @objc private func stepFPS(_ timer: Timer) {
        fpsFrameCount += 1
        let now = ProcessInfo.processInfo.systemUptime
        let elapsed = now - fpsStartTime
        guard elapsed >= 2 else { return }
        World3DDiagnostics.recordFPS(Double(fpsFrameCount) / elapsed)
        fpsFrameCount = 0
        fpsStartTime = now
    }

    @objc private func handleTap(_ recognizer: NSClickGestureRecognizer) {
        guard let arView = recognizer.view as? ARView, let renderer else { return }
        let location = recognizer.location(in: arView)
        guard let coordinate = renderer.coordinate(for: arView.entity(at: location)) else { return }

        sourceViewModel.selectCell(coordinate)
        renderer.render(adapter: adapter)
    }
}
