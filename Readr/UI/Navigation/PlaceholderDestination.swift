import SwiftUI

/// Stands in for a feature that has not been built yet.
///
/// It names the missing feature rather than showing a blank surface, a spinner
/// that never resolves, or an error. "Not built yet" and "nothing here" are
/// different messages, and a reader deserves to be told which one they are
/// looking at.
struct PlaceholderDestination: View {
    let tab: AppTab

    var body: some View {
        ContentUnavailableView {
            Label(tab.title, systemImage: tab.systemImage)
        } description: {
            Text(description)
        }
        .navigationTitle(tab.title)
    }

    private var description: String {
        switch tab {
        case .library:
            "Series you save will be collected here. The library is not built yet."
        case .browse:
            "Sources you can browse will be listed here. No source is available yet."
        case .downloads:
            "Chapters saved for offline reading will appear here. Downloads are not built yet."
        case .settings:
            "Reader, source, and storage settings will live here. Settings are not built yet."
        }
    }
}

#Preview("Every placeholder") {
    TabView {
        ForEach(AppTab.allCases) { tab in
            NavigationStack {
                PlaceholderDestination(tab: tab)
            }
            .tabItem { Label(tab.title, systemImage: tab.systemImage) }
        }
    }
}
