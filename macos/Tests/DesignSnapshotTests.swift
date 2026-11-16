//
//  DesignSnapshotTests.swift
//  BurrowTests
//
//  Offscreen renders of the redesigned shell, written only when
//  BURROW_SNAPSHOT_DIR is set (the macOS app workflow). Absent that
//  variable the test skips, so the normal suite stays hermetic.
//

import AppKit
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
        guard let raw = ProcessInfo.processInfo.environment["BURROW_SNAPSHOT_DIR"], !raw.isEmpty else {
            throw XCTSkip("BURROW_SNAPSHOT_DIR is unset")
        }
        let dir = URL(fileURLWithPath: raw, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let size = CGSize(width: 1040, height: 700)
        try write(ShellPreview(pane: .home), name: "monitor-light", scheme: .light, dir: dir, size: size)
        try write(ShellPreview(pane: .tool(.clean)), name: "monitor-dark", scheme: .dark, dir: dir, size: size)
        try write(CleanPreview(), name: "clean-light", scheme: .light, dir: dir, size: size)
        try write(CleanPreview(), name: "clean-dark", scheme: .dark, dir: dir, size: size)
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
