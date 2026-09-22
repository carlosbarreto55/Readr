import Foundation
import Testing

@testable import Readr

@Suite("SourceRegistry")
struct SourceRegistryTests {

    private let novel = StubSource(name: "Novel Site", type: .novel)
    private let manhwa = StubSource(name: "Manhwa Site", type: .manhwa)

    @Test("A registered source is resolvable by its identifier")
    func lookupHit() {
        let registry = SourceRegistry([novel, manhwa])
        #expect(registry[novel.id]?.name == "Novel Site")
        #expect(registry[manhwa.id]?.name == "Manhwa Site")
    }

    @Test("An unregistered identifier resolves to nothing")
    func lookupMiss() {
        let registry = SourceRegistry([novel])
        #expect(registry[manhwa.id] == nil)
        #expect(registry[0] == nil)
    }

    @Test("An empty registry is valid")
    func emptyRegistry() {
        let registry = SourceRegistry([])
        #expect(registry.isEmpty)
        #expect(registry.all.isEmpty)
        #expect(registry[novel.id] == nil)
    }

    @Test("Sources are listed in a stable order regardless of registration order")
    func stableOrdering() {
        #expect(SourceRegistry([novel, manhwa]).all.map(\.name) == ["Manhwa Site", "Novel Site"])
        #expect(SourceRegistry([manhwa, novel]).all.map(\.name) == ["Manhwa Site", "Novel Site"])
    }

    /// Presentation reads source metadata as domain values, which is what lets a
    /// presentation model stay clear of the registry and of concrete source types.
    @Test("The registry projects its sources as domain metadata")
    func projectsDomainInfo() {
        let infos = SourceRegistry([novel, manhwa]).infos
        #expect(infos.map(\.id) == [manhwa.id, novel.id])
        #expect(infos.map(\.contentType) == [.manhwa, .novel])
    }

    @Test("Sources differing only in content type do not collide")
    func sameNameDifferentTypeCoexist() {
        let asNovel = StubSource(name: "Shared Name", type: .novel)
        let asManhwa = StubSource(name: "Shared Name", type: .manhwa)
        let registry = SourceRegistry([asNovel, asManhwa])
        #expect(asNovel.id != asManhwa.id)
        #expect(registry[asNovel.id]?.type == .novel)
        #expect(registry[asManhwa.id]?.type == .manhwa)
    }

    @Test("A source's identifier is derived, not hand-picked")
    func identityIsDerived() {
        #expect(novel.id == computeSourceID(name: "Novel Site", lang: "en", type: .novel))
    }

    @Test("A source returns only the content shape its type declares")
    func contentShapeMatchesType() async throws {
        let chapter = Chapter(
            sourceID: novel.id,
            seriesURL: URL(string: "https://example.test/s")!,
            url: URL(string: "https://example.test/s/1")!,
            name: "One"
        )
        #expect(try await novel.chapterContent(for: chapter).contentType == .novel)
        #expect(try await manhwa.chapterContent(for: chapter).contentType == .manhwa)
    }
}
