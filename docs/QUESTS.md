# De tien tickets

**Er is geen vaste volgorde, maar wel een keten.** Vier tickets staan vanaf
minuut één open — BBD-201, BBD-202, BBD-204 en BBD-205 — en je kiest zelf waar
je begint. BBD-201 (de kickoff) maakt er twee vrij, de andere drie elk één, en
BBD-210 (Naar productie) wacht tot de andere negen klaar zijn plus de
deploysleutel.

```
BBD-201  Wat moeten we eigenlijk bouwen?  ->  BBD-203  De klant heeft feedback
                                          ->  BBD-208  De klant wil een AI-video
BBD-202  Waarom sta ik hier eigenlijk?    ->  BBD-209  Paardenbugs
BBD-204  De frontend is stuk              ->  BBD-207  A tegen B
BBD-205  De backend is stuk               ->  BBD-206  Niemand koopt iets
9/10 + deploysleutel                      ->  BBD-210  Naar productie
```

**Waarom de kickoff de dag opent.** Dit stond andersom: BBD-203 (de
klantfeedback) was een startticket en BBD-201 hing twee schakels diep achter
BBD-208, dat weer achter BBD-203 hing. Je begon je dag dus met het vertalen van
feedback op een product waarvan het spel nog nergens had gezegd wát het was, en
je haalde Willem erbij voordat je iemand kende. De premisse kwam als negende aan
de beurt, en dat is precies waar de dag onlogisch van gaat voelen. Dat BBD-203
én BBD-208 achter BBD-201 hangen is geen willekeurige herordening: haar feedback
en die AI-video staan letterlijk in de `wensen`-lijst van diezelfde
scopesessie.

De entree heeft daarmee bij een verse dag geen open ticket. Dat is geen verlies:
je loopt de gang in en krijgt daar meteen drie briefjes, en "een ruimte
binnenlopen levert werk op" leert zich beter aan een ruimte waar je zelf naartoe
gelopen bent.

Die afhankelijkheid staat op het **kind**, in zijn eigen `available_when`
(`{"tickets_done": ["t01"]}`), en niet als `unlocks` op de ouder. Dat is geen
stijlkeuze: zo is beschikbaarheid afgeleide state, en herstelt
`refresh_availability()` de hele keten na het laden van een save. Een `unlocks`
is een gebeurtenis, en die kan na het laden niet opnieuw worden afgespeeld —
een ticket achter een al-opgeleverd ticket bleef daardoor eeuwig LOCKED.

`unlock_ticket` bestaat nog wél als effect-op, en `data/klant_berichten.json`
gebruikt hem voor BBD-207 en BBD-201: De Klant trekt tijdens de dag werk naar
voren. Dat is een tweede, bewuste route naast de keten.

Wat wél groeit is je **inventaris**: een ticket komt erin zodra je de ruimte
binnenloopt waar het hangt. Verkennen levert werk op; niets zit achter iets
anders. Op het ticketbord kies je welk ticket je doel wordt, en de doelregel,
de hint (Q) en de wijzer in de wereld volgen die keuze.

> Dit wijkt af van de oorspronkelijke opdracht, die de keten
> `1 -> 2 -> 3 -> 4/5 -> 6 -> 7/8 -> 9 -> 10` voorschreef.

De ruimtes zijn de echte ruimtes van de vloer — zie `docs/LEVEL.md`.

| Code | Titel | Zone | Vakgebied | Minigame | Open |
|---|---|---|---|---|---|
| BBD-201 | Wat moeten we eigenlijk bouwen? | Summit | daan | `mg_user_story` | vanaf het begin |
| BBD-202 | Waarom sta ik hier eigenlijk? | De Werkvloer | daan | `mg_planning` | vanaf het begin |
| BBD-203 | De klant heeft feedback | Entree | willem | `mg_klantfeedback` | na BBD-201 |
| BBD-204 | De frontend is stuk | De Werkvloer | victor | `mg_frontend_fix` | vanaf het begin |
| BBD-205 | De backend is stuk | Het Patchhok | jonathan | `mg_backend_fix` | vanaf het begin |
| BBD-206 | Niemand koopt iets | Basecamp | danny | `mg_cro` | na BBD-205 |
| BBD-207 | A tegen B | Koffiecorner | danny | `mg_abgevecht` | na BBD-204 |
| BBD-208 | De klant wil een AI-video | Het Vergaderhokje | koen | `mg_video` | na BBD-201 |
| BBD-209 | Er lopen paardenbugs door het kantoor | De Werkvloer | bastiaan | `mg_paarden` | na BBD-202 |
| BBD-210 | Naar productie | Birdhouse | iedereen | `mg_deploy` | bij 9/10 |

