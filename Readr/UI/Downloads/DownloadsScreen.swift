import SwiftUI

struct DownloadsScreen: View {
    @Environment(\.appContainer) private var container
    @Environment(NavigationState.self) private var navigation
    @State private var model: DownloadsModel?

    var body: some View {
        Group {
            if let model {
                DownloadsContent(state: model.state, onAction: model.onAction)
                    .task { await model.observe() }
                    .task {
                        for await effect in model.effects {
                            guard !Task.isCancelled else { break }
                            switch effect {
                            case .openSeries(let id):
                                navigation.downloadsPath.append(.series(id))
                            }
                        }
                    }
            } else if let container {
                ProgressView()
                    .task {
                        guard model == nil else { return }
                        model = DownloadsModel(downloads: container.downloads)
                    }
            } else {
                ContentUnavailableView {
                    Label("Downloads Unavailable", systemImage: "exclamationmark.triangle")
                } description: {
                    Text("Readr’s app container was not installed in this view.")
                }
                .navigationTitle("Downloads")
            }
        }
    }
}
