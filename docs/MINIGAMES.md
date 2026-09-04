# Minigames

Elf minigames, **elf mechanieken**. Elke opgave is een JSON-config in
`data/minigame_content.json` plus één script; er is geen enkele mechaniek die
twee tickets draagt.

Dat is een omslag ten opzichte van de eerdere opzet. Die deelde zes mechanieken
over tien tickets, en `SlotBoard` droeg er vier: BBD-201, 202, 204 en 206
hadden dezelfde kop, dezelfde statusregel `n/m ingevuld · fouten 0/2`, hetzelfde
vakkenraster en dezelfde gele kaarten. Alleen de labels verschilden. De toets
die dat blootlegt:

> Vervang alle graphics door grijze blokken. Voelt deze minigame dan nog anders
> dan de andere tien?

Voor vier van de tien was het antwoord nee. Vandaar dat elk ticket nu zijn eigen
werkwoord heeft, en dat dat werkwoord uit de eigenaar van het ticket komt in
plaats van uit de techniek.

| Ticket | Mechaniek | Script | Werkwoord | Waarom dit personage |
|---|---|---|---|---|
| BBD-201 | Scope-schuif | `mg_scope.gd` | verdelen onder twee botsende grenzen | Daan bewaakt de scope en verliest de scope |
| BBD-202 | Stand-up | `mg_standup.gd` | ingrijpen op het juiste moment | een stand-up waar je in staat en niets aan hebt |
| BBD-203 | ChoiceScene | `mg_choicescene.gd` | onderhandelen | Willem haalt akkoord bij de klant |
| BBD-204 | Uitlijnen | `mg_uitlijnen.gd` | ruimtelijke precisie | Victor *ís* uitlijning |
| BBD-205 | CableBoard | `mg_cableboard.gd` | structuur herstellen | Jonathan vindt de oorzaak, niet het symptoom |
| BBD-206 | A/B-test | `mg_abtest.gd` | meten, lezen, opnieuw | Danny: "aanzetten en kijken" |
| BBD-207 | A tegen B | `mg_abgevecht.gd` | de juiste klap kiezen | Danny: "aanzetten en kijken", met vuisten |
| BBD-208 | Renderpijplijn | `mg_pijplijn.gd` | doorstroom onder druk | Koen giet alles in piepelienies |
| BBD-209 | WhackAHorse | `mg_whack.gd` | arcadereflex | Bastiaan ziet wat er beweegt |
| BBD-210 | Oplevering | `mg_oplevering.gd` | beperkte acties met gevolgen | de finale, per personage anders |
| de urenstaat | SlotBoard | `mg_slotboard.gd` | een formulier invullen | Dirk vraagt om je uren |

`SlotBoard` bestaat nog, en draagt nu precies één taak: de urenstaat van Dirk.
Dat is de winst van de omslag. Een vakkenraster is een formulier, en de enige
plek in het spel waar je écht een formulier invult is de urenstaat — dus landt
de grap harder dan toen dezelfde vorm ook vier echte tickets moest dragen.

## Wat de eigenaar je vertelt

Negen van de tien tickets zijn van iemand anders, en die iemand loopt met je
mee. Tot voor kort veranderde dat vooral *dat* het ticket openging: er kwam een
regel dialoog en daarna een opgave die voor iedereen identiek was. Wie er
meeliep was een sleutel, geen mens.

Nu geeft de eigenaar je vóór de minigame één waar feit over zijn eigen ticket,
in zijn eigen stem. Dat is de tegenhanger van het traitvoordeel hieronder: is
het jouw vakgebied, dan krijg je een voordeel in de mechaniek; is het dat niet,
dan krijg je de kennis van degene van wie het wél is.

