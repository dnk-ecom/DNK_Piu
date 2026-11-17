import AppKit
import AVFoundation
import Carbon
import Foundation

/// High-velocity voice dictation engine powered by Google Cloud Vertex AI (Gemini 3.8 Flash Multimodal Audio).
public enum DictationPhase: Equatable {
    case idle
    case listening(isLocked: Bool)
    case thinking
    case done(String, wasPasted: Bool)
    case failed(String)

    public var isHandsFree: Bool {
        if case .listening(let isLocked) = self { return isLocked }
        return false
    }
}

/// A recorded and transcribed voice message item.
public struct DictationItem: Identifiable, Codable, Equatable {
    public let id: UUID
    public let text: String
    public let timestamp: Date

    public init(id: UUID = UUID(), text: String, timestamp: Date = Date()) {
        self.id = id
        self.text = text
        self.timestamp = timestamp
    }

    public var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}

public final class AudioDictation: NSObject, ObservableObject, AVAudioRecorderDelegate {
    public static let shared = AudioDictation()

    @Published public private(set) var isRecording = false
    @Published public private(set) var isProcessing = false
    @Published public private(set) var phase: DictationPhase = .idle
    /// Exactly 9 bands matching Coucou's FlowBands.count
    @Published public private(set) var audioLevels: [Float] = [Float](repeating: 0.1, count: 9)
    @Published public var lastTranscript: String = ""
    @Published public var history: [DictationItem] = []
    @Published public var errorMessage: String? = nil

    private var recorder: AVAudioRecorder?
    private var meterTimer: Timer?
    private let recordingURL = URL(fileURLWithPath: "/tmp/dnk_piu_audio.wav")
    private let bridgeURL = URL(string: "http://127.0.0.1:11435/v1/audio/transcriptions")!
    private let historyKey = "piu_dictation_history"

    /// The frontmost app active when recording began (where the text should go)
    public private(set) var targetApp: NSRunningApplication?

    /// Dismisses active quote or phase back to idle
    public func dismiss() {
        DispatchQueue.main.async {
            self.phase = .idle
        }
    }

