//
//  Brand.swift
//  Burrow
//
//  Visual language for the macOS app: a quiet, native surface in the
//  spirit of the ChatGPT desktop app. Near-white in light mode, near-black
//  in dark mode, one restrained accent, and system type. Tool screens share
//  these tokens instead of inventing their own chrome.
//
//  Semantic status colours (success / warning / danger) stay distinct so a
//  health reading is still readable, but they are desaturated — colour is
//  information, not decoration.
//

import AppKit
import SwiftUI

/// The live interface text scale (issue #407). One process-wide object so
/// the `Brand` font factories — plain static funcs with no environment —
/// can read the factor cheaply on every body evaluation, and so the window
/// roots (`RootView`) can observe it and re-render when Settings changes
/// it. Not the menu-bar status item: that renders through `MenuBarRenderer`
/// with its own per-widget `MenuBarTextSize`.
final class TypeScale: ObservableObject {
    static let shared = TypeScale()

    @Published private(set) var value: InterfaceScale
    /// Cached so `Brand.scaled` is a field read, not an enum switch plus a
    /// defaults lookup, on each of the hundreds of font calls per render.
    private(set) var factor: CGFloat

    private init() {
        let v = Store.interfaceScale
        value = v
        factor = v.factor
    }

    func set(_ newValue: InterfaceScale) {
        Store.interfaceScale = newValue
        factor = newValue.factor
        value = newValue
    }
}

extension Color {
    /// 0xRRGGBB literal → sRGB Color.
    init(hex: UInt, alpha: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }

    /// Appearance-adaptive sRGB colour: `dark` hex in dark mode, `light` hex
    /// in light mode, each with its own opacity. Backed by a dynamic NSColor
    /// so it re-resolves when the system (or window) appearance flips.
    static func adaptive(_ dark: UInt, _ light: UInt,
                         darkA: Double = 1, lightA: Double = 1) -> Color {
        Color(nsColor: NSColor(name: nil) { ap in
            let isDark = ap.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let hex = isDark ? dark : light
            let a = isDark ? darkA : lightA
            return NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                           green: CGFloat((hex >> 8) & 0xFF) / 255,
                           blue: CGFloat(hex & 0xFF) / 255,
                           alpha: a)
        })
    }
}

enum Brand {
    // MARK: Ground — near-black (dark) / near-white (light)
    /// Main reading surface.
    static let canvas     = Color.adaptive(0x212121, 0xFFFFFF)
    /// Sidebar wash laid over the sidebar material.
    static let sidebar    = Color.adaptive(0x171717, 0xF7F7F8, darkA: 0.55, lightA: 0.72)
    static let base       = canvas
    static let baseSoft   = Color.adaptive(0x2A2A2A, 0xFFFFFF)
    static let nearBlack  = Color.adaptive(0x171717, 0xF4F4F5)

    // MARK: Text
    static let ink           = Color.adaptive(0xECECEC, 0x0D0D0D)
    static let textPrimary   = Color.adaptive(0xECECEC, 0x0D0D0D)
    static let textSecondary = Color.adaptive(0xECECEC, 0x0D0D0D, darkA: 0.64, lightA: 0.62)
    static let textTertiary  = Color.adaptive(0xECECEC, 0x0D0D0D, darkA: 0.40, lightA: 0.46)

    // MARK: Surfaces
    static let hairline      = Color.adaptive(0xFFFFFF, 0x000000, darkA: 0.10, lightA: 0.08)
    static let cardFill      = Color.adaptive(0x2B2B2B, 0xF7F7F8)
    static let cardFillHover = Color.adaptive(0x333333, 0xEFEFF1)
    static let chipFill      = Color.adaptive(0xFFFFFF, 0x000000, darkA: 0.06, lightA: 0.05)
    static let trackFill     = Color.adaptive(0xFFFFFF, 0x000000, darkA: 0.10, lightA: 0.06)
    /// Recessed field — search boxes, code blocks, segmented tracks.
    static let insetFill     = Color.adaptive(0x000000, 0x000000, darkA: 0.28, lightA: 0.04)
    static let sidebarSelection = Color.adaptive(0xFFFFFF, 0x000000, darkA: 0.08, lightA: 0.06)
    static let sidebarHover     = Color.adaptive(0xFFFFFF, 0x000000, darkA: 0.05, lightA: 0.04)
    static let segmentTrack     = Color.adaptive(0xFFFFFF, 0x000000, darkA: 0.08, lightA: 0.05)
    static let segmentSelected  = Color.adaptive(0x3A3A3A, 0xFFFFFF)

    // MARK: Inverse — the high-contrast control (light on dark, ink on paper)
    static let inverse   = Color.adaptive(0xECECEC, 0x0D0D0D)
    static let onInverse = Color.adaptive(0x171717, 0xFFFFFF)

    // MARK: Accent — one restrained green, used sparingly
    static let accent   = Color(hex: 0x1F8F6B)
    static let onAccent = Color(hex: 0xFFFFFF)

    // MARK: Status — muted, still distinguishable
    static let green  = accent
    static let gold   = Color(hex: 0xB8923A)
    static let amber  = Color(hex: 0xC4923A)
    static let orange = Color(hex: 0xC4845A)
    static let blue   = Color(hex: 0x6A8FBF)
    static let red    = Color(hex: 0xD15B54)
    static let teal   = Color(hex: 0x3E8F86)
    static let violet = Color(hex: 0x8A86B8)
    static let moss   = Color(hex: 0x7A9474)
    static let ginger = Color(hex: 0xC4926E)
    static let lilac  = Color(hex: 0x8A86B8)
    static let apricot = Color(hex: 0xC4926E)
    static let mint   = accent

    // Kept so older call sites compile; the mark itself is monochrome now.
    static let cream    = textPrimary
    static let espresso = canvas

    // MARK: Space and shape — one scale, used everywhere
    static let pageInset: CGFloat = 24
    static let cardPadding: CGFloat = 16
    static let radiusControl: CGFloat = 10
    static let radiusRow: CGFloat = 8
    static let radiusCard: CGFloat = 14
    static let rSmall: CGFloat = 8
    static let rCard: CGFloat = 14
    static let rLarge: CGFloat = 18

    /// Flat canvas. Older call sites used this as a tinted veil; it is a
    /// solid ground now so panes don't wash the window in a gradient.
    static var windowVeil: Color { canvas }

    /// Retired. Present so a stray call site paints nothing.
    static var ambientGlow: Color { .clear }

    // MARK: Type — San Francisco, the system face
    //
    // Sizes are written at the historical 1.0-scale values; the user's
    // interface text scale (issue #407) multiplies through `scaled(_:)`
    // at resolve time.
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: scaled(size), weight: weight, design: .monospaced)
    }
    static func sans(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: scaled(size), weight: weight)
    }
    static func display(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: scaled(size), weight: weight)
    }
    static func serif(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: scaled(size), weight: weight)
    }

    /// A point size at the user's interface text scale. The brand factories
    /// above apply it themselves; glyph sizes (`.system(size:)` on SF
    /// Symbols) and the popover width opt in at the call site so icons keep
    /// pace with the text they sit beside.
    static func scaled(_ size: CGFloat) -> CGFloat {
        size * TypeScale.shared.factor
    }
}
