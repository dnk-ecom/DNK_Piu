import AppKit
import Combine
import PiuCore
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var dictationPanel: DictationPillPanel!
    private var statusItem: NSStatusItem?
    private var popover: NSPopover!
    private var cancellables: Set<AnyCancellable> = []
    private let hotKey = DictationHotKey.shared
    private let dictation = AudioDictation.shared
    private let popoverViewModel = PopoverViewModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. Configure dedicated floating dictation capsule pill (Wispr Flow / Astryx style)
        dictationPanel = DictationPillPanel()

        // 2. Start Global HotKey Monitor (Hold Option to speak / double-tap for hands-free)
        hotKey.start()

        // 3. Setup Menubar status item with modern NSPopover
        setupStatusBar()

        // 4. React to Dictation Phase to show/hide the pop-up capsule pill and update status icon
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
                self.updateStatusBarIcon(for: phase)
            }
            .store(in: &cancellables)

        // 5. IPC listeners to show history HUD and toggle dictation from CLI/Scripts
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.dnk.piu.showHistory"),
            object: nil,
            queue: .main
        ) { _ in
            HistoryWindowController.shared.showHistory()
        }

        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.dnk.piu.toggleDictate"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.toggleDictate()
        }

        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.dnk.piu.togglePopover"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self, let button = self.statusItem?.button else { return }
            self.statusBarButtonClicked(button)
        }

        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.dnk.piu.showSettings"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            self.popoverViewModel.showSettings = true
            if !self.popover.isShown {
                self.showPopover()
            }
        }

        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.dnk.piu.showDashboard"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            self.popoverViewModel.showSettings = false
            if !self.popover.isShown {
                self.showPopover()
            }
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            if url.host == "history" || url.path == "/history" {
                HistoryWindowController.shared.showHistory()
            } else if url.host == "settings" || url.path == "/settings" {
                popoverViewModel.showSettings = true
                if !popover.isShown {
                    showPopover()
                }
            } else if url.host == "menu" || url.path == "/menu" {
                if let button = statusItem?.button {
                    statusBarButtonClicked(button)
                }
            }
        }
    }

    private func updateStatusBarIcon(for phase: DictationPhase) {
        guard let button = statusItem?.button else { return }
        switch phase {
        case .listening:
            button.contentTintColor = NSColor(hex: "#EF4444")
        case .thinking:
            button.contentTintColor = NSColor(hex: "#3B82F6")
        case .done:
            button.contentTintColor = NSColor(hex: "#36F4A4")
        default:
            button.contentTintColor = nil
        }
    }

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem?.button else { return }

        // Sovereign DNA Double Helix template icon (Молекула ДНК)
        button.image = DNAHelixView.createMenubarIcon()
        button.target = self
        button.action = #selector(statusBarButtonClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])

        setupPopover()
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 330, height: 410)
        popover.behavior = .transient
        popover.animates = true

        let popoverView = MenubarPopoverView(
            vm: popoverViewModel,
            onOpenHistory: { [weak self] in
                self?.closePopover()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    HistoryWindowController.shared.showHistory()
                }
            },
            onQuit: { [weak self] in
                self?.quit()
            }
        )
        let hostingController = NSHostingController(rootView: popoverView)
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.shouldRasterize = false
        popover.contentViewController = hostingController
    }

    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            showQuickContextMenu()
            return
        }

        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem?.button else { return }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        if let window = popover.contentViewController?.view.window {
            window.makeKey()
        }
    }

    private func closePopover() {
        popover.performClose(nil)
    }

    private func showQuickContextMenu() {
        let menu = NSMenu()

        let historyItem = NSMenuItem(title: "Відкрити журнал надиктовок...", action: #selector(openHistoryWindow), keyEquivalent: "h")
        if let icon = NSImage(systemSymbolName: "clock.arrow.circlepath", accessibilityDescription: nil) {
            historyItem.image = icon
        }
        historyItem.target = self
        menu.addItem(historyItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Вийти з DNK_Piu", action: #selector(quit), keyEquivalent: "q")
        if let icon = NSImage(systemSymbolName: "power", accessibilityDescription: nil) {
            quitItem.image = icon
        }
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        DispatchQueue.main.async { [weak self] in
            self?.statusItem?.menu = nil
        }
    }

    @objc private func toggleDictate() {
        dictation.toggle()
    }

    @objc private func openHistoryWindow() {
        closePopover()
        HistoryWindowController.shared.showHistory()
    }

    @objc private func quit() {
        hotKey.stop()
        dictationPanel?.orderOut(nil)
        popover?.performClose(nil)
        NSApp.terminate(nil)
    }
}

// Application Entry Point
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
