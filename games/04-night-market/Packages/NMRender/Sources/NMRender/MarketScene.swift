/// The Night Market scene: renders the map, stalls, gates, fixtures, and
/// customers from GameState snapshots, and forwards player intents.
///
/// The scene is presentation-only: it never mutates GameState. Input is
/// reported through the `MarketSceneDelegate` callbacks; the owning
/// controller applies reducer actions and calls `sync(state:)`.
import SpriteKit
import NMCore

@MainActor
public protocol MarketSceneDelegate: AnyObject {
    func sceneDidRequestPaint(_ tiles: [Tile])
    func sceneDidRequestErase(_ tiles: [Tile])
    func sceneDidRequestPlace(_ kind: FixtureKind, at tile: Tile)
    func sceneDidRequestMove(_ fixtureID: Int, to tile: Tile)
    func sceneDidLongPressStall(_ stall: Stall)
}

open class MarketScene: SKScene {
    public weak var marketDelegate: MarketSceneDelegate?

    public let tileWidth: CGFloat
    let gridWidth: Int
    let gridHeight: Int

    // Layers
    private let mapLayer = SKNode()
    private let walkwayLayer = SKNode()
    let fixtureLayer = SKNode()
    private let stallLayer = SKNode()
    let customerLayer = SKNode()
    private let heatLayer = SKNode()

    // Node pools
    var customerNodes: [Int: SKNode] = [:]
    private var walkwayNodes: [Int: SKShapeNode] = [:]  // key = tileIndex
    var fixtureNodes: [Int: SKNode] = [:]
    private var stallNodes: [Int: SKNode] = [:]

    // Input state
    private var dragPainted: [Tile] = []
    private var dragErased: [Tile] = []
    private var isErasing = false
    private var dragStart: CGPoint?
    /// Armed fixture tool: the next tap (a drag shorter than one tile) places it.
    public var placementTool: FixtureKind?
    private var movingFixtureID: Int?

    public var showsHeatmap = false {
        didSet { heatLayer.isHidden = !showsHeatmap }
    }

