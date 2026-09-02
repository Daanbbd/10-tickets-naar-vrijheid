# Ticketstroom-audit — elf oplossingen voor een dag van tien tickets

**Datum:** 2 september 2026 · **Engine:** Godot 4.7.2 · **Build:** werkboom op `ce59b06`
**Lens:** `GD-Agentic-Skills/skills/godot-quest-system/SKILL.md`
**Wijzigingen:** geen — geen code, geen data, geen docs aangepast.

De questmotor is netjes gebouwd en volgt de blauwdruk vrijwel overal. De schade
zit in de laag erboven: een storing die toeslaat tijdens het afronden van een
ticket, en een dialoogregel die zijn eigen id voorleest.

| | |
|---|---|
| Eigen testsuite | **17.497 controles, 0 fout** — geen van de bevindingen hieronder wordt erdoor gezien |
| Oplossingen per doorloop | **11** voor een dag van tien tickets; BBD-205 wordt elke doorloop twee keer opgelost |
| Lezers van negen beloningen | **0** — zes items en drie vlaggen worden uitgedeeld en door geen enkele conditie gelezen |

## Bewijslast

Statisch gelezen: `quest_engine.gd`, `session.gd`, `conditions.gd`,
`ticket_controller.gd`, `gevolgen.gd`, `storingen.gd`, `bus.gd`, `urenstaat.gd`,
alle tien `data/tickets/*.json` en `data/storingen.json`.

Uitgevoerd: de eigen testsuite (17.497 controles, groen) en een volledige
geautomatiseerde speelbeurt als *daan* (10/10, exitcode 0, 161,6 s). Eén
gedragsaanname is los geverifieerd tegen 4.7.2 in plaats van beredeneerd — zie
Q-02.

---

## Wat er sinds de vorige audit is veranderd: de dag heeft nu wél een keten

`docs/AUDIT.md` noemde als kern: negen tickets met `available_when: {}`, geen
enkele afhankelijkheid. Dat is opgelost.

```
open vanaf de start        via unlocks        via BBD-208      9 gedaan + sleutel

BBD-202  ──────────────▶   BBD-209
BBD-203  ──────────────▶   BBD-208  ──────▶   BBD-201  ──┐
BBD-204  ──────────────▶   BBD-207                       ├──▶  BBD-210
BBD-205  ──────────────▶   BBD-206  ─────────────────────┘
```

Vier tickets staan open vanaf seconde één, vijf zitten achter een
`unlocks`-rand, en de finale achter `min_tickets_done: 9` plus de deploysleutel.
Die winst is echt. De rest van dit rapport gaat over de gevolgen die er niet
mee zijn meegenomen: vijf tickets die nu LOCKED starten in een UI die daar geen
woord voor heeft, en een storing die nu botst met de nieuwe volgorde.

---

## Bevindingen

Twaalf, gesorteerd op speelbare schade.

### Q-01 · HOOG · bevestigd in een doorloop
**De backend-storing slaat toe *binnen* `complete()` en eet voortgang op**

**Bewijs.** De log van een gewone doorloop:

```
[SPEELBEURT] BBD-206 opgelost  (5/10)
[SPEELBEURT] BBD-207 opgelost  (5/10)   <- teller loopt niet op
[SPEELBEURT] BBD-208 opgelost  (6/10)
[SPEELBEURT] BBD-209 opgelost  (7/10)
[SPEELBEURT] BBD-201 opgelost  (8/10)
[SPEELBEURT] BBD-205 opgelost  (9/10)   <- voor de tweede keer
[SPEELBEURT] BBD-210 opgelost  (10/10)
[SPEELBEURT] 10/10 — naar de voordeur
```

**Mechanisme.** `QuestEngine.complete()` zet DONE, doet `done_order.append()`,
draait `run_effects()` en boekt daarna de tijd. `Storingen` hangt aan drie
signalen die alle drie *binnen* `complete()` vallen: `flag_changed`,
`time_booked` en `ticket_completed`. Bij BBD-207 is het `book_time()` →
`Bus.time_booked` → storingen.gd:84: dat ticket heeft geen `set_flag` in zijn
beloning (`add_item` + `toast` + `cue`), dus het `flag_changed`-pad bestaat daar
niet. Op dat moment is `done_count()` precies 6 en is t05 DONE, dus
`storing_backend_crash` gaat af en roept `reopen(&"t05")` aan — mét
`done_order.erase()` — terwijl `complete()` nog halverwege is.

