import AppKit
import PiuCore
import SwiftUI

extension Color {
    init(hex: String) {
        let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch clean.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255.0,
            green: Double(g) / 255.0,
            blue: Double(b) / 255.0,
            opacity: Double(a) / 255.0
        )
    }
}

/// Floating pop-up pill panel placed at bottom center of the active screen (Wispr Flow / Superwhisper style).
final class DictationPillPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 220, height: 44),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.level = .statusBar
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.hidesOnDeactivate = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        self.contentView = NSHostingView(rootView: DictationPillContainerView())
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func updatePosition() {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) } ?? NSScreen.main ?? NSScreen.screens[0]
        let visible = screen.visibleFrame
        let size = CGSize(width: 220, height: 44)
        let x = visible.midX - (size.width / 2.0)
        let y = visible.minY + 24.0
        self.setFrame(NSRect(origin: NSPoint(x: x, y: y), size: size), display: true)
    }

    func showAnimated() {
        updatePosition()
        self.alphaValue = 0.0
        self.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.16
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().alphaValue = 1.0
        }
    }

    func hideAnimated() {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.18
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().alphaValue = 0.0
        }, completionHandler: {
            self.orderOut(nil)
        })
    }
}

/// Container that hosts the ultra-compact, professional floating capsule pill.
struct DictationPillContainerView: View {
    @ObservedObject private var dictation = AudioDictation.shared

    var body: some View {
        WisprFlowPillView()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .animation(.spring(response: 0.28, dampingFraction: 0.82), value: dictation.phase)
    }
}

/// Ultra-minimalist, Apple-grade floating dark glass capsule matching Wispr Flow & Superwhisper.
struct WisprFlowPillView: View {
    @ObservedObject private var dictation = AudioDictation.shared

    var body: some View {
        ZStack {
            // Obsidian Black Frosted Glass Capsule
            Capsule()
                .fill(Color(hex: "#0C0E14").opacity(0.94))

            // Thin Luxury Border
            Capsule()
                .strokeBorder(
                    isLocked
                        ? LinearGradient(colors: [Color(hex: "#F97316"), Color(hex: "#FB923C")], startPoint: .leading, endPoint: .trailing)
                        : (isThinking
                            ? LinearGradient(colors: [Color(hex: "#6366F1"), Color(hex: "#22D3EE")], startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: [Color.white.opacity(0.18), Color.white.opacity(0.08)], startPoint: .leading, endPoint: .trailing)),
                    lineWidth: isLocked ? 1.4 : 0.8
                )

            HStack(spacing: 8) {
                switch dictation.phase {
                case .listening(let locked):
                    if locked {
                        // Hands-Free Cancel (✕)
                        Button {
                            dictation.cancel()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 9.0, weight: .bold))
                                .foregroundColor(.white.opacity(0.7))
                                .frame(width: 18, height: 18)
                                .background(Circle().fill(Color.white.opacity(0.10)))
                        }
                        .buttonStyle(.plain)
                    } else {
                        // Pulsating Minimal Recording Dot
                        Circle()
                            .fill(Color(hex: "#FF3B30"))
                            .frame(width: 6, height: 6)
                            .shadow(color: Color(hex: "#FF3B30").opacity(0.7), radius: 3)
                    }

                    // 7 Dynamic Audio Waveform Bars
                    SevenWaveBarsView(levels: dictation.audioLevels, isThinking: false)

                    if locked {
                        // Hands-Free Finish (✓)
                        Button {
                            dictation.stopAndTranscribe()
                        } label: {
                            Image(systemName: "checkmark")
                                .font(.system(size: 9.0, weight: .heavy))
                                .foregroundColor(.black)
                                .frame(width: 18, height: 18)
                                .background(Circle().fill(Color(hex: "#10B981")))
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text("⌥")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white.opacity(0.40))
                    }

                case .thinking:
                    // Elegant Wave Shimmer during Gemini 3.5 Flash Lite transcription
                    SevenWaveBarsView(levels: dictation.audioLevels, isThinking: true)

                    Text("⚡ ...")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(hex: "#22D3EE"))

                case .done(_, let wasPasted):
                    Image(systemName: wasPasted ? "checkmark" : "doc.on.clipboard")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundColor(Color(hex: wasPasted ? "#10B981" : "#F59E0B"))

                    Text(wasPasted ? "Вставлено" : "Скопійовано (⌘V)")
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                case .failed(let err):
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundColor(Color(hex: "#EF4444"))

                    Text(err.count > 16 ? "\(err.prefix(16))..." : err)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))

                case .idle:
                    EmptyView()
                }
            }
            .padding(.horizontal, isLocked ? 8 : 12)
        }
        .frame(width: pillWidth, height: 32)
        .shadow(color: Color.black.opacity(0.38), radius: 10, y: 3)
    }

    private var isLocked: Bool {
        if case .listening(let locked) = dictation.phase { return locked }
        return false
    }

    private var isThinking: Bool {
        if case .thinking = dictation.phase { return true }
        return false
    }

    private var pillWidth: CGFloat {
        switch dictation.phase {
        case .listening(let locked): return locked ? 154 : 124
        case .thinking: return 120
        case .done(_, let wasPasted): return wasPasted ? 116 : 158
        case .failed: return 130
        case .idle: return 60
        }
    }
}

/// 7 sleek vertical audio bars responding to real microphone power and breathing rhythm.
struct SevenWaveBarsView: View {
    let levels: [Float]
    let isThinking: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 2.8) {
                ForEach(0..<7, id: \.self) { i in
                    let height: CGFloat = {
                        if isThinking {
                            // Gentle sine-wave breathing wave during processing
                            let waveVal: Double = sin(t * 6.5 - Double(i) * 0.65)
                            let wave: Double = max(0.08, waveVal)
                            return CGFloat(3.5 + 11.0 * wave)
                        } else {
                            let level = levels.indices.contains(i) ? CGFloat(levels[i]) : 0.1
                            return max(3.5, min(16.0, 3.5 + 12.5 * level))
                        }
                    }()

                    Capsule()
                        .fill(
                            isThinking
                                ? Color(hex: "#818CF8").opacity(0.95)
                                : Color.white.opacity(0.92)
                        )
                        .frame(width: 2.8, height: height)
                }
            }
            .frame(height: 18)
        }
    }
}
