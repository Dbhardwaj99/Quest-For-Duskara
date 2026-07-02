import RealityKit
import SwiftUI
import AppKit

struct World3DAssetGalleryView: View {
    @State private var selectedAsset = World3DAssetPreview.defaultAsset
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .bottom) {
            World3DAssetPreviewContainer(asset: selectedAsset)
                .ignoresSafeArea()

            VStack(spacing: 12) {
				HStack {
					close
					
					Spacer(minLength: 0)
				}
				
				Spacer(minLength: 0)
				
                assetHeader
                assetPicker
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 18)
        }
        .background(DuskaraTheme.worldBackdrop.ignoresSafeArea())
		.navigationBarBackButtonHidden()
        .navigationTitle("3D Assets")
    }

    private var assetHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: selectedAsset.systemImage)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 34, height: 34)
                .background(DuskaraTheme.warmGold, in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(selectedAsset.title)
                    .font(.headline.weight(.black))
                    .foregroundStyle(.white)
                Text(selectedAsset.category)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.68))
            }

            Spacer(minLength: 12)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.16), lineWidth: 1))
    }

	private var close: some View {
		Button(action: {
			dismiss()
		}) {
			Image(systemName: "xmark.circle.fill")
				.font(.title)
				.foregroundColor(.white)
		}
	}
	
    private var assetPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(World3DAssetPreview.allAssets) { asset in
                    Button {
                        selectedAsset = asset
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: asset.systemImage)
                                .font(.system(size: 16, weight: .bold))
                            Text(asset.shortTitle)
                                .font(.caption.weight(.bold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }
                        .foregroundStyle(selectedAsset == asset ? .black : .white)
                        .frame(width: 86, height: 58)
                        .background(selectedAsset == asset ? DuskaraTheme.warmGold : Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(selectedAsset == asset ? 0.20 : 0.14), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(asset.title)
                }
            }
            .padding(.horizontal, 2)
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.16), lineWidth: 1))
    }
}

private struct World3DAssetPreviewContainer: NSViewControllerRepresentable {
    let asset: World3DAssetPreview

    func makeNSViewController(context: Context) -> World3DAssetPreviewViewController {
        World3DAssetPreviewViewController(asset: asset)
    }

    func updateNSViewController(_ nsViewController: World3DAssetPreviewViewController, context: Context) {
        nsViewController.show(asset)
    }
}

struct World3DAssetPreview: Identifiable, Hashable {
    let id: String
    let title: String
    let shortTitle: String
    let category: String
    let systemImage: String
    let content: World3DTileSnapshot.Content
    let materialColor: NSColor

    static func == (lhs: World3DAssetPreview, rhs: World3DAssetPreview) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static let defaultAsset = World3DAssetPreview.tree

    static let allAssets: [World3DAssetPreview] = [
        .grass,
        .water,
        .tree,
        .mountain
    ] + BuildingKind.allCases.map { .building($0, level: 1) }

    static let grass = World3DAssetPreview(
        id: "grass",
        title: "Grass Tile",
        shortTitle: "Grass",
        category: "Terrain",
        systemImage: "leaf.fill",
        content: .grass,
        materialColor: NSColor(red: 0.31, green: 0.44, blue: 0.24, alpha: 1)
    )

    static let water = World3DAssetPreview(
        id: "water",
        title: "Water Tile",
        shortTitle: "Water",
        category: "Terrain",
        systemImage: "drop.fill",
        content: .water,
        materialColor: NSColor(red: 0.34, green: 0.56, blue: 0.68, alpha: 1)
    )

    static let tree = World3DAssetPreview(
        id: "tree",
        title: "Tree",
        shortTitle: "Tree",
        category: "Decoration",
        systemImage: "tree.fill",
        content: .tree,
        materialColor: NSColor(red: 0.27, green: 0.43, blue: 0.22, alpha: 1)
    )

    static let mountain = World3DAssetPreview(
        id: "mountain",
        title: "Mountain",
        shortTitle: "Mountain",
        category: "Decoration",
        systemImage: "mountain.2.fill",
        content: .mountain,
        materialColor: NSColor(red: 0.42, green: 0.40, blue: 0.34, alpha: 1)
    )

    static func building(_ kind: BuildingKind, level: Int) -> World3DAssetPreview {
        World3DAssetPreview(
            id: "building_\(kind.rawValue)_\(level)",
            title: "\(kind.title) L\(level)",
            shortTitle: kind.title,
            category: "Building",
            systemImage: iconName(for: kind),
            content: .building(kind, level: level),
            materialColor: NSColor(red: 0.41, green: 0.34, blue: 0.24, alpha: 1)
        )
    }

    private static func iconName(for kind: BuildingKind) -> String {
        switch kind {
        case .house: "house.fill"
        case .pier: "sailboat.fill"
        case .farm: "carrot.fill"
        case .factory: "flask.fill"
        case .barracks: "shield.lefthalf.filled"
        }
    }
}

