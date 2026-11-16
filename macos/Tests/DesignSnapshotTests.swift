//
//  DesignSnapshotTests.swift
//  BurrowTests
//
//  Offscreen renders of the redesigned shell. The macOS app workflow
//  drops a sentinel next to this file before running the test, because
//  xcodebuild does not forward shell environment variables into XCTest.
//  Without the sentinel the test skips, so the normal suite stays hermetic.
//

import AppKit
import Charts
import SwiftUI
import XCTest
@testable import Burrow

final class DesignSnapshotTests: XCTestCase {
    private var previousDefaults: UserDefaults?
    private var suiteName: String?

    override func setUp() {
        super.setUp()
        previousDefaults = Store.d
        let name = "burrow-snapshots-\(UUID().uuidString)"
        suiteName = name
        Store.d = UserDefaults(suiteName: name)!
    }

    override func tearDown() {
        if let suiteName {
            Store.d.removePersistentDomain(forName: suiteName)
        }
        if let previousDefaults {
            Store.d = previousDefaults
        }
        super.tearDown()
    }

    func testWriteSnapshotsWhenRequested() throws {
        let testsDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let sentinel = testsDir.appendingPathComponent(".write-ui-snapshots")
        let envDir = ProcessInfo.processInfo.environment["BURROW_SNAPSHOT_DIR"]
        let requested = FileManager.default.fileExists(atPath: sentinel.path)
            || (envDir?.isEmpty == false)
        guard requested else {
            throw XCTSkip("UI snapshots were not requested")
        }
        let dir = envDir.flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: $0, isDirectory: true) }
            ?? testsDir.appendingPathComponent("ui-snapshots")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let monitor = CGSize(width: 1100, height: 760)
        try write(MonitorChartsPreview(), name: "after-monitor-light", scheme: .light, dir: dir, size: monitor)
        try write(MonitorChartsPreview(), name: "after-monitor-dark", scheme: .dark, dir: dir, size: monitor)
        let pop = CGSize(width: 760, height: 980)
        try write(PopoverParity(), name: "parity-popover-light", scheme: .light, dir: dir, size: pop)
        try write(PopoverParity(), name: "parity-popover-dark", scheme: .dark, dir: dir, size: pop)
        let history = CGSize(width: 880, height: 420)
        try write(HistoryChartPreview(), name: "after-history-light", scheme: .light, dir: dir, size: history)
        try write(HistoryChartPreview(), name: "after-history-dark", scheme: .dark, dir: dir, size: history)
        try write(BeforeChartsPreview(), name: "before-charts-dark", scheme: .dark, dir: dir, size: CGSize(width: 380, height: 280))
    }

    private func write<V: View>(_ view: V, name: String, scheme: ColorScheme, dir: URL, size: CGSize) throws {
        let appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
        let host = NSHostingView(rootView:
            view.frame(width: size.width, height: size.height)
                .environment(\.colorScheme, scheme)
        )
        host.appearance = appearance
        host.frame = NSRect(origin: .zero, size: size)

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false)
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

/// Sidebar plus the shared cards, segmented control, and access banner.
private struct ShellPreview: View {
    var pane: Pane

    var body: some View {
        HStack(spacing: 0) {
            SidebarNav(selected: .constant(pane))
            Rectangle().fill(Brand.hairline).frame(width: 1)
            VStack(alignment: .leading, spacing: 16) {
                PaneHeader {
                    HStack {
                        SegmentedPills(
                            items: ["Overview", "History", "Activity"],
                            selection: "Overview",
                            title: { $0 },
                            onSelect: { _ in })
                        Spacer()
                        PillButton(title: "Explain", filled: false) {}
                    }
                }
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Eyebrow(text: "Storage", glyph: "internaldrive")
                        Text("128 GB free")
                            .font(Brand.sans(22, .semibold))
                            .foregroundStyle(Brand.textPrimary)
                        Text("Your Mac has room to breathe.")
                            .font(Brand.sans(13))
                            .foregroundStyle(Brand.textSecondary)
                    }
                }
                .padding(.horizontal, Brand.pageInset)
                HStack(spacing: 12) {
                    metric("CPU", "cpu", "12%")
                    metric("Memory", "memorychip", "8.1 GB")
                }
                .padding(.horizontal, Brand.pageInset)
                Spacer()
                AccessBanner(
                    title: "Full Disk Access is off",
                    detail: "Without it, Burrow can't reach most system caches.",
                    onDismiss: {})
                    .padding(.horizontal, Brand.pageInset)
                    .padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Brand.canvas)
        }
        .background(Brand.canvas)
    }

    private func metric(_ title: String, _ glyph: String, _ value: String) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 6) {
                Eyebrow(text: title, glyph: glyph)
                Text(value)
                    .font(Brand.mono(20, .semibold))
                    .foregroundStyle(Brand.textPrimary)
            }
        }
    }
}

