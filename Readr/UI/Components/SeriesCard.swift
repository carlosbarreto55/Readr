import SwiftUI

/// The renderable catalog value shared by Library and Browse.
struct SeriesCardItem: Identifiable, Sendable {
    let series: Series
    let sourceName: String
    let isSaved: Bool

    var id: SeriesID { series.id }
}

/// A platform context-menu action for library membership.
enum SeriesCardMembershipAction: Sendable, Equatable {
    case add
    case remove

    var title: String {
        switch self {
        case .add: "Add to Library"
        case .remove: "Remove from Library"
        }
    }

    var systemImage: String {
        switch self {
        case .add: "plus"
        case .remove: "trash"
        }
    }
}

/// Cover, title, source, and platform-standard per-item actions.
struct SeriesCard: View {
    let item: SeriesCardItem
    let onOpen: () -> Void
    let onMembershipAction: () -> Void

    private var membershipAction: SeriesCardMembershipAction {
        item.isSaved ? .remove : .add
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.small) {
            CoverImage(url: item.series.coverURL)

            // `displayTitle`, never `title`: a series whose title failed to
            // parse still needs a label to be found, tapped, and removed.
            Text(item.series.displayTitle)
                .font(Typography.cardTitle)
                .foregroundStyle(Palette.label)
                .lineLimit(3)
                .truncationMode(.tail)
                .multilineTextAlignment(.leading)

            Text(item.sourceName)
                .font(Typography.caption)
                .foregroundStyle(Palette.secondaryLabel)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
        .onTapGesture(perform: onOpen)
        .contextMenu {
            Button(
                role: membershipAction == .remove ? .destructive : nil,
                action: onMembershipAction
            ) {
                Label(membershipAction.title, systemImage: membershipAction.systemImage)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens series details")
    }
}

#Preview("Series cards") {
    let sourceID: Int64 = 42
    HStack(alignment: .top, spacing: Spacing.large) {
        SeriesCard(
            item: SeriesCardItem(
                series: Series(
                    sourceID: sourceID,
                    url: URL(string: "https://example.test/short")!,
                    title: "A Short Title",
                    contentType: .novel
                ),
                sourceName: "FreeWebNovel",
                isSaved: false
            ),
            onOpen: {},
            onMembershipAction: {}
        )

        SeriesCard(
            item: SeriesCardItem(
                series: Series(
                    sourceID: sourceID,
                    url: URL(string: "https://example.test/long")!,
                    title:
                        "A Very Long Series Title That Needs More Than One Line to Stay Readable",
                    coverURL: URL(string: "https://example.invalid/missing.jpg"),
                    contentType: .manhwa
                ),
                sourceName: "AsuraScans",
                isSaved: true
            ),
            onOpen: {},
            onMembershipAction: {}
        )
    }
    .padding()
}
