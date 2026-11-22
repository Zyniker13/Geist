// Murmuration app — macOS game surface and mouse input (P2.5).
//
// An MTKView subclass in an NSViewRepresentable. Click-drag draws the
// flock-0 leader path, Option-drag steers the second sub-flock, and a
// trackpad pinch/scroll gesture condenses (or releases) the flock.

import SwiftUI
import MetalKit
import AppKit
import MUCore
import MURender

struct GameSurfaceMac: NSViewRepresentable {
    let model: GameModel

    func makeNSView(context: Context) -> MacGameView {
        let view = MacGameView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        view.model = model
        view.preferredFramesPerSecond = 120
        view.enableSetNeedsDisplay = false
        view.isPaused = false
        view.clearColor = MTLClearColor(red: 0.02, green: 0.02, blue: 0.04, alpha: 1)
        view.delegate = context.coordinator
        context.coordinator.attach(to: view)
        return view
    }

    func updateNSView(_ view: MacGameView, context: Context) {}

    func makeCoordinator() -> MacDrawCoordinator {
        MacDrawCoordinator(model: model)
    }
}

/// The draw delegate for the Mac surface.
@MainActor
final class MacDrawCoordinator: NSObject, MTKViewDelegate {
    let model: GameModel
    private(set) var renderer: FlockRenderer?
    private var frameCount = 0
    private var fpsWindowStart: Double = 0

    init(model: GameModel) {
        self.model = model
        super.init()
    }

    func attach(to view: MTKView) {
        renderer = try? FlockRenderer(
            mtkView: view,
            palette: model.region.palette,
            worldSize: SIMD2(
                Float(model.region.worldWidth), Float(model.region.worldHeight)
            ),
            hillSeed: model.region.seed
        )
        if renderer == nil {
            MUTrace.log("surface: renderer init failed")
        }
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    private static var tracedFirstDraw = false

    func draw(in view: MTKView) {
        if !Self.tracedFirstDraw {
            Self.tracedFirstDraw = true
            MUTrace.log("surface: first draw")
        }
        let frameStart = CACurrentMediaTime()
        let now = CACurrentMediaTime()
        let ticked = model.advanceFrame(now: now)
        if ticked {
            renderer?.update(model.scene, instant: model.ticksPerFrame > 1)
        }
        renderer?.draw(in: view)
        model.recordFrameCost(started: frameStart)
        frameCount += 1
        if fpsWindowStart == 0 { fpsWindowStart = now }
        let span = now - fpsWindowStart
        if span >= 1 {
            model.fps = Int((Double(frameCount) / span).rounded())
            frameCount = 0
            fpsWindowStart = now
        }
    }
}

/// The MTKView itself handles mouse and trackpad events.
@MainActor
final class MacGameView: MTKView {
    var model: GameModel?
    private var flockZeroBuilder = LeaderPathBuilder()
    private var flockOneBuilder = LeaderPathBuilder()

    override var acceptsFirstResponder: Bool { true }

    // MARK: - Mouse

    // MARK: - Hover preview (MU-P7.2): pointer movement (no button) draws
    // a dashed preview of the leader path it would commit. Enabled only
    // with -uitest-preview (mouse-moved delivery is unreliable in headless
    // XCUITest runs) and harmless otherwise.

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if trackingAreas.isEmpty || trackingAreas.allSatisfy({ $0.owner !== self }) {
            addTrackingArea(NSTrackingArea(
                rect: bounds,
                options: [.mouseMoved, .activeInKeyWindow],
                owner: self,
                userInfo: nil
            ))
        }
    }

    override func mouseMoved(with event: NSEvent) {
        guard let model = model else { return super.mouseMoved(with: event) }
        guard ProcessInfo.processInfo.arguments.contains("-uitest-preview") else {
            return super.mouseMoved(with: event)
        }
        guard let world = worldPoint(of: event) else { return super.mouseMoved(with: event) }
        model.stepPreview(to: world)
        super.mouseMoved(with: event)
    }

    override func mouseEntered(with event: NSEvent) {}
    override func mouseExited(with event: NSEvent) {
        model?.endPreview()
        super.mouseExited(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        model?.endPreview()
        guard let model = model else { return }
        if event.modifierFlags.contains(.option) {
            let path = model.state.leaderPaths[1]
            _ = flockOneBuilder.begin(
                leaderX: path.currentX, leaderY: path.currentY, subFlock: 1
            )
        } else {
            let path = model.state.leaderPaths[0]
            _ = flockZeroBuilder.begin(
                leaderX: path.currentX, leaderY: path.currentY, subFlock: 0
            )
        }
        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let model = model else { return }
        guard let world = worldPoint(of: event) else { return }
        let action: GameAction?
        if event.modifierFlags.contains(.option) {
            action = flockOneBuilder.extend(to: world)
        } else {
            action = flockZeroBuilder.extend(to: world)
        }
        if let action {
            model.apply(action)
        }
        super.mouseDragged(with: event)
    }

    // MARK: - Trackpad pinch (scroll-pinch condense)

    override func magnify(with event: NSEvent) {
        guard let model = model else { return }
        if event.magnification < -0.03 {
            model.apply(.condense(subFlock: 0))
        } else if event.magnification > 0.03 {
            model.apply(.releaseCondense(subFlock: 0))
        }
        super.magnify(with: event)
    }

    // MARK: - Coordinates

    // MARK: - Trackpad two-finger pan = split (MU-P7.2). The pinch handler
    // owns magnification; a deliberate two-finger swipe (no magnification,
    // steady horizontal or vertical translation) splits the flock. Matches
    // the iOS two-finger-tap semantics: only while a second flock is still
    // possible, always from flock 0 at ratio 0.5.

    private var panAccumulated: SIMD2<Float> = .zero

    override func scrollWheel(with event: NSEvent) {
        guard let model = model else { return super.scrollWheel(with: event) }
        if event.phase == .began {
            panAccumulated = .zero
        }
        // hasPreciseScrollingDeltas: a trackpad pan, not a wheel tick.
        if event.hasPreciseScrollingDeltas, model.state.subFlockCount < 2 {
            panAccumulated += SIMD2(Float(event.scrollingDeltaX), Float(event.scrollingDeltaY))
            let distance = (panAccumulated.x * panAccumulated.x
                + panAccumulated.y * panAccumulated.y).squareRoot()
            if distance > 60 {
                panAccumulated = .zero
                model.apply(.splitFlock(from: 0, ratio: 0.5))
            }
        }
        super.scrollWheel(with: event)
    }

    private func worldPoint(of event: NSEvent) -> SIMD2<Float>? {
        guard let model = model else { return nil }
        let location = convert(event.locationInWindow, from: nil)
        let flipped = SIMD2(Float(location.x), Float(bounds.height - location.y))
        let drawable = drawableSize
        let scaleX = Float(drawable.width) / Float(max(bounds.width, 1))
        let scaleY = Float(drawable.height) / Float(max(bounds.height, 1))
        let worldSize = SIMD2(
            Float(model.region.worldWidth), Float(model.region.worldHeight)
        )
        return FlockRenderer.worldPoint(
            viewPoint: SIMD2(flipped.x * scaleX, flipped.y * scaleY),
            viewSize: SIMD2(Float(drawable.width), Float(drawable.height)),
            worldSize: worldSize
        )
    }
}
