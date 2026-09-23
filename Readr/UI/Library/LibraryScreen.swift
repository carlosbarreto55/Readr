import SwiftUI

struct LibraryScreen: View {
    @Environment(\.appContainer) private var container
    @Environment(NavigationState.self) private var navigation
    @State private var model: LibraryModel?

    var body: some View {
        Group {
            if let model {
                LibraryContent(
                    state: model.state,
                    onAction: model.onAction,
                    onRefresh: { await model.refreshLibrary() }
                )
                .task {
                    model.onAction(.appeared)
                    for await effect in model.effects {
                        guard !Task.isCancelled else { break }
                        handle(effect)
                    }
                }
            } else if let container {
                ProgressView("Loading Library…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .task {
                        guard model == nil else { return }
                        model = LibraryModel(
                            library: container.library,
                            catalog: container.catalog,
                            settings: container.settings,
                            refresher: container.series
                        )
                    }
            } else {
                ContentUnavailableView {
                    Label("Library Unavailable", systemImage: "exclamationmark.triangle")
                } description: {
                    Text("Readr’s app container was not installed in this view.")
                }
                .navigationTitle("Library")
            }
        }
        .onChange(of: navigation.libraryRevision) {
            guard let model else { return }
            Task { await model.load(showingProgress: false) }
        }
        .onChange(of: navigation.selectedTab) { _, selectedTab in
            guard selectedTab == .library, let model else { return }
            model.onAction(.appeared)
        }
    }

    private func handle(_ effect: LibraryEffect) {
        switch effect {
        case .openSeries(let id):
            navigation.libraryPath.append(.series(id))
        }
    }
}
