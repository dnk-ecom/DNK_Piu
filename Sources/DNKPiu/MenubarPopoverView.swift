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
            // Solid Obsidian Dark Base guarantees crystal-sharp subpixel text antialiasing
            Color(hex: "#0C0D11")
                .ignoresSafeArea()

            // Subtle Frosted Blur Overlay
            VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow)
                .opacity(0.45)
                .ignoresSafeArea()

            // Rock-solid fixed 330x410 viewport with smooth horizontal spring slide transition
            ZStack {
                if vm.showSettings {
                    settingsScreen
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                } else {
                    dashboardScreen
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.85), value: vm.showSettings)
        }
        .frame(width: 330, height: 410)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
        )
    }

    // MARK: - Screen 1: Dashboard
    private var dashboardScreen: some View {
        VStack(spacing: 0) {
            // 1. Header Bar
            dashboardHeaderBar
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 12)

            Divider()
                .background(Color.white.opacity(0.10))

            // 2. Hero Interactive Voice Card
            heroVoiceCard
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

            Divider()
                .background(Color.white.opacity(0.08))

            // 3. Recent Dictations
            recentDictationsView
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

            Spacer(minLength: 0)

            Divider()
                .background(Color.white.opacity(0.10))

            // 4. Clean Footer Bar
            footerBar
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.25))
        }
    }

    // MARK: - Screen 2: Settings
    private var settingsScreen: some View {
        VStack(spacing: 0) {
            // Settings Header Bar
            settingsHeaderBar
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 12)

            Divider()
                .background(Color.white.opacity(0.10))

            // Settings Body
            settingsBodyView
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

            Spacer(minLength: 0)

            Divider()
                .background(Color.white.opacity(0.10))

            // Settings Footer Bar
            settingsFooterBar
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.25))
        }
    }

    // MARK: - Dashboard Header Bar
    private var dashboardHeaderBar: some View {
        HStack(spacing: 10) {
            // Sovereign 8-Bit Pixel DNA Molecule with real-time acoustic reactivity & absolute optical centering
            ZStack {
                DNAHelixView(
                    phase: dictation.phase,
                    audioLevel: dictation.audioLevels.max() ?? 0.05,
                    size: 26
                )
            }
            .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("DNK_Piu")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)

                    Text("v\(DNKPiuVersion.current)")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color(hex: "#A1A1AA"))
                }

                Text(statusSubtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(statusColor)
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
                        .foregroundColor(Color(hex: "#D4D4D8"))
                        .frame(width: 26, height: 26)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.06)))
                }
                .buttonStyle(.plain)
                .help("Відкрити журнал надиктовок (⌘H)")

                // Open Settings
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                        vm.showSettings = true
                    }
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "#D4D4D8"))
                        .frame(width: 26, height: 26)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.06)))
                }
                .buttonStyle(.plain)
                .help("Налаштування")
            }
        }
    }

    // MARK: - Settings Header Bar
    private var settingsHeaderBar: some View {
        HStack(spacing: 8) {
            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                    vm.showSettings = false
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .bold))
                    Text("Назад")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(AstryxTheme.accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 6).fill(AstryxTheme.accent.opacity(0.12)))
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Налаштування")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)

            Spacer()

            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
                    vm.showSettings = false
                }
            } label: {
                Text("Готово")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AstryxTheme.accent)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Hero Interactive Voice Card
    private var heroVoiceCard: some View {
        HStack(spacing: 12) {
            // Tactile HotKey Badge
            VStack(spacing: 2) {
                Text(hotKey.activePreset.symbol)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(statusColor)

                Text("Клавіша")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Color(hex: "#A1A1AA"))
            }
            .frame(width: 52, height: 50)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.10), lineWidth: 0.8)
                    )
            )

            // Status Copy & Instructions
            VStack(alignment: .leading, spacing: 3) {
                Text(voiceCardTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)

                Text(voiceCardDescription)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(Color(hex: "#D4D4D8"))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(statusColor.opacity(0.25), lineWidth: 0.8)
                )
        )
    }

    // MARK: - Recent Dictations View
    private var recentDictationsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("ОСТАННІ НАДИКТОВКИ")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "#A1A1AA"))

                Spacer()

                if !dictation.history.isEmpty {
                    Button {
                        onOpenHistory()
                    } label: {
                        Text("Всі записи (⌘H)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(AstryxTheme.accent)
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
                        .foregroundColor(Color(hex: "#71717A"))

                    Text("Історія надиктовок порожня")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "#D4D4D8"))

                    Text("Затисніть \(hotKey.activePreset.symbol) у будь-якій програмі для запису")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#A1A1AA"))
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
                        .foregroundColor(Color(hex: "#FAFAFA"))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 5) {
                        Text(item.relativeTime)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(Color(hex: "#A1A1AA"))

                        if !item.appDisplayName.isEmpty {
                            Text("•")
                                .font(.system(size: 10))
                                .foregroundColor(Color(hex: "#71717A"))

                            Text(item.appDisplayName)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(AstryxTheme.accent)
                        }
                    }
                }

                Spacer(minLength: 4)

                // Trailing Quick Copy Action
                Button {
                    copyToClipboard(item)
                } label: {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.clipboard")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(isCopied ? AstryxTheme.accent : Color(hex: "#D4D4D8"))
                        .frame(width: 22, height: 22)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(isCopied ? AstryxTheme.accent.opacity(0.15) : Color.white.opacity(0.06))
                        )
                }
                .buttonStyle(.plain)
                .help("Скопіювати")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(isHovered ? Color.white.opacity(0.08) : Color.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(isHovered ? Color.white.opacity(0.12) : Color.clear, lineWidth: 0.8)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            vm.hoveredItemId = hovering ? item.id : nil
        }
    }

    // MARK: - Settings Body View
    private var settingsBodyView: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Hotkey Section (Strict single key choice!)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Клавіша диктування")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Text("Hold-to-talk")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(Color(hex: "#A1A1AA"))
                }

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

                Text("Спрацьовує виключно обрана клавіша. Інша клавіша вільна для інших програм.")
                    .font(.system(size: 10))
                    .foregroundColor(Color(hex: "#A1A1AA"))
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.03)))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.08), lineWidth: 0.8))

            // Theme Section
            VStack(alignment: .leading, spacing: 6) {
                Text("Тема оформлення")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)

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
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.03)))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.08), lineWidth: 0.8))

            // Accessibility Status Card
            VStack(alignment: .leading, spacing: 6) {
                let isTrusted = DictationHotKey.isAccessibilityGranted()
                HStack(spacing: 8) {
                    Image(systemName: isTrusted ? "checkmark.shield.fill" : "exclamationmark.shield")
                        .foregroundColor(isTrusted ? AstryxTheme.accent : AstryxTheme.amber)
                        .font(.system(size: 14))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(isTrusted ? "Accessibility: Дозволено ✓" : "Потрібні дозволи")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)

                        Text("Для миттєвої вставки тексту в активну програму")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "#A1A1AA"))
                    }

                    Spacer()

                    if !isTrusted {
                        Button("Надати") {
                            DictationHotKey.openAccessibilitySettings()
                        }
                        .font(.system(size: 10, weight: .bold))
                        .buttonStyle(.borderedProminent)
                        .tint(AstryxTheme.accent)
                    }
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.03)))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.08), lineWidth: 0.8))
        }
    }

    // MARK: - Footers
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
                .foregroundColor(AstryxTheme.red.opacity(0.85))
            }
            .buttonStyle(.plain)
            .help("Вийти з DNK_Piu (⌘Q)")

            Spacer()

            Text("Клік на запис — вставка в курсор")
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "#A1A1AA"))
        }
    }

    private var settingsFooterBar: some View {
        HStack {
            Button {
                onQuit()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "power")
                        .font(.system(size: 10, weight: .bold))
                    Text("Вийти з DNK_Piu")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(AstryxTheme.red.opacity(0.85))
            }
            .buttonStyle(.plain)

            Spacer()

            Text("DNK_Piu v\(DNKPiuVersion.current)")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(Color(hex: "#A1A1AA"))
        }
    }

    // MARK: - Helpers
    private var statusColor: Color {
        switch dictation.phase {
        case .listening: return Color(hex: "#EF4444")
        case .thinking: return Color(hex: "#3B82F6")
        case .done: return AstryxTheme.shopifyMint
        case .failed: return Color(hex: "#EF4444")
        case .idle: return Color(hex: "#EF4444")
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
