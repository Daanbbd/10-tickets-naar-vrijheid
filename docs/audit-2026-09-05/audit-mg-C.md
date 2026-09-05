# Audit onderdeel C — mg_deploy, mg_urenstaat, de drie wereldhandelingen, tekstpijplijn

Getoetst aan `genre-party.md` (geen lange teksttutorials, één zin instructie,
score-moment), `game-loop-time-trial.md` (druk/klok), `tweening.md`
(feedback/climax), `agent-vision-vision-review-rubric.md` (framebeoordeling).
Lat: spanning + adrenaline + "yes, gehaald" — voor accountmanager én insider.

---

## 1. Tekstpijplijn — 9 minigame-id's met eigenaarsbriefing

`data/minigame_content.json` telt 11 ids; 9 hebben een `briefing`-veld dat via
`Briefing.regel()` → `TicketController._briefing()` door de eigenaar wordt
gezegd (BBD-201..209). `mg_deploy`/`mg_urenstaat` hebben dat veld niet (eigen
ticket resp. Dirk spreekt apart, zie §2).

Briefing-telling komt uit `--print-briefings` (dus **na** `Briefing.vul()`,
inclusief meerwoordige plaatshouders als `{belangrijk}` — een kale
JSON-telling gaf `mg_planning` ten onrechte op 27 i.p.v. de echte 34).
WAT/WAAROM/success/failure bevatten in deze 9 geen plaatshouders.

| id | type | briefing | WAT | WAAROM | success | failure | woorden vóór spel |
|---|---|--:|--:|--:|--:|--:|--:|
| mg_user_story | scope | 34 | 20 | 22 | 17 | 18 | **76** |
| mg_planning | standup | 34 | 24 | 30 | 4 | 13 | **88** |
| mg_klantfeedback | choicescene (wh) | 33 | 29 | 14 | 23 | 29 | **76** |
| mg_frontend_fix | uitlijnen | 10 | 13 | 14 | 19 | 14 | **37** |
| mg_backend_fix | cableboard (wh) | 27 | 23 | 16 | 26 | 27 | **66** |
| mg_cro | heatmap | 18 | 23 | 15 | 14 | 16 | **56** |
| mg_abgevecht | abgevecht | 16 | 14 | 13 | 9 | 12 | **43** |
| mg_video | pijplijn | 33 | 18 | 19 | 16 | 16 | **70** |
| mg_paarden | whack (wh) | 19 | 29 | 10 | 28 | 21 | **58** |
| **totaal (9)** | | 224 | 193 | 153 | 156 | 166 | gem. **63,3** |

(wh = wereldhandeling, onderdeel 3). `mg_deploy`: geen briefing, 19+14=33
kaartwoorden. `mg_urenstaat`: geen briefing, 19+15=34 kaartwoorden (§2).

Tikken tussen "ja, ik pak dit op" en de eerste speelhandeling, generiek:
1. Accept-dialoog (`offer`) — 1 tot enkele tikken, per ticket ongeteld.
2. Eigenaarsbriefing — 1 tik, **0 als het je eigen vakgebied is**
   (`Briefing.regel()` geeft dan `""`, `_briefing()` slaat de stap over).
3. `MinigameIntro`-kaartje — 1 tik, **alleen de eerste keer per minigame-id
   per speelbeurt** (`MinigameIntro.moet_getoond()`, `shell.gd:322`). Bij 9
   unieke ids op 10 tickets komt elk kaartje normaal precies één keer voor,
   behalve `mg_urenstaat` (herhaalbaar via Dirk, kaartje slaat de 2e keer over).

Minimaal dus 2-4 ceremoniële tikken vóór de eerste echte invoer, boven op de
37-88 woorden hierboven.

### Drie conclusies

1. **Tekstvolume correleert niet met mechaniek.** `mg_planning` (simpele
   afkap-timing) vraagt 88 woorden vooraf; `mg_frontend_fix` (slepen tot op
   het raster) maar 37. De twee wereldhandelingen `mg_klantfeedback` (76) en
   `mg_backend_fix` (66) vragen evenveel of meer vooraf-tekst dan volwaardige
   minigames als `mg_user_story` (76) — terwijl ze zelf niets zijn dan een
   paar dialoogkeuzes (§3). Tekst ligt overal even dik, ongeacht speeldiepte.