> **Correctie op een eerdere versie van dit rapport.** Hier stond dat de storing
> via `set_flag` → `Bus.flag_changed` binnenkomt. Dat kan bij BBD-207 niet: van
> de tien tickets hebben er maar drie een `set_flag` in `reward_effects` (t04
> `frontend_ok`, t05 `backend_ok`, t06 `cro_ok`). Het `flag_changed`-pad is wél
> hoe t05 zichzélf heropent als je hem als zevende of later oplost, want dat
> effect valt vóór `book_time()`. Gevonden door fun-2f tijdens het afstemmen.

**Gevolg.** Je lost een ticket op en de teller beweegt niet. Omdat
`book_time()` vóór `Gevolgen.boek()`, vóór `Bus.ticket_completed.emit()` en vóór
`save_to_disk()` staat, vuurt het voltooiingssignaal terwijl `is_done(t05)` al
weer false is, en schrijft de save t05 als open weg. En de dag vraagt elf
oplossingen voor tien tickets, waarvan de elfde een herhaling van dezelfde
minigame is — precies wat het ontwerp elders vermijdt ("geen twee delen een
mechaniek").

**Erger pad.** Zeven tickets zijn bereikbaar zonder t05. Doe er zes, en los dán
BBD-205 op: de trigger staat al op scherp en `when` wordt waar op het moment dat
je het ticket afrondt. Het wordt heropend in dezelfde adem als zijn eigen
afrondingsdialoog, vóór die dialoog speelt. Getraceerd in code, niet in een
doorloop gezien.

**Regelbreuk.** [storingen.gd:26](../scripts/world/storingen.gd) schrijft de
invariant zelf op: *"een storing kost tijd en informatie, nooit voortgang"*. Een
heropening haalt het ticket uit `done_order`, en dat ís voortgang.

**Richting.** Laat `_evalueer()` nooit binnen een lopende mutatie draaien —
`call_deferred`, of een wachtrij die pas leegloopt als `complete()` klaar is.
Strakker: een `_completing`-guard in `QuestEngine` waar `reopen()` op weigert.
En overweeg of een heropening niet gewoon een nieuw ticket hoort te zijn in
plaats van hetzelfde ticket terug op de vloer.

### Q-02 · HOOG · geverifieerd in 4.7.2
**Een opgelost ticket aanspreken leest zijn eigen dialoog-id voor**

**Waar.** [ticket_controller.gd:105](../scripts/world/ticket_controller.gd) —
`await _line(_dlg(t, &"done", "Dit is opgelost. Even niet aan zitten."))`

**Mechanisme.** `_dlg()` geeft een dialoog-*id* terug als de sleutel bestaat, en
anders de fallback-tekst. `_line()` zet zijn argument rechtstreeks in de
dialoogbox. Alle tien tickets definiëren `"done"`, dus de box zegt letterlijk
`t01_done`. Twee regels lager, bij `fetch` en `blocked`, staat wél het goede
patroon: `_play_or_line(id, fallback)`.

```
$ godot --headless --script probe.gd
get(&"done")  -> t01_done
has(&"done") -> true
as StringName -> t01_done
```

String- en StringName-sleutels zijn in Godot 4 uitwisselbaar in een Dictionary,
dus de `&"done"`-lookup vindt de JSON-sleutel `"done"`. De fallback wordt nooit
bereikt.

**Gevolg.** Tien geschreven `*_done`-dialogen in `data/dialogue/tickets.json`
spelen nooit. In plaats daarvan ziet de speler een interne id. Goed bereikbaar:
een TICKET-interactable blijft na oplevering TICKET, en `_ticket_for_anchor()`
valt bij een leeg anker terug op het laatst opgeloste ticket.

**Zelfde fout, nog stil.**
[ticket_controller.gd:109](../scripts/world/ticket_controller.gd) doet hetzelfde
voor `"locked"`. Dat valt nu niet op omdat geen ticket die sleutel heeft — maar
zie Q-03, want daar wil je hem juist gaan gebruiken.

**Richting.** `_play_or_line()` op beide regels, met de vaste tekst als fallback
in plaats van als `_dlg`-argument.

### Q-03 · MIDDEN · regressie van de nieuwe keten
**De keten bestaat, maar het spel vertelt er niets over**

**Bewijs.** Vijf tickets starten LOCKED. Geen enkel ticket definieert een
`locked`-dialoog, dus alle vijf de objecten zeggen dezelfde regel: *"Hier is nu
niets te doen."* Nergens staat wat het wel losmaakt.

**Erger.** Bord en HUD lezen `QuestEngine.undiscovered_count()`, en dat telt
alleen *beschikbare* tickets. Bij de start zegt de HUD "Nog 4 op de vloer"
terwijl de teller "Tickets 0/10" zegt. Heb je die vier gevonden, dan zegt het
bord "Alles gevonden." — met zes tickets nog op slot en 0/10 op de kop. Daarna
flipt die regel heen en weer tussen "Alles gevonden" en "Nog 1 op de vloer" bij
elke oplevering.

**Waarom.** Beide tellers zijn ontworpen voor het oude model waarin alles
tegelijk openstond. De ontdekking wás toen de enige onbekende; nu is er een
tweede.

**Richting.** Geef een LOCKED ticket een zichtbare vorm — een leeg vakje op het
bord met de reden ("wacht op BBD-208") — of laat de tellers de vergrendelde
tickets meerekenen en apart benoemen. Een `locked`-dialoog per ticket, met de
naam van de blokkade erin, kost alleen data (en Q-02 moet dan eerst weg).

### Q-04 · MIDDEN
**`available_when` wordt alleen bij een oplevering opnieuw gewogen**

**Bewijs.** `refresh_availability()` heeft drie aanroepers:
`initialise_tickets()`, `complete()` en het titelscherm na het laden.
`run_effects()` wordt daarentegen uit vier plekken gedraaid: ticketbeloningen,
dialoognodes ([dialogue_controller.gd:77-84](../scripts/ui/dialogue_controller.gd)),
de telefoon van De Klant ([telefoon.gd:273](../scripts/ui/telefoon.gd)) en
storingen ([storingen.gd:224](../scripts/world/storingen.gd)).

**Gevolg.** Elke `available_when` op `flags_all`, `has_item` of `overwerk` gaat
pas open bij de volgende oplevering, niet op het moment dat hij waar wordt. Bij
`overwerk` — een tijdsconditie — betekent dat: nooit, behalve toevallig op een
oplevergrens. Nu latent, omdat de vijf gesloten tickets via `unlocks` lopen; het
is een valkuil voor de eerstvolgende designer die "ticket opent als je de sleutel
hebt" in data wil zetten.

**Richting.** Hang `refresh_availability()` aan de bron in plaats van aan het
pad: één keer aan het einde van `run_effects()`, of aan `Bus.flag_changed` /
`item_added`. Hij is idempotent en goedkoop, dus vaker draaien kost niets.

### Q-05 · MIDDEN
**`unlocks` is een gebeurtenis zonder herspeling — een contentwijziging sloopt bestaande saves**

**De asymmetrie.** `world_changes` zijn herspeelbaar en worden na het laden
opnieuw afgespeeld (`WorldMutator.replay_all()`). `reward_effects` en `unlocks`
zijn dat niet: ze draaien exact één keer, op het moment van opleveren, en laten
alleen hun uitkomst in de save achter.

**Gevolg.** Komt er een ticket bij met `_never_` als `available_when`, en is zijn
ontsluiter in een bestaande save al DONE, dan staat het na het laden permanent op
LOCKED. `refresh_availability()` promoveert het niet (de conditie klopt niet) en
`unlocks` draait niet meer (het ticket is al opgeleverd). `all_done()` vraagt dan
een aantal dat niet te halen is. Geen crash, geen waarschuwing — de speler komt
de deur niet meer uit.

**Richting.** Draai de rand om: zet de afhankelijkheid op het kind
(`"available_when": {"tickets_done": ["t08"]}`) in plaats van als `unlocks` op de
ouder. Dan is beschikbaarheid volledig afgeleide state, wordt hij door
`refresh_availability()` na het laden gewoon opnieuw berekend, en verdwijnt Q-07
er meteen mee.

### Q-06 · MIDDEN
**Opnieuw opleveren deelt de beloning opnieuw uit**

**Mechanisme.** `complete()` beschermt zich met `if Session.is_done(id): return`.
Na een `reopen()` staat het ticket op AVAILABLE, dus die wacht laat door en
`run_effects()` draait een tweede keer. `set_flag` is idempotent; `add_item`,
`add_counter` en `kost_tijd` zijn dat niet.

**Vandaag.** Elke doorloop eindigt met `productdata` op aantal 2, en
`Gevolgen.boek(&"mg_backend_fix", …)` draait twee keer. De schade blijft nu klein
omdat niemand die twee leest (Q-08), maar het is dezelfde dubbele-beloningsfout
die de blauwdruk expliciet verbiedt.

**Richting.** Boekhouden welke `reward_effects` al gedraaid hebben (bijvoorbeeld
een `beloond`-set naast `done_order`), of de niet-idempotente ops bij een
heropening overslaan. Kies dit bewust: een tweede oplevering die opnieuw tijd
kost is verdedigbaar, een tweede die opnieuw een item uitdeelt niet.

### Q-07 · MIDDEN
**`_never_` is een magische vlag zonder vindplaats in de code**

**Waar.** Vijf databestanden zeggen
`"available_when": {"flags_all": ["_never_"]}`. De naam komt in geen enkel
`.gd`-bestand voor, staat in geen enkele doc, en heeft geen validator.

**Gevolg.** "Gesloten tot iets hem opent" wordt uitgedrukt als een conditie die
per ongeluk waar kan worden: zet ooit iemand een vlag met die naam, dan gaan alle
vijf tegelijk open. En de bedoeling is niet leesbaar — `flags_all: ["_never_"]`
ziet uit als data en niet als een schakelaar.

**Richting.** Maak het expliciet. Een echte sleutel in `Conditions.KEYS`
(`{"nooit": true}`) is één regel en de validator dekt hem meteen. Beter nog: het
omdraaien uit Q-05, waarmee de sentinel helemaal verdwijnt.

### Q-08 · MIDDEN · nog open uit de vorige audit
**Negen van de tien ticketbeloningen worden door niemand gelezen**

**Precies.** De tien tickets delen zes items en drie vlaggen uit. Grep over
`data/`, `scripts/` en `autoload/` — buiten de plek waar ze worden uitgedeeld —
geeft nul treffers voor: `user_story`, `planning`, `klantfeedback`,
`productdata`, `audiobestand`, `videobestand`, `frontend_ok`, `backend_ok`,
`cro_ok`.

**De uitzondering.** `deploysleutel` is het enige item dat een conditie ergens
leest. Van de twee `has_item`-lezers in de code is er één de generieke
`Conditions.check()` en één de QA-harnas.

**Richting.** Dit is een contentkeuze, geen bug: óf de items gaan iets doen (een
deur, een dialoogvariant, een korting op de finale), óf ze gaan eruit. Zoals het
nu staat is elke oplevering een toast en een teller. Merk op dat de *narratieve*
kant hier wél in orde is: de dertien `gevolg_*`-vlaggen uit `Gevolgen` worden
allemaal door de finale gelezen.

### Q-09 · LAAG
**Twee bronnen van waarheid voor "de dag is klaar"**

**Mechanisme.** `complete()` zet `alle_tickets_klaar` op true en zet hem nooit
terug. Maar `all_done()` kan wél terug naar false, want `reopen()` haalt uit
`done_order`. De voordeur gebruikt `Session.all_done()`
([main.gd:476](../scripts/world/main.gd), goed); zes dialoogvarianten in
`data/dialogue/wereld.json` hangen aan de vlag.

**Gevolg.** Nu niet bereikbaar — de enige heropening zit op zes opgeloste
tickets. Bij een tweede `reopen_ticket` later in de dag praat het kantoor over
een afgeronde dag terwijl de deur dicht blijft.

**Richting.** Zet de vlag ook terug in `reopen()`, of laat de dialoog
`min_tickets_done` gebruiken en gooi de vlag weg.

### Q-10 · LAAG · ontwerpvraag
**`order` beschrijft niet meer in welke volgorde je kunt spelen**

**Bewijs.** BBD-201 — *"Wat moeten we eigenlijk bouwen?"*, `order: 1` — zit
achter BBD-208, `order: 8`. Het bord
([scrumbord.gd:112](../scripts/ui/scrumbord.gd)), `GameData.ticket_ids()` en dus
ook `next_hint_ticket()` sorteren op `order`, dus het staat bovenaan de lijst
terwijl het als negende bereikbaar is.

**Vraag.** Als de grap is dat pas na de video blijkt dat niemand de user story
heeft opgeschreven: dan is dit goed, en verdient `order` een andere naam (het is
nu narratieve nummering, niet volgorde). Is het niet de bedoeling, dan wijst de
keten de verkeerde kant op.

### Q-11 · LAAG
**Docs, comments en een hardgecodeerde 10 spreken de data tegen**

**Achterhaald.**

| Plek | Staat er | Klopt niet want |
|---|---|---|
| `README.md:35` | "De tickets staan allemaal tegelijk open" | vijf van de tien starten LOCKED |
| `README.md:36` | "Elf tickets, elf verschillende opgaven" | tien tickets, elf minigames — `mg_urenstaat` hangt aan geen ticket |
| `docs/QUESTS.md:5` | "dat is de wincondititie, geen afhankelijkheid" | er zijn nu afhankelijkheden (plus tikfout) |
| `docs/QUESTS.md:148` | "negen staan open vanaf de start" | vier |
| `quest_engine.gd:215` | "nu alles tegelijk openstaat" | niet meer |
| `ticket_controller.gd:504` | "nu alles tegelijk openstaat" | niet meer |
| `boot.gd:52` | "Sinds alles tegelijk openstaat is dat geen voorwaarde meer" | niet meer |

**Hardgecodeerd.** `scrumbord.gd:126` schrijft `"JOUW TICKETS %d/10"` en
`main.gd:321/333/427` schrijven `/10`, terwijl de HUD `Session.total_tickets()`
gebruikt. Elf tickets maken van het bord een leugenaar en van de HUD niet.

**Kleine dode dingen.** `Bus.ticket_activated` en `Bus.world_change_applied`
worden uitgestuurd en door niemand beluisterd. `t.minigame_config` is wél gewired
(via `TraitModifier`) maar leeg in alle tien de tickets.

### Q-12 · MIDDEN
**17.497 groene controles zien geen van bovenstaande bevindingen**

**Waarom niet.** De suite controleert dat elke dialoog-id *bestaat*
(`test_runner.gd:421`, `:1747`), nooit dat hij ook echt gespeeld wordt — dus Q-02
glipt erdoor. Ze controleert ticketstanden na een oplevering, nooit tijdens; ze
heeft geen enkele assertie dat `done_count()` monotoon oploopt; en ze test
`reopen_ticket` op een ticket dat daarna hard op DONE wordt gezet (`:2510`),
waarmee juist het heropleveringspad wordt weggeknipt.

**Bonus.** `boot.gd::_quickstart --ticket=` ontsluit en levert tickets op in
`order`-volgorde en negeert de keten volledig. De QA-snelkoppeling kan dus
toestanden bouwen die het echte spel niet kan bereiken. Bij afsluiten lekt de
suite 36 ObjectDB-instanties en 7 resources.

**Richting.** Vier controles dekken vrijwel dit hele rapport:

1. elke `dialogue_ids`-sleutel die de speler kan raken speelt een dialoog en toont geen id;
2. `done_count()` daalt nooit binnen één `complete()`;
3. tweemaal opleveren van hetzelfde ticket verandert de inventaris niet;
4. bereikbaarheid van alle tickets waarbij `unlocks` de enige route is voor een `_never_`-ticket.

---

## Waar de motor het goed doet

Geen troostronde: op zeven van de acht harde regels uit de blauwdruk staat de
motor goed, en dat is de reden dat de bevindingen hierboven allemaal in de laag
*boven* de motor zitten.

| Regel uit de NEVER-lijst | Stand | Bewijs |
|---|---|---|
| Questen niet alleen op de speler | goed | Alle state in de `Session`-autoload; de wereld is `f(Session)` |
| Geverifieerde `StringName`-ids | goed | Consequent `StringName` voor tickets, vlaggen, items en counters, met een validator over de data |
| Niet pollen in `_process` | goed | Vijftien `_process`-functies, geen enkele die questtoestand afvraagt |
| Save/load voor questtoestand | goed | Nu wél gewired (`title_screen.gd:206`), inclusief opslaan bij achtergrondgang. Standen gaan als *naam* de save in, niet als enum-getal — een echt migratiepad |
| Geen questlogica in objectscripts | goed | Alleen `TicketController` roept `complete()` aan; objecten en NPC's dragen een anker, geen logica |
| Beloning niet in de quest-resource | goed | `TicketDef` declareert `reward_effects` als data; `QuestEngine` voert uit en `Session` muteert |
| Geen dubbele actieve instanties | goed | `_set_state()` is een idempotente overgang; `discover()` en `mark_helper_present()` hebben eigen wachten |
| **Geen dubbele beloning** | **fout** | Zie Q-06. De enige regel die breekt — en hij breekt via een pad dat de blauwdruk niet kent: heropenen in plaats van dubbel verbinden |

Twee dingen die de blauwdruk niet vraagt en die hier beter zijn dan gebruikelijk:
de scheiding tussen `run_effects` (draait één keer) en `world_changes`
(idempotent en herspeelbaar) is expliciet en overal volgehouden, en het
invoerslot is een *getelde* semafoor in plaats van een bool, met de bug die dat
oploste in het commentaar erbij.

---

## Volgorde, als er één middag is

1. **Q-02 eerst** — twee regels, en er komen tien geschreven dialogen bij die nu
   een id voorlezen. Beste verhouding in het rapport.
2. **Dan Q-01** — de enige bevinding die zichtbaar voortgang afpakt, en de enige
   die de eigen invariant van het project breekt. Het uitstel van `_evalueer()`
   is klein; de vraag óf een heropening het goede ontwerp is, is dat niet.
3. **Dan Q-03** — de keten is de grootste winst sinds de vorige audit en de
   speler kan hem niet zien. Zonder dit is het verschil met "negen losse
   boodschappen" alleen in de data zichtbaar.
4. **Q-05 en Q-07 samen** — de afhankelijkheid op het kind zetten haalt de
   `_never_`-sentinel weg, maakt beschikbaarheid volledig afgeleid, en maakt
   saves ongevoelig voor contentwijzigingen. Één datamigratie, drie problemen
   minder.
5. **Q-08 is een ontwerpbeslissing, geen taak** — negen dode beloningen zijn niet
   stuk, ze zijn onbeslist. Kies: iets laten doen, of weghalen.
6. **Q-11 en Q-04 bij gelegenheid** — achterhaalde docs en een teller die te laat
   weegt kosten nu niemand een speelbeurt, maar wel de volgende persoon die deze
   data aanraakt.

---

## Verantwoording

Er is voor deze audit niets gewijzigd: geen code, geen data, geen docs. Alle
regelverwijzingen gelden voor de werkboom op `ce59b06`.

Q-01 en Q-08 zijn in respectievelijk een echte doorloop en een grep bevestigd;
Q-02 is los tegen Godot 4.7.2 geverifieerd. Het "erger pad" bij Q-01 en de
saveschade bij Q-05 zijn in code getraceerd en niet uitgespeeld.
