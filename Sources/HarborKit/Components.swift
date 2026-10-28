import AppKit
import SwiftUI

/// A key as printed on a keyboard, for hints.
public struct Keycap: View {
    @Environment(\.palette) private var palette
    let key: String
    var compact: Bool

    public init(key: String, compact: Bool = false) {
        self.key = key
        self.compact = compact
    }

    public var body: some View {
        Text(key)
            .font(.system(size: compact ? 9 : 10.5, weight: .semibold))
            .foregroundStyle(palette.ink2)
            .padding(.horizontal, compact ? 4 : 5)
            .frame(minWidth: compact ? 15 : 18, minHeight: compact ? 15 : 18)
            .background(RoundedRectangle(cornerRadius: compact ? 4 : 5, style: .continuous).fill(palette.card))
            .overlay(RoundedRectangle(cornerRadius: compact ? 4 : 5, style: .continuous).strokeBorder(palette.hairline))
    }
}

/// Presses shrink a touch the moment the mouse goes down, not on release.
public struct PressableStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.harborPress, value: configuration.isPressed)
    }
}

/// The Harbor button: ink fill and cream text, or a quiet card.
public struct HarborButtonStyle: ButtonStyle {
    var prominent: Bool

    public init(prominent: Bool = true) {
        self.prominent = prominent
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(prominent ? Theme.background : Theme.ink)
            .padding(.horizontal, 14)
            .frame(height: 30)
            .background(
                Capsule().fill(prominent ? Theme.ink : Theme.card)
                    .overlay(Capsule().strokeBorder(prominent ? Color.clear : Theme.hairline))
            )
            .brightness(configuration.isPressed ? -0.06 : 0)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.harborPress, value: configuration.isPressed)
            .contentShape(Capsule())
    }
}

/// A row of colour dots, one per highlight, for any Harbor settings screen.
public struct AccentPicker: View {
    @Binding var selection: String

    public init(selection: Binding<String>) {
        _selection = selection
    }

    public var body: some View {
        HStack(spacing: 8) {
            ForEach(Accent.all) { accent in
                let selected = accent.id == selection
                Button { selection = accent.id } label: {
                    Circle()
                        .fill(accent.color)
                        .frame(width: 18, height: 18)
                        .padding(3)
                        .overlay(Circle().strokeBorder(selected ? Color.primary : .clear, lineWidth: 1.5))
                }
                .buttonStyle(PressableStyle())
                .help(accent.name)
                .accessibilityLabel(accent.name)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }
}

/// Fixed-size tiles in rows, with a short last row centred under the others
/// rather than hanging to the left.
public struct TileGrid: Layout {
    var tile: CGSize
    var columns: Int
    var spacing: CGFloat

    public init(tile: CGSize, columns: Int, spacing: CGFloat) {
        self.tile = tile
        self.columns = max(1, columns)
        self.spacing = spacing
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let count = subviews.count
        guard count > 0 else { return .zero }
        let cols = min(columns, count)
        let rows = (count + columns - 1) / columns
        return CGSize(width: CGFloat(cols) * tile.width + CGFloat(cols - 1) * spacing,
                      height: CGFloat(rows) * tile.height + CGFloat(rows - 1) * spacing)
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let count = subviews.count
        for index in 0..<count {
            let row = index / columns
            let inRow = min(columns, count - row * columns)
            let rowWidth = CGFloat(inRow) * tile.width + CGFloat(inRow - 1) * spacing
            let x = bounds.minX + (bounds.width - rowWidth) / 2 + CGFloat(index % columns) * (tile.width + spacing)
            let y = bounds.minY + CGFloat(row) * (tile.height + spacing)
            subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(tile))
        }
    }
}
