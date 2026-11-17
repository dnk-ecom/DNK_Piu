import AppKit
import PiuCore
import SwiftUI

/// Floating pop-up pill panel placed at bottom center of the active screen (Coucou FlowPill).
final class DictationPillPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 90),
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
        let size = CGSize(width: 340, height: 90)
        let x = visible.midX - (size.width / 2.0)
        let y = visible.minY + 24.0
        self.setFrame(NSRect(origin: NSPoint(x: x, y: y), size: size), display: true)
    }

    func showAnimated() {
        updatePosition()
        self.alphaValue = 0.0
        self.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.20
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().alphaValue = 1.0
        }
    }

    func hideAnimated() {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.24
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().alphaValue = 0.0
        }, completionHandler: {
            self.orderOut(nil)
        })
    }
}

/// Container that hosts both the floating speech bubble and the bottom capsule pill.
struct DictationPillContainerView: View {
    @ObservedObject private var dictation = AudioDictation.shared

    var body: some View {
        VStack(spacing: 6) {
            // Speech Bubble / Announcement above the pill
            if case .done(let text) = dictation.phase, !text.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(hex: "#10B981"))
                        .font(.system(size: 11, weight: .bold))

                    Text(text.count > 36 ? "\(text.prefix(36))..." : text)
                        .font(.system(size: 11.5, weight: .medium, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.95))
                        .lineLimit(1)

                    Text("Вставлено")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(Color(hex: "#10B981"))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color(hex: "#10B981").opacity(0.18))
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color(hex: "#0A0B0E").opacity(0.96))
                        .shadow(color: Color.black.opacity(0.4), radius: 8, y: 3)
                )
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                )
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            } else if case .failed(let err) = dictation.phase {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(Color(hex: "#F59E0B"))
                        .font(.system(size: 11, weight: .bold))
                    Text(err)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color(hex: "#0A0B0E").opacity(0.96)))
                .overlay(Capsule().strokeBorder(Color(hex: "#F59E0B").opacity(0.4), lineWidth: 1))
            }

            // Bottom Jet-Black Capsule Pill (Coucou FlowPill)
            CoucouFlowPillView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: dictation.phase)
    }
}

/// The sleek jet-black pill with 9 dancing audio dots, matching Coucou v0.6.0.
struct CoucouFlowPillView: View {
    @ObservedObject private var dictation = AudioDictation.shared

    var body: some View {
        ZStack {
            // Coucou Jet Black Capsule Background
            Capsule()
                .fill(Color(hex: "#0A0B0E").opacity(0.96))

            // Thin Frosted Border
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: isThinking
                            ? [Color(hex: "#C084FC"), Color(hex: "#22D3EE")]
                            : [Color.white.opacity(0.20), Color.white.opacity(0.12)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 1.0
                )

            HStack(spacing: 8) {
                switch dictation.phase {
                case .listening(let isLocked):
                    if isLocked {
                        Button {
                            dictation.cancel()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 9.5, weight: .heavy))
                                .foregroundColor(.white.opacity(0.7))
                                .frame(width: 20, height: 20)
                                .background(Circle().fill(Color.white.opacity(0.12)))
                        }
                        .buttonStyle(.plain)
                    } else {
                        // Glowing Gemini AI Star
                        Image(systemName: "sparkle")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Color(hex: "#22D3EE"))
                            .shadow(color: Color(hex: "#22D3EE").opacity(0.7), radius: 3)
                    }

                    // 9 Coucou Dancing Dots
                    CoucouNineDotsView(levels: dictation.audioLevels, isThinking: false)

                    if isLocked {
                        Button {
                            dictation.stopAndTranscribe()
                        } label: {
                            Image(systemName: "checkmark")
                                .font(.system(size: 9.5, weight: .heavy))
                                .foregroundColor(.black)
                                .frame(width: 20, height: 20)
                                .background(Circle().fill(Color(hex: "#10B981")))
                        }
                        .buttonStyle(.plain)
                    }

                case .thinking:
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(hex: "#C084FC"))

                    // 9 Ripple Dots during Gemini 3.8 Flash transcription
                    CoucouNineDotsView(levels: dictation.audioLevels, isThinking: true)

                case .done:
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(hex: "#10B981"))

                    Text("Готово")
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)

                case .failed:
                    Image(systemName: "mic.slash.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: "#F59E0B"))

                    Text("Помилка")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))

                case .idle:
                    EmptyView()
                }
            }
            .padding(.horizontal, 14)
        }
        .frame(width: pillWidth, height: 34)
        .shadow(color: Color.black.opacity(0.45), radius: 12, y: 4)
    }

    private var isThinking: Bool {
        if case .thinking = dictation.phase { return true }
        return false
    }

    private var pillWidth: CGFloat {
        switch dictation.phase {
        case .listening(let isLocked): return isLocked ? 168 : 138
        case .thinking: return 128
        case .done: return 110
        case .failed: return 110
        case .idle: return 80
        }
    }
}

/// Exactly 9 dots rising and falling with voice audio bands (Coucou FlowBands).
struct CoucouNineDotsView: View {
    let levels: [Float]
    let isThinking: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 3.2) {
                ForEach(0..<9, id: \.self) { i in
                    let height: CGFloat = {
                        if isThinking {
                            // Coucou sine-wave wave equation: 0.10 + 0.22 * sin(...)
                            let wave = max(0.0, sin(t * 7.5 - Double(i) * 0.75))
                            return 3.4 + 14.0 * CGFloat(wave)
                        } else {
                            let level = levels.indices.contains(i) ? CGFloat(levels[i]) : 0.1
                            return max(3.4, min(18.0, 3.4 + 14.6 * level))
                        }
                    }()

                    Capsule()
                        .fill(
                            isThinking
                                ? Color(hex: "#C084FC").opacity(0.95)
                                : Color.white.opacity(0.94)
                        )
                        .frame(width: 3.4, height: height)
                }
            }
            .frame(height: 20)
        }
    }
}
