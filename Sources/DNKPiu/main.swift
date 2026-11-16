import AppKit
import Combine
import PiuCore
import SwiftUI

/// Floating, nonactivating panel that accepts input without stealing focus from active editor/terminal.
final class PiuPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    private let store = PiuStore()
    private var panel: PiuPanel!
    private var dictationPanel: DictationPillPanel!
    private var statusItem: NSStatusItem?
    private var cancellables: Set<AnyCancellable> = []
    private let hotKey = DictationHotKey.shared
    private let margin: CGFloat = 16
    private let topMargin: CGFloat = 8

    func applicationDidFinishLaunching(_ notification: Notification) {
        store.start()

        // 1. Configure main floating companion panel (Top-Right)
        panel = PiuPanel(
            contentRect: NSRect(origin: .zero, size: Layout.pill),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: RootView(store: store))
        panel.delegate = self

        positionPanel()
        panel.orderFrontRegardless()

        // 2. Configure dedicated pop-up dictation pill (Bottom Center, Coucou-style)
        dictationPanel = DictationPillPanel()

        // 3. Start Global HotKey Monitor (Right Option hold-to-talk / double-tap hands-free)
        hotKey.start()

        // 4. Setup Menubar status item with dynamic delegate
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.title = "Piu"
        statusItem?.button?.image = NSImage(systemSymbolName: "cpu", accessibilityDescription: "DNK_Piu")

        let menu = NSMenu()
        menu.delegate = self
        statusItem?.menu = menu

        // 5. React to companion panel expansion with safe bounds animation
        store.$expanded
            .receive(on: DispatchQueue.main)
            .sink { [weak self] expanded in
                self?.fit(expanded: expanded)
            }
            .store(in: &cancellables)

        // 6. React to Dictation Phase to show/hide the pop-up pill
        store.dictation.$phase
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

    func menuWillOpen(_ menu: NSMenu) {
        menu.removeAllItems()

        // TOP SECTION IN MENU: Recent dictated texts
        if !store.dictation.history.isEmpty {
            let header = NSMenuItem(title: "🎙️ Надиктовано (останні):", action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)

            for item in store.dictation.history.prefix(3) {
                let preview = item.text.count > 34 ? "\(item.text.prefix(34))..." : item.text
                let menuItem = NSMenuItem(title: "  📋 \"\(preview)\"", action: #selector(copyHistoryItem(_:)), keyEquivalent: "")
                menuItem.representedObject = item.text
                menuItem.target = self
                menu.addItem(menuItem)
            }
            menu.addItem(.separator())
        }

        let toggleItem = NSMenuItem(title: "Toggle DNK_Piu Widget", action: #selector(toggleVisible), keyEquivalent: "p")
        toggleItem.target = self
        menu.addItem(toggleItem)

        let dictateItem = NSMenuItem(
            title: "Dictate Voice (\(hotKey.activePreset.displayName))",
            action: #selector(toggleDictate),
            keyEquivalent: "d"
        )
        dictateItem.target = self
        menu.addItem(dictateItem)

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

        let resetItem = NSMenuItem(title: "Скинути позицію у правий кут", action: #selector(resetCorner), keyEquivalent: "")
        resetItem.target = self
        menu.addItem(resetItem)

        menu.addItem(.separator())
        let accessibilityItem = NSMenuItem(title: "Дозволи Accessibility...", action: #selector(openAccessibility), keyEquivalent: "")
        accessibilityItem.target = self
        menu.addItem(accessibilityItem)

        let quitItem = NSMenuItem(title: "Вийти з DNK_Piu", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    @objc private func selectHotKeyPreset(_ sender: NSMenuItem) {
        if let preset = sender.representedObject as? FlowKeyPreset {
            hotKey.setPreset(preset)
        }
    }

    @objc private func copyHistoryItem(_ sender: NSMenuItem) {
        if let text = sender.representedObject as? String {
            FlowPaste.insert(text)
        }
    }

    @objc private func openAccessibility() {
        DictationHotKey.openAccessibilitySettings()
    }

    private func positionPanel() {
        guard let screen = panel?.screen ?? NSScreen.main ?? NSScreen.screens.first else { return }
        let visible = screen.visibleFrame
        let targetWidth: CGFloat = store.expanded ? Layout.panelWidth : Layout.pill.width
        let targetHeight: CGFloat = store.expanded ? min(Layout.maxPanelHeight, visible.height - 40) : Layout.pill.height

        let desiredX = visible.maxX - targetWidth - margin
        let desiredY = visible.maxY - targetHeight - topMargin

        let clampedX = min(max(desiredX, visible.minX + margin), visible.maxX - targetWidth - margin)
        let clampedY = min(max(desiredY, visible.minY + margin), visible.maxY - targetHeight - topMargin)

        panel.setFrame(NSRect(x: clampedX, y: clampedY, width: targetWidth, height: targetHeight), display: true, animate: false)
    }

    private func fit(expanded: Bool) {
        guard let screen = panel?.screen ?? NSScreen.main ?? NSScreen.screens.first else { return }
        let visible = screen.visibleFrame
        let targetWidth: CGFloat = expanded ? Layout.panelWidth : Layout.pill.width
        let targetHeight: CGFloat = expanded ? min(Layout.maxPanelHeight, visible.height - 40) : Layout.pill.height

        // Explicitly anchor to top-right of visible frame with strict clamping inside screen borders
        let desiredX = visible.maxX - targetWidth - margin
        let desiredY = visible.maxY - targetHeight - topMargin

        let clampedX = min(max(desiredX, visible.minX + margin), visible.maxX - targetWidth - margin)
        let clampedY = min(max(desiredY, visible.minY + margin), visible.maxY - targetHeight - topMargin)

        panel.setFrame(NSRect(x: clampedX, y: clampedY, width: targetWidth, height: targetHeight), display: true, animate: true)
    }

    @objc private func toggleVisible() {
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.orderFrontRegardless()
        }
    }

    @objc private func toggleDictate() {
        store.dictation.toggle()
    }

    @objc private func resetCorner() {
        positionPanel()
    }

    @objc private func quit() {
        hotKey.stop()
        dictationPanel?.orderOut(nil)
        store.stop()
        NSApp.terminate(nil)
    }
}

// Application Entry Point
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // Runs cleanly as a status bar accessory without dock clutter
app.run()
