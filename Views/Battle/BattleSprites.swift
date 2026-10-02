import SpriteKit
import AppKit

final class BattleSprites {
    private let atlases = ["BattleKnight", "BattleArcher", "BattleFX"].map(SKTextureAtlas.init(named:))
    private var frames: [String: [SKTexture]] = [:]
    private var effects: [String: SKTexture] = [:]
    static let pixel: SKTexture = {
        let image = NSImage(size: CGSize(width: 2, height: 2))
        image.lockFocus()
        NSColor.white.setFill()
        CGRect(x: 0, y: 0, width: 2, height: 2).fill()
        image.unlockFocus()
        return SKTexture(image: image)
    }()

    func preload(completion: @escaping () -> Void) {
        SKTextureAtlas.preloadTextureAtlases(atlases) { [weak self] in
            DispatchQueue.main.async {
                guard let self else { return }
                for (index, kind) in [SoldierKind.knight, .archer].enumerated() {
                    for team in ["blue", "red"] {
                        for (animation, count) in [("idle", 4), ("walk", 8), ("attack", 6), ("death", 6)] {
                            let key = "\(kind.rawValue)_\(team)_\(animation)"
                            self.frames[key] = (0..<count).map { self.atlases[index].textureNamed(String(format: "%@_%02d", key, $0)) }
                        }
                    }
                }
                for name in ["arrow", "blob_shadow"] + (0..<4).map({ String(format: "dust_%02d", $0) }) + (0..<3).map({ String(format: "hit_%02d", $0) }) {
                    self.effects[name] = self.atlases[2].textureNamed(name)
                }
                completion()
            }
        }
    }

    func animation(_ kind: SoldierKind, side: LaneBattle.Side, state: String) -> [SKTexture] {
        frames["\(kind.rawValue)_\(side == .attacker ? "blue" : "red")_\(state)"] ?? []
    }
    func effect(_ name: String) -> SKTexture { effects[name] ?? Self.pixel }
    func portrait(_ kind: SoldierKind, side: LaneBattle.Side) -> NSImage? {
        NSImage(named: "\(kind.rawValue)_\(side == .attacker ? "blue" : "red")_portrait")
    }
}

/// A fixed pool bounds the effects budget even during crowded fights.
final class BattleEffects: SKNode {
    private let sprites: BattleSprites
    private let pool: [SKSpriteNode] = (0..<24).map { _ in SKSpriteNode() }

    init(sprites: BattleSprites) {
        self.sprites = sprites
        super.init()
        for node in pool { node.isHidden = true; addChild(node) }
    }
    required init?(coder: NSCoder) { fatalError() }

    func puff(_ name: String, at point: CGPoint) {
        guard let node = pool.first(where: \.isHidden) else { return }
        node.isHidden = false
        node.alpha = 1
        node.zRotation = 0
        node.position = point
        node.zPosition = 1000 - point.y
        let count = name == "dust" ? 4 : 3
        let frames = (0..<count).map { sprites.effect(String(format: "%@_%02d", name, $0)) }
        node.size = CGSize(width: name == "dust" ? 48 : 32, height: name == "dust" ? 48 : 32)
        node.run(.sequence([.animate(with: frames, timePerFrame: 1.0 / 12), .fadeOut(withDuration: 0.15), .run { [weak node] in node?.isHidden = true }]))
    }

    func arrow(from: CGPoint, to: CGPoint) {
        guard let node = pool.first(where: \.isHidden) else { return }
        node.isHidden = false
        node.alpha = 1
        node.texture = sprites.effect("arrow")
        node.size = CGSize(width: 32, height: 8)
        node.zPosition = 1200
        let dx = to.x - from.x, dy = to.y - from.y, height: CGFloat = 0.6 * 64
        node.run(.sequence([.customAction(withDuration: 0.25) { node, elapsed in
            let t = min(1, elapsed / 0.25)
            node.position = CGPoint(x: from.x + dx * t, y: from.y + dy * t + 4 * height * t * (1 - t))
            node.zRotation = atan2(dy + 4 * height * (1 - 2 * t), dx)
        }, .run { [weak node] in node?.isHidden = true }]))
    }
}
