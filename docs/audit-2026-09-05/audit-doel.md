# Audit: legt het spel het doel uit?

Onderzocht: /Users/daan/Documents/fun/.claude/worktrees/10-tickets-vrijheid-handover-079cbc
(read-only; geen bestand gewijzigd)

## 1. Oordeel

Het spel legt de tickets en de reden voor collega's helder en op tijd uit; de
tijdsdruk wordt narratief goed opgebouwd maar mechanisch is er vrijwel geen
druk — en de tekst die de tickets belooft ("alle tien af") klopt niet
helemaal met wat de deur werkelijk eist (9/10 volstaat).

- **Tickets**: JA. `IntroUitleg` noemt het aantal, waar ze liggen, het bord en
  de wincondititie, vóór de personagekeuze; de teller (x/10) staat daarna
  permanent in de HUD.
- **Werkdag/tijdsdruk**: HALF. De klok is zichtbaar en tikt door, maar "tijd
  blokkeert nooit iets" is een letterlijk ontwerpprincipe (`urenstaat.gd`) —
  om 17:12 verandert alleen een kleur en een toast, en een schone speelbeurt
  overschrijdt het budget altíjd (bevestigd: autoplay eindigde op 18:14,
  9u02 gewerkt tegen een budget van 8u). Het "morgen live"-waarom wordt nooit
  gekoppeld aan een concrete kloktijd.
- **Waarom collega's**: JA. `IntroUitleg.lessen()` zegt het vóór de eerste
  aanraking; wie het toch probeert krijgt een dialoogregel met naam + rol van
  de juiste collega, en de doelregel/hint in de HUD wijst er daarna met
  locatie naar.

## 2. De eerste vijf minuten (letterlijke tekst)

| Scherm | Tekst | Wat de speler weet / niet weet |
|---|---|---|
| Titel | "10 TICKETS / NAAR VRIJHEID — Een werkdag bij Bluebird Day" | Weet: setting. Niet: wat een ticket is. |
| Uitleg (`IntroUitleg`) | Telefoonkaartje van "Manege De Vrije Teugel": *"Hoi! Morgen gaat de webshop voor de supplementen live, toch? Ik heb het al aan iedereen doorgestuurd. Ook aan de dierenarts."* Daaronder: *"Laatste dag van sprint veertien. Jij werkt vandaag mee bij Bluebird Day."* Kop "HOE DIT WERKT": *"Tien tickets, verspreid door het kantoor. Dennis hangt je eerste twee op het ticketbord. Daarna staan er Vier open — kies zelf."* en *"Niet jouw vak? Haal er een collega bij. Alle tien af, dan mag je naar buiten."* | Weet: wat er gebouwd wordt, dat er 10 tickets zijn, dat 4 meteen open staan, dat een ander vakgebied een collega vraagt, en de (onnauwkeurige) wincondititie. Niet: hoe laat het is, of er een deadline-uur bestaat, hoe je beweegt. |
| Personagekeuze | "WIE BEN JIJ VANDAAG" + ticketbalk "DE TIEN TICKETS VAN VANDAAG" die per collega oplicht, "Twee tickets zelf. Jij bepaalt wat er wel en niet in zit." | Weet: de kernspanning in beeld (eigen tickets vs. de rest). Niet: welke twee tickets — dat komt pas op het bord. |
| Besturing | "ZO BESTUUR JE DIT": WASD/pijltjes, Shift, E, Tab, Q, Esc | Weet: hoe te spelen. Niet: nog steeds geen kloktijd/deadline. |
| Wereld — intro-beat | Dennis (of Daan zelf): *"Morgen. Laatste dag van sprint veertien. Zij denkt dat we morgen live gaan, dus dat gaan we."* Dennis loopt voorop naar het bord: *"Dit is het bord. Alles wat vandaag moet, hangt hier."* / *"Kom hier terug als je niet weet wat je moet doen."* Twee briefjes landen (BBD-201, BBD-202). *"Die twee zijn van jou. Kies er een, dan gaan we los."* | Weet nu: de deadline komt uit een mond, het bord is de hub, zijn eerste twee tickets liggen klaar. Nog steeds niet: een concreet kloktijdstip voor "morgen live", en niet dat de 8‑uursbudget sowieso wordt overschreden. |

Bevestigd met frames (`docs/audit-shots/doel_titel.png`, `doel_uitleg.png`,
`doel_select.png`, `doel_besturing.png`, `doel_wereld.png`): de wereld-frame
toont de HUD al vanaf minuut één met linksboven "▤ 0/10" en rechtsboven de
klok "09:12", terwijl Dennis de deadline-regel uitspreekt.

## 3. Bevindingen

### Hoog

