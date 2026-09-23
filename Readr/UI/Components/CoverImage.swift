import NukeUI
import SwiftUI

/// A catalog cover backed by the app's shared Nuke image pipeline.
///
/// Loading, absent, and failed images all keep the same footprint. The title is
/// rendered by `SeriesCard`, outside this view, so a failed cover never hides the
/// series' identity.
struct CoverImage: View {
    let url: URL?

    var body: some View {
        LazyImage(url: url, transaction: Transaction(animation: .easeInOut)) { state in
            if let image = state.image {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder
            }
        }
        .aspectRatio(2 / 3, contentMode: .fit)
        .background(Palette.coverPlaceholder)
        .clipShape(.rect(cornerRadius: Spacing.small))
        .clipped()
        .accessibilityHidden(true)
    }

    private var placeholder: some View {
        ZStack {
            Palette.coverPlaceholder
            Image(systemName: "book.closed")
                .font(.title)
                .foregroundStyle(Palette.secondaryLabel)
        }
    }
}

#Preview("Cover placeholders") {
    HStack {
        CoverImage(url: nil)
        CoverImage(url: URL(string: "https://example.invalid/cover.jpg"))
    }
    .frame(maxWidth: 280)
    .padding()
}
