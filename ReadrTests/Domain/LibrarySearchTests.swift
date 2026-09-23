import Testing

@testable import Readr

@Suite("Library search matching")
struct LibrarySearchTests {

    @Test(
        "Matching ignores case, diacritics, and surrounding whitespace",
        arguments: [
            ("naruto", "Naruto"),
            ("SOLO LEVELING", "Solo Leveling"),
            ("pokemon", "Pokémon Adventures"),
            ("  crème ", "La Crème de la Crème"),
            ("amelie", "Amélie"),
            ("level", "Solo Leveling")
        ])
    func matches(query: String, title: String) {
        #expect(LibrarySearch.matches(query, title: title))
    }

    @Test("A title without the query does not match")
    func noMatch() {
        #expect(!LibrarySearch.matches("dragon", title: "Solo Leveling"))
    }

    @Test("An empty or blank query matches everything and is inactive")
    func emptyQuery() {
        #expect(LibrarySearch.matches("", title: "Anything"))
        #expect(LibrarySearch.matches("   ", title: "Anything"))
        #expect(!LibrarySearch.isActive("  "))
        #expect(LibrarySearch.isActive("a"))
    }
}
