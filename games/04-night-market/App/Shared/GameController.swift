/// GameController — owns the simulation loop, HUD state, and player actions.
/// All game logic lives in NMCore; this type only advances ticks and applies
/// reducer actions, then pushes snapshots to the renderer.
import SwiftUI
import Combine
import os
import NMCore
import NMContent
import NMAudio
import NMPlatform
import NMRender

@MainActor
public final class GameController: NSObject, ObservableObject, MarketSceneDelegate {
    // Simulation
    public private(set) var state: GameState
    private var rng: SeededRNG
    private var tickTimer: Timer?

    // Published HUD state
    @Published public var budgetUsed = 0
    @Published public var budgetTotal = 30
    @Published public var score = 0
    @Published public var hour = 18
    @Published public var clockMinutes = 0
    @Published public var customerCount = 0
    @Published public var paused = false
    @Published public var speed = 1
    @Published public var raining = false
    @Published public var pendingOffers: [UpgradeOffer] = []
    @Published public var results: ResultsSummary?
    @Published public var selectedStall: Stall?

    public struct ResultsSummary: Identifiable, Equatable {
        public var id: Int { finalScore * 1000 + nightNumber }
        public let served: Int
        public let survived: Bool
        public let finalScore: Int
        public let nightNumber: Int
        public let newAchievements: [String]
        public let unlockedMapName: String?
    }

    // Presentation-only traffic heatmap (not part of GameState).
    public private(set) var heatmap: [Int] = []
    private var servesTotal = 0
    private var overflowCount = 0
    private var nightNumber = 1  // init's slice night is night 1; restart/start(setup:) advance
    /// The setup this night was started with (drives profile accounting).
    private var currentSetup = NightSetup.freePlay(mapId: "taipei", scheduleId: "schedule_standard", seed: 42)

    public let scene: MarketScene

    public init(seed: UInt64 = 42) {
        self.seed = seed
        // The slice uses the scripted scenario (S2.3): rain pinned at 20:00.
        state = GameState.initial(seed: seed, overrides: NightScenario.taipeiSlice.overrides)
        // Calm first night (NM-P3.4): slower spawn ramp; set before any tick.
        if ProcessInfo.processInfo.arguments.contains("-uitest-calm") {
            state.calmFirstNight = true
        }
        rng = SeededRNG(seed: seed)
        heatmap = Array(repeating: 0, count: state.grid.width * state.grid.height)
        scene = MarketScene(state: state)
        super.init()
        scene.marketDelegate = self
        publishHud()
    }

    public let seed: UInt64

    // MARK: - Save / resume (S2.4, local only)

    private struct SaveData: Codable {
        var state: GameState
        var rng: SeededRNG
        var nightNumber: Int
        var servesTotal: Int
        /// StateHash.hex(state) at save time, for resume verification.
        var hash: String
    }

