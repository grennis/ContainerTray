import SwiftUI
import AppKit

@main
struct ContainerTrayApp: App {
    @StateObject private var manager = ContainerManager()

    var body: some Scene {
        MenuBarExtra {
            ContainerMenuView()
                .environmentObject(manager)
        } label: {
            menuBarIcon
        }
        .menuBarExtraStyle(.menu)
    }

    private var menuBarIcon: Image {
        guard manager.hasRunningContainer else {
            return Image(systemName: "cylinder")
        }
        // MenuBarExtra forces symbol images to render as a monochrome
        // template regardless of foregroundColor/renderingMode, so the
        // colored icon has to be built as a non-template NSImage instead.
        let configuration = NSImage.SymbolConfiguration(paletteColors: [.systemGreen])
        let nsImage = NSImage(systemSymbolName: "cylinder.fill", accessibilityDescription: "Containers running")?
            .withSymbolConfiguration(configuration)
        nsImage?.isTemplate = false
        return Image(nsImage: nsImage ?? NSImage())
    }
}
