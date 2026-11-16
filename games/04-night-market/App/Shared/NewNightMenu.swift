/// NewNightMenu — the launcher sheet (NM-P5.2/P5.3): daily and weekly
/// challenges plus free play over the unlocked map ladder. A menu sheet,
/// never a modal alert (ui-flow.md).
import SwiftUI
import NMCore
import NMRender

struct NewNightMenu: View {
    @ObservedObject var store: ProfileStore
    /// Assist setting (NM-P8.2), applied to every setup this menu builds.
    var assist: Bool = false
    let onStart: (NightSetup) -> Void
    @State private var assistOn = false
    @State private var highContrastOn = false
    @State private var statsOptIn = false
    @State private var exportNote: String?

    private func setup(_ base: NightSetup) -> NightSetup {
        var s = base
        s.assist = assist || assistOn
        Palette.highContrast = highContrastOn
        return s
    }

    private var daily: NightSetup {
        setup(
            NightSetup.challenge(
                .daily, yyyymmddUTC: BundledContent.ChallengeClock.yyyymmddUTC(),
                isoWeekUTC: BundledContent.ChallengeClock.isoWeekUTC(),
                mapIds: BundledContent.mapIds, scheduleIds: BundledContent.scheduleIds
            ))
    }

    private var weekly: NightSetup {
        setup(
            NightSetup.challenge(
                .weekly, yyyymmddUTC: BundledContent.ChallengeClock.yyyymmddUTC(),
                isoWeekUTC: BundledContent.ChallengeClock.isoWeekUTC(),
                mapIds: BundledContent.mapIds, scheduleIds: BundledContent.scheduleIds
            ))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tonight's Market")
                .font(.system(.title3, design: .monospaced).bold())
                .foregroundStyle(nmColor(Palette.hudText))

            challengeRow("Daily Challenge", setup: daily)
            challengeRow("Weekly Challenge", setup: weekly)

            Divider().overlay(nmColor(Palette.hudText).opacity(0.3))

            ForEach(BundledContent.mapIds, id: \.self) { mapId in
                mapRow(mapId)
            }

            Divider().overlay(nmColor(Palette.hudText).opacity(0.3))

            Toggle("Assist mode (longer overflow grace)", isOn: $assistOn)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(nmColor(Palette.hudText))
                .accessibilityIdentifier("assist-toggle")
            Toggle("High contrast", isOn: $highContrastOn)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(nmColor(Palette.hudText))
                .accessibilityIdentifier("high-contrast-toggle")

            Divider().overlay(nmColor(Palette.hudText).opacity(0.3))

            // Telemetry-free stats export (P9): nothing leaves the device;
            // the player opts in and shares the file themselves.
            Toggle("Include my stats in exports", isOn: $statsOptIn)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(nmColor(Palette.hudText))
                .accessibilityIdentifier("stats-optin-toggle")
            if statsOptIn {
                Button("Export Stats to Documents") {
                    exportNote = store.exportStatsToFile()
                }
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(nmColor(Palette.hudText))
                .accessibilityIdentifier("stats-export-button")
                if let exportNote {
                    Text(exportNote)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(nmColor(Palette.hudText).opacity(0.7))
                }
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.black.opacity(0.82)))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(nmColor(Palette.hudText).opacity(0.5), lineWidth: 1))
        .padding(.horizontal, 22)
        .padding(.bottom, 64)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("new-night-menu")
    }

    private func challengeRow(_ title: String, setup: NightSetup) -> some View {
        let mapName = (try? BundledContent.map(setup.mapId))?.name ?? setup.mapId
        return Button {
            onStart(setup)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.headline, design: .monospaced))
                        .foregroundStyle(nmColor(Palette.hudText))
                    Text("\(mapName) · \(setup.modifier?.title ?? "")")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(nmColor(Palette.hudText).opacity(0.8))
                }
                Spacer()
            }
        }
        .accessibilityIdentifier("challenge-\(title.lowercased().replacingOccurrences(of: " ", with: "-"))")
    }

    private func mapRow(_ mapId: String) -> some View {
        let unlocked = store.profile.unlockedMaps.contains(mapId)
        let threshold = UnlockCatalog.thresholds[mapId] ?? 0
        let definition = try? BundledContent.map(mapId)
        let name = definition?.name ?? mapId
        let scheduleLabel = (definition?.schedule ?? "schedule_standard")
            .replacingOccurrences(of: "schedule_", with: "") + " night"
        return Button {
            guard unlocked else { return }
            let seed = UInt64.random(in: 1...UInt64.max)
            onStart(setup(NightSetup.freePlay(
                mapId: mapId, scheduleId: definition?.schedule ?? "schedule_standard", seed: seed
            )))
        } label: {
            HStack {
                Text(unlocked ? name : "🔒 \(name)")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(nmColor(Palette.hudText).opacity(unlocked ? 1 : 0.55))
                Spacer()
                if !unlocked {
                    Text("reach score \(threshold)")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(nmColor(Palette.hudText).opacity(0.55))
                } else {
                    Text(scheduleLabel)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(nmColor(Palette.hudText).opacity(0.55))
                }
            }
        }
        .disabled(!unlocked)
        .accessibilityIdentifier("map-\(mapId)")
    }
}
