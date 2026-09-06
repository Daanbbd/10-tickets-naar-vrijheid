# Quest-audit — 10 Tickets naar Vrijheid

## 1 · Oordeel

De questmotor zelf is in uitstekende staat: de eerdere `AUDIT-TICKETSTROOM.md`
(2 sep) telde twaalf bevindingen, en op één "ontwerpvraag" (Q-10) en één
contentbeslissing (Q-08, inmiddels ook opgelost — zie §5) na zijn ze allemaal
zichtbaar gefixt, met het waarom in het commentaar erbij (`storingen.gd:180-196`,
`quest_engine.gd:44-52/206-222`). Wat overblijft is precies wat `docs/PLAN.md`
al vaststelde: **probleem D leeft nog** — 7 van de 9 vakgebied-tickets volgen
letterlijk fetch→recruit→minigame, en twee vondsten hieronder (de dode
`unlock_ticket` op BBD-201 en de nagenoeg-altijd-vroege ontgrendeling van
BBD-207) maken de ketendiagram in `QUESTS.md` optimistischer dan de praktijk.
De dag is qua *systeem* eerlijk chaotisch (16 storingen, 6 klantberichten, een
gegarandeerd overschreden budget), maar qua *beat* nog herhalend.

## 2 · Tickettabel (uit de data)

| Code | Vakgebied | Anchor/zone | available_when | Beat | world_changes | camera_focus |
|---|---|---|---|---|---|---|
| t01 BBD-201 | daan | vergadertafel / Summit | `{}` (open) | fetch→recruit→minigame (`mg_user_story`) | set_text whiteboard | ja, 1.4s |
| t02 BBD-202 | daan | tribune / Koffiecorner | `{}` (open) | fetch→recruit→minigame (`mg_planning`) | set_text scrumbord_gang | ja, 1.4s |
| t03 BBD-203 | willem | wachtbank / Entree | tickets_done:[t01] | **wereldhandeling** (`_wh_klantfeedback`, geen fail) | set_text, despawn klant | ja, 1.4s |
| t04 BBD-204 | victor | wandmonitor_vloer / Vloer | `{}` (open) | fetch→recruit→minigame (`mg_frontend_fix`) | set_text | ja, 1.4s |
| t05 BBD-205 | jonathan | serverrack_a / Patchhok | `{}` (open) | **wereldhandeling** (`_wh_backend`, geen fail) | set_text, set_modulate | ja, 1.4s |
| t06 BBD-206 | danny | dashboardmuur / Basecamp | tickets_done:[t05] | fetch→recruit→minigame (`mg_cro`) | set_text, set_modulate | ja, 1.4s |
| t07 BBD-207 | danny | speaker_koffiecorner / Koffiecorner | tickets_done:[t04] **of** klantbericht k1 (zie §4-H1) | fetch→recruit→minigame (`mg_abgevecht`) | set_text, set_ambience | ja, 1.4s |
| t08 BBD-208 | koen | hokje_ipad / Vergaderhokje | tickets_done:[t01] | fetch→recruit→minigame (`mg_video`) | set_text, spawn bezorger | ja (geen hold) |
| t09 BBD-209 | bastiaan | paardenkostuum / Vloer | tickets_done:[t02] | **wereldhandeling** (`_wh_paarden`, kán "niet af" maar niet falen); zoek_npc `paard_bug` | set_text, despawn 3 paardnpc's | ja (geen hold) |
| t10 BBD-210 | (iedereen) | deploycomputer / Birdhouse | min_tickets_done:8 + has_item deploysleutel | eigen-vakgebied-voor-iedereen; finale (75s klok) | set_text, set_locked voordeur | ja, 1.4s |

