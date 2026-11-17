import AppKit
import Combine
import PiuCore
import SwiftUI

/// Window Controller managing the native, floating Astryx-styled Voice History HUD.
final class HistoryWindowController: NSWindowController, NSWindowDelegate {
    static let shared = HistoryWindowController()

    private init() {
        let panel = HistoryPanel(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 560),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "Журнал надиктовок DNK_Piu"
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = NSColor(red: 0.05, green: 0.06, blue: 0.09, alpha: 0.98)
        panel.level = .floating
        panel.center()
        panel.setFrameAutosaveName("DNKPiuHistoryWindowHUD")

        super.init(window: panel)
        panel.delegate = self

        let hosting = NSHostingView(
            rootView: HistoryView(
                onClose: { [weak self] in
                    self?.window?.orderOut(nil)
                },
                onPasteItem: { [weak self] item in
                    self?.pasteAndDismiss(item)
                }
            )
        )
        panel.contentView = hosting
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showHistory() {
        guard let window = window else { return }
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func pasteAndDismiss(_ item: DictationItem) {
        window?.orderOut(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            FlowPaste.insert(item.text)
        }
    }
}

/// Floating NSPanel that handles Escape key automatically to dismiss.
final class HistoryPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        self.orderOut(nil)
    }
}

/// Time-range filters for recorded voice sessions.
enum HistoryTimeFilter: String, CaseIterable, Identifiable {
    case lastHour = "Остання 1 год"
    case today = "Сьогодні"
    case all = "Усі записи"

    var id: String { rawValue }
}

/// View model driving the history state with standard Combine publishers (no macro dependency).
final class HistoryViewModel: ObservableObject {
    @Published var items: [DictationItem] = []
    @Published var searchText: String = ""
    @Published var selectedFilter: HistoryTimeFilter = .lastHour
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

    func refresh() {
        let loaded = AudioDictation.loadPersistentEvents()
        if !loaded.isEmpty {
            self.items = loaded
        } else {
            self.items = AudioDictation.shared.history
        }
    }

    func copyItem(_ item: DictationItem) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.text, forType: .string)
        copiedId = item.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            if self?.copiedId == item.id { self?.copiedId = nil }
        }
    }

    func deleteItem(_ item: DictationItem) {
        items.removeAll { $0.id == item.id }
        AudioDictation.shared.remove(item: item)
    }

    func clearAll() {
        items.removeAll()
        AudioDictation.shared.clearHistory()
    }
}

/// Astryx-grade Native Voice History Inspector view.
struct HistoryView: View {
    var onClose: () -> Void
    var onPasteItem: (DictationItem) -> Void

    @StateObject private var vm = HistoryViewModel()

