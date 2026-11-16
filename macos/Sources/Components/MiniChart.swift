//
//  MiniChart.swift
//  Burrow / Components
//
//  Inline sparkline. One accent, a thin smoothed line, and a soft area
//  that fades out. No axes — the tile already states the current value.
//  Custom paths, not Swift Charts: these sit in a 20–40 pt strip where
//  Charts' plot margins would swallow the series (issue #75).
//

import SwiftUI

struct MiniChart: View {
    enum Style { case area, bars }
    /// `.percent` is always 0…100, so 15% sits near the bottom.
    /// `.fromZero` starts at 0 and ends just above the peak.
    enum Domain { case percent, fromZero }

    let values: [Double]
    var color: Color
    var style: Style = .area
    var domain: Domain = .fromZero
    /// Parked fans are a real all-zero series. Everything else treats a
    /// flat zero as "no samples yet" instead of drawing a dead line.
    var allowsFlat: Bool = false

    @State private var hover: Double?

    private var samples: [Double] {
        ChartSmoothing.prepare(values)
    }

    private var silent: Bool {
        let vals = samples
        guard vals.count >= 2 else { return true }
        return !allowsFlat && vals.allSatisfy { abs($0) < 0.0001 }
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack(alignment: .topTrailing) {
                if silent {
                    emptyTrack(w: w, h: h)
                } else {
                    sparkline(w: w, h: h)
                }
                if h >= 24, let hover {
                    Text(Self.format(hover))
                        .font(Brand.mono(9, .medium))
                        .foregroundStyle(Brand.textPrimary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(.ultraThinMaterial))
                        .allowsHitTesting(false)
                }
            }
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                guard !silent, h >= 24 else { hover = nil; return }
                switch phase {
                case .active(let pt):
                    let vals = samples
                    guard vals.count > 1, w > 0 else { return }
                    let t = min(max(pt.x / w, 0), 1)
                    let idx = Int((t * CGFloat(vals.count - 1)).rounded())
                    hover = vals[min(max(idx, 0), vals.count - 1)]
                case .ended:
                    hover = nil
                }
            }
        }
    }

    private func emptyTrack(w: CGFloat, h: CGFloat) -> some View {
        Capsule()
            .fill(Brand.trackFill)
            .frame(height: 2)
            .frame(maxHeight: .infinity, alignment: .center)
            .padding(.horizontal, 1)
            .accessibilityLabel(NSLocalizedString("No chart data yet", comment: ""))
    }

    private func sparkline(w: CGFloat, h: CGFloat) -> some View {
        let pts = points(w: w, h: h)
        return ZStack {
            guides(w: w, h: h)
            ChartSmoothing.area(pts, bottom: h - 1)
                .fill(LinearGradient(
                    colors: [color.opacity(0.22), color.opacity(0)],
                    startPoint: .top, endPoint: .bottom))
            ChartSmoothing.curve(pts)
                .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            if let last = pts.last {
                Circle().fill(color).frame(width: 4, height: 4).position(last)
            }
        }
    }

    /// Honest scale marks: baseline always, and a midpoint when the axis is 0…100.
    private func guides(w: CGFloat, h: CGFloat) -> some View {
        VStack(spacing: 0) {
            if domain == .percent {
                Spacer()
                Rectangle().fill(Brand.hairline).frame(height: 0.5)
            }
            Spacer()
            Rectangle().fill(Brand.hairline).frame(height: 0.5)
        }
        .frame(width: w, height: h)
    }

    private func points(w: CGFloat, h: CGFloat) -> [CGPoint] {
        let vals = samples
        let (lo, hi) = ChartSmoothing.scale(vals, domain: domain)
        let denom = max(hi - lo, 0.0001)
        let n = vals.count
        let plotH = h - 3
        return vals.enumerated().map { i, v in
            let x = n == 1 ? w / 2 : w * CGFloat(i) / CGFloat(max(n - 1, 1))
            let y = (1.0 - CGFloat((min(max(v, lo), hi) - lo) / denom)) * plotH + 1
            return CGPoint(x: x, y: y)
        }
    }

    private static func format(_ v: Double) -> String {
        abs(v) >= 100 ? String(format: "%.0f", v) : String(format: "%.1f", v)
    }
}

