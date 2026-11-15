/// Night Market game shell: market view + HUD + upgrade picker + results.
import SwiftUI
import SpriteKit
import NMCore
import NMRender

/// Cross-platform SKView wrapper.
public struct MarketView: ViewRepresentable {
    public let scene: MarketScene
    public var controller: GameController?

    public init(scene: MarketScene, controller: GameController? = nil) {
        self.scene = scene
        self.controller = controller
    }

    #if os(iOS)
        public func makeUIView(context: Context) -> SKView {
            let view = SKView()
            view.ignoresSiblingOrder = true
            view.allowsTransparency = false
            view.backgroundColor = Palette.nightGround
            // SwiftUI owns all touch input (MapInputCatcher); the scene is
            // presentation-only so HUD buttons never fight the SKView for taps.
            view.isUserInteractionEnabled = false
            view.presentScene(scene)
            return view
        }

        public func updateUIView(_ view: SKView, context: Context) {
            if view.scene !== scene { view.presentScene(scene) }
        }
    #else
        public func makeNSView(context: Context) -> MacMarketView {
            let view = MacMarketView()
            view.controller = controller
            view.ignoresSiblingOrder = true
            view.allowsTransparency = false
            view.layer?.backgroundColor = Palette.nightGround.cgColor
            view.presentScene(scene)
            return view
        }

        public func updateNSView(_ view: MacMarketView, context: Context) {
            if view.scene !== scene { view.presentScene(scene) }
            view.controller = controller
        }
    #endif
}

#if os(macOS)
    /// Mac input: left-drag paints, right-drag erases, space pauses, 1/2/3 speeds.
    public final class MacMarketView: SKView {
        weak var controller: GameController?
        private var isRightDrag = false
        private var market: MarketScene? { scene as? MarketScene }

        public override var acceptsFirstResponder: Bool { true }

        public override func mouseDown(with event: NSEvent) {
            isRightDrag = event.type == .rightMouseDown
            market?.beginDragPublic(at: convert(event), touchCount: isRightDrag ? 2 : 1)
        }

        public override func mouseDragged(with event: NSEvent) {
            market?.continueDragPublic(at: convert(event), touchCount: isRightDrag ? 2 : 1)
        }

        public override func mouseUp(with event: NSEvent) {
            market?.finishDragPublic()
            isRightDrag = false
        }

        public override func rightMouseDown(with event: NSEvent) {
            isRightDrag = true
            market?.beginDragPublic(at: convert(event), touchCount: 2)
        }

        public override func rightMouseDragged(with event: NSEvent) {
            market?.continueDragPublic(at: convert(event), touchCount: 2)
        }

        public override func rightMouseUp(with event: NSEvent) {
            market?.finishDragPublic()
            isRightDrag = false
        }

        public override func keyDown(with event: NSEvent) {
            switch event.keyCode {
            case 49:  // space
                controller?.setPaused(!(controller?.paused ?? false))
            case 18: controller?.setSpeed(1)
            case 19: controller?.setSpeed(2)
            case 20: controller?.setSpeed(3)
            default:
                super.keyDown(with: event)
            }
        }

        private func convert(_ event: NSEvent) -> CGPoint {
            guard let scene = market else { return .zero }
            let location = convert(event.locationInWindow, from: nil)
            return scene.convertPoint(fromView: CGPoint(x: location.x, y: bounds.height - location.y))
        }
    }
#endif

#if os(iOS)
    import UIKit
    /// SwiftUI color bridge for the NMRender palette.
    typealias ViewRepresentable = UIViewRepresentable
    func nmColor(_ c: SKColor) -> Color { Color(uiColor: c) }
#else
    import AppKit
    typealias ViewRepresentable = NSViewRepresentable
    func nmColor(_ c: SKColor) -> Color { Color(nsColor: c) }
#endif

/// The playable game screen.
public struct GameScreen: View {
    @StateObject private var game = GameController()
    @StateObject private var debug = DebugState.shared
    @StateObject private var tutorial = TutorialState()
    @State private var armed: FixtureKind?

    public init() {}

