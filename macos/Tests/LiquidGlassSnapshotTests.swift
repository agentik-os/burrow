//
//  LiquidGlassSnapshotTests.swift
//  BurrowTests
//
//  Renders the navigation rail and HUD contrast previews when
//  BURROW_SNAPSHOT_DIR is set, or when Tests/.write-ui-snapshots exists.
//  Skips otherwise.
//

import AppKit
import SwiftUI
import XCTest
@testable import Burrow

final class LiquidGlassSnapshotTests: XCTestCase {
    func testWriteRailSnapshotsWhenRequested() throws {
        let dir = try snapshotDirectory()
        let size = CGSize(width: 520, height: 720)
        try write(RailParity(), name: "rail-parity-light", scheme: .light, dir: dir, size: size)
        try write(RailParity(), name: "rail-parity-dark", scheme: .dark, dir: dir, size: size)
    }

    func testWritePopoverContrastSnapshotsWhenRequested() throws {
        let dir = try snapshotDirectory()
        // Tall enough for the full default HUD (all popupGrid tiles + battery
        // rings + 4 processes + all tool pills + Clean Watch + MCP footer).
        let size = CGSize(width: 760, height: 1480)
        try write(PopoverOnWallpaper(wallpaper: .brightStriped),
                  name: "popover-contrast-bright-wallpaper", scheme: .light, dir: dir, size: size)
        try write(PopoverOnWallpaper(wallpaper: .darkBusy),
                  name: "popover-contrast-dark-wallpaper", scheme: .dark, dir: dir, size: size)
        try write(PopoverOnWallpaper(wallpaper: .brightStriped),
                  name: "popover-contrast-bright-wallpaper-dark-ui", scheme: .dark, dir: dir, size: size)
        try write(PopoverOnWallpaper(wallpaper: .darkBusy),
                  name: "popover-contrast-dark-wallpaper-light-ui", scheme: .light, dir: dir, size: size)
    }

    private func snapshotDirectory() throws -> URL {
        let testsDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let sentinel = testsDir.appendingPathComponent(".write-ui-snapshots")
        let envDir = ProcessInfo.processInfo.environment["BURROW_SNAPSHOT_DIR"]
        let requested = FileManager.default.fileExists(atPath: sentinel.path) || (envDir?.isEmpty == false)
        guard requested else { throw XCTSkip("UI snapshots were not requested") }
        let dir = envDir.flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: $0, isDirectory: true) }
            ?? testsDir.appendingPathComponent("ui-snapshots")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func write<V: View>(_ view: V, name: String, scheme: ColorScheme, dir: URL, size: CGSize) throws {
        let appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
        let host = NSHostingView(rootView: view.frame(width: size.width, height: size.height).environment(\.colorScheme, scheme))
        host.appearance = appearance
        host.frame = NSRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = appearance
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
            XCTFail("no bitmap for \(name)")
            return
        }
        host.cacheDisplay(in: host.bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else {
            XCTFail("no png for \(name)")
            return
        }
        try png.write(to: dir.appendingPathComponent("\(name).png"))
    }
}

/// Left: the upstream rail fill. Right: FloatingRail, which uses that fill
/// before macOS 26 and Regular Liquid Glass + scrim on macOS 26.
private struct RailParity: View {
    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(spacing: 8) {
                Text("Upstream material").font(Brand.sans(12, .semibold)).foregroundStyle(.primary)
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Brand.cardFill)
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Brand.hairline, lineWidth: 1))
                    .frame(width: RailMetrics.width, height: 640)
            }
            VStack(spacing: 8) {
                Text("This build").font(Brand.sans(12, .semibold)).foregroundStyle(.primary)
                FloatingRail(selected: .constant(.home))
                    .frame(height: 640)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Brand.base)
    }
}

private enum SnapshotWallpaper {
    case brightStriped, darkBusy
}

/// Full default HUD chrome over a busy wallpaper — field parity with
/// `PopupView` defaults (`MenuBarMetric.popupGrid` + battery + 4 processes +
/// utility + Clean Watch + every tool pill + MCP). Contrast-only materials;
/// no live MoleStatus required.
private struct PopoverOnWallpaper: View {
    let wallpaper: SnapshotWallpaper
    private let spark = [0.2, 0.35, 0.28, 0.55, 0.4, 0.62, 0.48, 0.7]

