# Minigame-audit A — Scope, Stand-up, Uitlijnen

Getoetst tegen `genre-party.md` (geen tekst-tutorials, één zin, standaard
controls), `game-loop-time-trial.md` (druk/klok), `tweening.md`
(climax-moment) en de agent-vision-rubriek. Frames: `docs/audit-shots/mgA_*.png`,
gemaakt met `tools/qa_shot.py los <sec> --minigame=<id> --speler=<wie>
[--autoplay]`, bekeken met Read.

**Kanttekening:** tijdens dit onderzoek wijzigde een andere sessie live
`data/tickets/t02.json`/`t07.json`, `trait_modifier.gd` en
`ticket_controller.gd` (ongecommit) — precies het probleem dat ik in
mg_standup vond werd tijdens het schrijven gerepareerd, en `docs/MINIGAMES.md`
is inmiddels bijgewerkt om dat te bevestigen. Bevindingen hieronder zijn tegen
de ná-reparatie staat geverifieerd (frames ververst); mg_scope.gd/
mg_uitlijnen.gd zelf zijn door niemand anders aangeraakt.

---

## 1. mg_scope — BBD-201 "Scope bepalen"

**Verdict:** helder één-werkwoord-mechaniekje (tik = verplaats) met een
niet-triviale beslissing erin, maar zonder klok of pogingslimiet voelt het als
een formuliertje invullen — een open punt dat `docs/PLAN.md` zelf al noemt.

| uitleg-last | affordance | druk | faalspanning | climax | dubbel publiek | touch |
|---|---|---|---|---|---|---|
| 2 | 3 | 1 | 3 | 2 | 4 | 4 |

- **a.** briefing 34 woorden + WAT 20 + WAAROM 42 + statusregel (4) ≈ **80
  woorden**, minimaal **2 tikken** (briefing wegtikken, "Starten") vóór de
  eerste handeling.
- **b.** zonder tik blijft het intro-kaartje onbeperkt staan (`_first_daan.png`,
  `_first_willem.png`, na 1,1 s nog het kaartje). Ná "Starten"
  (`_real_first.png`, autoplay @0,55 s): een dichte lijst van 9 rijen met
  zichtbare scrollbalk; niets knippert of beweegt uit zichzelf. De twee balkjes
  (0/15, blij 0/10) suggereren het doel, maar dat lees je, je ziet het niet.
- **c.** één werkwoord: tik een rij, hij springt naar de andere lijst
  (`mg_scope.gd:244 _op_tik`, `:263 _verplaats`).
