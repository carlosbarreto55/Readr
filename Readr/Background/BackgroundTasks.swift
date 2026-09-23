import BackgroundTasks
import Foundation

/// The two `BGTaskScheduler` entry points declared in `project.yml`.
///
/// Best-effort by the platform's design: iOS decides whether and when either
/// runs, so no feature depends on one having run (`architecture.md` §8). The
/// foreground refresh on activation is the library's guarantee, and the download
/// queue resumes at every launch regardless.
enum BackgroundTasks {
    static let libraryRefresh = "dev.opus.readr.refresh.library"
    static let downloadProcessing = "dev.opus.readr.process.downloads"

    /// Registers both handlers. Must run before the app finishes launching,
    /// which is why `ReadrApp.init` calls it.
    static func register(container: AppContainer) {
        let scheduler = BGTaskScheduler.shared
        _ = scheduler.register(forTaskWithIdentifier: libraryRefresh, using: nil) { task in
            scheduleLibraryRefresh()
            run(task) {
                _ = await container.series.refreshLibrary()
            }
        }
        _ = scheduler.register(forTaskWithIdentifier: downloadProcessing, using: nil) { task in
            run(task) {
                await container.downloads.drainUntilIdle()
            }
        }
    }

    /// Asks for both tasks when the app leaves the foreground: a library refresh
    /// always, download processing only when something is waiting.
    static func schedule(container: AppContainer) async {
        scheduleLibraryRefresh()
        let queued = (try? await container.downloads.snapshot().queue.isEmpty == false) ?? false
        if queued {
            scheduleDownloadProcessing()
        }
    }

    private static func scheduleLibraryRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: libraryRefresh)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60)
        // A refused request means the system will not run one; the foreground
        // refresh still does, so this is not an error worth surfacing.
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func scheduleDownloadProcessing() {
        let request = BGProcessingTaskRequest(identifier: downloadProcessing)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        try? BGTaskScheduler.shared.submit(request)
    }

    /// Runs `work` for a system task: cancelled when the system expires the task,
    /// and reported complete when it finishes.
    private static func run(_ task: BGTask, work: @escaping @Sendable () async -> Void) {
        let handle = TaskHandle(task)
        let worker = Task {
            await work()
            handle.complete(success: !Task.isCancelled)
        }
        task.expirationHandler = {
            worker.cancel()
        }
    }
}

/// Carries a `BGTask` into the task that completes it.
///
/// `BGTask` predates `Sendable`; the scheduler documents completing it from any
/// thread, and this type only ever completes it once.
private final class TaskHandle: @unchecked Sendable {
    private let task: BGTask

    init(_ task: BGTask) {
        self.task = task
    }

    func complete(success: Bool) {
        task.setTaskCompleted(success: success)
    }
}