    public init(state: GameState, tileWidth: CGFloat = 32) {
        let grid = state.grid
        self.gridWidth = grid.width
        self.gridHeight = grid.height
        self.tileWidth = tileWidth
        super.init(size: CGSize(width: CGFloat(grid.width) * tileWidth, height: CGFloat(grid.height) * tileWidth))
        backgroundColor = Palette.nightGround
        scaleMode = .aspectFit
        buildMap(state)
        sync(state: state)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Coordinate mapping (row 0 at the top, like the grid dump)

    public func scenePoint(for tile: Tile) -> CGPoint {
        CGPoint(
            x: (CGFloat(tile.col) + 0.5) * tileWidth,
            y: (CGFloat(gridHeight - 1 - tile.row) + 0.5) * tileWidth
        )
    }

    public func tile(at point: CGPoint) -> Tile? {
        let col = Int(point.x / tileWidth)
        let rowFromBottom = Int(point.y / tileWidth)
        let row = gridHeight - 1 - rowFromBottom
        guard col >= 0, col < gridWidth, row >= 0, row < gridHeight else { return nil }
        return Tile(col: col, row: row)
    }

    // MARK: - Static map

    private func buildMap(_ state: GameState) {
        addChild(mapLayer)
        addChild(heatLayer)
        heatLayer.isHidden = true
        addChild(walkwayLayer)
        addChild(fixtureLayer)
        addChild(stallLayer)
        addChild(customerLayer)
        drawMap(state)
    }

    /// Draws ground, canals, plaza, and gates into mapLayer. Layers must
    /// already be attached (init attaches once; rebuild reuses them).
    private func drawMap(_ state: GameState) {

        for row in 0..<gridHeight {
            for col in 0..<gridWidth {
                let tile = Tile(col: col, row: row)
                let rect = SKShapeNode(rectOf: CGSize(width: tileWidth + 0.5, height: tileWidth + 0.5))
                let kind = state.grid.tile(at: tile)
                rect.fillColor = Palette.tile(kind)
                if kind == .ground {
                    // Subtle checker texture so the board reads as ground.
                    rect.fillColor =
                        (col + row).isMultiple(of: 2)
                        ? SKColor(hex: 0x12141C) : SKColor(hex: 0x0F1118)
                }
                rect.strokeColor = SKColor(hex: 0x1A1E28)
                rect.lineWidth = 0.5
                rect.position = scenePoint(for: tile)
                rect.zPosition = 0
                mapLayer.addChild(rect)
                if case .water = kind {
                    // Canal tiles join into continuous rounded bands.
                    let mask = TileArt.mask(
                        for: tile,
                        isWalkable: { t in
                            if case .water = state.grid.tile(at: t) { return true }
                            return false
                        }, in: state.grid)
                    let band = SKShapeNode(path: TileArt.path(for: mask, tileSize: tileWidth * 0.98))
                    band.fillColor = Palette.canal
                    band.strokeColor = SKColor(hex: 0x3E6FA5)
                    band.lineWidth = 1
                    band.position = scenePoint(for: tile)
                    band.zPosition = 0.5
                    mapLayer.addChild(band)
                }
                if case .plaza = kind {
                    rect.strokeColor = SKColor(hex: 0x3A4258)
                    rect.lineWidth = 1
                }
            }
        }

        // Gates: bright notches at the map edge.
        for gate in state.gates {
            let arch = SKShapeNode(rectOf: CGSize(width: tileWidth * 0.95, height: tileWidth * 0.95), cornerRadius: 5)
            arch.fillColor = SKColor(hex: 0xE8E4D8)
            arch.strokeColor = Palette.lanternGlow
            arch.lineWidth = 2
            arch.position = scenePoint(for: gate.position)
            arch.zPosition = 2
            arch.name = "gate:\(gate.id)"
            mapLayer.addChild(arch)
            let door = SKShapeNode(rectOf: CGSize(width: tileWidth * 0.34, height: tileWidth * 0.5), cornerRadius: 3)
            door.fillColor = SKColor(hex: 0x2A2E3A)
            door.strokeColor = .clear
            door.position = scenePoint(for: gate.position)
            door.zPosition = 2.1
            mapLayer.addChild(door)
        }
    }

    // MARK: - State sync

    /// Clears all node pools and rebuilds the scene for a fresh state
    /// (restart / restore).
    public func rebuild(with state: GameState) {
        customerNodes.removeAll()
        walkwayNodes.removeAll()
        fixtureNodes.removeAll()
        stallNodes.removeAll()
        heatLayer.removeAllChildren()
        walkwayLayer.removeAllChildren()
        fixtureLayer.removeAllChildren()
        stallLayer.removeAllChildren()
        customerLayer.removeAllChildren()
        mapLayer.removeAllChildren()
        drawMap(state)
        sync(state: state)
    }

    /// Reconciles the node pools with a new state snapshot.
    public func sync(state: GameState) {
        syncWalkways(state)
        syncStalls(state)
        syncFixtures(state)
        syncCustomers(state)
    }

    private func syncWalkways(_ state: GameState) {
        var seen = Set<Int>()
        for tile in state.walkwayTiles {
            let index = tile.row * gridWidth + tile.col
            seen.insert(index)
            if walkwayNodes[index] == nil {
                let node = SKShapeNode(path: TileArt.path(for: 0, tileSize: tileWidth * 0.96))
                node.fillColor = Palette.walkway
                node.strokeColor = .clear
                node.position = scenePoint(for: tile)
                node.zPosition = 1
                walkwayLayer.addChild(node)
                walkwayNodes[index] = node
            }
        }
        for (index, node) in walkwayNodes where !seen.contains(index) {
            node.removeFromParent()
            walkwayNodes.removeValue(forKey: index)
        }
        // Re-apply neighbor masks so tiles auto-join.
        for (index, node) in walkwayNodes {
            let row = index / gridWidth
            let col = index % gridWidth
            let tile = Tile(col: col, row: row)
            let mask = TileArt.mask(
                for: tile,
                isWalkable: { [weak self] t in
                    self?.isWalkableForArt(t, in: state) ?? false
                }, in: state.grid)
            node.path = TileArt.path(for: mask, tileSize: tileWidth * 0.96)
        }
    }

    private func isWalkableForArt(_ tile: Tile, in state: GameState) -> Bool {
        if state.walkwayTiles.contains(tile) { return true }
        if case .plaza = state.grid.tile(at: tile) { return true }
        return false
    }

    private func syncStalls(_ state: GameState) {
        for stall in state.stalls where stallNodes[stall.id] == nil {
            let node = makeStallNode(stall)
            stallNodes[stall.id] = node
            stallLayer.addChild(node)
        }
        for (id, node) in stallNodes where !state.stalls.contains(where: { $0.id == id }) {
            node.removeFromParent()
            stallNodes.removeValue(forKey: id)
        }
        for stall in state.stalls {
            guard let node = stallNodes[stall.id] else { continue }
            node.alpha = stall.isOpen ? 1 : 0.45
            // Awning stripe pulses while serving.
            if let stripe = node.childNode(withName: "stripe") as? SKShapeNode {
                stripe.fillColor = Palette.stall(stall.color)
            }
            if let badge = node.childNode(withName: "queue") as? SKLabelNode {
                badge.text = stall.queue.isEmpty ? nil : "×\(stall.queue.count)"
            }
        }
    }

    // MARK: - Traffic heatmap (P2.5)

    public func setHeatmap(_ counts: [Int]) {
        heatLayer.removeAllChildren()
        guard counts.count == gridWidth * gridHeight else { return }
        let maxCount = max(1, counts.max() ?? 1)
        for index in 0..<counts.count {
            let value = counts[index]
            guard value > 0 else { continue }
            let alpha = min(0.55, Double(value) / Double(maxCount) * 0.55)
            let col = index % gridWidth
            let row = index / gridWidth
            let rect = SKShapeNode(rectOf: CGSize(width: tileWidth + 0.5, height: tileWidth + 0.5))
            rect.fillColor = SKColor(hex: 0xFFB547).withAlphaComponent(alpha)
            rect.strokeColor = .clear
            rect.position = scenePoint(for: Tile(col: col, row: row))
            rect.zPosition = 4
            heatLayer.addChild(rect)
        }
    }

    // MARK: - Input (iOS/touch)

    /// Drag entry points shared with the Mac mouse wrapper.
    public func beginDragPublic(at point: CGPoint, touchCount: Int) {
        beginDrag(at: point, touchCount: touchCount)
    }

    public func continueDragPublic(at point: CGPoint, touchCount: Int) {
        continueDrag(at: point, touchCount: touchCount)
    }

    public func finishDragPublic() {
        finishDrag()
    }

    private func beginDrag(at point: CGPoint, touchCount: Int) {
        dragStart = point
        isErasing = touchCount >= 2
        if let tile = tile(at: point) {
            if isErasing {
                dragErased.append(tile)
            } else {
                dragPainted.append(tile)
            }
        }
    }

    private func continueDrag(at point: CGPoint, touchCount: Int) {
        guard let tile = tile(at: point) else { return }
        if isErasing {
            if !dragErased.contains(tile) { dragErased.append(tile) }
        } else {
            if !dragPainted.contains(tile) { dragPainted.append(tile) }
        }
    }

    private func finishDrag() {
        let moved =
            dragStart.map { start in
                hypot(
                    start.x - (dragPainted.last.map { scenePoint(for: $0).x } ?? start.x),
                    start.y - (dragPainted.last.map { scenePoint(for: $0).y } ?? start.y))
            } ?? 0
        let isTap = dragPainted.count <= 1 && dragErased.count <= 1 && moved < tileWidth * 0.5
        if isTap, let tool = placementTool, let tile = dragPainted.first ?? dragErased.first {
            placementTool = nil
            marketDelegate?.sceneDidRequestPlace(tool, at: tile)
        } else if !dragErased.isEmpty {
            marketDelegate?.sceneDidRequestErase(dragErased)
        } else if !dragPainted.isEmpty {
            marketDelegate?.sceneDidRequestPaint(dragPainted)
        }
        dragPainted = []
        dragErased = []
        dragStart = nil
        isErasing = false
    }

    /// Programmatic drag used by the Mac mouse wrapper and UI tests.
    public func dragStroke(tiles: [Tile], erasing: Bool) {
        guard !tiles.isEmpty else { return }
        if erasing {
            marketDelegate?.sceneDidRequestErase(tiles)
        } else {
            marketDelegate?.sceneDidRequestPaint(tiles)
        }
    }
}
