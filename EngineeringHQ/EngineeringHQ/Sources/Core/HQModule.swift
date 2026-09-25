import Combine
import SwiftUI

/// Summary state a module reports to the shell. The sidebar shows it next to
/// the module's name, and the menu bar icon reflects the most severe value
/// across all modules.
enum ModuleHealth: Int, Comparable {
    /// Nothing to report (not run yet, nothing running).
    case idle
    /// Last check succeeded.
    case ok
    /// Something the user started is running (for example a container).
    case active
    /// The module hit an error or a check failed.
    case failing

    static func < (lhs: ModuleHealth, rhs: ModuleHealth) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// One feature of Engineering HQ. Each module owns its state and supplies two
/// views: the detail pane shown in the main window, and the items it adds to
/// the menu bar menu. To add a feature, create a type conforming to this
/// protocol under `Modules/` and register it in `ModuleRegistry.makeDefault()`.
///
/// Modules are `ObservableObject`s so the shell can redraw the sidebar and
/// menu bar icon when `health` changes. The views a module returns should
/// hold the module as an `@ObservedObject` so they update on their own.
@MainActor
protocol HQModule: ObservableObject where ObjectWillChangePublisher == ObservableObjectPublisher {
    /// Stable identifier, used for sidebar selection and state restoration.
    var id: String { get }
    var title: String { get }
    /// SF Symbol shown in the sidebar.
    var systemImage: String { get }
    var health: ModuleHealth { get }

    /// Content for the main window's detail pane. It can add toolbar items
    /// and a navigation subtitle.
    func makeDetailView() -> AnyView

    /// Items for the menu bar menu. Use `Section`s, `Button`s and `Text`;
    /// the shell separates modules with dividers.
    func makeMenuContent() -> AnyView
}
