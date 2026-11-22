// Murmuration app — the game model (P2 vertical slice).
//
// Owns one day of engine state at a time: the ROADMAP's engine never resets
// its tick and fires day-end every tick past 4800, so multi-day play is one
// fresh GameState per day. The model runs ticks on the display frame (one
// 30 Hz tick per 1/30 s, or N ticks per frame in fast-forward), applies the
// day-start rival split, drives the Autoplayer and GentleRival in autoplay,
// and exposes player actions from either platform's input layer.

import SwiftUI
import MUCore
import MUContent
import MUAI
import MUMeta
import MURender

/// File-backed trace mirror for the UI-test gate diagnostics: stdout of a
/// launched app is not captured in the macOS xcodebuild log, so the gate
/// tests read the mirrored file instead. No-op unless `-uitest-trace` is
/// in the launch args.
enum MUTrace {
    #if os(macOS)
        static let filePath = "/tmp/mu-uitest-trace.log"
    #endif
    // All trace writers run on the main thread (Shell, PlayView, the MTKView
    // delegate); the flag only gates a one-time truncate.
    nonisolated(unsafe) private static var fresh = false

    static func log(_ line: String) {
        guard MULaunch.arguments().contains("-uitest-trace") else { return }
        print("[MU] \(line)")
        fflush(stdout)
        #if os(macOS)
            if !fresh {
                fresh = true
                if !FileManager.default.createFile(atPath: filePath, contents: nil) {
                    MULaunch.note("trace: createFile failed at \(filePath)")
                }
            }
            if let fh = FileHandle(forWritingAtPath: filePath) {
                defer { try? fh.close() }
                fh.seekToEndOfFile()
                fh.write(Data("[MU] \(line)\n".utf8))
            } else {
                MULaunch.note("trace: cannot open \(filePath) for append")
            }
        #endif
    }
}

/// One completed day's tally, shown on the results card (R-13).
struct DayResult: Equatable, Identifiable {
    var id: Int { day }
    var day: Int
    var playerRoosts: Int
    var rivalRoosts: Int
    var birdsAlive: Int
    var winner: Int  // 0 player, 1 rival, -1 none
}

/// The running game. Confined to the main actor; the render coordinator and
/// SwiftUI both touch it there.
@MainActor
final class GameModel: ObservableObject {
    let region: Region
    let totalDays: Int
    let autoplay: Bool
    /// Local two-flock versus (MU-P3.3): the rival flock is human-driven, so
    /// GentleRival is disabled and each touch routes to the nearest flock.
    let versus: Bool
    /// The rival pilot's difficulty tier (MU-P4.1).
    let rivalDifficulty: RivalDifficulty
    /// The daily challenge's modifier when this session is the daily
    /// (MU-P5.2); nil in every other mode.
    let dailyModifier: DailyModifier?
    /// Ticks advanced per display frame in fast-forward (UI tests).
    let ticksPerFrame: Int

    @Published private(set) var state: GameState
    @Published private(set) var day = 1
    @Published private(set) var paused = false
    @Published private(set) var dayEnded = false
    @Published private(set) var finished = false
    @Published private(set) var results: [DayResult] = []
    /// Session counters for the meta layer (MU-P5.3): peak flock size,
    /// cumulative starvation deaths, roosts claimed at each dusk.
    private(set) var peakFlock = 0
    private(set) var birdsStarved = 0
    private(set) var roostsClaimed = 0
    /// The campaign stage this session plays (nil outside campaign mode).
    let campaignStage: Int?
    @Published var fps = 0
    /// Rolling mean frame build time in milliseconds (tick + render encode).
    @Published var frameMs: Double = 0
    /// State hash, refreshed on the cadence below (UI-test hash checks).
    @Published var hashLabel = ""

    /// When set, the model self-pauses at that tick for two seconds (the
    /// pause/resume checkpoint-hash UI test).
    var pauseAtTick: Int?
    /// When true, `hashLabel` refreshes every 30 ticks and at pause/finish.
    var hashUpdates = false

    /// The five-step tutorial (P3.2). When present, the model drives it:
    /// the `tutorialDriver` issues the current step's action each tick and
    /// the `tutorialEngine` samples the post-tick state to advance the step.
    @Published private(set) var tutorialStep: Int = -1
    @Published private(set) var tutorialComplete = false
    /// The tutorial's steps (for the HUD banner). Empty when no tutorial.
    @Published private(set) var tutorialSteps: [TutorialStep] = []
    private var tutorialEngine: TutorialEngine?
    private var tutorialDriver = TutorialDriver()

