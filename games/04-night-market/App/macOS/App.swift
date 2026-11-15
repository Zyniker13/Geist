/// NM macOS — Night Market macOS entry point.
/// The Game menu (NM-P7.4): pause/resume, save, new night, and the debug
/// overlay, posted through NotificationCenter so the SwiftUI scene stays
/// the single owner of the controller.
import SwiftUI

extension Notification.Name {
    static let nmTogglePause = Notification.Name("nm.togglePause")
    static let nmSave = Notification.Name("nm.save")
    static let nmNewNight = Notification.Name("nm.newNight")
    static let nmToggleDebug = Notification.Name("nm.toggleDebug")
}

struct GameCommands: Commands {
    var body: some Commands {
        CommandMenu("Game") {
            Button("Pause or Resume") {
                NotificationCenter.default.post(name: .nmTogglePause, object: nil)
            }
            .keyboardShortcut("p", modifiers: .command)
            Button("Save Night") {
                NotificationCenter.default.post(name: .nmSave, object: nil)
            }
            .keyboardShortcut("s", modifiers: .command)
            Button("New Night") {
                NotificationCenter.default.post(name: .nmNewNight, object: nil)
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
            Divider()
            Button("Toggle Debug Overlay") {
                NotificationCenter.default.post(name: .nmToggleDebug, object: nil)
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])
        }
    }
}

@main
struct NMmacOS: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            GameCommands()
        }
        .windowResizability(.contentMinSize)
    }
}
