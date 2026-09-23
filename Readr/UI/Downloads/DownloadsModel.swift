import Foundation
import Observation

@Observable
@MainActor
final class DownloadsModel {
    private let downloads: any DownloadRepository
    private let effectContinuation: AsyncStream<DownloadsEffect>.Continuation

    private(set) var state = DownloadsState()
    let effects: AsyncStream<DownloadsEffect>

    init(downloads: any DownloadRepository) {
        self.downloads = downloads
        let stream = AsyncStream.makeStream(of: DownloadsEffect.self)
        effects = stream.stream
        effectContinuation = stream.continuation
    }

    deinit {
        effectContinuation.finish()
    }

    func onAction(_ action: DownloadsAction) {
        switch action {
        case .retry(let id):
            perform("retry the download") { try await $0.retry(id) }
        case .cancel(let id):
            perform("cancel the download") { try await $0.cancel(id) }
        case .delete(let ids):
            perform("delete the download") { try await $0.delete(ids) }
        case .deleteSeries(let id):
            perform("delete these downloads") { try await $0.deleteAll(in: id) }
        case .requestDeleteAll:
            state.isDeleteAllConfirmationPresented = true
        case .cancelDeleteAll:
            state.isDeleteAllConfirmationPresented = false
        case .confirmDeleteAll:
            state.isDeleteAllConfirmationPresented = false
            perform("delete all downloads") { try await $0.deleteAll() }
        case .openSeries(let id):
            effectContinuation.yield(.openSeries(id))
        case .dismissError:
            state.errorMessage = nil
        }
    }

    /// Follows the queue until cancelled. The screen runs this for as long as it
    /// is visible; the repository pushes every change, so nothing polls.
    func observe() async {
        for await snapshot in await downloads.updates() {
            apply(snapshot)
        }
    }

    func apply(_ snapshot: DownloadQueueSnapshot) {
        let grouped = DownloadsState.grouping(snapshot)
        state.queue = grouped.queue
        state.groups = grouped.groups
        state.storageBytes = snapshot.storageBytes
        state.isLoaded = true
    }

    private func perform(
        _ description: String,
        _ operation: @escaping @Sendable (any DownloadRepository) async throws -> Void
    ) {
        let downloads = self.downloads
        Task {
            do {
                try await operation(downloads)
            } catch {
                state.errorMessage = "Couldn’t \(description). \(error.localizedDescription)"
            }
        }
    }
}
