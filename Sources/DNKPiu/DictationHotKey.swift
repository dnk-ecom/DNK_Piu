import AppKit
import Carbon.HIToolbox
import Foundation
import PiuCore

/// Supported physical hold-to-talk preset keys (strictly mutually exclusive single keys).
public enum FlowKeyPreset: String, CaseIterable, Identifiable {
    case rightOption = "rightOption"   // Right Option (⌥) - Canonical Default!
    case leftOption = "leftOption"     // Left Option (⌥)
    case fn = "fn"                     // Fn / Globe (🌐)
    case rightCommand = "rightCommand" // Right Command (⌘)
    case rightControl = "rightControl" // Right Control (⌃)

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .rightOption: return "Правий Option (Right ⌥)"
        case .leftOption: return "Лівий Option (Left ⌥)"
        case .fn: return "Fn / Globe (🌐)"
        case .rightCommand: return "Правий Command (Right ⌘)"
        case .rightControl: return "Правий Control (Right ⌃)"
        }
    }

    public var symbol: String {
        switch self {
        case .rightOption: return "⌥R"
        case .leftOption: return "⌥L"
        case .fn: return "🌐"
        case .rightCommand: return "⌘R"
        case .rightControl: return "⌃R"
        }
    }

    /// Primary physical key code sent by macOS on flagsChanged.
    public var keyCode: UInt16 {
        switch self {
        case .rightOption: return UInt16(kVK_RightOption) // 61
        case .leftOption: return UInt16(kVK_Option) // 58
        case .fn: return UInt16(kVK_Function) // 63
        case .rightCommand: return UInt16(kVK_RightCommand) // 54
        case .rightControl: return UInt16(kVK_RightControl) // 62
        }
    }

    /// Evaluates if the incoming flagsChanged event matches this key preset.
    public func matches(keyCode: UInt16) -> Bool {
        switch self {
        case .rightOption:
            return keyCode == UInt16(kVK_RightOption)
        case .leftOption:
            return keyCode == UInt16(kVK_Option)
        case .fn:
            return keyCode == UInt16(kVK_Function)
        case .rightCommand:
            return keyCode == UInt16(kVK_RightCommand)
        case .rightControl:
            return keyCode == UInt16(kVK_RightControl)
        }
    }

    /// Evaluates if this specific modifier key is held down (strict device-dependent hardware bitmask).
    public func isDown(_ flags: NSEvent.ModifierFlags) -> Bool {
        let raw = flags.rawValue
        switch self {
        case .rightOption:
            // NX_DEVICERALTKEYMASK = 0x0000_0040 (strictly right option only)
            return (raw & 0x0000_0040) != 0
        case .leftOption:
            // NX_DEVICELALTKEYMASK = 0x0000_0020 (strictly left option only)
            return (raw & 0x0000_0020) != 0
        case .fn:
            return flags.contains(.function)
        case .rightCommand:
            // NX_DEVICERCMDKEYMASK = 0x0000_0010 (strictly right command only)
            return (raw & 0x0000_0010) != 0
        case .rightControl:
            // NX_DEVICERCTLKEYMASK = 0x0000_2000 (strictly right control only)
            return (raw & 0x0000_2000) != 0
        }
    }
}

/// Global Hotkey Monitor for hold-to-talk voice dictation and double-tap hands-free mode.
public final class DictationHotKey: ObservableObject {
    public static let shared = DictationHotKey()

    private static let keyPref = "piu_dictation_key"

    @Published public var activePreset: FlowKeyPreset {
        didSet {
            UserDefaults.standard.set(activePreset.rawValue, forKey: Self.keyPref)
        }
    }

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var isKeyDown = false
    private var keyDownTime: Double = 0
    private var lastTapUpTime: Double = 0
    private var tapTimer: DispatchWorkItem?
    private var trustTask: Task<Void, Never>?

    private init() {
        if let saved = UserDefaults.standard.string(forKey: Self.keyPref),
           let preset = FlowKeyPreset(rawValue: saved) {
            self.activePreset = preset
        } else {
            self.activePreset = .rightOption // Default to Right Option (Right ⌥) so Left Option is free!
        }
    }

    public static func isAccessibilityGranted() -> Bool {
        AXIsProcessTrusted()
    }

