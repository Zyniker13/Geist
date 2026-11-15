// Stall, glyph, and fixture node construction for MarketScene.
import SpriteKit
import NMCore

extension MarketScene {
    func makeStallNode(_ stall: Stall) -> SKNode {
        let node = SKNode()
        node.position = scenePoint(for: stall.position)
        node.zPosition = 3
        node.name = "stall:\(stall.id)"

        let body = SKShapeNode(
            rect: CGRect(x: -tileWidth * 0.42, y: -tileWidth * 0.34, width: tileWidth * 0.84, height: tileWidth * 0.68),
            cornerRadius: 5)
        body.fillColor = Palette.stallBody
        body.strokeColor = Palette.stall(stall.color).withAlphaComponent(0.9)
        body.lineWidth = 1.5
        node.addChild(body)

        let stripe = SKShapeNode(
            rect: CGRect(x: -tileWidth * 0.42, y: tileWidth * 0.18, width: tileWidth * 0.84, height: tileWidth * 0.16))
        stripe.fillColor = Palette.stall(stall.color)
        stripe.strokeColor = .clear
        stripe.name = "stripe"
        node.addChild(stripe)

        let glyph = makeGlyphNode(for: stall.color, size: tileWidth * 0.3)
        glyph.position = CGPoint(x: 0, y: -tileWidth * 0.06)
        glyph.name = "glyph"
        node.addChild(glyph)

        let badge = SKLabelNode(fontNamed: "Menlo-Bold")
        badge.fontSize = 11
        badge.fontColor = Palette.hudText
        badge.verticalAlignmentMode = .top
        badge.position = CGPoint(x: 0, y: -tileWidth * 0.4)
        badge.name = "queue"
        node.addChild(badge)
        return node
    }

    /// Color-blind-safe glyph per stall color (circle, triangle, square,
    /// diamond, star, hexagon).
    func makeGlyphNode(for color: StallColor, size: CGFloat) -> SKShapeNode {
        let path = CGMutablePath()
        switch color {
        case .noodles:
            path.addEllipse(in: CGRect(x: -size / 2, y: -size / 2, width: size, height: size))
        case .tea:
            path.move(to: CGPoint(x: 0, y: size / 2))
            path.addLine(to: CGPoint(x: size / 2, y: -size / 2))
            path.addLine(to: CGPoint(x: -size / 2, y: -size / 2))
            path.closeSubpath()
        case .skewers:
            path.addRoundedRect(
                in: CGRect(x: -size / 2, y: -size / 2, width: size, height: size), cornerWidth: 2, cornerHeight: 2)
        case .dumplings:
            path.move(to: CGPoint(x: 0, y: size / 2))
            path.addLine(to: CGPoint(x: size / 2, y: 0))
            path.addLine(to: CGPoint(x: 0, y: -size / 2))
            path.addLine(to: CGPoint(x: -size / 2, y: 0))
            path.closeSubpath()
        case .sweets:
            let points = 5
            for i in 0..<(points * 2) {
                let radius = i.isMultiple(of: 2) ? size / 2 : size / 4.4
                let angle = CGFloat(i) * .pi / CGFloat(points) - .pi / 2
                let pt = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
                if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
            }
            path.closeSubpath()
        case .seafood:
            for i in 0..<6 {
                let angle = CGFloat(i) * .pi / 3
                let pt = CGPoint(x: cos(angle) * size / 2, y: sin(angle) * size / 2)
                if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
            }
            path.closeSubpath()
        }
        let node = SKShapeNode(path: path)
        node.fillColor = Palette.stall(color)
        node.strokeColor = .clear
        return node
    }

    func syncFixtures(_ state: GameState) {
        for fixture in state.fixtures where fixtureNodes[fixture.id] == nil {
            let node = makeFixtureNode(fixture)
            fixtureNodes[fixture.id] = node
            fixtureLayer.addChild(node)
        }
        for (id, node) in fixtureNodes where !state.fixtures.contains(where: { $0.id == id }) {
            node.removeFromParent()
            fixtureNodes.removeValue(forKey: id)
        }
        for fixture in state.fixtures {
            fixtureNodes[fixture.id]?.position = scenePoint(for: fixture.position)
        }
    }