## Wereldveranderingen

Elk opgelost ticket verandert iets zichtbaars of hoorbaars. Alle veranderingen
zijn idempotent en worden bij het laden opnieuw afgespeeld.

| Code | Verandert |
|---|---|
| BBD-201 | `set_text` op `whiteboard_vergader`; `camera_focus` op `whiteboard_vergader` |
| BBD-202 | `set_text` op `scrumbord_gang` |
| BBD-203 | `set_text` op `wachtbank`; `despawn_npc` |
| BBD-204 | `set_text` op `wandmonitor_vloer`; `camera_focus` op `wandmonitor_vloer` |
| BBD-205 | `set_text` op `serverrack_a`; `set_modulate` op `serverrack_a` |
| BBD-206 | `set_text` op `dashboardmuur`; `set_modulate` op `dashboardmuur` |
| BBD-207 | `set_text` op `speaker_koffiecorner`; `set_ambience` |
| BBD-208 | `set_text` op `scherm_entree`; `spawn_npc` |
| BBD-209 | `set_text` op `vergadertafel` |
| BBD-210 | `set_text` op `deploycomputer`; `set_locked` op `voordeur` |

## Wat een ticket je aan tijd kost

Je dag is acht uur en er is meer werk dan dat (zie GAME_DESIGN.md). Wat het kost
staat in `scripts/core/urenstaat.gd`:

| Gebeurtenis | Kost | Waar geboekt |
|---|---|---|
| Ticket opgelost, jouw vakgebied | 30 min | `QuestEngine.complete()` |
| Ticket opgelost, collega erbij | 45 min | `QuestEngine.complete()` |
| Collega ophalen | 15 min | `QuestEngine.mark_helper_present()` |
| Mislukte minigame | 15 min | `TicketController`, FAIL-tak |
| Afgebroken minigame (ESC) | 0 | — |
| Rondlopen, onderzoeken, praten | 0 | — |

Twee tellers vullen samen de dag. Het grootboek hierboven boekt per handeling;
daarnaast tikt `Klok` er elke twintig seconden speeltijd één minuut bij
(`Klok.TICK_SEC`), zodat rondlopen en lezen ook tijd kosten — weinig, maar
zichtbaar op de klok. Een schone dag van ~25 minuten eindigt daardoor rond
19:00-19:30, dus na vijven. Dat is geen straf maar een gevolg: wat na je acht
uur (`Urenstaat.BUDGET_MIN`) dichtgaat, telt in de oplevering als *ongetest*
(`Gevolgen.ongetest_na_vijf()`, gevoed door `Session.completed_at`). Het
grootboek blijft headless testbaar; `_test_dagvenster` bewaakt dat de som van
beide tellers binnen één avond blijft.

De ticketkosten komen bewust **niet** uit de data. `reward_effects` is per ticket
identiek voor elk personage en kent geen `when`, terwijl de prijs afhangt van of
het jouw vakgebied was. De regel: *code boekt wat het systeem kost, data boekt
wat een scène kost* — voor dat laatste is er de effect-op `kost_tijd`.

Het ophalen wordt in `mark_helper_present()` geboekt en niet in de controller,
want die functie heeft drie aanroepers (de controller, `--playthrough` en de
testsuite); alleen daar telt een geautomatiseerde doorloop de zoektijd ook mee.

## Hints

Deze regels verschijnen op het ticketbord (▤, sneltoets Tab), via de hint
(?, sneltoets Q) en op de permanente doelregel in de HUD.

| Code | Hint |
|---|---|
| BBD-201 | Op de vergadertafel, achter het glas halverwege de gang. |
| BBD-202 | Meteen bij de voordeur, achter het eerste bureau-eiland. |
| BBD-203 | De klant zit op de bank, voorbij de kapstok. |
| BBD-204 | De wandmonitor hangt aan het begin van de werkvloer, naast het ticketbord. |
| BBD-205 | Direct onder de toiletten, achter de badgelezer. |
| BBD-206 | De dashboardmuur hangt in de tweede glazen ruimte, die met de ronde tafel. |
| BBD-207 | De speaker staat aan het eind van de tribune, tegen het blok waar je omheen kunt lopen. |
| BBD-208 | De iPad ligt in het hokje midden in de gang, met de Samen Bingo-poster op de deur. |
| BBD-209 | Ze zijn overal. Je vindt ze vanzelf. |
| BBD-210 | De deploymentcomputer staat in de laatste en grootste glazen zaal. De deploysleutel ligt in de plantenkast, onder het speelgoedpaard. |

