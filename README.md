# 10 Tickets naar Vrijheid

Een snelle tik-game in het kantoor van Bluebird Day. De webshop voor
paardensupplementen moet vrijdag live, en de klant heeft het al aan de
dierenarts verteld. Tickets komen binnen op het bord; jij rent ze naar de
collega van het juiste vak, haalt ze op als ze klaar zijn en zet ze live op de
server. Tien live, dan mag je naar huis.

Godot 4.7.2 · GDScript · portret, gemaakt voor de telefoon · vijf dagen van
een paar minuten.

## Spelen

**In de browser: https://daanbbd.github.io/10-tickets-naar-vrijheid/**

Alles gaat met tikken (of klikken):

- **Tik op een ticket** op het bord: je loopt erheen en pakt het. Je kunt er
  twee tegelijk dragen.
- **Tik op een collega**: je brengt het ticket. Bureaus die het kunnen
  aannemen lichten op in de kleur van het ticket. Is iemand klaar (groen
  vinkje), tik hem dan nog een keer om het op te halen.
- **Tik op de server**: alles wat klaar is gaat live. Twee tegelijk scheelt
  tien minuten.
- Tikken stapelt: tik drie dingen achter elkaar en je doet ze op volgorde
  (de nummertjes laten zien waar je heen gaat). Tik op de vloer om gewoon
  ergens heen te lopen.

Je kiest wie je bent. **Je eigen vak doe je zelf**, aan je eigen bureau: dat
is sneller, maar je staat zolang stil.

Laat je een ticket te lang liggen, dan **belt De Klant**, en dat kost je
twintig minuten. Voor 17:00 thuis is drie sterren.

**De week:** maandag frontend en backend · dinsdag Danny en de koffie
(even sneller lopen) · woensdag Willem, en Jonathan die een stand-up begint
(zijn rij ligt stil tot je hem afkapt) · donderdag Daan, en Dirk die je uren
wil (tik hem weg voor hij je te pakken heeft) · vrijdag de livegang, met een
server die soms in brand vliegt.

Lokaal: open het project in Godot en druk op play, of
`/Applications/Godot.app/Contents/MacOS/Godot --path .`. De voortgang staat in
`user://rush.json`.

## Waar het zit

| | |
|---|---|
| `scripts/rush/rush_data.gd` | vakken, collega's, tickettitels, de vijf dagen en hun balans |
| `scripts/rush/rush_game.gd` | de spellus: bord, collega's, server, klant, Jonathan, Dirk, brand |
| `scripts/rush/rush_kantoor.gd` | de vloer van één scherm en wat erop staat |
| `scripts/rush/rush_hud.gd` | klok, tien vakjes, hintregel, intro- en uitslagscherm, pauze |
| `scripts/rush/rush_menu.gd` | titel, wie ben jij, de week |
| `scripts/rush/rush_klank.gd` | alle geluid van de rush op één plek |

Het oude avontuur (rondlopen over de hele verdieping, dialogen, minigames)
staat er nog en is bereikbaar via de oude QA-vlaggen (`--speler=`,
`--minigame=`, `--scherm=`). De personages, sprites, portretten, de vloer en
de AudioDirector komen daar vandaan.

## De rush testen

```bash
tools/rush_balans.sh
```

laat een bot elke dag spelen met vijf personages en print de eindtijden.
Eén dag los: `Godot --headless --path . -- --rush-bot --dag=3 --speler=victor --tempo=10`.
Met `--echt` (en zonder `--headless`) tikt de bot via echte invoergebeurtenissen,
en met `--blijf` stopt hij niet aan het eind, voor schoten met
`tools/qa_shot.py los <sec> --rush-bot --blijf ...`.

## Testen (het oude avontuur)

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
