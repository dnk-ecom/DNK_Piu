import AppKit
import Combine
import PiuCore
import SwiftUI

/// Window Controller managing the native, floating Raycast/Apple-grade Voice History HUD.
final class HistoryWindowController: NSWindowController, NSWindowDelegate {
    static let shared = HistoryWindowController()

    private var hostingView: NSHostingView<HistoryView>?
    private let viewModel = HistoryViewModel()

    private init() {
        let panel = HistoryPanel(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 480),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "Журнал надиктовок"
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.center()
        panel.setFrameAutosaveName("DNKPiuHistoryHUDWindow")

        super.init(window: panel)
        panel.delegate = self

        let historyView = HistoryView(
            vm: viewModel,
            onClose: { [weak self] in
                self?.window?.orderOut(nil)
            },
            onPasteItem: { [weak self] item in
                self?.pasteAndDismiss(item)
            }
        )
        let hosting = NSHostingView(rootView: historyView)
        self.hostingView = hosting
        panel.contentView = hosting

        panel.onKeyDown = { [weak self] event in
            return self?.handleKeyEvent(event) ?? false
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showHistory() {
        guard let window = window else { return }
        viewModel.refresh()
        window.center()
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func pasteAndDismiss(_ item: DictationItem) {
        window?.orderOut(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            FlowPaste.insert(item.text)
        }
    }

    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case 53: // Escape
            window?.orderOut(nil)
            return true
        case 126: // Up arrow
            viewModel.moveSelection(up: true)
            return true
        case 125: // Down arrow
            viewModel.moveSelection(up: false)
            return true
        case 36: // Return / Enter
            if let selected = viewModel.selectedItem {
                pasteAndDismiss(selected)
                return true
            }
        case 8: // 'C' key with Command
            if event.modifierFlags.contains(.command), let selected = viewModel.selectedItem {
                viewModel.copyItem(selected)
                return true
            }
        case 51: // Backspace / Delete
            if let selected = viewModel.selectedItem {
                viewModel.deleteItem(selected)
                return true
            }
        default:
            break
        }
        return false
    }
}

/// Floating NSPanel that forwards custom key navigation.
final class HistoryPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    var onKeyDown: ((NSEvent) -> Bool)?

    override func keyDown(with event: NSEvent) {
        if let handled = onKeyDown?(event), handled {
            return
        }
        super.keyDown(with: event)
    }

    override func cancelOperation(_ sender: Any?) {
        self.orderOut(nil)
    }
}

/// Native macOS Frosted Glass Visual Effect Background.
struct VisualEffectBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

/// Time-range filters for recorded voice sessions.
enum HistoryTimeFilter: String, CaseIterable, Identifiable {
    case lastHour = "Остання година"
    case today = "Сьогодні"
    case all = "Усі"

    var id: String { rawValue }
}

/// Observable state driving the Voice History HUD.
final class HistoryViewModel: ObservableObject {
    @Published var items: [DictationItem] = []
    @Published var searchText: String = ""
    @Published var selectedFilter: HistoryTimeFilter = .lastHour
    @Published var selectedIndex: Int = 0
    @Published var hoveredId: UUID? = nil
    @Published var copiedId: UUID? = nil
    @Published var showDeleteAllAlert: Bool = false

    var filteredItems: [DictationItem] {
        let now = Date()
        return items.filter { item in
            switch selectedFilter {
            case .lastHour:
                if now.timeIntervalSince(item.timestamp) > 3600 { return false }
            case .today:
                if !Calendar.current.isDateInToday(item.timestamp) { return false }
            case .all:
                break
            }

            if !searchText.isEmpty {
                let query = searchText.lowercased()
                let matchesText = item.text.lowercased().contains(query)
                let matchesApp = item.appDisplayName.lowercased().contains(query)
                if !matchesText && !matchesApp { return false }
            }

            return true
        }
    }

    var selectedItem: DictationItem? {
        let list = filteredItems
        guard !list.isEmpty, selectedIndex >= 0, selectedIndex < list.count else { return nil }
        return list[selectedIndex]
    }

