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
        let pop = CGSize(width: 380, height: 720)
        try write(PopoverPreview(), name: "after-popover-light", scheme: .light, dir: dir, size: pop)
        try write(PopoverPreview(), name: "after-popover-dark", scheme: .dark, dir: dir, size: pop)
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
                  footnote: "last 30 minutes")
    }
}

/// Menu-bar popover chrome: glass tiles, sparklines, thin ring, circular actions.
private struct PopoverPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                BurrowMark().frame(width: 18, height: 18)
                Text("100").font(Brand.mono(16, .semibold)).foregroundStyle(Brand.textPrimary)
                Text("Excellent").font(Brand.sans(12)).foregroundStyle(Brand.textSecondary)
                Spacer()
                Text("1.67 TB free").font(Brand.sans(11)).foregroundStyle(Brand.textTertiary)
            }
            GlassGroup(spacing: 8) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ValueTile(variant: .hud, eyebrow: "CPU", glyph: "cpu", accent: Brand.accent,
                              value: "20", unit: "%", values: ChartFixture.cpu, footnote: "load 6.70")
                    ValueTile(variant: .hud, eyebrow: "GPU", glyph: "cpu.fill", accent: Brand.accent,
                              value: "45", unit: "%", values: ChartFixture.gpu, footnote: "M5 Max")
                    ValueTile(variant: .hud, eyebrow: "Memory", glyph: "memorychip", accent: Brand.accent,
                              value: "49", unit: "%", values: ChartFixture.mem, footnote: "31.3 / 64 GB")
                    ValueTile(variant: .hud, eyebrow: "Network", glyph: "network", accent: Brand.accent,
                              value: "76.3", unit: "MB/s", values: ChartFixture.net, footnote: "en0")
                }
            }
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Eyebrow(text: "Battery", glyph: "battery.100")
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("100").font(Brand.mono(18, .semibold)).foregroundStyle(Brand.textPrimary)
                        Text("%").font(Brand.sans(11)).foregroundStyle(Brand.textSecondary)
                    }
                    Text("1 cycle").font(Brand.sans(11)).foregroundStyle(Brand.textTertiary)
                }
                Spacer()
                RingGauge(percent: 100, color: Brand.accent, glyph: "laptopcomputer", label: "Mac", size: 36)
            }
            .padding(10)
            .glassTile(corner: 12)
            VStack(alignment: .leading, spacing: 0) {
                Eyebrow(text: "Top processes", glyph: "list.bullet")
                process("WindowServer", "18.2%", "490 MB")
                Rectangle().fill(Brand.hairline).frame(height: 1)
                process("Burrow", "4.1%", "210 MB")
                Rectangle().fill(Brand.hairline).frame(height: 1)
                process("Finder", "1.4%", "96 MB")
            }
            GlassGroup(spacing: 8) {
                HStack(spacing: 8) {
                    GlassCircleButton(systemName: "trash", helpText: "Clean") {}
                    GlassCircleButton(systemName: "slider.horizontal.3", helpText: "Optimize") {}
                    GlassCircleButton(systemName: "chart.pie", helpText: "Analyze") {}
                    GlassCircleButton(systemName: "wifi", helpText: "Network") {}
                    Spacer()
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.ultraThinMaterial)
    }

    private func process(_ name: String, _ cpu: String, _ mem: String) -> some View {
        HStack {
            Text(name).font(Brand.sans(12)).foregroundStyle(Brand.textPrimary)
            Spacer()
            Text(cpu).font(Brand.mono(11)).foregroundStyle(Brand.textSecondary)
            Text(mem).font(Brand.mono(11)).foregroundStyle(Brand.textTertiary).frame(width: 64, alignment: .trailing)
        }
        .padding(.vertical, 6)
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
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
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
