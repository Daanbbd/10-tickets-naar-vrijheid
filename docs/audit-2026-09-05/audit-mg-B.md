# Minigame-audit groep B — mg_cro (BBD-206), mg_abgevecht (BBD-207), mg_video (BBD-208)

Getoetst tegen `genre-party.md` (geen lange tutorials, één zin instructie, gestandaardiseerde controls),
`game-loop-time-trial.md` (druk/klok), `tweening.md` (climax-moment) en de vision-rubric (frames bekeken met Read).
Alle frames in `docs/audit-shots/mgB_*.png`, gemaakt met `tools/qa_shot.py los <sec> --minigame=<id> --speler=<id> [--autoplay]`.

---

## 1. mg_cro — "Waar klikken ze?" (BBD-206, danny)

**Verdict:** een origineel en grappig idee (drag-de-knop-naar-de-hitte) dat door een tekstpijplijn van bijna 100 woorden vóór de eerste tik en door een kapotte QA-autopilot wordt begraven.

| | uitleg-last | affordance | druk | faalspanning | climax | dubbel publiek | touch |
|---|---|---|---|---|---|---|---|
| score 1-5 | 2 | 3 | 4 | 3 | 3 | 4 | 2 |

**a. Tekst vóór eerste handeling.** Niet-eigenaar-pad (bv. willem): offer-dialoog `t06_offer` 4 regels (~39 woorden) → briefing van Danny 1 regel (18 woorden, gevuld) → WAT/WAAROM-kaartje (23+15=38 woorden) = **~95 woorden over 3 schermen, 6 tikken** vóór "Starten". Eigenaar-pad (danny): offer (4 tikken) + traittoast (auto) + kaartje (1 tik) = **5 tikken**, geen briefing.

**b. Tijd tot eerste input.** Zonder `--autoplay` blijft het scherm na 1,1 s én na 2,0 s exact het WAT/WAAROM-kaartje (`docs/audit-shots/mgB_mg_cro_first_danny.png`, `..._first_willem.png` — pixel-voor-pixel gelijk aan `..._intro.png`): niets in het spel zelf beweegt, knippert of wijst tot je "Starten" hebt getikt. Affordance ís aanwezig zodra je in het spel bent: hittepunten landen zichtbaar en een groene/oranje/rode balk loopt leeg.

**c. Kernhandeling.** Eén werkwoord: slepen (`_op_aanraking`/`_op_sleep`/`_op_los`, `scripts/minigames/mg_heatmap.gd:425-446`).

**d. Druk.** Zichtbare rondeklok (balk, groen→oranje→rood, 9 s/ronde, `_teken_klok()` regel 314-320). Doe je niets: de knop blijft staan, de ronde loopt af en telt als "mis" als de knop toevallig niet op het hete element staat.

**e. Faalkans — hard bewijs van een QA-gat.** `qa_solve()` (`scripts/minigames/mg_heatmap.gd:453-467`) wacht bewust 1 s ("eerst kijken, dan slepen") en moet daarna **herhaald** aangeroepen worden, ééns per ronde. De losse `--minigame=`-testroute (`scripts/ui/boot.gd:88-93`) roept `qa_solve()` echter maar **één keer** aan, 0,6 s na start — te vroeg voor de 1-s-gate, en daarna nooit meer (de echte, doorlopende `Autopilot`-node (`scripts/tests/autopilot.gd`) wordt pas toegevoegd in `scripts/world/main.gd:197-198`, dat dit korte testpad nooit laadt). Resultaat, twee keer onafhankelijk gereproduceerd (danny én willem, `--minigame=mg_cro --autoplay`):
```
[QA] minigame mg_cro -> outcome=1 score=18 payload={ conversie: 1.8, boven_doel: false, keuzes: ["mis","mis","mis"] }
```
De knop staat op alle gecontroleerde tijdstippen (1,0 / 1,5 / 2,0 / 4,0 s) nog op zijn startpositie — `docs/audit-shots/mgB_mg_cro_qabug_t2.png` en `..._t4.png` bewijzen dit met stapelende hitte-tellers (11→27 klikken) rond een stilstaande "Bestellen"-knop. **Dit is geen bug in de minigame zelf**: een volledige `--playthrough --autoplay` (die wél door `main.gd` loopt) meldt `[SPEELBEURT] BBD-206 opgelost (6/10)` — de echte winroute werkt. Het is een gat in `tools/qa_shot.py`/`--minigame=`, en dus in elke screenshot die daarmee van mg_cro gemaakt wordt (inclusief de bestaande `qa_shot.py minigames`-batch): die toont altijd de faalbanner, nooit een succesvolle ronde. Vermeld dit met klem aan andere sessies die met dit screenshot conclusies trekken.

