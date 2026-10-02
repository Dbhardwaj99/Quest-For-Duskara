import SpriteKit
import SwiftUI

struct BattleSpriteView: NSViewRepresentable {
    let scene: LaneBattleScene
    func makeNSView(context: Context) -> BattleSKView {
        let view = BattleSKView()
        view.preferredFramesPerSecond = 60
        view.ignoresSiblingOrder = true
        view.presentScene(scene)
        return view
    }
    func updateNSView(_ view: BattleSKView, context: Context) {}
    static func dismantleNSView(_ view: BattleSKView, coordinator: ()) { view.presentScene(nil) }
}

/// SpriteKit's responder receives keys even after clicking its canvas.
final class BattleSKView: SKView {
    override var acceptsFirstResponder: Bool { true }
    // The HUD supplies the accessible controls and lane summaries.
    override func accessibilityChildren() -> [Any]? { [] }
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); window?.makeFirstResponder(self) }
    override func keyDown(with event: NSEvent) {
        if (scene as? LaneBattleScene)?.key(event, down: true) != true { super.keyDown(with: event) }
    }
    override func keyUp(with event: NSEvent) {
        if (scene as? LaneBattleScene)?.key(event, down: false) != true { super.keyUp(with: event) }
    }
    override func resignFirstResponder() -> Bool {
        (scene as? LaneBattleScene)?.stopPanning()
        return super.resignFirstResponder()
    }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseMoved,.mouseEnteredAndExited,.activeInKeyWindow,.inVisibleRect], owner: self, userInfo: nil))
    }
    override func mouseMoved(with event: NSEvent) { (scene as? LaneBattleScene)?.hover(event) }
    override func mouseExited(with event: NSEvent) { (scene as? LaneBattleScene)?.clearHover() }
    override func scrollWheel(with event: NSEvent) { (scene as? LaneBattleScene)?.scroll(event) }
    override func magnify(with event: NSEvent) {
        guard let scene = scene as? LaneBattleScene else { return }
        scene.zoom(by: 1+event.magnification, about: event.location(in: scene))
    }
}

final class LaneBattleScene: SKScene {
    private(set) var battle: LaneBattle
    var selected: SoldierKind = .knight
    var onFinish: ((LaneBattle) -> Void)?
    var onHUD: ((BattleHUDState) -> Void)?
    var onSelect: ((SoldierKind) -> Void)?
    var onWithdrawRequest: (() -> Void)?
    var reduceMotion = false

    private let sprites = BattleSprites()
    private let world = SKNode()
    private let units = SKNode()
    private let cameraNode = SKCameraNode()
    private let highlight = SKSpriteNode(texture: BattleSprites.pixel, color: NSColor.white.withAlphaComponent(0.12), size: .zero)
    private let gateBar = SKSpriteNode(texture: BattleSprites.pixel, color: .systemRed, size: CGSize(width: 90,height: 5))
    private let gateLabel = SKLabelNode(fontNamed: "AvenirNextCondensed-Bold")
    private let layout: BattlefieldLayout?
    private var backdrop: BattleBackdrop?
    private var fortress: BattleFortress?
    private var effects: BattleEffects?
    private var nodes: [Int: UnitSpriteNode] = [:]
    private var assetsReady = false
    private var lastUpdate: TimeInterval?
    private var unsimulated = 0.0
    private var finished = false
    private var initializedCamera = false
    private var zoomLevel: CGFloat = 1
    private var keys = Set<UInt16>()
    private var panVelocity: CGFloat = 0
    private var lastManualPan = -Double.infinity
    private var downPoint: CGPoint?
    private var downCameraX: CGFloat = 0
    private var dragged = false
    private var lastTextUpdate = -Double.infinity
    private var hudPublisher: BattleHUDPublisher
    private var hasLanded = false
    private var lastHitSound = -Double.infinity
    private var gateBroke = false
    #if DEBUG
    private var peakNodes = 0
    private var frameCount = 0
    private var frameTime = 0.0
    private var updateTime = 0.0
    private var lastMetrics = 0.0
    private var hudPublications = 0
    private var hudPublishTime = 0.0
    #endif