    func moveSelection(up: Bool) {
        let count = filteredItems.count
        guard count > 0 else { return }
        if up {
            selectedIndex = max(0, selectedIndex - 1)
        } else {
            selectedIndex = min(count - 1, selectedIndex + 1)
        }
    }

    func refresh() {
        let loaded = AudioDictation.loadPersistentEvents()
        if !loaded.isEmpty {
            self.items = loaded
        } else {
            self.items = AudioDictation.shared.history
        }
        if selectedIndex >= filteredItems.count {
            selectedIndex = max(0, filteredItems.count - 1)
        }
    }

    func copyItem(_ item: DictationItem) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.text, forType: .string)
        copiedId = item.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            if self?.copiedId == item.id { self?.copiedId = nil }
        }
    }

    func deleteItem(_ item: DictationItem) {
        items.removeAll { $0.id == item.id }
        AudioDictation.shared.remove(item: item)
        if selectedIndex >= filteredItems.count {
            selectedIndex = max(0, filteredItems.count - 1)
        }
    }

    func clearAll() {
        items.removeAll()
        AudioDictation.shared.clearHistory()
        selectedIndex = 0
    }
}

/// Raycast / Apple Spotlight-grade Voice History Inspector View.
struct HistoryView: View {
    @ObservedObject var vm: HistoryViewModel
    var onClose: () -> Void
    var onPasteItem: (DictationItem) -> Void

    var body: some View {
        ZStack {
            // Native macOS HUD Frosted Glass Material
            VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()

            // Subtle Obsidian Dark Glass Tint
            Color(hex: "#0C0D11").opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top Search & Filter Bar (Raycast / Spotlight style)
                searchAndFilterBar
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 12)

                Divider()
                    .background(Color.white.opacity(0.07))

                // Scrollable List Content
                if vm.filteredItems.isEmpty {
                    emptyStateView
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 2) {
                                ForEach(Array(vm.filteredItems.enumerated()), id: \.element.id) { index, item in
                                    HistoryItemRow(
                                        item: item,
                                        isSelected: vm.selectedIndex == index,
                                        isHovered: vm.hoveredId == item.id,
                                        isCopied: vm.copiedId == item.id,
                                        onSelect: {
                                            vm.selectedIndex = index
                                            onPasteItem(item)
                                        },
                                        onHover: { hovering in
                                            vm.hoveredId = hovering ? item.id : nil
                                        },
                                        onCopy: { vm.copyItem(item) },
                                        onDelete: { vm.deleteItem(item) }
                                    )
                                    .id(item.id)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                        }
                        .onChange(of: vm.selectedIndex) { _, newIdx in
                            let items = vm.filteredItems
                            if newIdx >= 0 && newIdx < items.count {
                                withAnimation(.easeInOut(duration: 0.1)) {
                                    proxy.scrollTo(items[newIdx].id, anchor: .center)
                                }
                            }
                        }
                    }
                }

                Divider()
                    .background(Color.white.opacity(0.07))