/// The real Clean chooser inside the new shell.
private struct CleanPreview: View {
    var body: some View {
        HStack(spacing: 0) {
            SidebarNav(selected: .constant(.tool(.clean)))
            Rectangle().fill(Brand.hairline).frame(width: 1)
            CleanHub()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Brand.canvas)
        }
        .background(Brand.canvas)
    }
}

private enum ChartFixture {
    static func wave(count: Int = 48, base: Double, amp: Double, phase: Double = 0) -> [Double] {
        (0..<count).map { i in
            let t = Double(i) / Double(count - 1)
            return max(0, base + amp * sin(t * .pi * 2 + phase) + amp * 0.25 * sin(t * .pi * 6))
        }
    }
    static let cpu = wave(base: 22, amp: 14, phase: 0.4)
    static let gpu = wave(base: 18, amp: 22, phase: 1.2)
    static let mem = wave(base: 62, amp: 6, phase: 0.2)
    static let net = wave(base: 8, amp: 7, phase: 2.1)
}

/// Monitor metric cards and a history chart, the way the window draws them now.
private struct MonitorChartsPreview: View {
    var body: some View {
        HStack(spacing: 0) {
            SidebarNav(selected: .constant(.home))
            Rectangle().fill(Brand.hairline).frame(width: 1)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        tile("CPU", "cpu", "28.4", "%", ChartFixture.cpu)
                        tile("Memory", "memorychip", "64", "%", ChartFixture.mem)
                        tile("GPU", "cpu.fill", "41", "%", ChartFixture.gpu)
                    }
                    HStack(spacing: 12) {
                        tile("Network", "network", "12.4", "MB/s", ChartFixture.net)
                        GlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Eyebrow(text: "Disk", glyph: "internaldrive")
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Text("412").font(Brand.mono(28, .semibold)).foregroundStyle(Brand.textPrimary)
                                    Text("GB free").font(Brand.sans(13)).foregroundStyle(Brand.textSecondary)
                                }
                                LowSpaceBar(fraction: 0.68)
                            }
                        }
                        GlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Eyebrow(text: "Battery", glyph: "battery.100")
                                HStack {
                                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                                        Text("86").font(Brand.mono(28, .semibold)).foregroundStyle(Brand.textPrimary)
                                        Text("%").font(Brand.sans(13)).foregroundStyle(Brand.textSecondary)
                                    }
                                    Spacer()
                                    RingGauge(percent: 86, color: Brand.accent, glyph: "laptopcomputer",
                                              label: "Mac", size: 44)
                                }
                            }
                        }
                    }
                    HistoryChartPreview()
                }
                .padding(24)
            }
            .background(Brand.canvas)
        }
        .background(Brand.canvas)
    }

    private func tile(_ title: String, _ glyph: String, _ value: String, _ unit: String, _ series: [Double]) -> some View {
        ValueTile(eyebrow: title, glyph: glyph, accent: Brand.accent,
                  value: value, unit: unit, values: series, chartStyle: .area,
                  domain: unit == "%" ? .percent : .fromZero,
                  footnote: "last 30 minutes")
    }
}