    private static var saveURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NightMarket", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("save.json")
    }

    public var hasSave: Bool { FileManager.default.fileExists(atPath: Self.saveURL.path) }

    /// Writes the mid-night snapshot. Returns false when encoding failed.
    @discardableResult
    public func save() -> Bool {
        let data = SaveData(
            state: state, rng: rng, nightNumber: nightNumber, servesTotal: servesTotal,
            hash: StateHash.hex(state))
        let log = Logger(subsystem: "com.example.night-market", category: "save")
        do {
            let payload = try JSONEncoder().encode(data)
            try payload.write(to: Self.saveURL, options: .atomic)
            log.info("save ok \(self.state.clock.tick) ticks at \(Self.saveURL.path, privacy: .public)")
            DebugState.shared.autosaveHash = StateHash.hex(state)
            return true
        } catch {
            log.error("save failed: \(String(describing: error))")
            DebugState.shared.autosaveHash = "ERR \(String(describing: error).prefix(80))"
            return false
        }
    }

    /// Restores a saved mid-night game. Returns false (and keeps the
    /// current game) when no save exists or it fails to decode.
    @discardableResult
    public func resume() -> Bool {
        guard let payload = try? Data(contentsOf: Self.saveURL) else {
            Logger(subsystem: "com.example.night-market", category: "save").error("resume: no save file")
            DebugState.shared.autosaveHash = "NOFILE"
            return false
        }
        do {
            let data = try JSONDecoder().decode(SaveData.self, from: payload)
            let decodedHash = StateHash.hex(data.state)
            if decodedHash != data.hash {
                Logger(subsystem: "com.example.night-market", category: "save")
                    .error(
                        "resume decode hash mismatch: \(decodedHash, privacy: .public) vs \(data.hash, privacy: .public)"
                    )
                DebugState.shared.autosaveHash = "DECODE-MISMATCH \(decodedHash) vs \(data.hash)"
            }
            stop()
            state = data.state
            rng = data.rng
            nightNumber = data.nightNumber
            servesTotal = data.servesTotal
            results = nil
            selectedStall = nil
            heatmap = Array(repeating: 0, count: state.grid.width * state.grid.height)
            scene.rebuild(with: state)
            scene.marketDelegate = self
            publishHud()
            start()
            Logger(subsystem: "com.example.night-market", category: "save")
                .info("resume ok \(self.state.clock.tick) ticks")
            return true
        } catch {
            Logger(subsystem: "com.example.night-market", category: "save")
                .error("resume decode failed: \(String(describing: error))")
            DebugState.shared.autosaveHash = "DECODE-ERR \(String(describing: error).prefix(60))"
            return false
        }
    }

    public func deleteSave() {
        try? FileManager.default.removeItem(at: Self.saveURL)
    }

    // MARK: - UI-test affordances (never set by gameplay)

    /// -uitest-autolane: paints the canonical gate-to-plaza lane at tick 600
    /// so headless runs (Mac screenshot evidence) have player edits without
    /// synthesized mouse events.
    private var laneApplied = false
    private func autoLaneIfNeeded() {
        guard !laneApplied, state.clock.tick >= 600, state.usedBudget == 0 else { return }
        laneApplied = true
        let lane = (0..<12).map { Tile(col: $0, row: 9) }
        apply(.paintWalkway(lane))
    }

    /// -uitest-stress: injects 600 synthetic customers onto the plaza so the
    /// debug overlay's FPS readout can be measured under a real crowd load.
    public func injectStressCrowd(count: Int = 600) {
        var customers = state.customers
        var nextID = state.nextCustomerID
        let colors = StallColor.allCases
        // Scatter across the plaza block (rows 8..<13, cols 12..<20).
        let plazaTiles: [Tile] = (8..<13).flatMap { row in
            (12..<20).map { col in Tile(col: col, row: row) }
        }
        for i in 0..<count {
            let tile = plazaTiles[i % plazaTiles.count]
            let jitter = Int32((i * 37) % 600) - 300
            let customer = Customer(
                id: nextID,
                color: colors[i % colors.count],
                position: FixedPoint2(
                    x: Int32(tile.col) * 1024 + 512 + jitter,
                    y: Int32(tile.row) * 1024 + 512 + Int32((i * 53) % 600) - 300
                )
            )
            customers.append(customer)
            nextID += 1
        }
        state.customers = customers
        state.nextCustomerID = nextID
        publishHud()
        scene.sync(state: state)
    }

    public func start() {
        guard tickTimer == nil else { return }
        audioMixer?.start()
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.stepFrame()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        tickTimer = timer
    }

    public func stop() {
        tickTimer?.invalidate()
        tickTimer = nil
        audioMixer?.stop()
    }

    /// The audio engine, created once. UI-test launches keep audio off so
    /// headless runs never open an audio session.
    private lazy var audioMixer: AudioMixer? = {
        let underUITest = ProcessInfo.processInfo.arguments.contains { $0.hasPrefix("-uitest") }
        guard !underUITest else { return nil }
        return AudioMixer()
    }()

    /// One 30 Hz frame: run `speedMultiplier` simulation ticks.
    public func stepFrame() {
        guard !state.isPaused, state.pendingOffers.isEmpty, results == nil else {
            publishHud()
            return
        }
        // UI-test affordance: -uitest-fast advances 60 ticks per frame so a
        // full night runs in seconds under XCUITest. Never set by gameplay.
        let fastTicks = ProcessInfo.processInfo.arguments.contains("-uitest-fast") ? 60 : 0
        var events: [Event] = []
        for _ in 0..<(fastTicks > 0 ? fastTicks : state.speedMultiplier) {
            let (next, frameEvents) = Tick.advance(state: state, rng: &rng)
            state = next
            events.append(contentsOf: frameEvents)
            accumulateHeatmap()
            if state.clock.isNightOver { break }
        }
        handle(events)
        if ProcessInfo.processInfo.arguments.contains("-uitest-autolane") {
            autoLaneIfNeeded()
        }
        // Publish at ~10 Hz; every-frame publishing starves SpriteKit of
        // frame time under crowd load (400 customers, G2 perf check).
        frameCount += 1
        if frameCount % 3 == 0 || !state.pendingOffers.isEmpty {
            publishHud()
        }
        scene.sync(state: state)
    }

    private var frameCount = 0

    private func accumulateHeatmap() {
        for customer in state.customers {
            let tile = state.tileOf(customer.position)
            let index = tile.row * state.grid.width + tile.col
            guard heatmap.indices.contains(index) else { continue }
            heatmap[index] += 1
        }
    }

    private func handle(_ events: [Event]) {
        let autochoose = ProcessInfo.processInfo.arguments.contains("-uitest-autochoose")
        let autosave = ProcessInfo.processInfo.arguments.contains("-uitest-autosave")
        for event in events {
            switch event {
            case .served:
                servesTotal += 1
                audioMixer?.play(AudioEvent(kind: .serve, volume: 0.9, pitch: 1))
            case .hourReached:
                // UI-test affordance: accept the first offer immediately so
                // the night runs to the results screen without picker taps.
                if autochoose, let offer = state.pendingOffers.first {
                    if let (next, _) = try? Reducer.apply(.chooseUpgrade(offer.id), to: state, rng: &rng) {
                        state = next
                    }
                }
            case .overflowWarning:
                overflowCount += 1
                audioMixer?.play(AudioEvent(kind: .overflow, volume: 1.0, pitch: 1))
            case .nightEnded(let finalScore, let survived):
                let outcome = ProfileStore.NightOutcome(
                    served: servesTotal, survived: survived, finalScore: finalScore,
                    overflowCount: overflowCount, mapId: currentSetup.mapId,
                    modifier: currentSetup.modifier,
                    challenge: currentSetup.mode != .freePlay
                )
                let earned = ProfileStore.shared.applyNight(outcome)
                let unlockedName = earned.unlockedMaps.first.flatMap {
                    (try? BundledContent.map($0))?.name
                }
                results = ResultsSummary(
                    served: servesTotal, survived: survived,
                    finalScore: finalScore, nightNumber: nightNumber,
                    newAchievements: earned.achievements.map(\.title),
                    unlockedMapName: unlockedName
                )
                postNightLeaderboards(outcome: outcome, newAchievements: earned.achievements.map(\.id))
            default:
                break
            }
        }
        // UI-test affordance: autosave every half in-game hour so a relaunch
        // restores a known mid-night state. With -uitest-save-restart, the
        // save is immediately reloaded in-process (the Xcode UI-test harness
        // gives each XCUIApplication launch an empty data view, so a real
        // relaunch cannot observe the save there).
        let saveRestart = ProcessInfo.processInfo.arguments.contains("-uitest-save-restart")
        if autosave, state.clock.tick / 900 > lastAutosaveTick / 900 {
            // With -uitest-save-restart, hold the save until the walkway
            // paint has landed so the saved state includes player edits;
            // then pause, save, and reload in-process: the state hash
            // (which includes isPaused) must match the save verbatim.
            guard !saveRestart || state.usedBudget > 0 else { return }
            lastAutosaveTick = state.clock.tick
            if saveRestart { setPaused(true) }
            save()
            if saveRestart { resume() }
        }
    }

    private var lastAutosaveTick = -1

    private func publishHud() {
        budgetUsed = state.usedBudget
        budgetTotal = state.walkwayBudget
        score = state.score
        hour = state.clock.startHour + state.clock.hoursElapsed
        let minute = (state.clock.tick % state.clock.ticksPerHour) * 60 / state.clock.ticksPerHour
        clockMinutes = minute
        customerCount = state.customers.count
        paused = state.isPaused
        speed = state.speedMultiplier
        if case .rain = state.weather { raining = true } else { raining = false }
        pendingOffers = state.pendingOffers
        // Music follows the crowd (NM-P6.2): density + phase → stem mix.
        if let audio = audioMixer {
            let density = Double(state.customers.count) / MusicDirector.referenceCrowd
            let hourProgress = Double(state.clock.tick) / Double(state.clock.ticksPerHour * 12)
            audio.setMix(MusicDirector.mix(density: density, isRaining: state.weather.isRaining, hourProgress: hourProgress))
        }
        DebugState.shared.tick = state.clock.tick
        DebugState.shared.seed = seed
        DebugState.shared.stateHash = StateHash.digest(state)
        DebugState.shared.stateHashHex = StateHash.hex(state)
        // VoiceOver queue summary (NM-P8.2): a spoken snapshot of every open
        // stall's queue and service progress.
        DebugState.shared.queueSummary = Self.queueSummary(for: state)
        writeDebugShotIfNeeded()
    }

    /// -uitest-shot <path>: writes a PNG of the whole window once, at the
    /// first results screen or paused frame. Used to capture slice evidence
    /// on Mac, where `screencapture` needs permissions the harness lacks.
    private var shotWritten = false
    private func writeDebugShotIfNeeded() {
        #if os(macOS)
            let args = ProcessInfo.processInfo.arguments
            let autosaveOn = args.contains("-uitest-autosave")
            let saveRecorded = DebugState.shared.autosaveHash != "-"
            let shotReady =
                results != nil
                || (state.isPaused && (!autosaveOn || saveRecorded))
            guard !shotWritten, shotReady,
                let argIndex = args.firstIndex(of: "-uitest-shot"),
                argIndex + 1 < args.count
            else { return }
            let path = ProcessInfo.processInfo.arguments[argIndex + 1]
            guard let contentView = scene.view?.window?.contentView else { return }
            let bounds = contentView.bounds
            guard let rep = contentView.bitmapImageRepForCachingDisplay(in: bounds) else { return }
            contentView.cacheDisplay(in: bounds, to: rep)
            guard let png = rep.representation(using: .png, properties: [:]) else { return }
            do {
                try png.write(to: URL(fileURLWithPath: path))
                shotWritten = true
                Logger(subsystem: "com.example.night-market", category: "save")
                    .info("shot written to \(path, privacy: .public)")
            } catch {
                Logger(subsystem: "com.example.night-market", category: "save")
                    .error("shot failed: \(String(describing: error))")
            }
        #endif
    }

    // MARK: - Player intents

    public func apply(_ action: Action) {
        guard results == nil else { return }
        do {
            let (next, _) = try Reducer.apply(action, to: state, rng: &rng)
            state = next
        } catch {
            // Illegal edits are silently ignored (the UI only offers legal ones).
        }
        publishHud()
        scene.sync(state: state)
    }

    public func chooseUpgrade(_ offer: UpgradeOffer) {
        apply(.chooseUpgrade(offer.id))
    }

    public func setPaused(_ value: Bool) {
        apply(value ? .pause : .resume)
    }

    public func setSpeed(_ value: Int) {
        apply(.setSpeed(value))
    }

    public func restart(seed: UInt64) {
        stop()
        state = GameState.initial(seed: seed, overrides: NightScenario.taipeiSlice.overrides)
        rng = SeededRNG(seed: seed)
        heatmap = Array(repeating: 0, count: state.grid.width * state.grid.height)
        servesTotal = 0
        overflowCount = 0
        nightNumber += 1
        results = nil
        selectedStall = nil
        scene.rebuild(with: state)
        scene.marketDelegate = self
        publishHud()
        start()
    }

    /// Starts a night from a player-chosen setup (NM-P5.2/P5.3): bundled map,
    /// its or the challenge's schedule, and the challenge modifier if any.
    public func start(setup: NightSetup) throws {
        let map = try BundledContent.map(setup.mapId)
        let schedule = try BundledContent.schedule(setup.scheduleId)
        guard schedule.spawnsPerHour.count == 12 else {
            throw NSError(domain: "GameController", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "schedule \(setup.scheduleId) must cover 12 hours",
            ])
        }
        stop()
        state = try GameState.initial(
            seed: setup.seed, map: map, contentVersion: "0.5.0",
            spawnRates: schedule.spawnsPerHour,
            modifiers: setup.modifier.map { [$0] } ?? []
        )
        state.assistMode = setup.assist
        currentSetup = setup
        rng = SeededRNG(seed: setup.seed)
        heatmap = Array(repeating: 0, count: state.grid.width * state.grid.height)
        servesTotal = 0
        overflowCount = 0
        nightNumber += 1
        results = nil
        selectedStall = nil
        scene.rebuild(with: state, palette: CityPalette.named(map.palette))
        scene.marketDelegate = self
        publishHud()
        start()
    }

    public var stateHashHex: String { StateHash.hex(state) }

    // MARK: - MarketSceneDelegate

    public func sceneDidRequestPaint(_ tiles: [Tile]) {
        apply(.paintWalkway(tiles))
    }

    public func sceneDidRequestErase(_ tiles: [Tile]) {
        apply(.eraseWalkway(tiles))
    }

    public func sceneDidRequestPlace(_ kind: FixtureKind, at tile: Tile) {
        apply(.placeFixture(kind, tile))
    }

    public func sceneDidRequestMove(_ fixtureID: Int, to tile: Tile) {
        apply(.moveFixture(fixtureID, tile))
    }

    public func sceneDidLongPressStall(_ stall: Stall) {
        selectedStall = stall
    }

    /// Long-press handler from the iOS input catcher (scene-space point).
    public func selectStall(nearScenePoint point: CGPoint) {
        guard let tile = scene.tile(at: point) else { return }
        selectedStall = state.stalls.first { $0.position == tile }
    }

    /// Long-press handler by tile (used by tests and tools).
    public func selectStall(at tile: Tile) {
        selectedStall = state.stalls.first { $0.position == tile }
    }
}

