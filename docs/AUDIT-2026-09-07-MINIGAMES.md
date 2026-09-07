# Audit minigames — 7 september 2026

Negen parallelle audits (acht spelbare minigames plus de gedeelde laag), getoetst
aan de party-genre-rubriek van `godot-master` en aan `docs/MINIGAMES.md`. Statisch:
niets gedraaid, niets gewijzigd. Elke bevinding hieronder is in de code
nagekeken; de rekenclaims zijn nagerekend en dat staat er per geval bij.

Het spel is single-player, dus de multiplayer-helft van de party-rubriek
(split-screen, joypad-routing, 1v3-balans) is niet van toepassing en is
overgeslagen. Wat overblijft is precies wat hier knelt: tutorial-lengte,
leesbaarheid onder druk, feedback per handeling, consistente besturing,
handicap/toegankelijkheid en de scheiding tussen minigame en wereldstaat.

## Verdict

De mechanieken zijn goed. Elf werkwoorden voor elf tickets is echt doorgevoerd,
en zeven van de negen doorstaan de grijze-blokken-toets uit `MINIGAMES.md`.

Waar het misgaat is niet de mechaniek maar de laag eromheen. Drie dingen komen
in vrijwel elke audit terug:

1. **Er is geen feedback per handeling.** Alle vijf `Juice.schok()`-aanroepen in
   de minigame-laag zijn no-ops voor de speler, en `Haptiek` wordt in negen
   minigames nul keer aangeroepen. Wat er gebeurde staat in een tekstregel.
2. **De klok loopt op momenten dat de speler niet kan spelen** — onder de
   uitleg-overlay, met de app in de achtergrond, en door nadat de uitkomst
   al vaststaat.
3. **Drie van de acht minigames hebben geen echte opgave**: er is een route die
   goedkoper is dan de bedoelde (blind cyclen in de finale), of maar één
   winnende lijn (A tegen B), of geen druk (de renderpijplijn).

Vier faalpaden zijn regelrechte bugs waar een speler winst door verliest.

---

## Deel 1 — Fix één keer, werkt voor alle negen

Dit is het waardevolste deel. Elk punt hieronder wordt anders acht keer los
gerepareerd.

### C1 [P1] ESC tijdens de uitslagbanner maakt van een gewonnen ticket een ABORT

`scripts/minigames/minigame_base.gd:466-475`. `finish_with_banner()` zet alle
knoppen uit (regel 437) maar `_unhandled_input()` kent geen "uitslag staat vast".
Een `cancel` in de 1,6-1,9 s bannertijd roept `abort()` aan → `_finish(ABORT)`
zet `_done = true` → de `succeed()` op regel 461 is een no-op. Shell krijgt
ABORT en het ticket blijft ACTIVE (`ticket_controller.gd:285`). De speler heeft
gewonnen en verliest het ticket.

**Fix:** `var _uitslag_vast := false`; zetten in `finish_with_banner()` direct na
de `_done`-check; in `_unhandled_input()` vóór de cancel-tak `if _uitslag_vast: return`.
Raakt alle negen minigames in één wijziging.

### C2 [P1] Zeven klokken lopen door terwijl de app in de achtergrond staat

`shell.gd:348` zet `mg.process_mode = PROCESS_MODE_ALWAYS`; `_naar_achtergrond()`
(`shell.gd:119-121`) pauzeert alleen de tree en zet `Engine.max_fps = 1`. Een node
met `PROCESS_MODE_ALWAYS` krijgt `_process()` dus nog steeds, met delta ≈ 1 s.
**Nagerekend over de hele laag: zeven minigames hebben een `_process`-klok en
geen van de twaalf scripts in `scripts/minigames/` controleert `get_tree().paused`.**
Wie op de telefoon een appje beantwoordt, komt terug op een verloren ticket.

Bijkomend: het commentaar op `mg_oplevering.gd:932-936` beweert het tegendeel en
is dus onjuist.

**Fix:** `func klok_mag_lopen() -> bool: return not get_tree().paused` in
`MinigameBase`, en die in de zeven `_process`-guards gebruiken.

### C3 [P1] De uitleg-overlay ligt over een lopende klok

`minigame_base.gd:190-220`, zichtduur 2,5-6 s. Bij een herkansing (en altijd
onder `--autoplay`) verschijnt de overlay terwijl `_process()` van de minigame
al loopt. Geen enkele minigame weet dat de overlay bestaat — grep op
`_intro_overlay` in `mg_*.gd` geeft nul treffers.

Het duurste geval is A tegen B: `keuze_sec` is 7 s en de overlay eet er tot 6 van
op. Dat is exact playtest 2026-09-06 #28: *"stond de uitleg weer in beeld, liep de
timer al … Te laat. De zwakste klap valt."* De speler die het al één keer niet
haalde, verliest ronde 1 van zijn herkansing aan het kaartje dat hem moest helpen.

