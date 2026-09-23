import Testing

@Suite("FixtureLoader")
struct FixtureLoaderTests {
    @Test("A missing fixture fails loudly with its requested path")
    func missingFixtureThrows() {
        #expect(throws: FixtureLoaderError.missing("missing/site.html")) {
            try loadFixture("missing/site.html")
        }
    }
}