/// Two sparklines on one scale — network download and upload. The second
/// series is a quieter tint of the same accent so the tile stays one color.
struct DualMiniChart: View {
    let down: [Double]
    let up: [Double]
    var downColor: Color
    var upColor: Color
    var domain: MiniChart.Domain = .fromZero

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let d = ChartSmoothing.prepare(down)
            let u = ChartSmoothing.prepare(up)
            let silent = d.count < 2 && u.count < 2
            if silent {
                Capsule().fill(Brand.trackFill).frame(height: 2)
                    .frame(maxHeight: .infinity, alignment: .center)
            } else {
                let hi = ChartSmoothing.scale(d + u, domain: domain).hi
                ZStack {
                    series(d, w: w, h: h, hi: hi, color: downColor)
                    series(u, w: w, h: h, hi: hi, color: upColor)
                }
            }
        }
    }

    @ViewBuilder
    private func series(_ vals: [Double], w: CGFloat, h: CGFloat, hi: Double, color: Color) -> some View {
        if vals.count >= 2 {
            let n = vals.count
            let pts: [CGPoint] = vals.enumerated().map { i, v in
                CGPoint(x: w * CGFloat(i) / CGFloat(n - 1),
                        y: (1.0 - CGFloat(v / hi)) * (h - 2) + 1)
            }
            ZStack {
                ChartSmoothing.area(pts, bottom: h)
                    .fill(LinearGradient(
                        colors: [color.opacity(0.28), color.opacity(0)],
                        startPoint: .top, endPoint: .bottom))
                ChartSmoothing.curve(pts)
                    .stroke(color, style: StrokeStyle(lineWidth: 1.75, lineCap: .round, lineJoin: .round))
            }
        }
    }
}

enum ChartSmoothing {
    /// Keep the real samples. Only a long feed is reduced, and each bucket
    /// keeps its peak so a spike is not averaged away.
    static func prepare(_ values: [Double], maxPoints: Int = 72) -> [Double] {
        let tail = values.count > 360 ? Array(values.suffix(360)) : values
        return downsample(tail, to: maxPoints)
    }

    static func scale(_ values: [Double], domain: MiniChart.Domain) -> (lo: Double, hi: Double) {
        switch domain {
        case .percent:
            return (0, 100)
        case .fromZero:
            let peak = values.max() ?? 0
            return (0, peak <= 0 ? 1 : peak * 1.12)
        }
    }

    static func downsample(_ values: [Double], to limit: Int) -> [Double] {
        guard values.count > limit, limit > 1 else { return values }
        let step = Double(values.count) / Double(limit)
        return (0..<limit).map { i in
            let start = Int(Double(i) * step)
            let end = min(values.count, Swift.max(start + 1, Int(Double(i + 1) * step)))
            return values[start..<end].max() ?? 0
        }
    }

    /// Catmull-Rom through the points, as cubic segments. One path, so the
    /// popover never grows a view per sample (issue #75).
    static func curve(_ pts: [CGPoint]) -> Path {
        var path = Path()
        guard let first = pts.first else { return path }
        path.move(to: first)
        guard pts.count > 2 else {
            if pts.count == 2 { path.addLine(to: pts[1]) }
            return path
        }
        for i in 0..<(pts.count - 1) {
            let p0 = pts[max(i - 1, 0)]
            let p1 = pts[i]
            let p2 = pts[i + 1]
            let p3 = pts[min(i + 2, pts.count - 1)]
            // Tight handles: the curve passes the samples instead of bowing past them.
            let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 10, y: p1.y + (p2.y - p0.y) / 10)
            let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 10, y: p2.y - (p3.y - p1.y) / 10)
            path.addCurve(to: p2, control1: c1, control2: c2)
        }
        return path
    }

    static func area(_ pts: [CGPoint], bottom: CGFloat) -> Path {
        var path = curve(pts)
        guard let first = pts.first, let last = pts.last else { return path }
        path.addLine(to: CGPoint(x: last.x, y: bottom))
        path.addLine(to: CGPoint(x: first.x, y: bottom))
        path.closeSubpath()
        return path
    }
}
