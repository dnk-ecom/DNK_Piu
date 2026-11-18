// --- DNK-MRH-HEADER ---
// mrh_id: "Sources/DNKPiu/DNAHelixView.swift"
// purpose: "Sovereign 7x11 Bold Minimal Cybernetic DNA Molecule with Swallow-Matched Dynamic Phase Colors & Red Idle Pulse."
// canonical_source: true
// status: "Active"
// version: "3.0.0"
// updated_at: "2026-11-18"
// author: "DNK-e.com Maksym & Antigravity"
// --- END DNK-MRH-HEADER ---

import AppKit
import Foundation
import PiuCore
import SwiftUI

/// High-performance, Metal-accelerated Minimal 7x11 Cybernetic DNA Molecule (Лаконічна цифрова ДНК).
/// Matches the iconic dynamic color lifecycle of the Swallow (Ластівка):
/// - Idle (Не диктуємо): Червона пульсуюча (#EF4444) — спокійне дихання люмінесценції (0.82...1.0) з червоним неоновим ореолом.
/// - Listening (Диктуємо / надиктовуємо): Інтенсивна червона акустична пульсація (#EF4444) з білим серцевинним спалахом під гучність мікрофона.
/// - Thinking (Транскрибуємо): Електричний синій (#3B82F6) з квантовим потоком біжучих даних.
/// - Done (Вставлено): Резонансний м'ятний спалах (#36F4A4).
/// - Failed: Кораловий тривожний строб.
public struct DNAHelixView: View {
    public let phase: DictationPhase
    public let audioLevel: Float
    public let size: CGFloat

    // Canonical 7x11 Minimal Pixel Grid (7 columns: 0...6, 11 rows: 0...10, center is 3)
    private static let strandPixels: [(row: Int, col: Int)] = [
        // Top loop & terminals
        (0, 0), (0, 1), (0, 5), (0, 6),
        (1, 1), (1, 5),
        (2, 2), (2, 4),
        // Node 1 (Center crossover)
        (3, 3),
        // Center diamond loop
        (4, 2), (4, 4),
        (5, 1), (5, 5),
        (6, 1), (6, 5),
        (7, 2), (7, 4),
        // Node 2 (Center crossover)
        (8, 3),
        // Bottom loop & terminals
        (9, 2), (9, 4),
        (10, 0), (10, 1), (10, 5), (10, 6),
    ]

    // Connecting horizontal base-pair rungs
    private static let rungPixels: [(row: Int, col: Int)] = [
        // Rung 1 (Top loop)
        (1, 2), (1, 3), (1, 4),
        // Center diamond rungs
        (4, 3),
        (5, 2), (5, 3), (5, 4),
        (6, 2), (6, 3), (6, 4),
        (7, 3),
        // Rung 4 (Bottom loop)
        (9, 3)
    ]

