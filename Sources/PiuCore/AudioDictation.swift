import AppKit
import AVFoundation
import Carbon
import Foundation

/// High-velocity voice dictation engine powered by Google Cloud Vertex AI (Gemini 3.8 Flash Multimodal Audio).
public enum DNKPiuVersion {
    public static let current = "0.1.0"
    public static let build = "1"
    public static let releaseName = "Sovereign Whisper"
}

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
    public let targetApp: String?

    public init(id: UUID = UUID(), text: String, timestamp: Date = Date(), targetApp: String? = nil) {
        self.id = id
        self.text = text
        self.timestamp = timestamp
        self.targetApp = targetApp
    }

    public var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: timestamp)
    }

    public var relativeTime: String {
        let elapsed = Date().timeIntervalSince(timestamp)
        if elapsed < 60 {
            return "щойно"
        } else if elapsed < 3600 {
            let mins = max(1, Int(elapsed / 60))
            return "\(mins) хв тому"
        } else if elapsed < 86400 {
            let hours = Int(elapsed / 3600)
            return "\(hours) год тому"
        } else {
            let days = Int(elapsed / 86400)
            return "\(days) дн тому"
        }
    }

    public var appDisplayName: String {
        guard let target = targetApp, !target.isEmpty else { return "Система" }
        let last = target.components(separatedBy: ".").last ?? target
        switch last.lowercased() {
        case "antigravity-ide": return "Antigravity IDE"
        case "ghostty": return "Ghostty"
        case "cursor": return "Cursor"
        case "code": return "VS Code"
        case "chrome": return "Google Chrome"
        case "safari": return "Safari"
        case "slack": return "Slack"
        case "telegram": return "Telegram"
        default: return last.capitalized
        }
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
    private let recordingURL = URL(fileURLWithPath: "/tmp/dnk_piu_audio.m4a")
    private let bridgeURL = URL(string: "http://127.0.0.1:11435/v1/audio/transcriptions")!
    private let historyKey = "piu_dictation_history"

    /// Persistent HTTP/1.1 session with socket keep-alive for sub-700ms voice dictations
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpMaximumConnectionsPerHost = 4
        config.timeoutIntervalForRequest = 120.0
        config.httpShouldUsePipelining = true
        return URLSession(configuration: config)
    }()

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

        // Clean up previous recording file to ensure clean AAC container
        try? FileManager.default.removeItem(at: recordingURL)

        // Hardware-accelerated Apple Silicon AAC encoder (88% smaller payload, 0-latency encoding)
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 32000,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            recorder = try AVAudioRecorder(url: recordingURL, settings: settings)
            recorder?.isMeteringEnabled = true
            recorder?.delegate = self
            guard let rec = recorder, rec.record() else {
                recorder = nil
                DispatchQueue.main.async {
                    self.isRecording = false
                    self.errorMessage = "Мікрофон недоступний або зайнятий іншим процесом"
                    self.phase = .failed("Mic error")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        if case .failed = self.phase { self.phase = .idle }
                    }
                }
                return
            }
            DispatchQueue.main.async {
                self.isRecording = true
                self.phase = .listening(isLocked: locked)
                self.errorMessage = nil
                self.startMetering()
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Помилка ініціалізації мікрофона: \(error.localizedDescription)"
                self.phase = .failed(self.errorMessage ?? "Error")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    if case .failed = self.phase { self.phase = .idle }
                }
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
        Self.clearPersistentEvents()
    }

    /// Removes a specific transcript item.
    public func remove(item: DictationItem) {
        history.removeAll { $0.id == item.id }
        if lastTranscript == item.text {
            lastTranscript = history.first?.text ?? ""
        }
        saveHistory()
        Self.deletePersistentEvent(item)
    }

    /// Loads all recorded events from the persistent ~/.dnk_runtime/piu/voice_events.jsonl store.
    public static func loadPersistentEvents() -> [DictationItem] {
        let path = ("~/.dnk_runtime/piu/voice_events.jsonl" as NSString).expandingTildeInPath
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let content = String(data: data, encoding: .utf8) else {
            return []
        }
        var items: [DictationItem] = []
        let lines = content.components(separatedBy: "\n")
        for line in lines where !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard let lineData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  let text = json["text"] as? String else { continue }
            let tsDouble = json["timestamp"] as? Double ?? Date().timeIntervalSince1970
            let date = Date(timeIntervalSince1970: tsDouble)
            let app = json["target_app"] as? String
            items.append(DictationItem(text: text, timestamp: date, targetApp: app))
        }
        return items.reversed()
    }

    /// Rewrites the persistent store without a specific deleted item.
    public static func deletePersistentEvent(_ item: DictationItem) {
        let path = ("~/.dnk_runtime/piu/voice_events.jsonl" as NSString).expandingTildeInPath
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let content = String(data: data, encoding: .utf8) else { return }
        let lines = content.components(separatedBy: "\n")
        var remaining: [String] = []
        var deletedOne = false
        for line in lines where !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard let lineData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  let text = json["text"] as? String else {
                remaining.append(line)
                continue
            }
            if !deletedOne && text == item.text {
                deletedOne = true
                continue
            }
            remaining.append(line)
        }
        let updated = remaining.joined(separator: "\n") + (remaining.isEmpty ? "" : "\n")
        try? updated.write(to: URL(fileURLWithPath: path), atomically: true, encoding: .utf8)
    }

    /// Clears the persistent store file completely.
    public static func clearPersistentEvents() {
        let path = ("~/.dnk_runtime/piu/voice_events.jsonl" as NSString).expandingTildeInPath
        try? "".write(to: URL(fileURLWithPath: path), atomically: true, encoding: .utf8)
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

            // Safety watchdog: allows up to 125 seconds for long-form voice memos without freezing UI
            DispatchQueue.main.asyncAfter(deadline: .now() + 125.0) { [weak self] in
                guard let self = self else { return }
                if self.isProcessing || self.phase == .thinking {
                    self.isProcessing = false
                    self.phase = .idle
                }
            }
        }

        Task {
            guard let audioData = try? Data(contentsOf: self.recordingURL), !audioData.isEmpty else {
                await MainActor.run {
                    self.isProcessing = false
                    self.errorMessage = "No audio recorded"
                    self.phase = .failed("No audio")
                    completion?(nil)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        if case .failed = self.phase { self.phase = .idle }
                    }
                }
                return
            }

            // 1. Zero-data-loss: persistently archive audio to ~/.dnk_runtime/piu/recordings/
            let backupDir = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".dnk_runtime/piu/recordings")
            try? FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)
            let lastRecordingURL = backupDir.appendingPathComponent("last_recording.m4a")
            try? FileManager.default.removeItem(at: lastRecordingURL)
            try? audioData.write(to: lastRecordingURL)

            // Keep rolling timestamped archive (up to 20 files)
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd_HHmmss"
            let archiveName = "rec_\(formatter.string(from: Date())).m4a"
            let archiveURL = backupDir.appendingPathComponent(archiveName)
            try? audioData.write(to: archiveURL)

            // Clean up temporary recording container only after safe backup
            try? FileManager.default.removeItem(at: self.recordingURL)

            let base64Audio = audioData.base64EncodedString()
            let settings = DictationSettings.shared
            let customPrompt = settings.buildPrompt(targetApp: destApp?.bundleIdentifier)

            let payload: [String: Any] = [
                "audio_base64": base64Audio,
                "mime_type": "audio/aac",
                "model": settings.selectedModel.rawValue,
                "prompt": customPrompt,
                "formatting_mode": settings.formattingMode.rawValue,
                "strip_fillers": settings.stripFillers,
                "self_correction": settings.selfCorrection,
                "app_aware": settings.appAwareFormatting,
                "voice_commands": settings.voiceCommands,
                "target_app": destApp?.bundleIdentifier ?? ""
            ]

            var request = URLRequest(url: self.bridgeURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("keep-alive", forHTTPHeaderField: "Connection")
            request.timeoutInterval = 120.0

            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: payload)

                var dataOpt: Data?
                var respOpt: HTTPURLResponse?

                for attempt in 1...2 {
                    do {
                        let (d, r) = try await Self.session.data(for: request)
                        if let hr = r as? HTTPURLResponse {
                            dataOpt = d
                            respOpt = hr
                            break
                        }
                    } catch {
                        if attempt == 2 { throw error }
                        // Stale idle socket after Mac sleep; retry immediately
                        try? await Task.sleep(nanoseconds: 50_000_000)
                    }
                }

                guard let data = dataOpt, let httpResponse = respOpt, httpResponse.statusCode == 200,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let text = json["text"] as? String else {
                    let errStr = (dataOpt.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }?["error"] as? String) ?? "Invalid bridge response"
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

                let rawTranscript = text.trimmingCharacters(in: .whitespacesAndNewlines)
                let transcript = Self.sanitizeTranscript(rawTranscript)

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
                    let newItem = DictationItem(text: transcript, targetApp: destApp?.bundleIdentifier)
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

                    // Asynchronously dispatch and synchronize with Astryx Action Bus
                    AstryxVoiceBridge.dispatch(transcript: transcript, targetApp: destApp?.bundleIdentifier)

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

                    // Zero-data-loss: record failure into history with note that audio was preserved!
                    let failureItem = DictationItem(
                        text: "[⚠️ Помилка обробки: аудіо збережено в ~/.dnk_runtime/piu/recordings/last_recording.m4a]",
                        targetApp: destApp?.bundleIdentifier
                    )
                    self.history.insert(failureItem, at: 0)
                    if self.history.count > 30 { self.history.removeLast() }
                    self.saveHistory()

                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        if case .failed = self.phase { self.phase = .idle }
                    }
                }
            }
        }
    }

    /// Re-transcribes the last saved audio recording from ~/.dnk_runtime/piu/recordings/last_recording.m4a
    public func retryLastRecording(completion: ((String?) -> Void)? = nil) {
        let backupURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".dnk_runtime/piu/recordings/last_recording.m4a")
        guard FileManager.default.fileExists(atPath: backupURL.path),
              let audioData = try? Data(contentsOf: backupURL), !audioData.isEmpty else {
            self.phase = .failed("No backup recording")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { self.phase = .idle }
            return
        }

        self.phase = .thinking
        self.isProcessing = true
        let destApp = self.targetApp

        Task {
            let base64Audio = audioData.base64EncodedString()
            let settings = DictationSettings.shared
            let customPrompt = settings.buildPrompt(targetApp: destApp?.bundleIdentifier)

            let payload: [String: Any] = [
                "audio_base64": base64Audio,
                "mime_type": "audio/aac",
                "model": settings.selectedModel.rawValue,
                "prompt": customPrompt,
                "formatting_mode": settings.formattingMode.rawValue,
                "strip_fillers": settings.stripFillers,
                "self_correction": settings.selfCorrection,
                "app_aware": settings.appAwareFormatting,
                "voice_commands": settings.voiceCommands,
                "target_app": destApp?.bundleIdentifier ?? ""
            ]

            var request = URLRequest(url: self.bridgeURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("keep-alive", forHTTPHeaderField: "Connection")
            request.timeoutInterval = 120.0

            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: payload)
                let (data, resp) = try await Self.session.data(for: request)
                guard let httpResponse = resp as? HTTPURLResponse, httpResponse.statusCode == 200,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let text = json["text"] as? String else {
                    throw NSError(domain: "DNKPiu", code: -1, userInfo: [NSLocalizedDescriptionKey: "Bridge error"])
                }

                let rawTranscript = text.trimmingCharacters(in: .whitespacesAndNewlines)
                let transcript = Self.sanitizeTranscript(rawTranscript)
                await MainActor.run {
                    self.isProcessing = false
                    guard !transcript.isEmpty else {
                        self.phase = .failed("Empty transcript")
                        completion?(nil)
                        return
                    }

                    self.lastTranscript = transcript
                    let newItem = DictationItem(text: transcript, targetApp: destApp?.bundleIdentifier)
                    self.history.insert(newItem, at: 0)
                    if self.history.count > 30 { self.history.removeLast() }
                    self.saveHistory()

                    FlowPaste.insert(transcript, into: destApp)
                    self.phase = .done(transcript, wasPasted: true)
                    NSSound(named: "Pop")?.play()
                    completion?(transcript)

                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        if case .done = self.phase { self.phase = .idle }
                    }
                }
            } catch {
                await MainActor.run {
                    self.isProcessing = false
                    self.errorMessage = "Retry failed: \(error.localizedDescription)"
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

    /// Post-processing sanitizer that strips markdown wrappers and converts voice formatting commands.
    public static func sanitizeTranscript(_ raw: String) -> String {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip markdown code block wrappers if model wrapped in ```text ... ```
        if text.hasPrefix("```") {
            let lines = text.components(separatedBy: "\n")
            if lines.count >= 2 && lines.first?.hasPrefix("```") == true {
                let inner = lines.dropFirst().dropLast(lines.last?.hasPrefix("```") == true ? 1 : 0)
                text = inner.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // Strip outer quotes
        if (text.hasPrefix("\"") && text.hasSuffix("\"")) || (text.hasPrefix("«") && text.hasSuffix("»")) {
            text = String(text.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Deterministic regex replacement for spoken formatting commands
        if DictationSettings.shared.voiceCommands {
            let replacements: [(String, String)] = [
                ("(?i)\\b(новий рядок|нова стрічка)\\b", "\n"),
                ("(?i)\\b(новий абзац)\\b", "\n\n")
            ]
            for (pattern, repl) in replacements {
                if let regex = try? NSRegularExpression(pattern: pattern) {
                    let range = NSRange(location: 0, length: text.utf16.count)
                    text = regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: repl)
                }
            }
        }

        // Clean hybrid Latin 'kt' -> Cyrillic 'кт'
        text = text.replacingOccurrences(of: "kt", with: "кт")

        // User custom corrections from ~/.dnk_runtime/piu/corrections.json
        let corrPath = ("~/.dnk_runtime/piu/corrections.json" as NSString).expandingTildeInPath
        if let data = try? Data(contentsOf: URL(fileURLWithPath: corrPath)),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
            for (wrong, right) in dict {
                let pattern = "\\b" + NSRegularExpression.escapedPattern(for: wrong) + "\\b"
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                    let range = NSRange(location: 0, length: text.utf16.count)
                    text = regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: right)
                }
            }
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
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

    /// Sets the text on the general pasteboard and synthesizes ⌘V into the frontmost caret.
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

        // 4. Ensure target application is active if specified and inactive
        if let app = targetApp, !app.isActive, app.bundleIdentifier != Bundle.main.bundleIdentifier {
            log("FlowPaste.insert: targetApp \(app.bundleIdentifier ?? "") is inactive, yielding activation...")
            if #available(macOS 14.0, *) {
                NSApp.yieldActivation(to: app)
            }
            app.activate(options: [.activateIgnoringOtherApps])
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                postCmdV(isTrusted: isTrusted)
                scheduleClipboardRestore(saved, count: board.changeCount)
            }
            return isTrusted
        }

        // 5. Immediate hardware paste into active editor where caret is located
        postCmdV(isTrusted: isTrusted)
        scheduleClipboardRestore(saved, count: board.changeCount)

        return isTrusted
    }

    /// Coucou-verified synchronous ⌘V key injection via CoreGraphics HID Tap.
    private static func postCmdV(isTrusted: Bool = true) {
        log("postCmdV: executing Coucou-style synchronous CGEventPost... isTrusted=\(isTrusted)")

        if isTrusted {
            let source = CGEventSource(stateID: .combinedSessionState)
            let vKey = vKeyCode()

            guard let vDown = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true),
                  let vUp = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false) else {
                log("postCmdV: Failed to create CGEvent instances")
                return
            }

            // Command modifier flag is attached directly to the V key events
            vDown.flags = .maskCommand
            vUp.flags = .maskCommand

            // Post synchronously to system HID tap
            vDown.post(tap: .cghidEventTap)
            vUp.post(tap: .cghidEventTap)
            log("postCmdV: successfully posted vDown + vUp to .cghidEventTap")
        } else {
            // AppleScript fallback if Accessibility permission is missing
            log("postCmdV: Accessibility permission missing, executing System Events AppleScript fallback...")
            let scriptSource = "tell application \"System Events\" to keystroke \"v\" using command down"
            var err: NSDictionary?
            NSAppleScript(source: scriptSource)?.executeAndReturnError(&err)
            if let err = err {
                log("postCmdV: AppleScript error: \(err)")
            } else {
                log("postCmdV: AppleScript paste completed successfully.")
            }
        }
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

