import AppKit
import Combine
import PiuCore
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var dictationPanel: DictationPillPanel!
    private var statusItem: NSStatusItem?
    private var cancellables: Set<AnyCancellable> = []
    private let hotKey = DictationHotKey.shared
    private let dictation = AudioDictation.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. Configure dedicated floating dictation capsule pill (Wispr Flow / Superwhisper style)
        dictationPanel = DictationPillPanel()

        // 2. Start Global HotKey Monitor (Hold Option to speak / double-tap for hands-free)
        hotKey.start()

        // 3. Setup Menubar status item with direct click toggle and right-click context menu
        setupStatusBar()

        // 4. React to Dictation Phase to show/hide the pop-up capsule pill
        dictation.$phase
            .receive(on: DispatchQueue.main)
            .sink { [weak self] phase in
                guard let self = self else { return }
                if phase == .idle {
                    self.dictationPanel.hideAnimated()
                } else {
                    if !self.dictationPanel.isVisible {
                        self.dictationPanel.showAnimated()
                    }
                }
            }
            .store(in: &cancellables)
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem?.button else { return }

        // Elegant swallow icon in flight (Ластівка)
        if let image = NSImage(systemSymbolName: "swift", accessibilityDescription: "DNK_Piu (Ластівка)") {
            image.isTemplate = true
            button.image = image
        }
        button.target = self
        button.action = #selector(statusBarButtonClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        let menu = buildMenu()
        statusItem?.menu = menu
        sender.performClick(nil)
        DispatchQueue.main.async { [weak self] in
            self?.statusItem?.menu = nil
        }
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        populateMenu(menu)
        return menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        populateMenu(menu)
    }

    private func populateMenu(_ menu: NSMenu) {
        menu.removeAllItems()

        // Primary Voice Dictation Action
        let dictateTitle = dictation.isRecording ? "Зупинити диктування (Розпізнати)" : "Диктувати голосом (\(hotKey.activePreset.symbol))"
        let dictateItem = NSMenuItem(title: dictateTitle, action: #selector(toggleDictate), keyEquivalent: "d")
        dictateItem.target = self
        menu.addItem(dictateItem)
        menu.addItem(.separator())

        // Recent Dictated Transcripts (Click to copy / insert)
        let sectionHeader = NSMenuItem(title: "Журнал надиктовок:", action: nil, keyEquivalent: "")
        sectionHeader.isEnabled = false
        menu.addItem(sectionHeader)

        if !dictation.history.isEmpty {
            for item in dictation.history.prefix(5) {
                let preview = item.text.count > 36 ? "\(item.text.prefix(36))..." : item.text
                let menuItem = NSMenuItem(title: "  📋 \(preview)", action: #selector(pasteHistoryItem(_:)), keyEquivalent: "")
                menuItem.representedObject = item.text
                menuItem.target = self
                menu.addItem(menuItem)
            }
        } else {
            let emptyItem = NSMenuItem(title: "  (Історія сесії порожня)", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        }

        let openLogItem = NSMenuItem(title: "  📂 Відкрити журнал подій (JSONL)", action: #selector(openEventsLog), keyEquivalent: "")
        openLogItem.target = self
        menu.addItem(openLogItem)

        if !dictation.history.isEmpty {
            let clearHistoryItem = NSMenuItem(title: "  🗑 Очистити історію сесії", action: #selector(clearHistory), keyEquivalent: "")
            clearHistoryItem.target = self
            menu.addItem(clearHistoryItem)
        }
        menu.addItem(.separator())

        // HotKey Selection Submenu
        let hotKeyMenu = NSMenu()
        for preset in FlowKeyPreset.allCases {
            let item = NSMenuItem(title: preset.displayName, action: #selector(selectHotKeyPreset(_:)), keyEquivalent: "")
            item.representedObject = preset
            item.target = self
            if preset == hotKey.activePreset {
                item.state = .on
            }
            hotKeyMenu.addItem(item)
        }
        let hotKeyParent = NSMenuItem(title: "Налаштування клавіші диктування", action: nil, keyEquivalent: "")
        hotKeyParent.submenu = hotKeyMenu
        menu.addItem(hotKeyParent)

        // Accessibility Permission Status
        let isTrusted = DictationHotKey.isAccessibilityGranted()
        let axTitle = isTrusted ? "Дозволи Accessibility: Надано ✓" : "Дозволи Accessibility: Потрібно надати..."
        let accessibilityItem = NSMenuItem(title: axTitle, action: #selector(openAccessibility), keyEquivalent: "")
        accessibilityItem.target = self
        menu.addItem(accessibilityItem)

        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Вийти з DNK_Piu", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    @objc private func toggleDictate() {
        dictation.toggle()
    }

    @objc private func pasteHistoryItem(_ sender: NSMenuItem) {
        if let text = sender.representedObject as? String {
            FlowPaste.insert(text)
        }
    }

    @objc private func clearHistory() {
        dictation.clearHistory()
    }

    @objc private func openEventsLog() {
        let path = ("~/.dnk_runtime/piu/voice_events.jsonl" as NSString).expandingTildeInPath
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    @objc private func selectHotKeyPreset(_ sender: NSMenuItem) {
        if let preset = sender.representedObject as? FlowKeyPreset {
            hotKey.setPreset(preset)
        }
    }

    @objc private func openAccessibility() {
        DictationHotKey.openAccessibilitySettings()
    }

    @objc private func quit() {
        hotKey.stop()
        dictationPanel?.orderOut(nil)
        NSApp.terminate(nil)
    }
}

// Application Entry Point
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
