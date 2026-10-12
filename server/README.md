# Scorebord voor 10 Tickets naar Vrijheid

Een zo klein mogelijk online scorebord, zoals bij oude browsergames: **geen
account, alleen een bijnaam en een score.** Eén Cloudflare Worker
(`worker.js`, geen dependencies) met één Workers KV-opslag.

Het scorebord is optioneel. Zolang `ADRES` in `scripts/rush/rush_online.gd`
leeg is, doet het spel niets online en blijft alles op het apparaat.

## De belofte aan collega's

Dit is het punt van deze server. Wie speelt hoeft niets te vertrouwen dan wat
hier staat, en kan het nalezen in `worker.js` (onder de 400 regels, veel ervan commentaar) en `test.mjs`.

**Wat er bewaard wordt**, letterlijk, per regel op het bord:

| veld      | wat                                                                 |
|-----------|---------------------------------------------------------------------|
| `h`       | SHA-256 van de willekeurige sleutel van jouw apparaat (zie onder)   |
| `naam`    | je bijnaam, 1 tot 12 tekens: letters, cijfers, spatie, `-`, `_`     |
| `rol`     | je functie in het spel, uit een vaste lijst                         |
| `minuut`  | de tijd waarop je de dag afrondde (in minuten, 600 tot 1800)        |
| `sterren` | 1 tot 3, door de server uit `minuut` berekend                       |
| `ontsnap` | je ontsnaptijd in seconden, of `-1` als je niet ontsnapte           |
| `portret` | je pixelportret: een code van 1280 tekens, of leeg                  |

Ze staan in de KV-sleutel `scores:<jjjj-mm>:<dag>`, dus per maand en per dag
een lijst van maximaal 20 regels. Meer bewaart de server niet.

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

**Hoe lang.** Een sprint is een kalendermaand (UTC). Een maand-sleutel verdwijnt
uit KV op de 11e van de maand erna (`expiration`), dus een regel leeft
10 tot 41 dagen, nooit langer. Het bord toont alleen de huidige maand: op de
1e begint iedereen weer met een leeg bord.

**De sleutel.** Het spel maakt op jouw apparaat één keer een willekeurige
hexstring van 32 tekens (`RushSave.geef_sleutel()`). Die verlaat het apparaat
alleen in een POST of DELETE, en de server bewaart er alleen `SHA-256` van. De
hash dient voor twee dingen: je hebt per dag één regel (een betere tijd
vervangt je oude), en je kunt al je regels zelf wissen. Het is geen account:
je kunt je niet "inloggen" en niemand kan je ermee opzoeken. Raak je de sleutel
kwijt (browsergegevens gewist), dan kun je je regels niet meer zelf wissen;
ze verdwijnen dan vanzelf binnen 41 dagen.

**Wissen.** `DELETE /scores` met je sleutel verwijdert al jouw regels, op alle
dagen. In het spel is dat `RushOnline.wis(self)`. De spelkant kan er een knop
"Wis mijn scores" van maken die daarna ook de lokale eregalerij leegt.

