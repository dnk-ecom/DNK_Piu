# Changelog — DNK_Piu

All notable changes to **DNK_Piu** (Sovereign Voice Dictation & Audio HUD) will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.1.0] - 2026-11-18

### 🚀 Initial Public Milestone: "Sovereign Whisper"

#### Added
- **Pure Voice-to-Caret Architecture**:
  - Hold `⌥ Option` (or double-tap for hands-free) to dictate anywhere on macOS.
  - Coucou-standard synchronous `CGEvent` ⌘V injection directly into active caret.
  - Persistent code-signing certificate (`DNK Piu Local Signing`) guaranteeing Accessibility permissions survive app restarts.
- **Ultra-Laconic Floating Capsule (`WisprFlowPillView`)**:
  - Wispr Flow-style floating dark glass capsule (32pt height).
  - Clean state transitions: Listening (116pt), Thinking (80pt), Inserted (124pt).
  - Guaranteed single-line layout (`.lineLimit(1)` + `.fixedSize()`) preventing text wrapping.
- **Swallow Icon Micro-Transformations (`SwallowIconView`)**:
  - **🔴 Listening**: Swallow turns red (`#EF4444`) and organically pulses with voice level (`scale: 1.0 + level * 0.22`) and red neon glow.
  - **🔵 Thinking**: Swallow turns electric sapphire blue (`#3B82F6`) with wing-flutter hovering animation (`sin(t * 5) * 6.5°`) and 7 matching blue equalizer bars.
  - **🟢 Inserted**: Swallow flashes electric mint (`#36F4A4`) with clean "Вставлено" label.
  - Synchronized status bar icon tinting in macOS menubar (`NSStatusItem`).
- **Native Voice History HUD (`HistoryWindow.swift`)**:
  - Hotkey `⌘H` or menubar access.
  - Sleek, native macOS list rows with quiet metadata (`time • relative • app`).
  - Single-click to insert into active app window, or copy to clipboard (`⌘C`).
  - Search filter and time-range filtering ("Остання 1 год", "Сьогодні", "Усі записи").
- **Design System Parity (Electric Mint & Forest Teal)**:
  - Default palette matching DNK OS & Shopify Open Design research (`Canvas #02090A`, `Electric Mint #36F4A4`, `Forest Teal #008060`).
  - Optional `Obsidian Slate` theme mode.
- **Intelligent Speech-to-Text & Bridge**:
  - Google Cloud Vertex AI (Gemini 3.5 Flash Lite) with intelligent self-correction (auto-replaces stumbles, cleans filler words, executes voice punctuation commands).
  - Non-blocking asynchronous event persistence in `~/.dnk_runtime/piu/voice_events.jsonl` and dispatch to Astryx Action Bus.

#### Removed
- Heavy sidebars, static AI mock cards, and cluttered debug dashboards.
- Redundant external branding badges from the menubar interface.
