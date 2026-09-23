import SwiftUI

/// Renders `.text(html:)` — already parsed into blocks — as native attributed
/// text.
///
/// Native rather than a web view so Dynamic Type, selection, and reader themes
/// work (`architecture.md` §9). One `Text` per block in a lazy stack, so a long
/// chapter lays out only what is on screen; position is the first visible block.
struct TextRenderer: View {
    let blocks: [ChapterTextBlock]
    let preferences: ReaderPreferences
    let onPositionChanged: (Int) -> Void
    let onReachedEnd: () -> Void
    let onTap: () -> Void

    /// The Dynamic Type body size. The reader's text scale multiplies it; it
    /// never replaces it.
    @ScaledMetric(relativeTo: .body) private var bodySize: CGFloat = 17
    @State private var position: Int?

    init(
        blocks: [ChapterTextBlock],
        preferences: ReaderPreferences,
        initialIndex: Int,
        onPositionChanged: @escaping (Int) -> Void,
        onReachedEnd: @escaping () -> Void,
        onTap: @escaping () -> Void
    ) {
        self.blocks = blocks
        self.preferences = preferences
        self.onPositionChanged = onPositionChanged
        self.onReachedEnd = onReachedEnd
        self.onTap = onTap
        _position = State(initialValue: initialIndex)
    }

    private var size: CGFloat { bodySize * preferences.textScale }
    private var theme: ReaderTheme { preferences.theme }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: size * 0.9) {
                ForEach(blocks.indices, id: \.self) { index in
                    block(blocks[index])
                        .id(index)
                }
                // Reaching this is reaching the end of the chapter.
                Color.clear
                    .frame(height: 1)
                    .onAppear(perform: onReachedEnd)
            }
            .scrollTargetLayout()
            .padding(.horizontal, Spacing.xLarge)
            .padding(.vertical, Spacing.xxLarge * 2)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollPosition(id: $position, anchor: .top)
        .onChange(of: position) { _, index in
            if let index { onPositionChanged(index) }
        }
        .contentShape(.rect)
        .onTapGesture(perform: onTap)
        .background(ReaderColors.background(theme))
    }

    @ViewBuilder
    private func block(_ block: ChapterTextBlock) -> some View {
        switch block.kind {
        case .separator:
            Text("⁂")
                .font(font(scale: 1, bold: false, italic: false))
                .foregroundStyle(ReaderColors.secondaryText(theme))
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Scene break")
        case .heading:
            Text(attributed(block, scale: 1.3, forceBold: true))
                .foregroundStyle(ReaderColors.text(theme))
                .textSelection(.enabled)
                .accessibilityAddTraits(.isHeader)
        case .quote:
            Text(attributed(block, scale: 1, forceBold: false))
                .foregroundStyle(ReaderColors.secondaryText(theme))
                .lineSpacing(size * 0.35)
                .textSelection(.enabled)
                .padding(.leading, Spacing.large)
        case .paragraph:
            Text(attributed(block, scale: 1, forceBold: false))
                .foregroundStyle(ReaderColors.text(theme))
                .lineSpacing(size * 0.35)
                .textSelection(.enabled)
        }
    }

    private func attributed(
        _ block: ChapterTextBlock, scale: CGFloat, forceBold: Bool
    ) -> AttributedString {
        var result = AttributedString()
        for run in block.runs {
            var piece = AttributedString(run.text)
            piece.font = font(scale: scale, bold: forceBold || run.isBold, italic: run.isItalic)
            result += piece
        }
        return result
    }

    private func font(scale: CGFloat, bold: Bool, italic: Bool) -> Font {
        let design: Font.Design = preferences.fontDesign == .serif ? .serif : .default
        let base = Font.system(size: size * scale, weight: bold ? .bold : .regular, design: design)
        return italic ? base.italic() : base
    }
}

#Preview("Text renderer themes") {
    let blocks = [
        ChapterTextBlock(kind: .heading, runs: [ChapterTextRun(text: "Chapter 1: The Road")]),
        ChapterTextBlock(
            kind: .paragraph,
            runs: [
                ChapterTextRun(text: "The road ran on "),
                ChapterTextRun(text: "forever", isItalic: true),
                ChapterTextRun(text: ", and the traveller "),
                ChapterTextRun(text: "did not stop", isBold: true),
                ChapterTextRun(text: ".")
            ]),
        ChapterTextBlock(kind: .separator, runs: []),
        ChapterTextBlock(
            kind: .quote, runs: [ChapterTextRun(text: "“Home is where the road ends.”")])
    ]
    TabView {
        ForEach(ReaderTheme.allCases) { theme in
            TextRenderer(
                blocks: blocks,
                preferences: ReaderPreferences(
                    theme: theme, fontDesign: theme == .sepia ? .serif : .system),
                initialIndex: 0,
                onPositionChanged: { _ in },
                onReachedEnd: {},
                onTap: {}
            )
            .tabItem { Text(theme.title) }
        }
    }
}
