//
//  HomeView.swift
//  Burrow
//
//  Home — the live dashboard, reached by clicking the Burrow mark. It folds
//  the three "watch your Mac" views into one place behind a segmented switch:
//
//    Overview  — live metric cards + the process table (the old Status tab)
//    History   — long-range charts over the SQLite history
//    Activity  — Mole's cleanup session log
//
//  The Explain (AI) entry point lives here too, so it can speak to whatever
//  you're looking at — or the whole picture.
//

import SwiftUI

struct HomeView: View {
    let db: DB
    let live: LiveFeed
    let feeds: FeedHub
    var onNavigate: (Pane) -> Void

    enum Section: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case tuneup = "Tune-Up"
        case history = "History"
        case activity = "Activity"
        case doctor = "Doctor"
        var id: String { rawValue }
    }

    @State private var section: Section = .overview
    @State private var showExplain = false

    var body: some View {
        VStack(spacing: 0) {
            PaneHeader { header }
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showExplain) {
            ExplainView(db: db,
                        onNavigate: { showExplain = false; onNavigate($0) },
                        onClose: { showExplain = false })
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            segmented
            Spacer()
            if Store.aiEnabled { explainButton }
        }
    }

    private var segmented: some View {
        SegmentedPills(
            items: Array(Section.allCases),
            selection: section,
            title: { NSLocalizedString($0.rawValue, comment: "") },
            onSelect: { section = $0 })
    }

    private var explainButton: some View {
        Button { showExplain = true } label: {
            Label(NSLocalizedString("Explain", comment: ""), systemImage: "sparkles")
                .font(Brand.sans(13, .medium))
                .foregroundStyle(Brand.textPrimary)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: Brand.radiusControl, style: .continuous)
                        .fill(Brand.cardFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Brand.radiusControl, style: .continuous)
                        .strokeBorder(Brand.hairline, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var content: some View {
        switch section {
        case .overview: StatusView(db: db, live: live, feeds: feeds)
        case .tuneup:   TuneUpView()
        case .history:  HistoryView(db: db, live: live, feeds: feeds)
        case .activity: ActivityView(feeds: feeds)
        case .doctor:   DoctorView(db: db)
        }
    }
}
