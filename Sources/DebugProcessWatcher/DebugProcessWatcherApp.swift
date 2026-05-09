import AppKit
import SwiftUI

@main
struct DebugProcessWatcherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent()
        } label: {
            if let menuBarIcon {
                Image(nsImage: menuBarIcon)
            } else {
                Image(systemName: "terminal")
            }
        }

        WindowGroup(id: "main") {
            ProcessListView()
                .frame(minWidth: 800, minHeight: 400)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 900, height: 500)
    }

    private var menuBarIcon: NSImage? {
        guard
            let icon1xURL = Bundle.main.url(
                forResource: "menu_icon_24",
                withExtension: "png",
                subdirectory: "MenuBarIcon.imageset"
            ),
            let icon2xURL = Bundle.main.url(
                forResource: "menu_icon_48",
                withExtension: "png",
                subdirectory: "MenuBarIcon.imageset"
            ),
            let icon1xData = try? Data(contentsOf: icon1xURL),
            let icon2xData = try? Data(contentsOf: icon2xURL),
            let icon1xRep = NSBitmapImageRep(data: icon1xData),
            let icon2xRep = NSBitmapImageRep(data: icon2xData)
        else {
            return nil
        }

        let image = NSImage(size: NSSize(width: 24, height: 24))
        image.addRepresentation(icon1xRep)
        image.addRepresentation(icon2xRep)
        image.isTemplate = true
        image.size = NSSize(width: 24, height: 24)
        return image
    }
}
