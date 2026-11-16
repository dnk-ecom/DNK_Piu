import AppKit
import PiuCore
import SwiftUI

public enum Layout {
    public static let pill = CGSize(width: 140, height: 38)
    public static let panelWidth: CGFloat = 340
    public static let maxPanelHeight: CGFloat = 460
    public static let emptyListHeight: CGFloat = 70
}

public struct RootView: View {
    @ObservedObject public var store: PiuStore

    public init(store: PiuStore) {
        self.store = store
    }

    public var body: some View {
        Group {
            if store.expanded {
                ExpandedPanelView(store: store)
            } else {
                FloatingPillView(store: store)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: store.expanded)
    }
}

/// Compact floating pill showing active agents count & microphone button.
public struct FloatingPillView: View {
    @ObservedObject public var store: PiuStore
    @ObservedObject public var dictation = AudioDictation.shared

    public init(store: PiuStore) {
        self.store = store
    }

    public var body: some View {
        HStack(spacing: 8) {
            // Clickable pill header to expand
            Button(action: { store.expanded = true }) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(pillStatusColor)
                        .frame(width: 8, height: 8)

                    Text("DNK_Piu")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    if store.needsYouCount > 0 {
                        Text("\(store.needsYouCount)")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color(red: 0.95, green: 0.35, blue: 0.25))
                            .clipShape(Capsule())
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            // Microphone Dictation Button
            Button(action: { dictation.toggle() }) {
                ZStack {
                    Circle()
                        .fill(dictation.isRecording ? Color.red : Color.primary.opacity(0.08))
                        .frame(width: 26, height: 26)

                    if dictation.isProcessing {
                        ProgressView()
                            .scaleEffect(0.6)
                    } else {
                        Image(systemName: dictation.isRecording ? "mic.fill" : "mic")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(dictation.isRecording ? .white : .primary)
                    }
                }
            }
            .buttonStyle(.plain)
            .help("Google Gemini 3.8 Flash Dictation (Voice-to-Text)")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(width: Layout.pill.width, height: Layout.pill.height)
        .background(
            Capsule()
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.95))
                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 3)
        )
        .overlay(
            Capsule()
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
    }

    private var pillStatusColor: Color {
        if dictation.isRecording { return Color.red }
        if store.needsYouCount > 0 { return Color(red: 0.95, green: 0.35, blue: 0.25) }
        if store.sessions.contains(where: { store.activity($0) == .working }) {
            return Color(red: 0.18, green: 0.83, blue: 0.75) // DNK Cyan
        }
        return Color(red: 0.75, green: 0.45, blue: 0.95) // DNK Purple
    }
}

/// Accessibility permission prompt banner.
public struct AccessibilityBanner: View {
    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(Color(hex: "#F59E0B"))
                .font(.system(size: 11))

            VStack(alignment: .leading, spacing: 1) {
                Text("Потрібен дозвіл Accessibility")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.primary)
                Text("Для хоткеїв ⌥ та вставки ⌘V")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: { DictationHotKey.openAccessibilitySettings() }) {
                Text("Надати")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color(hex: "#A855F7"))
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(Color(hex: "#F59E0B").opacity(0.12))
        .cornerRadius(8)
        .padding(.horizontal, 10)
        .padding(.top, 6)
    }
}

/// Top card displaying the latest transcribed text and dictation history.
public struct DictationTopCard: View {
    @ObservedObject public var dictation = AudioDictation.shared
    @LocalState private var copiedId: UUID? = nil
    @LocalState private var showHistory: Bool = false

    public init() {}

    public var body: some View {
        if !dictation.history.isEmpty || !dictation.lastTranscript.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                // Header with icon, label and history toggle
                HStack(spacing: 6) {
                    Image(systemName: "waveform.badge.mic")
                        .foregroundColor(Color(hex: "#06B6D4"))
                        .font(.system(size: 12, weight: .bold))

                    Text("Надиктовано (Gemini 3.8)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    if let latest = dictation.history.first {
                        Text(latest.formattedTime)
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if dictation.history.count > 1 {
                        Button(action: { showHistory.toggle() }) {
                            HStack(spacing: 2) {
                                Text("Історія (\(dictation.history.count))")
                                    .font(.system(size: 9, weight: .semibold))
                                Image(systemName: showHistory ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 8, weight: .bold))
                            }
                            .foregroundColor(Color(hex: "#A855F7"))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(hex: "#A855F7").opacity(0.12))
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Latest Transcript Box
                let latestItem = dictation.history.first ?? DictationItem(text: dictation.lastTranscript)
                VStack(alignment: .leading, spacing: 6) {
                    Text(latestItem.text)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        Spacer()

                        // Copy to clipboard button
                        Button(action: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.declareTypes([.string], owner: nil)
                            NSPasteboard.general.setString(latestItem.text, forType: .string)
                            copiedId = latestItem.id
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                if copiedId == latestItem.id { copiedId = nil }
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: copiedId == latestItem.id ? "checkmark" : "doc.on.doc")
                                    .font(.system(size: 9, weight: .bold))
                                Text(copiedId == latestItem.id ? "Скопійовано!" : "Скопіювати")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            .foregroundColor(copiedId == latestItem.id ? .green : Color(hex: "#06B6D4"))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.primary.opacity(0.06))
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)

                        // Insert at cursor button
                        Button(action: {
                            FlowPaste.insert(latestItem.text)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.right.doc.on.clipboard")
                                    .font(.system(size: 9, weight: .bold))
                                Text("Вставити")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "#A855F7"), Color(hex: "#06B6D4")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                        .help("Insert text into active cursor position")
                    }
                }
                .padding(8)
                .background(Color(hex: "#A855F7").opacity(0.08))
                .cornerRadius(8)

                // History Dropdown
                if showHistory && dictation.history.count > 1 {
                    VStack(spacing: 4) {
                        ForEach(dictation.history.dropFirst().prefix(4)) { prevItem in
                            HStack(alignment: .center, spacing: 6) {
                                Text(prevItem.text)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)

                                Spacer()

                                Text(prevItem.formattedTime)
                                    .font(.system(size: 8))
                                    .foregroundColor(.secondary.opacity(0.7))

                                Button(action: {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.declareTypes([.string], owner: nil)
                                    NSPasteboard.general.setString(prevItem.text, forType: .string)
                                }) {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 8))
                                        .foregroundColor(Color(hex: "#A855F7"))
                                }
                                .buttonStyle(.plain)

                                Button(action: {
                                    FlowPaste.insert(prevItem.text)
                                }) {
                                    Image(systemName: "arrow.right.doc.on.clipboard")
                                        .font(.system(size: 8))
                                        .foregroundColor(Color(hex: "#06B6D4"))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(Color.primary.opacity(0.04))
                            .cornerRadius(5)
                        }
                    }
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.7))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(hex: "#A855F7").opacity(0.3), lineWidth: 1)
            )
            .padding(.horizontal, 10)
            .padding(.top, 8)
        }
    }
}

