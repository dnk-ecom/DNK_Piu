#!/usr/bin/env python3
"""
piu-history: CLI tool to inspect, search, and manage DNK_Piu dictated voice events.
"""
import argparse
import json
import os
import subprocess
import sys
import time

EVENTS_FILE = os.path.expanduser("~/.dnk_runtime/piu/voice_events.jsonl")
VOCAB_FILE = os.path.expanduser("~/.dnk_runtime/piu/vocabulary.json")
CORRECTIONS_FILE = os.path.expanduser("~/.dnk_runtime/piu/corrections.json")


def manage_vocab(add_term: str = None, show: bool = False):
    vocab = []
    if os.path.exists(VOCAB_FILE):
        try:
            with open(VOCAB_FILE, "r", encoding="utf-8") as f:
                vocab = json.load(f)
        except Exception:
            vocab = []
    if add_term:
        term = add_term.strip()
        if term and term not in vocab:
            vocab.append(term)
            with open(VOCAB_FILE, "w", encoding="utf-8") as f:
                json.dump(vocab, f, ensure_ascii=False, indent=2)
            print(f"✅ Додано до персонального словника: \"{term}\"")
        else:
            print(f"ℹ️ Термін \"{term}\" вже присутній у словнику.")
    if show or not add_term:
        print("\n📚 ПЕРСОНАЛЬНИЙ СЛОВНИК ТЕРМІНІВ ТА ВИРАЗІВ DNK_PIU:")
        print("═" * 50)
        for idx, term in enumerate(vocab, 1):
            print(f"  {idx}. {term}")
        print(f"\nФайл: {VOCAB_FILE}\n")


def manage_corrections(wrong: str = None, right: str = None, show: bool = False):
    corrections = {}
    if os.path.exists(CORRECTIONS_FILE):
        try:
            with open(CORRECTIONS_FILE, "r", encoding="utf-8") as f:
                corrections = json.load(f)
        except Exception:
            corrections = {}
    if wrong and right:
        corrections[wrong.strip()] = right.strip()
        with open(CORRECTIONS_FILE, "w", encoding="utf-8") as f:
            json.dump(corrections, f, ensure_ascii=False, indent=2)
        print(f"✅ Додано правило автовиправлення: \"{wrong}\" ➔ \"{right}\"")
    if show or not (wrong and right):
        print("\n🛠️ ПРАВИЛА АВТОВИПРАВЛЕНЬ (ACOUSTIC CORRECTIONS):")
        print("═" * 50)
        for k, v in corrections.items():
            print(f"  • {k} ➔ {v}")
        print(f"\nФайл: {CORRECTIONS_FILE}\n")


def format_duration(seconds: float) -> str:
    if seconds < 60:
        return f"{int(seconds)}с тому"
    elif seconds < 3600:
        return f"{int(seconds // 60)}хв тому"
    else:
        hours = seconds / 3600
        return f"{hours:.1f}год тому"