- **De intro belooft "alle tien af", de deur opent al bij 9/10.**
  `scripts/ui/intro_uitleg.gd:100`: *"Niet jouw vak? Haal er een collega bij.
  Alle tien af, dan mag je naar buiten."* Maar `data/tickets/t10.json` zet
  `available_when.min_tickets_done: 8`, en `autoload/session.gd:187`
  (`dag_klaar()`) opent de voordeur zodra *alleen* t10 (BBD-210, de deploy)
  DONE is — ongeacht of er nog een negende ticket open ligt. Dit is een
  bewust ontwerp (zie `docs/GAME_DESIGN.md:16-19`: "dat is bewust één te
  vroeg", en `Gevolgen.ongetest_na_vijf()`/`niet_af_regel()` in `ending.gd:186`
  rekenen een overgeslagen ticket door als bug in de aftiteling), maar de
  letterlijke onboardingtekst dekt die uitzondering niet. Effect: een speler
  die de intro-tekst serieus neemt, verwacht dat "naar buiten kunnen" hetzelfde
  is als "alles opgelost hebben", en kan zich later afvragen waarom hij naar
  buiten kán terwijl het bord nog een ticket toont. Voorstel: de regel
  nuanceren tot iets als "Genoeg tickets af, dan mag je naar buiten — de rest
  gaat gewoon mee, half af" — of in elk geval niet "alle tien".

### Midden

- **Geen enkele tekst noemt een concreet deadline-uur.** `IntroUitleg` en de
  intro-beat (`scripts/world/main.gd:442-455`) herhalen "morgen live" en
  "laatste dag van sprint veertien", maar de mechanische druk zit in
  `Urenstaat.BUDGET_MIN` (8 uur vanaf 09:12, dus 17:12) — dat getal komt
  nergens in dialoog of uitlegscherm voor. De speler ziet pas om 17:12 een
  toast *"17:12. Je acht uur zijn op."* (`scripts/ui/hud.gd:809-814`,
  `_meld_overwerk()`), zonder vooraankondiging en zonder dat er wordt gezegd
  wát dat betekent (een ticket dat daarna sluit telt als "ongetest"). Effect:
  de speler ervaart een klok die "gewoon meeloopt" zonder te weten dat er een
  drempel nadert of wat die drempel doet. Voorstel: één regel in de
  intro-uitleg of de eerste HUD-hint die "acht uur, dus rond vijven" noemt.