/// Expanded panel view displaying agents list and approval cards.
public struct ExpandedPanelView: View {
    @ObservedObject public var store: PiuStore

    public init(store: PiuStore) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "cpu")
                        .foregroundColor(Color(red: 0.18, green: 0.83, blue: 0.75))
                    Text("DNK_Piu")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }

                Spacer()

                Button(action: { store.muted.toggle() }) {
                    Image(systemName: store.muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)

                Button(action: { store.expanded = false }) {
                    Image(systemName: "chevron.up.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.6))

            Divider()

            // 1. Accessibility warning banner if not yet granted
            if !DictationHotKey.isAccessibilityGranted() {
                AccessibilityBanner()
            }

            // 2. TOP SECTION: Dictated text list (At the very top of the menu/panel!)
            DictationTopCard()

            // 3. Pending Approval Requests
            if !store.pending.isEmpty {
                VStack(spacing: 8) {
                    ForEach(store.pending) { req in
                        RequestCardView(store: store, request: req)
                    }
                }
                .padding(10)
            }

            // 4. Sessions List
            ScrollView {
                VStack(spacing: 6) {
                    if store.sessions.isEmpty {
                        VStack(spacing: 6) {
                            Image(systemName: "person.wave.2")
                                .font(.system(size: 20))
                                .foregroundColor(.secondary)
                            Text("No active agents")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                            Text("Start Antigravity, Gerych or Claude Code to monitor")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary.opacity(0.8))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: Layout.emptyListHeight)
                    } else {
                        ForEach(store.ordered) { session in
                            SessionRowView(store: store, session: session)
                        }
                    }
                }
                .padding(10)
            }
            .frame(maxHeight: Layout.maxPanelHeight)

            Divider()

            // Footer with dictation quick bar
            FooterDictationBar()
        }
        .frame(width: Layout.panelWidth)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        )
    }
}

public struct SessionRowView: View {
    @ObservedObject public var store: PiuStore
    public var session: AgentSession

    public init(store: PiuStore, session: AgentSession) {
        self.store = store
        self.session = session
    }

    public var body: some View {
        HStack(spacing: 10) {
            BuddyView(traits: session.buddy, activity: store.activity(session), size: 30)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(session.displayName)
                        .font(.system(size: 11, weight: .bold))
                        .lineLimit(1)

                    Text(session.info.agentKind.displayName)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color(hex: session.info.agentKind.badgeColor))
                        .cornerRadius(3)
                }

                Text(session.currentStep)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // 1-Click Jump to session window
            Button(action: { Jumper.activate(pid: session.info.pid, cwd: session.info.cwd) }) {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Focus agent session in terminal/editor")
        }
        .padding(8)
        .background(Color.primary.opacity(0.04))
        .cornerRadius(8)
    }
}

public struct FooterDictationBar: View {
    @ObservedObject public var dictation = AudioDictation.shared

    public init() {}

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .foregroundColor(Color(red: 0.18, green: 0.83, blue: 0.75))
                .font(.system(size: 11))

            Text(dictation.isRecording ? "Recording... (Hold ⌥ or double-tap)" : (dictation.lastTranscript.isEmpty ? "Google Cloud Dictation Ready" : dictation.lastTranscript))
                .font(.system(size: 10, weight: dictation.isRecording ? .semibold : .regular))
                .foregroundColor(dictation.isRecording ? .red : .secondary)
                .lineLimit(1)

            Spacer()

            Button(action: { dictation.toggle() }) {
                HStack(spacing: 4) {
                    Image(systemName: dictation.isRecording ? "stop.circle.fill" : "mic.fill")
                        .foregroundColor(dictation.isRecording ? .red : .primary)
                    Text(dictation.isRecording ? "Stop" : "Dictate")
                        .font(.system(size: 10, weight: .semibold))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.08))
                .cornerRadius(5)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.7))
    }
}

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted))
        var int: UInt64 = 0
        scanner.scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 7: // #RRGGBB
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (128, 128, 128)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}
