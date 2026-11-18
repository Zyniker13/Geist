// Murmuration app — iOS game surface and gesture input (P2.2).
//
// An MTKView in a UIViewRepresentable. The coordinator is both the draw
// delegate and the gesture owner: a one-finger pan builds the flock-0 leader
// path, a two-finger tap splits the flock, and a pinch condenses (or
// releases) it.

import SwiftUI
import MetalKit
import UIKit
import MUCore
import MURender

struct GameSurface: UIViewRepresentable {
    let model: GameModel

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        view.preferredFramesPerSecond = 60
        view.enableSetNeedsDisplay = false
        view.isPaused = false
        view.clearColor = MTLClearColor(red: 0.02, green: 0.02, blue: 0.04, alpha: 1)
        view.backgroundColor = .black
        view.isUserInteractionEnabled = true
        view.delegate = context.coordinator
        context.coordinator.attach(to: view)

        let pan = UIPanGestureRecognizer(
            target: context.coordinator, action: #selector(GameInput.pan(_:))
        )
        pan.maximumNumberOfTouches = 1
        pan.minimumNumberOfTouches = 1
        pan.delegate = context.coordinator
        view.addGestureRecognizer(pan)

        let split = UITapGestureRecognizer(
            target: context.coordinator, action: #selector(GameInput.twoFingerTap(_:))
        )
        split.numberOfTouchesRequired = 2
        split.delegate = context.coordinator
        view.addGestureRecognizer(split)

        let pinch = UIPinchGestureRecognizer(
            target: context.coordinator, action: #selector(GameInput.pinch(_:))
        )
        pinch.delegate = context.coordinator
        view.addGestureRecognizer(pinch)

        return view
    }

    func updateUIView(_ view: MTKView, context: Context) {}

    func makeCoordinator() -> GameInput {
        GameInput(model: model)
    }
}

/// Draw delegate plus gesture handling for the iOS surface.
@MainActor
final class GameInput: NSObject, MTKViewDelegate, UIGestureRecognizerDelegate {
    let model: GameModel
    private(set) var renderer: FlockRenderer?
    private var pathBuilder = LeaderPathBuilder()
    private var frameCount = 0
    private var fpsWindowStart: Double = 0

    init(model: GameModel) {
        self.model = model
        super.init()
    }

    /// Late-attach the renderer once the view exists (the coordinator is
    /// created before its MTKView).
    func attach(to view: MTKView) {
        renderer = try? FlockRenderer(
            mtkView: view,
            palette: model.region.palette,
            worldSize: SIMD2(
                Float(model.region.worldWidth), Float(model.region.worldHeight)
            ),
            hillSeed: model.region.seed
        )
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

    // MARK: - Gestures

    @objc func pan(_ gesture: UIPanGestureRecognizer) {
        guard let view = gesture.view as? MTKView else { return }
        let worldSize = SIMD2(
            Float(model.region.worldWidth), Float(model.region.worldHeight)
        )
        let world = Self.worldPoint(
            gesture.location(in: view), in: view, world: worldSize
        )
        switch gesture.state {
        case .began:
            let path = model.state.leaderPaths[0]
            if let action = pathBuilder.begin(
                leaderX: path.currentX, leaderY: path.currentY, subFlock: 0
            ) {
                model.apply(action)
            }
        case .changed:
            if let action = pathBuilder.extend(to: world) {
                model.apply(action)
            }
        default:
            break
        }
    }

    @objc func twoFingerTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended else { return }
        model.apply(.splitFlock(from: 0, ratio: 0.5))
    }

    @objc func pinch(_ gesture: UIPinchGestureRecognizer) {
        guard gesture.state == .ended else { return }
        if gesture.scale < 0.8 {
            model.apply(.condense(subFlock: 0))
        } else if gesture.scale > 1.25 {
            model.apply(.releaseCondense(subFlock: 0))
        }
    }

    // Recognizers run alongside each other; the pan stays single-touch.
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