**Fix:** in `_bouw_intro_overlay()` `set_process(false)`, in `_weg_intro_overlay()`
weer aan. Dan hoeft geen enkele minigame van de overlay te weten.

### C4 [P1] Er is geen feedback per handeling in de hele laag

Twee bevindingen die elkaar versterken:

- **`Juice.schok()` is onzichtbaar.** `juice.gd:29` schokt de node in groep
  `game_camera` (`world/game_camera.gd:58`). De minigame ligt op `MinigameLayer`,
  een `CanvasLayer` (`shell.tscn:9`), met een dekkend `SCHERM_NACHT`-frame tot 4 px
  van de rand (`minigame_base.gd:116-121`). Een CanvasLayer beweegt niet mee met
  een Camera2D. **Alle vijf aanroepen** (`minigame_base.gd:443`, `mg_abgevecht.gd:294`,
  `mg_heatmap.gd:380`, `mg_oplevering.gd:371` en `:777`) schokken dus een wereld
  die de speler niet ziet.
- **`Haptiek` wordt nul keer aangeroepen** in de negen minigames; de enige twee
  aanroepen staan in de basis (banner en storing).

Gevolg: geen enkele handeling in geen enkele minigame heeft een voelbare of
ruimtelijke terugkoppeling. Raak en mis klinken vaak ook hetzelfde
(`mg_standup.gd:422` speelt `klik` voor beide gevallen).

Bonus-inconsistentie: `mg_heatmap.gd:380` gebruikt schok als **succes**-signaal,
terwijl `minigame_base.gd:443` het als **verlies**-signaal gebruikt.

**Fix:** een `impact(sterkte)`-helper in de basis die tweent op `_kolom.position`
(±2 px, binnen het paneel, dus zichtbaar) plus `Haptiek.tril()`. Vervang de vijf
`Juice.schok`-aanroepen daardoor, en splits raak/mis-geluid overal waar dat nu
gedeeld is.

### C5 [P2] Twee minigames schrijven in Session, tegen het contract in

`minigame_base.gd:6-7` en `docs/ARCHITECTURE.md:162-164`: een minigame mag Session
lezen, nooit schrijven. Overtreders: `mg_abgevecht.gd:392` en `mg_oplevering.gd:769`,
beide `Session.add_counter(...)` op het moment van falen, vóór `finished`.

Gevolg: `--minigame=mg_deploy` en de testsuite muteren nu wereldstaat, en het
contract is niet meer dan een docstring.

**Fix:** de teller ophogen in de FAIL-tak van `TicketController`
(`ticket_controller.gd:266-283`), generiek als `<id>_pogingen`, en terug naar de
minigame via `cfg("pogingen")`. Plus een greptest op
`Session\.(add_|set_|book_)` in `mg_*.gd`, zodat het contract afdwingbaar wordt.

### C6 [P2] Vijf klokformaten, twee balken, twee minigames zonder klok

