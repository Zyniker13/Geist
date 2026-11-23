/// OR Shared — shared types and helpers.
import SwiftUI

/// Shared debug-overlay state (S0.7). The simulation layer updates these values;
/// the overlay renders them. Real values arrive with the P1 engine; the frame
/// below shows live zeros until then.
@MainActor
public final class DebugState: ObservableObject {
    public static let shared = DebugState()
    @Published public var isVisible = false
    @Published public var fps: Int = 0
    @Published public var tick: Int = 0
    @Published public var seed: UInt64 = 0
    @Published public var stateHash: UInt64 = 0
    /// Hex form of the current state hash (matches the sim's hash format).
    @Published public var stateHashHex: String = "-"

    /// Process-start reference for the cold-start metric (G8).
    public var bornUptime: TimeInterval = ProcessInfo.processInfo.systemUptime

    public init() {}
}

/// Main content view: a placeholder menu that proves the app shell builds and
/// launches on both platforms; the schematic board replaces this in P2.
public struct ContentView: View {
    @StateObject private var debug = DebugState.shared

    public init() {}

    public var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 12) {
                Text("Orrery")
                    .font(.largeTitle.bold())
                    .accessibilityIdentifier("title")
                Text("Brass rings, two players, one sun.")
                    .foregroundStyle(.secondary)
                Text("P0 scaffold — gameplay arrives in P1/P2.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(24)

            if debug.isVisible {
                DebugOverlay()
                    .padding(8)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .padding(12)
            }
        }
        #if os(iOS)
            .onAppear { DebugGestures.install() }
        #else
            .overlay(
                Button("") { debug.isVisible.toggle() }
                    .keyboardShortcut("d", modifiers: [.command, .shift])
                    .frame(width: 0, height: 0)
                    .opacity(0.001)
                    .accessibilityHidden(true)
            )
        #endif
    }
}

/// FPS / tick / seed / state-hash readout (S0.7).
struct DebugOverlay: View {
    @ObservedObject private var debug = DebugState.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("DEBUG").font(.caption2.bold()).foregroundStyle(.secondary)
            Text("FPS  \(debug.fps)").font(.system(.caption, design: .monospaced))
                .accessibilityIdentifier("debug-fps")
            Text("TICK \(debug.tick)").font(.system(.caption, design: .monospaced))
                .accessibilityIdentifier("debug-tick")
            Text("SEED \(debug.seed)").font(.system(.caption, design: .monospaced))
            Text("HASH \(debug.stateHashHex)").font(.system(.caption, design: .monospaced))
                .accessibilityIdentifier("debug-hash")
        }
    }
}

#if os(iOS)
    import UIKit

    /// Installs the three-finger double-tap debug toggle on the key window (S0.7).
    @MainActor
    enum DebugGestures {
        private static var installed = false

        static func install() {
            guard !installed else { return }
            installed = true
            let scenes = UIApplication.shared.connectedScenes
            guard let window = scenes.compactMap({ ($0 as? UIWindowScene)?.keyWindow }).first else { return }
            let tap = UITapGestureRecognizer(target: DebugTapTarget.shared, action: #selector(DebugTapTarget.handle))
            tap.numberOfTouchesRequired = 3
            tap.numberOfTapsRequired = 2
            tap.cancelsTouchesInView = false
            window.addGestureRecognizer(tap)
            startFPSMonitor()
        }

        /// Live FPS via CADisplayLink.
        private static func startFPSMonitor() {
            var last = CACurrentMediaTime()
            var frames = 0
            var accumulated: TimeInterval = 0
            let link = CADisplayLink(target: DebugTapTarget.shared, selector: #selector(DebugTapTarget.frameTick))
            link.add(to: .main, forMode: .common)
            DebugTapTarget.shared.onFrame = {
                frames += 1
                let now = CACurrentMediaTime()
                accumulated += now - last
                last = now
                if accumulated >= 1 {
                    DebugState.shared.fps = Int((Double(frames) / accumulated).rounded())
                    frames = 0
                    accumulated = 0
                }
            }
        }
    }

    /// objc target for the window gesture and the display-link callback.
    @MainActor
    final class DebugTapTarget: NSObject {
        static let shared = DebugTapTarget()
        var onFrame: (() -> Void)?

        @objc func handle() {
            DebugState.shared.isVisible.toggle()
        }

        @objc func frameTick() {
            onFrame?()
        }
    }
#endif
