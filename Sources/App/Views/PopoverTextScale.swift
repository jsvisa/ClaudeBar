import SwiftUI
import Domain

// MARK: - Text Scale

extension PopoverTextSize {
    /// Multiplier applied to every point size in the popover.
    ///
    /// Domain models the user's choice; the concrete numbers are a rendering
    /// decision and live here, beside the wrapper that applies them — the same
    /// split `MenuBarStackedSize` has with the stacked menu bar's point sizes.
    var textScale: CGFloat {
        switch self {
        case .medium: 1.0
        case .large: 1.2
        case .extraLarge: 1.4
        }
    }

    /// `size` in points at this text size.
    func scaled(_ size: CGFloat) -> CGFloat {
        size * textScale
    }
}

// MARK: - Popover Text Size Environment Key

/// Environment key carrying the popover's text size down the view tree.
private struct PopoverTextSizeKey: EnvironmentKey {
    static let defaultValue: PopoverTextSize = .default
}

extension EnvironmentValues {
    /// The text size the popover renders at.
    ///
    /// Injected where the popover is hosted, so every popover view reads the
    /// user's choice from the environment instead of threading it through
    /// initializers.
    var popoverTextSize: PopoverTextSize {
        get { self[PopoverTextSizeKey.self] }
        set { self[PopoverTextSizeKey.self] = newValue }
    }
}

// MARK: - Font Wrapper

/// Applies one of the popover's point sizes, scaled by the user's choice.
///
/// macOS' Text Size accessibility setting cannot do this job: it rescales
/// *semantic* fonts only, and the popover names every size explicitly so the
/// layout stays the designer's. Scaling here keeps one scale factor for the
/// whole popover, and the width grows with it (`PopoverContentWidth`), so a line
/// that fits at one size still fits at the next.
private struct PopoverFontModifier: ViewModifier {
    let size: CGFloat
    let weight: Font.Weight?
    let design: Font.Design?
    @Environment(\.popoverTextSize) private var popoverTextSize

    func body(content: Content) -> some View {
        content.font(.system(size: popoverTextSize.scaled(size), weight: weight, design: design))
    }
}

extension View {
    /// Popover text at `size` points, scaled by the user's Text Size setting.
    ///
    /// Every font drawn inside the popover goes through here, not just the quota
    /// cards: the header and provider pills, the session and cost cards, the
    /// embedded web card, and the share-pass overlays that cover the whole
    /// popover. A font left behind here is a font that stays 8pt at Extra Large
    /// and puts the setting half-applied.
    ///
    /// ## Usage
    /// ```swift
    /// Text("SESSION")
    ///     .popoverFont(8, weight: .medium, design: theme.fontDesign)
    /// ```
    func popoverFont(
        _ size: CGFloat,
        weight: Font.Weight? = nil,
        design: Font.Design? = nil
    ) -> some View {
        modifier(PopoverFontModifier(size: size, weight: weight, design: design))
    }
}