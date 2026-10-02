import SpriteKit
import AppKit

struct BattlefieldLayout: Decodable {
    struct Tile: Decodable {
        let name: String
        let layer: String
        let x, y, width, height, parallax: Double
    }
    let width, height: Double
    let shoreX, gateX: Double
    let laneYs: [Double]
    let tiles: [Tile]

    static func load(_ theme: WorldTheme) -> Self? {
        guard let data = NSDataAsset(name: "Battlefield\(theme.rawValue.capitalized)Layout")?.data else { return nil }
        return try? JSONDecoder().decode(Self.self, from: data)
    }
    var worldWidth: CGFloat { width / 2 }
    func point(lane: Int, position: Double, id: Int = 2) -> CGPoint {
        CGPoint(x: shoreX + position * (gateX - shoreX), y: laneYs[lane] + Double(id % 5 - 2) * 5)
    }
}

/// Visible tiles alone retain textures; leaving the viewport drops the reference.
final class BattleBackdrop: SKNode {
    private let layout: BattlefieldLayout
    private var tiles: [String: SKSpriteNode] = [:]
    init(layout: BattlefieldLayout) { self.layout = layout; super.init() }
    required init?(coder: NSCoder) { fatalError() }

    func update(cameraX: CGFloat, visibleWidth: CGFloat) {
        for tile in layout.tiles {
            let offset = (cameraX - layout.worldWidth / 2) * (1 - tile.parallax)
            let left = tile.x / 2 + offset
            let width = tile.width / 2
            let visible = left + width >= cameraX - visibleWidth / 2 && left <= cameraX + visibleWidth / 2
            if visible {
                let node = tiles[tile.name] ?? SKSpriteNode(texture: SKTexture(imageNamed: tile.name))
                if node.parent == nil {
                    node.anchorPoint = .zero
                    node.size = CGSize(width: width, height: tile.height / 2)
                    node.zPosition = tile.layer == "far" ? -30 : (tile.layer == "ground" ? -20 : 1300)
                    addChild(node); tiles[tile.name] = node
                }
                node.position = CGPoint(x: left, y: tile.y / 2)
            } else {
                tiles.removeValue(forKey: tile.name)?.removeFromParent()
            }
        }
    }
}

final class BattleFortress: SKNode {
    struct Piece: Decodable {
        let width, height, anchorX, anchorY, footprintWidth, footprintDepth: Double
        var slitX, slitY: Double?
    }
    private let atlas = SKTextureAtlas(named: "BattleFortress")
    private let anchors: [String: Piece]
    private let gate = SKSpriteNode()
    private var gateState = ""
    private(set) var firingSlit = CGPoint.zero

    init?(town: Town, layout: BattlefieldLayout) {
        guard let data = NSDataAsset(name: "BattleFortressLayout")?.data,
              let anchors = try? JSONDecoder().decode([String: Piece].self, from: data) else { return nil }
        self.anchors = anchors
        super.init()
        buildTown(town, layout: layout)
    }
    required init?(coder: NSCoder) { fatalError() }

    private func sprite(_ name: String, at point: CGPoint, scale: CGFloat = 1) -> SKSpriteNode {
        let node = SKSpriteNode(texture: atlas.textureNamed(name))
        if let piece = anchors[name] {
            node.size = CGSize(width: piece.width / 2, height: piece.height / 2)
            node.anchorPoint = CGPoint(x: piece.anchorX, y: piece.anchorY)
        }
        node.position = point; node.setScale(scale)
        node.zPosition = 1000 - point.y
        addChild(node)
        return node
    }

    private func buildTown(_ town: Town, layout: BattlefieldLayout) {
        let seed = World3DOcean.seed(for: town.id)
        let assets = town.buildings.flatMap { World3DTileEntity.settlementAssets(for: $0.kind, level: $0.level) }
        // Select deterministically, then put the larger silhouettes in the back row.
        let names = Array(Set(assets)).sorted()
        let chosen = (0..<min(5, names.count)).map { names[($0 + seed % max(1,names.count)) % names.count] }
            .sorted { (anchors["settlement_\($0)"]?.height ?? 0) > (anchors["settlement_\($1)"]?.height ?? 0) }
        for (index, name) in chosen.enumerated() {
            let x = layout.gateX + 115 + Double(index % 3) * 95 + Double(seed % 17)
            let y = layout.laneYs[0] + 55 - Double(index / 3) * 65
            sprite("settlement_\(name)", at: CGPoint(x: x, y: y), scale: 1.3)
        }
        for lane in [0,2] {
            sprite(lane == 2 ? "fort_endcap" : "fort_wall", at: layout.point(lane: lane, position: 1))
        }
        let middle = layout.point(lane: 1, position: 1)
        gate.position = middle; gate.zPosition = 1000-middle.y
        addChild(gate); damage(fraction: 1)
        let towerPoint = CGPoint(x: layout.gateX + 65, y: layout.laneYs[0] + 18)
        let scale: CGFloat = town.isDuskara ? 1.55 : 1
        sprite("fort_tower", at: towerPoint, scale: scale)
        let slit = anchors["fort_tower"]
        firingSlit = CGPoint(x: towerPoint.x + (slit?.slitX ?? 0) * scale, y: towerPoint.y + (slit?.slitY ?? 0) * scale)
        let flag = sprite("fort_banner_\(town.isPlayerControlled ? "blue" : "red")", at: CGPoint(x: layout.gateX + 105, y: layout.laneYs[0] + 12), scale: town.isDuskara ? 1.25 : 1)
        if town.isDuskara {
            let crest = SKLabelNode(fontNamed: "AvenirNextCondensed-Heavy")
            crest.text = "D"; crest.fontSize = 13; crest.fontColor = .white
            crest.position = CGPoint(x: 18, y: 110); flag.addChild(crest)
        }
    }

    func damage(fraction: Double) {
        let state = fraction > 2.0/3 ? "intact" : (fraction > 1.0/3 ? "cracked" : (fraction > 0 ? "breaking" : "broken"))
        guard state != gateState else { return }
        gateState = state
        let name = "fort_gate_\(state)"
        gate.texture = atlas.textureNamed(name)
        if let piece = anchors[name] {
            gate.size = CGSize(width: piece.width/2,height: piece.height/2)
            gate.anchorPoint = CGPoint(x: piece.anchorX,y: piece.anchorY)
        }
    }
}
