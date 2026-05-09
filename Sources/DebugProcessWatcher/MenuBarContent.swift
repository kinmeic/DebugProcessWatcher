import AppKit
import SwiftUI

struct MenuBarContent: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Show Debug Processes") {
            openWindow(id: "main")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NotificationCenter.default.post(name: .refreshProcesses, object: nil)
            }
        }
        .keyboardShortcut("D", modifiers: .command)

        Button("Open Terminal") {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            task.arguments = [
                "-e", "tell application \"Terminal\"",
                "-e", "activate",
                "-e", "do script \"clear\"",
                "-e", "end tell"
            ]
            try? task.run()
        }

        Divider()

        Button("Quit") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}
