// --- DNK-MRH-HEADER ---
// mrh_id: "Sources/PiuCore/DictationSettings.swift"
// purpose: "Configurable Speech Refinement & Intelligence Settings for DNK_Piu"
// canonical_source: true
// alters_files: []
// triggers_tasks: []
// status: "Active"
// version: "1.0.0"
// updated_at: "2026-11-20"
// author: "DNK-e.com Maksym & Antigravity"
// --- END DNK-MRH-HEADER ---

import AppKit
import Combine
import Foundation

/// Available formatting modes for speech refinement in DNK_Piu.
public enum FormattingMode: String, CaseIterable, Identifiable {
    case cleanVerbatim = "cleanVerbatim"
    case polished = "polished"
    case bulletItems = "bulletItems"
    case aiPrompt = "aiPrompt"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .cleanVerbatim: return "Чистий текст"
        case .polished: return "Діловий стиль"
        case .bulletItems: return "Список / Булети"
        case .aiPrompt: return "Промпт для ШІ"
        }
    }

    public var iconName: String {
        switch self {
        case .cleanVerbatim: return "text.quote"
        case .polished: return "sparkles"
        case .bulletItems: return "list.bullet"
        case .aiPrompt: return "terminal"
        }
    }

    public var subtitle: String {
        switch self {
        case .cleanVerbatim:
            return "Чистить «е-е» та слова-паразити, зберігає природний порядок слів"
        case .polished:
            return "Бездоганний граматичний та діловий стиль для листів і документів"
        case .bulletItems:
            return "Формує структурований список задач або тез (- ...)"
        case .aiPrompt:
            return "Інженерне формулювання чіткої задачі для ШІ-агентів"
        }
    }
}

/// Supported Gemini speech recognition models.
public enum DictationModel: String, CaseIterable, Identifiable {
    case flashLite = "gemini-3.5-flash-lite"
    case transcribe = "gemini-3.5-transcribe"
    case flash = "gemini-3.8-flash"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .flashLite: return "Gemini 3.5 Flash Lite"
        case .transcribe: return "Gemini 3.5 Transcribe"
        case .flash: return "Gemini 3.8 Flash"
        }
    }

    public var speedBadge: String {
        switch self {
        case .flashLite: return "⚡ ~0.7s (Ультра-швидка)"
        case .transcribe: return "🎯 Спеціалізована ASR"
        case .flash: return "🧠 Мультимодальна"
        }
    }
}

/// Central Observable Settings Manager for speech refinement and recognition options.
public final class DictationSettings: ObservableObject {
    public static let shared = DictationSettings()

    // MARK: - Keys
    private static let keyFormattingMode = "dnk_piu_formatting_mode"
    private static let keyStripFillers = "dnk_piu_strip_fillers"
    private static let keySelfCorrection = "dnk_piu_self_correction"
    private static let keyAppAware = "dnk_piu_app_aware_formatting"
    private static let keyVoiceCommands = "dnk_piu_voice_commands"
    private static let keySelectedModel = "dnk_piu_selected_model"

    // MARK: - Published Properties
    @Published public var formattingMode: FormattingMode {
        didSet {
            UserDefaults.standard.set(formattingMode.rawValue, forKey: Self.keyFormattingMode)
        }
    }

    @Published public var stripFillers: Bool {
        didSet {
            UserDefaults.standard.set(stripFillers, forKey: Self.keyStripFillers)
        }
    }

    @Published public var selfCorrection: Bool {
        didSet {
            UserDefaults.standard.set(selfCorrection, forKey: Self.keySelfCorrection)
        }
    }

    @Published public var appAwareFormatting: Bool {
        didSet {
            UserDefaults.standard.set(appAwareFormatting, forKey: Self.keyAppAware)
        }
    }

    @Published public var voiceCommands: Bool {
        didSet {
            UserDefaults.standard.set(voiceCommands, forKey: Self.keyVoiceCommands)
        }
    }

    @Published public var selectedModel: DictationModel {
        didSet {
            UserDefaults.standard.set(selectedModel.rawValue, forKey: Self.keySelectedModel)
        }
    }

    // MARK: - Initialization
    private init() {
        let savedMode = UserDefaults.standard.string(forKey: Self.keyFormattingMode) ?? FormattingMode.cleanVerbatim.rawValue
        self.formattingMode = FormattingMode(rawValue: savedMode) ?? .cleanVerbatim

        self.stripFillers = UserDefaults.standard.object(forKey: Self.keyStripFillers) as? Bool ?? true
        self.selfCorrection = UserDefaults.standard.object(forKey: Self.keySelfCorrection) as? Bool ?? true
        self.appAwareFormatting = UserDefaults.standard.object(forKey: Self.keyAppAware) as? Bool ?? true
        self.voiceCommands = UserDefaults.standard.object(forKey: Self.keyVoiceCommands) as? Bool ?? true

        let savedModel = UserDefaults.standard.string(forKey: Self.keySelectedModel) ?? DictationModel.flashLite.rawValue
        self.selectedModel = DictationModel(rawValue: savedModel) ?? .flashLite
    }

