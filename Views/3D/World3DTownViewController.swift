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
    private var isInputEnabled = true
    private var isSceneActive = true
    private let initialWorldMapProgress: Double
    private var renderedTown: Town?
    private var renderedGridSize: GridSize?
    private var renderedSelection: GridCoordinate?
    private var renderedPlacement: BuildingKind?
    private var renderedTheme: WorldTheme?
    private var renderedContrast: Double?
    private var renderedPlacementStock: ResourceWallet?
    private var renderedPlayerTownCount: Int?
    private var appliedBuildingScales: [BuildingKind: Float]?

    init(sourceViewModel: GameViewModel, initialWorldMapProgress: Double = 0) {
        self.sourceViewModel = sourceViewModel
        self.adapter = World3DStateAdapter(viewModel: sourceViewModel)
        self.initialWorldMapProgress = initialWorldMapProgress
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

    func setInputEnabled(_ enabled: Bool) {
        isInputEnabled = enabled
        cameraController.setInputEnabled(enabled)
    }

    func setWorldMapProgress(_ progress: Double, duration: Double) {
        cameraController.setWorldMapProgress(Float(progress), duration: duration)
        updatePacing()
    }

    /// Stops drawing while something else covers the town (the world map).
    func setActive(_ active: Bool) {
        isSceneActive = active
        updatePacing()
    }

    private func updatePacing() {
        renderView?.isPaused = isSceneActive == false || cameraController.isWorldMapCovered
    }

    func applyBuildingScales(_ scales: [BuildingKind: Float]) {
        guard scales != appliedBuildingScales else { return }
        appliedBuildingScales = scales
        renderer?.applyBuildingScales()
    }

    func syncFromGameState() {
        // Read the source before deferring, preserving SwiftUI's observation.
        let town = sourceViewModel.activeTown
        let gridSize = sourceViewModel.balance.gridSize
        let selection = sourceViewModel.selectedCoordinate
        let placement = sourceViewModel.placementBuildingKind
        let theme = WorldTheme.current
        let contrast = WorldContrast.level
        guard let renderer, cameraController.isInteracting == false,
              cameraController.isAtTown || renderedTown == nil else { return }
        let placementStock = placement == nil ? nil : sourceViewModel.spendingTown.resources
        let playerTownCount = placement == nil ? nil : sourceViewModel.playerTowns.count
        guard renderedTown?.id != town.id || renderedTown?.buildings != town.buildings
                || renderedTown?.biomeLayout != town.biomeLayout || renderedTown?.faction != town.faction
                || renderedTown?.soldierRoster != town.soldierRoster || renderedTown?.armyStrength != town.armyStrength
                || renderedGridSize != gridSize || renderedSelection != selection || renderedPlacement != placement
                || renderedPlacementStock != placementStock || renderedPlayerTownCount != playerTownCount
                || renderedTheme != theme || renderedContrast != contrast else { return }
        renderer.render(adapter: adapter)
        renderedTown = town
        renderedGridSize = gridSize
        renderedSelection = selection
        renderedPlacement = placement
        renderedTheme = theme
        renderedContrast = contrast
        renderedPlacementStock = placementStock
        renderedPlayerTownCount = playerTownCount
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
        cameraController.setWorldMapProgress(Float(initialWorldMapProgress), duration: 0)
        renderView.renderer.activeCamera = cameraController.camera
        renderView.onFrame = { [weak self] deltaTime in
            self?.cameraController.advance(by: deltaTime)
            self?.updatePacing()
        }
        cameraController.onInteractionEnded = { [weak self] in
            self?.syncFromGameState()
        }
        cameraController.onWorldMapTravelEnded = { [weak self] in
            self?.syncFromGameState()
        }
        self.renderer = renderer
        self.renderView = renderView

        let tap = NSClickGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        renderView.addGestureRecognizer(tap)
    }

    @objc private func handleTap(_ recognizer: NSClickGestureRecognizer) {
        guard isInputEnabled, let renderView, let renderer,
              let ray = renderView.ray(through: recognizer.location(in: renderView)),
              let coordinate = renderer.coordinate(along: ray) else { return }

        sourceViewModel.selectCell(coordinate)
        syncFromGameState()
    }
}