`docs/QUESTS.md` klopt woord-voor-woord met de data op ketendiagram, zone-namen,
minigame-id's, hints en world-changes-tabel — met twee uitzonderingen, zie
H1/H2 in §4. `docs/AUDIT-TICKETSTROOM.md`'s kernclaim ("negen `available_when: {}`,
geen enkele afhankelijkheid") is achterhaald: de keten bestaat nu wél en is
kind-zijdig (`available_when.tickets_done`), niet meer `unlocks`-only.

## 3 · Pacing (twee playthroughs, `--autoplay`)

Beide `--playthrough`-runs haalden 10/10, exitcode 0, geen "vastgelopen"/
"MISLUKT". `SPEELBEURT`-regels dragen geen kloktijd, dus dit is uit de
volgorde + `Urenstaat`-kosten (30 eigen / 60 collega incl. ophalen)
gereconstrueerd, niet uit letterlijke tijdstempels (zie §6).

| | danny | bastiaan |
|---|---|---|
| Duur (wall-clock, headless) | 176,5 s | 178,4 s |
| Eerste klantbericht (k1) | na ticket 1 | na ticket 1 |
| Klantberichten gemist | 0 van 6 | 0 van 6 |
| Eigen tickets (30 min) | t06, t07, t10 (3×) | t09, t10 (2×) |
| Rekenkundig minimum werktijd | 510 min (8u30) | 540 min (9u00) |
| Werkelijk gewerkt | 542 min → uit 18:14 | 572 min → uit 18:44 |
| Overschrijding budget (8u/480m) | +62 min | +92 min |

Elk personage heeft rekenkundig al een minimum van 510-540 min nodig (3
eigen+7 collega, of 2 eigen+8 collega, tickets), ruim boven het budget van 480
min — **het budget is per constructie niet haalbaar, voor alle zeven**. Beide
runs bevestigen dat: geen enkele order geeft "slack", de dag eindigt altijd
met minstens één ticket "na vijven" (ongetest). Geen lange stiltes zichtbaar:
storing_dennis (min_tickets_done:2) en k1 (na ticket 1) vallen allebei zeer
vroeg; de finale zelf is met een klok van 75s de kortste fase van de dag.
Zie `docs/audit-shots` (scratchpad `quest_danny.png`): het bord bevestigt na
laden "Nog 4 te vinden, 6 op slot." — Q-03 uit de vorige audit is dus echt
gefixt (was: "Alles gevonden" met 6 op slot en 0/10 op de teller).

## 4 · Bevindingen

### Hoog
**H1 · De t04→t07-keten is vanaf ticket 2 dood.** `data/klant_berichten.json`
k1 (`Gevolgen.DREMPELS[0]=1`, dus na het eerste opgeloste ticket, ongeacht
welk) heeft een onvoorwaardelijke `{"op":"unlock_ticket","ticket":"t07"}`.
`QuestEngine.unlock()` promoveert LOCKED→AVAILABLE zonder de `available_when`
opnieuw te toetsen. Omdat t04 zelf ook vanaf minuut één open staat, is de enige
situatie waarin de "echte" keten (t04 voor t07) nog telt: de speler lost als
állereerste ticket van de dag niet t04 op — en zodra hij zíjn eerste willekeurige
ticket oplevert, gaat t07 sowieso open. Effect op de speler: de suggestie in
`QUESTS.md`'s diagram ("BBD-204 → BBD-207") geldt in de praktijk voor
hooguit de eerste keuze van de dag, daarna is het cosmetisch.
Voorstel: noem dit expliciet in `QUESTS.md` ("k1 overrulet de keten na ticket 1"),
of gate k1's effect op `tickets_not_done:["t04"]`... nee, andersom: op
`when: tickets_done:["t04"]`-afwezigheid is al zo; voeg toe dat de vroege val
bewust is, of vertraag k1 naar drempel 2.