/// Menu-bar popover chrome: glass tiles, sparklines, thin ring, circular actions.
/// Same fields on both sides. Left is the upstream field list; right is the restyled HUD.
private struct PopoverParity: View {
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Upstream fields").font(Brand.sans(12, .semibold)).foregroundStyle(Brand.textPrimary)
                ForEach(ParityFields.all, id: \.self) { field in
                    Text(field).font(Brand.sans(10)).foregroundStyle(Brand.textSecondary)
                }
            }
            .frame(width: 220, alignment: .leading)
            FullPopoverPreview().frame(width: 360)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(hex: 0x141414))
        .environment(\.colorScheme, .dark)
    }
}

private enum ParityFields {
    static let all = [
        "Score 100 · Excellent · 1.67 TB free",
        "M5 Max · 64.0 GB · macOS 27.2.1 · up 3h 19m",
        "CPU 20% · 65°C · load 6.70",
        "GPU 45% · 63°C · M5 Max",
        "Memory 49% · pressure 18% · 31.3/64 GB · swap 0.0 GB",
        "Disk 1.67 TB free · 1.8 TB · 150.5 GB used · 8%",
        "Network 76.3 MB/s · en0 · ↓ 75190 ↑ 2912 KB/s",
        "Fan 1,489 RPM · 2 fans · macOS manages speed",
        "Battery 100% · 0:00 · 1 cyc · 100% Health · ring",
        "Top drain — Cursor · avg 85% CPU",
        "Processes: name · CPU% · memory · menu",
        "Stay Awake · Wipe · Eject",
        "Clean Watch 3.09 GB · 0 uninstalled · 1 optimized",
        "Tool grid: all 10 tools",
        "History · Settings · Open Burrow · Power",
        "MCP · 127.0.0.1:9277 + stdio",
    ]
}

