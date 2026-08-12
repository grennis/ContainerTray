import CoreServices
import Foundation

/// Watches Apple's `container` state directory for changes using FSEvents,
/// so `ContainerManager` can refresh when a container starts or stops
/// outside this app (for example from another terminal). FSEvents delivers
/// changes as they happen; there is no timer or repeated polling involved.
///
/// The `container` CLI has no `events`/`watch` subcommand and its XPC
/// protocol is request-reply only, so filesystem changes are the only
/// available signal. Starting or stopping a container touches files under
/// `~/Library/Application Support/com.apple.container/containers/<id>/`
/// (`stdio.log`, `vminitd.log`, `service.plist`), which this watches.
final class ContainerFSWatcher {
    private var stream: FSEventStreamRef?
    private let onChange: () -> Void
    private var debounceWorkItem: DispatchWorkItem?

    private static let watchedPath: String = {
        let base = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Application Support/com.apple.container").path
    }()

    init(onChange: @escaping () -> Void) {
        self.onChange = onChange
    }

    func start() {
        guard stream == nil else { return }

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let callback: FSEventStreamCallback = { _, clientCallBackInfo, _, _, _, _ in
            guard let clientCallBackInfo else { return }
            let watcher = Unmanaged<ContainerFSWatcher>.fromOpaque(clientCallBackInfo).takeUnretainedValue()
            watcher.scheduleDebouncedChange()
        }

        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            [Self.watchedPath] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            /* latency */ 0,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagNone)
        ) else {
            return
        }

        self.stream = stream
        FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
        FSEventStreamStart(stream)
    }

    func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
        debounceWorkItem?.cancel()
        debounceWorkItem = nil
    }

    /// Container start/stop touches several files in quick succession
    /// (log files, service.plist, disk image), so batch those bursts into
    /// a single refresh instead of reacting to each event separately.
    private func scheduleDebouncedChange() {
        debounceWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.onChange()
        }
        debounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }

    deinit {
        stop()
    }
}
