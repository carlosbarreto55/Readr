import SwiftUI

/// A recoverable failure shown above content without replacing it: what went
/// wrong, and optionally a retry, always a dismiss.
///
/// For failures where the screen still has something true to show — a stale
/// chapter list, a library whose removal did not go through.
struct FailureBanner: View {
    var title: String?
    let message: String
    var retry: (() -> Void)?
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            if let title {
                Text(title)
                    .font(Typography.cardTitle)
            }
            Text(message)
                .font(Typography.caption)
                .foregroundStyle(Palette.secondaryLabel)
            HStack {
                if let retry {
                    Button("Try Again", action: retry)
                        .buttonStyle(.borderedProminent)
                }
                Button("Dismiss", action: dismiss)
                    .buttonStyle(.bordered)
            }
        }
        .padding(Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface)
        .clipShape(.rect(cornerRadius: Spacing.small))
    }
}

#Preview("Failure banners") {
    VStack(spacing: Spacing.large) {
        FailureBanner(
            title: "Couldn’t remove The Swordmaster",
            message: "The library could not be written.",
            retry: {}, dismiss: {})
        FailureBanner(message: "Couldn’t refresh. The network connection was lost.", dismiss: {})
    }
    .padding()
}
