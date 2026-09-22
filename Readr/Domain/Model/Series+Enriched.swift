import Foundation

extension Series {

    /// This series with `details` folded onto it, keeping what `details` does not
    /// know.
    ///
    /// `source-detail-parsing` requires that a detail fetch *enrich* rather than
    /// replace: a field the detail page omits keeps the value the catalog listing
    /// gave it. Without the rule, refreshing a series that was found through
    /// search — where listings are richest — routinely makes it worse, and does
    /// so invisibly, because the series still renders.
    ///
    /// Identity is not a parameter of the merge. `sourceID` and `url` are taken
    /// from `self` and `details` is never consulted for them, so a detail page
    /// that resolves to a different URL cannot quietly turn this into a different
    /// series.
    ///
    /// "Knows nothing" is per field, not per fetch:
    /// - `nil` and `""` mean absent. A source that cannot parse a synopsis and a
    ///   source that parsed an empty one are indistinguishable at this layer, and
    ///   neither is worth discarding a known synopsis for.
    /// - `[]` genres mean absent. A detail page that lists no genres is far more
    ///   often one this plugin cannot read than a series that genuinely has none.
    /// - `.unknown` status means absent, which is exactly what the spec says an
    ///   unrecognized status degrades to.
    ///
    /// The cost is that a field cannot be *cleared* by a refresh — a series whose
    /// author was removed upstream keeps the old one. That is the right trade:
    /// upstream removals are rare, and a parser that broke overnight is not.
    public func enriched(with details: Series) -> Series {
        Series(
            sourceID: sourceID,
            url: url,
            title: details.title.isEmpty ? title : details.title,
            coverURL: details.coverURL ?? coverURL,
            synopsis: Self.preferring(details.synopsis, over: synopsis),
            author: Self.preferring(details.author, over: author),
            artist: Self.preferring(details.artist, over: artist),
            genres: details.genres.isEmpty ? genres : details.genres,
            status: details.status == .unknown ? status : details.status,
            // The detail page is authoritative about shape: it is the plugin's own
            // declared `type`, not something parsed off the page.
            contentType: details.contentType
        )
    }

    private static func preferring(_ incoming: String?, over existing: String?) -> String? {
        guard let incoming, !incoming.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return existing
        }
        return incoming
    }
}
