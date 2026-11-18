// --- DNK-MRH-HEADER ---
// mrh_id: "Sources/DNKPiu/DNAHelixView.swift"
// purpose: "Sovereign Minimalist Linear Sine Cybernetic DNA Molecule (Concept 3: Swiss/Braun Minimal) with Dynamic Lifecycle & Red Pulse."
// canonical_source: true
// status: "Active"
// version: "5.0.0"
// updated_at: "2026-11-18"
// author: "DNK-e.com Maksym & Antigravity"
// --- END DNK-MRH-HEADER ---

import AppKit
import Foundation
import PiuCore
import SwiftUI

/// Sovereign Minimalist Linear Sine Cybernetic DNA Molecule (Концепт 3: Minimalist Linear Sine).
/// Mathematically pure sine curves with smooth continuous curvature, 5 horizontal laser rungs, and glowing terminal pearls.
///
/// States:
/// - Idle (Не диктуємо): Червона пульсуюча (#EF4444) — спокійне дихання люмінесценції (0.84...1.0) з червоним неоновим ореолом.
/// - Listening (Диктуємо / надиктовуємо): Інтенсивна червона акустична пульсація під гучність мікрофона audioLevel.
/// - Thinking (Транскрибуємо): Електричний синій (#3B82F6) з біжучим квантовим фотоном по хвилі.
/// - Done (Вставлено): Резонансний м'ятний спалах (#36F4A4).
/// - Failed: Кораловий тривожний строб.
public struct DNAHelixView: View {
    public let phase: DictationPhase
    public let audioLevel: Float
    public let size: CGFloat

    public init(phase: DictationPhase = .idle, audioLevel: Float = 0.0, size: CGFloat = 20.0) {
        self.phase = phase
        self.audioLevel = audioLevel
        self.size = size
    }

