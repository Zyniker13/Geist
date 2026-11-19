// Murmuration app — the in-game HUD, results card, and debug overlay (S2.2).

import SwiftUI
import MUCore

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
            Spacer()
        }
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
