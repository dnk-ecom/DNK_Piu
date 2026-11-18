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

/// Dynamic Swallow Bird icon (Ластівка) with state micro-transformations.
/// - Listening: Red (#EF4444) + breathing/pulsing with microphone audio level.
/// - Thinking: Blue (#3B82F6) + gentle wing hovering / flight animation.
/// - Done: Mint (#36F4A4) + subtle spring pop.
struct SwallowIconView: View {
    let phase: DictationPhase
    let audioLevel: Float

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let color = swallowColor
            let (scale, angle, yOffset) = animationParameters(t: t)

            ZStack(alignment: .center) {
                Image(systemName: "swift")
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundColor(color)
                    .scaleEffect(x: -1.0 * scale, y: scale) // Mirrored flight direction + dynamic scale
                    .rotationEffect(.degrees(angle))
                    .offset(y: yOffset + 0.8) // Micro optical vertical centering compensation
                    .shadow(color: color.opacity(glowOpacity), radius: glowRadius)
            }
            .frame(width: 18, height: 18, alignment: .center)
        }
        .frame(width: 18, height: 18, alignment: .center)
    }

    private var swallowColor: Color {
        switch phase {
        case .listening:
            return Color(hex: "#EF4444")
        case .thinking:
            return Color(hex: "#3B82F6")
        case .done:
            return AstryxTheme.shopifyMint
        case .failed:
            return Color(hex: "#EF4444")
        case .idle:
            return AstryxTheme.shopifyMint
        }
    }

    private var glowOpacity: Double {
        switch phase {
        case .listening: return 0.75
        case .thinking: return 0.70
        case .done: return 0.55
        case .failed: return 0.60
        case .idle: return 0.0
        }
    }

    private var glowRadius: CGFloat {
        switch phase {
        case .listening: return 4.5
        case .thinking: return 3.5
        case .done: return 3.0
        default: return 0.0
        }
    }

    private func animationParameters(t: TimeInterval) -> (scale: CGFloat, angle: Double, yOffset: CGFloat) {
        switch phase {
        case .listening:
            // Dynamic mic volume pulse + gentle biological breathing
            let pulse = CGFloat(max(0.0, min(1.0, audioLevel)))
            let breath = CGFloat(sin(t * 7.0) * 0.04)
            let s = 1.0 + (pulse * 0.22) + breath
            return (scale: s, angle: 0.0, yOffset: 0.0)

        case .thinking:
            // Graceful flight / wing hovering micro-animation
            let angle = sin(t * 5.0) * 6.5
            let hover = sin(t * 4.0) * 1.5
            return (scale: 1.04, angle: angle, yOffset: hover)

        case .done:
            return (scale: 1.08, angle: 0.0, yOffset: 0.0)

        case .failed:
            let jitter = sin(t * 22.0) * 2.0
            return (scale: 1.0, angle: jitter, yOffset: 0.0)

        case .idle:
            return (scale: 1.0, angle: 0.0, yOffset: 0.0)
        }
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

            // Thin Luxury 0.8px Border
            Capsule()
                .strokeBorder(
                    borderGradient,
                    lineWidth: isLocked ? 1.2 : AstryxTheme.borderWidth
                )

            HStack(alignment: .center, spacing: 7) {
                // Leading Swallow Bird with Micro-Transformations (Red when listening, Blue when thinking)
                SwallowIconView(
                    phase: dictation.phase,
                    audioLevel: dictation.audioLevels.max() ?? 0.05
                )
                .frame(width: 18, height: 18, alignment: .center)

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
                                .frame(width: 17, height: 17, alignment: .center)
                                .background(Circle().fill(Color.white.opacity(0.12)))
                        }
                        .buttonStyle(.plain)
                    }

                    // 7 Dynamic Audio Waveform Bars
                    SevenWaveBarsView(levels: dictation.audioLevels, isThinking: false)
                        .frame(height: 18, alignment: .center)

                    if locked {
                        // Hands-Free Finish (✓)
                        Button {
                            dictation.stopAndTranscribe()
                        } label: {
                            Image(systemName: "checkmark")
                                .font(.system(size: 8.5, weight: .heavy))
                                .foregroundColor(AstryxTheme.canvas)
                                .frame(width: 17, height: 17, alignment: .center)
                                .background(Circle().fill(AstryxTheme.emerald))
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text("⌥")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white.opacity(0.35))
                            .frame(height: 18, alignment: .center)
                    }

                case .thinking:
                    // Ultra-laconic: Blue Swallow + 7 Blue Wave Bars
                    SevenWaveBarsView(levels: dictation.audioLevels, isThinking: true)
                        .frame(height: 18, alignment: .center)

                case .done(_, let wasPasted):
                    Text(wasPasted ? "Вставлено" : "Скопійовано")
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(height: 18, alignment: .center)

                case .failed(let err):
                    Text(err.count > 16 ? "\(err.prefix(16))..." : err)
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(height: 18, alignment: .center)

                case .idle:
                    EmptyView()
                }
            }
            .frame(height: 18, alignment: .center)
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
                return AnyShapeStyle(LinearGradient(
                    colors: [Color(hex: "#EF4444").opacity(0.60), Color(hex: "#EF4444").opacity(0.25)],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
            }
        case .thinking:
            return AnyShapeStyle(LinearGradient(
                colors: [Color(hex: "#3B82F6").opacity(0.75), Color(hex: "#60A5FA").opacity(0.35)],
                startPoint: .leading,
                endPoint: .trailing
            ))
        case .done(_, let wasPasted):
            return AnyShapeStyle(LinearGradient(
                colors: [wasPasted ? AstryxTheme.shopifyMint.opacity(0.70) : AstryxTheme.amber, Color.white.opacity(0.2)],
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
        case .listening(let locked): return locked ? 152 : 116
        case .thinking: return 80
        case .done(_, let wasPasted): return wasPasted ? 124 : 138
        case .failed: return 130
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
                            color: isThinking ? Color(hex: "#3B82F6").opacity(0.40) : .clear,
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
                Color(hex: "#3B82F6").opacity(1.0 - ratio * 0.20),
                Color(hex: "#60A5FA").opacity(0.80 + ratio * 0.20)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
