import Foundation
import SwiftUI

/// Mathematically symmetrical vector shape of the Ukrainian Swallow (Ластівка) in flight.
/// Perfectly balanced around x = width / 2 and optically centered vertically.
public struct SwallowShape: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let cx = w / 2.0

        // Vertical optical adjustment factor (+0.075 shifts visual mass down to true geometric center)
        let yShift = h * 0.075

        // Head / Beak at top center
        path.move(to: CGPoint(x: cx, y: h * 0.08 + yShift))

        // Right Head & Neck
        path.addQuadCurve(to: CGPoint(x: cx + w * 0.12, y: h * 0.22 + yShift),
                          control: CGPoint(x: cx + w * 0.06, y: h * 0.12 + yShift))

        // Right Wing Leading Edge (sweeping up and outward)
        path.addCurve(to: CGPoint(x: cx + w * 0.48, y: h * 0.16 + yShift),
                      control1: CGPoint(x: cx + w * 0.25, y: h * 0.22 + yShift),
                      control2: CGPoint(x: cx + w * 0.38, y: h * 0.16 + yShift))

        // Right Wing Tip & Trailing Edge
        path.addCurve(to: CGPoint(x: cx + w * 0.10, y: h * 0.52 + yShift),
                      control1: CGPoint(x: cx + w * 0.40, y: h * 0.32 + yShift),
                      control2: CGPoint(x: cx + w * 0.22, y: h * 0.44 + yShift))

        // Right Body to Fork of Tail
        path.addQuadCurve(to: CGPoint(x: cx + w * 0.20, y: h * 0.88 + yShift),
                          control: CGPoint(x: cx + w * 0.12, y: h * 0.68 + yShift))

        // Forked Tail Notch (Center Inset)
        path.addLine(to: CGPoint(x: cx, y: h * 0.66 + yShift))

        // Left Fork of Tail
        path.addLine(to: CGPoint(x: cx - w * 0.20, y: h * 0.88 + yShift))

        // Left Body to Wing
        path.addQuadCurve(to: CGPoint(x: cx - w * 0.10, y: h * 0.52 + yShift),
                          control: CGPoint(x: cx - w * 0.12, y: h * 0.68 + yShift))

        // Left Wing Trailing Edge
        path.addCurve(to: CGPoint(x: cx - w * 0.48, y: h * 0.16 + yShift),
                      control1: CGPoint(x: cx - w * 0.22, y: h * 0.44 + yShift),
                      control2: CGPoint(x: cx - w * 0.40, y: h * 0.32 + yShift))

        // Left Wing Leading Edge
        path.addCurve(to: CGPoint(x: cx - w * 0.12, y: h * 0.22 + yShift),
                      control1: CGPoint(x: cx - w * 0.38, y: h * 0.16 + yShift),
                      control2: CGPoint(x: cx - w * 0.25, y: h * 0.22 + yShift))

        // Left Neck & Head back to Beak
        path.addQuadCurve(to: CGPoint(x: cx, y: h * 0.08 + yShift),
                          control: CGPoint(x: cx - w * 0.06, y: h * 0.12 + yShift))

        path.closeSubpath()
        return path
    }
}