    var body: some View {
        ZStack {
            // Deep Obsidian Black Background
            Color(hex: "#08090D")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top Header Bar
                headerBar
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                // Search & Filter Toolbar
                filterBar
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)

                Divider()
                    .background(Color.white.opacity(0.08))

                // Scrollable Content
                if vm.filteredItems.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(vm.filteredItems) { item in
                                HistoryCardView(
                                    item: item,
                                    isCopied: vm.copiedId == item.id,
                                    onPaste: { onPasteItem(item) },
                                    onCopy: { vm.copyItem(item) },
                                    onDelete: { vm.deleteItem(item) }
                                )
                            }
                        }
                        .padding(20)
                    }
                }

                Divider()
                    .background(Color.white.opacity(0.08))

                // Bottom Status Footer
                footerBar
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
            }
        }
        .frame(minWidth: 580, minHeight: 480)
        .onAppear {
            vm.refresh()
        }
        .alert(isPresented: $vm.showDeleteAllAlert) {
            Alert(
                title: Text("Очистити історію надиктовок?"),
                message: Text("Це назавжди видалить усі збережені записи з журналу."),
                primaryButton: .destructive(Text("Очистити")) {
                    vm.clearAll()
                },
                secondaryButton: .cancel(Text("Скасувати"))
            )
        }
    }

    private var headerBar: some View {
        HStack(spacing: 10) {
            // Swallow Icon Badge (Astryx Identity)
            Image(systemName: "swift")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "#06B6D4"), Color(hex: "#10B981")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .scaleEffect(x: -1, y: 1)

            Text("Журнал надиктовок")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.white)

            // Badge count
            Text("\(vm.filteredItems.count)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(Color(hex: "#06B6D4"))
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color(hex: "#06B6D4").opacity(0.15)))

            Spacer()

            // Refresh Button
            Button {
                vm.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Color.white.opacity(0.06)))
            }
            .buttonStyle(.plain)
            .help("Оновити записи")

            // Close Button
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .help("Закрити (Esc)")
        }
    }

    private var filterBar: some View {
        VStack(spacing: 10) {
            // Search Input
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))

                TextField("Пошук по тексту надиктовок або програмі...", text: $vm.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
                    .foregroundColor(.white)

                if !vm.searchText.isEmpty {
                    Button {
                        vm.searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.10), lineWidth: 0.8)
                    )
            )

            // Segmented Filter
            HStack(spacing: 6) {
                ForEach(HistoryTimeFilter.allCases) { filter in
                    Button {
                        vm.selectedFilter = filter
                    } label: {
                        Text(filter.rawValue)
                            .font(.system(size: 11.5, weight: vm.selectedFilter == filter ? .semibold : .regular))
                            .foregroundColor(vm.selectedFilter == filter ? .white : .white.opacity(0.55))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(vm.selectedFilter == filter ? Color(hex: "#06B6D4").opacity(0.25) : Color.white.opacity(0.04))
                                    .overlay(
                                        Capsule()
                                            .stroke(vm.selectedFilter == filter ? Color(hex: "#06B6D4").opacity(0.5) : Color.clear, lineWidth: 0.8)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "mic.slash")
                .font(.system(size: 36))
                .foregroundColor(.white.opacity(0.2))

            Text("Немає записів за вибраний період")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.75))

            Text("Затисніть Option (⌥) у будь-якій програмі, щоб надиктувати текст.")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.40))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footerBar: some View {
        HStack {
            Text("💡 Клікніть «Вставити», щоб перенести текст у поточний курсор")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.40))

            Spacer()

            if !vm.items.isEmpty {
                Button {
                    vm.showDeleteAllAlert = true
                } label: {
                    Text("Очистити все")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Color(hex: "#EF4444").opacity(0.85))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// Card representing a single transcribed dictation event.
struct HistoryCardView: View {
    let item: DictationItem
    let isCopied: Bool
    var onPaste: () -> Void
    var onCopy: () -> Void
    var onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header Row: Time, Relative Tag, App Badge & Action Buttons
            HStack(spacing: 8) {
                // Clock icon & exact time
                Image(systemName: "clock")
                    .font(.system(size: 10.5))
                    .foregroundColor(Color(hex: "#06B6D4"))

                Text(item.formattedTime)
                    .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9))

                Text("•  \(item.relativeTime)")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.white.opacity(0.45))

                // App destination badge
                HStack(spacing: 4) {
                    Image(systemName: "app.window.checkmark")
                        .font(.system(size: 9))
                    Text(item.appDisplayName)
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(Color(hex: "#A78BFA"))
                .padding(.horizontal, 7)
                .padding(.vertical, 2.5)
                .background(
                    Capsule().fill(Color(hex: "#8B5CF6").opacity(0.12))
                )

                Spacer()

                // Actions: Copy
                Button {
                    onCopy()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.clipboard")
                            .font(.system(size: 10))
                        Text(isCopied ? "Скопійовано" : "Копіювати")
                            .font(.system(size: 10.5, weight: .medium))
                    }
                    .foregroundColor(isCopied ? Color(hex: "#10B981") : .white.opacity(0.7))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white.opacity(0.06))
                    )
                }
                .buttonStyle(.plain)

                // Actions: Paste
                Button {
                    onPaste()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.turn.down.left")
                            .font(.system(size: 10, weight: .bold))
                        Text("Вставити")
                            .font(.system(size: 10.5, weight: .bold))
                    }
                    .foregroundColor(Color(hex: "#08090D"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#06B6D4"), Color(hex: "#10B981")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                }
                .buttonStyle(.plain)

                // Delete button
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.35))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .help("Видалити запис")
            }

            // Transcript Text Body
            Text(item.text)
                .font(.system(size: 13, weight: .regular, design: .default))
                .foregroundColor(.white.opacity(0.92))
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(hex: "#10121A").opacity(0.90))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.07), lineWidth: 0.8)
                )
        )
    }
}