### Midden
**M1 · Dode `unlock_ticket` op t01.** `data/klant_berichten.json` k4
(drempel 6) bevat `{"op":"unlock_ticket","ticket":"t01"}`, maar
`data/tickets/t01.json:2` heeft `"available_when": {}` — t01 staat al vanaf
`initialise_tickets()` op AVAILABLE. `unlock()` (`quest_engine.gd:91-93`)
promoveert alleen als de staat nog LOCKED is, dus dit effect vuurt in élke
speelbeurt in het niets. `docs/QUESTS.md` zegt zelf zowel "BBD-201 open vanaf
het begin" (tabel) als "`unlock_ticket` ... gebruikt hem voor BBD-207 **en
BBD-201**" (proza) — die twee zinnen spreken elkaar tegen. Effect op de speler:
geen (t01 was toch al open), maar het is verwarrende dode data voor de
volgende persoon die de klantberichten aanpast. Voorstel: effect schrappen uit
k4, of de proza-zin in QUESTS.md corrigeren.

**M2 · 8/10-deploy heeft geen moment-van-keuze-waarschuwing.** `_wie()`
(`ticket_controller.gd:667-690`) en `_locked_hint()` (`:663-671`) leggen
messerscherp uit wát je nog mist (item of aantal tickets) zolang t10 nog
LOCKED/geblokkeerd is — sterk punt, zie §5. Maar zodra je wél 8/10 + sleutel
hebt en de finale start, komt er geen "je hebt nog 2 tickets open, doorzetten?"
— de enige feedback over de kosten (`Session.niet_af()` → bugs, tot 2) komt pas
op het eindscherm (`ending.gd:186-195`), 15-70 seconden later. Een speler die
toevallig bij 8/10 langs de deploycomputer loopt kan zo de dag beëindigen
zonder te beseffen dat dat *nu* gebeurt. Voorstel: één zin in `t10_offer` (of
de wat/waarom-kaart) die `Session.niet_af().size()` noemt vóór de klok start.

