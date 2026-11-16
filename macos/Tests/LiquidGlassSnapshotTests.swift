//
//  LiquidGlassSnapshotTests.swift
//  BurrowTests
//
//  Renders the navigation rail when BURROW_SNAPSHOT_DIR is set, or when
//  Tests/.write-ui-snapshots exists. Skips otherwise.
//

import AppKit
import SwiftUI
import XCTest
@testable import Burrow

final class LiquidGlassSnapshotTests: XCTestCase {
    func testWriteRailSnapshotsWhenRequested() throws {
        let testsDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let sentinel = testsDir.appendingPathComponent(".write-ui-snapshots")
        let envDir = ProcessInfo.processInfo.environment["BURROW_SNAPSHOT_DIR"]
        let requested = FileManager.default.fileExists(atPath: sentinel.path) || (envDir?.isEmpty == false)
        guard requested else { throw XCTSkip("UI snapshots were not requested") }
        let dir = envDir.flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: $0, isDirectory: true) }
            ?? testsDir.appendingPathComponent("ui-snapshots")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let size = CGSize(width: 520, height: 720)
        try write(RailParity(), name: "rail-parity-light", scheme: .light, dir: dir, size: size)
        try write(RailParity(), name: "rail-parity-dark", scheme: .dark, dir: dir, size: size)
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
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds),
              let png = rep.representation(using: .png, properties: [:]) else {
            XCTFail("no bitmap for \(name)")
            return
        }
        try png.write(to: dir.appendingPathComponent("\(name).png"))
    }
}

/// Left: the upstream rail fill. Right: FloatingRail, which uses that fill
/// before macOS 26 and Regular Liquid Glass on macOS 26.
private struct RailParity: View {
    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(spacing: 8) {
                Text("Upstream material").font(Brand.sans(12, .semibold)).foregroundStyle(Brand.textPrimary)
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Brand.cardFill)
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Brand.hairline, lineWidth: 1))
                    .frame(width: RailMetrics.width, height: 640)
            }
            VStack(spacing: 8) {
                Text("This build").font(Brand.sans(12, .semibold)).foregroundStyle(Brand.textPrimary)
                FloatingRail(selected: .constant(.home))
                    .frame(height: 640)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Brand.base)
    }
}
