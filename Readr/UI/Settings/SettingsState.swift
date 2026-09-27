import Foundation

struct SettingsState {
    var appTheme = AppTheme.system
    var preferences = ReaderPreferences()
    var sources: [SourceInfo] = []
    var appVersion = ""
    var isResetConfirmationPresented = false
    var storageBytes: Int64 = 0
    var isDeleteDownloadsConfirmationPresented = false
    var isRebuildingSearchIndex = false

    var storageLabel: String {
        ByteCountFormatter.string(fromByteCount: storageBytes, countStyle: .file)
    }
}

enum SettingsAction: Sendable, Equatable {
    case appeared
    case setAppTheme(AppTheme)
    case setReaderTheme(ReaderTheme)
    case setFontDesign(ReaderFontDesign)
    case setTextScale(Double)
    case setPageLayout(ReaderPageLayout)
    case setMangaPageLayout(ReaderPageLayout)
    case setComicPageLayout(ReaderPageLayout)
    case requestReset
    case cancelReset
    case confirmReset
    case requestDeleteDownloads
    case cancelDeleteDownloads
    case confirmDeleteDownloads
    case rebuildSearchIndex
}
