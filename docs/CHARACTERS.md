# Personages

## Speelbaar (kies er één; wisselen kan niet)

| Personage | Rol | Traits | Lost zelf op | Finale |
|---|---|---|---|---|
| **Daan** | Product Owner | proces, commercieel | BBD-201, BBD-202 | SCOPE NOT APPROVED |
| **Danny** | CRO-specialist | data, commercieel | BBD-206, BBD-207 | CHECKOUT CONVERSION CRITICAL |
| **Victor** | Frontend developer | technisch, detail | BBD-204, BBD-208 | FRONTEND BUILD FAILED |
| **Jonathan** | Backend developer | technisch, data | BBD-205, BBD-209 | PRODUCTION DATABASE CONNECTION FAILED |
| **Willem** | Client Lead | commercieel, sociaal | BBD-203 | CLIENT APPROVAL REQUIRED |

Willem bezit één ticket in plaats van twee; daar staat de inhoudelijk rijkste
finale tegenover (hij moet daadwerkelijk akkoord halen bij de klant).

De vier niet-gekozen collega's lopen als NPC rond en zijn op te halen wanneer een
ticket hun vakgebied is.

## NPC's

| Id | Naam | Rol | Standplaats |
|---|---|---|---|
| `dennis` | Dennis | Scrum Master | patrouilleert de gang |
| `bastiaan` | Bastiaan | Frontend developer | De Vloer |
| `koen` | Koen | Backend developer | Patchhok |
| `klant` | Mevrouw P. Aardenmens | Klant, Manege De Vrije Teugel | entree |
| `stagiair` | De stagiair | Stagiair | staat in de doorgang bij de entree |
| `bezorger` | De bezorger | Bezorger | verschijnt na BBD-208 |

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