**f. Climax.** Faalbanner (rood, `finish_with_banner`) — `docs/audit-shots/mgB_mg_cro_climax2.png`: "Je zit onder de doelstelling. Ze klikten wel, maar niet daar. Nog een keer, zegt Danny." Geen geluid-eigen climax-juice (geen schok/confetti bij succes te controleren door bovenstaand gat); bij een treffer wel `Juice.schok(1.0,0.15)` + groene knop-flits (`mg_heatmap.gd:359-361`) — puur tekstueel/kleur, geen deeltjes.

**g. Dubbel publiek.** Een leek snapt "sleep de knop naar de stip" uit het scherm zelf (blauwe knop, duidelijk hete gebied) — geen scrum-kennis nodig. Grap voor insiders: Danny's droge regels ("psies", "biem") en dat het "antwoord" letterlijk een grafiek-inzicht is dat CRO'ers ook echt gebruiken (klikheatmaps).

**h. Touch.** Veld is 164×190 px op een canvas van 192 px breed — erg krap. De knop zelf is 64×20 px: **20 px is lager dan de eigen UI-kit-norm** (`KNOP_MIN_H=30`, `keuzeknop` 26 px; zie `scripts/ui/ui_kit.gd:100`), al vangt `grow(8.0)` in `_op_aanraking` (regel 430) dat deels op als grijp-zone (~36 px). Groter probleem, expliciet gevraagd: een echte duim (~40-48 px contactvlak) die de knop sleept **bedekt op dit formaat bijna het hele element waar je 'm naartoe stuurt** — precies het gebied waar de hittestippen landen en waar je moet kijken om te zien of je goed zit. Met een muis (dunne cursor) is dat geen probleem; met een vinger is het slepen-en-tegelijk-zien-waar-je-heen-moet een reëel conflict dat nooit met een muis getest is.

**i. Lengte.** 3 rondes × 9 s + 2 × 1,4 s pauze ≈ **30 s** natuurlijk verloop — past ruim binnen 30-90 s.

**j. Grijze-blokken-test.** Slaagt: slepen-onder-tijd op een wireframe voelt anders dan de knop-kies-mechaniek van BBD-207, ook al delen ze zeven van de negen CRO-teksten (`docs/MINIGAMES.md`). Wel een herhaling in *thema* (twee "Danny doet CRO"-tickets na elkaar in de mechanieklijst) — geen mechanische overlap, wel een narratieve.

**Wat de speler nu ervaart.** Je krijgt een ticket, luistert Danny 4 zinnen lang aan, hoort dan zijn briefing, leest een kaartje met WAT en WAAROM, en tikt pas daarna voor het eerst zelf iets aan. Eenmaal binnen is het meteen duidelijk en leuk: stippen landen, je sleept de knop erheen, de balk loopt rood. Maar je duim zit precies op de plek die je probeert te raken, en je hebt geen idee of dat een probleem is tot je 'm optilt.

**Wat "halve bak" voelt.** Zes tikken tekst vóór je iets doet (a); een QA-tool die dit spel al maanden alleen op "mis" laat eindigen zonder dat iemand het merkte (e, `mgB_mg_cro_qabug_t2/t4.png`); een knop die kleiner is dan elke andere knop in het spel (h).

**Wat al goed is.** Eén glasheldere handeling zonder uitleg nodig zodra je in het spel bent; een levende, kloppende drukklok; een traitbonus die je *ziet* (tellers, `mgB_mg_cro_mid_danny.png` vs `..._mid_willem.png` — 62 vs geen cijfers).

