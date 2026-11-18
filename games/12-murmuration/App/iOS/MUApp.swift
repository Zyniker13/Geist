import SwiftUI

@main
struct MUApp: App {
    @StateObject private var debug = DebugState()

    var body: some Scene {
        WindowGroup {
            MenuView()
                .environmentObject(debug)
                .overlay(DebugGestureCatcher(onThreeFingerDoubleTap: { debug.toggle() }))
                .task { debug.loadLaunchFlags() }
        }
    }
}