def load_events():
    if not os.path.exists(EVENTS_FILE):
        return []
    events = []
    with open(EVENTS_FILE, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                events.append(json.loads(line))
            except Exception:
                continue
    return events


def show_history(hours: float = 1.0, limit: int = 20, search: str = None):
    events = load_events()
    if not events:
        print("📭 Журнал надиктовок порожній.")
        return

    now = time.time()
    cutoff = now - (hours * 3600) if hours > 0 else 0

    filtered = [e for e in events if e.get("timestamp", 0) >= cutoff]
    if search:
        search_lower = search.lower()
        filtered = [e for e in filtered if search_lower in e.get("text", "").lower()]

    if not filtered:
        print(f"📭 За останні {hours} год записів не знайдено.")
        return

    print(f"\n🕊️ ЖУРНАЛ НАДИКТОВОК DNK_PIU (Останні {hours} год, всього: {len(filtered)})")
    print("═" * 70)

    # Show newest first
    reversed_list = list(reversed(filtered))[:limit]
    for idx, e in enumerate(reversed_list, 1):
        ts = e.get("timestamp", 0)
        t_str = time.strftime("%H:%M:%S", time.localtime(ts))
        time_ago = format_duration(now - ts)
        app_id = e.get("target_app", "unknown")
        app_name = app_id.split(".")[-1]
        text = e.get("text", "")

        print(f" \033[1;36m[{idx}]\033[0m \033[1;32m{t_str}\033[0m \033[90m({time_ago} ➔ {app_name})\033[0m")
        print(f"     {text}\n")

    print(f"📁 Файл журналу: {EVENTS_FILE}")
    print("💡 Копіювати в буфер: piu-history --copy <INDEX>\n")


def copy_event(index: int, hours: float = 1.0):
    events = load_events()
    now = time.time()
    cutoff = now - (hours * 3600) if hours > 0 else 0
    filtered = [e for e in events if e.get("timestamp", 0) >= cutoff]
    reversed_list = list(reversed(filtered))

    if index < 1 or index > len(reversed_list):
        print(f"❌ Невірний індекс {index}. Доступно: 1..{len(reversed_list)}")
        return

    target = reversed_list[index - 1]
    text = target.get("text", "")
    p = subprocess.Popen(["pbcopy"], stdin=subprocess.PIPE)
    p.communicate(text.encode("utf-8"))
    print(f"✅ Скопійовано в буфер обміну [#{index}]: \"{text}\"")


def open_gui_hud():
    """Trigger the native macOS floating HUD via URL scheme or distributed notification."""
    try:
        subprocess.run(["open", "dnk-piu://history"], check=True)
        print("🕊️ Відкрито нативний журнал надиктовок DNK_Piu (HUD).")
    except Exception as e:
        print(f"⚠️ Помилка виклику HUD: {e}")


def main():
    parser = argparse.ArgumentParser(description="DNK_Piu Voice History Inspector")
    parser.add_argument("--hours", "-H", type=float, default=1.0, help="Фільтр за годинами (за замовчуванням: 1.0)")
    parser.add_argument("--all", "-a", action="store_true", help="Показати всі записи без обмеження часу")
    parser.add_argument("--limit", "-n", type=int, default=30, help="Максимальна кількість записів")
    parser.add_argument("--search", "-s", type=str, default=None, help="Пошук за словом чи фразою")
    parser.add_argument("--copy", "-c", type=int, default=None, help="Скопіювати запис за номером [N] в буфер")
    parser.add_argument("--open", "-o", "--gui", "-g", action="store_true", help="Відкрити нативний графічний HUD журнал надиктовок")
    parser.add_argument("--jsonl", action="store_true", help="Відкрити сирий JSONL файл у системному редакторі")
    parser.add_argument("--vocab", action="store_true", help="Показати персональний словник термінів та виразів")
    parser.add_argument("--vocab-add", type=str, metavar="TERM", help="Додати термін або вираз до персонального словника")
    parser.add_argument("--corrections", action="store_true", help="Показати поточні правила автовиправлень")
    parser.add_argument("--fix", nargs=2, metavar=("WRONG", "RIGHT"), help="Додати правило автовиправлення: --fix 'помилкове' 'вірне'")

    args = parser.parse_args()

    if args.vocab or args.vocab_add is not None:
        manage_vocab(add_term=args.vocab_add, show=args.vocab or not args.vocab_add)
        return

    if args.corrections or args.fix is not None:
        wrong = args.fix[0] if args.fix else None
        right = args.fix[1] if args.fix else None
        manage_corrections(wrong=wrong, right=right, show=args.corrections or not args.fix)
        return

    if args.open:
        open_gui_hud()
        return

    if args.jsonl:
        subprocess.run(["open", EVENTS_FILE])
        return

    if args.copy is not None:
        copy_event(args.copy, hours=0 if args.all else args.hours)
        return

    show_history(hours=0 if args.all else args.hours, limit=args.limit, search=args.search)


if __name__ == "__main__":
    main()