- **Een schone speelbeurt overschrijdt het budget altijd, en dat wordt nooit
  gezegd.** `scripts/world/klok.gd:12-24` en `docs/GAME_DESIGN.md:193,306`
  documenteren expliciet dat zelfs de goedkoopste dag boven de acht uur
  uitkomt ("je haalt het nooit" — bewuste ontwerpinvariant). De autoplay-
  speelbeurt in deze audit bevestigt dat cijfermatig:
  `[SPEELBEURT] gewerkt: 9u02, uit om 18:14 (budget 8u)` — 62 minuten
  overwerk op een schone, foutloze 10/10-run. Omdat de speler dit vooraf
  nergens leest, oogt het budget als een haalbaar doel terwijl het spel het
  bewust onhaalbaar maakt. Effect: "tijdsdruk" voelt willekeurig/oneerlijk in
  plaats van als een bewuste comedy-premisse ("er is altijd meer werk dan
  uren"). Voorstel: die ene zin ("er is altijd meer werk dan uren, dat hoort
  zo") een keer hardop laten zeggen — bijvoorbeeld door Dirk of Dennis.
- **Zonder collega alleen een dialoogregel, geen richting.**
  `scripts/world/ticket_controller.gd:156-158` toont bij een poging zonder de
  juiste collega de tekst uit `_fetch_hint()` (regel 660): *"Dit is niet jouw
  vakgebied. Je hebt %s nodig — %s."* (naam + rol). Die regel zegt wélke
  collega, maar niet wáár hij is — dat komt pas als je het ticket vastzet op
  het bord (dan wijst de doelregel/hint met locatie, `hud.gd:906-908`). Een
  speler die een niet-eigen ticket voor het eerst aanraakt zónder eerst het
  bord te openen, weet dus wie hij zoekt maar niet waar hij moet beginnen.
  Voorstel: `_fetch_hint()` dezelfde `_aanduiding()`-locatiestaart laten
  meegeven als de doelregel al doet.

### Laag

- **"DEPLOY x/8" op de deploycomputer wordt nergens uitgelegd.**
  `scripts/world/main.gd:629-646` zet dat label vanaf minuut één, maar er is
  geen dialoog/toast die zegt dat dit hetzelfde is als "8 van je 10 tickets".
  Voor een speler die de wereld verkent vóór hij iets snapt van het bord is
  "DEPLOY 3/8" een cijfer zonder context. Effect: klein, want de HUD-teller
  (x/10) staat er al naast als referentie. Voorstel: de eerste keer dat de
  speler in de buurt komt een eenmalige toast/flavourregel.
- **Board-scherm bij 0/10 kan als "kapot" ogen.** Het bordframe
  (`doel_bord.png`) toont een grote lege witte vlakte onder de kolommen totdat
  je naar beneden scrollt naar de toelichtende regel. De code compenseert dit
  al bewust (`scrumbord.gd` rond de `LEEG`-constante, met een eigen
  toelichting per kolom) maar de puur visuele leegte blijft opvallend groot op
  dit ene frame.

## 4. Wat goed is

- **Timing van de uitleg klopt.** De opdracht ("de webshop", "morgen live")
  staat vóór de personagekeuze, dus het eerste ticket dat je tegenkomt is
  nooit meer een raadsel — expliciet als regressie-fix gedocumenteerd in
  `docs/GAME_DESIGN.md:67-70`.
- **Permanente, altijd-zichtbare teller.** De HUD toont "▤ x/10" linksboven
  vanaf de allereerste wereld-frame (`doel_wereld.png`), niet pas na het eerste
  ticket.
- **Collega-behoefte wordt driemaal verankerd**: (1) in de intro-tekst vóór
  je ooit een ticket aanraakt, (2) als expliciete dialoogregel met naam+rol
  zodra je het toch probeert (`ticket_controller.gd:660`), (3) als doorlopende
  doelregel/hint met locatie zodra je het ticket vastzet
  (`hud.gd:906-908`, `_wie()`).
- **Voortgangsfeedback is rijk en multimodaal**: een post-it-kaart vliegt van
  vindplek naar het bord-icoon (`hud.gd:656-680`, `toon_ticket_melding()`),
  een klokrol + "+45 min"-popup bij oplevering, confetti en camera-schok
  (`ticket_controller.gd:_vier()`), en een geleidelijk warmere zonetint per
  voortgangsdrempel (`Gevolgen.tint()`, `docs/GAME_DESIGN.md:136`) — samen een
  duidelijk save van "iets is net gebeurd" zonder een wall of text.
- **Narratieve tijdsdruk via de klant-sms's**: vaste kloktijden (09:45, 11:20,
  14:05, 15:20, 16:40, 20:15 in `data/klant_berichten.json`) laten de dag
  merkbaar opschuiven richting de avond, ook zonder dat er ooit een expliciet
  deadline-uur wordt genoemd.

## 5. Niet geverifieerd

- De volledige aftitelingstekst (`ending.gd`) kon niet in één frame worden
  vastgelegd — het scherm speelt regel voor regel met wachttijd ertussen, en
  een QA-shot van 3–6 s ving alleen de eerste twee/drie regels. Inhoud is wel
  via codelezing bevestigd (`_niet_af_regel()`, `_na_vijf_regel()`,
  `_gebrekkig_regel()`, `_urenclou()`).
  Bijbehorende frames: `docs/audit-shots/doel_einde.png` en `doel_einde2.png`.
  Volledige `--print-briefings`-uitvoer van de testsuite is niet apart
  opgevraagd; briefingteksten zijn beoordeeld via `scripts/core/briefing.gd`
  zelf.
- Het "zonder collega proberen"-frame (`doel_zonder_collega.png`) trof in de
  praktijk een flavourdialoog ("Het paard staat boven de header...") in
  plaats van de fetch-regel, vermoedelijk omdat `--auto=` op dit object een
  ander tak van `_interact_with()` raakte dan een eerste, ongepinde aanraking
  via het echte ticketpad. De fetch-tekst zelf is wel geverifieerd in de code
  (`ticket_controller.gd:156-158,653-660`).
- Niet elke van de tien minigames/briefings is individueel bekeken op de
  vraag of hij "in de wereld" leert in plaats van in een wall of text — de
  audit-scope was het startpad en de kernvraag (tickets/tijd/collega's), niet
  elke minigame-intro.

## Frames (docs/audit-shots/)
`doel_titel.png`, `doel_uitleg.png`, `doel_select.png`, `doel_besturing.png`,
`doel_wereld.png`, `doel_bord.png`, `doel_einde.png`, `doel_einde2.png`,
`doel_zonder_collega.png`.

## Playthrough-log
`--playthrough --autoplay` (Daan, 10/10, headless): duur 174,3s realtime;
`gewerkt: 9u02, uit om 18:14 (budget 8u)`. Log:
`/private/tmp/claude-502/-Users-daan-Documents-fun--claude-worktrees-10-tickets-vrijheid-handover-079cbc/5f701028-9d25-4a7e-a4d7-0da3b68bd7aa/scratchpad/doel_playthrough_daan.log`
