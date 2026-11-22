// Murmuration app — the in-game HUD, results card, and debug overlay (S2.2).

import SwiftUI
import MUCore
import MUContent

/// Live status bar: day, flock size, flock energy, pause, restart.
struct HUD: View {
    @ObservedObject var model: GameModel

    var body: some View {
        VStack {
            HStack(spacing: 16) {
                Text("Day \(min(model.day, model.totalDays))/\(model.totalDays)")
                    .font(.headline)
                    .accessibilityIdentifier("game.day")
                Text("birds \(model.state.birds.count)")
                    .font(.subheadline.monospacedDigit())
                    .accessibilityIdentifier("game.birds")
                Text("energy \(model.state.energy.first ?? 0)")
                    .font(.subheadline.monospacedDigit())
                    .accessibilityIdentifier("game.energy")
                if let stage = model.campaignStage {
                    Text("stage \(stage + 1)/12")
                        .font(.subheadline.monospacedDigit())
                        .accessibilityIdentifier("game.stage")
                }
                Spacer()
                if model.state.isDusk {
                    Text("dusk")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                        .accessibilityIdentifier("game.dusk")
                }
                Button(model.paused ? "Resume" : "Pause") {
                    model.togglePause()
                }
                .accessibilityIdentifier("game.pause")
                Button("Restart") {
                    model.restart()
                }
                .accessibilityIdentifier("game.restart")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            tutorialBanner
            Spacer()
        }
    }

    /// The five-step tutorial banner (P3.2). Shows the current step's copy
    /// while active and a completion line when the tutorial is done. The
    /// `tutorial.complete` identifier is what the tutorial UI test waits on.
    @ViewBuilder
    private var tutorialBanner: some View {
        if model.tutorialComplete {
            Text("Murmuration mastered — the flock is yours")
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .accessibilityIdentifier("tutorial.complete")
        } else if model.tutorialStep >= 0,
                  let step = model.tutorialSteps[safe: model.tutorialStep] {
            VStack(spacing: 2) {
                Text(step.title)
                    .font(.subheadline.weight(.semibold))
                Text(step.body)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("tutorial.step")
        }
    }
}

private extension Array where Element: Equatable {
    /// Bounds-checked element (nil when the index is out of range).
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

/// Day-end tally (R-13): roosts won per flock, birds alive, winner.
struct ResultsCard: View {
    @ObservedObject var model: GameModel

    private var result: DayResult? {
        model.results.last
    }

    var body: some View {
        VStack(spacing: 12) {
            Text("Day \(model.day) complete")
                .font(.title2.weight(.semibold))
            if let result = result {
                Text("\(result.playerRoosts) player roosts — \(result.rivalRoosts) rival")
                    .accessibilityIdentifier("game.results.tally")
                Text("\(result.birdsAlive) birds alive")
                if result.winner >= 0 {
                    Text(result.winner == 0 ? "Player takes the day" : "Rival takes the day")
                        .font(.headline)
                }
            }
            if model.day < model.totalDays {
                Button("Next day") {
                    model.beginNextDay()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("game.nextDay")
            }
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("game.results")
    }
}
