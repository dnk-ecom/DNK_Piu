import AppKit
import Combine
import PiuCore
import SwiftUI

/// Astryx Design Style context menu header view displaying real-time status and branding.
struct AstryxMenuHeaderView: View {
    @ObservedObject private var dictation = AudioDictation.shared
    let activePreset: FlowKeyPreset

    var body: some View {
        HStack(spacing: 10) {
            // Swallow Icon Badge (Astryx Identity)
            Image(systemName: "swift")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AstryxTheme.swallowGradient)
                .scaleEffect(x: -1, y: 1)
                .frame(width: 26, height: 26)
                .background(
                    Circle()
                        .fill(AstryxTheme.elevated)
                        .overlay(Circle().stroke(AstryxTheme.borderSubtle, lineWidth: AstryxTheme.borderWidth))
                )

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text("DNK_Piu")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("VOICE")
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .foregroundColor(AstryxTheme.cyan)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(AstryxTheme.cyan.opacity(0.18)))
                }

                Text(statusSubtitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
            }

            Spacer()

            // Status Indicator Dot
            Circle()
                .fill(statusIndicatorColor)
                .frame(width: 7, height: 7)
                .shadow(color: statusIndicatorColor.opacity(0.8), radius: 3)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(width: 250, height: 44)
        .background(AstryxTheme.panel)
    }

    private var statusSubtitle: String {
        switch dictation.phase {
        case .listening(let locked):
            return locked ? "Hands-free запис..." : "Запис голосу..."
        case .thinking:
            return "Обробка Gemini..."
        case .done:
            return "Готово"
        case .failed:
            return "Помилка"
        case .idle:
            return "Гаряча клавіша: \(activePreset.symbol)"
        }
    }

    private var statusIndicatorColor: Color {
        switch dictation.phase {
        case .listening: return AstryxTheme.red
        case .thinking: return AstryxTheme.purple
        case .done: return AstryxTheme.emerald
        case .failed: return AstryxTheme.red
        case .idle: return AstryxTheme.emerald
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var dictationPanel: DictationPillPanel!
    private var statusItem: NSStatusItem?
    private var cancellables: Set<AnyCancellable> = []
    private let hotKey = DictationHotKey.shared
    private let dictation = AudioDictation.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. Configure dedicated floating dictation capsule pill (Astryx / Wispr Flow style)
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

        // 1. Astryx Header Component
        let headerItem = NSMenuItem()
        let headerView = NSHostingView(rootView: AstryxMenuHeaderView(activePreset: hotKey.activePreset))
        headerView.frame = NSRect(x: 0, y: 0, width: 250, height: 44)
        headerItem.view = headerView
        menu.addItem(headerItem)
        menu.addItem(.separator())

        // 2. Primary Voice Dictation Action
        let dictateTitle = dictation.isRecording ? "Зупинити диктування (Розпізнати)" : "Диктувати голосом (\(hotKey.activePreset.symbol))"
        let dictateItem = NSMenuItem(title: dictateTitle, action: #selector(toggleDictate), keyEquivalent: "d")
        dictateItem.target = self
        if let icon = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: nil) {
            dictateItem.image = icon
        }
        menu.addItem(dictateItem)
        menu.addItem(.separator())

        // 3. Dedicated Native History Window Action (⌘H)
        let historyWindowItem = NSMenuItem(title: "Відкрити журнал надиктовок...", action: #selector(openHistoryWindow), keyEquivalent: "h")
        historyWindowItem.target = self
        if let icon = NSImage(systemSymbolName: "clock.arrow.circlepath", accessibilityDescription: nil) {
            historyWindowItem.image = icon
        }
        menu.addItem(historyWindowItem)
        menu.addItem(.separator())

        // 4. Quick Recent Dictated Transcripts (Click to copy / insert)
        let sectionHeader = NSMenuItem(title: "Останні надиктовки (клік для вставки):", action: nil, keyEquivalent: "")
        sectionHeader.isEnabled = false
        menu.addItem(sectionHeader)

        if !dictation.history.isEmpty {
            for item in dictation.history.prefix(5) {
                let preview = item.text.count > 34 ? "\(item.text.prefix(34))..." : item.text
                let menuItem = NSMenuItem(title: preview, action: #selector(pasteHistoryItem(_:)), keyEquivalent: "")
                menuItem.representedObject = item.text
                menuItem.target = self
                if let icon = NSImage(systemSymbolName: "text.quote", accessibilityDescription: nil) {
                    menuItem.image = icon
                }
                menu.addItem(menuItem)
            }
        } else {
            let emptyItem = NSMenuItem(title: "(Історія сесії порожня)", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            if let icon = NSImage(systemSymbolName: "waveform.slash", accessibilityDescription: nil) {
                emptyItem.image = icon
            }
            menu.addItem(emptyItem)
        }

        if !dictation.history.isEmpty {
            let clearHistoryItem = NSMenuItem(title: "Очистити історію сесії", action: #selector(clearHistory), keyEquivalent: "")
            clearHistoryItem.target = self
            if let icon = NSImage(systemSymbolName: "trash", accessibilityDescription: nil) {
                clearHistoryItem.image = icon
            }
            menu.addItem(clearHistoryItem)
        }
        menu.addItem(.separator())

        // 5. HotKey Selection Submenu
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
        let hotKeyParent = NSMenuItem(title: "Клавіша диктування", action: nil, keyEquivalent: "")
        if let icon = NSImage(systemSymbolName: "keyboard", accessibilityDescription: nil) {
            hotKeyParent.image = icon
        }
        hotKeyParent.submenu = hotKeyMenu
        menu.addItem(hotKeyParent)

        // 6. Accessibility Permission Status
        let isTrusted = DictationHotKey.isAccessibilityGranted()
        let axTitle = isTrusted ? "Дозволи Accessibility: Надано ✓" : "Дозволи Accessibility: Потрібно надати..."
        let accessibilityItem = NSMenuItem(title: axTitle, action: #selector(openAccessibility), keyEquivalent: "")
        accessibilityItem.target = self
        if let icon = NSImage(systemSymbolName: isTrusted ? "checkmark.shield.fill" : "exclamationmark.shield", accessibilityDescription: nil) {
            accessibilityItem.image = icon
        }
        menu.addItem(accessibilityItem)

        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Вийти з DNK_Piu", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        if let icon = NSImage(systemSymbolName: "power", accessibilityDescription: nil) {
            quitItem.image = icon
        }
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

    @objc private func openHistoryWindow() {
        HistoryWindowController.shared.showHistory()
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