@MainActor
private final class World3DAssetPreviewViewController: NSViewController, NSGestureRecognizerDelegate {
    private let arView = ARView(frame: .zero)
    private let anchor = AnchorEntity(world: .zero)
    private let previewRoot = Entity()
    private let camera = PerspectiveCamera()

    private var currentAsset: World3DAssetPreview
    private var yaw: Float = -.pi / 6
    private var pitch: Float = 0.20
    private var scale: Float = 1.0
    private var startYaw: Float = -.pi / 6
    private var startPitch: Float = 0.20
    private var startScale: Float = 1.0

    init(asset: World3DAssetPreview) {
        self.currentAsset = asset
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
        configureGestures()
        show(currentAsset)
    }

    func show(_ asset: World3DAssetPreview) {
        guard isViewLoaded else {
            currentAsset = asset
            return
        }
        guard asset != currentAsset || previewRoot.children.isEmpty else { return }

        currentAsset = asset
        previewRoot.children.forEach { $0.removeFromParent() }

        let snapshot = World3DTileSnapshot(
            coordinate: GridCoordinate(x: 2, y: 3),
            content: asset.content,
            placementState: .normal
        )
        // The preview coordinate sits on the bottom edge of this grid so
        // edge-oriented buildings (the pier) face the camera.
        let entity = World3DTileEntity.makeTile(
            snapshot: snapshot,
            tileSize: 1.0,
            tileHeight: 0.13,
            material: SimpleMaterial(color: asset.materialColor, roughness: 0.86, isMetallic: false),
            gridSize: GridSize(columns: 5, rows: 4)
        )
        entity.position.y = -0.04
        previewRoot.addChild(entity)
        updatePreviewTransform()
    }

    private func configureScene() {
        arView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(arView)

        NSLayoutConstraint.activate([
            arView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            arView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            arView.topAnchor.constraint(equalTo: view.topAnchor),
            arView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        arView.environment.background = .color(NSColor(red: 0.10, green: 0.13, blue: 0.12, alpha: 1))

        let sun = DirectionalLight()
        sun.light.intensity = 4200
        sun.light.color = NSColor(red: 1.0, green: 0.82, blue: 0.58, alpha: 1)
        sun.orientation = simd_quatf(angle: -.pi / 4.6, axis: SIMD3<Float>(1, 0, 0)) * simd_quatf(angle: .pi / 5, axis: SIMD3<Float>(0, 1, 0))
        anchor.addChild(sun)

        let fill = PointLight()
        fill.light.intensity = 720
        fill.light.color = NSColor(red: 0.56, green: 0.66, blue: 0.78, alpha: 1)
        fill.position = SIMD3<Float>(-2.2, 2.3, 2.0)
        anchor.addChild(fill)

        let base = ModelEntity(
            mesh: .generateBox(size: SIMD3<Float>(1.42, 0.10, 1.42), cornerRadius: 0.16),
            materials: [SimpleMaterial(color: NSColor(red: 0.18, green: 0.16, blue: 0.12, alpha: 1), roughness: 0.95, isMetallic: false)]
        )
        base.position.y = -0.16
        anchor.addChild(base)

        camera.camera = PerspectiveCameraComponent(near: 0.01, far: 18, fieldOfViewInDegrees: 36)
        camera.look(at: SIMD3<Float>(0, 0.22, 0), from: SIMD3<Float>(1.35, 1.05, 1.55), relativeTo: nil)
        anchor.addChild(camera)

        anchor.addChild(previewRoot)
        arView.scene.anchors.append(anchor)
    }

    private func configureGestures() {
        let pan = NSPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.delegate = self
        arView.addGestureRecognizer(pan)

        let pinch = NSMagnificationGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        pinch.delegate = self
        arView.addGestureRecognizer(pinch)
    }

    @objc private func handlePan(_ recognizer: NSPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            startYaw = yaw
            startPitch = pitch
        case .changed:
            let translation = recognizer.translation(in: arView)
            yaw = startYaw + Float(translation.x) * 0.009
            pitch = min(0.72, max(-0.34, startPitch + Float(translation.y) * 0.006))
            updatePreviewTransform()
        default:
            break
        }
    }

    @objc private func handlePinch(_ recognizer: NSMagnificationGestureRecognizer) {
        switch recognizer.state {
        case .began:
            startScale = scale
        case .changed:
            scale = min(1.85, max(0.43, startScale * Float(1 + recognizer.magnification)))
            updatePreviewTransform()
        default:
            break
        }
    }

    func gestureRecognizer(_ gestureRecognizer: NSGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: NSGestureRecognizer) -> Bool {
        true
    }

    private func updatePreviewTransform() {
        previewRoot.scale = SIMD3<Float>(repeating: scale)
        previewRoot.orientation = simd_quatf(angle: yaw, axis: SIMD3<Float>(0, 1, 0)) * simd_quatf(angle: pitch, axis: SIMD3<Float>(1, 0, 0))
    }
}

#Preview {
    NavigationStack {
        World3DAssetGalleryView()
    }
}
