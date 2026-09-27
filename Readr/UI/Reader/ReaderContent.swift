import SwiftUI

/// The one Reader surface. Branches once on the document to pick a renderer and
/// shares everything else: chrome, the back edge, panels, and failure states.
struct ReaderContent: View {
    let state: ReaderState
    let onAction: (ReaderAction) -> Void

    /// The strip along the leading edge that belongs to back. Scaled so it stays
    /// reachable at large accessibility sizes.
    @ScaledMetric(relativeTo: .body) private var backEdgeWidth: CGFloat = 20

    private var theme: ReaderTheme { state.preferences.theme }

    var body: some View {
        ZStack(alignment: .leading) {
            ReaderColors.background(theme)
                .ignoresSafeArea()

            surface

            backEdge

            if state.controlsVisible || state.phase != .loaded {
                chrome
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: state.controlsVisible)
        .statusBarHidden(!state.controlsVisible)
        .persistentSystemOverlays(state.controlsVisible ? .automatic : .hidden)
        .preferredColorScheme(ReaderColors.colorScheme(theme))
        .sheet(
            isPresented: Binding(
                get: { state.isChapterListPresented },
                set: { onAction(.showChapterList($0)) })
        ) {
            ReaderChapterList(state: state, onAction: onAction)
        }
        .sheet(
            isPresented: Binding(
                get: { state.isSettingsPresented },
                set: { onAction(.showSettings($0)) })
        ) {
            ReaderSettingsPanel(
                preferences: state.preferences, contentType: state.route.contentType,
                onAction: onAction)
        }
    }

    @ViewBuilder
    private var surface: some View {
        switch state.phase {
        case .loading:
            ProgressView()
                .tint(ReaderColors.text(theme))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let failure):
            ContentUnavailableView {
                Label("Couldn’t Open Chapter", systemImage: "exclamationmark.triangle")
            } description: {
                Text(failure.message)
            } actions: {
                if failure.isRetryable {
                    Button("Try Again") { onAction(.retry) }
                        .buttonStyle(.borderedProminent)
                }
            }
            .foregroundStyle(ReaderColors.text(theme))
        case .loaded:
            renderer
                .ignoresSafeArea(edges: .bottom)
        }
    }

    @ViewBuilder
    private var renderer: some View {
        switch state.document {
        case .text(let blocks):
            TextRenderer(
                blocks: blocks,
                preferences: state.preferences,
                initialIndex: state.initialIndex,
                onPositionChanged: { onAction(.positionChanged(index: $0)) },
                onReachedEnd: { onAction(.reachedEnd) },
                onTextScaleChanged: { onAction(.setTextScale($0)) },
                onTap: { onAction(.toggleControls) }
            )
            .id(state.documentGeneration)
        case .pages(let urls):
            PageRenderer(
                urls: urls,
                preferences: state.preferences,
                contentType: state.route.contentType,
                initialIndex: state.initialIndex,
                onPositionChanged: { onAction(.positionChanged(index: $0)) },
                onReachedEnd: { onAction(.reachedEnd) },
                onTap: { onAction(.toggleControls) }
            )
            .id(pageRendererID)
        case nil:
            EmptyView()
        }
    }

    private var pageRendererID: String {
        "\(state.documentGeneration)-\(state.preferences.pageLayout.rawValue)"
            + "-\(state.preferences.mangaPageLayout.rawValue)"
    }

    /// Absorbs touches so no scroll or page turn can begin at the leading edge,
    /// and turns a rightward drag from it into back — the edge swipe a pushed
    /// view would get, which a full-screen cover does not.
    private var backEdge: some View {
        Color.clear
            .frame(width: backEdgeWidth)
            .frame(maxHeight: .infinity)
            .contentShape(.rect)
            .gesture(
                DragGesture(minimumDistance: 8)
                    .onEnded { value in
                        if value.translation.width > backEdgeWidth * 3 {
                            onAction(.close)
                        }
                    }
            )
            .accessibilityHidden(true)
    }

