import AppKit
import SwiftUI

enum MainWindow {
    static let id = "main"

    /// Shows the main window, bringing back the Dock icon that is hidden
    /// while the window is closed.
    static func open(using openWindow: OpenWindowAction) {
        NSApp.setActivationPolicy(.regular)
        openWindow(id: id)
        NSApp.activate(ignoringOtherApps: true)
    }
}

/// Sidebar of modules on the left, the selected module's detail on the right.
struct MainWindowView: View {
    @EnvironmentObject private var registry: ModuleRegistry
    @SceneStorage("selectedModuleID") private var selectedModuleID: String?

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedModuleID) {
                ForEach(registry.modules.indices, id: \.self) { index in
                    let module = registry.modules[index]
                    Label {
                        HStack {
                            Text(module.title)
                            Spacer()
                            HealthBadge(health: module.health)
                        }
                    } icon: {
                        Image(systemName: module.systemImage)
                    }
                    .tag(module.id)
                }
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 190, max: 260)
        } detail: {
            if let module = registry.module(id: selectedModuleID) {
                module.makeDetailView()
                    .id(module.id)
            } else {
                Text("Select a module")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 760, minHeight: 420)
        .onAppear {
            if registry.module(id: selectedModuleID) == nil {
                selectedModuleID = registry.modules.first?.id
            }
            NSApp.setActivationPolicy(.regular)
        }
        .onDisappear {
            // The app keeps running in the menu bar after the window closes;
            // drop the Dock icon until the window is opened again.
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
