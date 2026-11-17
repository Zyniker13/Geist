import SwiftUI
import UIKit

/// Three-finger double tap anywhere toggles the debug overlay (S0.7).
///
/// The catcher view is transparent and does not intercept touches for other controls
/// (harness pitfall: the gesture recognizer must not make the container opaque to
/// accessibility, so only the gesture lives here).
struct DebugGestureCatcher: UIViewRepresentable {
    let onThreeFingerDoubleTap: () -> Void

    func makeUIView(context: Context) -> UIView {
        let view = PassiveView()
        view.onThreeFingerDoubleTap = onThreeFingerDoubleTap
        let gesture = UITapGestureRecognizer(
            target: view,
            action: #selector(PassiveView.handleTap(_:))
        )
        gesture.numberOfTouchesRequired = 3
        gesture.numberOfTapsRequired = 2
        view.addGestureRecognizer(gesture)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        (uiView as? PassiveView)?.onThreeFingerDoubleTap = onThreeFingerDoubleTap
    }
}

private final class PassiveView: UIView {
    var onThreeFingerDoubleTap: () -> Void = {}

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // Never consume touches; only observe gestures.
        nil
    }

    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        onThreeFingerDoubleTap()
    }
}
