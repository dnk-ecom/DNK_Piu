import AppKit
import Foundation
import PiuCore

/// Global Hotkey Monitor for hold-to-talk voice dictation and double-tap hands-free mode.
final class DictationHotKey {
    static let shared = DictationHotKey()

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var isKeyDown = false
    private var keyDownTime: Double = 0
    private var lastTapUpTime: Double = 0
    private var tapTimer: DispatchWorkItem?

    private init() {}

    static func isAccessibilityGranted() -> Bool {
        AXIsProcessTrusted()
    }

    static func requestAccessibilityPermission() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func start() {
        guard globalMonitor == nil else { return }

        // Request system accessibility trust if not yet granted
        Self.requestAccessibilityPermission()

        // Global monitor catches keys while another app is frontmost (Terminal, Cursor, Browser)
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
            self?.handle(event: event)
        }

        // Local monitor catches keys while DNK_Piu itself is focused
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
            self?.handle(event: event)
            return event
        }
    }

    func stop() {
        if let g = globalMonitor { NSEvent.removeMonitor(g); globalMonitor = nil }
        if let l = localMonitor { NSEvent.removeMonitor(l); localMonitor = nil }
        tapTimer?.cancel()
        tapTimer = nil
    }

    private func handle(event: NSEvent) {
        if event.type == .keyDown {
            // Escape (keyCode 53) cancels dictation
            if event.keyCode == 53 && AudioDictation.shared.isRecording {
                AudioDictation.shared.cancel()
                return
            }

            // Keyboard shortcut fallback: Control + Option + D (toggle dictation)
            let flags = event.modifierFlags.intersection([.control, .option, .command])
            if flags == [.control, .option] && event.charactersIgnoringModifiers?.lowercased() == "d" {
                AudioDictation.shared.toggle()
                return
            }
            return
        }

        guard event.type == .flagsChanged else { return }

        let raw = event.modifierFlags.rawValue
        let keyCode = event.keyCode

        // Check target dictation keys:
        // 1. Right Option (keyCode 61, NX_DEVICERALTKEYMASK = 0x40)
        // 2. Fn / Globe key (keyCode 63, .function flag)
        // 3. Right Command (keyCode 54, NX_DEVICERCMDKEYMASK = 0x10)
        var isTargetKey = false
        var isDown = false

        if keyCode == 61 { // Right Option
            isTargetKey = true
            isDown = (raw & 0x0000_0040) != 0
        } else if keyCode == 63 || event.modifierFlags.contains(.function) { // Fn / Globe
            isTargetKey = true
            isDown = event.modifierFlags.contains(.function)
        } else if keyCode == 54 { // Right Command
            isTargetKey = true
            isDown = (raw & 0x0000_0010) != 0
        }

        guard isTargetKey else { return }

        let uptime = ProcessInfo.processInfo.systemUptime

        if isDown {
            guard !isKeyDown else { return }
            isKeyDown = true

            // Double-tap check within 0.38s -> Hands-Free mode
            if uptime - lastTapUpTime < 0.38 {
                tapTimer?.cancel()
                tapTimer = nil
                lastTapUpTime = 0
                AudioDictation.shared.start(locked: true)
            } else if AudioDictation.shared.phase == .idle {
                keyDownTime = uptime
                AudioDictation.shared.start(locked: false)
            } else if case .listening(let isLocked) = AudioDictation.shared.phase, isLocked {
                // In hands-free mode, pressing key again completes dictation
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

                if holdDuration >= 0.25 {
                    // Normal hold-to-talk: user held key while speaking and let go -> STOP & TRANSCRIBE!
                    AudioDictation.shared.stopAndTranscribe()
                } else {
                    // Quick tap -> wait for potential second tap
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
