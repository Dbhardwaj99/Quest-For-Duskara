import RealityKit
import UIKit

@MainActor
final class World3DTownViewController: UIViewController {
    private let sourceViewModel: GameViewModel
    private var adapter: World3DStateAdapter
    private var renderer: World3DRenderer?
    private let cameraController = World3DCameraController()
    private var fpsDisplayLink: CADisplayLink?
    private var fpsFrameCount = 0
    private var fpsStartTime: CFTimeInterval = 0
    private var didCountActiveARView = false

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

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard didCountActiveARView == false else { return }
        didCountActiveARView = true
        World3DDiagnostics.arViewDidAppear()
        startFPSReporting()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        guard didCountActiveARView else { return }
        didCountActiveARView = false
        stopFPSReporting()
        World3DDiagnostics.arViewDidDisappear()
    }

    deinit {
        fpsDisplayLink?.invalidate()
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
        view.backgroundColor = UIColor(red: 0.18, green: 0.22, blue: 0.27, alpha: 1)

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

    private func startFPSReporting() {
        fpsDisplayLink?.invalidate()
        fpsFrameCount = 0
        fpsStartTime = CACurrentMediaTime()
        let displayLink = CADisplayLink(target: self, selector: #selector(stepFPS(_:)))
        displayLink.add(to: .main, forMode: .common)
        fpsDisplayLink = displayLink
    }

    private func stopFPSReporting() {
        fpsDisplayLink?.invalidate()
        fpsDisplayLink = nil
    }

    @objc private func stepFPS(_ displayLink: CADisplayLink) {
        fpsFrameCount += 1
        let elapsed = displayLink.timestamp - fpsStartTime
        guard elapsed >= 2 else { return }
        World3DDiagnostics.recordFPS(Double(fpsFrameCount) / elapsed)
        fpsFrameCount = 0
        fpsStartTime = displayLink.timestamp
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard let arView = recognizer.view as? ARView, let renderer else { return }
        let location = recognizer.location(in: arView)
        guard let coordinate = renderer.coordinate(for: arView.entity(at: location)) else { return }

        sourceViewModel.selectCell(coordinate)
        renderer.render(adapter: adapter)
    }
}
