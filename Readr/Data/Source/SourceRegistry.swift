import Foundation

/// Resolves a source by its identifier.
///
/// Built once by the composition root and never mutated. There is no dynamic
/// loading — iOS does not permit it and the app does not need it.
public struct SourceRegistry: Sendable {
    private let sourcesByID: [Int64: any Source]

    /// - Precondition: no two sources share an `id`. A collision would mean two
    ///   sites keying their stored series and downloads identically, so it is a
    ///   composition-time programming error rather than a runtime condition.
    public init(_ sources: [any Source]) {
        var byID: [Int64: any Source] = [:]
        for source in sources {
            precondition(
                byID[source.id] == nil,
                "Duplicate sourceID \(source.id): '\(source.name)' collides with "
                    + "'\(byID[source.id]?.name ?? "")'. Source IDs are computed from "
                    + "(name, lang, type) — two sources cannot share all three."
            )
            byID[source.id] = source
        }
        self.sourcesByID = byID
    }

    /// The source with this identifier, or `nil` if none is registered.
    public subscript(id: Int64) -> (any Source)? {
        sourcesByID[id]
    }

    /// Every registered source, ordered by name for stable presentation.
    public var all: [any Source] {
        sourcesByID.values.sorted { $0.name < $1.name }
    }

    /// Every registered source as domain metadata.
    public var infos: [SourceInfo] {
        all.map(\.info)
    }

    public var isEmpty: Bool { sourcesByID.isEmpty }
}
