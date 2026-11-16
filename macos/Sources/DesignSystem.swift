//
//  DesignSystem.swift
//  Burrow
//
//  Shared controls. Screens compose these instead of restyling a capsule
//  or a search field locally, so padding, radius, and type stay in one place.
//

import SwiftUI

/// Soft glass tile. macOS 26+ uses the system Liquid Glass effect; earlier
/// systems fall back to a thin material with a faint specular edge.
struct GlassBackground: ViewModifier {
    var corner: CGFloat = Brand.radiusCard

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)
        if #available(macOS 26, *) {
            content
                .glassEffect(.regular, in: shape)
                .overlay(specular(shape))
        } else {
            content
                .background(shape.fill(.ultraThinMaterial))
                .overlay(specular(shape))
        }
    }

    private func specular(_ shape: RoundedRectangle) -> some View {
        shape.strokeBorder(
            LinearGradient(
                colors: [Color.white.opacity(0.38), Color.white.opacity(0.05)],
                startPoint: .top, endPoint: .bottom),
            lineWidth: 0.7)
    }
}

extension View {
    func glassTile(corner: CGFloat = Brand.radiusCard) -> some View {
        modifier(GlassBackground(corner: corner))
    }
}

/// Circular quick action. Liquid Glass on macOS 26+, a material circle before that.
struct GlassCircleButton: View {
    let systemName: String
    var helpText: String
    let action: () -> Void

    var body: some View {
        if #available(macOS 26, *) {
            Button(action: action) {
                Image(systemName: systemName)
                    .font(.system(size: Brand.scaled(13), weight: .medium))
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .foregroundStyle(Brand.textPrimary)
            .help(helpText)
            .accessibilityLabel(helpText)
        } else {
            Button(action: action) {
                Image(systemName: systemName)
                    .font(.system(size: Brand.scaled(13), weight: .medium))
                    .foregroundStyle(Brand.textPrimary)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(.ultraThinMaterial))
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.28), lineWidth: 0.6))
            }
            .buttonStyle(.plain)
            .help(helpText)
            .accessibilityLabel(helpText)
        }
    }
}

/// Groups neighbouring glass shapes so they share one specular field.
struct GlassGroup<Content: View>: View {
    var spacing: CGFloat = 8
    @ViewBuilder var content: () -> Content

    var body: some View {
        if #available(macOS 26, *) {
            GlassEffectContainer(spacing: spacing) { content() }
        } else {
            content()
        }
    }
}

/// Quiet segmented control: a gray track with a raised selection, not an
/// inverted black pill. `badge` is an optional count drawn after the title.
struct SegmentedPills<Item: Hashable>: View {
    let items: [Item]
    let selection: Item
    var size: CGFloat = 13
    var title: (Item) -> String
    var badge: ((Item) -> String?)? = nil
    /// Spoken name when it should differ from `title` (for example, a count).
    var spokenLabel: ((Item) -> String)? = nil
    let onSelect: (Item) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(items, id: \.self) { item in
                let on = item == selection
                Button {
                    withAnimation(.easeOut(duration: 0.14)) { onSelect(item) }
                } label: {
                    HStack(spacing: 6) {
                        Text(title(item))
                            .font(Brand.sans(size, on ? .semibold : .regular))
                        if let badge, let value = badge(item) {
                            Text(verbatim: value)
                                .font(Brand.sans(size - 1, .medium))
                                .foregroundStyle(on ? Brand.textSecondary : Brand.textTertiary)
                        }
                    }
                    .foregroundStyle(on ? Brand.textPrimary : Brand.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background {
                        if on {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Brand.segmentSelected)
                                .shadow(color: .black.opacity(0.04), radius: 1, y: 1)
                        }
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(spokenLabel?(item) ?? title(item))
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: Brand.radiusControl, style: .continuous)
                .fill(Brand.segmentTrack)
        )
    }
}

/// Rounded search field. Same metrics everywhere it appears.
struct QuietSearchField: View {
    var placeholder: LocalizedStringKey
    @Binding var text: String
    var width: CGFloat = 168

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: Brand.scaled(12), weight: .regular))
                .foregroundStyle(Brand.textTertiary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(Brand.sans(13))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(width: width)
        .background(
            RoundedRectangle(cornerRadius: Brand.radiusControl, style: .continuous)
                .fill(Brand.insetFill)
        )
    }
}

/// The page header strip: generous inset, then a hairline instead of a box.
struct PaneHeader<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
                .padding(.horizontal, Brand.pageInset)
                .padding(.top, 16)
                .padding(.bottom, 12)
            Rectangle().fill(Brand.hairline).frame(height: 1)
        }
    }
}
