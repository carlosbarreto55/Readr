import Foundation

struct SettingsState {
    var preferences = ReaderPreferences()
    var sources: [SourceInfo] = []
    var appVersion = ""
    var isResetConfirmationPresented = false
}

enum SettingsAction: Sendable {
    case appeared
    case setTheme(ReaderTheme)
    case setFontDesign(ReaderFontDesign)
    case setTextScale(Double)
    case setPageLayout(ReaderPageLayout)
    case requestReset
    case cancelReset
    case confirmReset
}