**Valsspelen gaat op vertrouwen.** Dit is een spel onder collega's. Wie de API
met `curl` aanroept kan elke tijd tussen 10:00 en 30:00 inleveren; dat is
bewust zo gelaten. Echt valsspelen tegenhouden vraagt om te weten wie je bent
(accounts), waar je vandaan komt (IP's) of wat je deed (replays), en dat is
precies wat we niet willen bewaren. De remmen die er wel zijn zijn dom en
anoniem: een strak formaat (alles daarbuiten is een 400), een realistische
tijdgrens, één regel per sleutel per dag, maximaal 20 regels per dag per
maand, en een korte lijst scheldwoorden die als naam geweigerd worden. Wil je
iets verwijderen, dan doe je dat zelf:
`npx wrangler kv key delete --binding SCORES "scores:2026-10:1"`.

## De API

JSON, in UTF-8. Alleen `https://daanbbd.github.io`, `http://localhost:8060`
en `http://127.0.0.1:8060` mogen het vanuit een browser gebruiken (CORS);
een browser van een andere site krijgt een 403. Zonder `Origin`-header (het
spel op desktop, `curl`) is er niets om te toetsen en werkt het gewoon.
Antwoorden worden niet gecachet.

**`GET /scores?dag=N`** (N is 0 tot 4)

```json
{"scores": [{"naam": "Victor", "rol": "Frontend developer", "minuut": 880.5,
             "sterren": 3, "ontsnap": -1, "portret": "…1280 tekens…"}]}
```

De top 20 van de huidige maand voor die dag, op `minuut` oplopend. Bij gelijke
tijd staat wie er eerst was bovenaan.

**`POST /scores`** met `Content-Type: application/json`

```json
{"dag": 1, "naam": "Victor", "rol": "Frontend developer", "minuut": 880.5,
 "ontsnap": -1, "portret": "…1280 tekens of leeg…", "sleutel": "…32 hex…"}
```

Antwoord: `{"plek": 3}` (1 is de beste), of `{"plek": 0}` als je de top 20 niet
haalt. Zijn alle zeven velden er niet, of is er een veld meer: 400.
Heb je die dag al een regel, dan vervangt een betere `minuut` die (bij gelijke
tijd een snellere `ontsnap`); anders blijft je oude regel staan en hoor je
de plek daarvan.

**`DELETE /scores`** met `{"sleutel": "…32 hex…"}`: antwoord
`{"verwijderd": 4}`.

| veld      | regel                                                               |
|-----------|---------------------------------------------------------------------|
| `dag`     | geheel getal 0 tot 4                                                |
| `naam`    | 1 tot 12 tekens, na trimmen; Latijnse letters (met accenten), cijfers, spatie, `-`, `_`; niet op de scheldlijst |
| `rol`     | een van de twaalf rollen in `ROLLEN` (de zes uit `RushProfiel`, de zeven uit `data/characters.json`) |
| `minuut`  | getal van 600 tot 1800 (op een tiende afgerond)                     |
| `ontsnap` | `-1`, of 8 tot 300                                                  |
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
node lokaal.mjs              # het bord op http://localhost:8787, in het geheugen
```

(`node --test server/` met een mapnaam werkt in Node 24 niet; geef het bestand.)

Om het spel er lokaal tegenaan te laten praten zet je `ADRES` tijdelijk op
`"http://localhost:8787"` en start je het spel via een van de toegestane
origins (poort 8060), of op desktop, zonder origin. Zet hem daarna terug op `""`.

## Live zetten: stap voor stap

Er is niets van dit alles al gedaan. Je hebt Node en een gratis Cloudflare-account
nodig.

1. **Account.** Maak er een op <https://dash.cloudflare.com/sign-up>. De gratis
   laag is genoeg; er is geen betaalpas nodig.
2. **Inloggen.** In `server/`: `npx wrangler login` (opent de browser).
   `npm create cloudflare` is niet nodig: `wrangler.toml` staat er al.
3. **Opslag maken.** `npx wrangler kv namespace create SCORES`. Het commando
   toont een `id`. Zet die in `wrangler.toml` bij `[[kv_namespaces]]` in plaats
   van `VERVANG_MET_DE_ID_VAN_JE_KV_NAMESPACE`. (Biedt wrangler aan dat zelf te
   doen, laat dat dan toe, maar zorg dat de `binding` `SCORES` heet en dat
   `[observability]` op `enabled = false` blijft staan.)
4. **Deployen.** `npx wrangler deploy`. Bij de eerste keer vraagt hij om een
   `workers.dev`-subdomein te kiezen. Het eind van de uitvoer toont het adres,
   zoiets als `https://tickets-scorebord.<jouwnaam>.workers.dev`.
5. **Controleren.** `curl "https://tickets-scorebord.<jouwnaam>.workers.dev/scores?dag=0"`
   moet `{"scores":[]}` geven.
6. **Aan het spel koppelen.** Zet dat adres, zonder slash aan het eind, in
   `scripts/rush/rush_online.gd` bij `const ADRES := ""`, exporteer de webbuild
   opnieuw en zet hem op GitHub Pages. Daarmee gaat het bord aan.
7. **Uitzetten kan altijd:** `ADRES` weer leeg maken, of de Worker verwijderen met
   `npx wrangler delete`.

## Kosten en grenzen

Dit past ruim in de gratis laag van Cloudflare. De grenzen zoals ik ze ken
(controleer ze op <https://developers.cloudflare.com/workers/platform/limits/>
en <https://developers.cloudflare.com/kv/platform/limits/>, ze veranderen
weleens):

- Workers: 100.000 verzoeken per dag, en een paar milliseconden CPU per verzoek
  (dit doet bijna niets).
- KV: 100.000 reads per dag, 1.000 writes per dag, 1.000 deletes per dag,
  1 GB opslag, en één write per seconde per sleutel.

De krapste is **1.000 writes per dag**. Elke geaccepteerde score is één write
(een score die je lijst niet haalt of niet verbetert, schrijft niets) en elk
bord is hooguit zo'n 30 KB. Honderd collega's die elk tien dagen per dag
spelen halen dat niet. Is de grens toch op, dan weigert KV schrijven en geeft
de Worker een 500: het spel krijgt dan plek 0 en gaat gewoon door.
