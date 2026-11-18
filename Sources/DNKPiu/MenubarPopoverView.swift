import AppKit
import Combine
import PiuCore
import SwiftUI

/// Observable view state for the menubar popover HUD.
public final class PopoverViewModel: ObservableObject {
    @Published public var showSettings: Bool = false
    @Published public var copiedId: UUID? = nil
    @Published public var hoveredItemId: UUID? = nil

    public init() {}
}

/// Modern, human-centric native macOS Menubar Popover (Wispr Flow / Raycast grade).
/// Replaces the legacy system NSMenu with a fluid, tactile SwiftUI surface.
public struct MenubarPopoverView: View {
    @ObservedObject private var dictation = AudioDictation.shared
    @ObservedObject private var theme = ThemeManager.shared
    @ObservedObject private var hotKey = DictationHotKey.shared
    @ObservedObject private var vm: PopoverViewModel

    var onOpenHistory: () -> Void
    var onQuit: () -> Void

    public init(
        vm: PopoverViewModel = PopoverViewModel(),
        onOpenHistory: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.vm = vm
        self.onOpenHistory = onOpenHistory
        self.onQuit = onQuit
    }

    public var body: some View {
        ZStack {
            // Native macOS Frosted HUD Glass Background
            VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()

            // Subtle Obsidian Dark Glass Tint
            Color(hex: "#0C0D11").opacity(0.88)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // 1. Header Bar
                headerBar
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 12)

                Divider()
                    .background(Color.white.opacity(0.08))

                // 2. Hero Interactive Voice Card
                heroVoiceCard
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)

                Divider()
                    .background(Color.white.opacity(0.06))

                // 3. Settings Drawer (Collapsible) or Recent Dictations
                if vm.showSettings {
                    settingsView
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                } else {
                    recentDictationsView
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                }

                Spacer(minLength: 0)

                Divider()
                    .background(Color.white.opacity(0.08))