**Ontwerpvoorstel.** Verwijder de briefing-tekst uit dit pad (danny's regel *is* het spel al: laat "basis/doel" alleen op het meterpaneel staan, niet ook nog uitgesproken) en laat het WAT/WAAROM-kaartje het enige tekstmoment zijn. Voeg een korte "kijk!"-pols (knipperende rand) op het startelement toe in de eerste 0,5 s zodat de affordance ook zonder lezen duidelijk is. Vergroot de knop naar minstens 26 px hoog en laat 'm bij het slepen 20-24 px boven de vingerpositie zweven (offset-drag) zodat je ziet wat je raakt. Fix eerst het QA-gat (`boot.gd`) zodat iedereen die screenshot dit spel eerlijk beoordeelt.

---

## 2. mg_abgevecht — "A tegen B" (BBD-207, formeel niemands vakgebied)

**Verdict:** de simpelste en snelste van de drie — drie keuzes, twee balken, klaar in seconden — maar zonder klok of tegendruk voelt het meer als een quiz dan als een gevecht.

| | uitleg-last | affordance | druk | faalspanning | climax | dubbel publiek | touch |
|---|---|---|---|---|---|---|---|
| score 1-5 | 3 | 4 | 1 | 2 | 3 | 5 | 4 |

**a. Tekst vóór eerste handeling.** `data/tickets/t07.json` heeft `owner_character: ""` → `QuestEngine.is_own_expertise()` geeft voor **elke** speler `true` terug (`scripts/core/quest_engine.gd:130-136`). Gevolg: geen ophaal-stap, en `TicketController._briefing()` (`scripts/world/ticket_controller.gd:326-332`) slaat de briefing altijd over — dit ticket krijgt dus **nooit** het "eigenaar vertelt je een feit"-moment, voor niemand. `docs/MINIGAMES.md` is hier net bijgewerkt naar "Danny (briefer, niet op te halen)", en `TraitModifier.GEEN_VOORDEEL["abgevecht"]` bevestigt: "ticket van iedereen ... geen vakgebied om voordeel aan te hangen". Tekst: offer-dialoog `t07_offer` 3 regels (~39 woorden, 3 tikken) → WAT/WAAROM-kaartje (14+13=27 woorden, 1 tik). **Totaal ~66 woorden, 4 tikken** — de lichtste van de drie.

**b. Tijd tot eerste input.** Zelfde patroon als mg_cro: zonder `--autoplay` blijft het scherm op het WAT/WAAROM-kaartje staan (`mgB_mg_abgevecht_first_danny.png` = `..._first_willem.png` = `..._intro.png`). Affordance in het spel zelf is uitstekend: drie knoppen met tekst, één ervan met focus-highlight — geen twijfel wat je moet doen.

**c. Kernhandeling.** Eén werkwoord: kiezen (`_kies()`, `scripts/minigames/mg_abgevecht.gd:207-244`). Geen tweede interactie te leren.

**d. Druk — het zwakke punt.** Geen klok, geen aflopende timer, geen tempo dat oploopt. "Wat gebeurt er als de speler niets doet (5 s, 20 s)?" — **niets**: het spel wacht voor eeuwig op een tik op een van de drie knoppen. Er is wel spanning in de *uitkomst* (twee levensbalken die realtime tegen elkaar bewegen via een tween, `_meet()` regel 249-271), maar geen enkele externe druk om snel te beslissen. Dat is precies het "adrenaline"-element dat de opdracht vraagt en hier ontbreekt.

**e. Faalkans.** Reëel: `_afronden()` (regel 297-316) — A verliest als B niet op 0 staat na 3 klappen. QA lost dit consequent in **1 aanroep** op (`qa_solve()` draait zelf een `while`-lus met `await` door alle rondes, regel 369-386) — bevestigd, standalone `--minigame=mg_abgevecht --autoplay`:
```
outcome=0 score=85 a_wint=true keuzes=["Voorraad-jab...", "Verplicht account eruit", "iDEAL bovenaan"]
```
Faaltekst ("B staat nog. A niet meer overtuigend genoeg. dat is ook data") kost geen voortgang — het ticket blijft gewoon open en Danny's oplopend absurde smoesjes (`t07_fail`) doen de rest.

**f. Climax.** `docs/audit-shots/mgB_mg_abgevecht_climax.png`: groene banner "B ligt eruit. A wint. dat is data. psies" — geen schok/confetti, puur tekst-op-kleur, en de banner overlapt lelijk de resterende variant-knoppen eronder (leesbaar, maar rommelig gelaagd). Bij een treffer: `AudioDirector.play_ui(&"pak")`, geen visuele "klap"-tween op de balken zelf buiten de normale vulanimatie.

**g. Dubbel publiek.** Sterk: "kies de klap, ik kijk wat-ie doet" is voor een leek een simpel spelletje-met-drie-opties; voor een marketeer is elke tekst een herkenbare CRO-in-joke (iDEAL bovenaan, een niet-bestaand loyaliteitsprogramma, "voor de zekerheid" een veld erbij). Danny's `toon_tegenklap`-optie (regel 329-333) is een leuke laag extra info die alleen zichtbaar is als de data dat vraagt.

**h. Touch.** Knoppen via `UiKit.keuzeknop` (min. 94×26 px) en `UiKit.knop_primair` (30 px) — ruim boven 22 px, geen probleem gevonden.

**i. Lengte.** Onder autoplay al klaar binnen 2-3 s (`mgB_mg_abgevecht_mid2.png` toont al ronde 3/3 op t=2s); met leestijd voor drie opties per ronde ligt een menselijke ronde eerder rond 20-40 s — binnen de norm, maar aan de korte kant zonder klok om het te rekken.

**j. Grijze-blokken-test.** Slaagt op mechaniekniveau (kiezen-uit-drie-met-nettoresultaat is anders dan slepen-onder-tijd), maar voelt zonder de tekst een stuk kaler dan mg_cro: geen klok, geen levende hittestippen, alleen twee balken en drie knoppen.

**Wat de speler nu ervaart.** Je krijgt geen collega te zien voor dit ticket — het scherm springt meteen naar het WAT/WAAROM-kaartje. Binnen is het overzichtelijk: drie opties, kies er een, zie een balk bewegen, herhaal. Het went snel, maar nergens voel je tijdsdruk; je kunt de tekst van alle drie opties rustig lezen zonder dat er iets tegen je tikt.

**Wat "halve bak" voelt.** Geen enkele vorm van druk of oplopend tempo (d) — het enige van de drie minigames zonder klok of dreigende teller; dat botst direct met de expliciete lat "echte uitdaging + adrenaline". De banner overlapt de UI eronder rommelig (f, `mgB_mg_abgevecht_climax.png`).

**Wat al goed is.** Kortste, schoonste tekstpad van de drie (4 tikken, 66 woorden); QA lost het foutloos en snel op; de nettoschade-vs-tegenklap-afweging is een echte kleine puzzel per ronde.

**Ontwerpvoorstel.** Voeg een korte klok per ronde toe (bv. 6-8 s om te kiezen) die bij aflopen automatisch de zwakste optie kiest — dat geeft precies de "kies snel of je verliest de beurt"-spanning die nu ontbreekt, zonder de bestaande data te veranderen. Laat de HP-balk bij een treffer even schokken (`Juice`-patroon, al elders in de codebase) in plaats van alleen te tweenen. Verplaats de banner buiten de resterende keuzekaarten zodat hij niet overlapt.

---

## 3. mg_video — "De renderpijplijn" (BBD-208, koen)

**Verdict:** de meest volwassen van de drie — een echte doorstroom-puzzel met zichtbare druk, een leerzame fail en een grap die letterlijk op het scherm groeit — maar met de langste tekstpijplijn ervoor.

| | uitleg-last | affordance | druk | faalspanning | climax | dubbel publiek | touch |
|---|---|---|---|---|---|---|---|
| score 1-5 | 2 | 4 | 5 | 4 | 4 | 4 | 4 |

**a. Tekst vóór eerste handeling.** Zwaarste pad van de drie. Niet-eigenaar: offer `t08_offer` 4 regels (~43 woorden, 4 tikken) → briefing van Koen (33 woorden gevuld, 1 tik) → WAT/WAAROM (18+19=37 woorden, 1 tik). **~113 woorden, 6 tikken.** Eigenaar (koen): offer (4 tikken) + traittoast (auto) + kaartje (1 tik) = 5 tikken, geen briefing.

**b. Tijd tot eerste input.** Ook hier: zonder `--autoplay` blijft het scherm op het kaartje staan tot 1,1 s (`mgB_mg_video_first_koen.png` = `..._first_willem.png` = `..._intro.png`). Eenmaal binnen: het spel vult zelf de eerste Prompt-slots (`_INTAKE`-timer, regel 34, 267-269) zodat je nooit op een leeg canvas start — goede affordance, je hoeft niet eens de "Nieuwe clip"-knop te vinden om iets te zien bewegen.

**c. Kernhandeling.** Eén werkwoord: doorschuiven (tik op een rijp blokje, of ernaast in de rij voor het meest rijpe — `_op_blok_input`/`_op_rij_input`, regel 339-352). Eén tweede, optionele handeling: "Nieuwe clip" halen (de pijplijn vult zichzelf ook automatisch, dus dit is versnelling, geen verplichte extra vaardigheid).

**d. Druk — het sterkste punt van de drie.** Twee zichtbare, voelbare drukmeters tegelijk: een aftellende klok (tijd) én een credit-burn op een rijpe, vastzittende clip in Render (rode paneel, pulserende `modulate`, regel 365-403). Doe je niets: credits lopen weg zodra Render vol raakt met rijpe clips — precies de "vind het knelpunt of het kost je geld"-spanning die de brief vraagt.

**e. Faalkans.** Reëel op twee manieren (credits op, of tijd om). QA lost het in **1 aanroep** op (`qa_solve()` zet alleen een vlag, `_qa_stap()` in `_process()` trekt daarna zelf leeg, regel 491-499) — bevestigd:
```
outcome=0 score=100 gepubliceerd=5 credits_over=120 tijd_over≈43 (van 60 s budget, dus ~17 s gebruikt)
```
Climax zichtbaar vastgelegd rond t=18,5 s (`mgB_mg_video_climax3.png`).

**f. Climax.** Groene banner "Vijf clips gepubliceerd. Koen zet er piepelienies om, dan hoeft dit nooit meer met de hand." (`mgB_mg_video_climax3.png`) — ook hier overlapt de banner de Render-rij eronder rommelig, zelfde patroon als mg_abgevecht. Geen deeltjes/schok; wel een goed leesbare cliplabel-onthulling die de hele speeltijd door zichtbaar blijft groeien (caption-regel, regel 431-434) — dát is de eigenlijke "juice": de grap ("Iets met een regenboog. Van haar neef") komt letterlijk tevoorschijn terwijl je speelt.

**g. Dubbel publiek.** Sterk: "schuif de blokjes door" is voor een leek een simpel doorstroom-spelletje; voor wie AI-videopijplijnen kent is het knelpunt-idee (Render kost geld als je 'm laat vollopen) een herkenbare, licht satirische waarheid. De cliplabels zelf zijn de losse grap-laag (`_clip_label`, "Paard kijkt in de camera", "Iets met een regenboog. Van haar neef").

**h. Touch.** Blokjes zijn 50×34 px, ruim boven 22 px; bovendien vangt de hele rij (`mouse_filter = STOP` op elke `PanelContainer`-rij, regel 134-135) een tik náást een blokje op en pakt dan automatisch de meest rijpe clip — een bewust grof tikdoel, precies goed voor een duim.

**i. Lengte.** Budget 60 s; met autoplay al klaar in ~17-18 s. Een mens die eerst moet lezen/begrijpen zit realistischer tussen 30-60 s — binnen de norm, eerder aan de langere kant.

**j. Grijze-blokken-test.** Slaagt duidelijk: drie stagerijen met capaciteit en rijpingstijd voelen structureel anders dan de andere twee, en zouden dat ook zonder enige tekst of kleur doen (alleen grijze blokken die van rij naar rij schuiven is al een herkenbare puzzel).

**Wat de speler nu ervaart.** Je hoort Koen zijn ticket toelichten, leest zijn briefing over het knelpunt, dan het kaartje, en dan pas mag je zelf een blokje aantikken. Eenmaal binnen werkt het meteen: clips komen vanzelf binnen, je ziet Render rood oplichten als er geld wegbrandt, en je moet kiezen wat je eerst leegtrekt. Het voelt als een echt mini-strategiespelletje met tijdsdruk, tot de banner verschijnt met de allerlaatste, absurdste cliptitel.

**Wat "halve bak" voelt.** Langste tekstpad van de drie vóór de eerste tik (113 woorden, 6 tikken) voor een mechaniek die zichzelf prima uitlegt zodra je de eerste twee blokjes ziet bewegen. De succesbanner overlapt de rij eronder net als bij mg_abgevecht.

**Wat al goed is.** Twee tegelijk voelbare drukbronnen (klok + credit-burn) — de beste "adrenaline" van de drie; zelfvullende pijplijn zodat je nooit op niets wacht; een grap die zich letterlijk onthult terwijl je speelt in plaats van pas op het eindscherm.

**Ontwerpvoorstel.** Schrap de briefing-tekst hier ook (het knelpunt wordt al zichtbaar zodra Render rood oplicht — laat het spel dat zelf laten zien in plaats van het eerst te laten opzeggen). Laat de statusregel bij "credits" een korte rode flits geven de eerste keer dat er echt geld wegbrandt, zodat ook een speler die de tekst oversloeg meteen doorheeft wat pijn doet. Verplaats de banner naast in plaats van over de laatste rij.

---

## Gedeelde bevindingen (tekstpijplijn, alle drie)

1. **Het WAT/WAAROM-kaartje is een harde blokkade, geen vluchtige toast.** Zonder `--autoplay` (dus: zonder al te weten wat je moet doen) blijft het scherm op dit kaartje staan tot je "Starten" tikt — bevestigd voor alle drie, voor beide geteste spelers, op zowel 1,1 s als 2,0/4,0 s. Dat is precies zoals het hoort te werken (`MinigameIntro.moet_getoond()`), maar het betekent ook dat er **geen enkel scherm bestaat** waarop je de minigame zelf ziet zonder eerst door tekst te zijn gegaan — de brief se klacht ("nu voelen ze allemaal als HEEL VEEL TEKST") zit dus niet alleen in de hoeveelheid woorden maar ook in de structuur: één blokkerend kaartje per minigame, per speelbeurt, zonder uitzondering.
2. **Twee van de drie eindbanners overlappen rommelig met de UI eronder** (mg_abgevecht, mg_video) — geen inhoudelijk probleem, wel een consistente visuele ruwe rand op het climax-moment, het moment dat juist het scherpst moet ogen.
3. **mg_cro en mg_video delen dezelfde tekstlaag-opbouw** (offer → briefing → trait-toast → kaartje) omdat beide een echte `owner_character` hebben; **mg_abgevecht heeft die laag niet** (`owner_character: ""`), wat het qua tekst het lichtste van de drie maakt maar ook het enige zonder een "collega vertelt je iets"-moment — een bewuste ontwerpkeuze (recent vastgelegd in `docs/MINIGAMES.md`/`TraitModifier.GEEN_VOORDEEL`), niet een omissie.
4. **QA-tooling is geen betrouwbare graadmeter voor mg_cro.** Elke sessie die met `tools/qa_shot.py minigames` of losse `--minigame=mg_cro --autoplay`-runs conclusies trekt over "hoe ziet een succesvolle ronde eruit" ziet in werkelijkheid altijd de faalbanner. Zie sectie 1e voor het bewijs en de exacte regelverwijzingen.

## Wat ik niet kon verifiëren

- Geluid zelf (alleen `AudioDirector.play_ui(&"...")`-aanroepen gelezen, niet beluisterd — sandbox is headless/write-movie, geen audio-uitvoer beschikbaar).
- Trilling/`Haptiek` — vereist een echt aanraakscherm.
- Een écht menselijk leestempo voor de dialoog- en briefingteksten (de "6 tikken"-telling neemt aan dat elke regel met één tik wordt weggeklikt; een trage lezer heeft er feitelijk evenveel tikken maar meer tijd voor nodig).
- Een succesvolle mg_cro-ronde via de geïsoleerde `--minigame=`-route kon *niet* gemaakt worden zonder de QA-harness te wijzigen (read-only); het succesbewijs komt daarom uit een volledige `--playthrough --autoplay`-run in plaats van een los frame.
- Exacte contrastwaarden op de banner-overlap (f, mg_abgevecht/mg_video) zijn niet gemeten, alleen visueel beoordeeld.

---

**Rapport:** `/private/tmp/claude-502/-Users-daan-Documents-fun--claude-worktrees-10-tickets-vrijheid-handover-079cbc/5f701028-9d25-4a7e-a4d7-0da3b68bd7aa/scratchpad/audit-mg-B.md`
