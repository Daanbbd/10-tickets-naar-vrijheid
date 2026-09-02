# Testen

Drie lagen, allemaal zonder handmatig spelen.

## 1. Datasuite (headless)

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --scene res://tests/test_runner.tscn
```

Ruim **16.000 controles**, exitcode 1 bij fouten. Dekt:

- alle JSON laadt zonder fouten
- geen dode verwijzingen: ticket→anker, ticket→minigame, dialoog→node,
  keuze→node, world_change→`world_ids.json`, NPC→dialoog
- alleen bekende ops en conditie-keys in effects, world_changes en `when`
- elke `variants`-lijst eindigt op een fallback zonder `when`
- **geen placeholdertekst** (TODO, FIXME, lorem ipsum) in spelerzichtbare strings
- grid klopt met `size`, geen tekens buiten de legenda
- spawnpunt, objecten en NPC-standplaatsen staan niet in een muur
- elk samengesteld meubel heeft zijn PNG, de maat in de naam klopt met de
  footprint, en een hangend ruimtebordje hangt niet boven een solide tegel
- minigame-inhoud: slots accepteren bestaande kaarten, elke tagpicker heeft een
  haalbaar goed resultaat, elke choicescene-drempel is haalbaar, mg_deploy heeft
  een variant per personage
- **de questketen voor alle zeven personages**: van 0 tot 10/10, inclusief de
  controle dat een ticket buiten je vakgebied *niet* oplosbaar is zonder collega
- **elke startroute zet de tickets open** — `QuestEngine.start_run()` is de enige
  ingang; een script dat `Session.start_new()` los aanroept faalt de suite
- **elk anker is vanaf de start aanspreekbaar**, per personage. Een `visible_when`
  op een ankerobject dat op een ander ticket wacht maakt dat object onzichtbaar
  voor de probe: E doet dan niets, zonder prompt en zonder geluid
- **ticket-eigenaarschap**: in de dialoog van een ticket spreekt geen ander
  speelbaar personage dan de eigenaar, elke `when.character` is die van de
  eigenaar, en de tekst noemt geen andere collega bij naam
- **karakterstemmen**: signature-tics per personage, Bastiaans dubbele komma,
  zinsbegin per personage (alleen Danny en Bastiaan schrijven klein), geen tic
  van een ander personage, en elk personage heeft minstens twaalf eigen
  spelersvarianten. Die laatste twee kijken óók naar `when.character`-varianten,
  die op `speaker: "speler"` staan en daardoor eerder buiten elke controle vielen
- **de inside jokes**: Willem, Danny, Daan en Victor zeggen nooit kaal "omzet",
  en "Absoluta" staat bij Willem nooit zonder de correctie "Looff"
- **leesbaarheid**: `GRIJS_OP_LICHT` en `GRIJS_OP_DONKER` halen 4,5:1 (WCAG AA)
  op elke ondergrond waar ze op staan, en geen enkel script zet `UiKit.GRIJS`
  nog als tekstkleur. Die kleur haalt de norm nergens — 3,1:1 op een licht
  paneel, 3,9:1 op een donker, 2,7:1 op papier — en stond tot voor kort op elke
  uitleg- en statusregel in het spel. Terugvallen erop is geen parse-fout en in
  de editor niet te zien; het is alleen buiten niet te lezen
- **de chrome van de minigames**: hoogstens één `UiKit.knop_primair()` per
  minigamescript, en `build_chrome()` bouwt nog steeds een donker oppervlak.
  Twee gevulde knoppen op één scherm wijzen allebei nergens heen, en een chrome
  die terugvalt op de crème standaard van `UiKit.panel()` maakt de minigames
  weer het enige lichte scherm van het spel — met tien secundaire regels in een
  grijstint die daar de norm niet haalt
- **navigatie**: de kompasstrip rekent met de vloerbreedte uit `floor.json` en
  niet met een constante, elke zone past binnen die breedte, en de doelregel
  noemt de ruimte hoogstens één keer

Met `-- --print-briefings` erachter schrijft de suite bovendien alle negen
briefings van de eigenaars uit, gevuld met de echte getallen uit
`minigame_content.json`. Dat is de goedkoopste manier om die teksten als geheel
te lezen zonder een speelbeurt te spelen.

## 1b. Parsecontrole over alle scripts

```bash
for f in $(find scripts autoload -name "*.gd" | sort); do
  out=$(godot --headless --path . --check-only --script "$f" 2>&1 | grep "Parse Error")
  [ -n "$out" ] && { echo "### $f"; echo "$out"; }