                // 4. Clean Footer Bar
                footerBar
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.20))
            }
        }
        .frame(width: 330, height: vm.showSettings ? 460 : 410)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.10), lineWidth: 0.8)
        )
    }

    // MARK: - Header Bar
    private var headerBar: some View {
        HStack(spacing: 10) {
            // Swallow Icon with dynamic state aura
            Image(systemName: "swift")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(statusColor)
                .scaleEffect(x: -1, y: 1)
                .frame(width: 26, height: 26)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.05))
                        .overlay(Circle().stroke(statusColor.opacity(0.35), lineWidth: 0.8))
                )
                .shadow(color: statusColor.opacity(0.40), radius: 4)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text("DNK_Piu")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("v\(DNKPiuVersion.current)")
                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.35))
                }

                Text(statusSubtitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(statusColor.opacity(0.90))
            }

            Spacer()

            // Header Action Buttons
            HStack(spacing: 6) {
                // Open Full History HUD (⌘H)
                Button {
                    onOpenHistory()
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.60))
                        .frame(width: 26, height: 26)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.04)))
                }
                .buttonStyle(.plain)
                .help("Відкрити журнал надиктовок (⌘H)")

                // Toggle Settings
                Button {
                    withAnimation {
                        vm.showSettings.toggle()
                    }
                } label: {
                    Image(systemName: vm.showSettings ? "xmark" : "gearshape")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(vm.showSettings ? AstryxTheme.accent : .white.opacity(0.60))
                        .frame(width: 26, height: 26)
                        .background(RoundedRectangle(cornerRadius: 6).fill(vm.showSettings ? AstryxTheme.accent.opacity(0.12) : Color.white.opacity(0.04)))
                }
                .buttonStyle(.plain)
                .help(vm.showSettings ? "Закрити налаштування" : "Налаштування")
            }
        }
    }

    // MARK: - Hero Interactive Voice Card
    private var heroVoiceCard: some View {
        HStack(spacing: 12) {
            // Tactile HotKey Badge
            VStack(spacing: 2) {
                Text(hotKey.activePreset.symbol)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(statusColor)

                Text("Клавіша")
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundColor(.white.opacity(0.40))
            }
            .frame(width: 50, height: 50)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(statusColor.opacity(0.25), lineWidth: 0.8)
                    )
            )

            // Explanatory voice guide
            VStack(alignment: .leading, spacing: 3) {
                Text(voiceCardTitle)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(.white.opacity(0.95))

                Text(voiceCardDescription)
                    .font(.system(size: 10.5, weight: .regular))
                    .foregroundColor(.white.opacity(0.45))
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.025))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.06), lineWidth: 0.8)
                )
        )
    }

    // MARK: - Recent Dictations View
    private var recentDictationsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("ОСТАННІ НАДИКТОВКИ")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.35))

                Spacer()

                if !dictation.history.isEmpty {
                    Button {
                        onOpenHistory()
                    } label: {
                        Text("Всі записи (⌘H)")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(AstryxTheme.accent.opacity(0.80))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)

            if dictation.history.isEmpty {
                VStack(spacing: 8) {
                    Spacer(minLength: 12)
                    Image(systemName: "waveform.slash")
                        .font(.system(size: 22))
                        .foregroundColor(.white.opacity(0.20))

                    Text("Історія надиктовок порожня")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(.white.opacity(0.50))

                    Text("Затисніть \(hotKey.activePreset.symbol) у будь-якій програмі для запису")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.30))
                    Spacer(minLength: 12)
                }
                .frame(maxWidth: .infinity, minHeight: 140)
            } else {
                VStack(spacing: 4) {
                    ForEach(Array(dictation.history.prefix(3))) { item in
                        recentItemRow(item)
                    }
                }
            }
        }
    }

    private func recentItemRow(_ item: DictationItem) -> some View {
        let isHovered = (vm.hoveredItemId == item.id)
        let isCopied = (vm.copiedId == item.id)

        return Button {
            pasteAndClose(item.text)
        } label: {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.text)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.white.opacity(0.90))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 5) {
                        Text(item.relativeTime)
                            .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.35))

                        if !item.appDisplayName.isEmpty {
                            Text("•")
                                .font(.system(size: 9))
                                .foregroundColor(.white.opacity(0.20))

                            Text(item.appDisplayName)
                                .font(.system(size: 9.5, weight: .medium))
                                .foregroundColor(AstryxTheme.accent.opacity(0.70))
                        }
                    }
                }

                Spacer(minLength: 4)

                // Trailing Quick Copy Action
                Button {
                    copyToClipboard(item)
                } label: {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.clipboard")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(isCopied ? AstryxTheme.accent : .white.opacity(0.40))
                        .frame(width: 22, height: 22)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(isCopied ? AstryxTheme.accent.opacity(0.12) : Color.white.opacity(0.04))
                        )
                }
                .buttonStyle(.plain)
                .help("Скопіювати")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(isHovered ? Color.white.opacity(0.06) : Color.white.opacity(0.02))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(isHovered ? Color.white.opacity(0.09) : Color.clear, lineWidth: 0.8)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            vm.hoveredItemId = hovering ? item.id : nil
        }
    }

    // MARK: - Settings Drawer View
    private var settingsView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("НАЛАШТУВАННЯ")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.35))
                .padding(.horizontal, 2)

            // Hotkey preset selector
            VStack(alignment: .leading, spacing: 5) {
                Text("Клавіша активації:")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.70))

                Picker("Клавіша", selection: Binding(
                    get: { hotKey.activePreset },
                    set: { hotKey.setPreset($0) }
                )) {
                    ForEach(FlowKeyPreset.allCases) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }

            // Theme preset selector
            VStack(alignment: .leading, spacing: 5) {
                Text("Тема оформлення:")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.70))

                Picker("Тема", selection: Binding(
                    get: { theme.mode },
                    set: { theme.setMode($0) }
                )) {
                    ForEach(AppThemeMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }

            // Accessibility Status
            HStack(spacing: 8) {
                let isTrusted = DictationHotKey.isAccessibilityGranted()
                Image(systemName: isTrusted ? "checkmark.shield.fill" : "exclamationmark.shield")
                    .foregroundColor(isTrusted ? AstryxTheme.accent : AstryxTheme.amber)
                    .font(.system(size: 13))

                Text(isTrusted ? "Дозволи Accessibility: Надано" : "Потрібні дозволи Accessibility")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.75))

                Spacer()

                if !isTrusted {
                    Button("Надати") {
                        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                        AXIsProcessTrustedWithOptions(opts)
                    }
                    .font(.system(size: 10.5, weight: .semibold))
                    .buttonStyle(.borderedProminent)
                    .tint(AstryxTheme.accent)
                }
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Footer Bar
    private var footerBar: some View {
        HStack {
            Button {
                onQuit()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "power")
                        .font(.system(size: 10, weight: .bold))
                    Text("Вийти")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(AstryxTheme.red.opacity(0.70))
            }
            .buttonStyle(.plain)
            .help("Вийти з DNK_Piu (⌘Q)")

            Spacer()

            Text("Клік на запис — вставка в курсор")
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.35))
        }
    }

    // MARK: - Helpers
    private var statusColor: Color {
        switch dictation.phase {
        case .listening: return Color(hex: "#EF4444")
        case .thinking: return Color(hex: "#3B82F6")
        case .done: return AstryxTheme.shopifyMint
        case .failed: return Color(hex: "#EF4444")
        case .idle: return AstryxTheme.shopifyMint
        }
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
            return "Помилка мікрофона"
        case .idle:
            return "Готово до запису"
        }
    }

    private var voiceCardTitle: String {
        switch dictation.phase {
        case .listening: return "Слухаємо ваш голос..."
        case .thinking: return "Транскрибуємо через Gemini..."
        case .done: return "Текст успішно вставлено!"
        case .failed: return "Помилка обробки"
        case .idle: return "Утримуйте \(hotKey.activePreset.symbol) щоб говорити"
        }
    }

    private var voiceCardDescription: String {
        switch dictation.phase {
        case .listening(let locked):
            return locked ? "Натисніть Esc або \(hotKey.activePreset.symbol) для зупинки" : "Відпустіть клавішу для миттєвої вставки"
        case .thinking:
            return "Штучний інтелект перетворює аудіо на чистий текст"
        case .done:
            return "Готово до наступної надиктовки"
        case .failed:
            return "Перевірте дозволи мікрофона або API ключ"
        case .idle:
            return "Або двічі натисніть для режиму Hands-free без утримання"
        }
    }

    private func pasteAndClose(_ text: String) {
        NSApp.keyWindow?.orderOut(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
            FlowPaste.insert(text)
        }
    }

    private func copyToClipboard(_ item: DictationItem) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.text, forType: .string)
        vm.copiedId = item.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            if vm.copiedId == item.id { vm.copiedId = nil }
        }
    }
}