    var body: some View {
        ZStack {
            wallpaperView
            ScrollView {
                hud
                    .padding(.horizontal, 48)
                    .padding(.vertical, 36)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder private var wallpaperView: some View {
        switch wallpaper {
        case .brightStriped:
            BrightStripedWallpaper()
        case .darkBusy:
            DarkBusyWallpaper()
        }
    }

    private var hud: some View {
        VStack(alignment: .leading, spacing: 9) {
            // Header — health + headline + free space
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 13)).foregroundStyle(Brand.green)
                Text("92").font(Brand.mono(16, .semibold)).foregroundStyle(.primary)
                Text("All systems nominal").font(Brand.sans(11)).foregroundStyle(.secondary)
                Spacer(minLength: 6)
                Text("128 GB free").font(Brand.mono(10)).foregroundStyle(.tertiary)
                Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }

            // Chips — chip · RAM · macOS · uptime
            HStack(spacing: 5) {
                Chip(text: "M3 Pro", color: Brand.textSecondary)
                Chip(text: "36 GB", color: Brand.textSecondary)
                Chip(text: "macOS 27.2.1", color: Brand.textSecondary)
                Chip(text: "up 2d 4h", color: Brand.textSecondary)
                Spacer()
            }

            // Metric grid — exact default popupGrid order
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                sampleTile(eyebrow: "CPU", glyph: "cpu", accent: Brand.green, value: "24", unit: "%",
                           chip: ("48°C", Brand.orange), footnote: "load 1.42", chart: .bars)
                sampleTile(eyebrow: "GPU", glyph: "cpu.fill", accent: Brand.orange, value: "31", unit: "%",
                           chip: ("52°C", Brand.orange), footnote: "M3 Pro", chart: .bars)
                sampleTile(eyebrow: "Memory", glyph: "memorychip", accent: Brand.amber, value: "61", unit: "%",
                           chip: ("61%", Brand.amber), footnote: "22.0/36 GB · swap 0.4 GB", chart: .area)
                diskTile
                sampleTile(eyebrow: "Network", glyph: "network", accent: Brand.green, value: "8.4", unit: "MB/s",
                           chip: ("en0", Brand.blue), footnote: "↓ 4200 ↑ 180 KB/s", chart: .area)
                sampleTile(eyebrow: "Fan", glyph: "fan", accent: PowerAccent.fan, value: "1200", unit: "RPM",
                           chip: ("2 fans", Brand.textSecondary), footnote: "macOS manages speed", chart: .area)
            }

            // Battery — rings + top drain (matches PopupView.batteryCard)
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Eyebrow(text: "Battery", glyph: "battery.100", color: Brand.green)
                    Spacer()
                    Chip(text: "100% Health", color: Brand.green)
                }
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text("78%").font(Brand.mono(16, .semibold)).foregroundStyle(.primary)
                            Text("4:12 left").font(Brand.mono(10)).foregroundStyle(.secondary)
                        }
                        Text("342 cyc · 31°C").font(Brand.mono(9)).foregroundStyle(.tertiary)
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        RingGauge(percent: 78, color: Brand.green, glyph: "laptopcomputer",
                                  label: "Mac", size: 34)
                        RingGauge(percent: 64, color: Brand.green, glyph: "headphones",
                                  label: "AirPods", size: 34)
                        RingGauge(percent: 42, color: Brand.amber, glyph: "magicmouse.fill",
                                  label: "Mouse", size: 34)
                    }
                }
                HStack(spacing: 5) {
                    Image(systemName: "bolt.fill").font(.system(size: 9)).foregroundStyle(Brand.gold)
                    Text("Top drain — Cursor · avg 18% CPU over the last hour")
                        .font(Brand.mono(9)).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(LiquidGlassMaterials.cardFill))
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)

            // Top processes — 4 rows + ellipsis affordance
            VStack(alignment: .leading, spacing: 5) {
                Eyebrow(text: "Top processes", glyph: "list.bullet", color: Brand.textSecondary)
                processRow("Cursor", cpu: 18.2, mem: "1.4 GB")
                processRow("WindowServer", cpu: 9.1, mem: "420 MB")
                processRow("Safari", cpu: 4.6, mem: "890 MB")
                processRow("node", cpu: 3.1, mem: "310 MB")
            }

            // Utility strip
            HStack(spacing: 6) {
                utility("cup.and.saucer.fill", "Stay Awake")
                utility("rectangle.inset.filled", "Wipe")
                utility("eject.fill", "Eject")
                Spacer()
            }

            Rectangle().fill(Brand.hairline).frame(height: 1)

            // Footer — Clean Watch + every tool + Open Burrow + MCP
            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    Eyebrow(text: "Clean Watch", glyph: "sparkles", color: Tool.clean.accent)
                    Spacer()
                    Text("12.4 GB cleaned · 3 uninstalled · 8 optimized")
                        .font(Brand.mono(9)).foregroundStyle(.secondary)
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 5), spacing: 6) {
                    ForEach(Tool.navOrder) { tool in
                        Image(systemName: tool.glyph)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(tool.accent)
                            .frame(maxWidth: .infinity, minHeight: 26)
                            .background(Capsule().fill(LiquidGlassMaterials.chipFill))
                            .overlay(Capsule().strokeBorder(tool.accent.opacity(0.45), lineWidth: 0.75))
                    }
                }
                HStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath").font(.system(size: 12)).foregroundStyle(.secondary)
                    Image(systemName: "gearshape").font(.system(size: 12)).foregroundStyle(.secondary)
                    Spacer()
                    Text("Open Burrow").font(Brand.sans(11, .semibold)).foregroundStyle(.primary)
                    Image(systemName: "power").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Text(verbatim: "MCP · stdio (burrow --mcp)")
                    .font(Brand.mono(9)).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(13)
        .frame(width: 334)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LiquidGlassMaterials.panelScrim)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Brand.hairline.opacity(0.55), lineWidth: 1)
        }
        .liquidGlassPanel(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.28), radius: 24, y: 10)
    }

    private var diskTile: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Eyebrow(text: "Disk", glyph: "internaldrive", color: Brand.blue)
                Spacer(minLength: 2)
                Chip(text: "1 TB", color: Brand.textSecondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("128 GB").font(Brand.mono(15, .semibold)).foregroundStyle(.primary)
                Text("free").font(Brand.mono(9)).foregroundStyle(.secondary)
            }
            LowSpaceBar(fraction: 0.72).frame(height: 4)
            Text("872 GB used · 72%").font(Brand.mono(8.5)).foregroundStyle(.tertiary).lineLimit(1)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(LiquidGlassMaterials.cardFill))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
    }

    private func sampleTile(eyebrow: String, glyph: String, accent: Color,
                            value: String, unit: String,
                            chip: (String, Color), footnote: String,
                            chart: MiniChart.Style) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Eyebrow(text: eyebrow, glyph: glyph, color: accent)
                Spacer(minLength: 2)
                Chip(text: chip.0, color: chip.1)
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).font(Brand.mono(15, .semibold)).foregroundStyle(.primary)
                Text(unit).font(Brand.mono(9)).foregroundStyle(.secondary)
            }
            MiniChart(values: spark, color: accent, style: chart)
                .frame(height: 13)
            Text(footnote).font(Brand.mono(8.5)).foregroundStyle(.tertiary).lineLimit(1)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(LiquidGlassMaterials.cardFill))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
    }

    private func processRow(_ name: String, cpu: Double, mem: String) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 3)
                .fill(LiquidGlassMaterials.chipFill)
                .frame(width: 15, height: 15)
                .overlay(
                    Image(systemName: "app.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                )
            Text(name).font(Brand.sans(11)).foregroundStyle(.primary).lineLimit(1)
            Spacer(minLength: 6)
            Text(String(format: "%.1f%%", cpu)).font(Brand.mono(10)).foregroundStyle(.secondary)
            Text(mem).font(Brand.mono(10)).foregroundStyle(.tertiary)
                .frame(width: 52, alignment: .trailing)
            Image(systemName: "ellipsis").font(.system(size: 10)).foregroundStyle(.secondary)
                .frame(width: 16, height: 16)
        }
    }

    private func utility(_ glyph: String, _ label: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: glyph).font(.system(size: 10, weight: .medium))
            Text(label).font(Brand.mono(10, .medium))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 9).padding(.vertical, 5)
        .background(Capsule().fill(LiquidGlassMaterials.chipFill))
        .overlay(Capsule().strokeBorder(Brand.hairline, lineWidth: 0.75))
    }
}

