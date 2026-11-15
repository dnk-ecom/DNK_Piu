import AppKit
import AVFoundation
import Foundation

/// High-velocity voice dictation engine powered by Google Cloud Vertex AI (Gemini 3.8 Flash Multimodal Audio).
public final class AudioDictation: NSObject, ObservableObject, AVAudioRecorderDelegate {
    public static let shared = AudioDictation()

    @Published public private(set) var isRecording = false
    @Published public private(set) var isProcessing = false
    @Published public var lastTranscript: String = ""
    @Published public var errorMessage: String? = nil

    private var recorder: AVAudioRecorder?
    private let recordingURL = URL(fileURLWithPath: "/tmp/dnk_piu_audio.wav")
    private let bridgeURL = URL(string: "http://127.0.0.1:11435/v1/audio/transcriptions")!

    private override init() {
        super.init()
    }

    /// Toggles or starts voice dictation.
    public func toggle() {
        if isRecording {
            stopAndTranscribe()
        } else {
            start()
        }
    }

    /// Starts recording microphone input.
    public func start() {
        guard !isRecording else { return }

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
            recorder?.delegate = self
            recorder?.record()
            DispatchQueue.main.async {
                self.isRecording = true
                self.errorMessage = nil
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Failed to start audio recording: \(error.localizedDescription)"
            }
        }
    }

    /// Stops recording and sends the audio to Vertex AI Gemini 3.8 Flash for transcription.
    public func stopAndTranscribe(insertAutomatically: Bool = true, completion: ((String?) -> Void)? = nil) {
        guard isRecording else { return }

        recorder?.stop()
        recorder = nil

        DispatchQueue.main.async {
            self.isRecording = false
            self.isProcessing = true
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            defer {
                DispatchQueue.main.async {
                    self.isProcessing = false
                }
            }

            guard let audioData = try? Data(contentsOf: self.recordingURL), !audioData.isEmpty else {
                DispatchQueue.main.async {
                    self.errorMessage = "No audio data recorded"
                    completion?(nil)
                }
                return
            }

            let base64Audio = audioData.base64EncodedString()
            let payload: [String: Any] = [
                "audio_base64": base64Audio,
                "mime_type": "audio/wav",
                "prompt": "Транскрибуй мову розробника (uk-UA / en-US). Зберігай технічні назви та сленг в оригіналі (Shopify, Clyro, Antigravity, commit, branch, PR, Swift, Python). Автоматично розставляй розділові знаки. Повертай ВИКЛЮЧНО текст без коментарів."
            ]

            var request = URLRequest(url: self.bridgeURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 12.0

            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Serialization error: \(error.localizedDescription)"
                    completion?(nil)
                }
                return
            }

            let semaphore = DispatchSemaphore(value: 0)
            var returnedText: String? = nil

            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                defer { semaphore.signal() }

                if let error = error {
                    DispatchQueue.main.async {
                        self.errorMessage = "Bridge request failed: \(error.localizedDescription)"
                    }
                    return
                }

                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let text = json["text"] as? String else {
                    DispatchQueue.main.async {
                        self.errorMessage = "Invalid response from Vertex AI audio bridge"
                    }
                    return
                }

                returnedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            task.resume()
            _ = semaphore.wait(timeout: .now() + 15.0)

            if let transcript = returnedText, !transcript.isEmpty {
                DispatchQueue.main.async {
                    self.lastTranscript = transcript
                    if insertAutomatically {
                        FlowPaste.insert(transcript)
                    }
                    completion?(transcript)
                }
            } else {
                DispatchQueue.main.async {
                    completion?(nil)
                }
            }
        }
    }
}

/// Transient pasteboard injector simulating ⌘V with clipboard preservation.
public enum FlowPaste {
    public static func insert(_ text: String) {
        guard !text.isEmpty else { return }

        let pasteboard = NSPasteboard.general
        let previousChangeCount = pasteboard.changeCount

        // 1. Snapshot previous clipboard items
        var previousItems: [(NSPasteboard.PasteboardType, Data)] = []
        if let items = pasteboard.pasteboardItems {
            for item in items {
                for type in item.types {
                    if let data = item.data(forType: type) {
                        previousItems.append((type, data))
                    }
                }
            }
        }

        // 2. Set transient text
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Mark as transient for Raycast / Paste / Maccy
        let transientType = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")
        let autoGeneratedType = NSPasteboard.PasteboardType("org.nspasteboard.AutoGeneratedType")
        pasteboard.setData(Data(), forType: transientType)
        pasteboard.setData(Data(), forType: autoGeneratedType)

        // 3. Synthesize ⌘V keystroke
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKeyCode: CGKeyCode = 0x09 // ANSI 'V' keycode

        let down = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand

        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)

        // 4. Restore clipboard after 700 ms if not modified by user
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            if pasteboard.changeCount == previousChangeCount + 1 && !previousItems.isEmpty {
                pasteboard.clearContents()
                for (type, data) in previousItems {
                    pasteboard.setData(data, forType: type)
                }
            }
        }
    }
}
