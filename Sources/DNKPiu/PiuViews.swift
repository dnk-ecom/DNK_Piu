import AppKit
import PiuCore
import SwiftUI

public enum Layout {
    public static let pill = CGSize(width: 136, height: 36)
    public static let panelWidth: CGFloat = 320
    public static let maxPanelHeight: CGFloat = 440
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

/// Compact floating pill showing active agents count & microphone button (Coucou Island style).
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
                        .shadow(color: pillStatusColor.opacity(0.6), radius: 3)

                    Text("DNK_Piu")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "#F5F6F8"))

                    if store.needsYouCount > 0 {
                        Text("\(store.needsYouCount)")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color(hex: "#EF4444"))
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
                        .fill(dictation.isRecording ? Color(hex: "#EF4444") : Color.white.opacity(0.10))
                        .frame(width: 24, height: 24)

                    if dictation.isProcessing {
                        ProgressView()
                            .scaleEffect(0.55)
                    } else {
                        Image(systemName: dictation.isRecording ? "mic.fill" : "mic")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(dictation.isRecording ? .white : Color(hex: "#22D3EE"))
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
                .fill(Color(hex: "#0A0B0E").opacity(0.96))
                .shadow(color: Color.black.opacity(0.4), radius: 10, x: 0, y: 3)
        )
        .overlay(
            Capsule()
                .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
        )
    }

    private var pillStatusColor: Color {
        if dictation.isRecording { return Color(hex: "#EF4444") }
        if store.needsYouCount > 0 { return Color(hex: "#F97316") }
        if store.sessions.contains(where: { store.activity($0) == .working }) {
            return Color(hex: "#22D3EE") // Coucou Cyan
        }
        return Color(hex: "#C084FC") // Coucou Purple
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
                    .foregroundColor(Color(hex: "#F5F6F8"))
                Text("Для хоткеїв ⌥ та вставки ⌘V")
                    .font(.system(size: 9))
                    .foregroundColor(Color.white.opacity(0.65))
            }

            Spacer()

            Button(action: { DictationHotKey.openAccessibilitySettings() }) {
                Text("Надати")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(hex: "#A855F7"))
                    .cornerRadius(5)
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(Color(hex: "#F59E0B").opacity(0.12))
        .cornerRadius(10)
        .padding(.horizontal, 10)
        .padding(.top, 6)
    }
}

/// Top card displaying the latest transcribed text and dictation history (Coucou design).
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
                    Image(systemName: "sparkles")
                        .foregroundColor(Color(hex: "#22D3EE"))
                        .font(.system(size: 11, weight: .bold))

                    Text("Надиктовано (Gemini 3.8)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "#F5F6F8"))

                    if let latest = dictation.history.first {
                        Text(latest.formattedTime)
                            .font(.system(size: 9))
                            .foregroundColor(Color.white.opacity(0.5))
                    }

                    Spacer()

                    if dictation.history.count > 1 {
                        Button(action: { showHistory.toggle() }) {
                            HStack(spacing: 3) {
                                Text("Історія (\(dictation.history.count))")
                                    .font(.system(size: 9, weight: .semibold))
                                Image(systemName: showHistory ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 8, weight: .bold))
                            }
                            .foregroundColor(Color(hex: "#C084FC"))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(hex: "#C084FC").opacity(0.15))
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Latest Transcript Box
                let latestItem = dictation.history.first ?? DictationItem(text: dictation.lastTranscript)
                VStack(alignment: .leading, spacing: 6) {
                    Text(latestItem.text)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(Color(hex: "#E8E9EC"))
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        Spacer()

                        // Copy to clipboard button
                        Button(action: {
                            FlowPaste.copyToClipboard(latestItem.text)
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
                            .foregroundColor(copiedId == latestItem.id ? Color(hex: "#10B981") : Color(hex: "#22D3EE"))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(5)
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
                            .padding(.horizontal, 9)
                            .padding(.vertical, 3)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "#A855F7"), Color(hex: "#06B6D4")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(5)
                        }
                        .buttonStyle(.plain)
                        .help("Insert text into active cursor position")
                    }
                }
                .padding(8)
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)

                // History Dropdown
                if showHistory && dictation.history.count > 1 {
                    VStack(spacing: 4) {
                        ForEach(dictation.history.dropFirst().prefix(4)) { prevItem in
                            HStack(alignment: .center, spacing: 6) {
                                Text(prevItem.text)
                                    .font(.system(size: 10))
                                    .foregroundColor(Color.white.opacity(0.75))
                                    .lineLimit(1)

                                Spacer()

                                Text(prevItem.formattedTime)
                                    .font(.system(size: 8))
                                    .foregroundColor(Color.white.opacity(0.4))

                                Button(action: {
                                    FlowPaste.copyToClipboard(prevItem.text)
                                }) {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 8))
                                        .foregroundColor(Color(hex: "#C084FC"))
                                }
                                .buttonStyle(.plain)

                                Button(action: {
                                    FlowPaste.insert(prevItem.text)
                                }) {
                                    Image(systemName: "arrow.right.doc.on.clipboard")
                                        .font(.system(size: 8))
                                        .foregroundColor(Color(hex: "#22D3EE"))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.03))
                            .cornerRadius(5)
                        }
                    }
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
            )
            .padding(.horizontal, 10)
            .padding(.top, 8)
        }
    }
}

