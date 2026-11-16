//
//  LiquidGlass.swift
//  Burrow / Components
//
//  macOS 26 Regular Liquid Glass for navigation and menu surfaces, plus the
//  legibility helpers the Axiom liquid-glass skill calls for: adaptive
//  dimming under large panels, denser card fills, and Reduce Transparency /
//  Increase Contrast fallbacks. Older systems keep the view's existing
//  material unchanged.
//

import AppKit
import SwiftUI

extension View {
    /// Regular Liquid Glass (lensing, adaptive tint). No-op before macOS 26.
    @ViewBuilder
    func regularGlass<S: Shape>(in shape: S) -> some View {
        if #available(macOS 26, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self
        }
    }

    /// Separates a scroll view from a bar pinned above it. No-op before macOS 26.
    @ViewBuilder
    func scrollEdgeGlass() -> some View {
        if #available(macOS 26, *) {
            self.scrollEdgeEffectStyle(.hard, for: .top)
        } else {
            self
        }
    }

    /// Regular glass over an adaptive content scrim so wallpaper does not
    /// punch through a large panel (menu HUD, rail). Clear is never used.
    /// No-op before macOS 26 — callers keep their pre-26 fill/veil.
    @ViewBuilder
    func liquidGlassPanel<S: InsettableShape>(in shape: S) -> some View {
        if #available(macOS 26, *) {
            self
                .background { shape.fill(LiquidGlassMaterials.panelScrim) }
                .overlay {
                    if LiquidGlassMaterials.increaseContrast {
                        shape.strokeBorder(Brand.hairline.opacity(0.9), lineWidth: 1.5)
                    }
                }
                .glassEffect(.regular, in: shape)
        } else {
            self
        }
    }
}

/// Shared fills and accessibility gates for glass surfaces.
enum LiquidGlassMaterials {
    /// System Reduce Transparency — frost/opaque instead of see-through glass.
    static var reduceTransparency: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
    }

    /// System Increase Contrast — denser fills + stronger borders.
    static var increaseContrast: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
    }

    /// Adaptive dimming under a large Regular-glass panel. Stabilizes the
    /// backdrop so semantic `.primary` / `.secondary` text can clear WCAG AA
    /// over both bright and dark wallpapers. Tuned so busy stripes no longer
    /// read through titles / footnotes (owner feedback on macOS 27.2.1).
    static var panelScrim: Color {
        if reduceTransparency || increaseContrast {
            return Color.adaptive(0x17120A, 0xF4EFE6, darkA: 0.98, lightA: 0.99)
        }
        // Near-opaque veil: Regular glass still lenses at the edges, but the
        // content plane stays stable over bright/striped desktops.
        return Color.adaptive(0x17120A, 0xF4EFE6, darkA: 0.90, lightA: 0.94)
    }

    /// Card / tile fill sitting on glass. Dark mode uses an elevated warm
    /// board (not a cream wash) so `.primary` / `.secondary` clear WCAG AA.
    static var cardFill: Color {
        if reduceTransparency || increaseContrast {
            return Color.adaptive(0x2A2114, 0xFFFFFF, darkA: 0.98, lightA: 1.0)
        }
        return Color.adaptive(0x2F281F, 0xFFFFFF, darkA: 0.96, lightA: 0.98)
    }

    /// Compact chip / tool-pill fill (icons need ≥ 3:1).
    static var chipFill: Color {
        if reduceTransparency || increaseContrast {
            return Color.adaptive(0xF2ECE0, 0x2A2114, darkA: 0.28, lightA: 0.18)
        }
        return Color.adaptive(0xF2ECE0, 0x2A2114, darkA: 0.20, lightA: 0.14)
    }
}
