import AVFoundation
import SwiftUI

/// The homescreen loop, blurred, behind the menu and difficulty screens. Shared
/// by both so they read as one continuous shot rather than two backdrops.
struct HomeBackgroundView: View {
    var body: some View {
        ZStack {
            // Still the ground beneath: if the video is missing from the bundle
            // or fails to load, these screens keep their original gradient
            // rather than falling through to black.
            DuskaraTheme.background

            // The backdrop encode, not the master: it only ever shows blurred, so
            // it ships at 960x540 / ~1 Mbps instead of the source's 1080p60.
            LoopingVideoView(resource: "homescreen-bg", extension: "mp4", blurRadius: 10)

            // The hero text and panels are white-on-anything, so a scrim rather
            // than trusting whichever frame happens to be on screen.
            Color.black.opacity(0.45)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

/// Blur lives on the player layer as a Core Image filter, not SwiftUI's
/// `.blur` — that modifier does not reach into an AppKit-hosted layer tree.
private struct LoopingVideoView: NSViewRepresentable {
    let resource: String
    let `extension`: String
    let blurRadius: Double

    func makeNSView(context: Context) -> LoopingVideoNSView {
        LoopingVideoNSView(resource: resource, extension: `extension`, blurRadius: blurRadius)
    }

    func updateNSView(_ nsView: LoopingVideoNSView, context: Context) {}

    static func dismantleNSView(_ nsView: LoopingVideoNSView, coordinator: ()) {
        nsView.stop()
    }
}

final class LoopingVideoNSView: NSView {
    private let playerLayer = AVPlayerLayer()
    private let player = AVQueuePlayer()
    private var looper: AVPlayerLooper?
    /// A gaussian blur samples past the edges and returns transparent there, so
    /// the layer is drawn oversized and the soft border falls outside the view.
    private let overscan: CGFloat

    init(resource: String, extension fileExtension: String, blurRadius: Double) {
        overscan = CGFloat(blurRadius) * 3
        super.init(frame: .zero)

        wantsLayer = true
        layerUsesCoreImageFilters = true
        layer = CALayer()
        layer?.masksToBounds = true

        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspectFill
        if let blur = CIFilter(name: "CIGaussianBlur", parameters: [kCIInputRadiusKey: blurRadius]) {
            playerLayer.filters = [blur]
        }
        layer?.addSublayer(playerLayer)

        guard let url = Bundle.main.url(forResource: resource, withExtension: fileExtension) else { return }
        let item = AVPlayerItem(url: url)
        // Ambient background: never audible, and never the reason a game's
        // audio session gets taken over.
        player.isMuted = true
        player.actionAtItemEnd = .advance
        looper = AVPlayerLooper(player: player, templateItem: item)
        player.play()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        // Frame changes are implicitly animated on a layer-backed view, which
        // makes a live resize lag behind the window.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        playerLayer.frame = bounds.insetBy(dx: -overscan, dy: -overscan)
        CATransaction.commit()
    }

    // Decoding a 4K loop nobody can see is pure battery, and the window can be
    // hidden without this view being torn down.
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window == nil ? player.pause() : player.play()
    }

    func stop() {
        player.pause()
        player.removeAllItems()
        looper = nil
    }
}