    public var body: some View {
        ZStack {
            MarketView(scene: game.scene, controller: game)
                .ignoresSafeArea()

            // Map input lives in its own touch surface so HUD buttons and
            // modal sheets never fight the SpriteKit view for taps.
            #if os(iOS)
                MapInputCatcher(scene: game.scene) { point in
                    game.selectStall(nearScenePoint: point)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, 76)
                .padding(.bottom, 64)
                .allowsHitTesting(
                    game.pendingOffers.isEmpty && game.results == nil && game.selectedStall == nil
                )
            #endif

            VStack {
                hud
                Spacer()
                tray
            }

            if !game.pendingOffers.isEmpty {
                UpgradePicker(offers: game.pendingOffers) { offer in
                    game.chooseUpgrade(offer)
                }
            }

            if let stall = game.selectedStall {
                StallSheet(stall: stall) { game.selectedStall = nil }
            }

            if let results = game.results {
                ResultsScreen(results: results) {
                    game.restart(seed: UInt64.random(in: 1...1_000_000))
                }
            }

            if tutorial.isVisible, let step = tutorial.current {
                TutorialCard(step: step, stepNumber: tutorial.index + 1, total: tutorial.steps.count) {
                    tutorial.advance()
                }
            }
        }
        .onAppear {
            game.start()
            tutorial.activateIfNeeded()
            DispatchQueue.main.async {
                if ProcessInfo.processInfo.arguments.contains("-uitest-fresh") {
                    self.game.deleteSave()
                } else if self.game.hasSave {
                    self.game.resume()
                }
                if ProcessInfo.processInfo.arguments.contains("-uitest-debug") {
                    self.debug.isVisible = true
                }
                if ProcessInfo.processInfo.arguments.contains("-uitest-stress") {
                    self.game.injectStressCrowd()
                }
                if ProcessInfo.processInfo.arguments.contains("-uitest-paused") {
                    self.game.setPaused(true)
                }
            }
        }
        .onDisappear { game.stop() }
    }

    private var hud: some View {
        HStack(spacing: 14) {
            Text("🌙 \(clockText)")
                .font(.system(.headline, design: .monospaced))
                .foregroundStyle(nmColor(Palette.hudText))
            Text("Score \(game.score)")
                .font(.system(.headline, design: .monospaced))
                .foregroundStyle(nmColor(Palette.hudText))
            Text("Walkway \(game.budgetUsed)/\(game.budgetTotal)")
                .font(.system(.headline, design: .monospaced))
                .foregroundStyle(
                    game.budgetUsed >= game.budgetTotal ? nmColor(Palette.stall(.noodles)) : nmColor(Palette.hudText)
                )
                .accessibilityIdentifier("budget-hud")
            if game.raining {
                Text("Rain")
                    .font(.system(.headline, design: .monospaced))
                    .foregroundStyle(nmColor(Palette.rainTint))
            }
            Spacer()
            Text("👥 \(game.customerCount)")
                .font(.system(.headline, design: .monospaced))
                .foregroundStyle(nmColor(Palette.hudText))
            speedControls
            Button {
                game.setPaused(!game.paused)
            } label: {
                Image(systemName: game.paused ? "play.fill" : "pause.fill")
                    .font(.headline)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("pause-button")
            .accessibilityLabel(game.paused ? "running" : "paused")
            .foregroundStyle(nmColor(Palette.hudText))
            Button {
                game.save()
            } label: {
                Image(systemName: "square.and.arrow.down")
                    .font(.headline)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(nmColor(Palette.hudText))
            .accessibilityIdentifier("save-button")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(nmColor(Palette.nightGround).opacity(0.85))
    }

    private var clockText: String {
        let h = game.hour % 24
        return String(format: "%02d:%02d", h, game.clockMinutes)
    }

    private var speedControls: some View {
        HStack(spacing: 4) {
            ForEach([1, 2, 3], id: \.self) { s in
                Button {
                    game.setSpeed(s)
                } label: {
                    Text("\(s)×")
                        .font(.system(.caption, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(game.speed == s ? nmColor(Palette.lanternGlow) : Color.clear)
                        )
                        .foregroundStyle(game.speed == s ? nmColor(Palette.nightGround) : nmColor(Palette.hudText))
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("speed-\(s)")
            }
        }
    }

    private var tray: some View {
        HStack(spacing: 10) {
            TrayButton(label: "Lantern", tint: nmColor(Palette.lanternGlow), selected: armed == .lantern(radius: 3)) {
                arm(.lantern(radius: 3))
            }
            TrayButton(label: "Awning", tint: nmColor(Palette.rainTint), selected: armed == .awning) {
                arm(.awning)
            }
            TrayButton(label: "Busker", tint: nmColor(Palette.stall(.tea)), selected: armed == .busker(radius: 2)) {
                arm(.busker(radius: 2))
            }
            TrayButton(label: "Seats", tint: nmColor(Palette.stallBody), selected: armed == .seat(count: 3)) {
                arm(.seat(count: 3))
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    /// Arm a placement tool; the next map tap places the fixture.
    private func arm(_ kind: FixtureKind) {
        if armed == kind {
            armed = nil
            game.scene.placementTool = nil
        } else {
            armed = kind
            game.scene.placementTool = kind
        }
    }
}

/// The tutorial card: a bottom menu-sheet step with a Next button, styled
/// like the other sheets (never a modal alert — ui-flow.md).
private struct TutorialCard: View {
    let step: TutorialStep
    let stepNumber: Int
    let total: Int
    let onNext: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Step \(stepNumber)/\(total) — \(step.title)")
                .font(.system(.headline, design: .monospaced))
                .foregroundStyle(nmColor(Palette.hudText))
            Text(step.text)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(nmColor(Palette.hudText))
            Button("Next") { onNext() }
                .font(.system(.caption, design: .monospaced))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 8).fill(nmColor(Palette.hudText).opacity(0.18)))
                .accessibilityIdentifier("tutorial-next")
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.72)))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(nmColor(Palette.hudText).opacity(0.5), lineWidth: 1))
        .padding(.horizontal, 24)
        .padding(.bottom, 72)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .allowsHitTesting(true)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("tutorial-card")
    }
}

private struct TrayButton: View {
    let label: String
    let tint: Color
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(.caption, design: .monospaced))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 8).fill(tint.opacity(selected ? 0.55 : 0.25)))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(tint, lineWidth: selected ? 2 : 1))
                .foregroundStyle(nmColor(Palette.hudText))
        }
        .buttonStyle(.borderless)
    }
}

