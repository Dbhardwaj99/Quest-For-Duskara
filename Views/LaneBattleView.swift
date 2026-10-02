import SpriteKit
import SwiftUI

/// Full-screen lane assault. SpriteKit draws the field on its own 60 fps
/// clock; the SwiftUI controls only change when the player clicks, so the
/// battle never re-renders the window.
struct LaneBattleView: View {
    let battle: LaneBattle
    let attackerName: String
    let targetName: String
    let onFinish: (LaneBattle) -> Void
    @State private var scene: LaneBattleScene?
    @State private var selected: SoldierKind = .knight
    @State private var reserve = SoldierRoster()

    var body: some View {
        ZStack {
            DuskaraTheme.panelDark.ignoresSafeArea()
            if let scene {
                SpriteView(scene: scene, preferredFramesPerSecond: 60)
                    .ignoresSafeArea()
            }
            VStack {
                header
                Spacer()
                controls
            }
            .padding(14)
        }
        .onAppear {
            guard scene == nil else { return }
            let scene = LaneBattleScene(battle: battle)
            scene.onFinish = onFinish
            scene.onDeploy = { reserve = $0 }
            scene.selected = selected
            reserve = battle.attackerReserve
            self.scene = scene
        }
        .onChange(of: selected) { scene?.selected = selected }
    }

    private var header: some View {
        VStack(spacing: 2) {
            Text("Assault on \(targetName)")
                .font(DuskaraTheme.Fonts.title)
            Text("Click a lane to land the selected unit from \(attackerName). Break the gate before time runs out.")
                .font(DuskaraTheme.Fonts.body)
                .foregroundStyle(DuskaraTheme.mutedInk)
        }
        .foregroundStyle(DuskaraTheme.ink)
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .background(DuskaraTheme.hudFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .allowsHitTesting(false)
    }

    private var controls: some View {
        HStack(spacing: 10) {
            unitButton(.knight, key: "k")
            unitButton(.archer, key: "a")
            Spacer(minLength: 20)
            Button("Withdraw", systemImage: "flag.fill") { scene?.withdraw() }
                .buttonStyle(DuskaraButtonStyle())
                .keyboardShortcut(.cancelAction)
                .frame(width: 150)
        }
        .frame(maxWidth: 620)
    }

    private func unitButton(_ kind: SoldierKind, key: KeyEquivalent) -> some View {
        let stats = LaneBattle.stats(kind)
        return Button {
            selected = kind
        } label: {
            Text("\(kind.title) ×\(reserve[kind]) · \(Int(stats.cost)) cmd")
        }
        .buttonStyle(DuskaraButtonStyle(prominent: selected == kind))
        .keyboardShortcut(key, modifiers: [])
        .disabled(reserve[kind] == 0)
        .frame(width: 190)
        .accessibilityHint("Selects \(kind.title) for the next landing. Shortcut \(String(key.character).uppercased()).")
    }
}

final class LaneBattleScene: SKScene {
    private(set) var battle: LaneBattle
    var selected: SoldierKind = .knight
    var onFinish: ((LaneBattle) -> Void)?
    var onDeploy: ((SoldierRoster) -> Void)?

    private let field = SKNode()
    private let unitLayer = SKNode()
    private let effects = SKNode()
    private let gate = SKShapeNode()
    private let gateBar = SKSpriteNode(color: .systemRed, size: .zero)
    private let commandBar = SKSpriteNode(color: .systemYellow, size: .zero)
    private let commandFrame = SKShapeNode()
    private let clockLabel = SKLabelNode(fontNamed: "AvenirNextCondensed-Bold")
    private let commandLabel = SKLabelNode(fontNamed: "AvenirNextCondensed-DemiBold")
    private let banner = SKLabelNode(fontNamed: "AvenirNextCondensed-Heavy")
    private var unitNodes: [Int: SKNode] = [:]
    private var lastUpdate: TimeInterval?
    private var finished = false

    private static let attackerColor = NSColor(red: 0.36, green: 0.62, blue: 0.95, alpha: 1)
    private static let defenderColor = NSColor(red: 0.90, green: 0.36, blue: 0.30, alpha: 1)