done
```

Ongeveer 0,2 s per bestand, dus ~12 s voor het hele project. Dit is de goedkoopste
gate die er is en hij hoort **vóór** de testsuite in een CI-pipeline.

Waarom hij bestaat: `mg_abtest.gd` bevatte een regel
`chrome_header().add_child(meter)` met een niet-bestaande `meter`. Een parsefout
in een minigame-script blijft onzichtbaar totdat die minigame echt geladen
wordt — de testsuite valideert data en questlogica, en laadt de scenes niet.
Hij kwam boven water op ticket 6 van een `--playthrough`, twee minuten diep,
als "BBD-206 liep vast".

Filter op **`Parse Error`** en niet op elke fout: `--script` heeft geen
autoloads, dus elk script dat `Bus`, `Session`, `GameData`, `Shell` of
`AudioDirector` aanraakt levert een `Compile Error: Identifier not found` op.
Dat is een artefact van deze modus en geen fout in het bestand.

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

**Laatste run:** alle **zeven** personages exit 0, 10/10, vier van de vier
klantmeldingen, nul parse- of scriptfouten. Daan en Danny komen uit op 8u30
(uit om 17:42), de andere vijf op 9u (18:12).

Deze doorloop was tot voor kort een muntworp. Hij wachtte op
`Session.is_done(tid)`, en die valt vóór de urenrol en de afrondingsdialoog —
dus begon de harnas aan het volgende ticket terwijl de stroom van het vorige
nog liep, en dan weigert `TicketController.handle_npc_talk()` stil op zijn
`_busy`-guard. Dertig seconden later meldde de speelbeurt "npc_<naam> liep niet
mee" zonder oorzaak, op een ticket dat van framing afhing. Een echte speler kan
zijn eigen dialoog niet inhalen; de harnas kon dat wel en testte daarmee iets
wat niet bestaat. Hij wacht nu na elk ticket op `tickets.bezig()`.

De speelbeurt **haalt de collega's echt op**: hij loopt naar de NPC, voert het
wervingsgesprek en wacht tot die meeloopt, in plaats van de vlag
`helper_bij_<ticket>` te zetten. Dat is de route die een speler neemt, en juist
daar zat de bug dat werven niets zichtbaars veranderde. De regel
`[SPEELBEURT] BBD-203: Willem opgehaald, doel staat op t03` bewijst dat het
ticket ook gepind wordt.

## 3. Visuele controle

Godot kan frames als PNG wegschrijven:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . --write-movie qa/f.png \
  --quit-after 200 -- --speler=victor --auto=koffiemachine
```

Voor de vloer zelf is `--kijk=<x>,<y>` de vlag: die zet de speler op een tegel
en doet verder niets. `--auto=` kan dat niet vervangen — die triggert de
interactie en legt een dialoogvenster over de onderste derde van het beeld,
precies waar de slagschaduwen en de raamband staan.

> **Wat een shot van de vloer niet laat zien.** De camera klemt verticaal
> volledig vast: 26 tegels is precies de viewporthoogte, dus elke shot toont de
> hele hoogte en `--kijk` verschuift alleen in x. De HUD dekt daarbij de
> bovenste vier tegelrijen af en de knoppenbalk de onderste ~2,5. Alles op y0–y3
> en y24–y25 staat er dus wel, maar zie je nooit. Dat is de reden dat het
> raamlicht drie rijen beslaat en dat het toiletbordje op y6 hangt en niet naast
> zijn deur op y3.

## QA-vlaggen

Alles achter `--` en alleen voor testen:

| Vlag | Doet |
|---|---|
| `--speler=<id>` | slaat titel en selectie over |
| `--ticket=<id>` | vinkt alle eerdere tickets af |
| `--minigame=<id>` | draait één minigame los |
| `--gedaan=<n>` | zet eerst n tickets op opgelost (voor `--minigame`) |
| `--scherm=uitleg\|select\|einde` | opent dat scherm direct |
| `--doorgaan` | drukt "Doorgaan" op het titelscherm in, dus hervat de bewaarde run (combineer met `--scherm=titel`) |
| `--klant=<1-4>` | legt die melding van De Klant klaar zonder er tickets voor op te lossen |
| `--auto=<world_id>` | zet de speler bij dat object en interacteert |
| `--kijk=<x>,<y>` | zet de speler op die tegel en doet verder niets |
| `--autoplay` | drukt zelf op de interactietoets en lost minigames op |
| `--playthrough` | speelt alle tien de tickets af |
| `--geen-pin` | speelbeurt zonder een ticket te kiezen, zodat de keuzevraag op een gedeeld object echt afgaat |
| `--quit-when-done` | sluit af met exitcode 0/1 |
| `--bord` | opent het sprintbord meteen |
| `--kaart` | zet de besturingskaart in beeld en laat hem staan |
| `--hint` | vraagt meteen een hint aan, zodat het hintbriefje in beeld staat |
| `--briefing=<ticket>` | speelt de briefing van de eigenaar van dat ticket meteen af |
| `--shot=<pad.png>` | schrijft één frame weg en stopt (niet met `--headless`) |
| `--shot-na=<sec>` | wanneer die shot valt, standaard 2,5 s |

