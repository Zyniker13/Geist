/// iOS map input: a transparent touch view over the map area that forwards
/// drags to the scene's programmatic API. SwiftUI buttons (HUD, tray,
/// pickers) live outside this view's inset frame, so they keep their taps.
#if os(iOS)
    import SwiftUI
    import UIKit
    import SpriteKit
    import NMCore
    import NMRender

    /// Transparent touch surface covering the map area (inset away from the
    /// HUD and tray strips). Two-finger contact erases; one finger paints;
    /// a long press selects the stall under the finger.
    struct MapInputCatcher: UIViewRepresentable {
        let scene: MarketScene
        let onLongPress: (CGPoint) -> Void

        func makeUIView(context: Context) -> TouchView {
            let view = TouchView()
            view.scene = scene
            view.onLongPress = onLongPress
            let press = UILongPressGestureRecognizer(
                target: context.coordinator, action: #selector(Coordinator.longPress(_:))
            )
            press.minimumPressDuration = 0.45
            view.addGestureRecognizer(press)
            return view
        }

        func updateUIView(_ view: TouchView, context: Context) {
            view.scene = scene
            view.onLongPress = onLongPress
        }

        func makeCoordinator() -> Coordinator { Coordinator() }

        final class Coordinator: NSObject {
            @objc func longPress(_ gesture: UILongPressGestureRecognizer) {
                guard gesture.state == .began, let view = gesture.view as? TouchView else { return }
                let location = gesture.location(in: view)
                view.onLongPress?(view.scenePoint(for: location))
            }
        }

        final class TouchView: UIView {
            var scene: MarketScene?
            var onLongPress: ((CGPoint) -> Void)?
            private var activeTouchCount = 1

            override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
                activeTouchCount = event?.allTouches?.count ?? touches.count
                guard let touch = touches.first else { return }
                scene?.beginDragPublic(at: scenePoint(for: touch.location(in: self)), touchCount: activeTouchCount)
            }

            override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
                activeTouchCount = max(activeTouchCount, event?.allTouches?.count ?? touches.count)
                guard let touch = touches.first else { return }
                scene?.continueDragPublic(at: scenePoint(for: touch.location(in: self)), touchCount: activeTouchCount)
            }

            override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
                scene?.finishDragPublic()
                activeTouchCount = 1
            }

            override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
                scene?.finishDragPublic()
                activeTouchCount = 1
            }

            /// Maps a point in this view to scene coordinates with the same
            /// aspect-fit math MarketScene uses to lay out its content.
            func scenePoint(for point: CGPoint) -> CGPoint {
                guard let scene else { return point }
                let scale = min(bounds.width / scene.size.width, bounds.height / scene.size.height)
                let spanW = scene.size.width * scale
                let spanH = scene.size.height * scale
                let offX = (bounds.width - spanW) / 2
                let offY = (bounds.height - spanH) / 2
                // Scene origin is bottom-left; view origin is top-left.
                let x = (point.x - offX) / scale
                let yFromTop = (point.y - offY) / scale
                return CGPoint(x: x, y: scene.size.height - yFromTop)
            }
        }
    }
#endif
