# Dialoog-audit — 10 Tickets naar Vrijheid

## 1. Oordeel

De dialoog is structureel goed gebouwd — zelfspeel-attributie, ketenlogica en
spreker-ids kloppen consequent, en de "echte keuze"-vraag levert geen enkele
puur cosmetische knop op. Waar het wringt is op uitvoeringsniveau: de
fetch/recruit-beat is op zinsniveau een kopieer-sjabloon dat een speler die
alle tien tickets doet er negen keer bijna letterlijk hoort, en twee van de
drie stem-regels (Danny lowercase, Bastiaan `,,`) worden op een handvol
plekken door de data zelf overtreden. Eén stuk data (`unlock_ticket` op
BBD-201 in `klant_berichten.json`) is dode code die de eigen documentatie
tegenspreekt.

## 2. Bevindingen

### Hoog

**H1 — Fetch/recruit-beat is een letterlijk sjabloon, 9x herhaald.**
Waar: `data/dialogue/tickets.json`, alle `tXX_fetch`/`tXX_recruit`-bomen.
Elke recruit-boom heeft exact dezelfde 4 nodes (`vraag→reactie→antwoord→oordeel`)
en exact 7 variants, en de fallback-opening is woordelijk hetzelfde sjabloon:
> t01: "Daan, ik loop vast op BBD-201. Er ligt een user story die geen user
> story is..." / t05: "Jonathan, ik loop vast op BBD-205. Product undefined,
> prijs NaN, voorraad null..."
De voorafgaande fetch-beat volgt hetzelfde sjabloon "[Domein] is van [Naam].
Ik ga hem halen." (`t04_fetch`: "Dit is frontend. Dus dit is Victor.";
`t05_fetch`: "Dit is backend. Dus dit is Jonathan."). Voor een speler die alle
tien tickets doet is dit de meest herhaalde beat in het spel (9 van de 10),
en de herhaling zit in de zinsconstructie zelf, niet alleen de structuur.
Voorstel: varieer de openingszin-vorm per ticket (vraagvorm, uitroep, korte
stelling) in plaats van steeds "[Naam], ik loop vast op BBD-2XX."

**H2 — Danny breekt zijn eigen lowercase-regel op meerdere, deels
ongedocumenteerde plekken.** Waar: `data/dialogue/tickets.json:1432-1433`
(`t06_offer.oordeel`, speaker `danny`, geen `when`): *"Dat is geen conversie.
Dat is een ongeluk."* — hoofdletter, terwijl de bible-regel
(`docs/dialogue-content.md:1254`) expliciet zegt "Danny schrijft en spreekt
altijd zonder hoofdletters." Zelfde patroon in `t06_offer.cijfer` (regel
1450), `t06_recruit.reactie` ("Welk getal?", regel 1570), `t07_complete.start`
(regel 1855, "A wint. Drie klappen..."). `docs/dialogue-content.md:1265`
erkent dit al voor `t06_fail`, maar niet voor deze vier andere plekken — de
overtreding is dus breder dan wat de eigen documentatie als bekend meldt.
Voorstel: lowercase toepassen op alle Danny-gesproken regels, ook de
default/non-self-play-variant van `t06_offer`/`t06_recruit`/`t07_complete`.

**H3 — Bastiaan breekt zijn `,,`-stijl op 4 plekken binnen dezelfde nodelijst.**
Waar: `data/dialogue/npcs.json` (`collega_bastiaan.nodes.start`/`tweede`),
speaker "bastiaan" overal. Regels 1484, 1490, 1519 eindigen op een punt met
hoofdletter-opener, terwijl 7 andere variants in dezelfde lijst wél lowercase
+ `,,` gebruiken:
> correct (variant 0): "hiya,, de accordion is klaar,, hij klapt perfect,,
> ik maak er nog een,,"
> afwijkend (variant 7): "Ik heb de hele build nagelopen,, er zit niets fout
> in,, dat vertrouw ik niet."
Bastiaan is volgens `docs/AUDIT.md` de herkenbaarste stem in het spel; deze
4 regels breken die herkenbaarheid binnen hetzelfde gesprek. Voorstel:
herschrijf de 4 regels naar lowercase-opening en `,,`-einde.

### Midden

