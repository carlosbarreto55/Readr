import SwiftUI

/// Wires a series' detail model to app dependencies and handles its effects.
struct SeriesScreen: View {
    let id: SeriesID

    @Environment(\.appContainer) private var container
    @Environment(NavigationState.self) private var navigation
    @State private var model: SeriesModel?

    var body: some View {
        Group {
            if let model {
                SeriesContent(
                    state: model.state,
                    onAction: model.onAction,
                    onRefresh: { await model.refresh() }
                )
            } else if container == nil {
                ContentUnavailableView {
                    Label("Series Unavailable", systemImage: "exclamationmark.triangle")
                } description: {
                    Text("Readr’s app container was not installed in this view.")
                }
            } else {
                ProgressView("Loading Series…")
            }
        }
        .task(id: id) {
            await runModel()
        }
        .task(id: model == nil) {
            await model?.observeDownloads()
        }
        .onChange(of: navigation.libraryRevision) {
            // Reading or a refresh elsewhere changed what is stored.
            model?.onAction(.storedStateChanged)
        }
    }

    @MainActor
    private func runModel() async {
        guard let container else { return }

        let activeModel: SeriesModel
        if let model {
            activeModel = model
        } else {
            let newModel = SeriesModel(
                id: id,
                repository: container.series,
                library: container.library,
                catalog: container.catalog,
                settings: container.settings,
                downloads: container.downloads
            )
            model = newModel
            activeModel = newModel
        }
        activeModel.onAction(.appeared)

        for await effect in activeModel.effects {
            guard !Task.isCancelled else { return }
            switch effect {
            case .openReader(let route):
                navigation.presentedReader = route
            }
        }
    }
}