| Ticket | Wie | Wat je ervan wijzer wordt |
|---|---|---|
| BBD-201 | Daan | de capaciteit, haar tevredenheidsgrens, en hoeveel van haar wensen eigenlijk projecten zijn |
| BBD-202 | Daan | wie er echt iets te melden heeft — dus wie je niet moet afkappen |
| BBD-203 | Willem | hoeveel rondes, en welke score je moet halen |
| BBD-204 | Victor | raster, speling en hoeveel er scheef staat |
| BBD-205 | Jonathan | hoeveel verbindingen fout zijn en hoeveel draden afleiding zijn |
| BBD-206 | Danny | je basislijn en je doel |
| BBD-207 | Danny | hoeveel HP A en B hebben |
| BBD-208 | Koen | welke stap het knelpunt is |
| BBD-209 | Bastiaan | het doel, de tijd, en dat de klantpaarden op bugs lijken |

**De feiten staan niet in de tekst.** De briefing in `minigame_content.json`
bevat plaatshouders (`{capaciteit}`, `{knelpunt}`, `{belangrijk}`), en `Briefing`
vult die uit dezelfde config die de minigame straks draait. Een briefing kan dus
niet verouderen: stel je de sprintcapaciteit bij, dan verandert wat Daan zegt
mee. `_test_briefings()` eist dat er na het vullen geen accolade overblijft — een
onopgeloste `{knelpunt}` op het scherm is precies het soort fout dat niemand
meldt — en controleert bovendien dat de genoemde spreker echt `belangrijk` is,
dat het genoemde knelpunt echt de kleinste capaciteit heeft, en dat het aantal
zware wensen klopt met `Gevolgen.ZWARE_WENSEN`. Een briefing die je de verkeerde
kant op stuurt is erger dan geen briefing.

Op je scherm bekijken: `-- --speler=<wie> --briefing=<ticket>`. De tekst van alle
negen op stdout: de testsuite met `-- --print-briefings`.

## Wat je eigen vakgebied doet

Eén ticket van de tien is van je personage zelf, en dan is de opgave anders.
Nooit strenger — dat botst met "falen kost nooit voortgang" — en altijd iets wat
je opmerkt, want een voordeel dat je niet ziet bestaat niet.

| Mechaniek | Wat er verandert |
|---|---|
| Scope-schuif | twee punten meer sprintruimte; haar tevredenheidsgrens blijft |
| Stand-up | één keer extra afkappen; het tijdbudget blijft |
| ChoiceScene | de drempel gaat één goede keuze omlaag |
| Uitlijnen | één pixel meer speling |
| CableBoard | twee losse draden minder |
| A/B-test | de effecten staan vooraf op de knoppen |
| TagPicker | een poging extra |
| Renderpijplijn | twintig credits extra |
| WhackAHorse | 25% meer tijd |
| Urenstaat | twee afleiderkaarten weg, één fout meer toegestaan |
| Oplevering | **niets** — met opzet |

De oplevering is de uitzondering: die begint met de dag die je gehad hebt
(`Gevolgen.finale_start()`), en een korting daarbovenop zou het gevolgensysteem
uithollen. Elk personage heeft daar al zijn eigen foutcode. Die reden staat in
`TraitModifier.GEEN_VOORDEEL`, zodat "besloten" te onderscheiden is van
"vergeten".

Het is de moeite waard te weten dat dit **nooit heeft gewerkt** tot deze ronde.
`TraitModifier.pas_toe()` las `t.minigame_config` — leeg in alle tien de
tickets — en schreef zijn resultaat naar `config`, terwijl elke minigame zijn
opgave uit `content()` haalt. Er stond wél een toast op het scherm die je een
voordeel beloofde. De aanpassing gaat nu als `inhoud` mee naar
`content_override`, en `_test_traits()` eist dat de opgave meetbaar verandert.

## Contract

```gdscript
MinigameBase.setup(config: Dictionary)      # na add_child
signal finished(result: MinigameResult)     # SUCCESS / FAIL / ABORT
```

`Shell.run_minigame(id, config)` pauzeert de wereld, hangt de scene op
MinigameLayer (50) en `await`t het resultaat. De minigame mag `Session`
**lezen** maar nooit schrijven: de uitkomst gaat uitsluitend via `finished`
terug naar `TicketController`.