    private var rng: SeededRNG
    private var autoplayer: Autoplayer?
    private var rival = GentleRival()
    private var previousBirds: BirdSoA
    private var falconPrev: [SIMD2<Float>] = []
    private var trace: [TracePoint] = []
    private var pendingTicks = 0.0
    private var lastFrameTime: Double = 0
    private var frameTimes: [Double] = []
    private var dayEndPauseTicks = 0
    private var selfPaused = false
    private var selfResumeTime: Double = 0

    static let tickInterval: Double = 1.0 / 30.0
    /// The leader trace keeps one second of samples (30 ticks at 30 Hz).
    static let traceLength = 30

    init(
        region: Region,
        totalDays: Int = 1,
        autoplay: Bool = false,
        ticksPerFrame: Int = 1,
        save: SavedGame? = nil,
        tutorial: Tutorial? = nil,
        versus: Bool = false,
        rivalDifficulty: RivalDifficulty? = nil,
        dailyModifier: DailyModifier? = nil,
        campaignStage: Int? = nil
    ) {
        self.region = region
        self.totalDays = totalDays
        self.autoplay = autoplay
        self.versus = versus
        self.rivalDifficulty = rivalDifficulty ?? region.rivalDifficulty
        self.dailyModifier = dailyModifier
        self.campaignStage = campaignStage
        self.ticksPerFrame = max(ticksPerFrame, 1)
        if let save = save, save.regionID == region.id {
            self.state = save.state
            self.day = save.day
            self.rng = save.rng
            self.autoplayer = save.autoplayer
            self.rival = save.rival
            self.previousBirds = save.state.birds
        } else {
            let fresh = region.makeGameState()
            self.state = fresh
            self.rng = SeededRNG(seed: region.seed)
            self.rival = GentleRival(difficulty: self.rivalDifficulty)
            self.previousBirds = fresh.birds
        }
        if autoplay {
            self.autoplayer = Autoplayer()
        }
        if let tutorial {
            self.tutorialEngine = TutorialEngine(steps: tutorial.steps)
            self.tutorialStep = 0
            self.tutorialSteps = tutorial.steps
            MUTrace.log("tutorial: loaded \(tutorial.steps.count) steps region=\(tutorial.region)")
        }
        startDayIfNeeded()
    }

    // MARK: - Day lifecycle

    private func startDayIfNeeded() {
        // Fresh day (not a resume): spawn the rival and seed the trace.
        if state.tick == 0 {
            // Versus and rival modes suppress the R-5 auto-merge: the
            // day-start split defines the two flocks, both starting
            // coincident, so the proximity rule would collapse them within
            // 30 ticks — merging the two players in versus, or absorbing
            // the rival's flock into the player's in rival mode (MU-P4.1).
            state.versusMergeSuppressed = versus || region.hasRival
            for action in RegionStarter.startingActions(
                for: region, difficulty: rivalDifficulty
            ) {
                apply(action)
            }
            MUTrace.log(
                "day-start: region=\(region.id) versus=\(versus) subFlocks=\(state.subFlockCount) paths=\(state.leaderPaths.count)"
            )
            trace = []
            if autoplay, var ai = autoplayer {
                if let action = ai.action(for: state) {
                    autoplayer = ai
                    apply(action)
                }
            }
        }
    }

    /// Advance the simulation to match wall-clock time (or fast-forward).
    /// Returns true when a tick ran this frame.
    @discardableResult
    func advanceFrame(now: Double) -> Bool {
        if paused || finished {
            lastFrameTime = now
            refreshHashIfNeeded(force: true)
            return false
        }
        if selfPaused {
            if now < selfResumeTime {
                lastFrameTime = now
                return false
            }
            selfPaused = false
            pauseAtTick = nil
        }
        if let at = pauseAtTick, state.tick >= at {
            selfPaused = true
            selfResumeTime = now + 2.0
            lastFrameTime = now
            refreshHashIfNeeded(force: true)
            return false
        }
        if lastFrameTime == 0 { lastFrameTime = now }
        var ran = false
        // The loop condition must not exclude dayEnded: runOneTick routes
        // day-end ticks through advanceAfterDayEnd (the card pause, then the
        // next day). Excluding them stalled autoplay forever after day 1.
        if ticksPerFrame > 1 {
            for _ in 0..<ticksPerFrame where !finished {
                runOneTick()
                ran = true
            }
        } else {
            pendingTicks += now - lastFrameTime
            let budget = Self.tickInterval
            var steps = Int(pendingTicks / budget)
            pendingTicks -= Double(steps) * budget
            steps = min(steps, 4)  // never spiral on a slow frame
            for _ in 0..<steps where !finished {
                runOneTick()
                ran = true
            }
        }
        lastFrameTime = now
        return ran
    }