    init(battle: LaneBattle, town: Town) {
        self.battle = battle
        hudPublisher = BattleHUDPublisher(battle)
        layout = BattlefieldLayout.load(WorldTheme.current)
        super.init(size: CGSize(width: 1200,height: 800))
        scaleMode = .resizeFill
        backgroundColor = WorldTheme.current.palette.sky
        addChild(world); world.addChild(units)
        addChild(cameraNode); camera = cameraNode
        for node in [highlight,gateBar] { node.colorBlendFactor = 1; node.zPosition = 1400; world.addChild(node) }
        highlight.isHidden = true
        gateLabel.fontSize = 12; gateLabel.fontColor = .white; gateLabel.zPosition = 1401
        world.addChild(gateLabel)
        if let layout {
            let backdrop = BattleBackdrop(layout: layout)
            world.addChild(backdrop); self.backdrop = backdrop
            fortress = BattleFortress(town: town, layout: layout)
            if let fortress { world.addChild(fortress) }
            let floor = SKSpriteNode(texture: BattleSprites.pixel, color: WorldTheme.current.palette.tileGround, size: CGSize(width: layout.worldWidth, height: 4096))
            floor.colorBlendFactor = 1; floor.anchorPoint = CGPoint(x: 0,y: 1)
            floor.position.y = 1; floor.zPosition = -25; world.addChild(floor)
            gateBar.anchorPoint = CGPoint(x: 0,y: 0.5)
            gateBar.position = CGPoint(x: layout.gateX-45,y: layout.laneYs[0]+140)
            gateLabel.position = CGPoint(x: layout.gateX,y: gateBar.position.y+10)
        }
        sprites.preload { [weak self] in
            guard let self, self.layout != nil, self.fortress != nil else { return }
            let effects = BattleEffects(sprites: self.sprites)
            self.world.addChild(effects); self.effects = effects
            self.assetsReady = true
            self.sync()
        }
    }
    required init?(coder: NSCoder) { fatalError() }

    override func didMove(to view: SKView) {
        initializedCamera = false
        didChangeSize(.zero)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        guard let layout, size.width > 0, size.height > 0 else { return }
        if !initializedCamera {
            zoomLevel = min(2,max(minZoom,size.width/(12*64)))
            cameraNode.position = CGPoint(x: size.width / zoomLevel / 2, y: 230)
            initializedCamera = true
        }
        zoomLevel = max(minZoom,zoomLevel)
        cameraNode.setScale(1/zoomLevel); clampCamera()
        backdrop?.update(cameraX: cameraNode.position.x,visibleWidth: size.width/zoomLevel)
        highlight.size = CGSize(width: layout.shoreX,height: abs(layout.laneYs[0]-layout.laneYs[1]))
    }
    private var minZoom: CGFloat { min(2,size.width / (layout?.worldWidth ?? size.width)) }
    private func clampCamera() {
        guard let layout else { return }
        let half = size.width / zoomLevel / 2
        cameraNode.position.x = max(half,min(layout.worldWidth-half,cameraNode.position.x))
    }
    private func manualPan() { lastManualPan = lastUpdate ?? 0 }
    func stopPanning() { keys.removeAll(); panVelocity = 0 }
    func zoom(by factor: CGFloat, about point: CGPoint? = nil) {
        guard factor > 0 else { return }
        let old = zoomLevel
        zoomLevel = min(2,max(minZoom,old*factor))
        let pivot = point ?? cameraNode.position
        cameraNode.position.x = pivot.x-(pivot.x-cameraNode.position.x)*old/zoomLevel
        cameraNode.setScale(1/zoomLevel); clampCamera(); manualPan()
    }
    func key(_ event: NSEvent, down: Bool) -> Bool {
        if [123,124].contains(event.keyCode) {
            if down { keys.insert(event.keyCode); manualPan() } else { keys.remove(event.keyCode) }
            return true
        }
        let character = event.charactersIgnoringModifiers?.lowercased() ?? ""
        guard down else { return ["1","2","3","k","a","+","=","-"].contains(character) || event.keyCode == 53 }
        if event.isARepeat, ["1","2","3"].contains(character) { return true }
        switch character {
        case "1","2","3": land(lane: Int(character)!-1)
        case "k": selected = .knight; onSelect?(.knight)
        case "a": selected = .archer; onSelect?(.archer)
        case "+","=": zoom(by: 1.15)
        case "-": zoom(by: 1/1.15)
        default:
            if event.keyCode == 53 { onWithdrawRequest?() } else { return false }
        }
        return true
    }
    func withdraw() { battle.withdraw() }
    func land(lane: Int) {
        guard assetsReady, battle.deploy(selected,lane: lane) else { return }
        hasLanded = true
        GameSound.battleLand.play()
        if let layout { effects?.puff("dust",at: layout.point(lane: lane,position: 0)) }
    }
    private func beachLane(at point: CGPoint) -> Int? {
        guard let layout, (0...layout.shoreX).contains(point.x) else { return nil }
        let spacing = abs(layout.laneYs[0]-layout.laneYs[1])
        return layout.laneYs.indices.min { abs(layout.laneYs[$0]-point.y)<abs(layout.laneYs[$1]-point.y) }
            .flatMap { abs(layout.laneYs[$0]-point.y)<=spacing/2 ? $0 : nil }
    }
    func hover(_ event: NSEvent) {
        guard let lane = beachLane(at: event.location(in: self)), let layout else { clearHover(); return }
        highlight.isHidden = false
        highlight.position = CGPoint(x: layout.shoreX/2,y: layout.laneYs[lane])
    }
    func clearHover() { highlight.isHidden = true }
    override func mouseDown(with event: NSEvent) {
        view?.window?.makeFirstResponder(view)
        downPoint = event.locationInWindow; downCameraX = cameraNode.position.x; dragged = false
    }
    override func mouseDragged(with event: NSEvent) {
        guard let downPoint else { return }
        let delta = event.locationInWindow.x-downPoint.x
        dragged = dragged || hypot(delta,event.locationInWindow.y-downPoint.y)>6
        if dragged { cameraNode.position.x = downCameraX-delta/zoomLevel; clampCamera(); manualPan(); clearHover() }
    }
    override func mouseUp(with event: NSEvent) {
        defer { downPoint = nil }
        if !dragged, let lane = beachLane(at: event.location(in: self)) { land(lane: lane) }
    }
    func scroll(_ event: NSEvent) {
        if event.modifierFlags.contains(.command) { zoom(by: exp(event.scrollingDeltaY*0.01),about: event.location(in: self)) }
        else {
            let delta = abs(event.scrollingDeltaX)>0.01 ? event.scrollingDeltaX : event.scrollingDeltaY
            cameraNode.position.x -= delta/zoomLevel; clampCamera(); manualPan()
        }
    }