    init(battle: LaneBattle) {
        self.battle = battle
        super.init(size: CGSize(width: 1200, height: 800))
        scaleMode = .resizeFill
        backgroundColor = NSColor(red: 0.10, green: 0.08, blue: 0.06, alpha: 1)
        for node in [field, unitLayer, effects] { addChild(node) }
        for node: SKNode in [gate, gateBar, commandFrame, commandBar, clockLabel, commandLabel, banner] { addChild(node) }
        clockLabel.fontSize = 22
        commandLabel.fontSize = 14
        commandLabel.horizontalAlignmentMode = .left
        clockLabel.horizontalAlignmentMode = .right
        commandBar.anchorPoint = CGPoint(x: 0, y: 0.5)
        gateBar.anchorPoint = CGPoint(x: 0.5, y: 0)
        banner.fontSize = 56
        banner.zPosition = 10
        banner.isHidden = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func withdraw() {
        battle.withdraw()
    }

    // MARK: Layout

    /// The battlefield: shore on the left, gate on the right, with room left
    /// for the SwiftUI header above and controls below.
    private var fieldRect: CGRect {
        CGRect(x: 70, y: 90, width: max(200, size.width - 190), height: max(150, size.height - 220))
    }

    private var laneHeight: CGFloat { fieldRect.height / CGFloat(LaneBattle.lanes) }

    private func point(lane: Int, position: Double, id: Int = 0) -> CGPoint {
        // Spread units sharing a spot so a crowd stays readable.
        let jitter = CGFloat(id % 5 - 2) * laneHeight * 0.1
        return CGPoint(x: fieldRect.minX + CGFloat(position) * fieldRect.width,
                       y: fieldRect.maxY - (CGFloat(lane) + 0.5) * laneHeight + jitter)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        field.removeAllChildren()
        let rect = fieldRect
        let shore = SKShapeNode(rect: CGRect(x: rect.minX - 50, y: rect.minY, width: 50, height: rect.height))
        shore.fillColor = NSColor(red: 0.25, green: 0.45, blue: 0.55, alpha: 1)
        shore.lineWidth = 0
        field.addChild(shore)
        for lane in 0..<LaneBattle.lanes {
            let band = SKShapeNode(rect: CGRect(x: rect.minX, y: rect.maxY - CGFloat(lane + 1) * laneHeight,
                                                width: rect.width, height: laneHeight))
            band.fillColor = lane.isMultiple(of: 2)
                ? NSColor(red: 0.33, green: 0.40, blue: 0.24, alpha: 1)
                : NSColor(red: 0.29, green: 0.36, blue: 0.21, alpha: 1)
            band.strokeColor = NSColor.black.withAlphaComponent(0.25)
            field.addChild(band)
        }
        let line = SKShapeNode(rect: CGRect(x: rect.minX + CGFloat(LaneBattle.holdLine) * rect.width - 1,
                                            y: rect.minY, width: 2, height: rect.height))
        line.fillColor = NSColor.white.withAlphaComponent(0.12)
        line.lineWidth = 0
        field.addChild(line)
        let tower = SKShapeNode(circleOfRadius: CGFloat(LaneBattle.towerRange) * rect.width)
        tower.position = CGPoint(x: rect.maxX, y: rect.midY)
        tower.fillColor = NSColor.systemRed.withAlphaComponent(0.06)
        tower.strokeColor = NSColor.systemRed.withAlphaComponent(0.25)
        field.addChild(tower)

        gate.path = CGPath(rect: CGRect(x: rect.maxX, y: rect.minY, width: 26, height: rect.height), transform: nil)
        gate.fillColor = NSColor(red: 0.45, green: 0.33, blue: 0.22, alpha: 1)
        gate.strokeColor = NSColor(red: 0.25, green: 0.18, blue: 0.12, alpha: 1)
        gate.lineWidth = 3
        gateBar.position = CGPoint(x: rect.maxX + 50, y: rect.minY)
        commandFrame.path = CGPath(rect: CGRect(x: rect.minX, y: rect.maxY + 16, width: 220, height: 12), transform: nil)
        commandFrame.strokeColor = NSColor.white.withAlphaComponent(0.4)
        commandBar.position = CGPoint(x: rect.minX, y: rect.maxY + 22)
        commandLabel.position = CGPoint(x: rect.minX + 230, y: rect.maxY + 16)
        clockLabel.position = CGPoint(x: rect.maxX + 26, y: rect.maxY + 12)
        banner.position = CGPoint(x: rect.midX, y: rect.midY)
    }

    // MARK: Input

    override func mouseDown(with event: NSEvent) {
        let location = event.location(in: self)
        guard fieldRect.insetBy(dx: -50, dy: 0).contains(location) else { return }
        let lane = Int((fieldRect.maxY - location.y) / laneHeight)
        if battle.deploy(selected, lane: min(LaneBattle.lanes - 1, max(0, lane))) {
            onDeploy?(battle.attackerReserve)
        } else if battle.attackerReserve[selected] > 0 {
            commandBar.run(.sequence([.colorize(with: .white, colorBlendFactor: 1, duration: 0.05),
                                      .colorize(withColorBlendFactor: 0, duration: 0.2)]))
        }
    }

    // MARK: Frame

    override func update(_ currentTime: TimeInterval) {
        let dt = lastUpdate.map { min(0.05, currentTime - $0) } ?? 0
        lastUpdate = currentTime
        battle.step(dt)
        drain()
        sync()
        if let outcome = battle.outcome, finished == false {
            finished = true
            banner.text = switch outcome {
            case .captured: "The gate falls!"
            case .repelled: "Repelled"
            case .withdrew: "Retreat!"
            }
            banner.fontColor = outcome == .captured ? .systemYellow : .white
            banner.isHidden = false
            let result = battle
            run(.sequence([.wait(forDuration: 1.6), .run { [weak self] in self?.onFinish?(result) }]))
        }
    }

    private func sync() {
        let rect = fieldRect
        var alive = Set<Int>()
        for unit in battle.units {
            alive.insert(unit.id)
            let node = unitNodes[unit.id] ?? makeNode(for: unit)
            node.position = point(lane: unit.lane, position: unit.position, id: unit.id)
            if let bar = node.childNode(withName: "health") as? SKSpriteNode {
                bar.xScale = CGFloat(max(0, unit.health / LaneBattle.stats(unit.kind).health))
            }
        }
        for (id, node) in unitNodes where alive.contains(id) == false {
            node.removeFromParent()
            unitNodes[id] = nil
        }
        gateBar.size = CGSize(width: 10, height: rect.height * CGFloat(max(0, battle.gateHealth / battle.gateMaxHealth)))
        let fill = CGFloat(battle.attackerCommand / LaneBattle.maxCommand)
        commandBar.size = CGSize(width: 220 * fill, height: 12)
        commandLabel.text = "Command \(Int(battle.attackerCommand))/\(Int(LaneBattle.maxCommand))"
        let seconds = Int(battle.timeRemaining.rounded(.up))
        clockLabel.text = String(format: "%d:%02d", seconds / 60, seconds % 60)
        clockLabel.fontColor = seconds <= 15 ? .systemRed : .white
    }

    private func makeNode(for unit: LaneBattle.Unit) -> SKNode {
        let color = unit.side == .attacker ? Self.attackerColor : Self.defenderColor
        let body: SKShapeNode = unit.kind == .knight
            ? SKShapeNode(rectOf: CGSize(width: 20, height: 20), cornerRadius: 4)
            : SKShapeNode(circleOfRadius: 8)
        body.fillColor = color
        body.strokeColor = NSColor.black.withAlphaComponent(0.6)
        body.lineWidth = 1.5
        let glyph = SKLabelNode(fontNamed: "AvenirNextCondensed-Bold")
        glyph.text = unit.kind == .knight ? "K" : "A"
        glyph.fontSize = 11
        glyph.fontColor = .black
        glyph.verticalAlignmentMode = .center
        body.addChild(glyph)
        let bar = SKSpriteNode(color: .systemGreen, size: CGSize(width: 22, height: 3))
        bar.anchorPoint = CGPoint(x: 0, y: 0.5)
        bar.position = CGPoint(x: -11, y: 15)
        bar.name = "health"
        body.addChild(bar)
        unitLayer.addChild(body)
        unitNodes[unit.id] = body
        return body
    }

    /// Turns the battle's events into short-lived effects.
    private func drain() {
        for event in battle.events {
            switch event {
            case let .shot(lane, from, to, side):
                let path = CGMutablePath()
                path.move(to: point(lane: lane, position: from))
                path.addLine(to: point(lane: lane, position: to))
                let streak = SKShapeNode(path: path)
                streak.strokeColor = (side == .attacker ? Self.attackerColor : Self.defenderColor).withAlphaComponent(0.8)
                streak.lineWidth = 1.5
                effects.addChild(streak)
                streak.run(.sequence([.fadeOut(withDuration: 0.18), .removeFromParent()]))
            case let .fell(lane, at, side):
                let puff = SKShapeNode(circleOfRadius: 10)
                puff.position = point(lane: lane, position: at)
                puff.strokeColor = side == .attacker ? Self.attackerColor : Self.defenderColor
                effects.addChild(puff)
                puff.run(.sequence([.group([.scale(to: 2.2, duration: 0.35), .fadeOut(withDuration: 0.35)]), .removeFromParent()]))
            case .gateHit:
                guard gate.action(forKey: "hit") == nil else { continue }
                gate.run(.sequence([.moveBy(x: 3, y: 0, duration: 0.04), .moveBy(x: -3, y: 0, duration: 0.06)]), withKey: "hit")
            }
        }
        battle.events.removeAll()
    }
}
