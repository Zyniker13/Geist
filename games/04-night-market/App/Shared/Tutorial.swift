import Foundation
import SwiftUI

/// One step of the six-step first-run tutorial (NM-P3.4). `advance` names the
/// in-game trigger that normally completes the step; the Next button always
/// works too, so no step can trap a new player.
struct TutorialStep: Codable, Equatable {
    let id: String
    let title: String
    let text: String
    let advance: String
}

/// Drives the tutorial card over the game screen. Enabled by the
/// `-uitest-tutorial` launch argument (the first-run toggle ships with the
/// settings phase); the card advances on Next and never blocks play.
@MainActor
final class TutorialState: ObservableObject {
    @Published private(set) var steps: [TutorialStep] = []
    @Published private(set) var index: Int = 0
    @Published var isVisible: Bool = false

    var current: TutorialStep? { steps.indices.contains(index) ? steps[index] : nil }
    var isLastStep: Bool { index == steps.count - 1 }

    /// Loads `tutorial.json` from the app bundle and shows step 1 when the
    /// launch argument is present.
    func activateIfNeeded() {
        guard steps.isEmpty else {
            if isVisible { return }
            if ProcessInfo.processInfo.arguments.contains("-uitest-tutorial") {
                index = 0
                isVisible = true
            }
            return
        }
        guard ProcessInfo.processInfo.arguments.contains("-uitest-tutorial") else { return }
        struct TutorialFile: Codable { let steps: [TutorialStep] }
        guard let url = Bundle.main.url(forResource: "tutorial", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(TutorialFile.self, from: data),
              decoded.steps.count == 6
        else { return }
        steps = decoded.steps
        index = 0
        isVisible = true
    }

    /// Next button (and event triggers): one step forward, dismiss at the end.
    func advance() {
        guard isVisible else { return }
        if index < steps.count - 1 {
            index += 1
        } else {
            isVisible = false
        }
    }
}
