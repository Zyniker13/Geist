/// OR macOS — Orrery macOS entry point.
import SwiftUI

@main
struct ORAppMac: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentMinSize)
    }
}
