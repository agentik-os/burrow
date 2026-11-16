//
//  WindowMetricsTests.swift
//  BurrowTests
//
//  The window may never clip Settings, and it must still fit a small laptop.
//
//  Navigation used to be a fixed-height icon rail. Its minimum was a
//  hand-picked 640, tools were added, and Settings fell off the bottom.
//  The sidebar scrolls its tool list and pins Settings, so the minimum is
//  a constant again — these tests lock that constant to the sidebar's own
//  measurements instead of a magic number copied into the window.
//

import XCTest
@testable import Burrow

final class WindowMetricsTests: XCTestCase {

    /// Pinned chrome is exactly the pieces SidebarNav lays out above, below,
    /// and beside the scrolling tool list. A stray spacer in that formula
    /// would change what "Settings still fits" means.
    func testPinnedChromeMatchesTheSidebarComposition() {
        let expected =
            SidebarMetrics.topPadding
            + SidebarMetrics.headerHeight
            + SidebarMetrics.headerGap
            + SidebarMetrics.rowHeight
            + SidebarMetrics.sectionGap
            + SidebarMetrics.sectionLabelHeight
            + SidebarMetrics.listTopGap
            + SidebarMetrics.dividerSpacing
            + SidebarMetrics.dividerThickness
            + SidebarMetrics.dividerSpacing
            + SidebarMetrics.rowHeight
            + SidebarMetrics.bottomPadding
        XCTAssertEqual(SidebarMetrics.pinnedChrome, expected)
    }

    /// The smallest window shows the pinned chrome and today's tools without
    /// opening the list already scrolled. Settings is pinned either way.
    func testMinimumHeightFitsPinnedChromeAndTodaysTools() {
        let needed = SidebarMetrics.pinnedChrome
            + SidebarMetrics.listHeight(toolCount: Tool.navOrder.count)
        XCTAssertGreaterThanOrEqual(WindowMetrics.minimumHeight, needed)
    }

    /// The bug that shipped: 640 was already too short for the old rail.
    /// The minimum stays above that floor on purpose.
    func testMinimumStaysAboveTheOldClippedHeight() {
        XCTAssertGreaterThan(WindowMetrics.minimumHeight, 640)
    }

    /// Adding a tool lengthens the scrolling list by one row and one gap.
    /// It must not change the window minimum — the list absorbs it.
    func testToolListGrowsWithoutChangingTheWindowMinimum() {
        let current = SidebarMetrics.listHeight(toolCount: Tool.navOrder.count)
        let oneMore = SidebarMetrics.listHeight(toolCount: Tool.navOrder.count + 1)
        XCTAssertEqual(oneMore - current, SidebarMetrics.rowHeight + SidebarMetrics.rowSpacing)
        XCTAssertEqual(WindowMetrics.minimumHeight, 680)
        XCTAssertGreaterThan(WindowMetrics.minimumHeight, SidebarMetrics.pinnedChrome)
    }

    func testListHeightMatchesRowMath() {
        let tools = 4
        let expected = SidebarMetrics.rowHeight * CGFloat(tools)
            + SidebarMetrics.rowSpacing * CGFloat(tools - 1)
        XCTAssertEqual(SidebarMetrics.listHeight(toolCount: tools), expected)
        XCTAssertEqual(SidebarMetrics.listHeight(toolCount: 0), 0)
    }

    /// Width is a deliberate content judgement, not derived — so it just has
    /// to stay sane. This catches an accidental zero or a wild value.
    func testMinimumWidthStaysReasonable() {
        XCTAssertEqual(WindowMetrics.minimumSize.width, WindowMetrics.minimumWidth)
        XCTAssertGreaterThanOrEqual(WindowMetrics.minimumWidth, 900)
        XCTAssertLessThanOrEqual(WindowMetrics.minimumWidth, 1400,
                                 "a minimum this large stops fitting on small laptops")
        XCTAssertGreaterThan(WindowMetrics.minimumWidth, SidebarMetrics.width + 480,
                             "the content column needs room beside the sidebar")
    }

    /// The minimum must fit on the smallest display Burrow supports. A
    /// 13-inch MacBook Air is 1440×900 in points, and macOS reserves the menu
    /// bar, so anything approaching 900 tall is unusable there.
    func testMinimumSizeFitsASmallLaptopDisplay() {
        XCTAssertLessThanOrEqual(WindowMetrics.minimumSize.width, 1440)
        XCTAssertLessThanOrEqual(WindowMetrics.minimumSize.height, 820,
                                 "must leave room for the menu bar on a 900pt-tall display")
    }

    func testSidebarWidthLeavesRoomForLabels() {
        XCTAssertGreaterThanOrEqual(SidebarMetrics.width, 200)
        XCTAssertLessThanOrEqual(SidebarMetrics.width, 280)
    }
}
