import RealityKit
import AppKit
// CAMetalDrawable isn't marked Sendable, but present() is thread-safe; it's
// called from RealityRenderer's scheduled handler.
@preconcurrency import QuartzCore
import Metal

/// Draws the RealityKit scene with `RealityRenderer` into our own Metal layer.
///
/// ARView on macOS renders on every display refresh — 120 Hz on ProMotion —
/// and offers no way to slow down, which kept the GPU pinned and the Mac hot.
/// Here a display link paces frames: 60 fps at most, 30 while the app is in
/// the background, none while the view is hidden, covered, or paused.
@MainActor
final class World3DRenderView: NSView {
    let renderer: RealityRenderer
    /// Runs once per frame, before the simulation steps; drives the camera.
    var onFrame: ((Float) -> Void)?
    /// Set while something else covers the scene (the world map).
    var isPaused = false {
        didSet {
            if isPaused != oldValue { updatePacing() }
        }
    }

    private let metalLayer = CAMetalLayer()
    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval?
    private var observers: [NSObjectProtocol] = []
    private var fpsFrameCount = 0
    private var fpsWindowStart: CFTimeInterval = 0

    init(renderer: RealityRenderer) {
        self.renderer = renderer
        super.init(frame: .zero)
        wantsLayer = true
        // Match ARView's image: its studio lighting, 4x MSAA, tone mapping
        // (on by default), and a Display P3 layer.
        renderer.cameraSettings.antialiasing = .multisample4X
        if let studio = Self.studioLighting {
            renderer.lighting.resource = studio.resource
            renderer.lighting.intensityExponent = studio.intensityExponent
        } else {
            debugPrint("World3D: ARView studio lighting unavailable; scene will render darker")
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// ARView's built-in image-based light. Without it the scene goes dark
    /// with hard black shadows.
    // ponytail: borrowed through ARView's `__environmentEntity` SPI; if a macOS
    // update drops it, ship our own EnvironmentResource instead.
    private static let studioLighting: (resource: EnvironmentResource, intensityExponent: Float)? = {
        guard let light = ARView(frame: .zero).__environmentEntity?.components[ImageBasedLightComponent.self],
              case .single(let resource) = light.source else { return nil }
        return (resource, light.intensityExponent)
    }()

    override func makeBackingLayer() -> CALayer {
        metalLayer.device = MTLCreateSystemDefaultDevice()
        metalLayer.pixelFormat = .bgra8Unorm_srgb
        metalLayer.colorspace = CGColorSpace(name: CGColorSpace.displayP3)
        // RealityRenderer's post pass may sample the target, not just draw to it.
        metalLayer.framebufferOnly = false
        return metalLayer
    }

    override func layout() {
        super.layout()
        updateDrawableSize()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        updateDrawableSize()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        displayLink?.invalidate()
        displayLink = nil
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
        guard let window else { return }

        let link = displayLink(target: self, selector: #selector(step(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
        let center = NotificationCenter.default
        for (name, object) in [
            (NSWindow.didChangeOcclusionStateNotification, window as AnyObject?),
            (NSApplication.didBecomeActiveNotification, nil),
            (NSApplication.didResignActiveNotification, nil)
        ] {
            observers.append(center.addObserver(forName: name, object: object, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.updatePacing() }
            })
        }
        updateDrawableSize()
        updatePacing()
    }

    /// World-space ray through a point in this view's coordinates, the
    /// replacement for ARView's hit testing.
    func ray(through point: CGPoint) -> (origin: SIMD3<Float>, direction: SIMD3<Float>)? {
        guard let camera = renderer.activeCamera,
              let lens = camera.components[PerspectiveCameraComponent.self],
              bounds.width > 0, bounds.height > 0 else { return nil }
        // Unflipped view: y already points up, like camera space.
        let ndc = SIMD2<Float>(Float(point.x / bounds.width) * 2 - 1, Float(point.y / bounds.height) * 2 - 1)
        let aspect = Float(bounds.width / bounds.height)
        let tanHalf = tan(lens.fieldOfViewInDegrees * .pi / 360)
        let scale = lens.fieldOfViewOrientation == .vertical
            ? SIMD2<Float>(tanHalf * aspect, tanHalf)
            : SIMD2<Float>(tanHalf, tanHalf / aspect)
        let transform = camera.transformMatrix(relativeTo: nil)
        let direction = transform * SIMD4<Float>(ndc.x * scale.x, ndc.y * scale.y, -1, 0)
        let origin = transform.columns.3
        return (SIMD3(origin.x, origin.y, origin.z), simd_normalize(SIMD3(direction.x, direction.y, direction.z)))
    }

    private func updateDrawableSize() {
        let scale = window?.backingScaleFactor ?? 2
        metalLayer.contentsScale = scale
        let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
        if metalLayer.drawableSize != size {
            metalLayer.drawableSize = size
        }
    }

    private func updatePacing() {
        guard let displayLink, let window else { return }
        let hidden = isPaused || window.occlusionState.contains(.visible) == false
        displayLink.isPaused = hidden
        if hidden {
            // Don't count the time away as one giant frame.
            lastTimestamp = nil
            return
        }
        let fps: Float = NSApp.isActive ? 60 : 30
        displayLink.preferredFrameRateRange = CAFrameRateRange(minimum: fps, maximum: fps, preferred: fps)
    }

    @objc private func step(_ link: CADisplayLink) {
        let now = link.targetTimestamp
        let deltaTime = lastTimestamp.map { min(now - $0, 0.1) } ?? 1.0 / 60
        lastTimestamp = now
        onFrame?(Float(deltaTime))

        guard metalLayer.drawableSize.width > 0, let drawable = metalLayer.nextDrawable() else { return }
        do {
            let output = try RealityRenderer.CameraOutput(.singleProjection(colorTexture: drawable.texture))
            // Presenting once scheduled is what MTLCommandBuffer.present does.
            try renderer.updateAndRender(deltaTime: deltaTime, cameraOutput: output, whenScheduled: { _ in
                drawable.present()
            })
        } catch {
            debugPrint("World3D: render failed:", error)
        }
        countFrame(at: link.timestamp)
    }

    private func countFrame(at time: CFTimeInterval) {
        fpsFrameCount += 1
        guard time - fpsWindowStart >= 2 else { return }
        if fpsWindowStart > 0 {
            World3DDiagnostics.recordFPS(Double(fpsFrameCount) / (time - fpsWindowStart))
        }
        fpsFrameCount = 0
        fpsWindowStart = time
    }
}