    func makeFixtureNode(_ fixture: Fixture) -> SKNode {
        let node = SKNode()
        node.zPosition = 2
        node.name = "fixture:\(fixture.id)"
        switch fixture.kind {
        case .lantern:
            let glow = SKSpriteNode(texture: Self.glowTexture())
            glow.size = CGSize(width: tileWidth * 5.2, height: tileWidth * 5.2)
            glow.blendMode = .add
            glow.alpha = 0.85
            glow.name = "glow"
            node.addChild(glow)
            let lamp = SKShapeNode(circleOfRadius: tileWidth * 0.22)
            lamp.fillColor = Palette.lanternGlow
            lamp.strokeColor = SKColor(hex: 0xFFE3B0)
            lamp.lineWidth = 1.5
            node.addChild(lamp)
        case .awning:
            let canopy = SKShapeNode(
                rect: CGRect(
                    x: -tileWidth * 0.42, y: -tileWidth * 0.42, width: tileWidth * 0.84, height: tileWidth * 0.84),
                cornerRadius: 4)
            canopy.fillColor = Palette.rainTint.withAlphaComponent(0.22)
            canopy.strokeColor = Palette.rainTint.withAlphaComponent(0.6)
            canopy.lineWidth = 1
            node.addChild(canopy)
        case .busker:
            let note = SKLabelNode(fontNamed: "Menlo-Bold")
            note.text = "♪"
            note.fontSize = 14
            note.fontColor = Palette.lanternGlow
            node.addChild(note)
        case .bridge:
            let plank = SKShapeNode(rectOf: CGSize(width: tileWidth * 0.7, height: tileWidth * 0.7))
            plank.fillColor = SKColor(hex: 0x6B5236)
            plank.strokeColor = SKColor(hex: 0x8A6D49)
            plank.lineWidth = 1.5
            node.addChild(plank)
        case .seat:
            let seat = SKShapeNode(rectOf: CGSize(width: tileWidth * 0.6, height: tileWidth * 0.6), cornerRadius: 3)
            seat.fillColor = SKColor(hex: 0x3A3F52)
            seat.strokeColor = Palette.hudText.withAlphaComponent(0.5)
            seat.lineWidth = 1
            node.addChild(seat)
        }
        return node
    }

    /// Cached warm radial-gradient texture for lantern light.
    private static var cachedGlow: SKTexture?

    static func glowTexture() -> SKTexture {
        if let cachedGlow { return cachedGlow }
        let size = 256
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard
            let context = CGContext(
                data: nil, width: size, height: size, bitsPerComponent: 8,
                bytesPerRow: 0, space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else { return SKTexture() }
        let colors =
            [
                SKColor(hex: 0xFFB547).withAlphaComponent(0.55).cgColor,
                SKColor(hex: 0xFFB547).withAlphaComponent(0.22).cgColor,
                SKColor(hex: 0xFFB547).withAlphaComponent(0.0).cgColor,
            ] as CFArray
        let gradient = CGGradient(
            colorsSpace: colorSpace, colors: colors, locations: [0.0, 0.45, 1.0]
        )!
        context.drawRadialGradient(
            gradient,
            startCenter: CGPoint(x: CGFloat(size) / 2, y: CGFloat(size) / 2),
            startRadius: 0,
            endCenter: CGPoint(x: CGFloat(size) / 2, y: CGFloat(size) / 2),
            endRadius: CGFloat(size) / 2,
            options: []
        )
        let texture = SKTexture(cgImage: context.makeImage()!)
        cachedGlow = texture
        return texture
    }

    func syncCustomers(_ state: GameState) {
        var seen = Set<Int>()
        for customer in state.customers {
            seen.insert(customer.id)
            let node: SKNode
            if let existing = customerNodes[customer.id] {
                node = existing
            } else {
                let dot = SKShapeNode(circleOfRadius: tileWidth * 0.16)
                dot.fillColor = Palette.stall(customer.color)
                dot.strokeColor = SKColor(hex: 0xE8E4D8).withAlphaComponent(0.6)
                dot.lineWidth = 1.5
                dot.zPosition = 5
                customerLayer.addChild(dot)
                customerNodes[customer.id] = dot
                node = dot
            }
            let point = unitPoint(of: customer.position)
            node.position = CGPoint(
                x: point.x * CGFloat(gridWidth) * tileWidth, y: point.y * CGFloat(gridHeight) * tileWidth)
        }
        for (id, node) in customerNodes where !seen.contains(id) {
            node.removeFromParent()
            customerNodes.removeValue(forKey: id)
        }
    }

    /// Maps fixed-point sim coordinates (units) to a 0..<1 scene fraction.
    func unitPoint(of position: FixedPoint2) -> CGPoint {
        let widthUnits = CGFloat(gridWidth) * 1024
        let heightUnits = CGFloat(gridHeight) * 1024
        let x = CGFloat(position.x) / widthUnits
        let yFromTop = CGFloat(position.y) / heightUnits
        return CGPoint(x: x, y: 1 - yFromTop)
    }
}
