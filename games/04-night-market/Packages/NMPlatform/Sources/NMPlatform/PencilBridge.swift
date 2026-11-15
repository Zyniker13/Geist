/// Apple Pencil support (NM-P7.3), behind an input model so tests run
/// without hardware: hover highlights the tile under the tip and squeeze
/// toggles erase. The UIKit glue is thin and delegates here.
import Foundation
import NMCore

/// The testable Pencil input model (§8.2: code paths behind protocols with
/// tests on the input model).
public struct PencilInputModel: Equatable, Sendable {
    public private(set) var eraseArmed = false

    public init() {}

    /// A squeeze toggles erase; returns the new state for the UI.
    @discardableResult
    public mutating func squeeze() -> Bool {
        eraseArmed.toggle()
        return eraseArmed
    }
}

/// Delegate surface the app implements (hover → tile highlight, squeeze →
/// erase toggle).
public protocol PencilBridgeDelegate: AnyObject {
    func pencilHoveredTile(_ tile: Tile?)
    func pencilEraseArmed(_ armed: Bool)
}

#if canImport(UIKit)
import UIKit

/// The UIKit glue: a `UIPencilInteraction` for squeeze and a
/// `UIHoverGestureRecognizer` for hover, forwarding into the model.
@MainActor
public final class PencilBridge: NSObject, UIPencilInteractionDelegate {
    public weak var delegate: PencilBridgeDelegate?
    public private(set) var model = PencilInputModel()
    private let interaction = UIPencilInteraction()
    private let hoverRecognizer = UIHoverGestureRecognizer()

    public override init() {
        super.init()
        interaction.delegate = self
    }

    /// Attach to the view that receives pencil input.
    public func attach(to view: UIView, tileMapper: @MainActor @escaping (CGPoint) -> Tile?) {
        view.addInteraction(interaction)
        hoverRecognizer.addTarget(self, action: #selector(hovered(_:)))
        view.addGestureRecognizer(hoverRecognizer)
        self.tileMapper = tileMapper
    }

    private var tileMapper: ((CGPoint) -> Tile?)?

    @objc private func hovered(_ recognizer: UIHoverGestureRecognizer) {
        switch recognizer.state {
        case .began, .changed:
            delegate?.pencilHoveredTile(tileMapper?(recognizer.location(in: recognizer.view)))
        default:
            delegate?.pencilHoveredTile(nil)
        }
    }

    public func pencilInteraction(
        _ interaction: UIPencilInteraction, didReceiveSqueeze squeeze: UIPencilInteraction.Squeeze
    ) {
        let armed = model.squeeze()
        delegate?.pencilEraseArmed(armed)
    }
}
#endif