// MARK: - HUD summaries and leaderboard posting (NM-P7.1, NM-P8.2)

extension GameController {
    /// "Noodles: 2 waiting, cooking, halfway. Tea: empty. …" for VoiceOver.
    static func queueSummary(for state: GameState) -> String {
        let open = state.stalls.filter(\.isOpen)
        guard !open.isEmpty else { return "Market closed" }
        let parts = open.map { stall -> String in
            let name = stall.color.debugName.capitalized
            let waiting = stall.queue.count
            let cooking: String
            if stall.serviceProgress > 0 {
                let pct = Int((Double(stall.serviceProgress) / Double(stall.serviceTicks) * 10).rounded())
                cooking = "cooking, \(pct * 10) percent done"
            } else {
                cooking = "idle"
            }
            let wait = waiting == 1 ? "1 waiting" : "\(waiting) waiting"
            return "\(name): \(wait), \(cooking)"
        }
        return parts.joined(separator: ". ")
    }

    /// The scores/achievements poster: real GameKit off UI tests, the
    /// recording fake under them so runs stay deterministic.
    var poster: ScoresPosting {
        let underUITest = ProcessInfo.processInfo.arguments.contains { $0.hasPrefix("-uitest") }
        return underUITest ? MockPoster() : GameCenterPoster()
    }

    /// Fires the night's leaderboard and achievement posts.
    func postNightLeaderboards(outcome: ProfileStore.NightOutcome, newAchievements: [String]) {
        let challenge: NightOutcomeSummary.Challenge?
        if outcome.challenge {
            challenge = currentSetup.mode == .daily ? .daily : .weekly
        } else {
            challenge = nil
        }
        let summary = NightOutcomeSummary(
            mapId: outcome.mapId, finalScore: outcome.finalScore,
            challenge: challenge, modifierId: outcome.modifier?.rawValue
        )
        let plan = LeaderboardPlan.posts(for: summary, newAchievements: newAchievements)
        for score in plan.scores { poster.post(score) }
        for id in plan.achievements { poster.reportAchievement(id: id, percentComplete: 100) }
        DebugState.shared.postsCount = plan.scores.count + plan.achievements.count
    }
}
