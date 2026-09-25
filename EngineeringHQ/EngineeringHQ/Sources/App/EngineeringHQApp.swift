import AppKit
import SwiftUI

@main
struct EngineeringHQApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var registry = ModuleRegistry.makeDefault()

    var body: some Scene {
        Window("Engineering HQ", id: MainWindow.id) {
            MainWindowView()
                .environmentObject(registry)
        }
        .defaultSize(width: 1000, height: 640)

        MenuBarExtra {
            MenuBarContent()
                .environmentObject(registry)
        } label: {
            MenuBarIcon.image(for: registry.overallHealth)
        }
        .menuBarExtraStyle(.menu)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Closing the window leaves the app running in the menu bar.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