    private override init() {
        super.init()
        loadHistory()
    }

    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let items = try? JSONDecoder().decode([DictationItem].self, from: data), !items.isEmpty {
            self.history = items
            self.lastTranscript = items.first?.text ?? ""
        } else if let saved = UserDefaults.standard.string(forKey: "piu_last_transcript"), !saved.isEmpty {
            let item = DictationItem(text: saved)
            self.history = [item]
            self.lastTranscript = saved
        }
    }

    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(encoded, forKey: historyKey)
        }
        UserDefaults.standard.set(lastTranscript, forKey: "piu_last_transcript")
    }

    /// Toggles voice dictation.
    public func toggle() {
        if isRecording {
            stopAndTranscribe()
        } else {
            start(locked: true)
        }
    }

    /// Starts recording microphone input.
    public func start(locked: Bool = false) {
        guard !isRecording else {
            if locked {
                DispatchQueue.main.async {
                    self.phase = .listening(isLocked: true)
                }
            }
            return
        }

        // Capture frontmost app where cursor currently lives (Coucou technique)
        let front = NSWorkspace.shared.frontmostApplication
        if let f = front, f.bundleIdentifier != Bundle.main.bundleIdentifier {
            self.targetApp = f
        }

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false
        ]

        do {
            recorder = try AVAudioRecorder(url: recordingURL, settings: settings)
            recorder?.isMeteringEnabled = true
            recorder?.delegate = self
            recorder?.record()
            DispatchQueue.main.async {
                self.isRecording = true
                self.phase = .listening(isLocked: locked)
                self.errorMessage = nil
                self.startMetering()
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to start audio recording: \(error.localizedDescription)"
                self.phase = .failed(self.errorMessage ?? "Error")
            }
        }
    }

    /// Cancels active recording without transcribing.
    public func cancel() {
        stopMetering()
        recorder?.stop()
        recorder = nil
        targetApp = nil
        try? FileManager.default.removeItem(at: recordingURL)
        DispatchQueue.main.async {
            self.isRecording = false
            self.isProcessing = false
            self.phase = .idle
        }
    }

    /// Clears all recorded transcripts.
    public func clearHistory() {
        history.removeAll()
        lastTranscript = ""
        saveHistory()
    }

    /// Removes a specific transcript item.
    public func remove(item: DictationItem) {
        history.removeAll { $0.id == item.id }
        if lastTranscript == item.text {
            lastTranscript = history.first?.text ?? ""
        }
        saveHistory()
    }

    /// Stops recording and sends the audio to Vertex AI Gemini 3.8 Flash for transcription.
    public func stopAndTranscribe(insertAutomatically: Bool = true, completion: ((String?) -> Void)? = nil) {
        guard isRecording else { return }

        stopMetering()
        recorder?.stop()
        recorder = nil

        let destApp = self.targetApp

        DispatchQueue.main.async {
            self.isRecording = false
            self.isProcessing = true
            self.phase = .thinking
        }

        Task {
            guard let audioData = try? Data(contentsOf: self.recordingURL), !audioData.isEmpty else {
                await MainActor.run {
                    self.isProcessing = false
                    self.errorMessage = "No audio recorded"
                    self.phase = .failed("No audio")
                    completion?(nil)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                        if case .failed = self.phase { self.phase = .idle }
                    }
                }
                return
            }

            let base64Audio = audioData.base64EncodedString()
            let payload: [String: Any] = [
                "audio_base64": base64Audio,
                "mime_type": "audio/wav",
                "model": "gemini-3.5-flash-lite",
                "prompt": "Транскрибуй мову розробника (uk-UA / en-US). Зберігай технічні терміни та назви в оригіналі (Shopify, Clyro, Antigravity, commit, branch, PR, Swift, Python, Coucou, Huddle). Автоматично розставляй розділові знаки. Повертай ВИКЛЮЧНО розпізнаний текст без лапок чи коментарів."
            ]

            var request = URLRequest(url: self.bridgeURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 45.0 // Generous timeout to avoid connection cancellation

            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: payload)
                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let text = json["text"] as? String else {
                    let errStr = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String ?? "Invalid bridge response"
                    await MainActor.run {
                        self.isProcessing = false
                        self.errorMessage = errStr
                        self.phase = .failed(errStr)
                        completion?(nil)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            if case .failed = self.phase { self.phase = .idle }
                        }
                    }
                    return
                }

                let transcript = text.trimmingCharacters(in: .whitespacesAndNewlines)

                await MainActor.run {
                    self.isProcessing = false
                    guard !transcript.isEmpty else {
                        self.phase = .failed("Empty transcript")
                        completion?(nil)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            if case .failed = self.phase { self.phase = .idle }
                        }
                        return
                    }

                    self.lastTranscript = transcript
                    let newItem = DictationItem(text: transcript)
                    self.history.insert(newItem, at: 0)
                    if self.history.count > 30 {
                        self.history.removeLast()
                    }
                    self.saveHistory()

                    var pasted = false
                    if insertAutomatically {
                        pasted = FlowPaste.insert(transcript, into: destApp)
                    } else {
                        FlowPaste.copyToClipboard(transcript)
                    }

                    self.phase = .done(transcript, wasPasted: pasted)
                    NSSound(named: "Pop")?.play()
                    completion?(transcript)

                    let autoDismissDelay: Double = pasted ? 0.45 : 2.5
                    DispatchQueue.main.asyncAfter(deadline: .now() + autoDismissDelay) {
                        if case .done = self.phase {
                            self.phase = .idle
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.isProcessing = false
                    self.errorMessage = "Bridge request error: \(error.localizedDescription)"
                    self.phase = .failed(self.errorMessage ?? "Error")
                    completion?(nil)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        if case .failed = self.phase { self.phase = .idle }
                    }
                }
            }
        }
    }

    private func startMetering() {
        meterTimer?.invalidate()
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { [weak self] _ in
            guard let self = self, let recorder = self.recorder, recorder.isRecording else { return }
            recorder.updateMeters()
            let power = recorder.averagePower(forChannel: 0) // -160 to 0 dB
            let normalized = max(0.05, min(1.0, Float((power + 42.0) / 42.0)))

            let t = Date().timeIntervalSinceReferenceDate
            var levels: [Float] = []
            for i in 0..<9 {
                let jitter = Float(sin(t * 11.0 + Double(i) * 1.5)) * 0.12
                let val = max(0.08, min(1.0, normalized * (0.60 + Float(i % 3) * 0.18) + jitter))
                levels.append(val)
            }
            DispatchQueue.main.async {
                self.audioLevels = levels
            }
        }
    }

    private func stopMetering() {
        meterTimer?.invalidate()
        meterTimer = nil
        audioLevels = [Float](repeating: 0.1, count: 9)
    }
}

