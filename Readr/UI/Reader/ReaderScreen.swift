import SwiftUI

/// Wires the Reader model to app dependencies and handles its effects.
///
/// Presented as a full-screen cover from the app shell, outside every tab's
/// navigation path (`architecture.md` §9).
struct ReaderScreen: View {
    let route: ReaderRoute

    @Environment(\.appContainer) private var container
    @Environment(\.dismiss) private var dismiss
    @State private var model: ReaderModel?

    var body: some View {
        Group {
            if let model {
                ReaderContent(state: model.state, onAction: model.onAction)
            } else if container == nil {
                ContentUnavailableView {
                    Label("Reader Unavailable", systemImage: "exclamationmark.triangle")
                } description: {
                    Text("Readr’s app container was not installed in this view.")
                } actions: {
                    Button("Close") { dismiss() }
                }
            } else {
                ProgressView()
            }
        }
        .task(id: route) {
            await runModel()
        }
    }

    @MainActor
    private func runModel() async {
        guard let container else { return }

        let activeModel: ReaderModel
        if let model {
            activeModel = model
        } else {
            let newModel = ReaderModel(
                route: route, repository: container.chapters, settings: container.settings)
            model = newModel
            activeModel = newModel
        }
        activeModel.onAction(.appeared)

        for await effect in activeModel.effects {
            guard !Task.isCancelled else { return }
            switch effect {
            case .close:
                // Let the last progress write land before whoever shows read
                // state reloads it.
                await activeModel.flushProgress()
                dismiss()
            }
        }
    }
}
