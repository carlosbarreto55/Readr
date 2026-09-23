import Foundation
import SwiftSoup

/// One run of chapter text with its inline emphasis.
struct ChapterTextRun: Sendable, Hashable {
    var text: String
    var isBold = false
    var isItalic = false
}

/// One block of chapter text: the unit the text renderer lays out, selects, and
/// tracks reading position by.
struct ChapterTextBlock: Sendable, Hashable {
    enum Kind: Sendable, Hashable {
        case paragraph
        case heading
        case quote
        /// A scene break: `<hr>`, or a paragraph of nothing but `*`, `-`, or `~`.
        case separator
    }

    var kind: Kind
    var runs: [ChapterTextRun]

    var plainText: String { runs.map(\.text).joined() }
}

/// Turns chapter HTML into text blocks for the native renderer.
///
/// `.text(html:)` stays HTML in the domain; only rendering is native
/// (`architecture.md` §9). This is where the two meet. It keeps structure —
/// paragraphs, headings, quotes, scene breaks — and inline emphasis, and drops
/// everything else: scripts, styles, attributes, layout.
///
/// Pure and synchronous. Callers run it off the main actor; a long chapter is
/// tens of thousands of nodes.
enum ChapterTextParser {

    private static let blockTags: Set<String> = [
        "p", "div", "section", "article", "li", "tr", "table", "ul", "ol", "center",
        "h1", "h2", "h3", "h4", "h5", "h6", "blockquote", "pre", "figure", "figcaption"
    ]
    private static let headingTags: Set<String> = ["h1", "h2", "h3", "h4", "h5", "h6"]
    private static let droppedTags: Set<String> = [
        "script", "style", "noscript", "iframe", "svg", "button", "form", "input", "select"
    ]
    private static let boldTags: Set<String> = ["b", "strong"]
    private static let italicTags: Set<String> = ["i", "em", "cite"]

    static func parse(_ html: String) -> [ChapterTextBlock] {
        guard let document = try? SwiftSoup.parseBodyFragment(html), let body = document.body()
        else {
            return fallback(html)
        }
        var builder = Builder()
        walk(body, style: Style(), into: &builder)
        builder.flush()
        return builder.blocks
    }

    private struct Style {
        var isBold = false
        var isItalic = false
        var kind: ChapterTextBlock.Kind = .paragraph

        /// The style inside an element with this tag.
        func entering(_ tag: String) -> Style {
            var style = self
            if boldTags.contains(tag) { style.isBold = true }
            if italicTags.contains(tag) { style.isItalic = true }
            if headingTags.contains(tag) {
                style.kind = .heading
            } else if tag == "blockquote" {
                style.kind = .quote
            }
            return style
        }
    }

    private struct Builder {
        var blocks: [ChapterTextBlock] = []
        var runs: [ChapterTextRun] = []
        var kind: ChapterTextBlock.Kind = .paragraph

        mutating func append(_ text: String, style: Style) {
            guard !text.isEmpty else { return }
            if runs.isEmpty { kind = style.kind }
            if var last = runs.last, last.isBold == style.isBold, last.isItalic == style.isItalic {
                last.text += text
                runs[runs.count - 1] = last
            } else {
                runs.append(
                    ChapterTextRun(text: text, isBold: style.isBold, isItalic: style.isItalic))
            }
        }

        mutating func separator() {
            flush()
            if blocks.last?.kind != .separator, !blocks.isEmpty {
                blocks.append(ChapterTextBlock(kind: .separator, runs: []))
            }
        }

        /// Ends the current block, collapsing whitespace and dropping it if empty.
        mutating func flush() {
            defer {
                runs = []
                kind = .paragraph
            }
            var normalized = runs.map { run in
                ChapterTextRun(
                    text: ChapterTextParser.collapse(run.text), isBold: run.isBold,
                    isItalic: run.isItalic)
            }
            // Trim the block's ends, not each run's: spaces between runs matter.
            if let first = normalized.first {
                normalized[0].text = String(first.text.drop(while: \.isWhitespace))
            }
            if let last = normalized.last {
                normalized[normalized.count - 1].text = String(
                    last.text.reversed().drop(while: \.isWhitespace).reversed())
            }
            normalized.removeAll { $0.text.isEmpty }
            guard !normalized.isEmpty else { return }

            let text = normalized.map(\.text).joined()
            if ChapterTextParser.isSceneBreak(text) {
                if blocks.last?.kind != .separator, !blocks.isEmpty {
                    blocks.append(ChapterTextBlock(kind: .separator, runs: []))
                }
                return
            }
            blocks.append(ChapterTextBlock(kind: kind, runs: normalized))
        }
    }

    private static func walk(_ element: Element, style: Style, into builder: inout Builder) {
        for node in element.getChildNodes() {
            if let text = node as? TextNode {
                builder.append(text.getWholeText(), style: style)
                continue
            }
            guard let child = node as? Element else { continue }
            let tag = child.tagName().lowercased()

            switch tag {
            case _ where droppedTags.contains(tag):
                continue
            case "br":
                builder.flush()
            case "hr":
                builder.separator()
            default:
                let isBlock = blockTags.contains(tag)
                if isBlock { builder.flush() }
                walk(child, style: style.entering(tag), into: &builder)
                if isBlock { builder.flush() }
            }
        }
    }

    /// Unparseable input still reads: one paragraph per non-empty line.
    private static func fallback(_ html: String) -> [ChapterTextBlock] {
        html.split(whereSeparator: \.isNewline)
            .map { collapse(String($0)).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { ChapterTextBlock(kind: .paragraph, runs: [ChapterTextRun(text: $0)]) }
    }

    static func collapse(_ text: String) -> String {
        var result = ""
        result.reserveCapacity(text.count)
        var lastWasSpace = false
        for character in text {
            if character.isWhitespace {
                if !lastWasSpace { result.append(" ") }
                lastWasSpace = true
            } else {
                result.append(character)
                lastWasSpace = false
            }
        }
        return result
    }

    static func isSceneBreak(_ text: String) -> Bool {
        let stripped = text.filter { !$0.isWhitespace }
        guard !stripped.isEmpty, stripped.count <= 12 else { return false }
        return stripped.allSatisfy { "*-~#•·=_".contains($0) }
    }
}
