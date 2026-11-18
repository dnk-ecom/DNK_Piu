// --- DNK-MRH-HEADER ---
// mrh_id: "Sources/DNKPiu/DNAHelixView.swift"
// purpose: "Sovereign Solar Duotone Acoustic Microphone with Dynamic Lifecycle & Voice Pulse."
// canonical_source: true
// status: "Active"
// version: "7.0.0"
// updated_at: "2026-11-18"
// author: "DNK-e.com Maksym & Antigravity"
// --- END DNK-MRH-HEADER ---

import AppKit
import Foundation
import PiuCore
import SwiftUI

/// Sovereign Solar Duotone Acoustic Microphone (Іконка Мікрофону).
///
/// States:
/// - Idle (Не диктуємо): Червона пульсуюча (#EF4444) — м'яке спокійне дихання люмінесценції (0.84...1.0) з червоним неоновим ореолом.
/// - Listening (Диктуємо / надиктовуємо): Інтенсивна червона акустична пульсація під гучність мікрофона audioLevel. Капсула наповнюється енергією мови, випромінюючи концентричні звукові кільця.
/// - Thinking (Транскрибуємо через Gemini): Електричний кобальтовий синій (#3B82F6) з квантовим резонансом.
/// - Done (Вставлено): Резонансний м'ятний спалах (#36F4A4).
/// - Failed: Кораловий тривожний строб (#F87171).
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
                renderMicrophone(context: &context, size: canvasSize, time: t)
            }
        }
        .frame(width: size, height: size, alignment: .center)
    }

    // MARK: - Metal-Accelerated Microphone Renderer
    private func renderMicrophone(context: inout GraphicsContext, size canvasSize: CGSize, time t: TimeInterval) {
        let w = canvasSize.width
        let h = canvasSize.height
        
        // Exact mathematical centering within canvas (viewBox 0 0 24 24)
        let scale = (min(w, h) / 24.0) * 0.82
        let ox = (w - 24.0 * scale) / 2.0
        let oy = (h - 24.0 * scale) / 2.0

        let (baseColor, glowColor) = phaseColors()
        let level = CGFloat(max(0.0, min(1.0, audioLevel)))

        // 1. Idle Breathing vs Active Resonance
        let breathAlpha: CGFloat
        let breathScale: CGFloat
        if isListening {
            breathAlpha = 1.0
            breathScale = 1.0 + level * 0.06 + CGFloat(sin(t * 14.0)) * 0.02
        } else if case .thinking = phase {
            breathAlpha = 0.90 + CGFloat(sin(t * 8.0)) * 0.10
            breathScale = 1.0 + CGFloat(sin(t * 6.0)) * 0.03
        } else if case .done = phase {
            breathAlpha = 1.0
            breathScale = 1.06
        } else {
            // Idle: soft red breathing
            breathAlpha = 0.85 + CGFloat(sin(t * 2.2)) * 0.15
            breathScale = 1.0 + CGFloat(sin(t * 2.2)) * 0.02
        }

        // 2. Ambient Core Glow
        let micCenter = CGPoint(x: ox + 12.0 * scale, y: oy + 12.0 * scale)
        let glowRadius: CGFloat = (isListening ? 12.0 : 7.0) * scale * (1.0 + level * 0.3)
        let glowBounds = CGRect(x: micCenter.x - glowRadius, y: micCenter.y - glowRadius, width: glowRadius * 2, height: glowRadius * 2)
        context.fill(Path(ellipseIn: glowBounds), with: .color(glowColor.opacity(isListening ? 0.45 : 0.20)))

        // 3. Acoustic Sound Rings (Radiating when speaking)
        if isListening && level > 0.04 {
            let ringPhase = CGFloat(fmod(t * 2.5, 1.0))
            let r1 = (8.0 + ringPhase * 8.0) * scale
            let ring1Rect = CGRect(x: micCenter.x - r1, y: micCenter.y - (3.0 * scale) - r1, width: r1 * 2, height: r1 * 2)
            let ring1Alpha = Double(max(0.0, (1.0 - ringPhase) * (0.4 + level * 0.4)))
            context.stroke(Path(ellipseIn: ring1Rect), with: .color(glowColor.opacity(ring1Alpha)), lineWidth: 1.2 * scale)

            let r2Phase = CGFloat(fmod(t * 2.5 + 0.5, 1.0))
            let r2 = (8.0 + r2Phase * 8.0) * scale
            let ring2Rect = CGRect(x: micCenter.x - r2, y: micCenter.y - (3.0 * scale) - r2, width: r2 * 2, height: r2 * 2)
            let ring2Alpha = Double(max(0.0, (1.0 - r2Phase) * (0.4 + level * 0.4)))
            context.stroke(Path(ellipseIn: ring2Rect), with: .color(glowColor.opacity(ring2Alpha)), lineWidth: 1.0 * scale)
        }

        // 4. Draw Microphone Cradle & Capsule
        let micRect = CGRect(x: ox, y: oy, width: 24.0 * scale, height: 24.0 * scale)
        
        var micContext = context
        if breathScale != 1.0 {
            micContext.translateBy(x: micCenter.x, y: micCenter.y)
            micContext.scaleBy(x: breathScale, y: breathScale)
            micContext.translateBy(x: -micCenter.x, y: -micCenter.y)
        }

        // Draw Solid Cradle (Stand + U-bracket)
        if let cradleImg = VectorAssets.cradleImage {
            let tintedCradle = tintImage(cradleImg, color: NSColor(baseColor).withAlphaComponent(breathAlpha))
            micContext.draw(Image(nsImage: tintedCradle), in: micRect)
        }

        // Draw Duotone Capsule (Dynamic voice fill)
        let capsuleAlpha: CGFloat
        if isListening {
            capsuleAlpha = min(1.0, 0.50 + level * 0.50)
        } else if case .thinking = phase {
            capsuleAlpha = 0.50 + CGFloat(sin(t * 10.0)) * 0.30
        } else if case .done = phase {
            capsuleAlpha = 0.90
        } else {
            // Idle duotone
            capsuleAlpha = 0.45 * breathAlpha
        }

        if let capsuleImg = VectorAssets.capsuleImage {
            let tintedCapsule = tintImage(capsuleImg, color: NSColor(baseColor).withAlphaComponent(capsuleAlpha))
            micContext.draw(Image(nsImage: tintedCapsule), in: micRect)
        }
    }

    // MARK: - State Color Model (Swallow Dynamic Lifecycle)
    private func phaseColors() -> (base: Color, glow: Color) {
        switch phase {
        case .idle:
            // Swallow Idle Red Pulse
            return (
                base: Color(red: 239 / 255.0, green: 68 / 255.0, blue: 68 / 255.0),
                glow: Color(red: 239 / 255.0, green: 68 / 255.0, blue: 68 / 255.0).opacity(0.35)
            )
        case .listening:
            // Active Voice Red Spark
            return (
                base: Color(red: 239 / 255.0, green: 68 / 255.0, blue: 68 / 255.0),
                glow: Color(red: 254 / 255.0, green: 202 / 255.0, blue: 202 / 255.0).opacity(0.60)
            )
        case .thinking:
            // Electric Cobalt Blue
            return (
                base: Color(red: 59 / 255.0, green: 130 / 255.0, blue: 246 / 255.0),
                glow: Color(red: 6 / 255.0, green: 182 / 255.0, blue: 212 / 255.0).opacity(0.55)
            )
        case .done:
            // Electric Mint
            return (
                base: Color(red: 54 / 255.0, green: 244 / 255.0, blue: 164 / 255.0),
                glow: Color(red: 54 / 255.0, green: 244 / 255.0, blue: 164 / 255.0).opacity(0.60)
            )
        case .failed:
            // Coral Alarm
            return (
                base: Color(red: 248 / 255.0, green: 113 / 255.0, blue: 113 / 255.0),
                glow: Color(red: 239 / 255.0, green: 68 / 255.0, blue: 68 / 255.0).opacity(0.50)
            )
        }
    }

    // MARK: - Image Tinting Helper
    private func tintImage(_ img: NSImage, color: NSColor) -> NSImage {
        let size = img.size
        let tinted = NSImage(size: size)
        tinted.lockFocus()
        color.setFill()
        NSRect(origin: .zero, size: size).fill()
        img.draw(in: NSRect(origin: .zero, size: size), from: .zero, operation: .destinationIn, fraction: 1.0)
        tinted.unlockFocus()
        return tinted
    }

    // MARK: - Menubar Template Icon (18x18)
    public static func createMenubarIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let img = NSImage(size: size)
        img.lockFocus()

        let fullSVG = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
          <g fill="white">
            <path fill-opacity=".5" d="M8 6a4 4 0 0 1 8 0v5a4 4 0 0 1-8 0Z" />
            <path d="M6 10v1a6 6 0 1 0 12 0v-1a1 1 0 0 1 2 0v1a8.006 8.006 0 0 1-7 7.939V21a1 1 0 0 1-2 0v-2.061A8.006 8.006 0 0 1 4 11v-1a1 1 0 0 1 2 0" />
          </g>
        </svg>
        """

        if let data = fullSVG.data(using: .utf8), let svgImg = NSImage(data: data) {
            let s: CGFloat = 14.0
            let ox: CGFloat = (18.0 - s) / 2.0
            let oy: CGFloat = (18.0 - s) / 2.0
            svgImg.draw(in: NSRect(x: ox, y: oy, width: s, height: s))
        }

        img.unlockFocus()
        img.isTemplate = true
        return img
    }
}

// MARK: - Vector Assets Cache
private enum VectorAssets {
    static let capsuleImage: NSImage? = {
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
          <path d="M8 6a4 4 0 0 1 8 0v5a4 4 0 0 1-8 0Z" fill="white"/>
        </svg>
        """
        return NSImage(data: svg.data(using: .utf8)!)
    }()

    static let cradleImage: NSImage? = {
        let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
          <path d="M6 10v1a6 6 0 1 0 12 0v-1a1 1 0 0 1 2 0v1a8.006 8.006 0 0 1-7 7.939V21a1 1 0 0 1-2 0v-2.061A8.006 8.006 0 0 1 4 11v-1a1 1 0 0 1 2 0" fill="white"/>
        </svg>
        """
        return NSImage(data: svg.data(using: .utf8)!)
    }()
}
