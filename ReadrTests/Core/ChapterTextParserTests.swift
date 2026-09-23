import Testing

@testable import Readr

@Suite("Chapter text parser")
struct ChapterTextParserTests {

    @Test("Paragraphs become blocks with collapsed whitespace")
    func paragraphs() {
        let blocks = ChapterTextParser.parse(
            "<p>  First   paragraph.\n </p><p>Second\tparagraph.</p>")
        #expect(blocks.map(\.plainText) == ["First paragraph.", "Second paragraph."])
        #expect(blocks.allSatisfy { $0.kind == .paragraph })
    }

    @Test("Line breaks separate paragraphs in text that uses them instead of <p>")
    func lineBreaks() {
        let blocks = ChapterTextParser.parse("<div>One.<br><br>Two.<br/>Three.</div>")
        #expect(blocks.map(\.plainText) == ["One.", "Two.", "Three."])
    }

    @Test("Emphasis is kept as runs, with the spaces between them")
    func emphasis() {
        let blocks = ChapterTextParser.parse(
            "<p>A <em>quiet</em> and <strong>bold</strong> <b><i>end</i></b>.</p>")
        let runs = blocks.first?.runs ?? []
        #expect(blocks.first?.plainText == "A quiet and bold end.")
        #expect(runs.first { $0.text == "quiet" }?.isItalic == true)
        #expect(runs.first { $0.text == "bold" }?.isBold == true)
        let end = runs.first { $0.text == "end" }
        #expect(end?.isBold == true)
        #expect(end?.isItalic == true)
    }

    @Test("Headings, quotes, and scene breaks keep their kind")
    func structure() {
        let blocks = ChapterTextParser.parse(
            """
            <h2>Chapter 3</h2><p>Before.</p><hr><p>* * *</p><p>After.</p>
            <blockquote>Quoted.</blockquote>
            """)
        #expect(blocks.map(\.kind) == [.heading, .paragraph, .separator, .paragraph, .quote])
        #expect(blocks.map(\.plainText) == ["Chapter 3", "Before.", "", "After.", "Quoted."])
    }

    @Test("Scripts, styles, and empty paragraphs are dropped")
    func dropsNoise() {
        let blocks = ChapterTextParser.parse(
            "<style>p{}</style><p>Kept.</p><script>track()</script><p>&nbsp;</p><p></p>")
        #expect(blocks.map(\.plainText) == ["Kept."])
    }

    @Test("Bare text with no markup still reads")
    func bareText() {
        #expect(ChapterTextParser.parse("Just words.").map(\.plainText) == ["Just words."])
        #expect(ChapterTextParser.parse("").isEmpty)
    }
}
