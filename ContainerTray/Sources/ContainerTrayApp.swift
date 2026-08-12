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
        // MenuBarExtra forces symbol images to render as a monochrome
        // template regardless of foregroundColor/renderingMode, so a colored
        // icon has to be built as a non-template NSImage instead.
        if manager.hasRunningContainer {
            return coloredIcon(.systemGreen, accessibilityDescription: "Containers running")
        }
        if manager.hasFailure {
            return coloredIcon(.systemRed, accessibilityDescription: "Container error")
        }
        return Image(systemName: "server.rack")
    }

    private func coloredIcon(_ color: NSColor, accessibilityDescription: String) -> Image {
        let configuration = NSImage.SymbolConfiguration(paletteColors: [color])
        let nsImage = NSImage(systemSymbolName: "server.rack", accessibilityDescription: accessibilityDescription)?
            .withSymbolConfiguration(configuration)
        nsImage?.isTemplate = false
        return Image(nsImage: nsImage ?? NSImage())
    }
}