- **d.** geen. Geen timer/klok in het hele bestand (`grep` op
  "_tijd\|Timer\|klok"` levert niets op). 5 s of 20 s niets doen: niets
  gebeurt. `docs/PLAN.md` §C noemt dit zelf al als open punt — nog steeds waar.
- **e.** ja: boven capaciteit is "Vastleggen" uitgeschakeld (geen faalmoment,
  een geblokkeerde knop); onder de tevredenheidsdrempel faal je echt ("Hier
  gaat zij niet blij van worden."). `qa_solve()` (regel 400) lost 512
  combinaties exhaustief op in **1 poging** — rekenwerk, geen behendigheid.
- **f.** gedeelde `finish_with_banner()` (1,6–1,9 s, kleur, trilling, geluid),
  geen eigen juice erbovenop. Eindigt letterlijk in een tekstbanner
  (`_end.png`/`_mid.png` tonen al de post-game debugregel, want de QA-solve is
  binnen 1 tik klaar).
- **g.** ja voor de leek ("budget verdelen, twee grenzen"); de grap zit in de
  wensenlijst zelf (het paard, Comic Sans) en werkt voor beide kanten, zonder
  aparte insiderlaag.
- **h.** rijen zijn 24 canvas-px (`mg_scope.gd:74`, ~10 mm) — voldoet.
- **i.** niet klok-gestuurd; qua inhoud realistisch 20–40 s voor een mens.
- **j.** overwegend geslaagd (twee tegengestelde meters is eigen), maar
  kaart-plus-knop is qua skelet dezelfde grammatica als mg_standup's scherm.

**Scène:** ticket, Dennis praat erover, dan een WAT/WAAROM-kaartje wegtikken.
Daarna negen wensen aan/uit tikken terwijl twee balkjes schuiven. Geen klok,
dus je kunt zo lang treuzelen als je wilt — niets haalt je uit je stoel.
Vastleggen → groen kaartje. Klaar.

**Halve bak:** geen enkele druk (bevestigd door `docs/PLAN.md` als open punt);
climax is uitsluitend de generieke banner; scherm is dicht (9 rijen × 3
cijfers + 2 meters ≈ 35+ elementen, scrollbalk zichtbaar in `_real_first.png`).

**Al goed:** één duidelijke tik-handeling; tween op verplaatsen + live
meebewegende balkjes geeft voelbare feedback per tik; de wensenlijst-inhoud is
de grap en werkt voor iedereen.

**Ontwerpvoorstel:** een zichtbare aftellende klok ("Dennis wacht: 45 s")
onder de header geeft afwegen een tempo. Laat de balkjes harder "juichen" bij
het raken van de drempel (kleurflits + pop op de balk zelf, niet pas bij
Vastleggen). WAT/WAAROM kan grotendeels weg: de twee meters + kleurcode leren
de opgave al zodra je één rij aantikt.

---

## 2. mg_standup — BBD-202 "De stand-up"

**Verdict:** de sterkste van de drie — echte klok, zichtbaar doel dat live
vult, een echt succesmoment per gevangen regel — maar het is ook de
minigame waar de vakgebied-brug net kapot bleek (en tijdens dit onderzoek
live gerepareerd werd).

| uitleg-last | affordance | druk | faalspanning | climax | dubbel publiek | touch |
|---|---|---|---|---|---|---|
| 2 | 3 | 5 | 4 | 3 | 4 | 5 |

- **a.** briefing 33 woorden + WAT 24 + WAAROM 29 + statusregel (4) ≈ **90
  woorden**, minimaal 2 tikken.
- **b.** zelfde patroon: kaartje blijft staan zonder tik. Ná "Starten"
  (`_real_first.png`, autoplay @0,55 s): uitstekende affordance — één groot
  blauw "Afkappen", een groene balk die al zichtbaar krimpt, infobalk "Nuttige
  info 0/2" — geen woord nodig om te snappen dat er een klok loopt.
- **c.** één werkwoord, één knop: "Afkappen" (`mg_standup.gd:376`).
- **d.** de sterkste van de drie. Echte klok (30 s), vloeiende
  groen→oranje→rood-overgang + voelbare puls in de laatste 20%
  (`:468-482`). Niets doen: de som van alle spreekduren (45 s) overschrijdt de
  klok (30 s) ruim voordat Danny's cruciale regel valt — **niets doen = altijd
  verliezen**, een hard en eerlijk antwoord.
- **e.** ja, leerzaam: iemand afkappen vóór zijn nuttige regel viel maakt dat
  segment definitief rood ("gemist"), en blijft dat. Faaltekst legt uit wát je
  miste zonder te verklappen wie. `qa_solve()` (regel 549) zet één strategie
  vast bij setup en voert die foutloos uit — **1 poging**.
- **f.** vóór de banner al een echt moment: een cruciale regel licht groen op
  met een korte pop (`:333 _markeer_nuttige_regel`) en de infobalk vult live
  (`_climax.png`: 2/2, Danny's regel groen, "Afkappen" grijs). Het eindscherm
  zelf blijft de generieke banner.
- **g.** sterk: zonder scrumkennis snap je "luister, kap ruis af" puur uit de
  balk. Voor insiders landt het harder (Padel, "pareltje hoor haha" als ruis;
  Jonathans bug en Danny's funnel-observatie als de twee echte meldingen).
- **h.** knop expliciet Vector2(0,32) — ruim boven de norm.
- **i.** hard begrensd op ≤ 30 s — aan de korte kant van de 30–90 s-norm, maar
  voelt door de reactiedruk niet te kort.
- **j.** enige van de drie met een écht kloklichaam — blijft in grijs
  herkenbaar anders.

**De trait-bug (gevonden én live gerepareerd tijdens dit onderzoek):** vóór de
reparatie toonden zowel `_first_daan.png` als `_first_willem.png` "4 keer
afkappen" — terwijl alleen Daan een bonus zou moeten krijgen. Oorzaak:
`data/tickets/t02.json` had `owner_character: ""`, en
`QuestEngine.is_own_expertise()` (`quest_engine.gd:130-136`) retourneert
`true` voor *iedereen* zodra dat veld leeg is, dus `TraitModifier.pas_toe()`
gaf de bonus aan elk personage. De live-fix zet standup (en abgevecht,
BBD-207) in `GEEN_VOORDEEL`: sinds 5 sept 2026 zijn dit "ieders tickets", dus
niemand krijgt nog een vakgebiedvoordeel — narratief consistent, en inmiddels
ook zo in `docs/MINIGAMES.md` gedocumenteerd. Wel stond `docs/MINIGAMES.md`'s
drempeltabel nog op "binnen 42 s" terwijl de data al 30 s is; kleine
documentatie-drift, los van de trait-fix.

**Scène:** kaartje wegtikken, dan meteen in een rondje: een balk loopt leeg,
een collega praat, één knop. Kap je te vroeg af, dan mis je het voorgoed. Als
Danny's regel groen oplicht en de infobalk vol staat, voelt dat als "ik heb
'm", ruim voor het spel het zelf bevestigt.

**Halve bak:** het eindscherm zelf is nog de generieke banner, ondanks de
sterke voor-climax; de traitbrug was tot deze reparatie kapot voor precies dit
ticket — een teken dat elk ticket's `owner_character` handmatig tegen de
belofte gecontroleerd moet worden.

**Al goed:** een kloklichaam met tanden (niets doen = verlies); het
"yes"-moment zit al ín het spel, niet pas in de banner.

**Ontwerpvoorstel:** laat de infobalk zelf bij 2/2 kort opflitsen vóór de
banner, zodat de winst zichtbaar op de balk plaatsvindt. Overweeg de klok naar
32–35 s te rekken zodat één keer twijfelen niet meteen kansloos is. Werk de
42s-vermelding in `docs/MINIGAMES.md` bij.

---

## 3. mg_uitlijnen — BBD-204 "Uitlijnen"

**Verdict:** de schoonste van de drie — de opgave is zichtbaar zonder een
woord te lezen — maar mist net als scope elke druk of pogingslimiet, en
"slepen primair, knoppen secundair" is in de praktijk twee manieren om
hetzelfde te doen.

| uitleg-last | affordance | druk | faalspanning | climax | dubbel publiek | touch |
|---|---|---|---|---|---|---|
| 1 | 5 | 1 | 2 | 3 | 5 | 4 |

- **a.** briefing 10 woorden + WAT 13 + WAAROM 14 + statusregel (5) ≈ **42
  woorden** — merkbaar het lichtste van de drie.
- **b.** kaartje blijft onbeperkt staan zonder tik (na 1,1 s nog het kaartje
  voor zowel Victor als Willem). Ná "Starten" (`_real_first.png`, autoplay
  @0,6 s): de sterkste affordance van de drie — een ruitraster met vijf
  duidelijk *scheve* gekleurde vlakken, zonder tekst te lezen zie je meteen wat
  mis is. Richtingsknoppen staan zichtbaar grijs tot je kiest.
- **c.** in principe één werkwoord (verschuiven), maar twee parallelle
  ingangen: slepen (de bedoelde hoofdroute, per bestandscommentaar) en vier
  losse knoppen. Slepen heeft nul affordance-signaal op het scherm zelf;
  alleen de knoppen claimen expliciet "dit is de besturing".
- **d.** geen. Net als mg_scope: geen timer/klok (`grep` levert niets op).
  "Klaar" is nooit uitgeschakeld — vroegtijdig indrukken kan een instant-fail
  geven zonder dat er ooit reden was om te haasten. Zelfde open punt uit
  `docs/PLAN.md`.
- **e.** technisch ja ("Het staat scheef. Niet erg scheef. Precies zo scheef
  dat je het blijft zien."), maar zonder tijdsdruk is er geen reden om
  vroegtijdig op Klaar te drukken — praktische faalkans voor een oplettende
  speler is laag. `qa_solve()` (regel 507) lost elk blok as-voor-as op in
  max. 64 tikken, in **1 aanroep**.
- **f.** de sterkste voor-de-banner-climax van de drie: elk vastklikkend blok
  krijgt een lichtflits + groene rand; bij de laatste snap staat het hele vel
  al groen vóórdat de banner er is (`_mid.png`, gevangen op 1,0 s: alle vlakken
  groen, banner met Victors grap "de uitlijning is nog wat meer uitgelijnd").
- **g.** de sterkste voor de leek ("zet dingen op de lijntjes" heeft nul
  uitleg nodig); insidergrap zit in de woordspeling zelf (Victor *ís*
  uitlijning; "de uitlijning is nog wat meer uitgelijnd").
- **h.** richtingsknoppen 34×30 px (ruim boven de norm). Twee van de vijf
  blokken (Logo 40×20, Navigatie 92×20) zijn 20 px hoog — net onder de 22
  px-vuistregel voor de eerste tik-om-te-selecteren, al vangt de
  grip-logica een eenmaal vastgehouden sleep daarna soepel op.
- **i.** niet klok-gestuurd; realistisch 20–50 s voor vijf blokken op
  precisie.
- **j.** slaagt overtuigend: een raster met scheve rechthoeken is in grijs nog
  steeds evident een uitlijnpuzzel, en de enige met ruimtelijke mechaniek.

**Scène:** kaartje wegtikken, dan een pagina die er zichtbaar "net niet goed"
uitziet. Blok aantikken en recht slepen; het klikt voelbaar vast met een groen
randje. Na vijf blokken staat alles strak en verschijnt Victors droge grapje.
Nergens haast, dus het voelde meer als opruimen dan als een minigame.

**Halve bak:** exact als scope geen klok/pogingslimiet; "Klaar" kan zonder
aanleiding een straf opleveren; slepen (de hoofdroute) heeft geen zichtbaar
signaal op het scherm zelf.

**Al goed:** sterkste grijze-blokken-test van de drie; per-blok visuele
climax vóór de eindbanner; de insidergrap zit in de succes-tekst zelf.

**Ontwerpvoorstel:** een zachte tijdsdruk die niet straft maar wél tempo geeft
(bijv. een aflopende teller "Victor kijkt mee: n keer nog scheef", geen harde
game-over). Geef de eerste sleepbeweging een duidelijk duwtje (bijv. een korte
pulserende rand rond het meest scheve blok bij setup) zodat slepen zich net zo
hard aandient als de knoppen. WAT/WAAROM kan grotendeels weg: het scheve
raster legt de opgave al uit; alleen raster/tolerantie hoeft ergens te blijven.

---

## Gedeelde bevindingen (tekstpijplijn)

- **Twee tikken minimum vóór elke minigame, altijd.** Briefing-dialoog en
  WAT/WAAROM-kaartje staan na elkaar en zijn niet te omzeilen zonder een echte
  tik — alle zes "eerste frame"-screenshots (2 spelers × 3 minigames) stonden
  na 1,1 s nog op het kaartje. Naar ontwerp bedoeld (de bewuste "breuk" tussen
  personage-stem en spelregels), maar de `gezien_vlag` is per minigame-id, niet
  per personage: heeft personage A het kaartje al gezien, dan ziet personage B
  het in dezelfde speelbeurt niet meer — inconsistente uitleg afhankelijk van
  speelvolgorde.
- **Alle drie delen dezelfde climax-machinerie** (`finish_with_banner()`,
  `minigame_base.gd:246-268`): 1,6–1,9 s banner, trilling, geluid, geen
  confetti/schok/unieke VFX. Standup en uitlijnen bouwen daar zelf een sterker
  voor-climax-moment omheen (groene pop resp. blok-snap-flits); scope leunt
  volledig op de gedeelde banner.
- **Scope en uitlijnen delen hetzelfde gat**: geen timer, geen pogingslimiet —
  een bevinding die het project zelf al kende (`docs/PLAN.md` §C) en die nog
  steeds onopgelost is voor beide.
- **De trait-brug is fragieler dan hij oogt**: een leeg `owner_character` gaf
  tot vlak vóór dit rapport iedereen de standup-bonus. Dezelfde vlag stond ook
  op BBD-207 (niet mijn scope, wel in dezelfde reparatie meegenomen) — dus
  geen ongeluk maar een patroon in hoe "ticket van iedereen" gemodelleerd werd.

## Wat ik niet kon verifiëren

- De ticket-specifieke Briefing-schermen (Dennis/Daan pratend vóór elk ticket)
  kon ik niet schoon vastleggen: `--briefing=<ticket>` zonder `--autoplay`
  blijft hangen op de openingsdialoog van de wereld; mét `--autoplay` stuurt
  de autopilot de speler eerst een wereldinteractie in. De tekst zelf is wel
  exact geverifieerd via `Briefing.vul()` + `data/minigame_content.json`
  (deterministisch), dus de woordentelling in a. staat vast.
  `mgA_scope_briefing2/3.png` tonen wel het DialogueBox-format, niet de
  ticket-specifieke regel.
- Een letterlijk "20 s niets doen"-frame voor scope/uitlijnen is niet apart
  geschoten: het antwoord (niets) volgt al uit de afwezigheid van elke
  timer-referentie in beide bestanden.
- De menselijke rondeduur (i.) is een schatting op contentomvang, niet
  gemeten: `qa_solve()` lost alle drie binnen 1 tik/aanroep op, dus
  autoplay-logs geven geen realistische menselijke tijdsindicatie.

## Screenshots

`docs/audit-shots/mgA_scope_{intro,first_daan,first_willem,real_first,mid,end,
briefing,briefing2,briefing3}.png` · `mgA_standup_{intro,first_daan,
first_willem,real_first,mid,climax,end}.png` · `mgA_uitlijnen_{intro,
first_victor,first_willem,real_first,mid,end}.png`
