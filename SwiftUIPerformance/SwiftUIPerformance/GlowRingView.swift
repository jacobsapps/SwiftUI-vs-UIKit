import SwiftUI
import PerformanceShared

struct GlowRingView: View {
    let color: UIColor
    let isAnimating: Bool

    var body: some View {
        if isAnimating {
            TimelineView(.animation) { timeline in
                GlowCanvas(
                    color: color,
                    phase: phase(for: timeline.date)
                )
            }
        } else {
            GlowCanvas(color: color, phase: 0)
        }
    }

    private func phase(for date: Date) -> CGFloat {
        let t = date.timeIntervalSinceReferenceDate
        let raw = (t / FeedSpec.Glow.duration).truncatingRemainder(dividingBy: 1)
        return CGFloat(raw)
    }
}

private struct GlowCanvas: View {
    let color: UIColor
    let phase: CGFloat

    var body: some View {
        Canvas { context, size in
            guard size.width > 0, size.height > 0 else { return }
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: FeedSpec.Glow.pathInset, dy: FeedSpec.Glow.pathInset)
            let radius = max(FeedSpec.Cell.cornerRadius - FeedSpec.Glow.pathInset, 0)
            let path = roundedRectPath(in: rect, radius: radius)
            let length = roundedRectLength(in: rect, radius: radius)

            drawGlow(
                context: &context,
                path: path,
                length: length,
                phase: phase
            )
            drawGlow(
                context: &context,
                path: path,
                length: length,
                phase: (phase + 0.5).truncatingRemainder(dividingBy: 1)
            )
        }
    }

    private func drawGlow(context: inout GraphicsContext, path: Path, length: CGFloat, phase: CGFloat) {
        guard length > 0 else { return }
        let headDistance = phase * length
        var tailDistance = headDistance - FeedSpec.Glow.tailLength
        if tailDistance < 0 {
            tailDistance += length
        }
        let tailFraction = FeedSpec.Glow.tailLength / length
        let headFraction = phase
        let tailFractionStart = headFraction - tailFraction

        let headPoint = roundedRectPoint(distance: headDistance, rect: path.boundingRect, radius: radius(from: path))
        let tailPoint = roundedRectPoint(distance: tailDistance, rect: path.boundingRect, radius: radius(from: path))

        let headColor = Color(uiColor: color.withAlphaComponent(FeedSpec.Glow.headAlpha))
        let tailColor = Color(uiColor: color.withAlphaComponent(FeedSpec.Glow.tailAlpha))
        let dotColor = Color(uiColor: color.withAlphaComponent(FeedSpec.Glow.dotAlpha))

        let shading = GraphicsContext.Shading.linearGradient(
            Gradient(colors: [tailColor, headColor]),
            startPoint: tailPoint,
            endPoint: headPoint
        )

        if tailFractionStart >= 0 {
            let trimmed = path.trimmedPath(from: tailFractionStart, to: headFraction)
            context.stroke(trimmed, with: shading, style: StrokeStyle(lineWidth: FeedSpec.Glow.tailWidth, lineCap: .round))
        } else {
            let wrappedStart = 1 + tailFractionStart
            let segmentA = path.trimmedPath(from: wrappedStart, to: 1)
            let segmentB = path.trimmedPath(from: 0, to: headFraction)
            context.stroke(segmentA, with: shading, style: StrokeStyle(lineWidth: FeedSpec.Glow.tailWidth, lineCap: .round))
            context.stroke(segmentB, with: shading, style: StrokeStyle(lineWidth: FeedSpec.Glow.tailWidth, lineCap: .round))
        }

        _ = dotColor
    }

    private func radius(from path: Path) -> CGFloat {
        let rect = path.boundingRect
        return max(FeedSpec.Cell.cornerRadius - FeedSpec.Glow.pathInset, 0).clamped(to: 0...min(rect.width, rect.height) / 2)
    }

    private func roundedRectPath(in rect: CGRect, radius: CGFloat) -> Path {
        Path(roundedRect: rect, cornerRadius: radius)
    }

    private func roundedRectLength(in rect: CGRect, radius: CGFloat) -> CGFloat {
        let r = radius.clamped(to: 0...min(rect.width, rect.height) / 2)
        let straight = 2 * (rect.width + rect.height - 4 * r)
        let arc = 2 * .pi * r
        return straight + arc
    }

    private func roundedRectPoint(distance: CGFloat, rect: CGRect, radius: CGFloat) -> CGPoint {
        let r = radius.clamped(to: 0...min(rect.width, rect.height) / 2)
        let top = rect.width - 2 * r
        let right = rect.height - 2 * r
        let arc = CGFloat.pi / 2 * r
        let total = 2 * (top + right) + 4 * arc
        var d = distance.truncatingRemainder(dividingBy: total)

        let start = CGPoint(x: rect.minX + r, y: rect.minY)
        if d <= top {
            return CGPoint(x: start.x + d, y: start.y)
        }
        d -= top

        if d <= arc {
            return pointOnArc(center: CGPoint(x: rect.maxX - r, y: rect.minY + r),
                              radius: r,
                              startAngle: -.pi / 2,
                              delta: d / r)
        }
        d -= arc

        if d <= right {
            return CGPoint(x: rect.maxX, y: rect.minY + r + d)
        }
        d -= right

        if d <= arc {
            return pointOnArc(center: CGPoint(x: rect.maxX - r, y: rect.maxY - r),
                              radius: r,
                              startAngle: 0,
                              delta: d / r)
        }
        d -= arc

        if d <= top {
            return CGPoint(x: rect.maxX - r - d, y: rect.maxY)
        }
        d -= top

        if d <= arc {
            return pointOnArc(center: CGPoint(x: rect.minX + r, y: rect.maxY - r),
                              radius: r,
                              startAngle: .pi / 2,
                              delta: d / r)
        }
        d -= arc

        if d <= right {
            return CGPoint(x: rect.minX, y: rect.maxY - r - d)
        }
        d -= right

        return pointOnArc(center: CGPoint(x: rect.minX + r, y: rect.minY + r),
                          radius: r,
                          startAngle: .pi,
                          delta: d / r)
    }

    private func pointOnArc(center: CGPoint, radius: CGFloat, startAngle: CGFloat, delta: CGFloat) -> CGPoint {
        let angle = startAngle + delta
        return CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
    }
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