private struct FullPopoverPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(Brand.green)
                Text("100").font(Brand.mono(16, .semibold)).foregroundStyle(Brand.textPrimary)
                Text("Excellent").font(Brand.sans(11)).foregroundStyle(Brand.textSecondary).lineLimit(1)
                Spacer(minLength: 4)
                Text("1.67 TB free").font(Brand.mono(10)).foregroundStyle(Brand.textTertiary)
            }
            HStack(spacing: 5) {
                Chip(text: "M5 Max", color: Brand.textSecondary)
                Chip(text: "64.0 GB", color: Brand.textSecondary)
                Chip(text: "macOS 27.2.1", color: Brand.textSecondary)
                Chip(text: "up 3h 19m", color: Brand.textSecondary)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ValueTile(variant: .hud, eyebrow: "CPU", glyph: "cpu", accent: Brand.green,
                          value: "20", unit: "%", chip: ("65°C", Brand.orange),
                          values: ChartFixture.cpu, domain: .percent, footnote: "load 6.70")
                ValueTile(variant: .hud, eyebrow: "GPU", glyph: "cpu.fill", accent: Brand.orange,
                          value: "45", unit: "%", chip: ("63°C", Brand.orange),
                          values: ChartFixture.gpu, domain: .percent, footnote: "M5 Max")
                ValueTile(variant: .hud, eyebrow: "Memory", glyph: "memorychip", accent: Brand.green,
                          value: "49", unit: "%", chip: ("18%", Brand.green),
                          values: ChartFixture.mem, domain: .percent, footnote: "31.3/64 GB · swap 0.0 GB")
                hudDisk
                ValueTile(variant: .hud, eyebrow: "Network", glyph: "network", accent: Brand.green,
                          value: "76.3", unit: "MB/s", chip: ("en0", Brand.blue),
                          values: ChartFixture.net, domain: .fromZero, footnote: "↓ 75190 ↑ 2912 KB/s")
                hudFan
            }
            battery
            processes
            HStack(spacing: 6) {
                action("cup.and.saucer.fill", "Stay Awake")
                action("rectangle.inset.filled", "Wipe")
                action("eject.fill", "Eject")
            }
            HStack {
                Eyebrow(text: "Clean Watch", glyph: "sparkles", color: Tool.clean.accent)
                Spacer()
                Text("3.09 GB cleaned · 0 uninstalled · 1 optimized")
                    .font(Brand.mono(9)).foregroundStyle(Brand.textSecondary)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 5), spacing: 6) {
                ForEach(Tool.navOrder) { tool in
                    Image(systemName: tool.glyph)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(tool.accent)
                        .frame(maxWidth: .infinity, minHeight: 26)
                        .glassTile(corner: 13)
                        .help(tool.title)
                }
            }
            HStack {
                Image(systemName: "clock.arrow.circlepath").foregroundStyle(Brand.textSecondary)
                Image(systemName: "gearshape").foregroundStyle(Brand.textSecondary)
                Spacer()
                Text("Open Burrow").font(Brand.sans(11, .semibold)).foregroundStyle(Brand.textPrimary)
                Image(systemName: "power").foregroundStyle(Brand.textSecondary)
            }
            Text("MCP · 127.0.0.1:9277 + stdio").font(Brand.mono(9)).foregroundStyle(Brand.textTertiary)
        }
        .padding(13)
        .background { PopupGlassStandIn() }
        .environment(\.colorScheme, .dark)
    }

    private var hudDisk: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Eyebrow(text: "Disk", glyph: "internaldrive", color: Brand.blue)
                Spacer()
                Chip(text: "1.8 TB", color: Brand.textSecondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("1.67 TB").font(Brand.mono(15, .semibold)).foregroundStyle(Brand.textPrimary)
                Text("free").font(Brand.mono(9)).foregroundStyle(Brand.textSecondary)
            }
            LowSpaceBar(fraction: 0.08)
            Text("150.5 GB used · 8%").font(Brand.mono(8.5)).foregroundStyle(Brand.textTertiary)
        }
        .padding(8).glassTile(corner: 12)
    }

    private var hudFan: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Eyebrow(text: "Fan", glyph: "fan", color: Brand.textSecondary)
                Spacer()
                Chip(text: "2 fans", color: Brand.textSecondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("1,489").font(Brand.mono(15, .semibold)).foregroundStyle(Brand.textPrimary)
                Text("RPM").font(Brand.mono(9)).foregroundStyle(Brand.textSecondary)
            }
            MiniChart(values: ChartFixture.net, color: Brand.textSecondary, domain: .fromZero, allowsFlat: true)
                .frame(height: 16)
            Text("macOS manages speed").font(Brand.mono(8.5)).foregroundStyle(Brand.textTertiary)
        }
        .padding(8).glassTile(corner: 12)
    }

    private var battery: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Eyebrow(text: "Battery", glyph: "battery.100", color: Brand.green)
                Spacer()
                Chip(text: "100% Health", color: Brand.green)
            }
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("100%").font(Brand.mono(16, .semibold)).foregroundStyle(Brand.textPrimary)
                        Text("0:00").font(Brand.mono(10)).foregroundStyle(Brand.textSecondary)
                    }
                    Text("1 cyc").font(Brand.mono(9)).foregroundStyle(Brand.textTertiary)
                }
                Spacer()
                RingGauge(percent: 100, color: Brand.green, glyph: "laptopcomputer", label: "Mac", size: 34)
            }
            Text("Top drain — Cursor · avg 85% CPU over the last hour")
                .font(Brand.mono(9)).foregroundStyle(Brand.textSecondary).lineLimit(1)
        }
        .padding(10).glassTile(corner: 12)
    }

    private var processes: some View {
        VStack(alignment: .leading, spacing: 4) {
            Eyebrow(text: "Top processes", glyph: "list.bullet", color: Brand.textSecondary)
            row("WindowServer", "78.9%", "490.2 MB", hot: true)
            row("Grok", "25.2%", "516.4 MB", hot: false)
            row("Grok", "17.7%", "107.6 MB", hot: false)
            row("com.apple.WebKit.WebContent", "17.6%", "799.5 MB", hot: false)
        }
    }

    private func row(_ name: String, _ cpu: String, _ mem: String, hot: Bool) -> some View {
        HStack(spacing: 8) {
            Text(name).font(Brand.sans(11)).foregroundStyle(Brand.textPrimary).lineLimit(1)
            Spacer()
            Text(cpu).font(Brand.mono(10)).foregroundStyle(hot ? Brand.orange : Brand.textSecondary)
            Text(mem).font(Brand.mono(10)).foregroundStyle(Brand.textTertiary).frame(width: 64, alignment: .trailing)
            Image(systemName: "ellipsis").font(.system(size: 10)).foregroundStyle(Brand.textTertiary)
        }
    }

    private func action(_ glyph: String, _ title: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: glyph).font(.system(size: 10, weight: .medium))
            Text(title).font(Brand.sans(11, .medium))
        }
        .foregroundStyle(Brand.textSecondary)
        .padding(.horizontal, 9).padding(.vertical, 5)
        .glassTile(corner: 14)
    }
}