**M1 — `unlock_ticket` op BBD-201 in `klant_berichten.json` is dode code die
de eigen docs tegenspreekt.** Waar: `data/klant_berichten.json` bericht `k4`
(effect `{"op":"unlock_ticket","ticket":"t01"}`), tekst: *"Trouwens, ik heb
nog een wens opgeschreven... misschien handig voor jullie planning."*
`data/tickets/t01.json` heeft `"available_when": {}` (al open vanaf minuut
1), en `QuestEngine.unlock()` (scripts/core/quest_engine.gd:91-93) doet
alleen iets als de staat nog `LOCKED` is — dat kan BBD-201 hier nooit zijn.
`docs/QUESTS.md:40-42` claimt expliciet dat dit effect "voor BBD-207 en
BBD-201" gebruikt wordt om werk naar voren te trekken; voor BBD-201 werkt dat
dus feitelijk niet, en de flavor-tekst doet bovendien alsof de klant een
nieuwe wens instuurt terwijl het de user story is die al vanaf de start op
tafel ligt. Voorstel: verwijder het dode effect of vervang het ticket-doel
door iets dat wél nog `LOCKED` kan zijn op dat moment in de dag.

**M2 — 3 nieuwe em-dash-treffers in speler-zichtbare minigame-briefteksten,
niet gedekt door de bekende-afwijkingen-lijst.** Waar: `data/minigame_content.json:73,75,390`:
> "Twee van hen melden iets bruikbaars — waaronder {belangrijk}."
> "Kap je ze af vóór ze het zeggen, dan hoor je het niet — en dat hoor je
> juist wel te horen."
> "Kijk waar ze wél klikken en sleep de knop daarheen — voordat de ronde om
> is."
`docs/SCHRIJFSTIJL.md:27-37` noemt al bekende em-dash-afwijkingen in dit
bestand, maar specifiek in de personagebeschrijvingen — deze 3 briefing/
waarom/intro-velden staan er niet bij en worden bij elke ronde van 3
minigames getoond. Voorstel: vervang door punt of komma, conform de eigen
regel.

**M3 — Storingen missen de dialoog-gate die idle-barks wél hebben.** Waar:
`scripts/entities/npc_layer.gd:53` checkt `Session.input_locked or
Shell.minigame_active()` voordat een idle-bark mag vuren; `scripts/world/
storingen.gd` heeft nergens zo'n check in `_evalueer()`/`_vuur_eenmalig()`/
`_volg()` — alleen een aparte, bewuste minigame-route (`mag_onderbreken_
minigame()`). Een `flag_changed`/`zone_entered`/`ticket_completed`-signaal
tijdens een open dialoogvenster kan dus een toast tonen of een collega laten
starten met meelopen (`npc_komt_langs`) terwijl de speler middenin een ander
gesprek zit — een asymmetrie met de wél verzorgde minigame- en idle-bark-
route. Voorstel: dezelfde `Session.input_locked`-check toevoegen aan
`Storingen._evalueer()`, of expliciet documenteren waarom dat bewust anders
is dan bij idle-barks.

**M4 — Keuzes zijn technisch nooit cosmetisch, maar de meeste hebben geen
gevolg buiten het eigen gesprek.** Van 319 dialoognodes hebben er 16 een
`choices`-array; alle 16 zetten verschillende flags/vervolgnodes (geen
dubbele knoppen naar hetzelfde resultaat). Maar flags als
`victor_entree_gemeld`, `padel_ingeschreven`, `bastiaan_component_gevraagd`
worden nergens anders gelezen dan door de eigen node (ze gijzelen alleen of
de keuze een 2e keer verschijnt) — grep bevestigt 2-3 treffers per flag,
altijd binnen dezelfde boom. Uitzondering: `klant_prioriteit_gevraagd`
(`t03_offer`) wordt herbruikt in Willems latere regel
(`data/dialogue/npcs.json:1205`), en `alarm_af` in een andere dialoogboom —
dat zijn de enige twee met een echo buiten het eigen gesprek. Voorstel: geen
harde fix nodig, maar als "keuze met gevolg" een doel is, is dit het patroon
om te herhalen.