/// Hour-boundary upgrade picker (R-5): two offers, choose one.
public struct UpgradePicker: View {
    public let offers: [UpgradeOffer]
    public let onChoose: (UpgradeOffer) -> Void

    public init(offers: [UpgradeOffer], onChoose: @escaping (UpgradeOffer) -> Void) {
        self.offers = offers
        self.onChoose = onChoose
    }

    public var body: some View {
        // Menu sheet, never a modal alert (ui-flow rule).
        VStack(spacing: 12) {
            Text("Hour complete — choose an upgrade")
                .font(.headline)
                .foregroundStyle(nmColor(Palette.hudText))
            ForEach(offers) { offer in
                Button {
                    onChoose(offer)
                } label: {
                    Text(offerName(offer))
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: 320)
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(nmColor(Palette.stallBody)))
                        .foregroundStyle(nmColor(Palette.hudText))
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("offer-button")
            }
        }
        .padding(24)
        .background(RoundedRectangle(cornerRadius: 16).fill(nmColor(Palette.nightGround).opacity(0.96)))
        .shadow(radius: 12)
        .accessibilityIdentifier("upgrade-picker")
    }

    private func offerName(_ offer: UpgradeOffer) -> String {
        switch offer.kind {
        case .extraWalkwayBudget(let n): return "+\(n) walkway budget"
        case .extraLanterns(let n): return "+\(n) lanterns"
        case .extraAwning: return "Extra awning"
        case .extraBusker: return "Extra busker"
        case .extraBridge: return "Bridge"
        case .extraSeating: return "Seating block (3 seats)"
        case .fasterService(let percent): return "Faster cooks (−\(percent)% service time)"
        case .extraQueue(let n): return "+\(n) queue at the busiest stall"
        }
    }
}

/// Long-press stall sheet: queue and service stats (R-12).
public struct StallSheet: View {
    public let stall: Stall
    public let onDismiss: () -> Void

    public init(stall: Stall, onDismiss: @escaping () -> Void) {
        self.stall = stall
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Stall").font(.headline).foregroundStyle(nmColor(Palette.hudText))
            Text("Queue: \(stall.queue.count) waiting")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(nmColor(Palette.hudText))
            Text("Service: \(stall.serviceTicks) ticks")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(nmColor(Palette.hudText))
            Button("Close") { onDismiss() }
                .buttonStyle(.borderless)
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 14).fill(nmColor(Palette.nightGround).opacity(0.96)))
    }
}

/// Results screen: served count, survival, score, and the traffic heatmap.
public struct ResultsScreen: View {
    public let results: GameController.ResultsSummary
    public let onRestart: () -> Void

    public init(results: GameController.ResultsSummary, onRestart: @escaping () -> Void) {
        self.results = results
        self.onRestart = onRestart
    }

    public var body: some View {
        VStack(spacing: 14) {
            Text(results.survived ? "Night survived!" : "The market overflowed")
                .font(.largeTitle.bold())
                .foregroundStyle(nmColor(Palette.hudText))
            Text("Served \(results.served) customers")
                .font(.title2)
                .foregroundStyle(nmColor(Palette.hudText))
            Text("Final score \(results.finalScore)")
                .font(.title3.monospaced())
                .foregroundStyle(nmColor(Palette.lanternGlow))
            Button("Next night") { onRestart() }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("next-night")
                .accessibilityIdentifier("next-night-button")
        }
        .padding(28)
        .background(RoundedRectangle(cornerRadius: 18).fill(nmColor(Palette.nightGround).opacity(0.97)))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("results-screen")
    }
}
