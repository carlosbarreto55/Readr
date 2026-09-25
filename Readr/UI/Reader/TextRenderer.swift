import SwiftUI

/// Renders `.text(html:)` — already parsed into blocks — as native attributed
/// text.
///
/// Native rather than a web view so Dynamic Type, selection, and reader themes
/// work (`architecture.md` §9). One `Text` per block in a lazy stack, so a long
/// chapter lays out only what is on screen; position is the first visible block.
///
/// A pinch resizes the text rather than magnifying it: it steps the reader's
/// text scale, previewing each step as a reflow, and reports the result on
/// release. The bound block position keeps the passage in view as text reflows.
struct TextRenderer: View {
    let blocks: [ChapterTextBlock]
    let preferences: ReaderPreferences
    let onPositionChanged: (Int) -> Void
    let onReachedEnd: () -> Void
    let onTextScaleChanged: (Double) -> Void
    let onTap: () -> Void

    /// The Dynamic Type body size. The reader's text scale multiplies it; it
    /// never replaces it.
    @ScaledMetric(relativeTo: .body) private var bodySize: CGFloat = 17
    @State private var position: Int?
    /// The pinch in progress: the scale it started from and its accumulated
    /// factor. `nil` when no pinch is under way.
    @State private var pinch: (start: Double, factor: CGFloat)?
    /// The snapped scale a pinch is previewing; replaces the stored one until
    /// release.
    @State private var previewScale: Double?

    init(
        blocks: [ChapterTextBlock],
        preferences: ReaderPreferences,
        initialIndex: Int,
        onPositionChanged: @escaping (Int) -> Void,
        onReachedEnd: @escaping () -> Void,
        onTextScaleChanged: @escaping (Double) -> Void,
        onTap: @escaping () -> Void
    ) {
        self.blocks = blocks
        self.preferences = preferences
        self.onPositionChanged = onPositionChanged
        self.onReachedEnd = onReachedEnd
        self.onTextScaleChanged = onTextScaleChanged
        self.onTap = onTap
        _position = State(initialValue: initialIndex)
    }

    private var textScale: Double { previewScale ?? preferences.textScale }
    private var size: CGFloat { bodySize * textScale }
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
        .gesture(
            PinchRecognizer(onChanged: { factor, _ in pinched(by: factor) }, onEnded: pinchEnded)
        )
        .background(ReaderColors.background(theme))
    }

    /// The text scale a pinch of `factor` makes from `start`: clamped and
    /// snapped to the settings slider's steps.
    static func pinchedScale(from start: Double, factor: CGFloat) -> Double {
        ReaderPreferences.clampedScale(start * Double(factor))
    }

    private func pinched(by factor: CGFloat) {
        let current = pinch ?? (start: textScale, factor: 1)
        let next = (start: current.start, factor: current.factor * factor)
        pinch = next
        // Snapped, so the text reflows once per step rather than every frame.
        let scale = Self.pinchedScale(from: next.start, factor: next.factor)
        if scale != previewScale {
            previewScale = scale
        }
    }

    private func pinchEnded() {
        if let previewScale, previewScale != preferences.textScale {
            onTextScaleChanged(previewScale)
        }
        pinch = nil
        previewScale = nil
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
                onTextScaleChanged: { _ in },
                onTap: {}
            )
            .tabItem { Text(theme.title) }
        }
    }
}
