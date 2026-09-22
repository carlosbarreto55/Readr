import Foundation

/// Source metadata as the rest of the app sees it.
///
/// Presentation obtains this from a repository. It is the reason a presentation
/// model never needs `SourceRegistry` or a concrete source type.
public struct SourceInfo: Sendable, Identifiable, Hashable, Codable {
    public let id: Int64
    public let name: String
    public let lang: String
    public let baseURL: URL
    public let contentType: ContentType

    public init(id: Int64, name: String, lang: String, baseURL: URL, contentType: ContentType) {
        self.id = id
        self.name = name
        self.lang = lang
        self.baseURL = baseURL
        self.contentType = contentType
    }
}