`Shell` zet `process_mode = PROCESS_MODE_ALWAYS` op de minigame. Daardoor loopt
`_process(delta)` gewoon door terwijl de tree gepauzeerd staat, en kan een
minigame real-time zijn zonder iets aan de pauze te veranderen. Drie doen dat:
de stand-up, de renderpijplijn en de paardenbugs. Een timer heeft in die
toestand `process_always` nodig: `get_tree().create_timer(t, true, false, true)`.

`build_chrome(titel, intro)` levert kop, statusregel, intro, een scrollbare
body en op een aanraakscherm een Stoppen-knop. Wat *niet* mag wegscrollen —
een meter, een klok, de enige actieknop — hoort buiten die scroll, via
`chrome_header()` of `chrome_footer()`.

De chrome is een **donker** oppervlak (`UiKit.SCHERM_NACHT`), dezelfde
ondergrond als het titel- en uitlegscherm: kop op `FS_HEAD` in
`BLUEBIRD_BRIGHT`, statusregel en intro in `GRIJS_OP_DONKER`. Wat een minigame
zelf in de body zet staat dus op donker tenzij het in een eigen licht paneel
zit (`PAPIER`, `WIT`, een post-it). Een label rechtstreeks op de chrome hoort
`WIT` of `GRIJS_OP_DONKER` te zijn, en nooit `INK`, `GRIJS_OP_LICHT` of
`BLUEBIRD_INK` — die drie verdwijnen daar in de achtergrond.

Eén blauwe `UiKit.knop_primair()` per scherm, en die hoort in
`chrome_footer()`. Alles wat secundair is — Stoppen, richtingsknoppen,
keuzerijen — houdt de gewone knopstijl. `mg_whack` en `mg_choicescene` hebben
er bewust nul: daar *is* de keuze de handeling.

ESC breekt af. Afbreken laat het ticket op ACTIVE staan; opnieuw praten is
opnieuw proberen. Falen kost nooit voortgang.

## De mechanieken

**Scope-schuif** (BBD-201) — negen wensen van De Klant, twee lijsten, één tik
verplaatst er een. Twee meters die tegen elkaar in werken: `punten` mag niet
boven `capaciteit`, `blij` moet op of boven `tevreden_min`. De goedkoopste wens
is het paard (1 punt) en die maakt haar het blijst (4), dus je kunt slagen door
het paard en Comic Sans op te leveren en de webshop weg te laten. Dat is geen
gat in de balans maar het punt, en `Gevolgen` onthoudt het.

**Stand-up** (BBD-202) — zeven collega's praten na elkaar in real-time, en je
hebt drie ingrepen om iemand af te kappen. Twee sprekers melden iets bruikbaars
(Jonathan een structurele bug, Danny de checkout), en nergens staat wie dat
zijn: dat moet je uit wat ze zeggen halen. Een balk "Nuttige info" vult zodra
zo'n regel valt — dat ís de opgave, letterlijk zichtbaar. Sta hij vol als de
stand-up afloopt (de klok op nul, of alle sprekers gehad), dan slaag je; anders
niet, net als elke andere minigame gewoon een retry. Zonder afkappen halen de
zeven sprekers de klok niet: Danny's regel valt pas als laatste, ruim buiten
het budget. Wie iemand afkapt nádat zijn nuttige regel al gevallen is verliest
niets — dat segment staat al groen.

**ChoiceScene** (BBD-203) — dialoogkeuzes met punten tegen een drempel. Opties
kunnen een `when` dragen, zodat sommige antwoorden alleen voor bepaalde
personages bestaan.

**Uitlijnen** (BBD-204) — een nagebouwde productpagina op zichtbaar ruitpapier,
vijf blokken van hun raster af. Tik een blok, verschuif het met vier
richtingsknoppen (slepen mag ook, maar de knoppen volstaan op zichzelf — met
een duim is een blok van 16 px geen doel). Binnen `tolerantie` klikt een blok
vast. De afwijkingen zijn geen veelvouden van `raster`, dus tolerantie is
noodzakelijk in plaats van vriendelijk en `perfect` is onbereikbaar.

**CableBoard** (BBD-205) — klik twee knooppunten om een kabel te leggen, nog
eens om hem weg te halen. Extra kabels tellen als fout.

