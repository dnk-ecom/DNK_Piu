import AppKit
import Carbon.HIToolbox
import Foundation
import PiuCore

/// Supported physical hold-to-talk preset keys (like Coucou v0.6.0 FlowKey).
public enum FlowKeyPreset: String, CaseIterable, Identifiable {
    case rightOption = "rightOption"
    case fn = "fn"
    case rightCommand = "rightCommand"
    case rightControl = "rightControl"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .rightOption: return "Right Option (⌥)"
        case .fn: return "Fn / Globe"
        case .rightCommand: return "Right Command (⌘)"
        case .rightControl: return "Right Control (⌃)"
        }
    }

    public var symbol: String {
        switch self {
        case .rightOption: return "⌥"
        case .fn: return "fn"
        case .rightCommand: return "⌘"
        case .rightControl: return "⌃"
        }
    }

    /// Exact physical key code sent by macOS on flagsChanged.
    public var keyCode: UInt16 {
        switch self {
        case .rightOption: return UInt16(kVK_RightOption) // 61
        case .fn: return UInt16(kVK_Function) // 63
        case .rightCommand: return UInt16(kVK_RightCommand) // 54
        case .rightControl: return UInt16(kVK_RightControl) // 62
        }
    }

    /// Evaluates if this specific modifier key is held down.
    /// Device-dependent bits differentiate the right key from the left key.
    public func isDown(_ flags: NSEvent.ModifierFlags) -> Bool {
        let raw = flags.rawValue
        switch self {
        case .rightOption:
            // NX_DEVICERALTKEYMASK = 0x0000_0040
            return (raw & 0x0000_0040) != 0
        case .fn:
            // kVK_Function (63) with .function flag
            return flags.contains(.function)
        case .rightCommand:
            // NX_DEVICERCMDKEYMASK = 0x0000_0010
            return (raw & 0x0000_0010) != 0
        case .rightControl:
            // NX_DEVICERCTLKEYMASK = 0x0000_2000
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

    private init() {
        if let saved = UserDefaults.standard.string(forKey: Self.keyPref),
           let preset = FlowKeyPreset(rawValue: saved) {
            self.activePreset = preset
        } else {
            self.activePreset = .rightOption
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
        Self.requestAccessibilityPermission()

        // Global monitor catches keys while another app is frontmost (Cursor, Ghostty, Terminal, Safari)
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
            self?.handle(event: event)
        }

        // Local monitor catches keys while DNK_Piu itself is focused
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
            self?.handle(event: event)
            return event
        }
    }

    public func stop() {
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

        // CRITICAL: We ONLY handle flagsChanged events where event.keyCode matches our configured preset!
        // This completely prevents arrow keys (123-126) and other function/modifier keys from triggering dictation.
        guard event.keyCode == activePreset.keyCode else { return }

        let isDown = activePreset.isDown(event.modifierFlags)
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
            } else if AudioDictation.shared.phase == .idle {
                keyDownTime = uptime
                AudioDictation.shared.start(locked: false)
            } else if case .listening(let isLocked) = AudioDictation.shared.phase, isLocked {
                // In hands-free mode, pressing the key again finishes dictation
                AudioDictation.shared.stopAndTranscribe()
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

                if holdDuration >= 0.22 {
                    // Normal hold-to-talk: user held key while speaking and let go -> STOP & TRANSCRIBE!
                    AudioDictation.shared.stopAndTranscribe()
                } else {
                    // Short tap (<0.22s): wait for possible second tap
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
            }
        }
    }
}