    /// Rolling mean of the full frame build cost in milliseconds (tick run +
    /// scene update + render encode). The render coordinators call this with
    /// the timestamp from the top of their draw callback.
    func recordFrameCost(started: Double) {
        let ms = (CACurrentMediaTime() - started) * 1000
        frameTimes.append(ms)
        if frameTimes.count > 30 {
            frameTimes.removeFirst(frameTimes.count - 30)
        }
        frameMs = frameTimes.reduce(0, +) / Double(max(frameTimes.count, 1))
    }

    /// Run exactly one engine tick.
    func runOneTick() {
        if dayEnded {
            advanceAfterDayEnd()
            return
        }
        let tickStart = CACurrentMediaTime()
        previousBirds = state.birds
        falconPrev = state.falcons.map { SIMD2(Float($0.currentX), Float($0.currentY)) }

        if autoplay, let action = autoplayer?.action(for: state) {
            apply(action)
        }
        // GentleRival (P2.5): the rival pilot drives the rival flock. In
        // versus mode (MU-P3.3) the rival is human-driven, so skip it.
        if !versus {
            var gentle = rival
            if let action = gentle.action(for: state) {
                rival = gentle
                apply(action)
            }
        }

        // Tutorial (P3.2): issue the current step's action before the tick so
        // it takes effect this tick; the engine samples the post-tick state.
        if !tutorialComplete,
           let step = tutorialEngine?.currentStep,
           let action = tutorialDriver.action(goal: step.goal, state: state) {
            apply(action)
        }

        let (next, events) = applyTick(to: state, rng: &rng)
        state = next
        appendTrace()
        // Meta counters (MU-P5.3): peak flock and starvation total.
        if state.birds.count > peakFlock { peakFlock = state.birds.count }
        for event in events {
            handle(event)
            if case .energy(.starve(_, let dead)) = event { birdsStarved += dead }
        }
        advanceTutorial()
        if dayEnded {
            finishDay()
            playbackTrace("day end at tick \(state.tick): pause=\(dayEndPauseTicks) results=\(results.count)")
        }
        let tickMs = (CACurrentMediaTime() - tickStart) * 1000
        if tickMs > 250 {
            playbackTrace("SLOW TICK day=\(day) tick=\(state.tick): \(Int(tickMs))ms birds=\(state.birds.count)")
        }
        if state.tick - lastTraceTick >= 300 || state.tick == 1 {
            lastTraceTick = state.tick
            playbackTrace(
                "day=\(day) tick=\(state.tick) birds=\(state.birds.count) fps=\(fps) dayEnded=\(dayEnded) finished=\(finished)"
            )
        }
    }

    /// Sample the post-tick state to advance the tutorial (P3.2). Called once
    /// per tick after the simulation step. When a step's goal is met the
    /// engine advances; when the last step completes, `tutorialComplete` is
    /// set and the UI shows the completion banner.
    private func advanceTutorial() {
        guard var engine = tutorialEngine, !tutorialComplete else { return }
        let completed = engine.progress(state: state)
        tutorialStep = engine.stepIndex
        tutorialEngine = engine
        guard completed else { return }
        if engine.isComplete {
            tutorialComplete = true
            MUTrace.log("tutorial.complete")
        } else {
            MUTrace.log("tutorial.step \(engine.stepIndex) \(engine.currentStep?.id ?? "")")
        }
    }

    private func appendTrace() {
        let path = state.leaderPaths[0]
        trace.append(
            TracePoint(
                x: Float(path.currentX), y: Float(path.currentY),
                age: 0
            ))
        if trace.count > Self.traceLength {
            trace.removeFirst(trace.count - Self.traceLength)
        }
        for i in trace.indices {
            trace[i].age = Float(trace.count - 1 - i) / Float(Self.traceLength)
        }
    }

    private func handle(_ event: GameEvent) {
        switch event {
        case .dayEnd:
            dayEnded = true
            recordMetaForDay()
        case .roost(.dayEnd(let player, let rival)):
            recordResult(playerRoosts: player, rivalRoosts: rival)
        case .victory(let winner):
            if var last = results.last {
                last.winner = winner
                results[results.count - 1] = last
            }
        default:
            break
        }
    }

    private func recordResult(playerRoosts: Int, rivalRoosts: Int) {
        let result = DayResult(
            day: day,
            playerRoosts: playerRoosts,
            rivalRoosts: rivalRoosts,
            birdsAlive: state.birds.count,
            winner: -1
        )
        if let index = results.firstIndex(where: { $0.day == day }) {
            results[index] = result
        } else {
            results.append(result)
        }
        roostsClaimed = playerRoosts
    }