    private var isListening: Bool {
        if case .listening = phase { return true }
        return false
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, canvasSize in
                renderSineDNA(context: &context, size: canvasSize, time: t)
            }
        }
        .frame(width: size, height: size, alignment: .center)
    }

    // MARK: - Metal-Accelerated Minimalist Sine Renderer
    private func renderSineDNA(context: inout GraphicsContext, size canvasSize: CGSize, time t: TimeInterval) {
        let w = canvasSize.width
        let h = canvasSize.height

        let scale = min(w / 64.0, h / 120.0)
        let ox = w / 2.0
        let oy = h / 2.0

        let (frontBaseColor, backBaseColor, rungBaseColor, glowColor) = phaseColors()

        // 1. Calculate animation & pulse parameters
        let breathAlpha: Double = {
            switch phase {
            case .idle:
                return 0.84 + 0.16 * sin(t * 3.2)
            case .listening:
                let vol = Double(min(1.0, max(0.0, audioLevel)))
                return 0.90 + 0.10 * vol
            case .thinking:
                return 0.95
            case .done:
                return 1.0
            case .failed:
                return 0.70 + 0.30 * sin(t * 14.0)
            }
        }()

        let volumeBoost: CGFloat = {
            if case .listening = phase {
                return CGFloat(min(1.0, max(0.0, audioLevel)))
            }
            return 0.0
        }()

        // 2. Ambient Glow Pass
        let glowRadius = min(w, h) * (phase == .idle ? 0.36 : (isListening ? 0.44 : 0.34))
        let glowRect = CGRect(
            x: (w - glowRadius * 2) / 2.0,
            y: (h - glowRadius * 2) / 2.0,
            width: glowRadius * 2,
            height: glowRadius * 2
        )
        context.fill(Path(ellipseIn: glowRect), with: .color(glowColor.opacity(0.24 * breathAlpha)))

        let halfH: CGFloat = 50.0 * scale
        let baseAmp: CGFloat = 24.0 * scale
        let amp: CGFloat = baseAmp * (1.0 + volumeBoost * 0.14)

        let rungW = max(1.0, 6.0 * scale)
        let strandW = max(2.2, 14.0 * scale)
        let highlightW = max(0.8, 5.0 * scale)
        let nodeR = max(1.2, 6.0 * scale)
        let pearlR = max(1.8, 9.0 * scale)

        // 3. Base-Pair Rungs (5 horizontal laser connections)
        let rungRatios: [CGFloat] = [-0.76, -0.38, 0.0, 0.38, 0.76]
        for ratio in rungRatios {
            let ry = ratio * halfH
            let p = (ratio + 1.0) / 2.0
            let wRung = abs(sin(p * 2.0 * .pi)) * amp

            if wRung > 2.0 {
                var rungPath = Path()
                rungPath.move(to: CGPoint(x: ox - wRung, y: oy + ry))
                rungPath.addLine(to: CGPoint(x: ox + wRung, y: oy + ry))

                context.stroke(
                    rungPath,
                    with: .color(rungBaseColor.opacity(breathAlpha * 0.85)),
                    style: StrokeStyle(lineWidth: rungW, lineCap: .round)
                )

                // Central laser micro-node
                let np = CGPoint(x: ox, y: oy + ry)
                let nodeRect = CGRect(x: np.x - nodeR, y: np.y - nodeR, width: nodeR * 2, height: nodeR * 2)
                context.fill(Path(ellipseIn: nodeRect), with: .color(Color.white))
            }
        }

        // 4. Compute Continuous Sine Curve Paths
        var backPath = Path()
        var frontPath = Path()

        let steps = 40
        for i in 0...steps {
            let p = CGFloat(i) / CGFloat(steps)
            let y = -halfH + p * (halfH * 2.0)
            let sineX = sin(p * 2.0 * .pi) * amp

            let ptFront = CGPoint(x: ox + sineX, y: oy + y)
            let ptBack = CGPoint(x: ox - sineX, y: oy + y)

            if i == 0 {
                frontPath.move(to: ptFront)
                backPath.move(to: ptBack)
            } else {
                frontPath.addLine(to: ptFront)
                backPath.addLine(to: ptBack)
            }
        }

        // 5. Draw Back Strand
        context.stroke(
            backPath,
            with: .color(backBaseColor.opacity(breathAlpha)),
            style: StrokeStyle(lineWidth: strandW, lineCap: .round, lineJoin: .round)
        )

        // 6. Draw Front Strand with 3D Drop Shadow
        context.stroke(
            frontPath,
            with: .color(Color.black.opacity(0.38)),
            style: StrokeStyle(lineWidth: strandW + 3.0 * scale, lineCap: .round, lineJoin: .round)
        )

        context.stroke(
            frontPath,
            with: .color(frontBaseColor.opacity(breathAlpha)),
            style: StrokeStyle(lineWidth: strandW, lineCap: .round, lineJoin: .round)
        )

        // Specular glint
        context.stroke(
            frontPath,
            with: .color(Color.white.opacity(0.40)),
            style: StrokeStyle(lineWidth: highlightW, lineCap: .round, lineJoin: .round)
        )

        // 7. Terminal Glowing Pearls (Top & Bottom)
        let topPt = CGPoint(x: ox, y: oy - halfH)
        let botPt = CGPoint(x: ox, y: oy + halfH)

        for pt in [topPt, botPt] {
            let pRect = CGRect(x: pt.x - pearlR, y: pt.y - pearlR, width: pearlR * 2, height: pearlR * 2)
            context.fill(Path(ellipseIn: pRect), with: .color(frontBaseColor.opacity(breathAlpha)))
            let coreRect = CGRect(x: pt.x - pearlR * 0.6, y: pt.y - pearlR * 0.6, width: pearlR * 1.2, height: pearlR * 1.2)
            context.fill(Path(ellipseIn: coreRect), with: .color(Color.white))
        }

        // 8. Thinking Phase: Traveling Photon Wave
        if case .thinking = phase {
            let photonPhase = (t * 2.2).truncatingRemainder(dividingBy: 1.0)
            let py = -halfH + CGFloat(photonPhase) * (halfH * 2.0)
            let px = sin(photonPhase * 2.0 * .pi) * amp
            let ppos = CGPoint(x: ox + px, y: oy + py)
            let pr = max(2.0, 8.0 * scale)
            let pRect = CGRect(x: ppos.x - pr, y: ppos.y - pr, width: pr * 2, height: pr * 2)
            context.fill(Path(ellipseIn: pRect), with: .color(Color.white))
        }
    }

    // MARK: - Color Palette Matching the Swallow (Ластівка)
    private func phaseColors() -> (front: Color, back: Color, rung: Color, glow: Color) {
        switch phase {
        case .idle:
            // Червона пульсуюча коли не диктуємо (#EF4444)
            return (
                Color(hex: "#EF4444"),
                Color(hex: "#B91C1C"),
                Color(hex: "#FECACA"),
                Color(hex: "#EF4444")
            )
        case .listening:
            // Інтенсивний червоний з білим еквалайзером при вимові (#EF4444)
            return (
                Color(hex: "#EF4444"),
                Color(hex: "#B91C1C"),
                Color(hex: "#FCA5A5"),
                Color(hex: "#EF4444")
            )
        case .thinking:
            // Електричний синій (#3B82F6) як ширяюча ластівка
            return (
                Color(hex: "#3B82F6"),
                Color(hex: "#1D4ED8"),
                Color(hex: "#93C5FD"),
                Color(hex: "#3B82F6")
            )
        case .done:
            // Фірмовий електричний м'ятний (#36F4A4)
            return (
                AstryxTheme.shopifyMint,
                Color(hex: "#059669"),
                Color.white,
                AstryxTheme.shopifyMint
            )
        case .failed:
            // Кораловий тривожний
            return (
                Color(hex: "#EF4444"),
                Color(hex: "#991B1B"),
                Color(hex: "#DC2626"),
                Color(hex: "#EF4444")
            )
        }
    }

    // MARK: - Menubar Status Bar Template Icon
    public static func createMenubarIcon(size: NSSize = NSSize(width: 18, height: 18)) -> NSImage {
        let img = NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

            let w = size.width
            let h = size.height

            let scale = min(w / 64.0, h / 120.0)
            let ox = w / 2.0
            let oy = h / 2.0

            let halfH: CGFloat = 50.0 * scale
            let amp: CGFloat = 24.0 * scale

            let rungW = max(1.0, 6.0 * scale)
            let strandW = max(2.2, 14.0 * scale)

            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            ctx.setStrokeColor(NSColor.black.cgColor)
            ctx.setFillColor(NSColor.black.cgColor)

            // Rungs
            ctx.setLineWidth(rungW)
            let rungRatios: [CGFloat] = [-0.76, -0.38, 0.0, 0.38, 0.76]
            for ratio in rungRatios {
                let ry = ratio * halfH
                let p = (ratio + 1.0) / 2.0
                let wRung = abs(sin(p * 2.0 * .pi)) * amp
                if wRung > 2.0 {
                    ctx.move(to: CGPoint(x: ox - wRung, y: oy + ry))
                    ctx.addLine(to: CGPoint(x: ox + wRung, y: oy + ry))
                    ctx.strokePath()
                }
            }

            // Sine Strands
            ctx.setLineWidth(strandW)
            let steps = 30
            for strandSign in [CGFloat(1.0), CGFloat(-1.0)] {
                for i in 0...steps {
                    let p = CGFloat(i) / CGFloat(steps)
                    let y = -halfH + p * (halfH * 2.0)
                    let sineX = strandSign * sin(p * 2.0 * .pi) * amp
                    let pt = CGPoint(x: ox + sineX, y: oy + y)

                    if i == 0 {
                        ctx.move(to: pt)
                    } else {
                        ctx.addLine(to: pt)
                    }
                }
                ctx.strokePath()
            }

            return true
        }
        img.isTemplate = true
        return img
    }
}
