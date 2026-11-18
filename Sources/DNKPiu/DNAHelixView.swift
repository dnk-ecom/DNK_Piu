// --- DNK-MRH-HEADER ---
// mrh_id: "Sources/DNKPiu/DNAHelixView.swift"
// purpose: "Sovereign Solar Duotone Acoustic Microphone (Zero Background, Pure Central Capsule Pulse) with Swallow Dynamic Lifecycle."
// canonical_source: true
// status: "Active"
// version: "7.1.0"
// updated_at: "2026-11-18"
// author: "DNK-e.com Maksym & Antigravity"
// --- END DNK-MRH-HEADER ---

import AppKit
import Foundation
import PiuCore
import SwiftUI

/// Sovereign Solar Duotone Acoustic Microphone (Чистий мікрофон без фону, пульсує лише центральна пігулка).
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

    // MARK: - Metal-Accelerated Pure Microphone Renderer (Zero Background)
    private func renderMicrophone(context: inout GraphicsContext, size canvasSize: CGSize, time t: TimeInterval) {
        let w = canvasSize.width
        let h = canvasSize.height
        
        // Exact mathematical centering within canvas (viewBox 0 0 24 24)
        let scale = (min(w, h) / 24.0) * 0.90
        let ox = (w - 24.0 * scale) / 2.0
        let oy = (h - 24.0 * scale) / 2.0

        let (baseColor, _) = phaseColors()
        let level = CGFloat(max(0.0, min(1.0, audioLevel)))

        let micRect = CGRect(x: ox, y: oy, width: 24.0 * scale, height: 24.0 * scale)

        // 1. Draw Steady Cradle (Stand + U-bracket) — Always solid, zero jitter, zero background
        if let cradleImg = VectorAssets.cradleImage {
            let tintedCradle = tintImage(cradleImg, color: NSColor(baseColor))
            context.draw(Image(nsImage: tintedCradle), in: micRect)
        }

        // 2. Draw Pulsing Central Capsule (Лише центральна пігулка пульсує)
        // Center of capsule in viewBox: cx = 12.0, cy = 8.5
        let capCenter = CGPoint(x: ox + 12.0 * scale, y: oy + 8.5 * scale)

        let capScaleX: CGFloat
        let capScaleY: CGFloat
        let capAlpha: CGFloat
        let capColor: Color

        if isListening {
            // Active Speech Modulation: Central capsule pulses and breathes to voice energy
            let pulse = CGFloat(sin(t * 14.0))
            capScaleY = 1.0 + level * 0.28 + pulse * 0.05
            capScaleX = 1.0 + level * 0.16 + pulse * 0.03
            capAlpha = CGFloat(min(1.0, 0.60 + level * 0.40 + Double(pulse) * 0.08))
            // Capsule glows with fiery bright red during loud speech
            capColor = Color(
                red: 254 / 255.0,
                green: min(1.0, (68.0 + level * 90.0) / 255.0),
                blue: min(1.0, (68.0 + level * 90.0) / 255.0)
            )
        } else if case .thinking = phase {
            let thinkPulse = CGFloat(sin(t * 10.0))
            capScaleY = 1.0 + thinkPulse * 0.08
            capScaleX = 1.0 + thinkPulse * 0.04
            capAlpha = CGFloat(0.55 + Double(thinkPulse) * 0.25)
            capColor = baseColor
        } else if case .done = phase {
            capScaleY = 1.06
            capScaleX = 1.06
            capAlpha = 1.0
            capColor = baseColor
        } else {
            // Idle: soft gentle breathing
            let idlePulse = CGFloat(sin(t * 2.2))
            capScaleY = 1.0 + idlePulse * 0.04
            capScaleX = 1.0 + idlePulse * 0.02
            capAlpha = CGFloat(0.50 + Double(idlePulse) * 0.15)
            capColor = baseColor
        }

        var capContext = context
        capContext.translateBy(x: capCenter.x, y: capCenter.y)
        capContext.scaleBy(x: capScaleX, y: capScaleY)
        capContext.translateBy(x: -capCenter.x, y: -capCenter.y)

        if let capsuleImg = VectorAssets.capsuleImage {
            let tintedCapsule = tintImage(capsuleImg, color: NSColor(capColor).withAlphaComponent(capAlpha))
            capContext.draw(Image(nsImage: tintedCapsule), in: micRect)
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