**A/B-test** (BBD-206) — drie rondes, elke ronde één variant aanzetten. Het
resultaat loopt daarna **zichtbaar** op of af met een tween: de speler moet de
naald zien bewegen, niet een nieuw getal zien staan. Danny's regel over de
uitslag komt pas ná de meting. Je keuze in ronde twee zou anders zijn als je
ronde één niet had gezien — dat is het verschil met een keuzemenu met verborgen
punten.

**A tegen B** (BBD-207) — drie klappen, elk een keuze uit drie CRO-tweaks. Elke
klap doet schade aan B én slaat terug op A; het net-effect (schade minus
tegenklap) bepaalt of hij de moeite waard was. A moet B knock-outen binnen de
drie klappen, of B wint op punten. Verliezen laat het ticket gewoon openstaan
— geen game over, alleen Danny die met een steeds absurdere reden terugkomt om
het nog een keer te proberen (zie `data/dialogue/tickets.json` → `t07_fail`,
gestuurd door `Session.get_counter(&"ab_pogingen")`).

**Renderpijplijn** (BBD-208) — zes clips door Prompt → Render → Publish. Elke
stage heeft capaciteit, elke clip rijpt, een rijpe clip schuif je door met een
tik. De druk: Render heeft twee plekken, en een clip die daar **rijp staat te
wachten** verbrandt credits. Was vier stages met een kosteloze Review erbij;
die voegde een derde tik per clip toe zonder een nieuwe afweging, dus is hij
geschrapt — Render blijft de enige stap die pijn doet.

> `kost` in de data is credits per seconde voor een clip die **rijp is en niet
> door kan**, niet voor de hele renderduur. De letterlijke lezing maakt de
> config onhaalbaar (5 clips × 5 s × 6 credits = 150 tegen een budget van 100)
> en haalt de druk er juist uit: het punt is dat je Review leegtrekt vóórdat
> Render klaar is, precies wat de intro zegt.

**WhackAHorse** (BBD-209) — de arcadepiek. Bugpaarden raken telt; een
klantpaard raken kost drie seconden en levert "JE HEBT EEN KLANTPAARD
GESLAGEN" op. Nooit meer dan twee paarden tegelijk; de spawninterval loopt op
na elke treffer. Geen game over, alleen tijd.

**Oplevering** (BBD-210) — zie hieronder.

**SlotBoard** (de urenstaat) — sleep kaartjes naar genummerde vakken. Echte
drag & drop; klikken op een geplaatst kaartje haalt het terug.

## De finale: de oplevering

Drie fasen, met een `enum` + `match` in plaats van fasenummers.

1. **Voorbereiden.** Acht handelingen, verdeeld over zeven keuzes met een prijs.
   Vier waarden vormen de toestand: `bugs` (lager is beter), `vertrouwen`,
   `getest`, `scope`. Het aantal bugs is **onbekend** tot je test — testen
   onthult het, en kost handelingen die je dan niet meer kunt fixen. Bug fixen
   kan pas ná testen. Drie gebeurtenissen overkomen je op vaste momenten; de
   laatste zet er een bug bíj, dus wie precies op nul handelingen uitkomt komt
   bedrogen uit.
2. **Deployen.** De checks lopen op groen. Dan faalt hij op precies jouw
   vakgebied: `varianten[<personage>].foutcode` uit de data, groot en in rood.
   SCOPE NOT APPROVED voor Daan, FRONTEND BUILD FAILED voor Victor, en zo
   verder — zie `docs/CHARACTERS.md`.
3. **Herstellen.** Twee extra handelingen om op die foutcode te reageren.
   Daarna gaat het onvermijdelijk live.

**Elke uitkomst heet "OPGELEVERD".** Er is geen game over; de finale eindigt
altijd met `ok = true`. Wat verschilt is de tekst eronder, van "het staat live
en het werkt" tot "dat is het enige wat je er nu over kunt zeggen". Die tekst
komt via `Gevolgen` op het eindscherm terecht, met je jas al aan.

