import RealityKit
import UIKit

private enum World3DInteractionTool: Equatable {
    case select
    case build(BuildingKind)
    case decorate(World3DDecorationKind)
    case clearDecoration
}

@MainActor
final class World3DGameViewController: UIViewController {
    private let sourceViewModel: GameViewModel
    private var adapter: World3DStateAdapter
    private var renderer: World3DRenderer?
    private let cameraController = World3DCameraController()

    private var activeTool: World3DInteractionTool = .select
    private var selectedBuildingKind: BuildingKind = .house
    private var selectedDecorationKind: World3DDecorationKind = .tree

    private let statusLabel = UILabel()
    private let segmentedControl = UISegmentedControl(items: ["Select", "Build", "Decor", "Clear"])
    private let buildingButton = UIButton(type: .system)
    private let decorationButton = UIButton(type: .system)
    private let upgradeButton = UIButton(type: .system)

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
        configureOverlay()
        renderAndRefreshStatus("3D town ready")
    }

    func syncFromGameState() {
        renderer?.render(adapter: adapter)
        refreshControls()
    }

    private func configureScene() {
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

    private func configureOverlay() {
        view.backgroundColor = .black

        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = .white
        closeButton.backgroundColor = UIColor.black.withAlphaComponent(0.34)
        closeButton.layer.cornerRadius = 19
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(closeButton)

        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.backgroundColor = UIColor.black.withAlphaComponent(0.50)
        segmentedControl.selectedSegmentTintColor = UIColor.systemYellow.withAlphaComponent(0.92)
        segmentedControl.addTarget(self, action: #selector(toolChanged(_:)), for: .valueChanged)
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(segmentedControl)

        configureMenuButton(buildingButton)
        configureMenuButton(decorationButton)
        configureUpgradeButton()

        view.addSubview(buildingButton)
        view.addSubview(decorationButton)
        view.addSubview(upgradeButton)

        statusLabel.textColor = .white
        statusLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        statusLabel.numberOfLines = 3
        statusLabel.textAlignment = .center
        statusLabel.backgroundColor = UIColor.black.withAlphaComponent(0.52)
        statusLabel.layer.cornerRadius = 8
        statusLabel.layer.masksToBounds = true
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            closeButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -14),
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            closeButton.widthAnchor.constraint(equalToConstant: 38),
            closeButton.heightAnchor.constraint(equalToConstant: 38),

            segmentedControl.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 14),
            segmentedControl.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -12),
            segmentedControl.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),

            buildingButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 14),
            buildingButton.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 10),
            buildingButton.widthAnchor.constraint(equalToConstant: 150),
            buildingButton.heightAnchor.constraint(equalToConstant: 38),

            decorationButton.leadingAnchor.constraint(equalTo: buildingButton.trailingAnchor, constant: 10),
            decorationButton.centerYAnchor.constraint(equalTo: buildingButton.centerYAnchor),
            decorationButton.widthAnchor.constraint(equalToConstant: 130),
            decorationButton.heightAnchor.constraint(equalToConstant: 38),

            upgradeButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -14),
            upgradeButton.centerYAnchor.constraint(equalTo: buildingButton.centerYAnchor),
            upgradeButton.widthAnchor.constraint(equalToConstant: 128),
            upgradeButton.heightAnchor.constraint(equalToConstant: 38),

            statusLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 14),
            statusLabel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -14),
            statusLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -14),
            statusLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 54)
        ])

        rebuildMenus()
        refreshControls()
    }

    private func configureMenuButton(_ button: UIButton) {
        button.tintColor = .white
        button.backgroundColor = UIColor.black.withAlphaComponent(0.54)
        button.layer.cornerRadius = 8
        button.titleLabel?.font = .systemFont(ofSize: 13, weight: .bold)
        button.showsMenuAsPrimaryAction = true
        button.translatesAutoresizingMaskIntoConstraints = false
    }

    private func configureUpgradeButton() {
        upgradeButton.setTitle("Upgrade", for: .normal)
        upgradeButton.setImage(UIImage(systemName: "arrow.up.circle.fill"), for: .normal)
        upgradeButton.tintColor = .black
        upgradeButton.backgroundColor = UIColor.systemYellow.withAlphaComponent(0.94)
        upgradeButton.layer.cornerRadius = 8
        upgradeButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .bold)
        upgradeButton.addTarget(self, action: #selector(upgradeTapped), for: .touchUpInside)
        upgradeButton.translatesAutoresizingMaskIntoConstraints = false
    }

    private func rebuildMenus() {
        buildingButton.menu = UIMenu(children: BuildingKind.allCases.map { kind in
            UIAction(title: kind.title, image: UIImage(systemName: "plus.square.fill")) { [weak self] _ in
                self?.selectBuildingKind(kind)
            }
        })
        decorationButton.menu = UIMenu(children: World3DDecorationKind.allCases.map { kind in
            UIAction(title: kind.title, image: UIImage(systemName: kind == .tree ? "tree.fill" : "mountain.2.fill")) { [weak self] _ in
                self?.selectDecorationKind(kind)
            }
        })
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard let arView = recognizer.view as? ARView, let renderer else { return }
        let location = recognizer.location(in: arView)
        guard let coordinate = renderer.coordinate(for: arView.entity(at: location)) else { return }

        switch activeTool {
        case .select:
            sourceViewModel.selectCell(coordinate)
            renderAndRefreshStatus(statusForSelection(at: coordinate))
        case .build(let kind):
            if sourceViewModel.placementBuildingKind != kind {
                sourceViewModel.beginPlacement(for: kind)
            }
            sourceViewModel.selectCell(coordinate)
            renderAndRefreshStatus("Build action at \(coordinate.x), \(coordinate.y)")
        case .decorate(let decoration):
            sourceViewModel.selectCell(coordinate)
            let message = adapter.placeDecoration(decoration, at: coordinate)
            renderAndRefreshStatus(message)
        case .clearDecoration:
            sourceViewModel.selectCell(coordinate)
            let message = adapter.clearDecoration(at: coordinate)
            renderAndRefreshStatus(message)
        }
    }

    @objc private func toolChanged(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 1:
            activeTool = .build(selectedBuildingKind)
            sourceViewModel.beginPlacement(for: selectedBuildingKind)
        case 2:
            cancelLivePlacementIfNeeded()
            activeTool = .decorate(selectedDecorationKind)
        case 3:
            cancelLivePlacementIfNeeded()
            activeTool = .clearDecoration
        default:
            cancelLivePlacementIfNeeded()
            activeTool = .select
        }
        renderAndRefreshStatus(labelForActiveTool())
    }

    @objc private func upgradeTapped() {
        guard sourceViewModel.selectedBuilding != nil else { return }
        sourceViewModel.upgradeSelectedBuilding()
        renderAndRefreshStatus("Upgrade requested")
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    private func selectBuildingKind(_ kind: BuildingKind) {
        selectedBuildingKind = kind
        activeTool = .build(kind)
        segmentedControl.selectedSegmentIndex = 1
        sourceViewModel.beginPlacement(for: kind)
        renderAndRefreshStatus("Build: \(kind.title)")
    }

    private func selectDecorationKind(_ kind: World3DDecorationKind) {
        selectedDecorationKind = kind
        activeTool = .decorate(kind)
        segmentedControl.selectedSegmentIndex = 2
        cancelLivePlacementIfNeeded()
        renderAndRefreshStatus("Decor: \(kind.title)")
    }

    private func cancelLivePlacementIfNeeded() {
        if sourceViewModel.placementBuildingKind != nil {
            sourceViewModel.cancelPlacement()
        }
    }

    private func renderAndRefreshStatus(_ text: String) {
        renderer?.render(adapter: adapter)
        refreshControls(status: text)
    }

    private func refreshControls(status: String? = nil) {
        buildingButton.setTitle("  \(selectedBuildingKind.title)", for: .normal)
        decorationButton.setTitle("  \(selectedDecorationKind.title)", for: .normal)
        buildingButton.isHidden = segmentedControl.selectedSegmentIndex != 1
        decorationButton.isHidden = segmentedControl.selectedSegmentIndex != 2

        let canUpgrade = sourceViewModel.selectedBuilding.map(sourceViewModel.canUpgrade) ?? false
        upgradeButton.isHidden = sourceViewModel.selectedBuilding == nil || activeTool != .select
        upgradeButton.isEnabled = canUpgrade
        upgradeButton.alpha = canUpgrade ? 1 : 0.55

        let headline = status ?? labelForActiveTool()
        let resources = ResourceKind.allCases
            .map { "\($0.title): \(sourceViewModel.activeTown.resources[$0])" }
            .joined(separator: "  ")
        statusLabel.text = "\(headline)\nDay \(sourceViewModel.state.day)  Free People: \(sourceViewModel.freePeople)/\(sourceViewModel.populationCapacity)\n\(resources)"
    }

    private func statusForSelection(at coordinate: GridCoordinate) -> String {
        if let building = sourceViewModel.selectedBuilding {
            return "Selected \(building.kind.title) L\(building.level) at \(coordinate.x), \(coordinate.y)"
        }
        return "Selected plot \(coordinate.x), \(coordinate.y)"
    }

    private func labelForActiveTool() -> String {
        switch activeTool {
        case .select:
            return "Select tiles and buildings"
        case .build(let kind):
            return "Build: \(kind.title)"
        case .decorate(let kind):
            return "Decor: \(kind.title)"
        case .clearDecoration:
            return "Clear decorations"
        }
    }
}
