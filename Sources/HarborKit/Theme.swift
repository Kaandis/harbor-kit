import AppKit
import SwiftUI

/// Harbor design tokens: warm cream surfaces, ink text, one quiet highlight.
public enum Theme {
    public static let background = dynamic(light: 0xfbf3ea, dark: 0x1d1916)
    public static let raised = dynamic(light: 0xf4e8da, dark: 0x29231f)
    public static let card = dynamic(light: 0xfffbf6, dark: 0x332c27)
    public static let ink = dynamic(light: 0x231f1c, dark: 0xf6ece2)
    public static let ink2 = dynamic(light: 0x6e625a, dark: 0xc0b1a4)
    public static let ink3 = dynamic(light: 0x857568, dark: 0x9e8e80)
    public static let coral = Color(nsColor: NSColor(hex: 0xe8664f))
    public static let hairline = dynamic(light: 0x231f1c, dark: 0xffffff, alpha: 0.08)

    /// The tint laid over a translucent surface, so glass reads cream rather than grey.
    public static let surfaceTint = dynamic(light: 0xfbf3ea, dark: 0x1d1916, alpha: 0.78)

    /// A colour that follows light and dark appearance.
    public static func dynamic(light: Int, dark: Int, alpha: CGFloat = 1) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light, alpha: alpha)
        })
    }
}

/// The colour of selections and carets. Pebble, a soft grey, is the default;
/// every option keeps about 3:1 against Harbor's tiles.
public struct Accent: Identifiable, Equatable, Sendable {
    public let id: String
    public let color: Color

    /// The name in the interface language.
    public var name: String {
        String(localized: String.LocalizationValue(id.prefix(1).uppercased() + id.dropFirst()), bundle: .module)
    }

    public static func == (a: Accent, b: Accent) -> Bool { a.id == b.id }

    public static let all: [Accent] = [
        Accent(id: "pebble", color: Theme.dynamic(light: 0x8f8881, dark: 0xa8a098)),
        Accent(id: "sky", color: Theme.dynamic(light: 0x3d8fd6, dark: 0x6fb4ee)),
        Accent(id: "mint", color: Theme.dynamic(light: 0x2f9e74, dark: 0x5fc79e)),
        Accent(id: "lilac", color: Theme.dynamic(light: 0x8a6fd0, dark: 0xb39cec)),
        Accent(id: "sun", color: Theme.dynamic(light: 0xd99a1e, dark: 0xf2c25a)),
        Accent(id: "coral", color: Theme.coral),
        Accent(id: "graphite", color: Theme.dynamic(light: 0x3a3532, dark: 0xd8d0c8)),
        Accent(id: "system", color: Color(nsColor: .controlAccentColor)),
    ]

    public static let pebble = all[0]

    public static func named(_ id: String) -> Accent { all.first { $0.id == id } ?? .pebble }
}

/// Springs. Critically damped by default: SwiftUI springs retarget from the
/// current value and velocity, so every transition stays interruptible.
public extension Animation {
    /// Panels and pages appearing and leaving.
    static let harborPresent = Animation.spring(response: 0.28, dampingFraction: 1)
    /// A selection sliding between items.
    static let harborSelect = Animation.spring(response: 0.2, dampingFraction: 1)
    /// Press feedback: short and immediate.
    static let harborPress = Animation.spring(response: 0.12, dampingFraction: 1)
}

public extension NSColor {
    convenience init(hex: Int, alpha: CGFloat = 1) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xff) / 255,
                  green: CGFloat((hex >> 8) & 0xff) / 255,
                  blue: CGFloat(hex & 0xff) / 255,
                  alpha: alpha)
    }
}

/// The colours a floating surface draws with. Cream is Harbor's own look;
/// Liquid Glass hands the surface to the system and switches text to
/// vibrant system colours so it reads over any wallpaper.
public struct Palette: Sendable {
    public var isGlass = false
    public var ink = Theme.ink
    public var ink2 = Theme.ink2
    public var ink3 = Theme.ink3
    public var card = Theme.card
    public var raised = Theme.raised
    public var hairline = Theme.hairline

    public static let cream = Palette()
    public static let glass = Palette(isGlass: true,
                                      ink: .primary,
                                      ink2: .secondary,
                                      ink3: Color(nsColor: .tertiaryLabelColor),
                                      card: Color.primary.opacity(0.07),
                                      raised: Color.primary.opacity(0.06),
                                      hairline: Color.primary.opacity(0.1))

    /// Liquid Glass needs macOS 26; earlier systems keep cream.
    public static func named(_ style: String) -> Palette {
        if #available(macOS 26, *), style == "glass" { return .glass }
        return .cream
    }
}

private struct PaletteKey: EnvironmentKey { static let defaultValue = Palette.cream }
private struct AccentKey: EnvironmentKey { static let defaultValue = Accent.pebble }
private struct StaticRenderKey: EnvironmentKey { static let defaultValue = false }

public extension EnvironmentValues {
    /// True while `ImageRenderer` draws a view: AppKit-backed materials don't
    /// render there, so surfaces fall back to their solid colour.
    var isStaticRender: Bool {
        get { self[StaticRenderKey.self] }
        set { self[StaticRenderKey.self] = newValue }
    }

    var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }

    var accent: Accent {
        get { self[AccentKey.self] }
        set { self[AccentKey.self] = newValue }
    }
}

/// A floating Harbor surface: system glass under a cream tint, or Liquid
/// Glass if chosen. Solid when the user asks for less transparency, outlined
/// when they ask for more contrast.
public struct HarborSurface: View {
    var cornerRadius: CGFloat
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.isStaticRender) private var isStaticRender
    @Environment(\.palette) private var palette

    public init(cornerRadius: CGFloat) {
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ZStack {
            if reduceTransparency || isStaticRender {
                shape.fill(palette.isGlass ? Color(nsColor: .windowBackgroundColor) : Theme.background)
            } else if palette.isGlass, #available(macOS 26, *) {
                LiquidGlass(cornerRadius: cornerRadius)
            } else {
                VisualEffectBlur()
                    .clipShape(shape)
                shape.fill(Theme.surfaceTint)
            }
        }
        .overlay(
            shape.strokeBorder(contrast == .increased ? palette.ink2 : palette.hairline,
                               lineWidth: contrast == .increased ? 1.5 : 1)
        )
    }
}

private struct VisualEffectBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

/// AppKit's Liquid Glass view, as a panel background.
@available(macOS 26, *)
private struct LiquidGlass: NSViewRepresentable {
    var cornerRadius: CGFloat

    func makeNSView(context: Context) -> NSGlassEffectView {
        let view = NSGlassEffectView()
        view.cornerRadius = cornerRadius
        return view
    }

    func updateNSView(_ view: NSGlassEffectView, context: Context) {
        view.cornerRadius = cornerRadius
    }
}
