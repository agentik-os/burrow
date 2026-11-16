//
//  DesignSystem.swift
//  Burrow
//
//  Shared controls. Screens compose these instead of restyling a capsule
//  or a search field locally, so padding, radius, and type stay in one place.
//

import SwiftUI

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