private struct PopupGlassStandIn: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color(hex: 0x171717).opacity(0.92))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.7))
    }
}

private struct HistoryChartPreview: View {
    private var points: [(Date, Double)] {
        let start = Date().addingTimeInterval(-3600)
        return ChartFixture.cpu.enumerated().map { i, v in
            (start.addingTimeInterval(Double(i) * 75), v)
        }
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text("CPU usage").font(Brand.sans(15, .semibold)).foregroundStyle(Brand.textPrimary)
                    Text("%").font(Brand.sans(12)).foregroundStyle(Brand.textTertiary)
                }
                Chart {
                    ForEach(Array(points.enumerated()), id: \.offset) { _, p in
                        AreaMark(x: .value("Time", p.0), y: .value("Value", p.1))
                            .foregroundStyle(LinearGradient(
                                colors: [Brand.accent.opacity(0.28), Brand.accent.opacity(0)],
                                startPoint: .top, endPoint: .bottom))
                            .interpolationMethod(.catmullRom)
                        LineMark(x: .value("Time", p.0), y: .value("Value", p.1))
                            .foregroundStyle(Brand.accent)
                            .lineStyle(StrokeStyle(lineWidth: 1.75, lineCap: .round))
                            .interpolationMethod(.catmullRom)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisValueLabel(format: .dateTime.hour().minute())
                            .font(Brand.sans(10)).foregroundStyle(Brand.textTertiary)
                    }
                }
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(position: .leading, values: [0, 50, 100]) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Brand.hairline)
                        AxisValueLabel().font(Brand.sans(10)).foregroundStyle(Brand.textTertiary)
                    }
                }
                .frame(height: 180)
            }
        }
    }
}

/// The previous sparkline: chunky bars and a hard polyline, for the before shot.
private struct BeforeChartsPreview: View {
    var body: some View {
        VStack(spacing: 8) {
            legacy("CPU", ChartFixture.cpu, bars: true, color: Color(hex: 0x3CB371))
            legacy("Memory", ChartFixture.mem, bars: false, color: Color(hex: 0xF0B24A))
        }
        .padding(12)
        .background(Color(hex: 0x1A1812))
    }

    private func legacy(_ title: String, _ values: [Double], bars: Bool, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased()).font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(color)
            Text("20%").font(.system(size: 15, weight: .semibold, design: .monospaced)).foregroundStyle(.white)
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                let hi = values.max() ?? 1
                if bars {
                    let slot = w / CGFloat(values.count)
                    Path { p in
                        for (i, v) in values.enumerated() {
                            let bh = max(2, CGFloat(v / hi) * h)
                            let bw = slot * 0.62
                            p.addRect(CGRect(x: CGFloat(i) * slot, y: h - bh, width: bw, height: bh))
                        }
                    }.fill(color)
                } else {
                    Path { p in
                        for (i, v) in values.enumerated() {
                            let pt = CGPoint(x: w * CGFloat(i) / CGFloat(values.count - 1),
                                             y: (1 - CGFloat(v / hi)) * h)
                            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
                        }
                    }.stroke(color, lineWidth: 1.5)
                }
            }
            .frame(height: 28)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.18)))
    }
}