De **begintoestand komt uit je dag**. `Gevolgen.finale_start()` telt de gevolgen
van de negen tickets op en `TicketController` geeft die mee als
`start_override`. Een zorgvuldige dag begint op twee bugs en zeven vertrouwen;
een dag waarop je scope te groot liet worden en de klant ontevreden hield
begint op vier en vier. Geen van beide is onhaalbaar — een slechte dag maakt de
oplevering duurder, niet onmogelijk. `_test_gevolgen` faalt als die twee gelijk
uitkomen, want dan hebben de keuzes geen gevolgen meer.

De minigame weet zelf niets van de wereld: hij leest `cfg("start_override")` en
valt terug op `start` uit de data. Daardoor is de finale los te draaien met
`--minigame=mg_deploy`.

## De urenstaat

`mg_urenstaat` is de enige `SlotBoard` die er nog is, en hij heeft geen goed
antwoord. Dat is geen modus meer maar de hele mechaniek: de gecontroleerde
variant (met `accepts` en `max_fouten`) is verwijderd toen elk ticket zijn eigen
mechaniek kreeg.

- elke regel neemt elk uurblok
- een regel neemt er meer dan één (`capaciteit`)
- je slaagt zodra alles verdeeld is; er zijn geen fouten
- de verdeling gaat mee in `MinigameResult.payload`, en Dirk reageert daarop

De regels van echte tickets komen niet uit de data maar uit
`Session.completed_tickets_in_order()`: het werk dat je vandaag gedaan hebt is
per speelbeurt anders. De data levert alleen de posten waar je uren op kwijt
kunt die niet aan werk hangen — intern overleg, kennisdeling, BBD-000 Overig.

De grap is de kant op die je niet verwacht. Je hebt halverwege je dag zo'n vier
uur gewerkt, en het systeem verwacht er acht. Je hebt dus te véél uren voor te
weinig werk, en die moeten ergens heen. Precies wat de echte Dirk vraagt: "zou
je je uren aanvullen als er nog wat mist?"

Elke verdeling wordt aangenomen. Dirk keurt niets af — hij bedankt je en zet er
een vraagteken bij.

## Balans

Alles is in 60–120 seconden te doen en op de eerste of tweede poging haalbaar.

| Minigame | Drempel |
|---|---|
| scope | ≤ 13 punten én ≥ 10 blij, uit negen wensen |
| stand-up | zeven sprekers binnen 42 s, met drie ingrepen |
| klantfeedback | 6 van maximaal 9 punten |
| uitlijnen | vijf blokken binnen 2 px van hun raster |
| backend | de gevraagde kabels, geen extra |
| A/B-test | 2,7% vanaf een basis van 1,8%; maximaal haalbaar 3,4% |
| tagpickers | 4 pogingen |
| renderpijplijn | 5 van 6 clips in 60 s, binnen 100 credits |
| paardenbugs | 10 bugs in 60 seconden |
| oplevering | geen drempel — vier uitkomsten op score `vertrouwen + getest − 2·bugs + scope` |
| urenstaat | geen goed antwoord; alles verdelen volstaat |

## QA

Elke mechaniek implementeert `qa_solve()`, die de minigame **langs de echte
winroute** oplost — de juiste kaarten leggen, de veilige tags kiezen, de
gevraagde kabels trekken, de blokken op hun raster tikken, de pijplijn
leegtrekken. De autopilot roept dat aan, zodat een geautomatiseerde speelbeurt
de daadwerkelijke wincondities test en niet een omweg.

Voor een real-time minigame is dat geen tik maar een lus: `qa_solve()` zet een
vlag, en `_process` doet daarna per frame wat een speler zou doen. Dat betekent
ook dat een headless run genoeg frames moet krijgen. Richtlijnen, gemeten:

| Minigame | `--quit-after` |
|---|---|
| stand-up | 8000 |
| renderpijplijn | 3600 |
| oplevering | 3000 |
| de rest | 1200 |

Een `--minigame`-run geeft **exitcode 0 ook als de minigame nooit startte**. De
`[QA] minigame <id> -> outcome=…`-regel op stdout is het echte bewijs; controleer
die, niet alleen de exitcode.
