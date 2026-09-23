import SwiftUI

/// A chapter's download state at a glance: queued, progress, stored, or failed.
///
/// Shared by the Series chapter list and the Reader's chrome, so a chapter reads
/// the same wherever it is shown. Renders nothing for a chapter never queued.
struct DownloadStateIndicator: View {
    let state: DownloadState?

    var body: some View {
        switch state {
        case nil:
            EmptyView()
        case .pending:
            Image(systemName: "clock")
                .foregroundStyle(Palette.secondaryLabel)
                .accessibilityLabel("Queued for download")
        case .downloading(let progress):
            Group {
                if let fraction = progress.fraction {
                    ProgressView(value: fraction)
                        .progressViewStyle(.circular)
                } else {
                    ProgressView()
                }
            }
            .accessibilityLabel("Downloading")
        case .completed:
            Image(systemName: "arrow.down.circle.fill")
                .foregroundStyle(Palette.accent)
                .accessibilityLabel("Downloaded")
        case .failed:
            Image(systemName: "exclamationmark.circle")
                .foregroundStyle(Palette.secondaryLabel)
                .accessibilityLabel("Download failed")
        }
    }
}

#Preview("Download states") {
    HStack(spacing: Spacing.large) {
        DownloadStateIndicator(state: .pending)
        DownloadStateIndicator(state: .downloading(.indeterminate))
        DownloadStateIndicator(state: .downloading(DownloadProgress(completed: 3, total: 4)))
        DownloadStateIndicator(state: .completed)
        DownloadStateIndicator(state: .failed(message: "", isRetryable: true))
    }
    .padding()
}