    /// Fold this day into the meta layer (MU-P5): campaign carry, daily
    /// best, lifetime stats. UI-test runs (autoplay/fast-forward) record
    /// too — the meta layer is part of shipped behavior.
    private func recordMetaForDay() {
        roostsClaimed = max(roostsClaimed, 0)
        let outcome = SessionOutcome(
            peakFlock: peakFlock,
            roostsClaimed: roostsClaimed,
            birdsStarved: birdsStarved,
            isVersus: versus,
            isDaily: dailyModifier != nil,
            isCampaignEnd: false
        )
        let dailyDayNumber = dailyModifier != nil
            ? DailyChallenge(date: DailyChallenge.epoch).dayNumber
            : nil
        _ = MetaStore.record(outcome, dayCompleted: true, dailyDayNumber: dailyDayNumber)
        if let stage = campaignStage {
            _ = MetaStore.recordCampaignStage(
                index: max(stage - 1, 0), endSize: state.birds.count
            )
        }
    }

    /// A day's tick counter passes 4800 exactly once (the model stops there),
    /// so the card shows immediately and the next day starts fresh.
    private func finishDay() {
        if autoplay || ticksPerFrame > 1 {
            dayEndPauseTicks = ticksPerFrame > 1 ? 1 : 45
        }
    }

    private func advanceAfterDayEnd() {
        if dayEndPauseTicks > 0 {
            dayEndPauseTicks -= 1
            return
        }
        guard day < totalDays else {
            finished = true
            // The final hash must be readable the moment the final card
            // appears: the test reads debug.hash right after game.final,
            // and the next advanceFrame may not run before it does.
            refreshHashIfNeeded(force: true)
            playbackTrace("finished: \(results.count) days recorded hash=\(hashLabel)")
            return
        }
        day += 1
        playbackTrace("day start: \(day)/\(totalDays)")
        state = region.makeGameState()
        rng = SeededRNG(seed: region.seed)
        previousBirds = state.birds
        falconPrev = []
        trace = []
        lastTraceTick = -1
        dayEnded = false
        autoplayer = autoplay ? Autoplayer() : nil
        rival = GentleRival(difficulty: rivalDifficulty)
        startDayIfNeeded()
    }

    /// Trace playback for the UI-test harness: stdout lines on a tick
    /// cadence and at every lifecycle edge, so a hung session can be
    /// diagnosed from the runner log.
    private var tracePlayback: Bool = false
    private var lastTraceTick = -1

    func enablePlaybackTrace() {
        tracePlayback = true
        playbackTrace("playview ready: ticksPerFrame=\(ticksPerFrame) totalDays=\(totalDays) autoplay=\(autoplay)")
    }

    func playbackTrace(_ line: String) {
        guard tracePlayback else { return }
        MUTrace.log(line)
    }

    // MARK: - Player actions

    func apply(_ action: GameAction) {
        let (next, _) = applyAction(action, to: state)
        state = next
    }

    func togglePause() {
        paused.toggle()
        if paused || finished {
            refreshHashIfNeeded(force: true)
        }
    }

    /// Manual advance from the results card (S2.2).
    func beginNextDay() {
        guard dayEnded, !finished else { return }
        dayEndPauseTicks = 0
        advanceAfterDayEnd()
    }

    func restart() {
        day = 1
        state = region.makeGameState()
        rng = SeededRNG(seed: region.seed)
        previousBirds = state.birds
        falconPrev = []
        trace = []
        results = []
        dayEnded = false
        finished = false
        paused = false
        autoplayer = autoplay ? Autoplayer() : nil
        rival = GentleRival(difficulty: rivalDifficulty)
        startDayIfNeeded()
    }

    // MARK: - Rendering handoff

    /// The scene for the renderer: this tick against the previous one.
    var scene: RenderScene {
        makeScene(state: state, previousBirds: previousBirds, falconPrev: falconPrev, trace: trace)
    }

    // MARK: - Save/resume (S2.4)

    func makeSave() -> SavedGame {
        SavedGame(
            regionID: region.id,
            day: day,
            state: state,
            rng: rng,
            autoplayer: autoplayer,
            rival: rival
        )
    }

    func saveLocally() {
        SavedGame.store(makeSave())
    }

    static func loadSave(regionID: String) -> SavedGame? {
        SavedGame.load(regionID: regionID)
    }

    // MARK: - Debug overlay feed

    private var lastHashTick = -1

    private func refreshHashIfNeeded(force: Bool) {
        guard hashUpdates || force else { return }
        if force || state.tick - lastHashTick >= 30 {
            lastHashTick = state.tick
            hashLabel = String(format: "%016llx", stateHash(state))
        }
    }
}
