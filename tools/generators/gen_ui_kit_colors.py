"""Genereert UiKit's kleurconstanten (scripts/ui/ui_kit.gd) uit palette.py.

palette.py is de enige hand-onderhouden kleurbron in dit project — dit
script leest zijn `P`-dict en schrijft het GEGENEREERD-blok in ui_kit.gd
terug. Draai dit opnieuw na elke wijziging aan de merk-/UI-kleuren in
palette.py; wijzig het blok in ui_kit.gd zelf nooit met de hand.

    python3 tools/generators/gen_ui_kit_colors.py

Met --check schrijft het niets weg, maar vergelijkt alleen: dit is de
sync-test tussen palette.py en ui_kit.gd (geen apart testframework nodig,
dit project heeft er nog geen voor Python). Faalt met exit-code 1 als
iemand ui_kit.gd handmatig heeft gewijzigd zonder de generator te draaien,
of als palette.py is gewijzigd zonder ui_kit.gd bij te werken:

    python3 tools/generators/gen_ui_kit_colors.py --check
"""
import sys
from pathlib import Path

from palette import P

ROOT = Path(__file__).resolve().parent.parent.parent
UI_KIT = ROOT / "scripts" / "ui" / "ui_kit.gd"

START = "# --- GEGENEREERD UIT palette.py, NIET HANDMATIG BEWERKEN — START ---"
END = "# --- GEGENEREERD UIT palette.py, NIET HANDMATIG BEWERKEN — EINDE ---"

# (UiKit-constante, palette.py-key, korte uitleg van de relatie tot BBD)
MAPPING = [
    ("INK", "bb_night", "letterlijk bb-night"),
    ("PANEL", "bb_day", "letterlijk bb-day"),
    ("PANEL_DARK", "ui_panel_donker", "neutrale derivaat"),
    ("LINE", "ui_line", "neutrale derivaat"),
    ("GRIJS", "ui_grijs", "neutrale derivaat"),
    ("WIT", "wit", "neutraal"),
    ("BLUEBIRD_INK", "bb_blue", "letterlijk bb-blue, voor lichte ondergrond"),
    ("BLUEBIRD_BRIGHT", "ui_bluebird_bright", "derivaat voor donkere ondergrond — bb-blue zelf is daar te donker om te lezen"),
    ("BLUEBIRD_TINT", "bb_light_blue", "letterlijk bb-light-blue"),
    ("GROEN", "ui_groen", "derivaat van bb-green, leesbaar op 8-10px"),
    ("GROEN_TINT", "bb_green", "letterlijk bb-green"),
    ("ROOD", "ui_rood", "game-only utility — BBD heeft geen foutkleur"),
    ("ORANJE", "ui_oranje", "derivaat van bb-orange, leesbaar op 8-10px"),
    ("ORANJE_TINT", "bb_orange", "letterlijk bb-orange"),
    ("ROZE_TINT", "bb_pink", "letterlijk bb-pink — gereserveerd voor mensen/cultuur"),
    ("NEUTRAAL_TINT", "ui_neutraal_tint", "letterlijk --color-line — voor niet-accent states"),
]


def hex_of(key: str) -> str:
    r, g, b = P[key]
    return f"#{r:02x}{g:02x}{b:02x}"


def build_block() -> str:
    name_w = max(len(name) for name, _, _ in MAPPING)
    lines = [START]
    for name, key, note in MAPPING:
        decl = f'const {name.ljust(name_w)} := Color("{hex_of(key)}")'
        lines.append(f"{decl}  # {key} — {note}")
    lines.append(END)
    return "\n".join(lines)


def main() -> None:
    check_only = "--check" in sys.argv[1:]

    text = UI_KIT.read_text()
    if START not in text or END not in text:
        raise SystemExit(
            f"Markers niet gevonden in {UI_KIT} — voeg eerst handmatig "
            f"'{START}' en '{END}' toe op de plek waar de kleurconstanten "
            "moeten komen."
        )
    start_i = text.index(START)
    end_i = text.index(END) + len(END)
    new_text = text[:start_i] + build_block() + text[end_i:]

    if new_text == text:
        print("ui_kit.gd was al up-to-date.")
        return

    if check_only:
        print(
            f"NIET IN SYNC: {UI_KIT} wijkt af van palette.py. "
            "Draai 'python3 tools/generators/gen_ui_kit_colors.py' "
            "(zonder --check) om bij te werken.",
            file=sys.stderr,
        )
        sys.exit(1)

    UI_KIT.write_text(new_text)
    print(f"ui_kit.gd bijgewerkt uit palette.py ({len(MAPPING)} kleuren).")


if __name__ == "__main__":
    main()
