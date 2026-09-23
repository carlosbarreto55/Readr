import Foundation

extension Series {

    /// The title to show: the stored title, or a placeholder derived from the URL
    /// when the title is blank.
    ///
    /// `library-blank-title-repair` requires a series whose title failed to parse
    /// to remain displayable, openable, and removable — so nothing renders an
    /// empty string where a title belongs. The placeholder is presentation only;
    /// identity never depends on it.
    public var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? Self.placeholderTitle(for: url) : trimmed
    }

    /// Whether the stored title needs repairing.
    public var hasBlankTitle: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The last meaningful path component, de-slugged: `the-swordmaster_2` →
    /// `The Swordmaster 2`. Falls back to the host, then to the whole URL.
    static func placeholderTitle(for url: URL) -> String {
        let ignored: Set<String> = ["", "/", "series", "novel", "manga", "comics", "book"]
        let component = url.pathComponents
            .reversed()
            .first { !ignored.contains($0.lowercased()) }

        if let component {
            let stripped = component.replacingOccurrences(
                of: #"\.[A-Za-z0-9]{2,5}$"#, with: "", options: .regularExpression)
            let words =
                stripped
                .split(whereSeparator: { $0 == "-" || $0 == "_" || $0 == "+" || $0 == " " })
                .map { word in word.prefix(1).uppercased() + word.dropFirst() }
            if !words.isEmpty {
                return words.joined(separator: " ")
            }
        }
        return url.host() ?? url.absoluteString
    }
}