    override func update(_ currentTime: TimeInterval) {
        let dt = lastUpdate.map { max(0,min(0.1,currentTime-$0)) } ?? 0
        #if DEBUG
        let began = CFAbsoluteTimeGetCurrent()
        if let lastUpdate { frameTime += currentTime-lastUpdate; frameCount += 1 }
        #endif
        lastUpdate = currentTime
        guard assetsReady else { return }
        let direction: CGFloat = (keys.contains(124) ? 1 : 0)-(keys.contains(123) ? 1 : 0)
        if direction != 0 { panVelocity = max(-900,min(900,panVelocity+direction*2200*dt)) }
        else { panVelocity *= max(0,1-10*dt) }
        if abs(panVelocity)>0.1 { cameraNode.position.x += panVelocity*dt/zoomLevel; manualPan() }
        else if !reduceMotion, currentTime-lastManualPan>3,
                let front = battle.units.filter({ $0.side == .attacker }).map(\.position).max(), let layout {
            let goal = layout.point(lane: 1,position: front).x+size.width/zoomLevel*0.15
            cameraNode.position.x += (goal-cameraNode.position.x)*(1-exp(-dt*2))
        }
        clampCamera()
        backdrop?.update(cameraX: cameraNode.position.x,visibleWidth: size.width/zoomLevel)
        #if DEBUG
        unsimulated += dt*(ProcessInfo.processInfo.arguments.contains("-battleFast") ? 4 : 1)
        if ProcessInfo.processInfo.arguments.contains("-battleAutoplay") {
            for kind in [SoldierKind.knight,.archer] where battle.canDeploy(kind) { selected = kind; land(lane: 1) }
        }
        #else
        unsimulated += dt
        #endif
        while unsimulated >= LaneBattle.tick { battle.step(LaneBattle.tick); unsimulated -= LaneBattle.tick }
        drain(); sync()
        if currentTime-lastTextUpdate>=0.25 {
            lastTextUpdate = currentTime
            let gateText = "GATE \(Int(max(0,battle.gateHealth).rounded(.up)))"
            if gateLabel.text != gateText { gateLabel.text = gateText }
        }
        if let next = hudPublisher.update(battle, now: currentTime, hasLanded: hasLanded) {
            #if DEBUG
            let hudBegan = CFAbsoluteTimeGetCurrent()
            #endif
            onHUD?(next)
            #if DEBUG
            hudPublications += 1; hudPublishTime += CFAbsoluteTimeGetCurrent()-hudBegan
            #endif
        }
        #if DEBUG
        func count(_ node: SKNode) -> Int { 1+node.children.reduce(0) { $0+count($1) } }
        peakNodes = max(peakNodes,count(self)); updateTime += CFAbsoluteTimeGetCurrent()-began
        if currentTime-lastMetrics>5 || battle.outcome != nil {
            lastMetrics = currentTime
            let data: [String: Double] = ["peakNodes":Double(peakNodes),"fps":Double(frameCount)/max(0.001,frameTime),"sceneUpdateMS":updateTime/max(1,Double(frameCount))*1000,"elapsed":battle.elapsed,"hudPublications":Double(hudPublications),"hudPublishMS":hudPublishTime/max(1,Double(hudPublications))*1000,"cameraX":cameraNode.position.x,"zoom":zoomLevel]
            if ProcessInfo.processInfo.arguments.contains("-battleSandbox"), let encoded = try? JSONSerialization.data(withJSONObject:data) {
                try? encoded.write(to: FileManager.default.temporaryDirectory.appendingPathComponent("duskara-battle-metrics.json"))
            }
        }
        #endif
        if battle.outcome != nil, !finished {
            finished = true
            let result = battle
            run(.sequence([.wait(forDuration: reduceMotion ? 0.1 : 1.2),.run { [weak self] in self?.onFinish?(result) }]))
        }
    }
    private func sync() {
        guard let layout else { return }
        let half = size.width/zoomLevel/2 + 96
        let visible = battle.units.filter {
            let x = layout.point(lane: $0.lane,position: $0.position,id: $0.id).x
            return abs(x-cameraNode.position.x) <= half
        }
        let visibleIDs = Set(visible.map(\.id))
        for (id,node) in nodes {
            if (!visibleIDs.contains(id) && !node.isDying) || node.parent == nil {
                node.removeFromParent(); nodes[id] = nil
            }
        }
        for unit in visible {
            let node: UnitSpriteNode
            if let existing = nodes[unit.id] { node = existing }
            else {
                // ponytail: cap overlapping sprites at 76 (three nodes each) to
                // keep the whole scene below 300; add formations if armies grow.
                guard nodes.count < 76 else { continue }
                node = UnitSpriteNode(unit: unit,sprites: sprites); units.addChild(node); nodes[unit.id] = node
            }
            let point = layout.point(lane: unit.lane,position: unit.position,id: unit.id)
            node.sync(unit,at: point); node.setScale(0.9+CGFloat(unit.lane)*0.05); node.zPosition = 1000-point.y
        }
        let fraction = max(0,battle.gateHealth/battle.gateMaxHealth)
        gateBar.xScale = fraction; fortress?.damage(fraction: fraction)
    }
    private func drain() {
        guard let layout else { return }
        for event in battle.events {
            switch event {
            case let .struck(attacker,target):
                guard let node = nodes[attacker] else { continue }
                node.strike()
                let destination = target.flatMap { id in
                    nodes[id]?.position ?? battle.units.first(where: { $0.id == id }).map {
                        layout.point(lane: $0.lane,position: $0.position,id: id)
                    }
                } ?? CGPoint(x: layout.gateX,y: node.position.y)
                let origin = CGPoint(x: node.position.x,y: node.position.y+40)
                let ranged = node.kind == .archer
                // Frame 3 is the release/impact. Damage already happened in the rules.
                node.run(.sequence([.wait(forDuration: 3.0/12),.run { [weak self] in
                    guard let self else { return }
                    let now = self.lastUpdate ?? 0
                    if now-self.lastHitSound >= 1.0/6 { GameSound.battleHit.play(); self.lastHitSound = now }
                    if ranged { self.effects?.arrow(from: origin,to: destination) }
                    self.effects?.puff("hit",at: destination)
                }]))
            case let .fell(id,_,lane,position,_):
                nodes[id]?.die(); effects?.puff("dust",at: layout.point(lane:lane,position:position,id:id))
            case let .shot(lane,_,to,_):
                if let fortress { effects?.arrow(from: fortress.firingSlit,to: layout.point(lane:lane,position:to)) }
            case .gateHit:
                if battle.gateHealth<=0, !gateBroke {
                    gateBroke = true; GameSound.battleGateBreak.play()
                    effects?.puff("dust",at: layout.point(lane:1,position:1))
                    if !reduceMotion, cameraNode.action(forKey:"shake")==nil {
                        cameraNode.run(.sequence([.moveBy(x:3,y:0,duration:0.04),.moveBy(x:-6,y:0,duration:0.06),.moveBy(x:3,y:0,duration:0.04)]),withKey:"shake")
                    }
                }
            }
        }
        battle.events.removeAll()
    }
}
