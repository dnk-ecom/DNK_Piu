// --- DNK-MRH-HEADER ---
// mrh_id: "Sources/DNKPiu/DNAHelixView.swift"
// purpose: "Sovereign 8-Bit Pixel Cybernetic DNA Molecule with Subtle Acoustic & State Reactivity."
// canonical_source: true
// status: "Active"
// version: "2.1.0"
// updated_at: "2026-11-18"
// author: "DNK-e.com Maksym & Antigravity"
// --- END DNK-MRH-HEADER ---

import AppKit
import Foundation
import PiuCore
import SwiftUI

/// High-performance, Metal-accelerated 8-Bit Pixel Cybernetic DNA Molecule (Біо-кібернетична молекула ДНК)
/// Meticulously matching the sovereign DNK brand identity with subtle micro-animations for the floating pill and HUD.
///
/// States:
/// - Idle: Gentle breathing luminescence (0.85...1.0) + subtle traveling cyan rung shimmer (living code).
/// - Listening: Real-time voice acoustic reactivity — cyan base-pair rungs pulse and expand with microphone audioLevel.
/// - Thinking: Upward quantum data cascade in Electric Blue (#3B82F6) & Sky Cyan (#38BDF8).
/// - Done: Resonant harmonic mint flash (#36F4A4).
/// - Failed: Coral warning pulse (#EF4444).
public struct DNAHelixView: View {
    public let phase: DictationPhase
    public let audioLevel: Float
    public let size: CGFloat

    // Canonical 8-Bit Pixel Grid coordinates (9 columns wide: 1...9, 18 rows high: 1...18)
    private static let strandPixels: [(row: Int, col: Int)] = [
        // Loop 1 Top
        (1, 1), (1, 2), (1, 8), (1, 9),
        (2, 2), (2, 3), (2, 7), (2, 8),
        (3, 3), (3, 4), (3, 6), (3, 7),
        (4, 4), (4, 5), (4, 6),
        // Node 1 (Center crossing)
        (5, 5), (5, 6),
        // Loop 1 Bottom / Loop 2 Top
        (6, 4), (6, 5), (6, 6),
        (7, 3), (7, 4), (7, 6), (7, 7),
        (8, 2), (8, 3), (8, 7), (8, 8),
        (9, 1), (9, 2), (9, 8), (9, 9),
        // Loop 2 Mid
        (10, 1), (10, 2), (10, 8), (10, 9),
        (11, 2), (11, 3), (11, 7), (11, 8),
        (12, 3), (12, 4), (12, 6), (12, 7),
        (13, 4), (13, 5), (13, 6),
        // Node 2 (Center crossing)
        (14, 5), (14, 6),
        // Loop 2 Bottom
        (15, 4), (15, 5), (15, 6),
        (16, 3), (16, 4), (16, 6), (16, 7),
        (17, 2), (17, 3), (17, 7), (17, 8),
        (18, 1), (18, 2), (18, 8), (18, 9),
    ]

    // Connecting horizontal base pairs (Sky Cyan)
    private static let rungRows: [Int] = [2, 8, 11, 17]
    private static let rungCols: [Int] = [4, 5, 6]

