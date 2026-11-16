//
//  SidebarNav.swift
//  Burrow
//
//  The window's navigation: a quiet, full-height sidebar. Monochrome
//  SF Symbols, labels always visible, a soft selection fill. The tool
//  list scrolls; Settings stays pinned. Same `Pane` model as the rest
//  of the window — this only changes how a pane is chosen.
//

import SwiftUI

struct SidebarNav: View {
    @Binding var selected: Pane

    var body: some View {
        VStack(spacing: 0) {
            wordmark
                .frame(height: SidebarMetrics.headerHeight)

            Color.clear.frame(height: SidebarMetrics.headerGap)

            SidebarRow(
                label: NSLocalizedString("Monitor", comment: ""),
                glyph: "gauge",
                isOn: selected == .home,
                action: { select(.home) })

            Color.clear.frame(height: SidebarMetrics.sectionGap)

            Text(NSLocalizedString("Tools", comment: "sidebar section"))
                .font(Brand.sans(11, .medium))
                .foregroundStyle(Brand.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .frame(height: SidebarMetrics.sectionLabelHeight)

            Color.clear.frame(height: SidebarMetrics.listTopGap)

            ScrollView {
                VStack(spacing: SidebarMetrics.rowSpacing) {
                    ForEach(Tool.navOrder) { tool in
                        SidebarRow(
                            label: tool.title,
                            glyph: tool.glyph,
                            isOn: selected == .tool(tool),
                            action: { select(.tool(tool)) })
                    }
                }
            }
            .scrollIndicators(.hidden)

            Color.clear.frame(height: SidebarMetrics.dividerSpacing)
            Rectangle()
                .fill(Brand.hairline)
                .frame(height: SidebarMetrics.dividerThickness)
                .padding(.horizontal, 8)
            Color.clear.frame(height: SidebarMetrics.dividerSpacing)

            SidebarRow(
                label: NSLocalizedString("Settings", comment: ""),
                glyph: "gearshape",
                isOn: selected == .settings,
                action: { select(.settings) })
                .frame(height: SidebarMetrics.rowHeight)
        }
        .padding(.horizontal, SidebarMetrics.horizontalPadding)
        .padding(.top, SidebarMetrics.topPadding)
        .padding(.bottom, SidebarMetrics.bottomPadding)
        .frame(width: SidebarMetrics.width)
        .frame(maxHeight: .infinity, alignment: .top)
        .background {
            VisualEffectBackground(material: .sidebar, blending: .behindWindow)
            Brand.sidebar
        }
    }

    private var wordmark: some View {
        Button { select(.home) } label: {
            HStack(spacing: 10) {
                BurrowMark()
                    .frame(width: 22, height: 22)
                Text("Burrow")
                    .font(Brand.sans(15, .semibold))
                    .foregroundStyle(Brand.textPrimary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(NSLocalizedString("Burrow, Monitor", comment: "sidebar wordmark"))
    }

    private func select(_ pane: Pane) {
        withAnimation(.easeOut(duration: 0.16)) { selected = pane }
    }
}

/// One sidebar destination. Selection is a quiet fill, not a coloured tile.
private struct SidebarRow: View {
    let label: String
    let glyph: String
    let isOn: Bool
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: glyph)
                    .font(.system(size: Brand.scaled(SidebarMetrics.iconColumn - 3), weight: .regular))
                    .frame(width: SidebarMetrics.iconColumn, height: SidebarMetrics.iconColumn)
                Text(label)
                    .font(Brand.sans(13, isOn ? .medium : .regular))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .foregroundStyle(isOn ? Brand.textPrimary : Brand.textSecondary)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: SidebarMetrics.rowHeight, maxHeight: SidebarMetrics.rowHeight, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: Brand.radiusRow, style: .continuous)
                    .fill(fill)
            }
            .contentShape(RoundedRectangle(cornerRadius: Brand.radiusRow, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
        .animation(.easeOut(duration: 0.16), value: isOn)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private var fill: Color {
        if isOn { return Brand.sidebarSelection }
        if hovering { return Brand.sidebarHover }
        return .clear
    }
}