    public static func requestAccessibilityPermission() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    public static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    public func setPreset(_ preset: FlowKeyPreset) {
        self.activePreset = preset
    }

    public func start() {
        guard globalMonitor == nil else { return }

        // Request system accessibility trust if not yet granted
        if !Self.isAccessibilityGranted() {
            Self.requestAccessibilityPermission()
            waitForTrust()
        }

        // Global monitor catches keys while another app is frontmost (Cursor, Ghostty, Terminal, Safari)
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
            self?.handle(event: event)
        }

        // Local monitor catches keys while DNK_Piu itself is focused
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
            self?.handle(event: event)
            return event
        }

        // Auto re-arm on system wake
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.stop()
            self?.start()
        }
    }

    private func waitForTrust() {
        trustTask?.cancel()
        trustTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard let self = self else { return }
                if Self.isAccessibilityGranted() {
                    self.stop()
                    self.start()
                    return
                }
            }
        }
    }

    public func stop() {
        trustTask?.cancel()
        trustTask = nil
        if let g = globalMonitor { NSEvent.removeMonitor(g); globalMonitor = nil }
        if let l = localMonitor { NSEvent.removeMonitor(l); localMonitor = nil }
        tapTimer?.cancel()
        tapTimer = nil
    }

    private func handle(event: NSEvent) {
        if event.type == .keyDown {
            // Escape (keyCode 53) cancels dictation immediately
            if event.keyCode == 53 && AudioDictation.shared.isRecording {
                AudioDictation.shared.cancel()
                return
            }

            // Keyboard shortcut toggle: ⌃⌥D (Control + Option + D)
            let flags = event.modifierFlags.intersection([.control, .option, .command])
            if flags == [.control, .option] && event.charactersIgnoringModifiers?.lowercased() == "d" {
                AudioDictation.shared.toggle()
                return
            }
            return
        }

        guard event.type == .flagsChanged else { return }

        let isDown = activePreset.isDown(event.modifierFlags)
        let matchesKey = activePreset.matches(keyCode: event.keyCode)

        // Resilient modifier tracking:
        // If the key is physically no longer down according to system modifier flags,
        // ALWAYS process as release even if event.keyCode doesn't match (e.g. multi-key release).
        if isKeyDown && !isDown {
            // Fall through to release logic below
        } else if !matchesKey {
            return
        }

        let uptime = ProcessInfo.processInfo.systemUptime

        if isDown {
            guard !isKeyDown else { return }
            isKeyDown = true

            // Double-tap detection within 0.38s -> Hands-Free Mode (Locked)
            if uptime - lastTapUpTime < 0.38 {
                tapTimer?.cancel()
                tapTimer = nil
                lastTapUpTime = 0
                AudioDictation.shared.start(locked: true)
            } else if case .listening(let isLocked) = AudioDictation.shared.phase, isLocked {
                // In hands-free mode, pressing the key again finishes dictation
                AudioDictation.shared.stopAndTranscribe()
            } else if case .listening(false) = AudioDictation.shared.phase {
                // Already recording hold-to-talk: avoid redundant start
                return
            } else {
                // Clean recovery from idle, failed, done, or lingering thinking: start fresh dictation!
                keyDownTime = uptime
                AudioDictation.shared.start(locked: false)
            }
        } else {
            guard isKeyDown else { return }
            isKeyDown = false
            let holdDuration = uptime - keyDownTime

            if case .listening(let isLocked) = AudioDictation.shared.phase {
                if isLocked {
                    // In hands-free mode, key release does not stop recording
                    return
                }

                if holdDuration >= 0.18 {
                    // Normal hold-to-talk: user held key while speaking and let go -> STOP & TRANSCRIBE!
                    AudioDictation.shared.stopAndTranscribe()
                } else {
                    // Short tap (<0.18s): wait for possible second tap
                    lastTapUpTime = uptime
                    let workItem = DispatchWorkItem { [weak self] in
                        guard self != nil else { return }
                        if case .listening(let locked) = AudioDictation.shared.phase, !locked {
                            AudioDictation.shared.cancel()
                        }
                    }
                    tapTimer = workItem
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.38, execute: workItem)
                }
            } else if AudioDictation.shared.isRecording {
                // Safeguard: if phase desynced from isRecording, stop and transcribe anyway
                AudioDictation.shared.stopAndTranscribe()
            }
        }
    }
}
