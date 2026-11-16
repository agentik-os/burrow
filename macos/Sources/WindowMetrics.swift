//
//  WindowMetrics.swift
//  Burrow
//
//  One definition of how small the main window may get.
//
//  The sidebar is a full-height column. Its tool list scrolls and Settings
//  is pinned, so the window no longer has to grow every time a tool is
//  added — that used to clip Settings off the bottom of a too-short window.
//  The minimum is still tall enough for the pinned chrome plus today's
//  tool list, and short enough for a 13-inch MacBook Air.
//

import CoreGraphics

/// Fixed geometry of the navigation sidebar. `SidebarNav` lays out with
/// these numbers and nothing else, so `pinnedChrome` is the height that
/// stays on screen when the tool list scrolls.
enum SidebarMetrics {
    static let width: CGFloat = 240
    static let rowHeight: CGFloat = 34
    static let rowSpacing: CGFloat = 2
    static let iconColumn: CGFloat = 18
    /// Clears the traffic lights that sit over the sidebar's top-leading
    /// corner (the window is a transparent-titlebar full-size content view,
    /// so the safe area does not do this for us).
    static let topPadding: CGFloat = 52
    static let bottomPadding: CGFloat = 12
    static let horizontalPadding: CGFloat = 10
    static let headerHeight: CGFloat = 40
    /// Air between the wordmark and the pinned Monitor row.
    static let headerGap: CGFloat = 8
    static let sectionGap: CGFloat = 10
    static let sectionLabelHeight: CGFloat = 18
    static let listTopGap: CGFloat = 6
    static let dividerSpacing: CGFloat = 8
    static let dividerThickness: CGFloat = 1

    /// Wordmark, Monitor, section label, the gap before the scrolling list,
    /// the divider, and the pinned Settings row — everything except tools.
    static var pinnedChrome: CGFloat {
        topPadding
            + headerHeight
            + headerGap
            + rowHeight
            + sectionGap
            + sectionLabelHeight
            + listTopGap
            + dividerSpacing
            + dividerThickness
            + dividerSpacing
            + rowHeight
            + bottomPadding
    }

    /// Height of `toolCount` navigation rows, including the gaps between them.
    static func listHeight(toolCount: Int) -> CGFloat {
        let rows = CGFloat(max(toolCount, 0)) * rowHeight
        let gaps = CGFloat(max(toolCount - 1, 0)) * rowSpacing
        return rows + gaps
    }
}

enum WindowMetrics {
    /// The narrowest the window may be.
    ///
    /// Width is a content judgement — the widest panes (Analyze's treemap,
    /// the process tables) stop being readable below this — so it stays a
    /// deliberate constant. It includes the sidebar.
    static let minimumWidth: CGFloat = 980

    /// Tall enough for the pinned sidebar chrome and today's tool list,
    /// short enough to leave a menu bar on a 900pt display.
    static let minimumHeight: CGFloat = 680

    static var minimumSize: CGSize {
        CGSize(width: minimumWidth, height: minimumHeight)
    }
}
