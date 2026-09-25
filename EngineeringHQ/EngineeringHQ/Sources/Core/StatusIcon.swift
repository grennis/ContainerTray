import AppKit
import SwiftUI

enum StatusIcon {
    /// Menu bar and menu item images render SF Symbols as monochrome
    /// templates, ignoring `foregroundColor`/`renderingMode`. A colored icon
    /// has to be built as a non-template `NSImage` with a palette color and
    /// wrapped in `Image(nsImage:)`.
    static func colored(_ systemName: String, color: NSColor, accessibilityDescription: String? = nil) -> Image {
        let configuration = NSImage.SymbolConfiguration(paletteColors: [color])
        let nsImage = NSImage(systemSymbolName: systemName, accessibilityDescription: accessibilityDescription)?
            .withSymbolConfiguration(configuration)
        nsImage?.isTemplate = false
        return Image(nsImage: nsImage ?? NSImage())
    }
}

/// Small dot shown beside a module's name in the sidebar.
struct HealthBadge: View {
    let health: ModuleHealth

    var body: some View {
        switch health {
        case .idle:
            EmptyView()
        case .ok, .active:
            Circle().fill(Color.green).frame(width: 8, height: 8)
                .accessibilityLabel(health == .active ? "Running" : "Healthy")
        case .failing:
            Circle().fill(Color.red).frame(width: 8, height: 8)
                .accessibilityLabel("Failing")
        }
    }
}
