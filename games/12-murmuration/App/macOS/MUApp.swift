import SwiftUI

@main
struct MUApp: App {
    @StateObject private var debug = DebugState()

    var body: some Scene {
        WindowGroup {
            MenuView()
                .environmentObject(debug)
                .background(
                    Button("") { debug.toggle() }
                        .keyboardShortcut("d", modifiers: [.command, .shift])
                        .opacity(0)
                        .frame(width: 0, height: 0)
                        .accessibilityHidden(true)
                )
                .task { debug.loadFromLaunchArguments() }
        }
        .commands {
            // ⌘⇧D also lives in the menu bar so the shortcut is discoverable (S0.7).
            CommandMenu("Debug") {
                Button("Toggle Debug Overlay") { debug.toggle() }
                    .keyboardShortcut("d", modifiers: [.command, .shift])
            }
        }
    }
}