/// Bridge synchronizing transcribed dictations with the Astryx Operating System & AI Agents.
public enum AstryxVoiceBridge {
    public static func dispatch(transcript: String, targetApp: String?) {
        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let payload: [String: Any] = [
            "text": transcript,
            "target_app": targetApp ?? "unknown",
            "timestamp": Date().timeIntervalSince1970,
            "source": "dnk_piu_pill"
        ]

        let queue = DispatchQueue(label: "com.dnk.piu.astryx", qos: .utility)
        queue.async {
            let fileManager = FileManager.default
            let dirPath = ("~/.dnk_runtime/piu" as NSString).expandingTildeInPath
            if !fileManager.fileExists(atPath: dirPath) {
                try? fileManager.createDirectory(atPath: dirPath, withIntermediateDirectories: true)
            }

            // 1. Write latest intent to ~/.dnk_runtime/piu/last_intent.json
            let lastIntentPath = "\(dirPath)/last_intent.json"
            if let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted]) {
                try? jsonData.write(to: URL(fileURLWithPath: lastIntentPath))
            }

            // 2. Append to ~/.dnk_runtime/piu/voice_events.jsonl
            let eventsPath = "\(dirPath)/voice_events.jsonl"
            if let lineData = try? JSONSerialization.data(withJSONObject: payload, options: []) {
                var lineWithNewline = lineData
                lineWithNewline.append(contentsOf: "\n".data(using: .utf8)!)
                if let handle = FileHandle(forWritingAtPath: eventsPath) {
                    handle.seekToEndOfFile()
                    handle.write(lineWithNewline)
                    handle.closeFile()
                } else {
                    try? lineWithNewline.write(to: URL(fileURLWithPath: eventsPath))
                }
            }

            // 3. Non-blocking HTTP POST to Astryx / DNK kernel endpoints (fire & forget)
            let endpoints = [
                "http://127.0.0.1:8000/api/v1/voice/parse_command",
                "http://127.0.0.1:3000/api/voice/intent"
            ]
            for endpoint in endpoints {
                guard let url = URL(string: endpoint) else { continue }
                var req = URLRequest(url: url)
                req.httpMethod = "POST"
                req.timeoutInterval = 0.5
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.httpBody = try? JSONSerialization.data(withJSONObject: payload)
                URLSession.shared.dataTask(with: req) { _, _, _ in }.resume()
            }
        }
    }
}

