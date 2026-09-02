# 10 Tickets naar Vrijheid

Een Nederlandstalige top-down pixel-art comedy adventure op één verdieping van
Bluebird Day. Je kiest één collega, lost tien tickets op rond een webshop voor
paardensupplementen, en mag pas naar buiten bij 10/10.

Godot 4.7.2 · GDScript · ~25 minuten speeltijd.

## Spelen

**In de browser: https://daanbbd.github.io/10-tickets-naar-vrijheid/**

Werkt op desktop en op een telefoon; op een aanraakscherm verschijnt de
duimbesturing. Bijwerken na een wijziging gaat met `tools/deploy_web.sh`.

## Lokaal spelen

Open het project in Godot en druk op play, of vanaf de command line:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

**Besturing (toetsenbord)** — WASD of pijltjes lopen · Shift rennen · **E**
praten, onderzoeken, gebruiken · **TAB** je tickets · **Q** hint · **ESC**
minigame afbreken.

**Besturing (telefoon)** — duim links om te lopen, ver uitduwen is rennen · de
knop rechtsonder draagt het werkwoord van waar je voor staat · **▤** je tickets
· **?** hint.

De tickets staan allemaal tegelijk open. Je vindt ze door rond te lopen, en je
kiest op het bord welke je als eerste doet. Elf tickets, elf verschillende
opgaven — geen twee delen een mechaniek. Wat je onderweg besluit komt terug:
in wat je collega's zeggen, in wat De Klant je stuurt, en in hoe zwaar de
oplevering begint.

## Testen

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --scene res://tests/test_runner.tscn
```

Een volledige geautomatiseerde speelbeurt:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 40000 \
  -- --speler=daan --playthrough --autoplay --quit-when-done
```

Zie `docs/TESTING.md` voor alle QA-vlaggen.

## Assets opnieuw genereren

Alle pixel art en audio wordt door scripts gemaakt, niet met de hand.

```bash
python3 -m venv tools/.venv && tools/.venv/bin/pip install Pillow
tools/.venv/bin/python tools/generators/gen_tiles.py       # tileset
tools/.venv/bin/python tools/generators/gen_characters.py  # spritesheets
tools/.venv/bin/python tools/generators/gen_props.py       # paarden, iconen
tools/.venv/bin/python tools/generators/gen_portraits.py   # portretten uit assets/personen/
tools/.venv/bin/python tools/generators/gen_floor.py       # data/floor.json
python3 tools/generators/gen_audio.py                      # sfx + muziek (stdlib + ffmpeg)
```

## Documentatie

| | |
|---|---|
| `docs/GAME_DESIGN.md` | kernloop, toon, scope |
| `docs/ARCHITECTURE.md` | autoloads, datamodel, valkuilen |
| `docs/QUESTS.md` | de tien tickets en hun wereldveranderingen |
| `docs/CHARACTERS.md` | speelbare personages en NPC's |
| `docs/LEVEL.md` | de verdieping en hoe je hem vervangt |
| `docs/MINIGAMES.md` | de zes mechanieken |
| `docs/TESTING.md` | testaanpak en QA-vlaggen |

## Structuur

```
autoload/     Bus, GameData, Session, Shell, AudioDirector
scripts/      core, world, entities, ui, minigames, tests
scenes/       boot, world, entities, minigames
data/         characters, npcs, items, tickets, dialogue, floor, objects, minigames
assets/       gegenereerde sprites, tilesets, audio + de teamfoto's
tools/        generatoren voor alle assets
tests/        headless testsuite
```