    public init(phase: DictationPhase = .idle, audioLevel: Float = 0.0, size: CGFloat = 20.0) {
        self.phase = phase
        self.audioLevel = audioLevel
        self.size = size
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, canvasSize in
                renderPixelDNA(context: &context, size: canvasSize, time: t)
            }
        }
        .frame(width: size, height: size, alignment: .center)
    }

    // MARK: - Metal-Accelerated Pixel DNA Renderer
    private func renderPixelDNA(context: inout GraphicsContext, size canvasSize: CGSize, time t: TimeInterval) {
        let w = canvasSize.width
        let h = canvasSize.height

        let gridCols: CGFloat = 9.0
        let gridRows: CGFloat = 18.0

        // Scale to fit canvas with optimal tight margins
        let cellSize = min(w / (gridCols + 1.2), h / (gridRows + 0.6))
        let gridW = gridCols * cellSize
        let gridH = gridRows * cellSize

        // Absolute optical centering
        let ox = (w - gridW) / 2.0 - (1.0 * cellSize)
        let oy = (h - gridH) / 2.0 - (1.0 * cellSize)

        let pixelGap = max(0.3, cellSize * 0.08)
        let cornerRadius = max(0.4, cellSize * 0.14)

        // Palette resolution
        let (strandBaseColor, rungBaseColor, _) = phaseColors()

        // 1. Calculate animation parameters
        let breathAlpha: Double = {
            switch phase {
            case .idle:
                return 0.86 + 0.14 * sin(t * 2.2)
            case .listening:
                let vol = Double(min(1.0, max(0.0, audioLevel)))
                return 0.90 + 0.10 * vol
            case .thinking:
                return 0.95
            case .done:
                return 1.0
            case .failed:
                return 0.75 + 0.25 * sin(t * 12.0)
            }
        }()

        // Mic volume boost for listening phase
        let volumeBoost: CGFloat = {
            if case .listening = phase {
                return CGFloat(min(1.0, max(0.0, audioLevel)))
            }
            return 0.0
        }()

        // Rung shimmer index for idle state (traveling light pulse across 4 rungs)
        let activeShimmerRungIndex: Int = {
            if case .idle = phase {
                let cycle = (t * 0.8).truncatingRemainder(dividingBy: 1.0)
                return Int(cycle * 4.0)
            }
            return -1
        }()

        // Thinking quantum cascade phase
        let thinkingCascadeRow: Int = {
            if case .thinking = phase {
                return Int((t * 14.0).truncatingRemainder(dividingBy: 18.0)) + 1
            }
            return -1
        }()

        // Ambient cyber glow pass in center
        let glowRect = CGRect(x: w * 0.15, y: h * 0.15, width: w * 0.7, height: h * 0.7)
        context.fill(Path(ellipseIn: glowRect), with: .color(strandBaseColor.opacity(0.18 * breathAlpha)))

        // --- DRAW RUNGS (Base Pairs) ---
        for (idx, r) in Self.rungRows.enumerated() {
            let isShimmerActive = (idx == activeShimmerRungIndex)
            let isThinkingNear = abs(r - thinkingCascadeRow) <= 1

            let rungBrightness: Double = {
                if case .listening = phase {
                    return 0.90 + Double(volumeBoost) * 0.35
                } else if isShimmerActive {
                    return 1.0
                } else if isThinkingNear {
                    return 1.0
                }
                return 0.82
            }()

            let rungColor: Color = {
                if isThinkingNear {
                    return Color.white
                } else if isShimmerActive {
                    return Color(hex: "#7DD3FC") // Brighter Ice Cyan
                } else {
                    return rungBaseColor
                }
            }()

            for c in Self.rungCols {
                let px = ox + CGFloat(c) * cellSize
                let py = oy + CGFloat(r) * cellSize
                let rect = CGRect(
                    x: px + pixelGap / 2.0,
                    y: py + pixelGap / 2.0,
                    width: cellSize - pixelGap,
                    height: cellSize - pixelGap
                )

                let path = Path(roundedRect: rect, cornerRadius: cornerRadius)
                context.fill(path, with: .color(rungColor.opacity(breathAlpha * rungBrightness)))

                // Top specular highlight
                let glintRect = CGRect(
                    x: rect.minX + 0.2,
                    y: rect.minY + 0.2,
                    width: rect.width - 0.4,
                    height: max(0.4, rect.height * 0.25)
                )
                context.fill(Path(glintRect), with: .color(Color.white.opacity(0.35)))
            }
        }

        // --- DRAW DOUBLE HELIX STRANDS ---
        for (r, c) in Self.strandPixels {
            let px = ox + CGFloat(c) * cellSize
            let py = oy + CGFloat(r) * cellSize
            let rect = CGRect(
                x: px + pixelGap / 2.0,
                y: py + pixelGap / 2.0,
                width: cellSize - pixelGap,
                height: cellSize - pixelGap
            )

            // Thinking stream highlight
            let isThinkingActive = (r == thinkingCascadeRow || (r + 18 - thinkingCascadeRow) % 18 == 1)

            let pixelColor: Color = {
                if isThinkingActive {
                    return Color.white
                } else if case .listening = phase {
                    // Voice reactive brightness boost
                    if volumeBoost > 0.4 && (c == 5 || c == 6) {
                        return Color(hex: "#F59E0B") // Amber core sparkle on voice peaks
                    }
                    return strandBaseColor
                } else {
                    return strandBaseColor
                }
            }()

            let pixelAlpha = isThinkingActive ? 1.0 : breathAlpha

            let path = Path(roundedRect: rect, cornerRadius: cornerRadius)
            context.fill(path, with: .color(pixelColor.opacity(pixelAlpha)))

            // Specular glint on pixel top for crisp 3D cyber-chip texture
            let glintRect = CGRect(
                x: rect.minX + 0.2,
                y: rect.minY + 0.2,
                width: rect.width - 0.4,
                height: max(0.4, rect.height * 0.25)
            )
            context.fill(Path(glintRect), with: .color(Color.white.opacity(0.32)))
        }
    }

    // MARK: - Color Palette Mapping
    private func phaseColors() -> (strand: Color, rung: Color, glow: Color) {
        switch phase {
        case .listening:
            // Electric Mint & Bright Voice Cyan
            return (
                AstryxTheme.shopifyMint,
                Color(hex: "#38BDF8"),
                AstryxTheme.shopifyMint
            )
        case .thinking:
            // Electric Blue & Cyan Quantum Flow
            return (
                Color(hex: "#3B82F6"),
                Color(hex: "#38BDF8"),
                Color(hex: "#60A5FA")
            )
        case .done:
            // Pure Electric Mint Harmonic
            return (
                AstryxTheme.shopifyMint,
                AstryxTheme.shopifyMint,
                AstryxTheme.shopifyMint
            )
        case .failed:
            // Coral Warning
            return (
                Color(hex: "#EF4444"),
                Color(hex: "#DC2626"),
                Color(hex: "#EF4444")
            )
        case .idle:
            // Sovereign Electric Mint (#36F4A4) & Sky Cyan (#38BDF8)
            return (
                AstryxTheme.shopifyMint,
                Color(hex: "#38BDF8"),
                AstryxTheme.shopifyMint
            )
        }
    }

    // MARK: - Menubar Status Bar Template Icon
    public static func createMenubarIcon(size: NSSize = NSSize(width: 18, height: 18)) -> NSImage {
        let img = NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

            let w = size.width
            let h = size.height

            let gridCols: CGFloat = 9.0
            let gridRows: CGFloat = 18.0

            let cellSize = min(w / (gridCols + 1.2), h / (gridRows + 0.6))
            let gridW = gridCols * cellSize
            let gridH = gridRows * cellSize

            let ox = (w - gridW) / 2.0 - (1.0 * cellSize)
            let oy = (h - gridH) / 2.0 - (1.0 * cellSize)

            let pixelGap = max(0.3, cellSize * 0.08)
            let cornerRadius = max(0.4, cellSize * 0.14)

            ctx.setFillColor(NSColor.black.cgColor)

            // Draw Rungs
            for r in Self.rungRows {
                for c in Self.rungCols {
                    let px = ox + CGFloat(c) * cellSize
                    let py = oy + CGFloat(r) * cellSize
                    let rRect = CGRect(
                        x: px + pixelGap / 2.0,
                        y: py + pixelGap / 2.0,
                        width: cellSize - pixelGap,
                        height: cellSize - pixelGap
                    )
                    let path = CGPath(roundedRect: rRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
                    ctx.addPath(path)
                    ctx.fillPath()
                }
            }

            // Draw Strands
            for (r, c) in Self.strandPixels {
                let px = ox + CGFloat(c) * cellSize
                let py = oy + CGFloat(r) * cellSize
                let pRect = CGRect(
                    x: px + pixelGap / 2.0,
                    y: py + pixelGap / 2.0,
                    width: cellSize - pixelGap,
                    height: cellSize - pixelGap
                )
                let path = CGPath(roundedRect: pRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
                ctx.addPath(path)
                ctx.fillPath()
            }

            return true
        }
        img.isTemplate = true
        return img
    }
}