`bouw_klokbalk()`/`zet_klokbalk()` bestaat in de basis (`minigame_base.gd:309-347`)
maar wordt door 3 van de 8 gebruikt. De rest doet het zelf: `"%d sec · nog %dx"`,
`"Dennis wacht · %d s"`, `"%d cr · %d s · %d/%d"`, een eigen `m:ss`-label met eigen
balk (`mg_oplevering.gd:266`), en twee minigames zonder zichtbare klok terwijl ze
wél een tijdsdruk hebben (uitlijnen, heatmap — playtest #13: *"Ik mis ook urgentie
als speler hier"*).

**Fix:** `start_klok()` / `klok_tik(delta)` / `signal klok_om` in de basis, met één
tijdformaat rechts in de statusregel. Links inhoud, rechts tijd, altijd.

### C7 [P2] Er is geen enkele handicap-knop

De party-rubriek eist een optioneel handicapsysteem. Er is er geen, en het
tijdbudget staat onder **zeven verschillende JSON-namen**: `klok_sec`, `tijd`,
`drift_sec`, `ronde_sec`, `keuze_sec`, `klok_seconden`, `duur`. Een "rustig
tempo"-instelling is daardoor acht losse wijzigingen.

**Fix:** `MinigameBase.tijd(basis) -> basis * Instellingen.tempo` (1.0 / 1.5), en
elke minigame leest zijn tijdsleutel daardoor. Eén instelling in het pauzemenu.

### C8 [P3] `qa_solve()` slaagt stil als je hem vergeet

`minigame_base.gd:31-34` doet standaard `succeed(100)`. Alle negen overschrijven
hem vandaag, dus er is nu geen gat — maar de tiende minigame die het vergeet haalt
in elke geautomatiseerde beurt 100 punten. Dat is precies de val waardoor groen
eerder al betekenisloos werd.

**Fix:** standaard `push_error(...)` + `fail(...)`, plus een assert in de
testlus dat elk minigame-script `qa_solve` daadwerkelijk overschrijft.

### C9 [P3] Zes eigen `_exit_tree`'s, geen enkele roept `super()` aan

`mg_abgevecht.gd:99`, `mg_heatmap.gd:478`, `mg_oplevering.gd:941`, `mg_scope.gd:403`,
`mg_standup.gd:537`, `mg_uitlijnen.gd:468` — alle zes overschrijven de basis zonder
`super()`, dus de kill van `_intro_tween` draait niet. Praktisch onschadelijk
(node-gebonden tweens sterven mee), maar het is zes keer hetzelfde huiswerk en de
vastloper-les moet elke minigame apart onthouden.

**Fix:** `maak_tween()` in de basis die registreert en in `_exit_tree()` alles
killt, met de regel *nooit `await tw.finished`* in de docstring. De zes eigen
kill-lijstjes kunnen dan weg.

### C10 [P3] Focus: vijf keer FOCUS_NONE, drie keer grab_focus, acht keer anders

`minigame_base.gd:164` (Stoppen), `mg_pijplijn.gd:109`, `mg_oplevering.gd:233` en
`:323`, `mg_uitlijnen.gd:367`, `mg_standup.gd:155` zetten focus uit; `mg_slotboard.gd:44`
en `mg_abgevecht.gd:251`/`:310` doen het goed. In vier minigames is met toetsenbord
of gamepad geen hoofdknop te bereiken, en dit is een web-export die ook op desktop
draait. In scope en uitlijnen is Tab+Enter zelfs een gegarandeerde nederlaag: de
enige focusbare knop is Klaar/Vastleggen met een leeg veld.

**Fix:** `_focus_eerste_knop()` in de basis na `_on_setup()`; de vijf FOCUS_NONE-regels
weg. Stoppen mag FOCUS_NONE blijven zolang Escape werkt (zie C1).

### C11 [P3] De scene wordt geladen op de tik waarna de klok start

`shell.gd:336` doet `load(path)` ná het uitlegkaartje (regels 323-334). Eerlijk
gewogen is de winst klein — de `.tscn`'s zijn ~330 bytes en web-export heeft
`thread_support=false`, dus `load_threaded_request` levert daar geen echte thread —
maar het *moment* is verkeerd: de GDScript-compile van 147-976 regels valt nu
precies op de tik waarna de klok begint te tikken.

**Fix:** regel 336 verplaatsen naar vóór regel 323. Threaded loading is hier
ceremonie; het verplaatsen kost één regel.

### C12 [P3] Catalogus: blijf bij JSON, maar maak het één bron

De party-rubriek wil `.tres`-`MinigameData`. **Afgewogen en met reden afgewezen:**
de typering zit nu in tests die per `type` strenger zijn dan een Resource-klasse
zou zijn, en drie Python-tools lezen de JSON. Wat wél wringt is dat
`minigames.json` en `minigame_content.json` dezelfde sleutelset hebben en uit
elkaar kunnen lopen — en dat is al gebeurd: `mg_paarden` staat nog in de catalogus
terwijl t09 een wereldhandeling is, dus `mg_whack` wordt meegetoetst als spelbare
minigame en heeft geen `klaar_als`.

**Fix:** `scene` en `title` als velden in `minigame_content.json`, `minigames.json`
weg, `GameData.minigames` als afgeleide view. Plus: hernoem de catalogusregel naar
`mg_qa_fixture` en voeg een test toe dat elk catalogus-id een ticket heeft.

---

## Deel 2 — Per minigame

### t01 · Scope bepalen (`mg_scope.gd`)

- **[P1] Na "Vastleggen" blijven de wensen tikbaar.** `minigame_base.gd:437` zet
  alleen `Button`s uit, maar `WensRij` is een `PanelContainer` (`mg_scope.gd:65`).
  Tijdens de banner is `_done` nog false: een tik verplaatst een wens, `_werk_bij()`
  zet `_vastleg.disabled` terug op false, en een tweede druk levert een tweede
  banner en tweede confetti. De eerste timer wint, dus **`Gevolgen` boekt een andere
  uitslag dan de speler op het scherm ziet.** Fix: een `_afgerond`-vlag, gezet in
  `_vastleggen()` en `_tijd_op()`, gecheckt in `_op_tik()`.
- **[P1] Bij het openen is niets aanwijsbaar tikbaar.** Playtest #35: *"wtf"*,
  *"erg vage minigame"* — van de eigenaar van het ticket, die wist wat hij moest doen.
  Negen verschoten briefjes zonder knop-affordance, en de klok loopt al. Uitlijnen
  en heatmap pulseren hun eerste doel; scope niet. Fix: `puls_rand()` op de eerste
  rij, en de klok pas starten na de eerste tik of na 3 s inloop.
- **[P2] "Dennis wacht" noemt iemand die in dit ticket niet voorkomt.** Dennis
  spreekt pas in t02. Dit is dezelfde fout als #35c/#35d ("ZIJ wacht — wie is zij?"),
  die voor de lege-lijstregel al gefixt is maar in de klokregel en de uitslagteksten
  nog staat.
- **[P2] Geen feedback op het moment dat een grens overschreden wordt.** De tik die
  de sprint over capaciteit duwt klinkt identiek aan elke andere tik; het moment
  dat `blij` de drempel haalt — het eigenlijke doel — heeft nul geluid.

**Het ene ding:** geef de speler drie seconden voordat Dennis begint te tellen, en
pulseer het eerste briefje. Alles wat de playtest "vaag" noemde zit in de eerste
seconden, niet in de mechaniek.

### t02 · De stand-up (`mg_standup.gd`)

- **[P1] De uitslag ligt vast maar de ronde loopt door.** `_uitslag` wordt alleen
  gezet op klok-nul of laatste spreker. Staat de balk al op 2/2, of zijn de ingrepen
  op en past de rest niet meer in de klok, dan zit de speler het uit. Dit is letterlijk
  playtest #20: *"de rest van de minigame zit ik passief te wachten en te hopen."*
  Voor het gemist-geval bestaat de directe stop wél (`:424-433`) — dat patroon
  uitbreiden.
- **[P1] De bonus "stand-up met adem over" is onbereikbaar.** **Nagerekend:** 45 s
  spreektijd, klok 30 s, drie ingrepen. De beste route kapt Dennis (10), Koen (7)
  en Willem (6) en houdt Victor 3 + Jonathan 9 + Bastiaan 5 + Danny 5 = **22 s**,
  dus `tijd_over` haalt met de fade-overhead nooit de 8,0 s die `gevolgen.gd:286`
  eist. Met de fix hierboven valt het einde op ≈17,8 s en werkt de drempel;
  anders 8,0 → 5,0.
- **[P1] Spreekduur is onzichtbaar, dus wie je afkapt is gokken.** De speler kan
  alles inhoudelijk goed doen en toch falen. Fix: een tempobalk van 2 px onder de
  naam. Binnen één seconde zie je dat Victors balk rent en die van Dennis kruipt —
  dat is precies de informatie die het afkapbesluit nodig heeft, zonder tekst.
- **[P2] Bij een herkansing dekt de doelherinnering 6 s de kaart** terwijl Dennis
  (de waardevolste afkap) al praat. Zie C3.
- **[P2] Stoppen ligt 3 px onder Afkappen** en roept `abort()` aan zonder bevestiging,
  in een tik-onder-tijdsdruk-spel.
- **[P2] Danny's "verborgen" belang heeft geen tand.** Met `nuttige_regel: 0` staat
  zijn segment groen zodra zijn kaart verschijnt; hem afkappen kan nooit te vroeg
  zijn. De enige echte val is Jonathans eerste 3 s, en die wijst de intro aan. Data-fix:
  verwissel Danny's regel 0 en 1 en zet `nuttige_regel: 1`.

### t04 · Uitlijnen (`mg_uitlijnen.gd`)

- **[P1] `perfect` — Victors enige gevolg — is alleen haalbaar binnen 8 seconden.**
  **Geverifieerd:** drift telt `±1` px op bij `start` (`:571`/`:575`) terwijl de
  speler alleen in rasterstappen van 4 beweegt, dus `rest` kan na één drift nooit
  meer 0 zijn. En omdat een blok met rest 1 daarna als `vast` geldt (tolerantie 2),
  wordt het niet nóg eens gedreven. `docs/MINIGAMES.md:235` beweert het omgekeerde.
  Fix: `blok.start.x += richting * float(_raster)`. Dat lost drie dingen in één
  wijziging op — zie hieronder.
- **[P1] De drift is onvoelbaar.** Eén pixel, geen geluid, geen aftelbalk; alleen
  een schud van 2 px en een statusregel. Playtest #13: *"Geen zichtbare timer of
  urgentie-indicator."* De druk die op 5 sep gebouwd is, bereikt de speler niet.
  Met de rasterfix is de drift 4 px en dus zichtbaar.
- **[P2] Victors traitvoordeel verandert niets merkbaars.** +1 tolerantie telt
  alleen als een blok exact 3× op dezelfde as gedreven is — bij ≥24 s stilstand én
  geluk. `MINIGAMES.md:113`: *"een voordeel dat je niet ziet bestaat niet."* Fix:
  geef Victor langzamere drift (`drift_sec + 4`) in plaats van tolerantie.
- **[P2] Het 5/5-moment ziet er hetzelfde uit als 1/5.** In een precisiespel is
  "alles zit" de climax; nu is het een tekstverschil.
- **[P2] Klaar op 4/5 faalt zonder aan te wijzen welk blok scheef staat** — en na
  een drift van 1-3 px ziet dat blok uitgelijnd uit.
- **[P3] Drift kan een blok buiten het vel duwen** (`_klem()` klemt alleen
  spelerstappen; prijs kan naar x = −6 onder een `clip_contents`-kader).

**Het ene ding:** drift in rasterstappen, met een leeglopende klokbalk en een
geluid. Dat lost de urgentie, de onbereikbare `perfect` én de plek voor Victors
voordeel in één keer op.

### t06 · Waar klikken ze? (`mg_heatmap.gd`)

*Correctie op mijn eigen briefing: ik meldde deze agent dat `failure` ontbrak in
`mg_cro`. Dat was een artefact van mijn eigen uitlezing — de sleutel bestaat wel.
De agent heeft dat nagekeken en teruggeduwd.*

- **[P1] Je ziet tijdens het slepen niet of de knop "telt".** De 40%-overlapregel
  (`RAAK_DEEL 0.4`) is onzichtbaar; een knop half op de foto en half op de prijs
  geeft geen enkel signaal, en de speler hoort pas na de klok "mis". Dit is de plek
  waar je faalt zonder te begrijpen waarom. Het hitte lezen is de opgave; de knop
  neerleggen mag geen tweede, verborgen puzzel zijn.
- **[P2] Danny's regel is 1,4 s zichtbaar en wordt dan gewist.** 50 tekens in 1,4 s,
  terwijl de basis zelf op 16 tekens/s rekent (dus 3,1 s). De enige uitleg van
  *waarom* het raak of mis was, is niet te lezen.
- **[P2] Dode tijd:** de ronde eindigt alleen op de klok, dus wie na 3 s ziet waar
  ze klikken wacht 6 s. Drie rondes plus pauzes is ~34 s vast, ongeacht vaardigheid.
- **[P2] Schok bij succes** (`:380`), terwijl de basis schok als verlies gebruikt —
  en beide zijn onzichtbaar, zie C4.
- **[P3] Eigen rondeklok** naast de gedeelde `bouw_klokbalk()`, met eigen
  kleurdrempels; zie C6.
- **[P3] Dubbele tik op touch:** één vinger levert een ScreenTouch én een MouseButton,
  beide bereiken `_op_aanraking`, dus twee keer klikgeluid.

### t07 · A tegen B (`mg_abgevecht.gd`)

- **[P1] De keuzeklok loopt al onder de overlay** — het duurste geval van C3, tot
  6 van 7 s van ronde 1.
- **[P1] Er is precies één winnende lijn en A kan niet vallen.** **Nagerekend over
  alle 27 combinaties: 1 van 27 wint** (35+40+35 = 110 ≥ 100). Elke afwijking
  verliest. De maximale tegenklap is 65 < 100, dus `_hp_a > 0.0` is altijd waar en
  **de tegenklap beslist nooit iets** — terwijl de intro juist een afweging belooft
  ("kost A ook wat"). Eén timeout = verloren gevecht, en dat gevecht loopt dan nog
  twee rondes door met groene blokjes. `Gevolgen` mapt `hp_a_over` naar
  `ab_hp_a_over`, maar niets leest die sleutel.
  Fix: `hp_b` naar 90 (dan winnen drie lijnen en overleeft één zwakke ronde), plus
  een vroege stop als B buiten bereik is, plus `ab_hp_a_over` een lezer geven of de
  mapping schrappen.
- **[P2] Een treffer is niet te zien en niet te voelen** — zie C4. Beide balken
  bewegen ook tegelijk in 0,5 s, dus schade en tegenklap zijn als gebeurtenis niet
  te onderscheiden, en A's balk flitst niet bij een tegenklap.
  `docs/AUDIT-2026-09-05.md:324` belooft "de HP-balk schokt bij een treffer"; dat
  gebeurt niet.
- **[P2] Drie labels tot 55 tekens lezen in 7 s** op 10 px, terwijl de code om de
  tegenklap als getal op de knop te zetten al bestaat maar uitstaat
  (`toon_tegenklap` wordt nooit gezet). Eén regel JSON zet die aan.
- **[P2] De groene verloopblokjes liegen:** "Niets. Laten staan" (15/0) kleurt
  groen (+15) maar is een verliezende klap.
- **[P2] Danny's commentaar verdwijnt bij een timeout** als workaround voor een
  layout-vastloper; precies in het geval waarin de speler uitleg nodig heeft. De
  heatmap zet hetzelfde label in `chrome_footer()` en heeft dat probleem niet.

**Goed nieuws:** dit script is *niet* meer gevoelig voor de gekillde-Tween-vastloper.
`_meet()` polt op `is_running()` in plaats van `await tween.finished` (`:340`), en
`_test_geen_await_op_killbare_tween()` bewaakt dat projectbreed.

**Het ene ding:** maak de klap voelbaar en laat de balans de afweging waarmaken
die de intro belooft. Nu is het een quiz met twee balkjes die zich een gevecht noemt.

### t08 · De renderpijplijn (`mg_pijplijn.gd`)

- **[P1] De doorstroomdruk bestaat niet.** **Geverifieerd in de data:** Publish
  heeft `capaciteit 9, duur 0, kost 0` voor zes clips — die stage kan per definitie
  niet blokkeren. Credits verbranden dus alleen als een rijpe clip *niet* wordt
  aangetikt, en er is nooit een reden dat niet meteen te doen. Het werkwoord
  "doorstroom onder druk" is er niet; de opgave is "tik het rode blokje".
  Doorgerekend heeft de klok 3,5× marge, en beide faalstaten vereisen dat de speler
  wegloopt. Gevolg: `Gevolgen`-drempels op `credits_over < 25` en `>= 60` hebben in
  de praktijk nul variantie.
  Fix: `stages[2]` naar `capaciteit 1, duur 3.0`, en een rijpe Publish-clip de
  pijplijn laten verlaten. Dan wordt het het enige spel waar je iets bewust *niet*
  moet doen (de tweede Render-plek even leeg laten).
- **[P1] De time-out toont de credits-tekst.** **Geverifieerd:** `failure`
  ("De credits zijn op…") staat op de tijd-op-tak (`:289`), terwijl de credits-tak
  het kale `credits_op` ("Credits op.") krijgt. Een speler die de klok laat
  verlopen krijgt letterlijk de verkeerde verklaring. Fix: sleutel `tijd_op`
  toevoegen en de twee takken omwisselen.
- **[P2] Credits en klok zijn alleen een getal** in een kleine statusregel die per
  hele eenheid springt; zie C6.
- **[P2] Verbranden is stil:** de enige pijnlijke gebeurtenis heeft geen geluid en
  geen trilling. Het fout-geluid klinkt wél bij een volle stage — die nooit voorkomt.
- **[P2] Koens voordeel is onmerkbaar:** +20 credits is 3,3 s aarzelen op een
  budget dat in de praktijk niet slinkt en dat nergens als meter staat.
- **[P2] De primaire blauwe knop staat in de scrollende body** (tegen het contract
  in `MINIGAMES.md:191-193`) en is door de auto-intake van 1,2 s alleen in de eerste
  seconde zinvol. Hij trekt het oog naar de verkeerde plek.
- **[P2] De rijp-puls is vermoedelijk onzichtbaar** op de lichte blokjes: `modulate`
  boven 1,0 clampt, en PANEL is al `#f3f3f3`. Pulseren naar donker in plaats van licht.

### t10 · De oplevering — de finale (`mg_oplevering.gd` + `brandjes_model.gd`)

De belangrijkste minigame van het spel, en de zwakste balans. Geen enkele
playtest-observatie: de sessie van 6 sep liep vast bij 4/10 tickets.

- **[P1] Blind door de zeven knoppen cyclen is gratis en haalt de perfecte score.**
  Een misser kost alleen 0,4 s knoppenslot (`blus()` verandert niets bij een misser),
  en `blus()` pakt élk zichtbaar brandje dat die handeling vraagt. Doorgerekend met
  een replica van het model over vijf zaden: **159 missers per avond en op alle vijf
  zaden dezelfde score als perfect spel.** Het commentaar op `:56` ("blind rammen
  onaantrekkelijk maken") wordt door de getallen niet gedragen.
- **[P1] "Hoogstens drie tegelijk" gebeurt nooit.** **Nagerekend:** de curve
  `[[0,9],[25,7],[50,5]]` geeft 12 spawnmomenten in 75 s (de laatste exact op de
  klokgrens), tegen brandjes die 6-10 s duren. Bij normaal spel staat er **maximaal
  één** kaartje; twee van de drie slots blijven de hele avond leeg, en van de 14
  brandjes in de lijst komen er minstens twee nooit in beeld. De statusregel
  "3 brandjes tegelijk" kán niet voorkomen. De hele P5-belofte
  (*"nu schreeuwt alles tegelijk"*) is niet waar: de finale speelt als een trage
  reactietest.
- **[P1] Blussen is netto winst, dus méér brandjes = hógere score.** Zes van zeven
  keuzes hebben een positief effect. Nu gecapt door de spawns; zodra de curve
  dichter wordt scoort de rampdag met perfect spel 19-22 en de zorgvuldige dag
  16-18 — **de slechtste dag wint**, en "de dag zaait de avond" staat op zijn kop.
  Fix: maak blussen "de straf vermeden" (keuze-effecten op `{}`) en laat de score
  door start plus verloop dragen. Dan zijn curve en rij vrij te tunen. Deze drie
  bevindingen horen samen gefixt te worden.
- **[P2] Fase 3 leeft buiten het model en de kalibratietest rekent haar niet mee.**
  `_herstel_handeling` muteert `_model` rechtstreeks en dupliceert de onthul-logica
  van `blus()`. De QA-route levert +3 die de test niet ziet: op zaad 1234 haalt een
  rampdag daardoor precies VLEKKELOOS, wat de test juist verbiedt. "Who owns what"
  is hier gebroken: het model bezit de toestand, de scene muteert hem.
- **[P2] Onder druk zijn de kaartjes niet te onderscheiden en de knoplabels sluiten
  niet aan op de kaarttekst.** De echte handleiding is de mapping van 14 teksten op
  7 werkwoorden, en die leer je alleen door te missen — een misser zegt
  "Niets brandt daar." en niet wat wél brandt. Concreet fout: `informeren.label` is
  "Klant mailen" terwijl het brandje "Dennis: statusje?" is, en Dennis is
  scrummaster, geen klant.
- **[P2] `_storing()` kan het model voorgoed pauzeren:** `gepauzeerd = true` op
  `:563`, en de early return op `:590` zet hem niet terug. Vandaag onbereikbaar,
  maar het is exact de vastloperfamilie — een pad dat `gepauzeerd` laat staan is een
  klok die nooit op nul komt. Bijkomend: wereldstoringen komen via een ander pad
  binnen (`MinigameBase.storing()`) en pauzeren het model niet.
- **[P2] Twee faalschermen op rij met dezelfde foutcode**, en fase 2 faalt ook na
  perfect spel — dus de speler leert dat de console niets met zijn spel te maken heeft.
- **[P3] Em-dash in spelertekst** (`:759`), buiten het bereik van de stijltest die
  alleen JSON scant.

**Het ene ding:** laat de brandjes echt stapelen én maak blussen "schade vermijden"
in plaats van "punten pakken". Pas dan is "blussen wat tegelijk brandt" wat de
speler doet, en pas dan kan iemand aan `spawn_curve` draaien zonder de balans te breken.

### De urenstaat (`mg_slotboard.gd`)

De eerlijke conclusie: **wat er na de omslag over is, is geen minigame en ook geen
formulier — het is een dialoogkeuze met drie knoppen in minigame-chrome.** Het
script zegt dat zelf (`:8-9`). Grijze-blokken-toets: drie gestapelde knoppen boven
een tekstregel is exact `DialogueBox.show_choices()`, met dezelfde `UiKit.keuzeknop`.

- **[P1] Een ingediend formulier krijgt confetti, dimmer, GELUKT-trilling en twee
  keer `ticket_klaar`** (de basis én `ticket_controller.gd:767`). Dirk keurt niets
  af en er is niets gewonnen. Confetti op een urenstaat vertelt de speler dat hij
  iets gepresteerd heeft, en dat ondergraaft precies de droge toon die Dirk hoort te
  hebben. Elke speelbeurt.
- **[P1] De drie keuzes tonen geen enkel getal.** `_verdeling()` rekent per optie
  exact uit hoeveel er op de tickets en op overig komt — en dat gaat alleen naar de
  payload. `Session.worked_minutes` komt nergens voor. **De grap uit
  `MINIGAMES.md:394` (te veel uren voor te weinig werk) staat dus nergens op het
  scherm.** Fix: regels met tickets en de drie vaste posten, "Gewerkt 4u15 · Te
  boeken 8u00" erboven, en een tik die de uurvakken vult in Dirks notatie. De
  rekenkern bestaat al; het is presentatie.
- **[P2] Dirks regel "er staan nog {aantal} tickets op nul" kan nooit vallen.**
  **Nagerekend:** `_verdeel(n, budget)` geeft `basis = budget / n`, dus een 0
  vereist meer dan 480 tickets. Met tien tickets is `lege_tickets` altijd 0 in alle
  drie de takken. Eén van Dirks vier slotregels is dode data — en het is zijn beste
  regel. Er staat wel een test op, maar die toetst zijn tics, niet zijn
  bereikbaarheid.
- **[P2] Alle drie de opties leveren hetzelfde op.** `geboekt_min = 480`, dezelfde
  vlag, en niets in `Gevolgen` leest `keuze`, `op_rest` of `lege_tickets`. "Geen
  goed antwoord" is de bedoeling; "geen verschil" is iets anders. Dit is nu de enige
  plek in het spel waar een keuze werkelijk niets doet — terwijl de wereldhandelingen
  op 5 sep juist een prijs kregen.
- **[P2] Het uitlegkaartje met "Starten" staat er nog** voor een formulier, en
  vertelt de clou twee keer voordat de speler iets gedaan heeft. `MINIGAMES.md:371`
  en de M7-bevinding van de eigen audit spreken elkaar hier tegen.

**Wat hier goed is en met rust gelaten moet worden:** de toetsenbordkant is de beste
van alle minigames, en het boeken zit correct in de TicketController.

---

## Deel 3 — Twee dingen die alleen zichtbaar worden als je alles naast elkaar legt

### De klok wordt richting het eind langer in plaats van korter

| # | Ticket | Mechaniek | Klok |
|---|---|---|---|
| 1 | t01 | Scope | 45 s |
| 2 | t02 | Stand-up | 30 s |
| 3 | t03 | Klantfeedback | 3 × 8 s |
| 4 | t04 | Uitlijnen | geen klok, drift 8 s |
| 5 | t05 | Backend | geen klok |
| 6 | t06 | Heatmap | 3 × 9 s |
| 7 | t07 | A tegen B | 3 × 7 s |
| 8 | t08 | Renderpijplijn | 60 s |
| 9 | t09 | Paardenbugs | 60 s |
| 10 | t10 | Oplevering (finale) | 75 s |

De drie langste klokken staan achter elkaar aan het slot (60-60-75), tegen 3×7 s in
het midden. En de drie rondegebaseerde spellen zitten op elkaar geplakt in t03, t06
en t07. Los van de finale-balans hierboven: het tempo van de speelbeurt loopt niet op,
het loopt uit.

### Drie van de acht traitvoordelen zijn niet waarneembaar

Uitlijnen (+1 tolerantie, telt vrijwel nooit), pijplijn (+20 credits op een budget
dat niet slinkt en niet zichtbaar is) en abgevecht (staat in `GEEN_VOORDEEL`, maar
er staat wel code voor klaar). `MINIGAMES.md:113` legt de regel zelf vast: *een
voordeel dat je niet ziet bestaat niet.* Er staat nu een toast op het scherm die
iets belooft dat de opgave niet levert.

---

## Voorgestelde volgorde

**Ronde 1 — de vier bugs waardoor een speler winst verliest.** Klein, los te doen,
elk in één bestand: C1 (ESC eet een gewonnen ticket), C2 (klok in de achtergrond),
C3 (overlay over een lopende klok), en de tikbare wensen na de banner in t01.

**Ronde 2 — de gedeelde laag.** C4 (impact-feedback), C6 (één klok), C5
(Session-contract), C7 (tempo/handicap). Vier wijzigingen in `MinigameBase` die
alle negen minigames tegelijk optillen; C4 en C6 zijn wat elke individuele audit
als "het ene ding" noemde.

**Ronde 3 — de drie minigames zonder echte opgave.** De finale (blind cyclen +
stapelen + blussen als schade-vermijding, in één keer), A tegen B (`hp_b` 90 +
vroege stop), de renderpijplijn (Publish als echte poort). Dit is designwerk met
data-consequenties, dus het hoort na ronde 2 en met een herkalibratie van de tests.

**Ronde 4 — de dode paden.** De onbereikbare stand-up-bonus, `perfect` in uitlijnen,
Dirks `lege_tickets`-regel, `ab_hp_a_over` zonder lezer, de drie onwaarneembare
traits. Allemaal klein; samen is het het verschil tussen een spel dat zijn eigen
beloftes nakomt en een spel dat ze alleen opschrijft.

**Losstaand — de urenstaat.** Die vraagt een beslissing van Daan, geen fix: het
formulier zichtbaar maken (regels, uren, Dirks notatie) of accepteren dat het een
gesprek is en de minigame-chrome eraf halen. Beide zijn verdedigbaar; de huidige
tussenvorm met confetti is dat niet.

---

## Verantwoording

Negen agents, elk met één minigame plus de party-rubriek, allemaal lees-only en
zonder het spel te draaien (parallelle `qa_shot`-runs botsen op gedeelde
tijdelijke bestanden). Elke rekenclaim die een designbesluit raakt, is daarna in
deze sessie zelf nagerekend tegen de code en de data: de klokpauze over de hele
laag, `perfect` in uitlijnen, de stand-up-bonus, de 27 gevechtslijnen, de
Publish-capaciteit, de gekruiste faalteksten, de spawncurve van de finale, Dirks
`_verdeel()`, en het ABORT-pad in de banner. Twee correcties tijdens het werk: de
`failure`-sleutel van `mg_cro` ontbreekt níet (mijn briefingfout), en de finale
heeft 12 spawnmomenten en niet 11.

Niet gedekt door deze audit: de drie wereldhandelingen (t03, t05, t09) draaien
nooit als minigame-scene en vielen buiten scope. Alles wat hier "vermoeden" heet,
is niet in een lopend spel gezien.
