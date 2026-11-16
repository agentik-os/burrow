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

    let values: [Double]
    var color: Color
    var style: Style = .area
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
            ChartSmoothing.area(pts, bottom: h)
                .fill(LinearGradient(
                    colors: [color.opacity(0.32), color.opacity(0.04), color.opacity(0)],
                    startPoint: .top, endPoint: .bottom))
            ChartSmoothing.curve(pts)
                .stroke(color, style: StrokeStyle(lineWidth: 1.75, lineCap: .round, lineJoin: .round))
        }
    }

    private func points(w: CGFloat, h: CGFloat) -> [CGPoint] {
        let vals = samples
        let (lo, hi) = bounds(vals)
        let denom = max(hi - lo, 0.0001)
        let n = vals.count
        return vals.enumerated().map { i, v in
            let x = n == 1 ? w / 2 : w * CGFloat(i) / CGFloat(n - 1)
            let y = (1.0 - CGFloat((v - lo) / denom)) * (h - 2) + 1
            return CGPoint(x: x, y: y)
        }
    }

    /// Floor at 0. A steady non-zero series sits in the band instead of
    /// pinning to the ceiling; a dead-flat zero is handled by `silent`.
    private func bounds(_ vals: [Double]) -> (lo: Double, hi: Double) {
        let lo = min(vals.min() ?? 0, 0)
        let hi = vals.max() ?? 1
        if hi - lo < 0.001 { return (0, max(hi * 1.35, 1)) }
        let pad = (hi - lo) * 0.12
        return (lo, hi + pad)
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
                let hi = max(d.max() ?? 0, u.max() ?? 0, 0.0001) * 1.12
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
    /// Bucket a noisy feed, then a short moving average, capped so a
    /// sparkline never plots hundreds of kinks.
    static func prepare(_ values: [Double], maxPoints: Int = 48) -> [Double] {
        let tail = values.count > 240 ? Array(values.suffix(240)) : values
        return movingAverage(downsample(tail, to: maxPoints), window: 3)
    }

    static func downsample(_ values: [Double], to max: Int) -> [Double] {
        guard values.count > max, max > 1 else { return values }
        let step = Double(values.count) / Double(max)
        return (0..<max).map { i in
            let start = Int(Double(i) * step)
            let end = min(values.count, max(start + 1, Int(Double(i + 1) * step)))
            let slice = values[start..<end]
            return slice.reduce(0, +) / Double(slice.count)
        }
    }

    static func movingAverage(_ values: [Double], window: Int) -> [Double] {
        guard window > 1, values.count > window else { return values }
        let half = window / 2
        return values.indices.map { i in
            let lo = max(0, i - half)
            let hi = min(values.count, i + half + 1)
            let slice = values[lo..<hi]
            return slice.reduce(0, +) / Double(slice.count)
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
            let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
            let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
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
