import AppKit
import PiuCore
import SwiftUI

/// Floating pop-up pill panel placed at bottom center of the active screen (Wispr Flow / Superwhisper style).
final class DictationPillPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 260, height: 44),
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
        let size = CGSize(width: 260, height: 44)
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

/// Ultra-minimalist, Apple-grade floating dark glass capsule matching Astryx OS tokens.
struct WisprFlowPillView: View {
    @ObservedObject private var dictation = AudioDictation.shared
    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        ZStack {
            // Astryx Canvas Surface with Frosted Glass Opacity
            Capsule()
                .fill(AstryxTheme.canvas.opacity(0.96))

            // Thin Luxury 0.8px Border (Passive 0.08 / Active Astryx Gradients)
            Capsule()
                .strokeBorder(
                    borderGradient,
                    lineWidth: isLocked ? 1.2 : AstryxTheme.borderWidth
                )

            HStack(spacing: 7) {
                // Leading Swallow Bird Badge (Ластівка - Astryx Identity)
                Image(systemName: "swift")
                    .font(.system(size: 11.0, weight: .bold))
                    .foregroundStyle(AstryxTheme.swallowGradient)
                    .scaleEffect(x: -1, y: 1)
                    .opacity(0.95)

                switch dictation.phase {
                case .listening(let locked):
                    if locked {
                        // Hands-Free Cancel (✕)
                        Button {
                            dictation.cancel()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 8.5, weight: .bold))
                                .foregroundColor(.white.opacity(0.7))
                                .frame(width: 17, height: 17)
                                .background(Circle().fill(Color.white.opacity(0.12)))
                        }
                        .buttonStyle(.plain)
                    } else {
                        // Pulsating Minimal Recording Dot
                        Circle()
                            .fill(AstryxTheme.red)
                            .frame(width: 6, height: 6)
                            .shadow(color: AstryxTheme.red.opacity(0.8), radius: 3)
                    }

                    // 7 Dynamic Audio Waveform Bars
                    SevenWaveBarsView(levels: dictation.audioLevels, isThinking: false)

                    if locked {
                        // Hands-Free Finish (✓)
                        Button {
                            dictation.stopAndTranscribe()
                        } label: {
                            Image(systemName: "checkmark")
                                .font(.system(size: 8.5, weight: .heavy))
                                .foregroundColor(AstryxTheme.canvas)
                                .frame(width: 17, height: 17)
                                .background(Circle().fill(AstryxTheme.emerald))
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text("⌥")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white.opacity(0.35))
                    }

                case .thinking:
                    // Minimalist Flash Indicator (⚡)
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(AstryxTheme.thinkingGradient)
                        .opacity(0.95)

                    // 7 Dynamic Breathing Wave Bars with Gradient Illumination (Cyan/Purple)
                    SevenWaveBarsView(levels: dictation.audioLevels, isThinking: true)

                case .done(_, let wasPasted):
                    Image(systemName: wasPasted ? "checkmark" : "doc.on.clipboard")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundColor(wasPasted ? AstryxTheme.emerald : AstryxTheme.amber)

                    Text(wasPasted ? "Вставлено" : "Скопійовано")
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                case .failed(let err):
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundColor(AstryxTheme.red)

                    Text(err.count > 16 ? "\(err.prefix(16))..." : err)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))

                case .idle:
                    EmptyView()
                }
            }
            .padding(.horizontal, isLocked ? 8 : 10)
        }
        .frame(width: pillWidth, height: 32)
        .shadow(color: Color.black.opacity(0.50), radius: 12, y: 4)
    }

    private var isLocked: Bool {
        if case .listening(let locked) = dictation.phase { return locked }
        return false
    }

    private var borderGradient: AnyShapeStyle {
        switch dictation.phase {
        case .listening(let locked):
            if locked {
                return AnyShapeStyle(LinearGradient(
                    colors: [AstryxTheme.amber, Color(hex: "#FB923C")],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
            } else {
                return AnyShapeStyle(AstryxTheme.activeGradient)
            }
        case .thinking:
            return AnyShapeStyle(AstryxTheme.thinkingGradient)
        case .done(_, let wasPasted):
            return AnyShapeStyle(LinearGradient(
                colors: [wasPasted ? AstryxTheme.emerald : AstryxTheme.amber, Color.white.opacity(0.2)],
                startPoint: .leading,
                endPoint: .trailing
            ))
        case .failed:
            return AnyShapeStyle(LinearGradient(
                colors: [AstryxTheme.red, Color.white.opacity(0.1)],
                startPoint: .leading,
                endPoint: .trailing
            ))
        case .idle:
            return AnyShapeStyle(AstryxTheme.borderSubtle)
        }
    }

    private var pillWidth: CGFloat {
        switch dictation.phase {
        case .listening(let locked): return locked ? 168 : 136
        case .thinking: return 106
        case .done(_, let wasPasted): return wasPasted ? 142 : 160
        case .failed: return 146
        case .idle: return 60
        }
    }
}

/// 7 sleek vertical audio bars responding to real microphone power and breathing rhythm.
struct SevenWaveBarsView: View {
    let levels: [Float]
    let isThinking: Bool
    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 2.8) {
                ForEach(0..<7, id: \.self) { i in
                    let height: CGFloat = {
                        if isThinking {
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
                                ? AnyShapeStyle(barThinkingGradient(for: i))
                                : AnyShapeStyle(Color.white.opacity(0.92))
                        )
                        .frame(width: 2.8, height: height)
                        .shadow(
                            color: isThinking ? AstryxTheme.cyan.opacity(0.35) : .clear,
                            radius: isThinking ? 2.5 : 0
                        )
                }
            }
            .frame(height: 18)
        }
    }

    private func barThinkingGradient(for index: Int) -> LinearGradient {
        let ratio = Double(index) / 6.0
        return LinearGradient(
            colors: [
                AstryxTheme.cyan.opacity(1.0 - ratio * 0.25),
                AstryxTheme.purple.opacity(0.75 + ratio * 0.25)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