2. **Briefing en WAT/WAAROM-kaartje herhalen dezelfde informatie in twee
   conventies na elkaar.** `mg_user_story`: briefing "13 punten passen erin...
   3 geen wens maar een project" → kaartje WAT "De klant noemt 9 dingen. Er
   passen 13 punten in de sprint...". Twee schermen, twee stijlen (dialoogbox
   met portret, dan kaartje zonder), dezelfde drie getallen — de "lange
   tutorial" die `genre-party.md` verbiedt, alleen in twee happen geknipt.
3. **"Eigen vakgebied = 0 woorden briefing" scheelt 30-40% tekst, onzichtbaar
   voor de speler.** Voor je eigen ticket valt de briefing-laag helemaal weg
   (TraitModifier-voordeel i.p.v. briefing — een goede keuze), dus de tabel
   toont het worst-case-aantal woorden: van toepassing op zes van de zeven
   personages, een derde korter voor de eigenaar zelf.

---

## 2. Per onderdeel

### mg_deploy — BBD-210, "De oplevering" (`scripts/minigames/mg_oplevering.gd`)

**Verdict:** een goed doorgerekend resource-spel met een echte faalstaat zit
achter een rustig cijfer-dashboard i.p.v. "alles schreeuwt tegelijk", en de
climax zelf is stuk — het succesbanner overlapt de eigen consoletekst.

| uitleg-last | affordance | druk | faalspanning | climax | dubbel publiek | touch |
|---|---|---|---|---|---|---|
| 4/5 | 2/5 | 3/5 | 4/5 | **2/5** | 4/5 | 5/5 |

**Getallen:** 0 woorden briefing + 33 woorden kaartje. 8 handelingen, 4
meters (BUGS/VERTROUWEN/GETEST/SCOPE, twee tonen "?" tot getest), klok 75s
(rood <15s), 3 gebeurtenissen op cumulatief verbruik (1× schermvullende
"OPGELET"-storing), 3 consoleregels heen, bij falen 3-regelige rollback
(code→foutcode→foutregel), 2 hersteltacties, 3 consoleregels terug.
Autopilot-doorloop: **35 gesimuleerde seconden**, passend voor een finale.
Knoppen: `UiKit.KNOP_MIN_H = 30px` (`ui_kit.gd:100`), ruim boven de 22px-norm.