**M5 — Langste dialoogregels benaderen/overschrijden mogelijk de
box-kalibratie.** Waar: `scripts/ui/dialogue_box.gd:16-23` (HOOGTE_MAX=210,
commentaar: gekalibreerd op BBD-208's briefing als "langste tekst die het
spel kent", 141 tekens). De data bevat langere regels: `data/dialogue/
npcs.json` (Dirk, `dirk_urenstaat.nodes.veel_rest`, 200 tekens vóór
`{naam}`/`{rest}`-substitutie): *"Dank je {naam}! Ik zie {rest} op overige
posten staan... Ik zet er een vraagteken bij, dan kijkt mijn collega Dennis
er nog even naar. Alvast bedankt!"* Met een echte naam en duur ingevuld kan
dit ruim boven de 141-teken-ijkwaarde komen. Boven HOOGTE_MAX schakelt de box
zelf om naar `scroll_active=true` (regel 188-190), maar er is nergens
scroll-input voor de speler gebonden (geen sleep/muiswiel-handler in
`dialogue_box.gd` of `dialogue_controller.gd`) — op het primaire
touch-doelplatform zou de onderkant van zo'n regel dan onbereikbaar zijn.
Kon niet volledig experimenteel bevestigd worden (zie §4). Voorstel: render
`dirk_urenstaat.veel_rest`/`lege_tickets` met een realistische naam+duur en
meet de werkelijke hoogte; voeg zo nodig scroll-input toe of kort de regel in.

### Laag

**L1 — Willem en Victor: 100% stemconsistentie, weinig variatie op de
kernjoke.** "Absoluta... ehh, Looff" komt 4x voor, steeds letterlijk
(`data/dialogue/npcs.json:1150,1236,1408`, `data/dialogue/tickets.json:753`),
nooit fout zonder correctie. Geen bevinding, wel vermeldenswaardig dat de
grap weinig variatie kent.

## 3. Wat goed is

- **Zelfspeel-attributie is zorgvuldig opgelost.** Elke ticket-dialoog met een
  speelbare eigenaar heeft een `"when":{"character":["<eigenaar>"]}`-variant
  die de spreker naar `"speler"` (of narrator `""`) omzet, met vaak een
  herschreven tekst i.p.v. dezelfde zin met andere `speaker` — bv.
  `data/dialogue/tickets.json` `t01_offer.duiding`: bij Daan zelf "Niemand
  spreekt je tegen. Dat is het vervelende aan Product Owner zijn.", anders
  "Het is een wens. Van de klant. Dus het is een risico." De eigen-NPC wordt
  bovendien nooit gespawned (`scripts/entities/npc_layer.gd`), dus de speler
  ontmoet zichzelf letterlijk nooit als collega.
- **Geen foute spreker-ids.** Volledige scan van alle `speaker`-velden in
  `tickets.json`/`npcs.json`/`wereld.json` levert geen typo's of onbekende
  ids op, en geen enkele NPC praat over zichzelf in de derde persoon (los van
  de bewuste Absoluta/Janny/Dirk-Dennis-grappen).
- **Ketens kloppen inhoudelijk.** BBD-201→203/208, 202→209, 204→207, 205→206
  refereren geen personages/feiten die de speler op dat moment nog niet kan
  kennen; `available_when` in de losse ticketbestanden komt exact overeen met
  `docs/QUESTS.md`.
- **Geen emoji, geen AI-cliché-taal, geen slogan-drieslag** aangetroffen in
  dialoogdata (volledige scan).
- **Sommige keuzes hebben wél een echt, later gebruikt gevolg** (`alarm_af`,
  `klant_prioriteit_gevraagd`) — het patroon bestaat, het wordt alleen niet
  overal toegepast.

## 4. Niet geverifieerd

- **Werkelijke box-hoogte van Dirks langste regel na tokensubstitutie**: kon
  niet in-game gerenderd worden binnen dit budget (vereist een specifieke
  urenboekingsstand om `veel_rest`/`lege_tickets` te triggeren). Eén frame
  van Dirks openingsregel (`docs/audit-shots/praat_dirk.png`) bevestigt dat
  de box met portret en een gemiddelde regel prima past; de 200+ tekens
  lange varianten zijn alleen code-analytisch beoordeeld.
- **Storingen-tijdens-dialoog** is afgeleid uit het ontbreken van een gate in
  `storingen.gd`, niet visueel gereproduceerd — dat vereist een exacte
  signal-timing (een `flag_changed`/`ticket_completed` terwijl de dialoogbox
  al open staat) die niet betrouwbaar op te zetten was binnen dit budget.
- **Volledige combinatoriek van 7 personages × 10 tickets** (self-play +
  fetch/recruit) is niet uitgeput getest; de audit heeft daan/danny als
  voorgeschreven steekproef gedaan plus representatieve NPC-varianten, niet
  alle 630 combinaties.