    public init(phase: DictationPhase = .idle, audioLevel: Float = 0.0, size: CGFloat = 18.0) {
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
                renderMinimalDNA(context: &context, size: canvasSize, time: t)
            }
        }
        .frame(width: size, height: size, alignment: .center)
    }

    // MARK: - Metal-Accelerated Minimal DNA Renderer
    private func renderMinimalDNA(context: inout GraphicsContext, size canvasSize: CGSize, time t: TimeInterval) {
        let w = canvasSize.width
        let h = canvasSize.height

        let gridCols: CGFloat = 7.0
        let gridRows: CGFloat = 11.0

        // Chunky pixel sizing with optimal margins
        let cellSize = min(w / (gridCols + 0.8), h / (gridRows + 0.6))
        let gridW = gridCols * cellSize
        let gridH = gridRows * cellSize

        // Absolute optical centering
        let ox = (w - gridW) / 2.0
        let oy = (h - gridH) / 2.0

        let pixelGap = max(0.4, cellSize * 0.08)
        let cornerRadius = max(0.6, cellSize * 0.16)

        let (strandBaseColor, rungBaseColor, glowColor) = phaseColors()

        // 1. Calculate breathing & pulse animation parameters
        let breathAlpha: Double = {
            switch phase {
            case .idle:
                // Red pulsating when not dictating (дихання люмінесценції)
                return 0.82 + 0.18 * sin(t * 3.2)
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

        // Mic volume boost for listening phase
        let volumeBoost: CGFloat = {
            if case .listening = phase {
                return CGFloat(min(1.0, max(0.0, audioLevel)))
            }
            return 0.0
        }()

        // Scale effect for voice pulse
        let dynamicScale: CGFloat = {
            if case .listening = phase {
                return 1.0 + volumeBoost * 0.12
            }
            return 1.0
        }()

        // Thinking quantum cascade row (cycles 0...10)
        let thinkingCascadeRow: Int = {
            if case .thinking = phase {
                return Int((t * 10.0).truncatingRemainder(dividingBy: 11.0))
            }
            return -1
        }()

        // 2. Ambient Glow Pass
        let glowRadius = min(w, h) * (phase == .idle ? 0.38 : (isListening ? 0.44 : 0.35))
        let glowRect = CGRect(
            x: (w - glowRadius * 2) / 2.0,
            y: (h - glowRadius * 2) / 2.0,
            width: glowRadius * 2,
            height: glowRadius * 2
        )
        context.fill(Path(ellipseIn: glowRect), with: .color(glowColor.opacity(0.22 * breathAlpha)))

        // Center transform for dynamic scale
        if dynamicScale != 1.0 {
            context.translateBy(x: w / 2.0, y: h / 2.0)
            context.scaleBy(x: dynamicScale, y: dynamicScale)
            context.translateBy(x: -w / 2.0, y: -h / 2.0)
        }

        // --- DRAW RUNGS (Horizontal Base Pairs) ---
        for (r, c) in Self.rungPixels {
            let isThinkingNear = abs(r - thinkingCascadeRow) <= 1

            let rungBrightness: Double = {
                if case .listening = phase {
                    return 0.90 + Double(volumeBoost) * 0.30
                } else if isThinkingNear {
                    return 1.0
                }
                return 0.85
            }()

            let rungColor: Color = {
                if isThinkingNear {
                    return Color.white
                } else if case .listening = phase {
                    return volumeBoost > 0.35 ? Color.white : rungBaseColor
                } else {
                    return rungBaseColor
                }
            }()

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

            // Specular glint
            let glintRect = CGRect(
                x: rect.minX + 0.3,
                y: rect.minY + 0.2,
                width: rect.width - 0.6,
                height: max(0.4, rect.height * 0.25)
            )
            context.fill(Path(glintRect), with: .color(Color.white.opacity(0.35)))
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

            let isThinkingActive = (r == thinkingCascadeRow)

            let pixelColor: Color = {
                if isThinkingActive {
                    return Color.white
                } else if case .listening = phase {
                    if volumeBoost > 0.4 && (r == 3 || r == 8) {
                        return Color.white // Crossover nodes ignite white on voice peaks
                    }
                    return strandBaseColor
                } else {
                    return strandBaseColor
                }
            }()

            let pixelAlpha = isThinkingActive ? 1.0 : breathAlpha

            let path = Path(roundedRect: rect, cornerRadius: cornerRadius)
            context.fill(path, with: .color(pixelColor.opacity(pixelAlpha)))

            // Specular glint on pixel top for chunky 3D cyber-chip texture
            let glintRect = CGRect(
                x: rect.minX + 0.3,
                y: rect.minY + 0.2,
                width: rect.width - 0.6,
                height: max(0.4, rect.height * 0.25)
            )
            context.fill(Path(glintRect), with: .color(Color.white.opacity(0.35)))
        }
    }

    // MARK: - Color Palette Matching the Swallow (Ластівка)
    private func phaseColors() -> (strand: Color, rung: Color, glow: Color) {
        switch phase {
        case .idle:
            // Червона пульсуюча коли не диктуємо (#EF4444)
            return (
                Color(hex: "#EF4444"),
                Color(hex: "#FECACA"),
                Color(hex: "#EF4444")
            )
        case .listening:
            // Інтенсивний червоний з білим еквалайзером при вимові (#EF4444)
            return (
                Color(hex: "#EF4444"),
                Color(hex: "#FCA5A5"),
                Color(hex: "#EF4444")
            )
        case .thinking:
            // Електричний синій (#3B82F6) як ширяюча ластівка
            return (
                Color(hex: "#3B82F6"),
                Color(hex: "#93C5FD"),
                Color(hex: "#3B82F6")
            )
        case .done:
            // Фірмовий електричний м'ятний (#36F4A4)
            return (
                AstryxTheme.shopifyMint,
                Color.white,
                AstryxTheme.shopifyMint
            )
        case .failed:
            // Кораловий тривожний
            return (
                Color(hex: "#EF4444"),
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

            let gridCols: CGFloat = 7.0
            let gridRows: CGFloat = 11.0

            let cellSize = min(w / (gridCols + 0.8), h / (gridRows + 0.6))
            let gridW = gridCols * cellSize
            let gridH = gridRows * cellSize

            let ox = (w - gridW) / 2.0
            let oy = (h - gridH) / 2.0

            let pixelGap = max(0.4, cellSize * 0.08)
            let cornerRadius = max(0.5, cellSize * 0.16)

            ctx.setFillColor(NSColor.black.cgColor)

            // Draw Rungs
            for (r, c) in Self.rungPixels {
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
