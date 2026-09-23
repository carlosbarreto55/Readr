import Foundation

/// `SystemSearchRepository` over the library and the Spotlight projection.
struct DefaultSystemSearchRepository: SystemSearchRepository {
    let library: any LibraryRepository
    let projection: SpotlightProjection

    func resolve(activityIdentifier: String) async -> SystemSearchResolution {
        guard let id = SpotlightIdentifier.seriesID(from: activityIdentifier) else {
            return .unrecognized
        }
        do {
            guard try await library.isSaved(id) else {
                // The index outlived the library entry. Remove it so the result
                // stops appearing (`library-search-via-spotlight`).
                await projection.remove([id])
                return .noLongerSaved
            }
            return .series(id)
        } catch {
            // The library could not be read. Open the series and let its screen
            // say so, rather than deleting an entry that may be valid.
            return .series(id)
        }
    }

    func rebuildIndex() async {
        // An unreadable library leaves the index alone: rebuilding from nothing
        // would erase a projection that may still be right.
        guard let saved = try? await library.savedSeries() else { return }
        await projection.rebuild(saved)
    }
}