## Mobiel testen op een laptop

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

Geen vlag meer. Er was een `--touch` en een `--geen-touch`, en die zetten de
duimbesturing aan of uit — want er waren twee indelingen: een mobiele met een
knoppenbalk, en een desktopversie die naar toetsen verwees. Dat was de kern van
het probleem: **alle QA-shots stonden op `--touch` terwijl er met een
toetsenbord gespeeld werd**, dus de mobiele helft werd bekeken en nooit
gebruikt. Nu is er één besturing (`Besturing`) en zijn toetsen sneltoetsen naar
dezelfde knoppen. Wat je op je laptop ziet is wat er op een telefoon staat.

De **muis bestuurt de joystick**: `Besturing._input()` accepteert
`InputEventMouseButton`/`MouseMotion` zolang `DisplayServer.is_touchscreen_available()`
onwaar is (`Invoer.muis_als_vinger()`). Klikken en slepen in de linkeronderhoek
werkt dus als een duim, en tikken op het dialoogvenster zet door.

Die voorwaarde is geen luxe. Godot emuleert standaard óók de andere kant op
(`emulate_mouse_from_touch`), dus op een echte telefoon levert één vinger zowel
een ScreenTouch als een MouseButton op — zonder die wacht zou die vinger de
joystick twee keer aansturen.

> **Wat hiermee niet te testen is:** of het venster op het scherm past. De
> QA-shots renderen de viewport, niet het OS-venster, dus een afgekapte
> onderrand is er onzichtbaar. Zie de venstermaat-valkuil in ARCHITECTURE.md.

## Let op: de globale class-cache

`.godot/global_script_class_cache.cfg` mag **niet** verwijderd worden zonder daarna
`Godot --headless --path . --editor --quit` te draaien: alleen de editor kan die cache
herbouwen, headless niet. Zonder geldige cache laadt `main.tscn` helemaal niet.

Datzelfde geldt bij het **toevoegen** van een script met een nieuwe
`class_name`. De cache kent die klasse dan nog niet, en de eerstvolgende run
faalt met `Parse Error: Identifier "X" not declared` — in een bestand dat er
niets mee te maken heeft, want het is de autoload-keten die omvalt. Draai dus
na elk nieuw `class_name`:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --editor --quit
```

`.godot/` staat in `.gitignore`, dus **elke verse clone en elke CI-run begint
met een koude cache.** De editorpas hoort daarom de eerste stap van een
CI-pipeline te zijn, vóór de testsuite. Draai hem ook niet parallel met een
andere Godot-run op dezelfde werkboom: twee processen die de cache tegelijk
herschrijven laten hem leeg achter.

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
- de karakterselectie riep `Session.start_new()` aan zonder
  `QuestEngine.initialise_tickets()`: elk ticket bleef LOCKED, elk object zei
  "hier is nu niets te doen" en de hint meldde dat alles al opgelost was. De
  QA-snelstart deed het paar wél, dus de enige route met de bug was de route die
  een speler neemt
- `wachtbank`, het anker van BBD-203, had nog een `visible_when` op BBD-202 uit
  de verlaten ketenopzet. BBD-203 ligt in de spawnzone en is dus het eerste
  ticket dat je vindt: de doelwijzer plantte zich voor elke nieuwe speler op een
  object waar E niets deed
- commit `9da2cf2` verschoof BBD-208 en BBD-209 naar Koen en Bastiaan zonder de
  dialoog mee te verhuizen. Naam en portret komen uit het `speaker`-veld, dus je
  liep naar Bastiaan en kreeg Jonathan te zien — en Koen en Bastiaan hadden
  nergens in het spel een eigen spelersvariant

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

De export dekt de besturing, want die is er nu altijd: de knoppenbalk hangt
niet meer aan een apparaatvraag. Wat een mobiele browser wél verandert is
`DisplayServer.is_touchscreen_available()`, en dus of een muisklik voor een
vingertik doorgaat (`Invoer.muis_als_vinger()`).

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
