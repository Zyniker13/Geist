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
import MURender

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
    /// Ticks advanced per display frame in fast-forward (UI tests).
    let ticksPerFrame: Int

    @Published private(set) var state: GameState
    @Published private(set) var day = 1
    @Published private(set) var paused = false
    @Published private(set) var dayEnded = false
    @Published private(set) var finished = false
    @Published private(set) var results: [DayResult] = []
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
        save: SavedGame? = nil
    ) {
        self.region = region
        self.totalDays = totalDays
        self.autoplay = autoplay
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
            self.previousBirds = fresh.birds
        }
        if autoplay {
            self.autoplayer = Autoplayer()
        }
        startDayIfNeeded()
    }

    // MARK: - Day lifecycle

    private func startDayIfNeeded() {
        // Fresh day (not a resume): spawn the rival and seed the trace.
        if state.tick == 0 {
            for action in RegionStarter.startingActions(for: region) {
                apply(action)
            }
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
        if ticksPerFrame > 1 {
            for _ in 0..<ticksPerFrame where !dayEnded && !finished {
                runOneTick()
                ran = true
            }
        } else {
            pendingTicks += now - lastFrameTime
            let budget = Self.tickInterval
            var steps = Int(pendingTicks / budget)
            pendingTicks -= Double(steps) * budget
            steps = min(steps, 4)  // never spiral on a slow frame
            for _ in 0..<steps where !dayEnded && !finished {
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
        previousBirds = state.birds
        falconPrev = state.falcons.map { SIMD2(Float($0.currentX), Float($0.currentY)) }

        if autoplay, let action = autoplayer?.action(for: state) {
            apply(action)
        }
        var gentle = rival
        if let action = gentle.action(for: state) {
            rival = gentle
            apply(action)
        }

        let (next, events) = applyTick(to: state, rng: &rng)
        state = next
        appendTrace()
        for event in events {
            handle(event)
        }
        if dayEnded {
            finishDay()
        }
    }

    private func appendTrace() {
        let path = state.leaderPaths[0]
        trace.append(TracePoint(
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
            return
        }
        day += 1
        state = region.makeGameState()
        rng = SeededRNG(seed: region.seed)
        previousBirds = state.birds
        falconPrev = []
        trace = []
        dayEnded = false
        autoplayer = autoplay ? Autoplayer() : nil
        rival = GentleRival()
        startDayIfNeeded()
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
        rival = GentleRival()
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
