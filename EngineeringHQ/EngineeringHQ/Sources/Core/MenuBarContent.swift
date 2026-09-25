import AppKit
import SwiftUI

/// The menu shown when the menu bar icon is clicked: each module's items,
/// separated by dividers, then app-level commands.
struct MenuBarContent: View {
    @EnvironmentObject private var registry: ModuleRegistry
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ForEach(registry.modules.indices, id: \.self) { index in
            registry.modules[index].makeMenuContent()
            Divider()
        }

        Button("Open Engineering HQ") {
            MainWindow.open(using: openWindow)
        }
        .keyboardShortcut("o")

        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}

/// Menu bar icon: red when any module is failing, green when something is
/// running, otherwise the standard monochrome template.
struct MenuBarIcon {
    private static let symbol = "wrench.and.screwdriver"

    static func image(for health: ModuleHealth) -> Image {
        switch health {
        case .failing:
            return StatusIcon.colored(symbol, color: .systemRed, accessibilityDescription: "Engineering HQ: failing")
        case .active:
            return StatusIcon.colored(symbol, color: .systemGreen, accessibilityDescription: "Engineering HQ: running")
        case .idle, .ok:
            return Image(systemName: symbol)
        }
    }
}
