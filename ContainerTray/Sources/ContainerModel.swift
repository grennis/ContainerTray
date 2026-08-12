import Foundation

struct ContainerItem: Identifiable, Equatable {
    let id: String
    let imageReference: String
    let state: String

    var isRunning: Bool {
        state.caseInsensitiveCompare("running") == .orderedSame
    }
}

/// Mirrors the JSON emitted by `container list --all --format json`.
struct ContainerListEntry: Decodable {
    let id: String
    let configuration: Configuration
    let status: Status

    struct Configuration: Decodable {
        let image: Image

        struct Image: Decodable {
            let reference: String
        }
    }

    struct Status: Decodable {
        let state: String
    }
}

extension ContainerItem {
    init(entry: ContainerListEntry) {
        self.init(
            id: entry.id,
            imageReference: entry.configuration.image.reference,
            state: entry.status.state
        )
    }
}
