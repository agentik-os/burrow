//
//  LiquidGlass.swift
//  Burrow / Components
//
//  macOS 26 Regular Liquid Glass for navigation and menu surfaces.
//  Older systems keep the view's existing material unchanged.
//

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
}