**M3 · `docs/GAME_DESIGN.md` noemt vier klant-drempels, het zijn er zes.**
"op 3, 5, 7 en 9 tickets" (GAME_DESIGN.md, sectie "De Klant is een
telefoonscherm") vs. `Gevolgen.DREMPELS := [1, 3, 5, 6, 7, 9]` en zes
berichten (k1..k6) in de data. Cosmetische documentatie-drift, geen
gedragsbug. Voorstel: tabel bijwerken naar de zes drempels.

### Laag
**L1 · `docs/PLAN.md`'s "4 storingen"-telling is achterhaald.**
`data/storingen.json` bevat nu 16 definities (2 `npc_komt_langs`, 8
`iets_gaat_stuk`, 6 `afleiding`), niet 4. Dit is een verbetering t.o.v. de
diagnose in PLAN.md §1, niet een nieuw gat — maar het betekent dat die
diagnoseparagraaf niet meer als actuele stand gelezen moet worden voor dit
onderdeel. Voorstel: bij de volgende PLAN-update dit getal corrigeren (of de
paragraaf markeren als "vóór de storingen-uitbreiding").

**L2 · `gevolg_paard_gemist` is voor zijn enige doelgroep onbereikbaar** (al
gedocumenteerd en bewust geaccepteerd in `gevolgen.gd:186-198`: de vlag kan
alléén true worden via Bastiaans eigen vakgebiedvoordeel, en `npc_layer.gd`
spawnt nooit een NPC voor je eigen personage, dus Bastiaan ziet zijn eigen
reactieregel op die vlag nooit). Geen actie nodig, alleen ter bevestiging dat
dit klopt met de code — geen nieuwe softlock.

## 5 · Wat goed is

- **Geen enkele bereikbare volgorde loopt vast.** `_test_geen_dood_punt()`
  (`test_runner.gd:1737`) doet een volledige BFS over alle 10! opbouwvolgordes
  en bewijst dat elk pad tot 10/10 komt; `_test_keten_is_bereikbaar_en_afgeleid()`
  (`:3762`) bewijst bovendien dat de keten volledig herafleidbaar is uit
  `done_order` alleen (save/load-veilig). Zelf nagerekend: geen van de 10
  tickets' `available_when` verwijst naar een niet-bestaand of zichzelf-ticket.
- **Eén enkele bron voor "wat nu, waar": doelregel (`hud.gd:1293`), hint/Q
  (`hud.gd:1293` idem), wijzer (`main.gd:257`) en kompasstrip (`main.gd:368`
  via dezelfde `_doel_node()`) lezen letterlijk allevier `QuestEngine.
  next_hint_ticket()`. Ze kunnen elkaar structureel niet tegenspreken — alleen
  het ticketbriefje (`ticket_badge.gd:73`, `preferred_at_anchor()`) toont iets
  anders (al het beschikbare werk op een anker), en dat is een bewust ander
  signaal ("hier ligt iets" vs. "dit is je doel"), geen contradictie.
- **Eigen-vakgebied-voordeel is consistent en gedekt.** `TraitModifier.VOORDEEL`
  dekt alle 9 mechaniek-types 1-op-1 met de 9 vakgebied-tickets; `_test_traits()`
  dwingt af dat een nieuwe mechaniek nooit stil zonder voordeel blijft.
  `npc_layer.gd:85/148` slaat consistent (één regel, geen per-personage-
  uitzondering) de NPC van je eigen personage over bij spawn — geverifieerd
  voor alle 7 speelbare personages via dezelfde `StringName`-vergelijking.
- **Alle 10 world_changes hebben een `camera_focus`**, dus élke oplossing is
  zichtbaar ongeacht waar de speler staat (bv. t09: paardenbug ergens op de
  vloer aanspreken, camera pant daarna naar de vergadertafel) — geen ticket
  verandert iets dat de speler kan missen.
- **Bijna alle bevindingen uit `AUDIT-TICKETSTROOM.md` (2 sep) zijn zichtbaar
  gefixt met het waarom in het commentaar**: de storing-race (Q-01, nu
  `_plan_evaluatie()` + `wachttijd_verstreken()`, `storingen.gd:177-196/238-268`),
  het voorgelezen dialoog-id (Q-02, nu `_play_or_line()` overal,
  `ticket_controller.gd:110-126`), de onzichtbare keten (Q-03, bevestigd via
  screenshot: "Nog 4 te vinden, 6 op slot"), de `_never_`-sentinel (Q-05/Q-07,
  verdwenen — keten zit nu op het kind), dubbele beloning bij heropening (Q-06,
  `Session.beloond`-wacht in `quest_engine.gd:219-222`), de dode
  ticketbeloningen (Q-08, nu gelezen in `data/dialogue/wereld.json` als
  wereld-flavor), en de losse `alle_tickets_klaar`-vlag (Q-09, reset in
  `reopen()`, `quest_engine.gd:115-116`).

## 6 · Niet geverifieerd

- **Exacte kloktijd per ticket.** `[SPEELBEURT]`-regels dragen geen tijdstempel;
  een live `Monitor` met tijdstempel-prefix faalde op macOS' `awk` (geen
  `strftime`, one-true-awk). De tijdlijn in §3 is terugberekend uit
  `Urenstaat`-kosten + de eindregel, niet rechtstreeks gelogd.
- **Welke van de 16 storingen daadwerkelijk afgingen in de twee playthroughs**
  — `storingen.gd` print niets naar stdout, dus dat is uit de code (triggers)
  afgeleid, niet uit de logs waargenomen.
- **Mobiel/touch-gedrag van de gidslaag** — niet getest binnen deze audit
  (headless); `docs/PLAN.md` noemt dit zelf al als open ("Daan zelf moet
  spelen op een echte telefoon").
- De exacte gebruikerservaring van de M2-vondst (verrast door een vroege
  deploy) is een aanname op basis van de UI-tekst, niet in een handmatige
  speelsessie waargenomen.
