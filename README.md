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
pauzemenu, en een minigame afbreken.

**Besturing (telefoon)** — zet je duim ergens in de onderste tweederde van het
scherm en er komt een joystick op, links of rechts; ver uitduwen is rennen ·
tik op een object om ermee te doen wat er bij staat · **▤** je tickets · **?**
hint · **☰** pauze. Die drie knoppen staan linksonder en zijn de enige plek
waar geen joystick opkomt.

Met een muis komt er geen joystick op — daar loop je met WASD en klik je op een
object waar je naast staat.

Je krijgt deze uitleg ook in het spel: één scherm na je personagekeuze, met de
besturing van het apparaat waar je op speelt. Later nog eens nodig? **F1**.

Je dag wordt bij elk opgelost ticket bewaard, en ook als je de app wegdrukt.
**Doorgaan** op het titelscherm zet je terug waar je gebleven was.

De dag begint bij de kickoff: BBD-201 ("Wat moeten we eigenlijk bouwen?") staat
open zodra je binnenkomt, samen met drie andere tickets, en haar feedback en de
AI-video komen daar pas achteraan. De rest komt vrij door werk af te maken. Je vindt ze door rond te lopen, en je kiest op het bord welke je als
eerste doet. Tien tickets, tien verschillende opgaven — geen twee delen een
mechaniek. Wat je onderweg besluit komt terug:
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
