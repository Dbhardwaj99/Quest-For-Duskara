import SpriteKit

final class UnitSpriteNode: SKSpriteNode {
    let kind: SoldierKind
    let side: LaneBattle.Side
    private let sprites: BattleSprites
    private let health = SKSpriteNode(texture: BattleSprites.pixel, color: .systemGreen, size: CGSize(width: 24, height: 3))
    private var state = ""
    private var desired = "idle"
    private(set) var isDying = false

    init(unit: LaneBattle.Unit, sprites: BattleSprites) {
        kind = unit.kind
        side = unit.side
        self.sprites = sprites
        super.init(texture: nil, color: .white, size: CGSize(width: 96, height: 96))
        anchorPoint = CGPoint(x: 0.5, y: 0.18)
        let shadow = SKSpriteNode(texture: sprites.effect("blob_shadow"), size: CGSize(width: 44, height: 16))
        shadow.position.y = -2
        shadow.zPosition = -1
        addChild(shadow)
        health.anchorPoint = CGPoint(x: 0, y: 0.5)
        health.colorBlendFactor = 1
        health.position = CGPoint(x: -12, y: 76)
        addChild(health)
        animate("idle")
    }
    required init?(coder: NSCoder) { fatalError() }

    func sync(_ unit: LaneBattle.Unit, at point: CGPoint) {
        desired = hypot(position.x - point.x, position.y - point.y) > 0.001 ? "walk" : "idle"
        position = point
        health.xScale = CGFloat(max(0, unit.health / LaneBattle.stats(kind).health))
        if state != "attack", !isDying { animate(desired) }
    }

    func strike() { if !isDying { animate("attack") } }
    func die() {
        guard !isDying else { return }
        isDying = true
        health.isHidden = true
        animate("death")
    }

    private func animate(_ next: String) {
        guard next != state else { return }
        state = next
        removeAction(forKey: "animation")
        let frames = sprites.animation(kind, side: side, state: next)
        guard !frames.isEmpty else { return }
        texture = frames[0]
        let action = SKAction.animate(with: frames, timePerFrame: 1.0 / 12)
        if next == "death" {
            run(.sequence([action, .fadeOut(withDuration: 0.4), .removeFromParent()]), withKey: "animation")
        } else if next == "attack" {
            run(.sequence([action, .run { [weak self] in self?.animate(self?.desired ?? "idle") }]), withKey: "animation")
        } else {
            run(.repeatForever(action), withKey: "animation")
        }
    }
}
