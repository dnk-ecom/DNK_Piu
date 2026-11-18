import AppKit
import Foundation
import PiuCore
import SwiftUI

/// High-performance, Metal-accelerated Cybernetic DNA Molecule (Біо-кібернетична молекула ДНК)
/// meticulously matching the sovereign DNK brand identity with real-time acoustic streaming reactivity.
///
/// States:
/// - Idle: Hypnotic breathing glow along Cyber Amethyst (#A855F7) & Electric Mint (#36F4A4) circuit traces.
/// - Listening: Acoustic streaming reactivity — nodes and rungs pulse dynamically with microphone volume, shifting to Electric Crimson (#EF4444) & Neon Amber (#F59E0B).
/// - Thinking: Upward quantum data stream flowing through the helical backbone in Electric Blue (#3B82F6) & Neon Cyan (#38BDF8).
/// - Done: Resonant harmonic mint pulse (#36F4A4).
/// - Failed: Coral/Red alert flicker.
public struct DNAHelixView: View {
    public let phase: DictationPhase
    public let audioLevel: Float
    public let size: CGFloat

    public init(phase: DictationPhase = .idle, audioLevel: Float = 0.0, size: CGFloat = 24.0) {
        self.phase = phase
        self.audioLevel = audioLevel
        self.size = size
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, canvasSize in
                renderCyberDNA(context: &context, size: canvasSize, time: t)
            }
        }
        .frame(width: size, height: size, alignment: .center)
    }

    // MARK: - Metal-Accelerated Cyber DNA Canvas Renderer
    private func renderCyberDNA(context: inout GraphicsContext, size canvasSize: CGSize, time t: TimeInterval) {
        let w = canvasSize.width
        let h = canvasSize.height

        // Mathematical scaling from canonical coordinate space (w: 335, h: 600)
        let scale = min(w / 335.0, h / 600.0) * 0.94
        let ox = (w - 335.0 * scale) / 2.0
        let oy = (h - 600.0 * scale) / 2.0

        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: ox + x * scale, y: oy + y * scale)
        }

        let (spineColor, compColor, padColor, glowColor) = phaseColors()

        let baseSpineW = max(1.2, 18.0 * scale)
        let baseRungW = max(0.9, 11.0 * scale)
        let baseNodeR = max(1.4, 15.0 * scale)

        // Acoustic scaling for listening phase
        let volumeBoost: CGFloat = {
            switch phase {
            case .listening:
                return CGFloat(min(1.0, max(0.0, audioLevel)))
            default:
                return 0.0
            }
        }()

        let spineW = baseSpineW * (1.0 + volumeBoost * 0.15)
        let rungW = baseRungW * (1.0 + volumeBoost * 0.20)
        let nodeR = baseNodeR * (1.0 + volumeBoost * 0.35)

        // Streaming speed
        let speed: Double = {
            switch phase {
            case .listening: return 4.0 + Double(volumeBoost) * 7.5
            case .thinking: return 6.5
            case .done: return 2.0
            case .failed: return 3.0
            case .idle: return 2.0
            }
        }()

        let streamPhase = (t * speed).truncatingRemainder(dividingBy: 1.0)
        let breathAlpha = 0.85 + 0.15 * sin(t * 3.0)

        // 1. Companion Tracks (Green / Mint / Cyan)
        var topCompPath = Path()
        topCompPath.move(to: p(275, 18))
        topCompPath.addLine(to: p(275, 78))
        topCompPath.addLine(to: p(200, 138))

        var midCompPath = Path()
        midCompPath.move(to: p(145, 184))
        midCompPath.addLine(to: p(69, 244))
        midCompPath.addLine(to: p(69, 363))
        midCompPath.addLine(to: p(145, 423))

        var botCompPath = Path()
        botCompPath.move(to: p(200, 468))
        botCompPath.addLine(to: p(275, 528))
        botCompPath.addLine(to: p(275, 588))

        // Ambient glow pass for companion tracks
        context.stroke(topCompPath, with: .color(compColor.opacity(0.35 * breathAlpha)), lineWidth: spineW + 2.5)
        context.stroke(topCompPath, with: .color(compColor), lineWidth: spineW)

        context.stroke(midCompPath, with: .color(compColor.opacity(0.35 * breathAlpha)), lineWidth: spineW + 2.5)
        context.stroke(midCompPath, with: .color(compColor), lineWidth: spineW)

        context.stroke(botCompPath, with: .color(compColor.opacity(0.35 * breathAlpha)), lineWidth: spineW + 2.5)
        context.stroke(botCompPath, with: .color(compColor), lineWidth: spineW)

        // 2. Spine (Continuous Diagonal Ribbon)
        var spinePath = Path()
        spinePath.move(to: p(69, 18))
        spinePath.addLine(to: p(69, 78))
        spinePath.addLine(to: p(275, 242))
        spinePath.addLine(to: p(275, 365))
        spinePath.addLine(to: p(69, 528))
        spinePath.addLine(to: p(69, 588))

        context.stroke(spinePath, with: .color(glowColor.opacity(0.40 * breathAlpha)), lineWidth: spineW + 3.0)
        context.stroke(spinePath, with: .color(spineColor), lineWidth: spineW)

        // 3. Horizontal Rungs and Contact Nodes
        let rungs: [(CGFloat, CGFloat, CGFloat, CGFloat, Bool)] = [
            // Top tier
            (69, 18, 228, 18, true),
            (69, 56, 228, 56, true),
            (115, 115, 175, 115, true),
            // Middle tier
            (190, 172, 138, 172, true),
            (275, 228, 118, 228, true),
            (275, 272, 118, 272, true),
            (275, 316, 118, 316, true),
            (190, 435, 138, 435, true),
            // Bottom tier
            (115, 492, 175, 492, true),
            (69, 550, 228, 550, true),
            (69, 588, 228, 588, true)
        ]

        for (sx, sy, ex, ey, hasNode) in rungs {
            var rPath = Path()
            rPath.move(to: p(sx, sy))
            rPath.addLine(to: p(ex, ey))
            context.stroke(rPath, with: .color(spineColor), lineWidth: rungW)

            if hasNode {
                let ep = p(ex, ey)
                let nodeRect = CGRect(x: ep.x - nodeR, y: ep.y - nodeR, width: nodeR * 2, height: nodeR * 2)
                context.fill(Path(ellipseIn: nodeRect), with: .color(spineColor))
                // Specular micro-core
                let dotR = max(0.6, nodeR * 0.42)
                let dotRect = CGRect(x: ep.x - dotR, y: ep.y - dotR, width: dotR * 2, height: dotR * 2)
                context.fill(Path(ellipseIn: dotRect), with: .color(Color.white.opacity(0.92)))
            }
        }

        // 4. Square Microchip Pads
        let pads: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (288, 50, 36, 36),
            (288, 220, 36, 36),
            (288, 270, 36, 36),
            (16, 520, 36, 36)
        ]

        for (px, py, pw, ph) in pads {
            let p1 = p(px, py)
            let rectPad = CGRect(x: p1.x, y: p1.y, width: pw * scale, height: ph * scale)
            let rVal = max(1.5, 7.0 * scale)
            context.fill(Path(roundedRect: rectPad, cornerRadius: rVal), with: .color(padColor))
            context.stroke(
                Path(roundedRect: rectPad, cornerRadius: rVal),
                with: .color(Color.white.opacity(0.55)),
                lineWidth: max(0.6, 1.2 * scale)
            )

            // Center IC contact dot
            let dotX = rectPad.midX
            let dotY = rectPad.midY
            let cR = max(0.8, 3.8 * scale)
            context.fill(
                Path(ellipseIn: CGRect(x: dotX - cR, y: dotY - cR, width: cR * 2, height: cR * 2)),
                with: .color(Color.white.opacity(0.95))
            )
        }

        // 5. Streaming Data Packet Pulse (Traveling along spine)
        let packetProgress = phase == .thinking ? (1.0 - streamPhase) : streamPhase
        let packetY: CGFloat = 18.0 + CGFloat(packetProgress) * (588.0 - 18.0)
        let packetX: CGFloat = {
            if packetY < 78.0 {
                return 69.0
            } else if packetY <= 242.0 {
                let frac = (packetY - 78.0) / (242.0 - 78.0)
                return 69.0 + frac * (275.0 - 69.0)
            } else if packetY <= 365.0 {
                return 275.0
            } else if packetY <= 528.0 {
                let frac = (packetY - 365.0) / (528.0 - 365.0)
                return 275.0 - frac * (275.0 - 69.0)
            } else {
                return 69.0
            }
        }()

        let pktPoint = p(packetX, packetY)
        let pktR = max(1.5, nodeR * 0.85)
        context.fill(
            Path(ellipseIn: CGRect(x: pktPoint.x - pktR, y: pktPoint.y - pktR, width: pktR * 2, height: pktR * 2)),
            with: .color(Color.white.opacity(0.95))
        )
    }

    // MARK: - Color Palette Mapping
    private func phaseColors() -> (Color, Color, Color, Color) {
        switch phase {
        case .listening:
            // Electric Crimson & Neon Amber
            return (
                Color(hex: "#EF4444"),
                Color(hex: "#F59E0B"),
                Color(hex: "#FB923C"),
                Color(hex: "#EF4444")
            )
        case .thinking:
            // Radiant Electric Blue & Sky Cyan
            return (
                Color(hex: "#3B82F6"),
                Color(hex: "#38BDF8"),
                Color(hex: "#60A5FA"),
                Color(hex: "#3B82F6")
            )
        case .done:
            // Pure Electric Mint Harmonic
            return (
                AstryxTheme.shopifyMint,
                AstryxTheme.shopifyMint,
                AstryxTheme.shopifyMint,
                AstryxTheme.shopifyMint
            )
        case .failed:
            // Coral Warning
            return (
                Color(hex: "#EF4444"),
                Color(hex: "#DC2626"),
                Color(hex: "#EF4444"),
                Color(hex: "#EF4444")
            )
        case .idle:
            // Cyber Amethyst (#A855F7) & Electric Mint (#36F4A4)
            return (
                Color(hex: "#A855F7"),
                AstryxTheme.shopifyMint,
                Color(hex: "#8B5CF6"),
                Color(hex: "#A855F7")
            )
        }
    }

    // MARK: - Menubar Status Bar Template Icon
    public static func createMenubarIcon(size: NSSize = NSSize(width: 18, height: 18)) -> NSImage {
        let img = NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

            let w = size.width
            let h = size.height
            let scale = min(w / 335.0, h / 600.0) * 0.94
            let ox = (w - 335.0 * scale) / 2.0
            let oy = (h - 600.0 * scale) / 2.0

            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: ox + x * scale, y: oy + y * scale)
            }

            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)

            let spineW = max(1.2, 18.0 * scale)
            let rungW = max(0.9, 11.0 * scale)
            let nodeR = max(1.4, 15.0 * scale)

            ctx.setStrokeColor(NSColor.black.cgColor)
            ctx.setFillColor(NSColor.black.cgColor)

            // 1. Companion tracks
            ctx.setLineWidth(spineW)
            ctx.move(to: p(275, 18))
            ctx.addLine(to: p(275, 78))
            ctx.addLine(to: p(200, 138))
            ctx.strokePath()

            ctx.move(to: p(145, 184))
            ctx.addLine(to: p(69, 244))
            ctx.addLine(to: p(69, 363))
            ctx.addLine(to: p(145, 423))
            ctx.strokePath()

            ctx.move(to: p(200, 468))
            ctx.addLine(to: p(275, 528))
            ctx.addLine(to: p(275, 588))
            ctx.strokePath()

            // 2. Spine
            ctx.move(to: p(69, 18))
            ctx.addLine(to: p(69, 78))
            ctx.addLine(to: p(275, 242))
            ctx.addLine(to: p(275, 365))
            ctx.addLine(to: p(69, 528))
            ctx.addLine(to: p(69, 588))
            ctx.strokePath()

            // 3. Rungs & Nodes
            let rungs: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
                (69, 18, 228, 18),
                (69, 56, 228, 56),
                (115, 115, 175, 115),
                (190, 172, 138, 172),
                (275, 228, 118, 228),
                (275, 272, 118, 272),
                (275, 316, 118, 316),
                (190, 435, 138, 435),
                (115, 492, 175, 492),
                (69, 550, 228, 550),
                (69, 588, 228, 588)
            ]

            ctx.setLineWidth(rungW)
            for (sx, sy, ex, ey) in rungs {
                ctx.move(to: p(sx, sy))
                ctx.addLine(to: p(ex, ey))
                ctx.strokePath()

                let ep = p(ex, ey)
                ctx.fillEllipse(in: CGRect(x: ep.x - nodeR, y: ep.y - nodeR, width: nodeR * 2, height: nodeR * 2))
            }

            // 4. Chip pads
            let pads: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
                (288, 50, 36, 36),
                (288, 220, 36, 36),
                (288, 270, 36, 36),
                (16, 520, 36, 36)
            ]
            for (px, py, pw, ph) in pads {
                let p1 = p(px, py)
                let rectPad = CGRect(x: p1.x, y: p1.y, width: pw * scale, height: ph * scale)
                ctx.fill(rectPad)
            }

            return true
        }
        img.isTemplate = true
        return img
    }
}
