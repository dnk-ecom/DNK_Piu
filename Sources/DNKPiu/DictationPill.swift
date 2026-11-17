import AppKit
import PiuCore
import SwiftUI

/// Floating pop-up pill panel placed at bottom center of the active screen (Coucou FlowPill).
final class DictationPillPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 160),
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
        let size = CGSize(width: 520, height: 160)
        let x = visible.midX - (size.width / 2.0)
        let y = visible.minY + 12.0
        self.setFrame(NSRect(origin: NSPoint(x: x, y: y), size: size), display: true)
    }

    func showAnimated() {
        updatePosition()
        self.alphaValue = 0.0
        self.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().alphaValue = 1.0
        }
    }

    func hideAnimated() {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().alphaValue = 0.0
        }, completionHandler: {
            self.orderOut(nil)
        })
    }
}

/// Container that hosts both the floating speech bubble card and the bottom capsule pill.
struct DictationPillContainerView: View {
    @ObservedObject private var dictation = AudioDictation.shared

    var body: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 0)

            // 1. Coucou Quote Card / Announcement above the pill
            if case .done(let text, let wasPasted) = dictation.phase, !text.isEmpty {
                FlowQuoteCardView(text: text, wasPasted: wasPasted)
            } else if case .failed(let err) = dictation.phase {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(Color(hex: "#EF4444"))
                        .font(.system(size: 11, weight: .bold))
                    Text(err)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color(hex: "#0A0B0E").opacity(0.96)))
                .overlay(Capsule().strokeBorder(Color(hex: "#EF4444").opacity(0.4), lineWidth: 1))
            }

            // 2. Bottom Jet-Black Capsule Pill (Coucou FlowPill)
            CoucouFlowPillView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .animation(.spring(response: 0.34, dampingFraction: 0.78), value: dictation.phase)
    }
}

/// Rich quote card displayed right above the pill with action buttons (Wispr Flow / Coucou style).
struct FlowQuoteCardView: View {
    let text: String
    let wasPasted: Bool
    @ObservedObject var dictation = AudioDictation.shared
    @LocalState private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: wasPasted ? "checkmark.circle.fill" : "doc.on.clipboard.fill")
                    .foregroundColor(Color(hex: wasPasted ? "#10B981" : "#F59E0B"))
                    .font(.system(size: 12, weight: .bold))

                Text(wasPasted ? "Текст успішно вставлено" : "Скопійовано в буфер обміну")
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "#F5F6F8"))

                Spacer()

                Button {
                    dictation.dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.6))
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(Color.white.opacity(0.10)))
                }
                .buttonStyle(.plain)
            }

            // Transcribed text preview (multi-line up to 3 lines)
            Text("\"\(text)\"")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color.white.opacity(0.92))
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Spacer()

                // Copy Button
                Button {
                    FlowPaste.copyToClipboard(text)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 9.5, weight: .bold))
                        Text(copied ? "Скопійовано!" : "Скопіювати")
                            .font(.system(size: 10.5, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                // Paste Again Button (forces immediate ⌘V into the target app)
                Button {
                    FlowPaste.insert(text, into: dictation.targetApp)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right.doc.on.clipboard")
                            .font(.system(size: 9.5, weight: .bold))
                        Text("Вставити (⌘V)")
                            .font(.system(size: 10.5, weight: .bold))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(hex: "#22D3EE"))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .frame(maxWidth: 380)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(hex: "#0A0B0E").opacity(0.96))
                .shadow(color: Color.black.opacity(0.5), radius: 14, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
        )
        .transition(.scale(scale: 0.85, anchor: .bottom).combined(with: .opacity))
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

            // Thin Frosted Border (Glowing Amber in Hands-Free mode, Gradient in Thinking)
            Capsule()
                .strokeBorder(
                    isLocked
                        ? LinearGradient(colors: [Color(hex: "#F97316"), Color(hex: "#FB923C")], startPoint: .leading, endPoint: .trailing)
                        : (isThinking
                            ? LinearGradient(colors: [Color(hex: "#C084FC"), Color(hex: "#22D3EE")], startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: [Color.white.opacity(0.22), Color.white.opacity(0.12)], startPoint: .leading, endPoint: .trailing)),
                    lineWidth: isLocked ? 1.5 : 1.0
                )

            HStack(spacing: 8) {
                switch dictation.phase {
                case .listening(let locked):
                    if locked {
                        // ✕ Cancel button in Hands-Free
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
                        .help("Скасувати запис")
                    } else {
                        // Glowing Gemini Star Mascot
                        HStack(spacing: 3) {
                            Circle()
                                .fill(Color(hex: "#22D3EE"))
                                .frame(width: 5, height: 5)
                                .shadow(color: Color(hex: "#22D3EE").opacity(0.8), radius: 3)
                            Image(systemName: "sparkle")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color(hex: "#22D3EE"))
                        }
                    }

                    // 9 Coucou Dancing Dots
                    CoucouNineDotsView(levels: dictation.audioLevels, isThinking: false)

                    if locked {
                        // ✓ Finish button in Hands-Free
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
                        .help("Завершити надиктовку")
                    }

                case .thinking:
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(hex: "#C084FC"))

                    // 9 Ripple Dots during Gemini 3.8 Flash transcription
                    CoucouNineDotsView(levels: dictation.audioLevels, isThinking: true)

                case .done(_, let wasPasted):
                    Image(systemName: wasPasted ? "checkmark" : "doc.on.clipboard")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(hex: wasPasted ? "#10B981" : "#F59E0B"))

                    Text(wasPasted ? "Готово" : "Скопійовано")
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)

                case .failed(let err):
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: "#EF4444"))

                    Text(err.count > 16 ? "\(err.prefix(16))..." : err)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))

                case .idle:
                    EmptyView()
                }
            }
            .padding(.horizontal, isLocked ? 8 : 14)
        }
        .frame(width: pillWidth, height: 34)
        .shadow(color: Color.black.opacity(0.45), radius: 12, y: 4)
        .animation(.spring(response: 0.35, dampingFraction: 0.76), value: dictation.phase)
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
        case .listening(let locked): return locked ? 168 : 138
        case .thinking: return 132
        case .done: return 114
        case .failed: return 128
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
