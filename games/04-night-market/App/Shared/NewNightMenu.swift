/// NewNightMenu — the launcher sheet (NM-P5.2/P5.3): daily and weekly
/// challenges plus free play over the unlocked map ladder. A menu sheet,
/// never a modal alert (ui-flow.md).
import SwiftUI
import NMCore
import NMRender

struct NewNightMenu: View {
    @ObservedObject var store: ProfileStore
    let onStart: (NightSetup) -> Void

    private var daily: NightSetup {
        NightSetup.challenge(
            .daily, yyyymmddUTC: BundledContent.ChallengeClock.yyyymmddUTC(),
            isoWeekUTC: BundledContent.ChallengeClock.isoWeekUTC(),
            mapIds: BundledContent.mapIds, scheduleIds: BundledContent.scheduleIds
        )
    }

    private var weekly: NightSetup {
        NightSetup.challenge(
            .weekly, yyyymmddUTC: BundledContent.ChallengeClock.yyyymmddUTC(),
            isoWeekUTC: BundledContent.ChallengeClock.isoWeekUTC(),
            mapIds: BundledContent.mapIds, scheduleIds: BundledContent.scheduleIds
        )
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
        Button {
            onStart(setup)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.headline, design: .monospaced))
                        .foregroundStyle(nmColor(Palette.hudText))
                    Text("\(setup.mapId) · \(setup.modifier?.title ?? "")")
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
        let name = (try? BundledContent.map(mapId))?.name ?? mapId
        return Button {
            guard unlocked else { return }
            let schedule = (try? BundledContent.map(mapId))?.schedule ?? "schedule_standard"
            let seed = UInt64.random(in: 1...UInt64.max)
            onStart(NightSetup.freePlay(mapId: mapId, scheduleId: schedule, seed: seed))
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
                }
            }
        }
        .disabled(!unlocked)
        .accessibilityIdentifier("map-\(mapId)")
    }
}