/// Seamless pasteboard injector simulating ⌘V with universal keyboard layout support (Coucou-style).
public enum FlowPaste {
    public static let transientType = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")
    public static let autoGeneratedType = NSPasteboard.PasteboardType("org.nspasteboard.AutoGeneratedType")

    private static var wokenApps: Set<pid_t> = []

    /// Wakes up accessibility for Electron / Chromium apps (VS Code, Antigravity, Chrome) so they accept simulated input.
    public static func wakeAccessibility(of app: NSRunningApplication?) {
        guard let app = app, AXIsProcessTrusted(), !wokenApps.contains(app.processIdentifier) else { return }
        wokenApps.insert(app.processIdentifier)
        let element = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetAttributeValue(element, "AXManualAccessibility" as CFString, kCFBooleanTrue)
    }

    /// Copies text directly to the system clipboard and keeps it there permanently.
    public static func copyToClipboard(_ text: String) {
        guard !text.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.declareTypes([.string, transientType, autoGeneratedType], owner: nil)
        pasteboard.setString(text, forType: .string)
        pasteboard.setData(Data(), forType: transientType)
        pasteboard.setData(Data(), forType: autoGeneratedType)
    }

    /// Internal diagnostic file logger for zero-guesswork debugging.
    public static func log(_ message: String) {
        let logPath = ("~/.dnk_runtime/piu/piu.log" as NSString).expandingTildeInPath
        let line = "[\(Date())] \(message)\n"
        if let data = line.data(using: .utf8) {
            if let fileHandle = FileHandle(forWritingAtPath: logPath) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                fileHandle.closeFile()
            } else {
                try? data.write(to: URL(fileURLWithPath: logPath))
            }
        }
    }

    /// Sets the text on the general pasteboard, restores focus to target app if needed, and synthesizes ⌘V.
    @discardableResult
    public static func insert(_ text: String, into targetApp: NSRunningApplication? = nil) -> Bool {
        guard !text.isEmpty else { return false }

        // 1. Snapshot previous clipboard to restore later
        let board = NSPasteboard.general
        let saved = snapshot(board)

        // 2. Write new text with transient flags so clipboard managers don't pollute history
        board.clearContents()
        board.declareTypes([.string, transientType, autoGeneratedType], owner: nil)
        board.setString(text, forType: .string)
        board.setData(Data(), forType: transientType)
        board.setData(Data(), forType: autoGeneratedType)

        let isTrusted = AXIsProcessTrusted()
        log("FlowPaste.insert: textCount=\(text.count), targetApp=\(targetApp?.bundleIdentifier ?? "nil"), isTrusted=\(isTrusted)")

        // 3. Wake accessibility for Chromium/Electron editors (Antigravity, Cursor, VS Code)
        wakeAccessibility(of: targetApp)

        // 4. Check if target application needs explicit reactivation
        let needsActivation = (targetApp != nil && targetApp?.bundleIdentifier != Bundle.main.bundleIdentifier && !(targetApp?.isActive ?? true))

        if needsActivation, let app = targetApp {
            if #available(macOS 14.0, *) {
                NSApp.yieldActivation(to: app)
            }
            app.activate()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                postCmdV(into: app, isTrusted: isTrusted)
                scheduleClipboardRestore(saved, count: board.changeCount)
            }
        } else {
            // Immediate hardware paste into active editor where caret is located
            postCmdV(into: targetApp, isTrusted: isTrusted)
            scheduleClipboardRestore(saved, count: board.changeCount)
        }

        return isTrusted
    }

    /// True 4-step hardware keyboard event sequence: Command Down -> V Down -> V Up -> Command Up.
    private static func postCmdV(into targetApp: NSRunningApplication? = nil, isTrusted: Bool = true) {
        log("postCmdV: executing 4-step sequence into \(targetApp?.bundleIdentifier ?? "activeWindow")...")
        let source = CGEventSource(stateID: .combinedSessionState)
        let cmdKey: CGKeyCode = 0x37 // Left Command
        let vKey = vKeyCode()

        guard let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: cmdKey, keyDown: true),
              let vDown = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true),
              let vUp = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false),
              let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: cmdKey, keyDown: false) else {
            log("postCmdV: Failed to create CGEvent instances")
            return
        }

        cmdDown.flags = .maskCommand
        vDown.flags = .maskCommand
        vUp.flags = .maskCommand
        cmdUp.flags = []

        // 1. Post to hardware HID event tap (Universal macOS WindowServer routing)
        cmdDown.post(tap: .cghidEventTap)
        vDown.post(tap: .cghidEventTap)
        vUp.post(tap: .cghidEventTap)
        cmdUp.post(tap: .cghidEventTap)

        // 2. Also post directly to target application PID if known to guarantee delivery
        if let pid = targetApp?.processIdentifier {
            cmdDown.postToPid(pid)
            vDown.postToPid(pid)
            vUp.postToPid(pid)
            cmdUp.postToPid(pid)
        }

        // 3. AppleScript fallback if Accessibility is not granted
        if !isTrusted {
            log("postCmdV: Accessibility permission missing, executing System Events AppleScript fallback...")
            let scriptSource = "tell application \"System Events\" to keystroke \"v\" using command down"
            var err: NSDictionary?
            NSAppleScript(source: scriptSource)?.executeAndReturnError(&err)
            if let err = err {
                log("postCmdV: AppleScript error: \(err)")
            }
        }
        log("postCmdV: finished dispatching paste events.")
    }

    private static func scheduleClipboardRestore(_ items: [[NSPasteboard.PasteboardType: Data]], count: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            let board = NSPasteboard.general
            if board.changeCount == count {
                log("scheduleClipboardRestore: restoring previous clipboard after 2.0s")
                restore(items, to: board)
            }
        }
    }

    private static func snapshot(_ board: NSPasteboard) -> [[NSPasteboard.PasteboardType: Data]] {
        (board.pasteboardItems ?? []).map { item in
            var out: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) { out[type] = data }
            }
            return out
        }
    }

    private static func restore(_ items: [[NSPasteboard.PasteboardType: Data]], to board: NSPasteboard) {
        guard !items.isEmpty else { return }
        board.clearContents()
        for entry in items {
            let item = NSPasteboardItem()
            for (type, data) in entry {
                item.setData(data, forType: type)
            }
            board.writeObjects([item])
        }
    }

    /// Dynamically resolves the physical key code for 'V' with Command held across keyboard layouts.
    /// Handles QWERTY, AZERTY, Ukrainian, and layout switching seamlessly.
    public static func vKeyCode() -> CGKeyCode {
        let fallback = CGKeyCode(kVK_ANSI_V) // 0x09
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let raw = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return fallback }
        let data = Unmanaged<CFData>.fromOpaque(raw).takeUnretainedValue() as Data
        let commandState = UInt32((cmdKey >> 8) & 0xFF)

        let found: CGKeyCode? = data.withUnsafeBytes { bytes in
            guard let layout = bytes.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return nil }
            for code in 0..<128 {
                var dead: UInt32 = 0
                var length = 0
                var chars = [UniChar](repeating: 0, count: 4)
                let status = UCKeyTranslate(
                    layout,
                    UInt16(code),
                    UInt16(kUCKeyActionDisplay),
                    commandState,
                    UInt32(LMGetKbdType()),
                    OptionBits(1 << kUCKeyTranslateNoDeadKeysBit),
                    &dead,
                    4,
                    &length,
                    &chars
                )
                if status == noErr, length == 1, chars[0] == 0x76 /* 'v' */ {
                    return CGKeyCode(code)
                }
            }
            return nil
        }
        return found ?? fallback
    }
}
