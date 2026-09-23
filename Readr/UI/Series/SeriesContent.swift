import SwiftUI

struct SeriesContent: View {
    let state: SeriesState
    let onAction: (SeriesAction) -> Void
    /// Pull-to-refresh. Async so the system spinner stays up until the refresh
    /// has actually finished.
    let onRefresh: @MainActor () async -> Void

    var body: some View {
        Group {
            switch state.phase {
            case .loading:
                ProgressView("Loading Series…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let message):
                ContentUnavailableView {
                    Label("Couldn’t Open Series", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                } actions: {
                    Button("Try Again") { onAction(.retry) }
                        .buttonStyle(.borderedProminent)
                }
            case .loaded:
                if let series = state.series {
                    loaded(series)
                }
            }
        }
        .background(Palette.background)
        .navigationTitle(state.series?.displayTitle ?? "Series")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !state.chapters.isEmpty {
                ToolbarItem(placement: .topBarTrailing) { downloadMenu }
            }
        }
    }

    private var downloadMenu: some View {
        Menu {
            Button(
                "Download All (\(state.undownloadedChapters.count))",
                systemImage: "arrow.down.circle"
            ) {
                onAction(.downloadAll)
            }
            .disabled(state.undownloadedChapters.isEmpty)
            Button(
                "Download Unread (\(state.undownloadedUnreadChapters.count))",
                systemImage: "arrow.down.circle.dotted"
            ) {
                onAction(.downloadUnread)
            }
            .disabled(state.undownloadedUnreadChapters.isEmpty)
        } label: {
            Label("Download", systemImage: "arrow.down.circle")
        }
    }

    private func loaded(_ series: Series) -> some View {
        List {
            Section {
                header(series)
                actions
                if let synopsis = series.synopsis, !synopsis.isEmpty {
                    synopsisView(synopsis)
                }
                if !series.genres.isEmpty {
                    Text(series.genres.joined(separator: " · "))
                        .font(Typography.caption)
                        .foregroundStyle(Palette.secondaryLabel)
                }
            }
            .listRowSeparator(.hidden)

            if let failure = state.membershipFailure {
                FailureBanner(
                    message: failure,
                    retry: { onAction(.retryMembership) },
                    dismiss: { onAction(.dismissMembershipFailure) }
                )
                .listRowSeparator(.hidden)
            }
            if let failure = state.refreshFailure, !state.chapters.isEmpty {
                FailureBanner(message: failure, dismiss: { onAction(.dismissRefreshFailure) })
                    .listRowSeparator(.hidden)
            }

            chapterSection
        }
        .listStyle(.plain)
        .refreshable { await onRefresh() }
    }

    private func header(_ series: Series) -> some View {
        HStack(alignment: .top, spacing: Spacing.large) {
            CoverImage(url: series.coverURL)
                .frame(maxWidth: 120)

            VStack(alignment: .leading, spacing: Spacing.xSmall) {
                Text(series.displayTitle)
                    .font(Typography.sectionTitle)
                    .foregroundStyle(Palette.label)
                    .textSelection(.enabled)
                if let author = series.author {
                    Text(author)
                        .font(Typography.body)
                        .foregroundStyle(Palette.secondaryLabel)
                }
                if let artist = series.artist, artist != series.author {
                    Text("Art by \(artist)")
                        .font(Typography.caption)
                        .foregroundStyle(Palette.secondaryLabel)
                }
                Text(state.metadataLine)
                    .font(Typography.caption)
                    .foregroundStyle(Palette.secondaryLabel)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private var actions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Spacing.medium) { actionButtons }
            VStack(alignment: .leading, spacing: Spacing.small) { actionButtons }
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        Button {
            onAction(.toggleLibrary)
        } label: {
            Label(
                state.isSaved ? "In Library" : "Add to Library",
                systemImage: state.isSaved ? "checkmark" : "plus")
        }
        .buttonStyle(.bordered)
        .accessibilityHint(state.isSaved ? "Removes this series from your library" : "")

        if state.continueTarget != nil {
            Button {
                onAction(.continueReading)
            } label: {
                Label(
                    state.hasReadingHistory ? "Continue Reading" : "Start Reading",
                    systemImage: "book")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func synopsisView(_ synopsis: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xSmall) {
            Text(synopsis)
                .font(Typography.body)
                .foregroundStyle(Palette.label)
                .lineLimit(state.isSynopsisExpanded ? nil : 4)
            Button(state.isSynopsisExpanded ? "Less" : "More") { onAction(.toggleSynopsis) }
                .font(Typography.caption)
                .buttonStyle(.borderless)
        }
    }

    @ViewBuilder
    private var chapterSection: some View {
        Section {
            if state.chapters.isEmpty {
                emptyChapters
            } else {
                ForEach(state.displayedChapters) { chapter in
                    SeriesChapterRow(
                        item: chapter, isSaved: state.isSaved,
                        downloadState: state.downloadStates[chapter.id], onAction: onAction)
                }
            }
        } header: {
            HStack {
                Text(state.chapterCountLabel)
                    .font(Typography.sectionTitle)
                    .foregroundStyle(Palette.label)
                Spacer()
                if state.chapters.count > 1 {
                    Menu {
                        Picker(
                            "Chapter Order",
                            selection: Binding(
                                get: { state.chapterOrder },
                                set: { onAction(.selectChapterOrder($0)) })
                        ) {
                            ForEach(SeriesChapterOrder.allCases) { order in
                                Text(order.title).tag(order)
                            }
                        }
                    } label: {
                        Label("Chapter Order", systemImage: "arrow.up.arrow.down")
                            .labelStyle(.iconOnly)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var emptyChapters: some View {
        if state.isRefreshing {
            HStack(spacing: Spacing.small) {
                ProgressView()
                Text("Loading chapters…")
                    .foregroundStyle(Palette.secondaryLabel)
            }
        } else if let failure = state.refreshFailure {
            VStack(alignment: .leading, spacing: Spacing.small) {
                Text(failure)
                    .font(Typography.body)
                    .foregroundStyle(Palette.secondaryLabel)
                Button("Try Again") { onAction(.retry) }
                    .buttonStyle(.borderedProminent)
            }
        } else {
            Text("No chapters yet.")
                .foregroundStyle(Palette.secondaryLabel)
        }
    }
}

/// One chapter in the list: name, date and progress, upstream status, and the
/// read-state actions valid for a saved series.
private struct SeriesChapterRow: View {
    let item: LibraryChapter
    let isSaved: Bool
    let downloadState: DownloadState?
    let onAction: (SeriesAction) -> Void

    var body: some View {
        Button {
            onAction(.openChapter(item.id))
        } label: {
            VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                Text(item.chapter.name)
                    .font(Typography.body)
                    .foregroundStyle(item.isRead ? Palette.secondaryLabel : Palette.label)
                    .multilineTextAlignment(.leading)
                if let detail {
                    Text(detail)
                        .font(Typography.caption)
                        .foregroundStyle(Palette.secondaryLabel)
                }
                if !item.isListedUpstream {
                    Label("No longer listed by the source", systemImage: "exclamationmark.circle")
                        .font(Typography.caption)
                        .foregroundStyle(Palette.secondaryLabel)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
            .overlay(alignment: .trailing) {
                DownloadStateIndicator(state: downloadState)
            }
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            downloadButton
        }
        .swipeActions(edge: .leading) {
            if isSaved {
                toggleReadButton
                    .tint(Palette.accent)
            }
        }
        .contextMenu {
            downloadButton
            if isSaved {
                toggleReadButton
                Button {
                    onAction(.markPreviousRead(item.id))
                } label: {
                    Label("Mark Previous as Read", systemImage: "arrow.up.to.line")
                }
            }
        }
    }

    @ViewBuilder
    private var downloadButton: some View {
        switch downloadState {
        case nil, .failed:
            Button {
                onAction(.download([item.id]))
            } label: {
                Label("Download", systemImage: "arrow.down.circle")
            }
            .tint(Palette.accent)
        case .pending, .downloading:
            Button(role: .destructive) {
                onAction(.cancelDownload(item.id))
            } label: {
                Label("Cancel Download", systemImage: "xmark.circle")
            }
        case .completed:
            Button(role: .destructive) {
                onAction(.deleteDownload(item.id))
            } label: {
                Label("Delete Download", systemImage: "trash")
            }
        }
    }

    private var toggleReadButton: some View {
        Button {
            onAction(.setRead([item.id], isRead: !item.isRead))
        } label: {
            Label(
                item.isRead ? "Mark Unread" : "Mark Read",
                systemImage: item.isRead ? "eye.slash" : "eye")
        }
    }

    private var detail: String? {
        var parts: [String] = []
        if let date = item.chapter.dateUploaded {
            parts.append(date.formatted(date: .abbreviated, time: .omitted))
        }
        if let scanlator = item.chapter.scanlator, !scanlator.isEmpty {
            parts.append(scanlator)
        }
        if item.isInProgress {
            parts.append("\(Int((item.readingPosition * 100).rounded()))% read")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

#Preview("Saved series") {
    let seriesURL = URL(string: "https://example.test/series/road")!
    let chapters = (1...6).map { index in
        LibraryChapter(
            chapter: Chapter(
                sourceID: 1, seriesURL: seriesURL, url: seriesURL.appending(path: "c\(index)"),
                name: "Chapter \(index)", number: Double(index),
                dateUploaded: Date(timeIntervalSince1970: 1_750_000_000 + Double(index) * 86_400)),
            isRead: index < 3, readingPosition: index < 3 ? 1 : (index == 3 ? 0.4 : 0),
            sourceIndex: index - 1, isListedUpstream: index != 2)
    }
    NavigationStack {
        SeriesContent(
            state: SeriesState(
                phase: .loaded,
                series: Series(
                    sourceID: 1, url: seriesURL,
                    title: "The Long Road Home Through a Thousand Worlds",
                    synopsis: "A traveller crosses a thousand worlds looking for home.",
                    author: "A. Writer", genres: ["Fantasy", "Adventure"], status: .ongoing,
                    contentType: .novel),
                sourceName: "Novel Source", chapters: chapters, isSaved: true,
                refreshFailure: "Couldn’t refresh. The network connection was lost.",
                downloadStates: [
                    chapters[0].id: .completed,
                    chapters[3].id: .downloading(DownloadProgress(completed: 2, total: 5)),
                    chapters[4].id: .pending
                ]),
            onAction: { _ in }, onRefresh: {})
    }
}

#Preview("Series states") {
    let blank = Series(
        sourceID: 2, url: URL(string: "https://example.test/series/the-swordmaster")!,
        title: "", contentType: .manhwa)
    TabView {
        NavigationStack {
            SeriesContent(state: SeriesState(), onAction: { _ in }, onRefresh: {})
        }
        .tabItem { Text("Loading") }
        NavigationStack {
            SeriesContent(
                state: SeriesState(
                    phase: .loaded, series: blank, sourceName: "Comic Source",
                    isRefreshing: true),
                onAction: { _ in }, onRefresh: {})
        }
        .tabItem { Text("Blank title") }
        NavigationStack {
            SeriesContent(
                state: SeriesState(phase: .failed(message: "This source is no longer available.")),
                onAction: { _ in }, onRefresh: {})
        }
        .tabItem { Text("Failed") }
    }
}