/// Expanded panel view displaying agents list and approval cards (Coucou Island container).
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
                    Image(systemName: "sparkle")
                        .foregroundColor(Color(hex: "#22D3EE"))
                        .font(.system(size: 13, weight: .bold))
                    Text("DNK_Piu")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "#F5F6F8"))
                }

                Spacer()

                Button(action: { store.muted.toggle() }) {
                    Image(systemName: store.muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Color.white.opacity(0.6))
                }
                .buttonStyle(.plain)

                Button(action: { store.expanded = false }) {
                    Image(systemName: "chevron.up.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color.white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.03))

            Divider().background(Color.white.opacity(0.08))

            // 1. Accessibility warning banner if not yet granted
            if !DictationHotKey.isAccessibilityGranted() {
                AccessibilityBanner()
            }

            // 2. TOP SECTION: Dictated text list (Coucou style)
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
                            Image(systemName: "sparkles")
                                .font(.system(size: 20))
                                .foregroundColor(Color.white.opacity(0.3))
                            Text("Немає активних агентів")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color.white.opacity(0.6))
                            Text("Antigravity, Gerych або Denchik")
                                .font(.system(size: 9))
                                .foregroundColor(Color.white.opacity(0.4))
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

            Divider().background(Color.white.opacity(0.08))

            // Footer with dictation quick bar
            FooterDictationBar()
        }
        .frame(width: Layout.panelWidth)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color(hex: "#0A0B0E").opacity(0.96))
                .shadow(color: Color.black.opacity(0.55), radius: 24, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
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
            BuddyView(traits: session.buddy, activity: store.activity(session), size: 28)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(session.displayName)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(hex: "#F5F6F8"))
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
                    .foregroundColor(Color.white.opacity(0.65))
                    .lineLimit(1)
            }

            Spacer()

            // 1-Click Jump to session window
            Button(action: { Jumper.activate(pid: session.info.pid, cwd: session.info.cwd) }) {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 13))
                    .foregroundColor(Color.white.opacity(0.5))
            }
            .buttonStyle(.plain)
            .help("Focus agent session in terminal/editor")
        }
        .padding(8)
        .background(Color.white.opacity(0.03))
        .cornerRadius(8)
    }
}

public struct FooterDictationBar: View {
    @ObservedObject public var dictation = AudioDictation.shared
    @ObservedObject public var hotKey = DictationHotKey.shared

    public init() {}

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .foregroundColor(Color(hex: "#22D3EE"))
                .font(.system(size: 11))

            Text(dictation.isRecording ? "Запис... (Відпустіть \(hotKey.activePreset.symbol))" : (dictation.lastTranscript.isEmpty ? "Хоткей: \(hotKey.activePreset.displayName)" : dictation.lastTranscript))
                .font(.system(size: 10, weight: dictation.isRecording ? .semibold : .regular))
                .foregroundColor(dictation.isRecording ? Color(hex: "#EF4444") : Color.white.opacity(0.65))
                .lineLimit(1)

            Spacer()

            Button(action: { dictation.toggle() }) {
                HStack(spacing: 4) {
                    Image(systemName: dictation.isRecording ? "stop.circle.fill" : "mic.fill")
                        .foregroundColor(dictation.isRecording ? Color(hex: "#EF4444") : Color(hex: "#22D3EE"))
                    Text(dictation.isRecording ? "Стоп" : "Диктувати")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color(hex: "#F5F6F8"))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.08))
                .cornerRadius(5)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.02))
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
