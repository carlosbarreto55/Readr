import SwiftUI

/// The root shown when the store could not be opened.
///
/// The app deliberately stops here rather than starting with an empty library.
/// Deleting the store would make this screen go away and take the reader's entire
/// library and reading progress with it — see `architecture.md` §6.2. A reader who
/// sees this still has their data; a reader who never sees it does not.
struct StoreUnavailableView: View {
    let error: any Error

    var body: some View {
        ContentUnavailableView {
            Label("Can't open your library", systemImage: "exclamationmark.triangle")
        } description: {
            Text(
                """
                Readr found your saved data but could not open it, so it has not \
                changed anything. Your library is still on this device.
                """
            )
        } actions: {
            Text(error.localizedDescription)
                .font(Typography.caption)
                .foregroundStyle(Palette.secondaryLabel)
                .multilineTextAlignment(.center)
                .textSelection(.enabled)
                .padding(.horizontal, Spacing.large)
        }
    }
}

#Preview {
    StoreUnavailableView(
        error: NSError(
            domain: "ReadrPreview",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "The store is in an unrecognised format."]
        )
    )
}
