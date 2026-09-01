# Testen

Drie lagen, allemaal zonder handmatig spelen.

## 1. Datasuite (headless)

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --scene res://tests/test_runner.tscn
```

Ruim **5000 controles**, exitcode 1 bij fouten. Dekt:

- alle JSON laadt zonder fouten
- geen dode verwijzingen: ticket→anker, ticket→minigame, dialoog→node,
  keuze→node, world_change→`world_ids.json`, NPC→dialoog
- alleen bekende ops en conditie-keys in effects, world_changes en `when`
- elke `variants`-lijst eindigt op een fallback zonder `when`
- **geen placeholdertekst** (TODO, FIXME, lorem ipsum) in spelerzichtbare strings
- grid klopt met `size`, geen tekens buiten de legenda
- spawnpunt, objecten en NPC-standplaatsen staan niet in een muur
- minigame-inhoud: slots accepteren bestaande kaarten, elke tagpicker heeft een
  haalbaar goed resultaat, elke choicescene-drempel is haalbaar, mg_deploy heeft
  een variant per personage
- **de questketen voor alle vijf personages**: van 0 tot 10/10, inclusief de
  controle dat een ticket buiten je vakgebied *niet* oplosbaar is zonder collega

## 2. Speelbeurt in de echte runtime

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 40000 \
  -- --speler=daan --playthrough --autoplay --quit-when-done
```

Loopt alle tien de tickets af in de draaiende game: dialogen, minigames,
wereldveranderingen, de voordeur en het eindscherm. De autopilot stuurt echte
`InputEventAction`s door de normale invoerketen en lost elke minigame op via
`qa_solve()`, dus de echte wincondities worden getest.

Exitcode 0 alleen bij 10/10. Status per ticket komt op stdout.

**Laatste run:** alle vijf personages exit 0, 10/10, nul scriptfouten.

## 3. Visuele controle

Godot kan frames als PNG wegschrijven:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . --write-movie qa/f.png \
  --quit-after 200 -- --speler=victor --auto=koffiemachine
```

## QA-vlaggen

Alles achter `--` en alleen voor testen:

| Vlag | Doet |
|---|---|
| `--speler=<id>` | slaat titel en selectie over |
| `--ticket=<id>` | vinkt alle eerdere tickets af |
| `--minigame=<id>` | draait één minigame los |
| `--scherm=select\|einde` | opent dat scherm direct |
| `--auto=<world_id>` | zet de speler bij dat object en interacteert |
| `--autoplay` | drukt zelf op de interactietoets en lost minigames op |
| `--playthrough` | speelt alle tien de tickets af |
| `--quit-when-done` | sluit af met exitcode 0/1 |
| `--touch` | zet de duimbesturing aan op de desktop (stick + knoppen) |
| `--geen-touch` | zet de duimbesturing uit op een aanraakscherm |
| `--shot=<pad.png>` | schrijft één frame weg en stopt (niet met `--headless`) |
| `--shot-na=<sec>` | wanneer die shot valt, standaard 2,5 s |

## Let op: de globale class-cache

`.godot/global_script_class_cache.cfg` mag **niet** verwijderd worden zonder daarna
`Godot --headless --path . --editor --quit` te draaien: alleen de editor kan die cache
herbouwen, headless niet. Zonder geldige cache laadt `main.tscn` helemaal niet.

De meegeleverde skills-bibliotheek `GD-Agentic-Skills/` declareert zelf
`class_name Interactable` (die erft van `Area3D`) en kaapte daarmee de registry, waardoor
`Interactable.Kind` verdween en de speelbeurt hieronder volledig faalde. Daarom staat er
nu een `.gdignore` in die map. Zet die niet weg.

## Bugs die deze aanpak heeft gevonden

- `TileSetAtlasSource` moet aan de `TileSet` hangen vóór `get_tile_data()`
- een in code gemaakte Control onder een in code gemaakte CanvasLayer blijft 0×0
- BBD-202 en BBD-209 delen één anker; het object kende maar één ticket, waardoor
  BBD-209 onbereikbaar was — gevonden door de speelbeurt, niet door de datasuite
- `owner_character: ""` op BBD-210 maakte de finale onbereikbaar

## Op een echte telefoon testen

De duimbesturing, de veilige zone en de app-pauze zijn niet headless te
controleren: ze hangen aan een aanraakscherm, aan `get_display_safe_area()` en
aan een OS dat de app wegdrukt. Daarvoor is een webexport op het LAN de
kortste weg — geen kabel, geen developer-account, geen installatie.

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  --export-release Web build/web/index.html
python3 tools/serve_web.py            # standaard poort 8060
```

Het script print het LAN-adres dat je op de telefoon opent. Python's
`http.server` kent `.wasm` niet op macOS, en zonder die mimetype weigert de
browser `instantiateStreaming`; daarom zet `serve_web.py` de mimetypes en de
COOP/COEP-headers zelf.

De Web-preset staat op `variant/thread_support=false`, want mét threads eist de
browser die COOP/COEP-headers ook van elke hostende partij. `build/` is
genegeerd; `export_presets.cfg` ook, dus de preset staat niet in een verse
clone.

Dit werkt pas zodra de export templates geïnstalleerd zijn — zie hieronder.

## Bekende beperkingen

- Geen export templates geïnstalleerd, dus geen standalone build. Het project
  draait vanuit de editor of via `--path`.
- De speelbeurt teleporteert tussen ankers en simuleert het ophalen van een
  collega; het lopen en de follow-AI worden handmatig gecontroleerd.
