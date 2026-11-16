import AppKit
import Combine
import PiuCore
import SwiftUI

/// Floating, nonactivating panel that accepts input without stealing focus from active editor/terminal.
final class PiuPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    private let store = PiuStore()
    private var panel: PiuPanel!
    private var dictationPanel: DictationPillPanel!
    private var statusItem: NSStatusItem?
    private var cancellables: Set<AnyCancellable> = []
    private let hotKey = DictationHotKey.shared
    private let cornerKey = "piuTopRight"

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

        // 5. React to companion panel expansion
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

        let dictateItem = NSMenuItem(title: "Dictate Voice (Hold Right ⌥)", action: #selector(toggleDictate), keyEquivalent: "d")
        dictateItem.target = self
        menu.addItem(dictateItem)

        let resetItem = NSMenuItem(title: "Reset Position to Top-Right", action: #selector(resetCorner), keyEquivalent: "")
        resetItem.target = self
        menu.addItem(resetItem)

        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit DNK_Piu", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    @objc private func copyHistoryItem(_ sender: NSMenuItem) {
        if let text = sender.representedObject as? String {
            FlowPaste.insert(text)
        }
    }

    private func positionPanel() {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let x = visible.maxX - Layout.pill.width - 20
        let y = visible.maxY - Layout.pill.height - 10
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func fit(expanded: Bool) {
        let currentOrigin = panel.frame.origin
        let currentHeight = panel.frame.height
        let targetSize = expanded ? CGSize(width: Layout.panelWidth, height: 420) : Layout.pill

        // Maintain top-right anchor when expanding
        let newY = currentOrigin.y + (currentHeight - targetSize.height)
        let newX = panel.frame.maxX - targetSize.width

        panel.setFrame(NSRect(origin: NSPoint(x: newX, y: newY), size: targetSize), display: true, animate: true)
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
app.setActivationPolicy(.accessory) // Runs cleanly as an accessory without dock clutter
app.run()
