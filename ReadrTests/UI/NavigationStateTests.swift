import Foundation
import Testing

@testable import Readr

/// Every tab keeps its own path. Selecting a different tab must never clear,
/// truncate, or reorder another tab's path.
@Suite("NavigationState")
@MainActor
struct NavigationStateTests {
    private let seriesID = SeriesID(
        sourceID: 1, url: URL(string: "https://example.test/series/one")!)

    @Test("Library is the destination shown on launch, with every tab at its root")
    func initialState() {
        let navigation = NavigationState()
        #expect(navigation.selectedTab == .library)
        for tab in AppTab.allCases {
            #expect(navigation.depth(of: tab) == 0)
        }
    }

    @Test("A path survives switching away and back")
    func pathSurvivesTabSwitch() {
        let navigation = NavigationState()
        navigation.libraryPath.append(.series(seriesID))

        navigation.selectedTab = .downloads
        navigation.selectedTab = .library

        #expect(navigation.libraryPath == [.series(seriesID)])
        #expect(navigation.depth(of: .library) == 1)
    }

    @Test("Pushing on one tab leaves every other tab untouched")
    func pathsDoNotInterfere() {
        let navigation = NavigationState()
        navigation.libraryPath.append(.series(seriesID))

        #expect(navigation.depth(of: .browse) == 0)
        #expect(navigation.depth(of: .downloads) == 0)
        #expect(navigation.depth(of: .settings) == 0)
    }

    @Test("Returning one tab to its root affects only that tab")
    func popToRootIsScoped() {
        let navigation = NavigationState()
        navigation.libraryPath.append(.series(seriesID))
        navigation.browsePath.append(.catalog(sourceID: 1))
        navigation.settingsPath.append(.reader)

        navigation.popToRoot(.library)

        #expect(navigation.depth(of: .library) == 0)
        #expect(navigation.depth(of: .browse) == 1)
        #expect(navigation.depth(of: .settings) == 1)
    }

    @Test("Paths keep push order")
    func pathsKeepOrder() {
        let navigation = NavigationState()
        navigation.browsePath.append(.catalog(sourceID: 7))
        navigation.browsePath.append(.series(seriesID))
        #expect(navigation.browsePath == [.catalog(sourceID: 7), .series(seriesID)])
    }
}
