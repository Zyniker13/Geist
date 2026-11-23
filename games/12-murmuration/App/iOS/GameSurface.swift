// Murmuration app — iOS game surface and touch input (P2.2 / MU-P3.3).
//
// An MTKView in a UIViewRepresentable. The coordinator is both the draw
// delegate and the touch owner. Each single-finger drag builds a leader path
// for the flock nearest the touch (MU-P3.3: in versus mode the two players
// each steer the flock closest to their finger); a two-finger tap splits the
// flock and a pinch condenses (or releases) it, both routed to the nearest
// flock.

import SwiftUI
import MetalKit
import UIKit
import MUCore
import MURender

/// An MTKView that forwards raw touches to the input coordinator so that
/// several simultaneous single-finger drags can each steer a different flock
/// (MU-P3.3).
final class GameView: MTKView {
    weak var input: GameInput?

    override var isMultipleTouchEnabled: Bool {
        get { true }
        set {}
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        for touch in touches {
            input?.touchBegan(touch.location(in: self), touch: touch)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        for touch in touches {
            input?.touchMoved(touch.location(in: self), touch: touch)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        for touch in touches {
            input?.touchEnded(touch: touch)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        for touch in touches {
            input?.touchEnded(touch: touch)
        }
    }
}

struct GameSurface: UIViewRepresentable {
    let model: GameModel

    func makeUIView(context: Context) -> GameView {
        let view = GameView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        view.preferredFramesPerSecond = 60
        view.enableSetNeedsDisplay = false
        view.isPaused = false
        view.clearColor = MTLClearColor(red: 0.02, green: 0.02, blue: 0.04, alpha: 1)
        view.backgroundColor = .black
        view.isUserInteractionEnabled = true
        view.delegate = context.coordinator
        view.input = context.coordinator
        context.coordinator.attach(to: view)

        let split = UITapGestureRecognizer(
            target: context.coordinator, action: #selector(GameInput.twoFingerTap(_:))
        )
        split.numberOfTouchesRequired = 2
        // In versus mode two players each hold one finger; the two-finger tap
        // must not cancel those raw touches (it is a no-op there anyway).
        split.cancelsTouchesInView = false
        split.delegate = context.coordinator
        view.addGestureRecognizer(split)

        let pinch = UIPinchGestureRecognizer(
            target: context.coordinator, action: #selector(GameInput.pinch(_:))
        )
        pinch.delegate = context.coordinator
        view.addGestureRecognizer(pinch)

        // Pencil/pointer hover preview (MU-P7.2): while a Pencil (or mouse
        // pointer) hovers above the surface, accumulate a preview leader
        // path; it commits on touch-down and vanishes otherwise. Enabled
        // only with -uitest-preview in UI tests (hover events are not
        // synthesizable under XCUITest) and harmless elsewhere.
        if ProcessInfo.processInfo.arguments.contains("-uitest-preview") {
            let hover = UIHoverGestureRecognizer(
                target: context.coordinator, action: #selector(GameInput.hover(_:))
            )
            hover.delegate = context.coordinator
            view.addGestureRecognizer(hover)
        }

        return view
    }

    func updateUIView(_ view: GameView, context: Context) {}

    func makeCoordinator() -> GameInput {
        GameInput(model: model)
    }
}

/// Draw delegate plus touch handling for the iOS surface.
@MainActor
final class GameInput: NSObject, MTKViewDelegate, UIGestureRecognizerDelegate {
    let model: GameModel
    private(set) var renderer: FlockRenderer?
    private weak var view: MTKView?
    private var frameCount = 0
    private var fpsWindowStart: Double = 0

    /// One live drag per touch, each steering the flock it was routed to.
    private struct PanSession {
        var builder: LeaderPathBuilder
        var flock: UInt8
    }
    private var sessions: [ObjectIdentifier: PanSession] = [:]

    init(model: GameModel) {
        self.model = model
        super.init()
    }

    /// Late-attach the renderer once the view exists (the coordinator is
    /// created before its MTKView).
    func attach(to view: MTKView) {
        self.view = view
        renderer = try? FlockRenderer(
            mtkView: view,
            palette: model.region.palette,
            worldSize: SIMD2(
                Float(model.region.worldWidth), Float(model.region.worldHeight)
            ),
            hillSeed: model.region.seed
        )
        applyAccessibilityOptions()
    }

    /// Push the model's accessibility options into the renderer (MU-P8.1).
    /// Called on attach and whenever the settings change.
    func applyAccessibilityOptions() {
        guard let renderer else { return }
        if model.reduceMotion {
            // 1-in-4 decimation keeps the swarm read while quartering the
            // instance load; flutter snaps (no between-tick blend).
            renderer.birdStride = 4
            renderer.reducesFlutter = true
        } else {
            renderer.birdStride = 1
            renderer.reducesFlutter = false
        }
        renderer.highContrastRival = model.highContrastRival
    }

    // MARK: - MTKViewDelegate

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        let frameStart = CACurrentMediaTime()
        let now = CACurrentMediaTime()
        let ticked = model.advanceFrame(now: now)
        if ticked {
            renderer?.update(model.scene, instant: model.ticksPerFrame > 1)
        }
        renderer?.draw(in: view)
        steerHapticPulse()
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

    // MARK: - Touches (leader paths)

    private var worldSize: SIMD2<Float> {
        SIMD2(Float(model.region.worldWidth), Float(model.region.worldHeight))
    }

    func touchBegan(_ location: CGPoint, touch: UITouch) {
        guard let view = view else { return }
        let world = Self.worldPoint(location, in: view, world: worldSize)
        let flock = routeFlock(for: world)
        // One live session per flock: in solo mode a second finger is ignored
        // (the two-finger tap still splits), in versus each flock gets one.
        if sessions.values.contains(where: { $0.flock == flock }) { return }
        let paths = model.state.leaderPaths
        let path = Int(flock) < paths.count ? paths[Int(flock)] : LeaderPath(points: [])
        var builder = LeaderPathBuilder()
        guard
            let action = builder.begin(
                leaderX: path.currentX, leaderY: path.currentY, subFlock: flock
            )
        else {
            return
        }
        model.apply(action)
        sessions[ObjectIdentifier(touch)] = PanSession(builder: builder, flock: flock)
        // Haptics (MU-P6): continuous light texture while steering.
        steerHapticStart()
    }

    func touchMoved(_ location: CGPoint, touch: UITouch) {
        guard let view = view, var session = sessions[ObjectIdentifier(touch)] else {
            return
        }
        let world = Self.worldPoint(location, in: view, world: worldSize)
        if let action = session.builder.extend(to: world) {
            model.apply(action)
        }
        sessions[ObjectIdentifier(touch)] = session
    }

    func touchEnded(touch: UITouch) {
        sessions[ObjectIdentifier(touch)] = nil
        steerHapticStop()
    }

    // MARK: - Pencil/pointer hover preview (MU-P7.2)

    /// While the pointer hovers, grow a preview leader path for the flock
    /// the hover point routes to. The preview renders through
    /// `GameModel.previewBuilder` (dashed-bright in the renderer) but does
    /// NOT touch game state — the path commits only on touch-down.
    @objc func hover(_ gesture: UIHoverGestureRecognizer) {
        guard let view = gesture.view as? MTKView else { return }
        switch gesture.state {
        case .began, .changed:
            let world = Self.worldPoint(gesture.location(in: view), in: view, world: worldSize)
            let flock = routeFlock(for: world)
            // One live preview at a time; a hover that crosses to the
            // other flock in versus keeps steering the flock it started on.
            guard model.previewFlock.map({ $0 == flock }) ?? true else { return }
            model.stepPreview(to: world)
        case .ended, .cancelled, .failed:
            model.endPreview()
        default:
            break
        }
    }

    // MARK: - Steering haptics (MU-P6)

    /// Continuous light texture while a drag steers a flock. Core haptics
    /// has no "run until stopped" primitive, so the coordinator keeps a
    /// light generator prepared and re-fires a short tick while sessions
    /// are live; the render loop cadence keeps it feeling continuous.
    private let steerHaptic = UIImpactFeedbackGenerator(style: .light)
    private var steerHapticFireTick = 0

    private func steerHapticStart() {
        steerHaptic.prepare()
        steerHapticFireTick = 0
    }

    private func steerHapticStop() {
        if sessions.isEmpty { return }
        steerHapticFireTick = 0
    }

    /// Called from the render loop: re-fires the light texture while any
    /// steering session is live (scaled by flock speed via the model).
    func steerHapticPulse() {
        guard !sessions.isEmpty else { return }
        steerHapticFireTick += 1
        // Fire every 6 frames (~20 Hz at 120 fps) — a texture, not a drum.
        if steerHapticFireTick % 6 == 0 {
            steerHaptic.impactOccurred(intensity: 0.4)
        }
    }

    // MARK: - Gestures

    @objc func twoFingerTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended, let view = gesture.view as? MTKView else { return }
        // A split is only meaningful while a second flock is still possible.
        guard model.state.subFlockCount < 2 else { return }
        let world = Self.worldPoint(gesture.location(in: view), in: view, world: worldSize)
        model.apply(.splitFlock(from: routeFlock(for: world), ratio: 0.5))
    }

    @objc func pinch(_ gesture: UIPinchGestureRecognizer) {
        guard gesture.state == .ended, let view = gesture.view as? MTKView else { return }
        let world = Self.worldPoint(gesture.location(in: view), in: view, world: worldSize)
        let flock = routeFlock(for: world)
        if gesture.scale < 0.8 {
            model.apply(.condense(subFlock: flock))
        } else if gesture.scale > 1.25 {
            model.apply(.releaseCondense(subFlock: flock))
        }
    }

    /// Route a touch to the flock nearest it (MU-P3.3). Outside versus mode,
    /// or with a single flock, everything goes to flock 0.
    private func routeFlock(for world: SIMD2<Float>) -> UInt8 {
        guard model.versus else { return 0 }
        let state = model.state
        guard state.subFlockCount > 1 else { return 0 }
        let c0 = centroidOfFlock(
            birds: state.birds, assignments: state.subFlockAssignments, subFlock: 0
        )
        let c1 = centroidOfFlock(
            birds: state.birds, assignments: state.subFlockAssignments, subFlock: 1
        )
        let d0 = Self.sqDist(world, SIMD2(Float(c0.x), Float(c0.y)))
        let d1 = Self.sqDist(world, SIMD2(Float(c1.x), Float(c1.y)))
        return d1 < d0 ? 1 : 0
    }

    private static func sqDist(_ a: SIMD2<Float>, _ b: SIMD2<Float>) -> Float {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return dx * dx + dy * dy
    }

    // Recognizers run alongside each other.
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool {
        true
    }

    // MARK: - Coordinates

    /// View points to world units, accounting for the drawable scale.
    static func worldPoint(
        _ point: CGPoint, in view: MTKView, world: SIMD2<Float>
    ) -> SIMD2<Float> {
        let drawable = view.drawableSize
        let bounds = view.bounds.size
        guard bounds.width > 0, bounds.height > 0 else { return .zero }
        let scaleX = drawable.width / bounds.width
        let scaleY = drawable.height / bounds.height
        return FlockRenderer.worldPoint(
            viewPoint: SIMD2(Float(point.x * scaleX), Float(point.y * scaleY)),
            viewSize: SIMD2(Float(drawable.width), Float(drawable.height)),
            worldSize: world
        )
    }
}
