import SwiftUI

/// Wires one Browse source-list or catalog model to app dependencies and routes.
struct BrowseScreen: View {
    let sourceID: Int64?

    @Environment(\.appContainer) private var container
    @Environment(NavigationState.self) private var navigation
    @State private var model: BrowseModel?

    init(sourceID: Int64? = nil) {
        self.sourceID = sourceID
    }

    var body: some View {
        Group {
            if let model {
                BrowseContent(state: model.state, onAction: model.onAction)
            } else if container == nil {
                ContentUnavailableView {
                    Label("Browse Unavailable", systemImage: "exclamationmark.triangle")
                } description: {
                    Text("The app dependencies were not provided.")
                }
            } else {
                ProgressView()
            }
        }
        .task(id: container.map(ObjectIdentifier.init)) {
            await runModel()
        }
        .onChange(of: navigation.selectedTab) { _, selectedTab in
            guard selectedTab == .browse, let model else { return }
            model.onAction(.refreshMembership)
        }
    }

    @MainActor
    private func runModel() async {
        guard let container else { return }

        let activeModel: BrowseModel
        if let model {
            activeModel = model
        } else {
            let newModel = BrowseModel(
                sourceID: sourceID,
                catalog: container.catalog,
                library: container.library
            )
            model = newModel
            activeModel = newModel
            newModel.onAction(.appeared)
        }

        for await effect in activeModel.effects {
            guard !Task.isCancelled else { return }
            switch effect {
            case .openSource(let sourceID):
                navigation.browsePath.append(.catalog(sourceID: sourceID))
            case .openSeries(let id):
                navigation.browsePath.append(.series(id))
            }
        }
    }
}
