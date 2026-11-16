import AppKit
import PiuCore
import SwiftUI

/// Floating, non-activating pop-up pill panel placed at the bottom center of the active screen.
final class DictationPillPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 48),
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
        self.contentView = NSHostingView(rootView: DictationPillView())
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func updatePosition() {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) } ?? NSScreen.main ?? NSScreen.screens[0]
        let visible = screen.visibleFrame
        let size = CGSize(width: 280, height: 48)
        let x = visible.midX - (size.width / 2.0)
        let y = visible.minY + 28.0
        self.setFrame(NSRect(origin: NSPoint(x: x, y: y), size: size), display: true)
    }

    func showAnimated() {
        updatePosition()
        self.alphaValue = 0.0
        self.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().alphaValue = 1.0
        }
    }

    func hideAnimated() {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().alphaValue = 0.0
        }, completionHandler: {
            self.orderOut(nil)
        })
    }
}

/// Dynamic soundwave visualizer responding to microphone volume levels.
struct WaveformBarsView: View {
    let levels: [Float]
    let isThinking: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 3.2) {
                ForEach(0..<levels.count, id: \.self) { i in
                    let height: CGFloat = {
                        if isThinking {
                            // Organic wave ripple when transcribing with Gemini
                            let wave = max(0.15, sin(t * 8.0 - Double(i) * 0.75))
                            return 4.0 + 18.0 * CGFloat(wave)
                        } else {
                            let level = levels.indices.contains(i) ? levels[i] : 0.15
                            return max(4.0, min(24.0, CGFloat(level) * 22.0))
                        }
                    }()

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: isThinking ? [Color(hex: "#C084FC"), Color(hex: "#67E8F9")] : [Color.white, Color(hex: "#A855F7")],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(width: 3.2, height: height)
                }
            }
            .frame(height: 26)
        }
    }
}

/// The pop-up dictation pill UI view matching Coucou's FlowPill design.
struct DictationPillView: View {
    @ObservedObject private var dictation = AudioDictation.shared

    var body: some View {
        ZStack {
            // Frosted dark pill capsule
            Capsule()
                .fill(Color(red: 0.07, green: 0.07, blue: 0.10).opacity(0.92))
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [Color(hex: "#A855F7").opacity(0.8), Color(hex: "#06B6D4").opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 1.2
                )

            HStack(spacing: 10) {
                switch dictation.phase {
                case .listening(let isLocked):
                    if isLocked {
                        Button {
                            dictation.cancel()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white.opacity(0.7))
                                .frame(width: 22, height: 22)
                                .background(Circle().fill(Color.white.opacity(0.12)))
                        }
                        .buttonStyle(.plain)
                    } else {
                        Circle()
                            .fill(Color(hex: "#EF4444"))
                            .frame(width: 8, height: 8)
                            .shadow(color: Color(hex: "#EF4444").opacity(0.8), radius: 4)
                    }

                    WaveformBarsView(levels: dictation.audioLevels, isThinking: false)

                    Text(isLocked ? "Hands-free" : "Слухаю...")
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.95))

                    if isLocked {
                        Button {
                            dictation.stopAndTranscribe()
                        } label: {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.black)
                                .frame(width: 22, height: 22)
                                .background(Circle().fill(Color(hex: "#10B981")))
                        }
                        .buttonStyle(.plain)
                    }

                case .thinking:
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(hex: "#C084FC"))

                    WaveformBarsView(levels: dictation.audioLevels, isThinking: true)

                    Text("Розпізнаю (Gemini 3.8)...")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.92))

                case .done(let text):
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Color(hex: "#10B981"))

                    Text("Вставлено!")
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .foregroundColor(Color.white)

                    if !text.isEmpty {
                        Text("(\(text.prefix(20))...)")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(Color.white.opacity(0.6))
                            .lineLimit(1)
                    }

                case .failed(let msg):
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(hex: "#F59E0B"))

                    Text(msg)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.85))
                        .lineLimit(1)

                case .idle:
                    EmptyView()
                }
            }
            .padding(.horizontal, 14)
        }
        .frame(width: 270, height: 44)
        .shadow(color: Color.black.opacity(0.4), radius: 10, y: 4)
    }
}