    private var chrome: some View {
        VStack(spacing: 0) {
            topBar
            Spacer(minLength: 0)
            if state.phase == .loaded {
                bottomBar
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: Spacing.medium) {
            Button {
                onAction(.close)
            } label: {
                Label("Close Reader", systemImage: "xmark")
                    .labelStyle(.iconOnly)
                    .font(Typography.sectionTitle)
            }

            VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                Text(state.chapterTitle)
                    .font(Typography.cardTitle)
                    .lineLimit(2)
                if !state.seriesTitle.isEmpty {
                    Text(state.seriesTitle)
                        .font(Typography.caption)
                        .foregroundStyle(Palette.secondaryLabel)
                        .lineLimit(1)
                }
                if !state.isProgressStored {
                    Text("Progress is saved only for series in your library.")
                        .font(Typography.caption)
                        .foregroundStyle(Palette.secondaryLabel)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, Spacing.screenMargin)
        .padding(.vertical, Spacing.small)
        .background(.bar)
    }

    private var bottomBar: some View {
        HStack(spacing: Spacing.large) {
            Button {
                onAction(.previousChapter)
            } label: {
                Label("Previous Chapter", systemImage: "chevron.backward")
            }
            .disabled(!state.hasPrevious)

            Button {
                onAction(.showChapterList(true))
            } label: {
                Label("Chapters", systemImage: "list.bullet")
            }
            .disabled(state.chapters.isEmpty)

            Spacer(minLength: 0)

            ProgressView(value: state.progress)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Chapter progress")
                .accessibilityValue(state.progressLabel)
            Text(state.progressLabel)
                .font(Typography.caption)
                .monospacedDigit()

            Spacer(minLength: 0)

            ReaderDownloadButton(state: state.currentDownloadState) {
                onAction(.download)
            }

            Button {
                onAction(.showSettings(true))
            } label: {
                Label("Reader Settings", systemImage: "textformat.size")
            }

            Button {
                onAction(.nextChapter)
            } label: {
                Label("Next Chapter", systemImage: "chevron.forward")
            }
            .disabled(!state.hasNext)
        }
        .labelStyle(.iconOnly)
        .font(Typography.sectionTitle)
        .padding(.horizontal, Spacing.screenMargin)
        .padding(.vertical, Spacing.medium)
        .background(.bar)
    }
}

/// The chrome's download control: offers the download, then shows its state.
private struct ReaderDownloadButton: View {
    let state: DownloadState?
    let onDownload: () -> Void

    var body: some View {
        switch state {
        case nil, .failed:
            Button(action: onDownload) {
                Label("Download Chapter", systemImage: "arrow.down.circle")
            }
        case .pending, .downloading, .completed:
            DownloadStateIndicator(state: state)
        }
    }
}

/// The series' chapters, current one marked, read ones dimmed.
private struct ReaderChapterList: View {
    let state: ReaderState
    let onAction: (ReaderAction) -> Void

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                List(state.chapters) { item in
                    Button {
                        onAction(.selectChapter(item.id))
                    } label: {
                        HStack {
                            Text(item.chapter.name)
                                .foregroundStyle(
                                    item.isRead ? Palette.secondaryLabel : Palette.label)
                            Spacer()
                            if item.id == state.currentChapterID {
                                Image(systemName: "book.fill")
                                    .foregroundStyle(Palette.accent)
                                    .accessibilityLabel("Current chapter")
                            }
                        }
                    }
                    .id(item.id)
                }
                .onAppear { proxy.scrollTo(state.currentChapterID, anchor: .center) }
            }
            .navigationTitle("Chapters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onAction(.showChapterList(false)) }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// Reader appearance, adjustable without leaving the chapter.
private struct ReaderSettingsPanel: View {
    let preferences: ReaderPreferences
    let contentType: ContentType
    let onAction: (ReaderAction) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Picker(
                    "Theme",
                    selection: Binding(
                        get: { preferences.theme }, set: { onAction(.setTheme($0)) })
                ) {
                    ForEach(ReaderTheme.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)

                if contentType == .novel {
                    Picker(
                        "Font",
                        selection: Binding(
                            get: { preferences.fontDesign },
                            set: { onAction(.setFontDesign($0)) })
                    ) {
                        ForEach(ReaderFontDesign.allCases) { Text($0.title).tag($0) }
                    }
                    Stepper(
                        value: Binding(
                            get: { preferences.textScale }, set: { onAction(.setTextScale($0)) }),
                        in: ReaderPreferences.textScaleRange,
                        step: ReaderPreferences.textScaleStep
                    ) {
                        Text("Text Size \(Int((preferences.textScale * 100).rounded()))%")
                    }
                } else {
                    Picker(
                        "Page Layout",
                        selection: Binding(
                            get: {
                                contentType == .manga
                                    ? preferences.mangaPageLayout : preferences.pageLayout
                            },
                            set: { onAction(.setPageLayout($0)) })
                    ) {
                        ForEach(ReaderPageLayout.allCases) { Text($0.title).tag($0) }
                    }
                }
            }
            .navigationTitle("Reader Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onAction(.showSettings(false)) }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private func previewState(_ contentType: ContentType, theme: ReaderTheme) -> ReaderState {
    let seriesURL = URL(string: "https://example.test/series")!
    var state = ReaderState(
        route: ReaderRoute(
            sourceID: 1, seriesURL: seriesURL, chapterURL: seriesURL.appending(path: "2"),
            contentType: contentType),
        preferences: ReaderPreferences(theme: theme))
    state.chapters = (1...3).map { index in
        LibraryChapter(
            chapter: Chapter(
                sourceID: 1, seriesURL: seriesURL, url: seriesURL.appending(path: "\(index)"),
                name: "Chapter \(index)"),
            isRead: index == 1, sourceIndex: index)
    }
    state.phase = .loaded
    state.progress = 0.42
    state.isProgressStored = contentType == .novel
    return state
}

#Preview("Novel chapter") {
    var state = previewState(.novel, theme: .sepia)
    state.document = .text([
        ChapterTextBlock(kind: .heading, runs: [ChapterTextRun(text: "Chapter 2")]),
        ChapterTextBlock(
            kind: .paragraph,
            runs: [ChapterTextRun(text: String(repeating: "The road ran on. ", count: 40))])
    ])
    return ReaderContent(state: state, onAction: { _ in })
}

#Preview("Manhwa chapter") {
    var state = previewState(.manhwa, theme: .dark)
    state.document = .pages((1...3).map { URL(string: "https://example.invalid/\($0).jpg")! })
    return ReaderContent(state: state, onAction: { _ in })
}

#Preview("Failed chapter") {
    var state = previewState(.manhwa, theme: .system)
    state.phase = .failed(
        ReaderFailure(
            message: "This chapter returned text where page images were expected.",
            isRetryable: true))
    return ReaderContent(state: state, onAction: { _ in })
}
