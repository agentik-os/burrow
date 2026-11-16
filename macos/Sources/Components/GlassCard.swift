//
//  GlassCard.swift
//  Burrow / Components
//
//  The translucent card + the two small atoms that sit inside it
//  everywhere: the uppercase eyebrow (small glyph + label) and the
//  pill chip. Kept tiny and dependency-free so the dashboard reads as
//  a flat list of `GlassCard { ... }` blocks.
//

import SwiftUI

struct GlassCard<Content: View>: View {
    var padding: CGFloat = Brand.cardPadding
    var corner: CGFloat = Brand.radiusCard
    var minHeight: CGFloat? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
            .glassTile(corner: corner)
    }
}

/// Section label with a leading glyph. Sentence case, same size everywhere.
struct Eyebrow: View {
    let text: String
    let glyph: String
    var color: Color = Brand.textSecondary

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: glyph)
                .font(.system(size: Brand.scaled(12), weight: .regular))
            Text(NSLocalizedString(text, comment: ""))
                .font(Brand.sans(13, .medium))
        }
        .foregroundStyle(color)
    }
}

/// Small rounded pill used for inline status ("normal", "HTTP", "Good").
struct Chip: View {
    let text: String
    var color: Color = Brand.textSecondary

    var body: some View {
        Text(NSLocalizedString(text, comment: ""))
            .font(Brand.sans(11, .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(color.opacity(0.12))
            )
    }
}
