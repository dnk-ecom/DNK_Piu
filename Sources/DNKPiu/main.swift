import AppKit
import Combine
import PiuCore
import SwiftUI

/// Floating, nonactivating panel that accepts input without stealing focus from active editor/terminal.
final class PiuPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
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

        // 4. Setup Menubar status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.title = "Piu"
        statusItem?.button?.image = NSImage(systemSymbolName: "cpu", accessibilityDescription: "DNK_Piu")

        let menu = NSMenu()
        menu.addItem(withTitle: "Toggle DNK_Piu Widget", action: #selector(toggleVisible), keyEquivalent: "p")
        menu.addItem(withTitle: "Dictate Voice (Hold Right ⌥)", action: #selector(toggleDictate), keyEquivalent: "d")
        menu.addItem(withTitle: "Reset Position to Top-Right", action: #selector(resetCorner), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit DNK_Piu", action: #selector(quit), keyEquivalent: "q")
        for entry in menu.items { entry.target = self }
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
        let targetSize = expanded ? CGSize(width: Layout.panelWidth, height: 380) : Layout.pill

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