De drie glazen vergaderruimtes staan in de hints **op een rij genummerd**:
Summit is de eerste, Basecamp de tweede, Birdhouse de laatste en grootste. Dat
is geen sfeertekst maar het navigatiesysteem: het glas op y7 maakt ze door de
hele gang zichtbaar (zie LEVEL.md), dus "de tweede glazen ruimte" is een
aanwijzing die je met je ogen oplost in plaats van met een plattegrond.

De overige hints ankeren op objecten die er echt staan, nooit op
windrichtingen — "aan de zuidwand" is op een strook van 130 x 26 tegels geen
informatie. Elke ruimtelijke bewering in deze tabel is nagerekend tegen
`data/objects.json`; staat er "naast de koelkast", dan staat het naast de
koelkast.

## Twee tickets op één object

`QuestEngine.tickets_at_anchor()` is de enige plek die een object naar
tickets vertaalt, en de resolver die "welke bedoel je?" vraagt bestaat nog
steeds (`TicketController._ticket_for_anchor()`): staan er op één anker twee
open tickets, dan vraagt het spel het; heb je er één gekozen op het bord, dan
wint die keuze en blijft de vraag uit. Het scrumbord in de gang
(`scrumbord_gang`) droeg ooit zo'n paar (BBD-202 en BBD-209), maar BBD-209 was
altijd al gated op `tickets_done: [t02]` — de vraag viel dus nooit echt. Sinds
BBD-209 naar het paardenkostuum verhuisde is er in de data geen gedeeld anker
meer over; de resolver blijft staan als vangnet. Danny en Daan bezitten allebei
twee tickets, dus dezelfde vraag kan nog wél bij een collega vallen
(`_ticket_waiting_for()`).

## Vakgebied en ophalen

Is het ticket jouw vakgebied, dan pak je het direct op. Zo niet, dan moet je
eerst de eigenaar opzoeken en aanspreken; die loopt met je mee tot het object.
`QuestEngine.requirements_met()` bewaakt dat, en de testsuite controleert per
personage dat een ticket buiten je vakgebied *niet* oplosbaar is zonder collega.

**Een collega ophalen ís het aannemen van de opdracht.** `handle_npc_talk()`
activeert het ticket en pint het, zodat het meteen in je inventaris zit, op het
bord landt en de doelregel erheen wijst. Zonder dat veranderde er niets
zichtbaars als je iemand meekreeg, en dan is het gesprek een gesprek in plaats
van een opdracht.

Wie er meeloopt staat permanent op de doelregel, op het bord en in de
interactieprompt — niet alleen in een toast van drie seconden.
`QuestEngine.helper_stand()` is de enige plek die dat bepaalt (EIGEN, NODIG, MEE,
GEWEEST); de HUD, het scrumbord en de hint lezen daar alle drie uit.

De vlag `helper_bij_<ticket>` wordt pas bij het object gezet, niet bij het
ophalen. Raak je je collega onderweg kwijt, dan kun je hem gewoon opnieuw
ophalen in plaats van het ticket zonder hem op te lossen.

De op te halen collega's staan op **vaste posten** tussen de twee tickets die ze
bezitten. Bij 16px is een bewegende NPC ruis en een geposteerde NPC een
landmark. Alleen Dennis patrouilleert de gang en Dirk loopt achter je aan — en
dat zijn precies de twee die je niet komt ophalen.

BBD-210 heeft bewust geen eigenaar: elk personage krijgt daar zijn eigen
variant van (zie CHARACTERS.md). Daarnaast vraagt hij de **deploysleutel** uit
de plantenkast, onder het speelgoedpaard.

## Vinden en kiezen

| Begrip | Waar het leeft | Wat het betekent |
|---|---|---|
| open | `available_when` in `data/tickets/` | mag gedaan worden; vier staan open vanaf de start |
| op slot | `available_when` klopt nog niet | bestaat, maar wacht op ander werk; `QuestEngine.locked_count()` |
| gevonden | `Session.discovered` | zit in je inventaris, want je bent in die ruimte geweest |
| gekozen | `Session.pinned_ticket` | jouw doel; stuurt doelregel, hint en wijzer |

`QuestEngine.discover_in_zone()` vult je inventaris bij het binnenlopen van een
ruimte. `next_hint_ticket()` is de enige plek die bepaalt waar het spel je
naartoe stuurt: je keuze, anders het eerste ticket dat je bij je hebt, anders
het eerste dat er nog ligt — zodat de hint je op verkenning stuurt in plaats
van te zwijgen.