private struct BrightStripedWallpaper: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [
                Color(hex: 0xF7F1E3), Color(hex: 0xE8F0FF), Color(hex: 0xFFE8D6), Color(hex: 0xE6F7EA)
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
            GeometryReader { geo in
                Path { path in
                    let step: CGFloat = 28
                    var x: CGFloat = -geo.size.height
                    while x < geo.size.width + geo.size.height {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x + geo.size.height, y: geo.size.height))
                        x += step
                    }
                }
                .stroke(Color(hex: 0x2A2114).opacity(0.18), lineWidth: 10)
            }
            Circle().fill(Color(hex: 0x5B8DEF).opacity(0.35)).frame(width: 280, height: 280)
                .offset(x: 210, y: -260)
            Circle().fill(Color(hex: 0xF0714E).opacity(0.28)).frame(width: 220, height: 220)
                .offset(x: -240, y: 280)
        }
        .clipped()
    }
}

private struct DarkBusyWallpaper: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [
                Color(hex: 0x0B1020), Color(hex: 0x1A1430), Color(hex: 0x102018)
            ], startPoint: .top, endPoint: .bottom)
            GeometryReader { geo in
                Path { path in
                    let step: CGFloat = 34
                    var x: CGFloat = -geo.size.height
                    while x < geo.size.width + geo.size.height {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x + geo.size.height, y: geo.size.height))
                        x += step
                    }
                }
                .stroke(Color.white.opacity(0.10), lineWidth: 12)
            }
            Circle().fill(Color(hex: 0x8E84F0).opacity(0.45)).frame(width: 320, height: 320)
                .blur(radius: 8)
                .offset(x: 200, y: -220)
            Circle().fill(Color(hex: 0x16A37F).opacity(0.35)).frame(width: 260, height: 260)
                .blur(radius: 6)
                .offset(x: -220, y: 260)
        }
        .clipped()
    }
}
