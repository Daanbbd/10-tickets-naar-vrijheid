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
| `--geen-pin` | speelbeurt zonder een ticket te kiezen, zodat de keuzevraag op een gedeeld object echt afgaat |
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
python3 tools/serve_web.py            # standaard poort 8060, met TLS
```

Het script print twee adressen: eerst een eenmalige certificaat-installatie,
daarna de game. Volg die volgorde — stap 2 werkt niet zonder stap 1, of alleen
door een waarschuwing heen te klikken.

Die TLS is geen luxe. Godot 4.7 weigert te starten buiten een secure context:
`getMissingFeatures()` in de shell checkt `window.isSecureContext` en meldt
anders alleen `Secure Context - Check web server configuration (use HTTPS)`.
Localhost is secure, een LAN-IP over http niet — dus een build die op je Mac via
`127.0.0.1` prima draait komt op je telefoon niet voorbij het laadscherm. Dat is
de makkelijkste manier om een uur te verliezen.

Het script maakt daarom een eigen mini-CA plus servercertificaat in
`build/cert/` (genegeerd, want daar staan privésleutels). Vier dingen daaraan
mogen niet weg, want Apple weigert sinds iOS 13 een certificaat dat er niet aan
voldoet **zonder doorklik-optie** — je krijgt dan geen waarschuwing maar een
blokkade:

| eis | waarom |
|---|---|
| `subjectAltName` met het IP | iOS negeert de CN volledig |
| `extendedKeyUsage=serverAuth` | ontbreekt deze, dan faalt het stil |
| SHA-256, RSA ≥ 2048 | zwakkere combinaties worden geweigerd |
| geldigheid ≤ 398 dagen | langer levende certificaten worden geweigerd |

En de CA moet écht een CA zijn (`basicConstraints=critical,CA:TRUE`): iOS toont
alleen root-certificaten onder Certificaatvertrouwen. Een los self-signed
servercertificaat laat zich wel installeren, maar is daar niet aan te zetten —
dan lijkt het gelukt en werkt het alsnog niet.

De CA wordt over gewoon http aangeboden, want anders heb je het certificaat
nodig om het certificaat te kunnen ophalen. Controleer de keten desgewenst met:

```bash
openssl verify -CAfile build/cert/ca.pem build/cert/<ip>.pem
curl --cacert build/cert/ca.pem https://<ip>:8060/index.html   # zonder -k
```

Python's `http.server` kent `.wasm` niet op macOS, en zonder die mimetype
weigert de browser `instantiateStreaming`; daarom zet het script de mimetypes en
de COOP/COEP-headers ook zelf.

Ruim na de test het profiel op de telefoon op (Instellingen → Algemeen → VPN en
apparaatbeheer) en `rm -rf build/cert` op de Mac. Een vertrouwde CA op een
persoonlijk toestel laat je niet slingeren.

Wil je de certificaatwaarschuwing helemaal kwijt, dan is een tunnel met een echt
certificaat (cloudflared, ngrok) de weg — maar dat zet de build op het open
internet, dus dat is een bewuste keuze en geen standaardstap.

De Web-preset staat op `variant/thread_support=false`, want mét threads eist de
browser die COOP/COEP-headers ook van elke hostende partij.

`build/` is genegeerd, en `export_presets.cfg` ook. Die preset staat dus niet in
een verse clone, en daarom staan de drie waarden die niet vanzelf goed gaan
hier:

| optie | waarde | waarom |
|---|---|---|
| `vram_texture_compression/for_mobile` | `false` | op `true` weigert de export met "configuration errors" zolang `import_etc2_astc` uitstaat — en blokcompressie smeert pixel-art uit, wat botst met `default_texture_filter=0` |
| `vram_texture_compression/for_desktop` | `false` | idem |
| `html/head_include` | `<meta name="apple-mobile-web-app-capable" content="yes">` | zonder dit opent "Zet op beginscherm" op iOS een Safari-tab met adresbalk, en test je de portretlayout met minder hoogte dan het echt is |

De exportfout hierboven meldt "due to configuration errors" en zet er dan niets
achter, ook niet met `--verbose`. De oorzaak is vrijwel altijd de
texturecompressie.

Dit werkt pas zodra de export templates geïnstalleerd zijn — zie hieronder.

## Wat een webexport níet test

De export dekt de duimbesturing: `Invoer.touch()` accepteert ook
`DisplayServer.is_touchscreen_available()`, en die is waar in een mobiele
browser.

Twee dingen dekt hij niet.

De **veilige zone** niet. `UiKit.veilige_insets()` leunt op
`DisplayServer.get_display_safe_area()`, en het webplatform vult die niet: in
`godot.js` staat geen enkele verwijzing naar `env(safe-area-inset-*)`, dus de
engine kan de insets niet weten en geeft de hele ruit terug. De notch is alleen
op een echte iOS- of Android-build te controleren.

De **app-pauze** vermoedelijk niet. `NOTIFICATION_APPLICATION_PAUSED` is een
iOS/Android-notificatie; op web komt alleen focus in/uit, en `Shell` laat die
route alleen door als `OS.has_feature("mobile")` waar is. Of die vlag op een
web-export waar is, is niet vastgesteld. Te meten door het toestel te
vergrendelen en terug te komen: als het spel gepauzeerd stond en het geluid uit
was, liep de route.

## Bekende beperkingen

- Geen export templates geïnstalleerd, dus geen standalone build. Het project
  draait vanuit de editor of via `--path`.
- De speelbeurt teleporteert tussen ankers en simuleert het ophalen van een
  collega; het lopen en de follow-AI worden handmatig gecontroleerd.
