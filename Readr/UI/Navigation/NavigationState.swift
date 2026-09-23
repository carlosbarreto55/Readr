import Foundation
import Observation

/// Which top-level destination is selected, and where each one has navigated to.
///
/// Every tab keeps its own path. Selecting a different tab must never clear,
/// truncate, or reorder another tab's path — a reader who is three levels deep in
/// Library and glances at Downloads expects to come back to where they were.
@Observable
@MainActor
public final class NavigationState {
    public var selectedTab: AppTab = .library

    public var libraryPath: [LibraryRoute] = []
    public var browsePath: [BrowseRoute] = []
    public var downloadsPath: [DownloadsRoute] = []
    public var settingsPath: [SettingsRoute] = []

    /// The chapter the Reader is presenting, outside every tab's path.
    ///
    /// Clearing it closes the Reader and bumps `libraryRevision`, because reading
    /// changed progress that Library and Series display.
    public var presentedReader: ReaderRoute? {
        didSet {
            if oldValue != nil, presentedReader == nil {
                libraryDidChange()
            }
        }
    }

    /// Bumped when stored library state changed outside the screen showing it — a
    /// background or activation refresh, or reading — so visible screens reload.
    public private(set) var libraryRevision = 0

    public func libraryDidChange() {
        libraryRevision += 1
    }

    public init() {}

    /// How deep a tab has navigated. `0` is its root.
    public func depth(of tab: AppTab) -> Int {
        switch tab {
        case .library: libraryPath.count
        case .browse: browsePath.count
        case .downloads: downloadsPath.count
        case .settings: settingsPath.count
        }
    }

    /// Returns a tab to its root, leaving every other tab untouched.
    public func popToRoot(_ tab: AppTab) {
        switch tab {
        case .library: libraryPath.removeAll()
        case .browse: browsePath.removeAll()
        case .downloads: downloadsPath.removeAll()
        case .settings: settingsPath.removeAll()
        }
    }
}