    // MARK: - Prompt Formulation
    /// Builds a comprehensive intelligent system instruction prompt based on active user settings.
    public func buildPrompt(targetApp: String? = nil) -> String {
        var sections: [String] = []
        sections.append("""
        System instruction: You are a high-speed intelligent speech-to-text editor for the Astryx / DNK OS developer workstation (uk-UA / en-US).
        Task: Transcribe spoken audio strictly into clean Ukrainian (uk-UA). Preserve English only for explicit IT/developer terms and code.
        CRITICAL: Do NOT transcribe into Spanish, Russian, or other languages unless explicitly spoken.
        """)

        var rules: [String] = []

        if selfCorrection {
            rules.append("1. Self-Correction & Retractions: If the speaker misspeaks, self-corrects, or says 'ой ні', 'видали це', 'закресли', 'ні, зачекай', 'тобто' or changes a word/sentence, apply the edit inline and output ONLY the final intended thought. Example: 'Створи таску для шапки... ой ні, для футера' -> 'Створи таску для футера'.")
        } else {
            rules.append("1. Verbatim Reproduction: Transcribe all words exactly as spoken without applying self-corrections.")
        }

        if stripFillers {
            rules.append("2. Filler Words: Strip speech disfluencies and fillers (е-е, ну, типу, коротше, власне, так би мовити, як то кажуть) unless essential to meaning.")
        } else {
            rules.append("2. Filler Words: Retain spoken filler words and colloquialisms as uttered.")
        }

        if voiceCommands {
            rules.append("""
            3. Formatting & Punctuation Commands:
               - 'новий рядок' / 'з нового рядка' -> \\n
               - 'новий абзац' -> \\n\\n
               - 'знак оклику' -> !
               - 'знак питання' -> ?
               - 'двокрапка' -> :
               - 'крапка з комою' -> ;
               - 'тире' -> —
            """)
        } else {
            rules.append("3. Punctuation: Transcribe spoken punctuation words literally if uttered.")
        }

        rules.append("4. Developer Terminology & Proper Names: Preserve technical names and project entities in original casing and spelling (Shopify, Astryx, Clyro, Antigravity, Герич, Денчік, Ластівка, commit, branch, PR, Swift, Python, React, Next.js, API, GraphQL, Tailwind, Docker).")
        rules.append("5. Orthography: Always use proper Ukrainian Cyrillic orthography (e.g. 'диктовка', 'диктовці', never mix Latin characters like 'kt' into Ukrainian words).")

        switch formattingMode {
        case .cleanVerbatim:
            rules.append("6. Style: Clean verbatim. Clean up speech disfluencies and self-corrections but preserve the natural wording, sentence order, and tone of the speaker.")
        case .polished:
            rules.append("6. Style: Polished prose. Transform conversational spoken phrasing into clear, grammatically flawless, articulate business language. Fix fragmented sentences and ensure smooth professional flow.")
        case .bulletItems:
            rules.append("6. Style: Structured bullet points / action items. Structure the key ideas and action items into a clean Markdown bulleted list (- ...). Group related ideas together with concise, actionable wording.")
        case .aiPrompt:
            rules.append("6. Style: AI Engineer Prompt. Structure the output as a clear, imperative prompt or technical task specification for an AI agent/engineer. State the objective, context, and requirements cleanly.")
        }

        if appAwareFormatting, let target = targetApp?.lowercased(), !target.isEmpty {
            if target.contains("antigravity") || target.contains("cursor") || target.contains("code") || target.contains("xcode") || target.contains("terminal") || target.contains("ghostty") || target.contains("iterm") {
                rules.append("7. App Context: Target is a code editor or developer terminal. Ensure identifiers, commands, variables, and code comments are formatted precisely.")
            } else if target.contains("slack") || target.contains("telegram") || target.contains("messages") || target.contains("discord") {
                rules.append("7. App Context: Target is a team messenger. Keep formatting concise, direct, and conversational.")
            } else if target.contains("mail") || target.contains("outlook") || target.contains("spark") {
                rules.append("7. App Context: Target is an email client. Format into clear paragraphs with professional tone.")
            } else if target.contains("obsidian") || target.contains("notion") || target.contains("notes") {
                rules.append("7. App Context: Target is a knowledge base / note app. Use clean Markdown structure where appropriate.")
            }
        }

        rules.append("Final Output Format: Return STRICTLY the final recognized and cleaned text without quotation marks, conversational replies, or markdown code blocks (unless formatting as bullets/markdown). If no speech is present, return empty string.")

        sections.append(rules.joined(separator: "\n\n"))
        return sections.joined(separator: "\n\n")
    }

    // MARK: - Quick File Access
    public static func openVocabularyFile() {
        let path = ("~/.dnk_runtime/piu/vocabulary.json" as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: path)
        let dir = url.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        if !FileManager.default.fileExists(atPath: url.path) {
            let defaultVocab = [
                "Shopify", "Astryx", "Clyro", "Antigravity", "Герич", "Денчік", "Ластівка",
                "PR", "commit", "branch", "Swift", "Python", "GraphQL", "Tailwind", "Docker"
            ]
            if let data = try? JSONSerialization.data(withJSONObject: defaultVocab, options: [.prettyPrinted]) {
                try? data.write(to: url)
            }
        }
        NSWorkspace.shared.open(url)
    }

    public static func openCorrectionsFile() {
        let path = ("~/.dnk_runtime/piu/corrections.json" as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: path)
        let dir = url.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        if !FileManager.default.fileExists(atPath: url.path) {
            let defaultCorrections: [String: String] = [
                "діктовка": "диктовка",
                "діктовці": "диктовці"
            ]
            if let data = try? JSONSerialization.data(withJSONObject: defaultCorrections, options: [.prettyPrinted]) {
                try? data.write(to: url)
            }
        }
        NSWorkspace.shared.open(url)
    }
}
