import Foundation

enum FixtureLoaderError: Error, Equatable {
    case missing(String)
}

private final class FixtureBundleToken: NSObject {}

/// Reads a saved source fixture from the unit-test bundle.
///
/// `project.yml` adds `ReadrTests/Fixtures` as a folder reference, so the
/// relative path is stable and two sites may both own a `popular.html` without
/// one flattening over the other.
func loadFixture(_ relativePath: String) throws -> String {
    let bundle = Bundle(for: FixtureBundleToken.self)
    guard let resources = bundle.resourceURL else {
        throw FixtureLoaderError.missing(relativePath)
    }

    let fixtureURL =
        resources
        .appending(path: "Fixtures", directoryHint: .isDirectory)
        .appending(path: relativePath, directoryHint: .notDirectory)
    guard FileManager.default.fileExists(atPath: fixtureURL.path) else {
        throw FixtureLoaderError.missing(relativePath)
    }

    return try String(contentsOf: fixtureURL, encoding: .utf8)
}
