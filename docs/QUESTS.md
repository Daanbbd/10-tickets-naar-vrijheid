# De tien tickets

Volgorde en afhankelijkheden volgen de opdracht exact:
`1 -> 2 -> 3 -> 4/5 -> 6 -> 7/8 -> 9 -> 10`.

De ruimtes zijn de echte ruimtes van de vloer — zie `docs/LEVEL.md`.

| Code | Titel | Zone | Vakgebied | Minigame | Open na |
|---|---|---|---|---|---|
| BBD-201 | Wat moeten we eigenlijk bouwen? | Summit | daan | `mg_user_story` | vanaf het begin |
| BBD-202 | Waarom sta ik hier eigenlijk? | De Vloer | daan | `mg_planning` | t01 |
| BBD-203 | De klant heeft feedback | Entree | willem | `mg_klantfeedback` | t02 |
| BBD-204 | De frontend is stuk | De Vloer | victor | `mg_frontend_fix` | t03 |
| BBD-205 | De backend is stuk | Het Patchhok | jonathan | `mg_backend_fix` | t03 |
| BBD-206 | Niemand koopt iets | Basecamp | danny | `mg_cro` | t04, t05 |
| BBD-207 | We hebben muziek nodig | Koffiecorner | danny | `mg_muziek` | t06 |
| BBD-208 | De klant wil een AI-video | Het Vergaderhokje | victor | `mg_video` | t06 |
| BBD-209 | Er lopen paardenbugs door het kantoor | De Vloer | jonathan | `mg_paarden` | t07, t08 |
| BBD-210 | Naar productie | Birdhouse | iedereen | `mg_deploy` | t09 |

## Wereldveranderingen

Elk opgelost ticket verandert iets zichtbaars of hoorbaars. Alle veranderingen
zijn idempotent en worden bij het laden opnieuw afgespeeld.

| Code | Verandert |
|---|---|
| BBD-201 | `set_text` op `whiteboard_vergader`; `camera_focus` op `whiteboard_vergader` |
| BBD-202 | `set_text` op `scrumbord_gang` |
| BBD-203 | `set_text` op `receptiebalie`; `despawn_npc` |
| BBD-204 | `set_text` op `wandmonitor_vloer`; `camera_focus` op `wandmonitor_vloer` |
| BBD-205 | `set_text` op `serverrack_a`; `set_modulate` op `serverrack_a` |
| BBD-206 | `set_text` op `dashboardmuur`; `set_modulate` op `dashboardmuur` |
| BBD-207 | `set_text` op `speaker_koffiecorner`; `set_ambience` |
| BBD-208 | `set_text` op `scherm_entree`; `spawn_npc` |
| BBD-209 | `set_text` op `vergadertafel` |
| BBD-210 | `set_text` op `deploycomputer`; `set_locked` op `voordeur` |

## Hints

Deze regels verschijnen op het ticketbord (TAB), via de hinttoets (Q) en op de
permanente doelregel in de HUD.

| Code | Hint |
|---|---|
| BBD-201 | De user story staat op de vergadertafel in Summit. |
| BBD-202 | Het scrumbord hangt achter de bureaus, aan de zuidwand. |
| BBD-203 | De klant wacht bij de receptie. |
| BBD-204 | De wandmonitor achter de bureaus laat de staging zien. |
| BBD-205 | Het Patchhok zit naast de toiletten, achter de badgelezer. |
| BBD-206 | De dashboardmuur hangt in Basecamp, boven de ronde tafel. |
| BBD-207 | De speaker staat in de koffiecorner, bij de tribune. |
| BBD-208 | De iPad ligt in het vergaderhokje, midden in de gang. |
| BBD-209 | Ze zijn overal. Je vindt ze vanzelf. |
| BBD-210 | De deploymentcomputer staat in Birdhouse. Je hebt de deploysleutel uit de plantenkast nodig. |

## Ontgrendelt

| Code | Zet open |
|---|---|
| BBD-201 | t02 |
| BBD-202 | t03 |
| BBD-203 | t04, t05 |
| BBD-204 | t06 |
| BBD-205 | t06 |
| BBD-206 | t07, t08 |
| BBD-207 | t09 |
| BBD-208 | t09 |
| BBD-209 | t10 |
| BBD-210 | — |

## Vakgebied en ophalen

Is het ticket jouw vakgebied, dan pak je het direct op. Zo niet, dan moet je
eerst de eigenaar opzoeken en aanspreken; die loopt met je mee tot het object.
`QuestEngine.requirements_met()` bewaakt dat, en de testsuite controleert per
personage dat een ticket buiten je vakgebied *niet* oplosbaar is zonder collega.

De collega's staan op **vaste posten** tussen de twee tickets die ze bezitten;
alleen de stagiair loopt nog. Bij 16px is een bewegende NPC ruis en een
geposteerde NPC een landmark.

BBD-210 heeft bewust geen eigenaar: elk personage krijgt daar zijn eigen
variant van (zie CHARACTERS.md). Daarnaast vraagt hij de **deploysleutel** uit
de plantenkast, onder het speelgoedpaard.
