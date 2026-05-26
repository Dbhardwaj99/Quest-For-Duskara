import RealityKit
import UIKit

@MainActor
final class World3DTestViewController: UIViewController {
    private let sourceViewModel: GameViewModel
    private var adapter: World3DStateAdapter
    private var renderer: World3DRenderer?
    private let cameraController = World3DCameraController()

    private var selectedCoordinate: GridCoordinate?
    private var activeTool: World3DPlacementTool?

    private let statusLabel = UILabel()
    private let segmentedControl = UISegmentedControl(items: ["Select", "Building", "Tree", "Mountain", "Clear"])

    init(sourceViewModel: GameViewModel) {
        self.sourceViewModel = sourceViewModel
        self.adapter = World3DStateAdapter(sourceViewModel: sourceViewModel)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureScene()
        configureOverlay()
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
        renderer.render(adapter: adapter)
        cameraController.install(in: arView)
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

        statusLabel.text = "3D World Prototype"
        statusLabel.textColor = .white
        statusLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        statusLabel.numberOfLines = 2
        statusLabel.textAlignment = .center
        statusLabel.backgroundColor = UIColor.black.withAlphaComponent(0.48)
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

            statusLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 14),
            statusLabel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -14),
            statusLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -14),
            statusLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 42)
        ])
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard let arView = recognizer.view as? ARView, let renderer else { return }
        let location = recognizer.location(in: arView)
        guard let coordinate = renderer.coordinate(for: arView.entity(at: location)) else { return }

        selectedCoordinate = coordinate
        renderer.select(coordinate)

        if let activeTool {
            let message = adapter.apply(activeTool, at: coordinate)
            renderer.render(adapter: adapter)
            renderer.select(coordinate)
            updateStatus(message)
        } else {
            updateStatus("Selected \(coordinate.x), \(coordinate.y)")
        }
    }

    @objc private func toolChanged(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 1:
            activeTool = .building
        case 2:
            activeTool = .tree
        case 3:
            activeTool = .mountain
        case 4:
            activeTool = .clear
        default:
            activeTool = nil
        }
        updateStatus(activeTool.map { "Tool: \($0.title)" } ?? "Select tiles")
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    private func updateStatus(_ text: String) {
        if let selectedCoordinate {
            statusLabel.text = "\(text) · Selected \(selectedCoordinate.x), \(selectedCoordinate.y)"
        } else {
            statusLabel.text = text
        }
    }
}