**Wat de speler ervaart** (accountmanager-blik): kort kaartje ("acht
handelingen voordat je op deployen drukt"), dan een wit paneeltje met vier
onbekende afkortingen en zes genummerde knoppen met prijskaartje — leest als
een spreadsheet, geen chaos. Het klokje en de schermvullende "OPGELET"-
onderbreking werken wél. De console-fase is het beste stuk: drie regels op
groen, dan leeg scherm, dan koud rood "DEPLOYMENT FAILED" — een echt "oh
nee"-moment. Maar bij een geslaagde deploy verschijnt onderin de console al
een groene "OPGELEVERD: VLEKKELOOS"-regel met tekst eronder, en er half
overheen legt zich een tweede, identieke groene banner — twee stukken
onleesbare, overlappende groene tekst precies op het "yes!"-moment.

**Halve bak, concreet:**
- `mg_oplevering.gd:595-613` — na de succesregel in de console
  (`_console_regel(titel, GROEN, FS_HEAD)`, regel 598, met
  `_console.alignment = ALIGNMENT_CENTER`, dus verticaal gecentreerd) komt
  `_banner` (ook verticaal gecentreerd, `PRESET_CENTER` in
  `minigame_base.gd:157-161`) er bovenop met dezelfde tekst. Bewijs:
  `mgC_deploy_f400.png`/`f420.png` tonen "OPGELEVERD:" half achter de banner
  "OPGELEVERD: VLEKKELOOS", met de succesregel er dwars doorheen.
- Dashboard (`mgC_deploy_f150.png`) is een rustige lijst, geen chaos — precies
  wat `docs/PLAN.md` zelf als probleem benoemt.
- Vier metercijfers vragen elke keer een vertaalslag ("is 4 vertrouwen goed?")
  zonder legenda op het scherm zelf.

**Wat goed is:** de faalstaat kost tijd/gezicht, nooit voortgang
(`faalt_deploy()`), tweede poging slaagt gegarandeerd. De storing-overname
(`_toon_storing()`) is goede juice (fade in/uit, geluid). De klok voelt echt.

**Ontwerpvoorstel — toetsing PLAN-brandjes (max 6 regels):** het brandjes-
idee (2-3 tegelijk aflopende kaartjes, één juiste handeling elk) is de juiste
ingreep: verandert de rustige lijst in "alles tegelijk" zonder de werkende
console/faalstaat te breken. Wat ontbreekt: (1) de banner/console-overlap
hierboven blijft bestaan tenzij `finish_with_banner()` en de consoletekst
ontkoppeld worden — fix dat sowieso; (2) met 2-3 timed kaartjes + het
bestaande "?"-verborgen-metermechaniek stapelt leestijd zich juist op als de
klok het minst vergeeft — een korte legenda verdient een zin in het ontwerp;
(3) op 192px-canvas is verticale ruimte krap met kaartjes + dashboard samen —
het ontwerp zegt niets over hoeveel er zonder scrollen past, en scrollen onder
tijdsdruk is een anti-affordance.

---

### mg_urenstaat — Dirks urenstaat (`scripts/minigames/mg_slotboard.gd`)

**Verdict:** bewust geen minigame maar een formulier met een grap, en dat
werkt — maar het loopt door dezelfde chrome/kaartje-pijplijn als een echte
minigame en belooft daarmee iets wat het niet levert.

| uitleg-last | affordance | druk | faalspanning | climax | dubbel publiek | touch |
|---|---|---|---|---|---|---|
| 4/5 | 4/5 | 1/5 | 1/5 | 2/5 | 5/5 | 5/5 |

**Wanneer/hoe vaak:** Dirk is een los rondlopende NPC, geen ticket — op elk
moment aan te spreken. Zijn gesprek eindigt in 3 keuzes ("boek ze nu" / "ik
loop ergens tegenaan" (Dennis-grap) / "geen tijd"); alleen de eerste start
`mg_urenstaat` (`ticket_controller.gd:565-566`). Geen vlag blokkeert een
herhaling — `Session.book_hours()` telt gewoon op. Optioneel en herhaalbaar,
geen verplicht ticket.

**Formulier of grap:** mechanisch een formulier — drie kant-en-klare
verdelingen, geen falen (`qa_solve()`: "Dirk accepteert toch alles"), geen
klok. Bevestigd op scherm (`mgC_uren_a.png`, `mgC_uren_b.png`): drie
tekstknoppen, klik, reactieregel, platte groene banner "Ingediend. Dirk heeft
het gezien." — geen tween, geen geluidsvariatie. De grap zit in de
schrijfstijl, niet in een mechaniek.

**Halve bak:** `MinigameIntro` en `build_chrome()` maken geen onderscheid
tussen "hier komt een minigame" en "hier komt een formulier" — beide krijgen
hetzelfde donkere WAT/WAAROM-kaartje en "Starten"-knop. Voor de enige echte
niet-minigame is dat een overpromise van precies de chrome die `PLAN.md` zelf
bekritiseert als identiek voor alles.

**Wat goed is:** kort (34 woorden, geen briefing-laag nodig), de opties
rekenen eerlijk tegen `Session.completed_tickets_in_order()`.

**Ontwerpvoorstel (max 6 regels):** (1) laat het formulier blijven — dat is
precies goed; (2) sla het WAT/WAAROM-kaartje over voor `mg_urenstaat`, of
vervang het door één regel in Dirks eigen stem; (3) voeg één keer een knipoog
toe dat "elke keuze wordt geaccepteerd" de clou is (nu alleen codecommentaar);
(4) geen mechanische verandering nodig.

---

### De drie wereldhandelingen (`scripts/world/ticket_controller.gd`)

**Verdict:** alle drie zijn onderbroken dialogen met af en toe een
meerkeuzevraag, ononderscheidbaar van een gewoon NPC-gesprek — ondanks een
volledig contentschema en, bij BBD-203/205, evenveel of meer voorafgaande
tekst dan een echte minigame.

| | uitleg-last | affordance | druk | faalspanning | climax | dubbel publiek | touch |
|---|---|---|---|---|---|---|---|
| gezamenlijk | 2/5 | 4/5 | 1/5 | 1/5 | 2/5 | 4/5 | 4/5 |

**BBD-203, `_wh_klantfeedback()` (`:378-412`).** Drie rondes `ask_choice()`
met 2-4 gefilterde opties, score opgeteld, één eindregel bij de drempel.
Bevestigd op scherm (`mgC_wh_klant_f40..180.png`, `--speler=willem
--auto=wachtbank --autoplay`): speelt in de gewone wereld, normale
dialoogbox, geen chrome/klok/dashboard. 76 woorden vooraf — evenveel als
`mg_user_story`. Geen keuzecombinatie heeft een zichtbaar mechanisch gevolg
buiten de eindtekst; falen kost niets.

**BBD-205, `_wh_backend()` (`:419-468`).** Eén `ask_choice()` ("Welke kabel
leg je?") tussen de juiste verbinding en 1-2 afleiders. Bevestigd op scherm
(`mgC_wh_backend_f55/f80/f110.png`): dialoogregel beschrijft het symptoom
("Product: undefined. Prijs: NaN..."), dan één keuze — de hele "minigame" is
één klik, met 66 woorden eromheen.

**BBD-209, `_wh_paarden()` (`:492-499`).** Via het scrumbord: alleen hint +
toast, ticket blijft open (`Session.pin`); je moet zelf een rondlopend
bugpaard opzoeken en aanspreken — dat gesprek lost automatisch op. Enige met
een ruimtelijk element, al is elk paard goed en schakelt Bastiaans
vakgebiedvoordeel (`geen_zoektocht`) het zoeken zelfs uit. Niet los
ge-screenshot (zie §3), wel met hoge zekerheid uit de code.

**Halve bak + extra bevinding:**
- De gesproken briefing voor BBD-209 (type `whack`) zegt nog steeds **"10
  bugs binnen 60 seconden"** — cijfers uit `mg_whack.gd`'s dode
  contentschema. De wereldhandeling kent geen 10 bugs en geen 60s-klok: je
  spreekt één paard aan en het ticket is klaar. De briefing belooft een
  andere, spannendere minigame dan wat er gebeurt (`ticket_controller.gd:
  471-499`; content in `data/minigame_content.json` → `mg_paarden`).
- Geen van de drie heeft klok, echte faalinzet, of aanraak-/sleepmechaniek —
  precies het vermoeden van de opdracht: "tekst met een knop".

**Wat goed is:** schrijfkwaliteit houdt de grappen overeind (de
zichzelf-tegensprekende klant, "Product: undefined. Prijs: NaN",
paardenkostuum-absurdisme); camera-schok + confetti bij afronden
(`TicketController._vier()`) geeft alsnog het generieke "ticket klaar"-gevoel.

**Verhouding tot echte minigames:** korter in speeltijd (~10-20s) maar niet
korter in vooraf-tekst, en missend: dashboard, klok, faalconsequentie,
tween-feedback — wél opgetuigd met dezelfde contentschema's als een echte
minigame.

**Ontwerpvoorstel (max 6 regels):** (1) maak de `mg_paarden`-briefing waar
(schrap "10 bugs binnen 60 seconden", schrijf wat het is) — pure tekstfix;
(2) geef `_wh_backend()` een zichtbaar gevolg per foute keuze i.p.v. alleen
eindtekst — leen `_flits()`; (3) overweeg zachte tijdsdruk op de drie rondes
van `_wh_klantfeedback()` (de klant is ongeduldig) voor een druklaag; (4)
laat BBD-209 een zoek-en-praat-moment blijven, maar overweeg
`geen_zoektocht` niet de hele mechaniek te laten wegnemen.

---

## 3. Wat niet geverifieerd kon worden

- Exacte tikken per `offer`-gesprek per ticket (niet los uitgeteld).
- Exacte pixelmaten van knoppen op het echte canvas (alleen `KNOP_MIN_H=30`
  als bron, niet per minigame met DPI-metingen op screenshots nagemeten).
- BBD-209 niet los ge-screenshot — beoordeeld uit de code, na hetzelfde
  patroon bevestigd te hebben op scherm bij BBD-203/205.
- `mg_whack.tscn` zelf niet ge-screenshot — draait in een echte speelbeurt
  nooit (bevestigd door `PLAN.md` en `t09.wereldhandeling == true`).
- Framevangst via `tools/qa_shot.py` was onbetrouwbaar door gelijktijdige
  peersessies in dezelfde checkout: een eerste poging leverde een frame van
  een andere, gelijktijdig lopende sessie op (`docs/audit-shots/los.png` en
  `.godot/qa_shot_tmp/` zijn gedeeld). Opgelost door Godot rechtstreeks met
  `--write-movie` naar een eigen scratchpad-map te sturen; alle `mgC_*.png`-
  frames in dit rapport komen uit die geïsoleerde runs.
- Of de banner/console-overlap in `mg_oplevering` er in de volledige
  wereld-flow (via een echt ticket) identiek uitziet — de aanroep is
  code-identiek aan de losse QA-harnas, dus hoge zekerheid, niet apart
  in-world geverifieerd.
