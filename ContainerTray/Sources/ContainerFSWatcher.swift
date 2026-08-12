import CoreServices
import Foundation
import os.log

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
    private var trailingWorkItem: DispatchWorkItem?

    private static let logger = Logger(subsystem: "com.grennis.ContainerTray", category: "FSWatcher")

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

        let callback: FSEventStreamCallback = { _, clientCallBackInfo, eventCount, _, _, _ in
            guard let clientCallBackInfo else { return }
            let watcher = Unmanaged<ContainerFSWatcher>.fromOpaque(clientCallBackInfo).takeUnretainedValue()
            ContainerFSWatcher.logger.debug("received \(eventCount) fs event(s)")
            watcher.handleEvent()
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
            Self.logger.error("FSEventStreamCreate failed; external changes will not be detected")
            return
        }

        self.stream = stream
        FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)

        guard FSEventStreamStart(stream) else {
            Self.logger.error("FSEventStreamStart failed; external changes will not be detected until relaunch")
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            self.stream = nil
            return
        }
        Self.logger.info("watching \(Self.watchedPath, privacy: .public)")
    }

    func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
        trailingWorkItem?.cancel()
        trailingWorkItem = nil
    }

    /// Container start/stop touches several files in quick succession (log
    /// files, service.plist, disk image). This fires `onChange` immediately
    /// on the first event of a burst (leading edge), so a steady stream of
    /// events can't indefinitely postpone every refresh, and again once the
    /// burst goes quiet (trailing edge), so later-settling changes still
    /// trigger a refresh. `ContainerManager` treats each signal as "state may
    /// have changed" and reconciles with further delayed refreshes, since a
    /// single query right after a signal isn't guaranteed to see settled state.
    private func handleEvent() {
        let isNewBurst = trailingWorkItem == nil
        trailingWorkItem?.cancel()

        if isNewBurst {
            Self.logger.debug("leading edge fire")
            onChange()
        }

        let workItem = DispatchWorkItem { [weak self] in
            self?.trailingWorkItem = nil
            Self.logger.debug("trailing edge fire")
            self?.onChange()
        }
        trailingWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }

    deinit {
        stop()
    }
}
