/// How the Reader looks. Every value is the reader's own choice and is stored
/// through `SettingsStore`, so the Reader and Settings read the same keys.
public enum ReaderTheme: String, Sendable, Hashable, CaseIterable, Identifiable {
    /// Follows the system appearance.
    case system
    case light
    case sepia
    case dark

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .sepia: "Sepia"
        case .dark: "Dark"
        }
    }
}

public enum ReaderFontDesign: String, Sendable, Hashable, CaseIterable, Identifiable {
    case system
    case serif

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .system: "System"
        case .serif: "Serif"
        }
    }
}

/// How manhwa pages are laid out.
public enum ReaderPageLayout: String, Sendable, Hashable, CaseIterable, Identifiable {
    /// One continuous vertical run — how webtoons are drawn to be read.
    case vertical
    /// One page at a time, turned horizontally.
    case paged

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .vertical: "Vertical Scroll"
        case .paged: "Paged"
        }
    }
}

/// The Reader's appearance as one value.
public struct ReaderPreferences: Sendable, Hashable {
    public var theme: ReaderTheme
    public var fontDesign: ReaderFontDesign
    /// Multiplies the Dynamic Type body size; it never replaces it.
    public var textScale: Double
    public var pageLayout: ReaderPageLayout

    public init(
        theme: ReaderTheme = .system,
        fontDesign: ReaderFontDesign = .system,
        textScale: Double = 1,
        pageLayout: ReaderPageLayout = .vertical
    ) {
        self.theme = theme
        self.fontDesign = fontDesign
        self.textScale = Self.clampedScale(textScale)
        self.pageLayout = pageLayout
    }

    public static let textScaleRange: ClosedRange<Double> = 0.8...2.0
    public static let textScaleStep = 0.1

    /// Clamped to the supported range and rounded to the step, so a stored value
    /// from a build with different bounds still reads back as something offered.
    public static func clampedScale(_ scale: Double) -> Double {
        guard scale.isFinite else { return 1 }
        let clamped = min(max(scale, textScaleRange.lowerBound), textScaleRange.upperBound)
        return (clamped / textScaleStep).rounded() * textScaleStep
    }
}

/// The settings keys reader preferences are stored under.
public enum ReaderSettingKeys {
    public static let theme = RawSettingKey("readr.reader.theme", default: ReaderTheme.system)
    public static let fontDesign = RawSettingKey(
        "readr.reader.fontDesign", default: ReaderFontDesign.system)
    public static let textScale = SettingKey("readr.reader.textScale", default: 1.0)
    public static let pageLayout = RawSettingKey(
        "readr.reader.pageLayout", default: ReaderPageLayout.vertical)
}

extension SettingsStore {
    /// The reader's stored appearance, defaults where nothing is stored.
    public var readerPreferences: ReaderPreferences {
        ReaderPreferences(
            theme: value(for: ReaderSettingKeys.theme),
            fontDesign: value(for: ReaderSettingKeys.fontDesign),
            textScale: value(for: ReaderSettingKeys.textScale),
            pageLayout: value(for: ReaderSettingKeys.pageLayout)
        )
    }

    public func setReaderPreferences(_ preferences: ReaderPreferences) {
        set(preferences.theme, for: ReaderSettingKeys.theme)
        set(preferences.fontDesign, for: ReaderSettingKeys.fontDesign)
        set(preferences.textScale, for: ReaderSettingKeys.textScale)
        set(preferences.pageLayout, for: ReaderSettingKeys.pageLayout)
    }
}
