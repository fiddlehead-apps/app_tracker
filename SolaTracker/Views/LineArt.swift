import SwiftUI

/// Slim line drawing in the style of the app icon. Coordinates are those of the
/// 1024 px icon canvas (tools/make_icon.py); `area` is the part of it to show.
struct LineArt: View {
    let area: CGRect
    let width: CGFloat
    var lineWidth: CGFloat = 3.5
    var color: Color = .accentColor
    let draw: (inout Path) -> Void

    var body: some View {
        let scale = width / area.width
        Canvas { ctx, _ in
            var path = Path()
            draw(&path)
            let fit = CGAffineTransform(scaleX: scale, y: scale).translatedBy(x: -area.minX, y: -area.minY)
            ctx.stroke(path.applying(fit), with: .color(color),
                       style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        }
        .frame(width: width, height: area.height * scale)
        .accessibilityHidden(true)
    }
}

extension Path {
    /// Fiddlehead curl starting at `start`, leaving in direction `heading`
    /// (degrees, 0 = up, clockwise). Same construction as the curl in the app icon.
    mutating func addFiddlehead(at start: CGPoint, heading: Double, radius: Double, turns: Int = 3, left: Bool = false) {
        let h = heading * .pi / 180, flip: Double = left ? -1 : 1
        func place(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: start.x + flip * x * cos(h) - y * sin(h), y: start.y + flip * x * sin(h) + y * cos(h))
        }
        move(to: start)
        var from = 0.0
        for (i, f) in [1, 0.64, 0.33, 0.12].prefix(turns).enumerated() {
            let r = radius * f
            let (cx, a0) = i % 2 == 0 ? (from + r, Double.pi) : (from - r, 0)
            for k in 1...40 {
                let a = a0 + .pi * Double(k) / 40
                addLine(to: place(cx + r * cos(a), r * sin(a)))
            }
            from = cx - r * cos(a0)
        }
    }
}

private func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

/// Tally marks whose strike curls up at the end. The motif of the app icon.
struct TallyIllustration: View {
    var body: some View {
        LineArt(area: CGRect(x: 220, y: 276, width: 588, height: 472), width: 110) { p in
            for x: CGFloat in [314, 416, 518, 620] {
                p.move(to: pt(x, 300))
                p.addLine(to: pt(x, 724))
            }
            p.move(to: pt(244, 640))
            p.addLine(to: pt(660, 420))
            p.addFiddlehead(at: pt(660, 420), heading: atan2(416, 220) * 180 / .pi, radius: 84)
        }
    }
}
