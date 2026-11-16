//
//  Tool.swift
//  Burrow
//
//  The tools, each with a monochrome SF Symbol. Navigation colour is
//  shared (see Brand) — a tool no longer repaints the window. `navOrder`
//  is the sidebar order. `.status` is the live dashboard, reached as Home.
//

import SwiftUI

enum Tool: String, CaseIterable, Identifiable {
    case clean, purge, installer, apps, optimize, analyze, dupes, orphans, photos, status, ports, net, connectivity, tuneup

    var id: String { rawValue }

    /// Display order in the top nav. Purge and Installer fold into Clean as
    /// category cards (CleanHub), so the cleanup family is one pill: clean →
    /// optimize, then apps / analyze. The .purge/.installer cases live on for
    /// the hub cards, MCP actions, and Explain deep-links. The live dashboard
    /// isn't a tool anymore — it's Home, reached by the Burrow mark.
    static let navOrder: [Tool] = [.clean, .optimize, .apps, .analyze, .dupes, .orphans, .photos, .ports, .net, .connectivity]

    /// Lowercase tab label (matches the instrument-panel voice).
    var label: String { NSLocalizedString(rawValue, comment: "") }

    /// Title-case name for heroes / headings.
    var title: String {
        switch self {
        case .clean:     return NSLocalizedString("Clean", comment: "")
        case .purge:     return NSLocalizedString("Purge", comment: "")
        case .installer: return NSLocalizedString("Installers", comment: "")
        case .apps:      return NSLocalizedString("Apps", comment: "")
        case .optimize:  return NSLocalizedString("Optimize", comment: "")
        case .analyze:   return NSLocalizedString("Analyze", comment: "")
        case .dupes:     return NSLocalizedString("Duplicates", comment: "")
        case .orphans:   return NSLocalizedString("Leftovers", comment: "")
        case .photos:    return NSLocalizedString("Similar Photos", comment: "")
        case .status:    return NSLocalizedString("Status", comment: "")
        case .ports:     return NSLocalizedString("Ports", comment: "")
        case .net:       return NSLocalizedString("Network", comment: "")
        case .connectivity: return NSLocalizedString("Get Online", comment: "")
        case .tuneup:    return NSLocalizedString("Tune-Up", comment: "")
        }
    }

    var glyph: String {
        switch self {
        case .clean:     return "trash"
        case .purge:     return "folder"
        case .installer: return "arrow.down.circle"
        case .apps:      return "square.grid.2x2"
        case .optimize:  return "slider.horizontal.3"
        case .analyze:   return "chart.pie"
        case .dupes:     return "doc.on.doc"
        case .orphans:   return "tray"
        case .photos:    return "photo"
        case .status:    return "waveform.path"
        case .ports:     return "network"
        case .net:       return "arrow.up.arrow.down"
        case .connectivity: return "wifi"
        case .tuneup:    return "wrench.and.screwdriver"
        }
    }

    /// Tools share one ink. Status colour (success, warning, danger) lives
    /// on `Brand`, not on the tool, so navigation stays monochrome.
    var accent: Color { Brand.textPrimary }

    /// Our own one-liner per tool — earthy, in keeping with the name.
    var tagline: String {
        switch self {
        case .clean:     return NSLocalizedString("Fresh air through old tunnels.", comment: "")
        case .purge:     return NSLocalizedString("Clear the diggings dev work leaves behind.", comment: "")
        case .installer: return NSLocalizedString("Sweep out the crates you unpacked.", comment: "")
        case .apps:      return NSLocalizedString("Shed what you've outgrown.", comment: "")
        case .optimize:  return NSLocalizedString("Small turns, a smoother run.", comment: "")
        case .analyze:   return NSLocalizedString("Map every chamber below.", comment: "")
        case .dupes:     return NSLocalizedString("Find what you've stashed twice.", comment: "")
        case .orphans:   return NSLocalizedString("Traces of tenants long gone.", comment: "")
        case .photos:    return NSLocalizedString("Spot the shots that echo.", comment: "")
        case .status:    return NSLocalizedString("Every pulse of the den.", comment: "")
        case .ports:     return NSLocalizedString("See who's listening.", comment: "")
        case .net:       return NSLocalizedString("Watch what travels the tunnels.", comment: "")
        case .connectivity: return NSLocalizedString("Find your way back to the surface.", comment: "")
        case .tuneup:    return NSLocalizedString("One pass, a tidier den.", comment: "")
        }
    }
}

/// Everything the main window can show. The five tools plus Burrow's two
/// extras (Settings, History) — all navigated from the same top bar, in
/// the same window, so there's exactly one navigation model in the app.
enum Pane: Equatable, Hashable {
    case home          // the live dashboard: Overview · History · Activity
    case tool(Tool)
    case settings
}
