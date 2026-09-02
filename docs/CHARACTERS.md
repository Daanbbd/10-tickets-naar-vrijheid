# Personages

## Speelbaar (kies er één; wisselen kan niet)

| Personage | Rol | Traits | Lost zelf op | Finale |
|---|---|---|---|---|
| **Daan** | Product Owner | proces, commercieel | BBD-201, BBD-202 | SCOPE NOT APPROVED |
| **Danny** | CRO-specialist | data, commercieel | BBD-206, BBD-207 | CHECKOUT CONVERSION CRITICAL |
| **Victor** | Frontend developer | technisch, detail | BBD-204 | FRONTEND BUILD FAILED |
| **Jonathan** | Backend developer | technisch, data | BBD-205 | PRODUCTION DATABASE CONNECTION FAILED |
| **Willem** | Client Lead | commercieel, sociaal | BBD-203 | CLIENT APPROVAL REQUIRED |
| **Bastiaan** | Frontend developer | technisch, detail | BBD-209 | VISUAL REGRESSION DETECTED |
| **Koen** | Backend / AI & automatisering | technisch, sociaal | BBD-208 | AI OUTPUT NOT REVIEWED |

Alleen Daan en Danny bezitten twee tickets; de rest één. Bij Willem staat
daar de inhoudelijk rijkste finale tegenover (hij moet daadwerkelijk akkoord halen
bij de klant).

De zes niet-gekozen collega's lopen als NPC rond en zijn op te halen wanneer een
ticket hun vakgebied is. Wat dat oplevert staat in
[MINIGAMES.md](MINIGAMES.md): de eigenaar geeft je vóór zijn minigame één waar
feit over zijn eigen ticket, in zijn eigen stem.

> **Eén functietitel per collega.** De rollen stonden op drie plekken —
> `characters.json`, `npcs.json` en elk ticket — en die weken van elkaar af:
> vijf van de zeven hadden er twee, Koen drie. Daan is Product Owner (elke
> dialoogregel behandelt hem al zo), Willem is Client Lead, Koen is Backend /
> AI & automatisering. Victor en Bastiaan zijn allebei gewoon frontend
> developer; hun specialisme (design systemen, Shopify) staat in de tagline.
> `data/characters.json` is de enige bron: een ticket erft de rol van zijn
> eigenaar bij het laden, en `_test_briefings()` controleert dat het ticket én
> de NPC dezelfde titel dragen.

> Bastiaan en Koen zijn speelbaar sinds commit `9da2cf2`. Het eigenaarschap van
> BBD-208 en BBD-209 verhuisde toen van Victor en Jonathan naar hen; de dialoog
> bleef achter, waardoor je bij Bastiaan Jonathans naam en portret kreeg. Dat is
> hersteld, en `_test_ticket_eigenaarschap` bewaakt het nu.

## NPC's

| Id | Naam | Rol | Standplaats |
|---|---|---|---|
| `dennis` | Dennis | Scrum Master | patrouilleert de gang |
| `dirk` | Dirk Schrijver | Scrum Master | verschijnt bij 5/10 en loopt met je mee |
| `klant` | Mevrouw P. Aardenmens | Klant, Manege De Vrije Teugel | entree |
| `bezorger` | De bezorger | Bezorger | verschijnt na BBD-208 |

## Dirk Schrijver

Twee scrum masters is het punt. Dennis is de mens die zegt "verder heb ik niks
nodig"; Dirk is het systeem dat wél iets nodig heeft. Dennis krijgt één regel
over Dirk en dat is genoeg.

Dirk verschijnt bij 5/10 in de gang en loopt daarna met je mee tot je je uren
geboekt hebt. Hij blokkeert niets: je kunt hem de hele dag negeren en de game
gewoon uitspelen — dat hij dan de hele dag achter je aan loopt is de grap.

**Zijn stem** is onberispelijk beleefd en net iets te precies. Nul verwijt, nul
stemverheffing: de druk zit volledig in de structuur van zijn berichten — een
exact getal, een exacte verwachting, en dan bedankt hij je voor iets wat je nog
niet gedaan hebt.

> "Hoi Daan, even een klein seintje. Er staat vandaag tot nu toe 0u geboekt,
> terwijl de verwachting rond de 4u ligt. Zou je je uren aanvullen als er nog
> wat mist?"

Vier dingen die moeten blijven: hij begint altijd met je naam, hij herhaalt zich
in plaats van te escaleren, hij zegt "als er nog wat mist" alsof het jouw
vergeetachtigheid is, en hij stuurt je door naar "mijn collega Dennis, die denkt
graag met je mee". Zijn tics staan in `TICS` in de testsuite.

De getallen in zijn regels kunnen niet in vaste strings: `DialogueController`
vult `{naam}`, `{gewerkt}`, `{geboekt}`, `{budget}` en `{klok}` in vlak voor het
renderen.

**Hij is geen robot**, en dat is de visuele grap. Hij is een gerenderde corporate
avatar: grijze blazer over een lichte polo, bruin haar, een DS-speldje op de
revers. Hij ziet eruit als een echte collega — alleen ziet hij er *te* uit.
Iedereen op de vloer komt uit dezelfde zeven spritesheets, afgeleid van echte
teamfoto's; Dirk hoort daar zichtbaar niet uit te komen. Daarom krijgt zijn
portret in `gen_portraits.py` meer kleuren dan de 24 van de rest, plus een
gladstrijking (`GERENDERD`). In een pixel-art game is een te vloeiend portret
onmiddellijk onbehaaglijk.

> Zijn bronfoto hoort als `assets/personen/dirk.png` in de map; daarna
> `gen_portraits.py` draaien. Zolang die er niet is praat hij zonder portret —
> `_portrait_for()` valt netjes terug.

## Uiterlijk

Alle personages komen uit **zeven herkleurbare spritesheets** van 16×24
(`plain`, `beard`, `glasses`, `curly`, `long`, `hoodie`, `buttons`). Huid, haar
en shirt zijn sleutelkleuren die de runtime vervangt — één sheet, oneindig veel
collega's.

Huidskleur, haarkleur, shirtkleur en uiterlijkvariant zijn afgeleid van de echte
teamfoto's in `assets/personen/`. Dezelfde foto's leveren via
`tools/generators/gen_portraits.py` de pixel-portretten (32×40, 24 kleuren) voor
het selectiescherm en het dialoogvenster.

## De namenlijst vervangen

Alles staat in `data/npcs.json` en `data/characters.json`. Dialoog verwijst
uitsluitend naar **id's**, nooit naar namen, dus hernoemen raakt geen enkele
dialoogregel. Nieuwe foto's in `assets/personen/<id>.png` zetten en
`gen_portraits.py` draaien is genoeg voor nieuwe portretten.
