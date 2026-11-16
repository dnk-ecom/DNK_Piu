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

    func start() {
        guard globalMonitor == nil else { return }

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
            }
            return
        }

        guard event.type == .flagsChanged else { return }

        // NX_DEVICERALTKEYMASK = 0x0000_0040 (Right Option)
        // NX_DEVICEFunctionKey = Fn / Globe key
        let raw = event.modifierFlags.rawValue
        let isRightOption = (raw & 0x0000_0040 != 0) || (event.keyCode == 61)

        let uptime = ProcessInfo.processInfo.systemUptime

        if isRightOption {
            if !isKeyDown {
                // Key pressed DOWN
                isKeyDown = true

                // Check for double-tap within 0.38s
                if uptime - lastTapUpTime < 0.38 {
                    tapTimer?.cancel()
                    tapTimer = nil
                    lastTapUpTime = 0
                    // Double-tap detected -> lock into hands-free mode!
                    AudioDictation.shared.start(locked: true)
                } else if AudioDictation.shared.phase == .idle {
                    keyDownTime = uptime
                    AudioDictation.shared.start(locked: false)
                } else if case .listening(let isLocked) = AudioDictation.shared.phase, isLocked {
                    // In hands-free mode, pressing Right Option again completes the dictation
                    AudioDictation.shared.stopAndTranscribe()
                }
            }
        } else {
            if isKeyDown {
                // Key released UP
                isKeyDown = false
                let holdDuration = uptime - keyDownTime

                if case .listening(let isLocked) = AudioDictation.shared.phase {
                    if isLocked {
                        // In hands-free mode, release does not stop recording
                        return
                    }

                    if holdDuration >= 0.28 {
                        // Normal hold-to-talk: user held the key while speaking and let go
                        AudioDictation.shared.stopAndTranscribe()
                    } else {
                        // Quick tap: wait briefly to see if user taps a second time
                        lastTapUpTime = uptime
                        let workItem = DispatchWorkItem { [weak self] in
                            guard self != nil else { return }
                            if case .listening(let locked) = AudioDictation.shared.phase, !locked {
                                // Tap timed out with no hold: cancel recording
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
}