                // Bottom Status & Action Legend (Raycast style)
                statusBar
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.20))
            }
        }
        .frame(minWidth: 580, minHeight: 460)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.09), lineWidth: 0.8)
        )
        .alert(isPresented: $vm.showDeleteAllAlert) {
            Alert(
                title: Text("Очистити історію?"),
                message: Text("Усі надиктовані записи буде видалено назавжди."),
                primaryButton: .destructive(Text("Очистити")) {
                    vm.clearAll()
                },
                secondaryButton: .cancel(Text("Скасувати"))
            )
        }
    }

    // MARK: - Search & Filter Bar
    private var searchAndFilterBar: some View {
        HStack(spacing: 10) {
            // Sovereign 3D DNA Brand Molecule
            DNAHelixView(phase: .idle, audioLevel: 0.0, size: 22)
                .frame(width: 24, height: 24)

            // Search Field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.35))

                TextField("Пошук надиктовок...", text: $vm.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.white)

                if !vm.searchText.isEmpty {
                    Button {
                        vm.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.40))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
                    )
            )

            // Minimal Segmented Filter Tabs
            HStack(spacing: 2) {
                ForEach(HistoryTimeFilter.allCases) { filter in
                    Button {
                        vm.selectedFilter = filter
                        vm.selectedIndex = 0
                    } label: {
                        Text(filter.rawValue)
                            .font(.system(size: 11, weight: vm.selectedFilter == filter ? .semibold : .regular))
                            .foregroundColor(vm.selectedFilter == filter ? .white : .white.opacity(0.45))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(vm.selectedFilter == filter ? Color.white.opacity(0.12) : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(2)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.03))
            )
        }
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "mic.slash")
                .font(.system(size: 32))
                .foregroundColor(.white.opacity(0.20))

            Text("Немає записів за цей період")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.70))

            Text("Затисніть ⌥ Option, щоб надиктувати текст у будь-якій програмі.")
                .font(.system(size: 11.5))
                .foregroundColor(.white.opacity(0.35))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Status Bar / Keyboard Hints Footer
    private var statusBar: some View {
        HStack(spacing: 12) {
            // Count
            Text("\(vm.filteredItems.count) надиктовок")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.35))

            Spacer()

            // Raycast-style subtle shortcut hints
            HStack(spacing: 12) {
                shortcutHint(key: "↵", label: "Вставити")
                shortcutHint(key: "⌘C", label: "Копіювати")
                shortcutHint(key: "⌫", label: "Видалити")
                shortcutHint(key: "Esc", label: "Закрити")
            }

            if !vm.items.isEmpty {
                Button {
                    vm.showDeleteAllAlert = true
                } label: {
                    Text("Очистити")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AstryxTheme.red.opacity(0.60))
                }
                .buttonStyle(.plain)
                .padding(.leading, 6)
            }
        }
    }

    private func shortcutHint(key: String, label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                .padding(.horizontal, 4.5)
                .padding(.vertical, 1.5)
                .background(RoundedRectangle(cornerRadius: 3.5).fill(Color.white.opacity(0.08)))
                .foregroundColor(.white.opacity(0.75))

            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.40))
        }
    }
}

/// Clean, flat list row free of nested card clutter.
struct HistoryItemRow: View {
    let item: DictationItem
    let isSelected: Bool
    let isHovered: Bool
    let isCopied: Bool
    var onSelect: () -> Void
    var onHover: (Bool) -> Void
    var onCopy: () -> Void
    var onDelete: () -> Void

    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(alignment: .center, spacing: 12) {
                // Main Transcript Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.text)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.white.opacity(0.92))
                        .lineSpacing(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 6) {
                        Text(item.formattedTime)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.35))

                        Text("•")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.20))

                        Text(item.relativeTime)
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.35))

                        if !item.appDisplayName.isEmpty {
                            Text("•")
                                .font(.system(size: 10))
                                .foregroundColor(.white.opacity(0.20))

                            Text(item.appDisplayName)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(AstryxTheme.accent.opacity(0.70))
                        }
                    }
                }

                Spacer(minLength: 8)

                // Trailing quiet actions: Copy & Delete
                HStack(spacing: 4) {
                    Button {
                        onCopy()
                    } label: {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.clipboard")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(isCopied ? AstryxTheme.accent : (isHovered || isSelected ? .white.opacity(0.60) : .white.opacity(0.25)))
                            .frame(width: 24, height: 24)
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(isCopied ? AstryxTheme.accent.opacity(0.12) : Color.white.opacity(0.04))
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Скопіювати в буфер (⌘C)")

                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 10.5))
                            .foregroundColor(isHovered || isSelected ? .white.opacity(0.40) : .white.opacity(0.15))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .help("Видалити запис (⌫)")
                }
                .opacity(isHovered || isSelected ? 1.0 : 0.0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.white.opacity(0.08) : (isHovered ? Color.white.opacity(0.04) : Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            onHover(hovering)
        }
    }
}
