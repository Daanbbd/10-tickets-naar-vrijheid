# Scorebord voor 10 Tickets naar Vrijheid

Een zo klein mogelijk online scorebord, zoals bij oude browsergames: **geen
account, alleen een bijnaam en een score.** Eén Cloudflare Worker
(`worker.js`, geen dependencies) met één Workers KV-opslag.

Het scorebord is optioneel. Zolang `ADRES` in `scripts/rush/rush_online.gd`
leeg is, doet het spel niets online en blijft alles op het apparaat.

## De belofte aan collega's

Dit is het punt van deze server. Wie speelt hoeft niets te vertrouwen dan wat
hier staat, en kan het nalezen in `worker.js` (zo'n 500 regels, veel ervan commentaar) en `test.mjs`.

**Wat er bewaard wordt**, letterlijk, per regel op het bord:

| veld      | wat                                                                 |
|-----------|---------------------------------------------------------------------|
| `h`       | SHA-256 van de willekeurige sleutel van jouw apparaat (zie onder)   |
| `naam`    | je bijnaam, 1 tot 12 tekens: letters, cijfers, spatie, `-`, `_`     |
| `rol`     | je functie in het spel, uit een vaste lijst                         |
| `minuut`  | de tijd waarop je de dag afrondde (in minuten, 600 tot 1800)        |
| `sterren` | 1 tot 3, door de server uit `minuut` berekend                       |
| `ontsnap` | je ontsnaptijd in seconden, of `-1` als je niet ontsnapte           |
| `punten`  | je puntentotaal van die dag (geheel getal); daarop wordt gerangschikt |
| `portret` | je pixelportret: een code van 1280 tekens, of leeg                  |

Ze staan in de KV-sleutel `scores:<jjjj-Www>:<dag>` (bijvoorbeeld
`scores:2026-W42:1`), dus per week en per dag een lijst van maximaal 20 regels. Meer bewaart de server niet.

**Wat er niet bewaard wordt:**

- geen IP-adres, geen User-Agent, geen cookies, geen e-mail, geen account;
- geen tijdstempel en geen id per regel (de volgorde is alleen de rangschikking);
- niet je sleutel zelf, alleen de hash ervan;
- niet `wie` (welk personage je speelde) en niet `gebeld`; die stuurt het spel
  niet eens mee, en de server weigert velden die hij niet kent;
- geen foto. Een portret is altijd 32x40 pixels uit een vast palet van 32
  kleuren, als code van precies 1280 tekens uit `0-9a-v`. Daar past niets
  anders in, en de server weigert alles wat niet exact zo is.

**Geen logs.** `wrangler.toml` zet `[observability]` en `logpush` uit en de code
gebruikt nergens `console`. De Worker leest de headers met IP, User-Agent en
cookies niet. Een test (`test.mjs`) controleert dat de broncode ze niet noemt
en dat er niets van in KV terechtkomt.

Eerlijk over wat hier buiten valt: Cloudflare is de host en ziet zoals elke
host het IP-adres op netwerkniveau om een antwoord terug te kunnen sturen
(zie hun privacybeleid), en het dashboard toont samengevatte tellingen
(aantal verzoeken, fouten). Dat staat los van wat deze code leest of bewaart,
en er zit geen gegeven per speler in.

**Slack (optioneel, uit tenzij jij het aanzet).** Is de secret `SLACK_WEBHOOK`
gezet, dan stuurt de Worker één bericht naar die webhook zodra iemand nummer 1
van een dag wordt en dat eerst iemand anders was (of niemand). Alleen dit gaat
de deur uit: de **bijnaam, de dag, de punten en de eindtijd**, in een zin als
"🏆 *Danny* staat nu #1 op dinsdag met 2.340 punten (thuis om 15:42). Wie gaat
erover?" met een link naar het spel. Geen portret, geen rol, geen sleutel of
hash, geen IP. Is de secret niet gezet, dan gaat er niets naar buiten en doet
de Worker precies wat hij zonder deze regel deed. Zie "Slack aan en uit zetten".

**Hoe lang.** Een sprint is een ISO-week (UTC, maandag tot en met zondag, het
weeknummer volgt de donderdag zoals gebruikelijk). Een sleutel verdwijnt uit KV
aan het einde van de week erna (`expiration`: de maandag 00:00 UTC, twee weken
na de maandag van zijn eigen week), dus een regel leeft 7 tot 14 dagen, nooit
langer. Het bord toont alleen de huidige week: op maandag begint iedereen weer
met een leeg bord.

**De sleutel.** Het spel maakt op jouw apparaat één keer een willekeurige
hexstring van 32 tekens (`RushSave.geef_sleutel()`). Die verlaat het apparaat
alleen in een POST of DELETE, en de server bewaart er alleen `SHA-256` van. De
hash dient voor twee dingen: je hebt per dag één regel (een betere tijd
vervangt je oude), en je kunt al je regels zelf wissen. Het is geen account:
je kunt je niet "inloggen" en niemand kan je ermee opzoeken. Raak je de sleutel
kwijt (browsergegevens gewist), dan kun je je regels niet meer zelf wissen;
ze verdwijnen dan vanzelf binnen 14 dagen.

**Wissen.** `DELETE /scores` met je sleutel verwijdert al jouw regels, op alle
dagen van de huidige en de vorige week (langer bestaat er niets). In het spel is dat `RushOnline.wis(self)`. De spelkant kan er een knop
"Wis mijn scores" van maken die daarna ook de lokale eregalerij leegt.

**Valsspelen gaat op vertrouwen.** Dit is een spel onder collega's. Wie de API
met `curl` aanroept kan elke tijd tussen 10:00 en 30:00 inleveren, met punten
tot de grens hieronder; dat is bewust zo gelaten. De server controleert alleen
dat `punten` past bij de tijd: nooit meer dan de formule uit het spel op haar
gunstigst geeft (basis 1000, 5 per minuut voor 17:00, reeks, spoedtickets en
dubbel-punten samen hooguit ~2500, 10 per seconde ontsnaptijd onder de 40 s).
Dat is een zeef tegen onzin en tikfouten, geen anti-cheat. Echt valsspelen tegenhouden vraagt om te weten wie je bent
(accounts), waar je vandaan komt (IP's) of wat je deed (replays), en dat is
precies wat we niet willen bewaren. De remmen die er wel zijn zijn dom en
anoniem: een strak formaat (alles daarbuiten is een 400), een realistische
tijd- en puntengrens, één regel per sleutel per dag, maximaal 20 regels per
dag per week, en een korte lijst scheldwoorden die als naam geweigerd worden. Wil je
iets verwijderen, dan doe je dat zelf:
`npx wrangler kv key delete --binding SCORES "scores:2026-W42:1"`.

## De API

JSON, in UTF-8. Alleen `https://daanbbd.github.io`, `http://localhost:8060`
en `http://127.0.0.1:8060` mogen het vanuit een browser gebruiken (CORS);
een browser van een andere site krijgt een 403. Zonder `Origin`-header (het
spel op desktop, `curl`) is er niets om te toetsen en werkt het gewoon.
Antwoorden worden niet gecachet (`Cache-Control: no-store`).

**`GET /scores?dag=N`** (N is 0 tot 4)

```json
{"sprint": "2026-W42",
 "scores": [{"naam": "Victor", "rol": "Frontend developer", "minuut": 880.5,
             "sterren": 3, "ontsnap": -1, "punten": 3140, "portret": "…1280 tekens…"}]}
```

De top 20 van de huidige week voor die dag, op `punten` aflopend. Bij gelijke
punten staat de lagere `minuut` bovenaan, dan de snellere `ontsnap` (`-1`, niet
ontsnapt, telt als de langzaamste), en bij een volledig gelijke stand wie er
eerst was.

**`GET /koplopers`**

```json
{"sprint": "2026-W42",
 "dagen": [{"naam": "Victor", "rol": "Frontend developer", "minuut": 880.5,
            "sterren": 3, "ontsnap": -1, "punten": 3140, "portret": "…"},
           null, null, null, null]}
```

De nummer 1 van elke dag (0 tot 4) in één antwoord, `null` voor een dag zonder
regels. Vijf KV-reads, één verzoek. Het spel hangt hiermee het portret van de
koploper in het kantoor en meldt "X is je voorbij".

**`POST /scores`** met `Content-Type: application/json`

```json
{"dag": 1, "naam": "Victor", "rol": "Frontend developer", "minuut": 880.5,
 "ontsnap": -1, "punten": 3140, "portret": "…1280 tekens of leeg…", "sleutel": "…32 hex…"}
```

Antwoord: `{"plek": 3}` (1 is de beste), of `{"plek": 0}` als je de top 20 niet
haalt. Zijn alle acht velden er niet, of is er een veld meer: 400.
Heb je die dag al een regel, dan vervangt een hoger puntentotaal die (bij
gelijke punten de beste volgens de volgorde hierboven: lagere `minuut`, dan
snellere `ontsnap`); anders blijft je oude regel staan en hoor je de plek
daarvan.

**`DELETE /scores`** met `{"sleutel": "…32 hex…"}`: antwoord
`{"verwijderd": 4}`. `POST /scores/wis` met dezelfde body doet precies
hetzelfde; die gebruikt het spel, omdat Godot op het web bij DELETE niet altijd
een body meestuurt.

| veld      | regel                                                               |
|-----------|---------------------------------------------------------------------|
| `dag`     | geheel getal 0 tot 4                                                |
| `naam`    | 1 tot 12 tekens, na trimmen; Latijnse letters (met accenten), cijfers, spatie, `-`, `_`; niet op de scheldlijst |
| `rol`     | een van de twaalf rollen in `ROLLEN` (de zes uit `RushProfiel`, de zeven uit `data/characters.json`) |
| `minuut`  | getal van 600 tot 1800 (op een tiende afgerond)                     |
| `ontsnap` | `-1`, of 8 tot 300                                                  |
| `punten`  | geheel getal, 0 tot `1000 + max(0, 1020 - minuut) * 5 + 2500 + (ontsnap >= 0 ? max(0, 40 - ontsnap) * 10 : 0)`, naar beneden afgerond |
| `portret` | leeg, of precies 1280 tekens uit `0-9a-v`                           |
| `sleutel` | precies 32 tekens uit `0-9a-f`                                      |

Sterren worden nooit aangenomen maar berekend, zoals `RushData.sterren_voor()`:
tot en met 17:00 (1020) drie, tot en met 18:30 (1110) twee, daarna een.

Foutcodes: 400 (past niet), 403 (andere site), 404 (ander pad), 405 (andere
methode), 413 (body groter dan 4 KB), 415 (geen JSON), 500 (iets ging mis; er
wordt niets gelogd).

Een bekende beperking: KV is geen database. Twee scores die op precies hetzelfde
moment binnenkomen kunnen elkaar overschrijven, en een lezer kan tot ongeveer
een minuut een ouder bord zien. Voor een bord onder collega's is dat prima.

## Zelf draaien en testen

```sh
cd server
npm test                     # of: node --test server/test.mjs vanuit de projectmap
node lokaal.mjs              # het bord op http://localhost:8787, in het geheugen, zonder Slack
```

(`node --test server/` met een mapnaam werkt in Node 24 niet; geef het bestand.)

Om het spel er lokaal tegenaan te laten praten zet je `ADRES` tijdelijk op
`"http://localhost:8787"` en start je het spel via een van de toegestane
origins (poort 8060), of op desktop, zonder origin. Zet hem daarna terug op `""`.

## Live zetten: stap voor stap

Je hebt Node en een gratis Cloudflare-account nodig (dat bestaat nu). De gratis
laag is genoeg; er is geen betaalpas nodig.

1. **Inloggen.** In `server/`: `npx wrangler login` (opent de browser).
   `npm create cloudflare` is niet nodig: `wrangler.toml` staat er al.
2. **Opslag maken.** `npx wrangler kv namespace create SCORES`. Het commando
   toont een `id`. Zet die in `wrangler.toml` bij `[[kv_namespaces]]` als `id`.
   (Biedt wrangler aan dat zelf te doen, laat dat dan toe, maar zorg dat de
   `binding` `SCORES` heet, dat `logpush = false` boven de eerste tabel blijft
   staan en dat `[observability]` op `enabled = false` blijft staan.)
3. **Controleren zonder te deployen.** `npx wrangler deploy --dry-run` valideert
   de config.
4. **Deployen.** `npx wrangler deploy`. Bij de eerste keer vraagt hij om een
   `workers.dev`-subdomein te kiezen. Het eind van de uitvoer toont het adres,
   zoiets als `https://tickets-scorebord.<jouwnaam>.workers.dev`.
5. **Nakijken.** `curl "https://tickets-scorebord.<jouwnaam>.workers.dev/scores?dag=0"`
   moet `{"sprint":"2026-W42","scores":[]}` geven (met het weeknummer van dat
   moment), en `.../koplopers` vijf keer `null`.
6. **Aan het spel koppelen.** Zet dat adres, zonder slash aan het eind, in
   `scripts/rush/rush_online.gd` bij `const ADRES := ""`, exporteer de webbuild
   opnieuw en zet hem op GitHub Pages. Daarmee gaat het bord aan.
7. **Optioneel: Slack.** Zie hieronder.
8. **Uitzetten kan altijd:** `ADRES` weer leeg maken, of de Worker verwijderen met
   `npx wrangler delete`.

### Slack aan en uit zetten

Maak in Slack een *Incoming Webhook* voor het kanaal waar de meldingen moeten
komen (een app met "Incoming Webhooks"; Slack geeft een adres dat met
`https://hooks.slack.com/` begint). Dan, in `server/`:

```sh
npx wrangler secret put SLACK_WEBHOOK     # plak het webhook-adres als wrangler erom vraagt
```

Meteen actief, zonder opnieuw te deployen. Het adres staat dus niet in de code
of in git. Uitzetten:

```sh
npx wrangler secret delete SLACK_WEBHOOK
```

Is de secret leeg, ontbreekt hij, of begint hij niet met `https://`, dan gaat er
niets naar buiten. Wat er verstuurd wordt: één `POST` met `{"text": "…"}`, alleen
bijnaam (met `&`, `<` en `>` veilig gemaakt voor Slack), dag, punten en eindtijd.
De Worker wacht er niet op (`ctx.waitUntil`), negeert fouten van Slack en logt
niets: een storing bij Slack raakt de score niet. Lokaal (`lokaal.mjs`) staat
Slack altijd uit.

## Kosten en grenzen

Dit past ruim in de gratis laag van Cloudflare. De grenzen zoals ik ze ken
(controleer ze op <https://developers.cloudflare.com/workers/platform/limits/>
en <https://developers.cloudflare.com/kv/platform/limits/>, ze veranderen
weleens):

- Workers: 100.000 verzoeken per dag, en een paar milliseconden CPU per verzoek
  (dit doet bijna niets).
- KV: 100.000 reads per dag (`/koplopers` kost er vijf per verzoek), 1.000 writes per dag, 1.000 deletes per dag,
  1 GB opslag, en één write per seconde per sleutel.

De krapste is **1.000 writes per dag**. Elke geaccepteerde score is één write
(een score die je lijst niet haalt of niet verbetert, schrijft niets) en elk
bord is hooguit zo'n 30 KB. Een Slack-melding is geen KV-write, maar wel een
uitgaand verzoek (één per nieuwe nummer 1). Honderd collega's die elk tien dagen per dag
spelen halen dat niet. Is de grens toch op, dan weigert KV schrijven en geeft
de Worker een 500: het spel krijgt dan plek 0 en gaat gewoon door.
