import SwiftUI

struct DownloadsContent: View {
    let state: DownloadsState
    let onAction: (DownloadsAction) -> Void

    var body: some View {
        Group {
            if !state.isLoaded {
                ProgressView("Loading Downloads…")
            } else if state.isEmpty {
                ContentUnavailableView {
                    Label("No Downloads", systemImage: "arrow.down.circle")
                } description: {
                    Text(
                        "Download chapters from a series to read them offline. They’ll appear here."
                    )
                }
            } else {
                list
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background)
        .navigationTitle("Downloads")
        .toolbar {
            if !state.groups.isEmpty || !state.queue.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Delete All Downloads", systemImage: "trash", role: .destructive) {
                            onAction(.requestDeleteAll)
                        }
                    } label: {
                        Label("More", systemImage: "ellipsis.circle")
                    }
                }
            }
        }
        .confirmationDialog(
            "Delete all downloads?",
            isPresented: Binding(
                get: { state.isDeleteAllConfirmationPresented },
                set: { if !$0 { onAction(.cancelDeleteAll) } }),
            titleVisibility: .visible
        ) {
            Button("Delete All Downloads", role: .destructive) { onAction(.confirmDeleteAll) }
            Button("Cancel", role: .cancel) { onAction(.cancelDeleteAll) }
        } message: {
            Text("Stored chapters are removed from this device. Your library is kept.")
        }
    }

    private var list: some View {
        List {
            if let message = state.errorMessage {
                Section {
                    Text(message)
                        .font(Typography.caption)
                        .foregroundStyle(Palette.secondaryLabel)
                    Button("Dismiss") { onAction(.dismissError) }
                }
            }

            if !state.queue.isEmpty {
                Section("Queue") {
                    ForEach(state.queue) { entry in
                        DownloadQueueRow(entry: entry, onAction: onAction)
                    }
                }
            }

            ForEach(state.groups) { group in
                Section {
                    ForEach(group.entries) { entry in
                        HStack {
                            Text(entry.chapter.name)
                                .font(Typography.body)
                            Spacer()
                            Text(
                                ByteCountFormatter.string(
                                    fromByteCount: entry.byteCount, countStyle: .file)
                            )
                            .font(Typography.caption)
                            .foregroundStyle(Palette.secondaryLabel)
                        }
                        .swipeActions {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                onAction(.delete([entry.id]))
                            }
                        }
                    }
                } header: {
                    groupHeader(group)
                }
            }

            Section {
                LabeledContent("Storage Used", value: state.storageLabel)
            } footer: {
                Text("Downloads are kept on this device and are not backed up to iCloud.")
            }
        }
    }

    private func groupHeader(_ group: DownloadSeriesGroup) -> some View {
        HStack {
            Button {
                onAction(.openSeries(group.seriesID))
            } label: {
                Text(group.title)
                    .font(Typography.cardTitle)
                    .multilineTextAlignment(.leading)
            }
            .accessibilityHint("Opens series details")
            Spacer()
            Menu {
                Button(
                    "Delete \(group.entries.count) Chapters", systemImage: "trash",
                    role: .destructive
                ) {
                    onAction(.deleteSeries(group.seriesID))
                }
            } label: {
                Label("Series Downloads", systemImage: "ellipsis")
                    .labelStyle(.iconOnly)
            }
        }
    }
}

/// A queued chapter: waiting, downloading with progress, or failed with a retry.
private struct DownloadQueueRow: View {
    let entry: DownloadEntry
    let onAction: (DownloadsAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            Text(entry.chapter.name)
                .font(Typography.body)
            Text(entry.seriesTitle.isEmpty ? " " : entry.seriesTitle)
                .font(Typography.caption)
                .foregroundStyle(Palette.secondaryLabel)
            status
        }
        .swipeActions {
            Button("Cancel", systemImage: "xmark", role: .destructive) {
                onAction(.cancel(entry.id))
            }
        }
    }

    @ViewBuilder
    private var status: some View {
        switch entry.state {
        case .pending:
            Text("Waiting")
                .font(Typography.caption)
                .foregroundStyle(Palette.secondaryLabel)
        case .downloading(let progress):
            if let fraction = progress.fraction {
                ProgressView(value: fraction) {
                    EmptyView()
                } currentValueLabel: {
                    if let total = progress.total {
                        Text("\(progress.completed) of \(total) pages")
                    }
                }
            } else {
                ProgressView()
                    .progressViewStyle(.linear)
                    .accessibilityLabel("Downloading")
            }
        case .failed(let message, let isRetryable):
            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                Text(message)
                    .font(Typography.caption)
                    .foregroundStyle(Palette.secondaryLabel)
                if isRetryable {
                    Button("Retry") { onAction(.retry(entry.id)) }
                        .buttonStyle(.bordered)
                }
            }
        case .completed:
            EmptyView()
        }
    }
}

#Preview("Downloads") {
    let seriesURL = URL(string: "https://example.test/series/one")!
    func entry(_ number: Int, _ state: DownloadState, bytes: Int64 = 0) -> DownloadEntry {
        DownloadEntry(
            chapter: Chapter(
                sourceID: 1, seriesURL: seriesURL, url: seriesURL.appending(path: "\(number)"),
                name: "Chapter \(number)", number: Double(number)),
            seriesTitle: "The Swordmaster", contentType: .manhwa, state: state,
            enqueuedAt: .now, byteCount: bytes)
    }
    let snapshot = DownloadQueueSnapshot(
        entries: [
            entry(1, .completed, bytes: 4_200_000),
            entry(2, .completed, bytes: 3_900_000),
            entry(3, .downloading(DownloadProgress(completed: 12, total: 40))),
            entry(4, .pending),
            entry(5, .failed(message: "The request timed out.", isRetryable: true))
        ],
        storageBytes: 8_100_000)
    let grouped = DownloadsState.grouping(snapshot)
    return NavigationStack {
        DownloadsContent(
            state: DownloadsState(
                isLoaded: true, queue: grouped.queue, groups: grouped.groups,
                storageBytes: snapshot.storageBytes),
            onAction: { _ in })
    }
}

#Preview("No downloads") {
    NavigationStack {
        DownloadsContent(state: DownloadsState(isLoaded: true), onAction: { _ in })
    }
}
