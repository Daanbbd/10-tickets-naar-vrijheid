# Minigames

Tien minigames, **zes mechanieken**. Dat is de belangrijkste scopebeslissing van
het project: elke minigame is een JSON-config in `data/minigame_content.json`,
geen eigen codebase.

| Mechaniek | Script | Gebruikt door |
|---|---|---|
| SlotBoard | `mg_slotboard.gd` | BBD-201, 202, 204, 206 |
| TagPicker | `mg_tagpicker.gd` | BBD-207, 208 |
| ChoiceScene | `mg_choicescene.gd` | BBD-203 |
| CableBoard | `mg_cableboard.gd` | BBD-205 |
| WhackAHorse | `mg_whack.gd` | BBD-209 |
| DeployConsole | `mg_deploy.gd` | BBD-210 |

## Contract

```gdscript
MinigameBase.setup(config: Dictionary)      # na add_child
signal finished(result: MinigameResult)     # SUCCESS / FAIL / ABORT
```

`Shell.run_minigame(id, config)` pauzeert de wereld, hangt de scene op
MinigameLayer (50) en `await`t het resultaat. De minigame mag `Session` **lezen**
maar nooit schrijven: de uitkomst gaat uitsluitend via `finished` terug naar
`TicketController`.

ESC breekt af. Afbreken laat het ticket op ACTIVE staan; opnieuw praten is
opnieuw proberen. Falen kost nooit voortgang.

## De mechanieken

**SlotBoard** — sleep kaartjes naar genummerde vakken. Echte drag & drop
(`_get_drag_data` / `_drop_data`); klikken op een geplaatst kaartje haalt het
terug. Er zijn altijd meer kaarten dan vakken; de afleiders zijn de grap.
Kaarten worden bewust **allemaal neutraal** getekend — de `tint` uit de data zou
het antwoord verklappen.

**TagPicker** — kies N tags uit een pool; de combinatie bepaalt de uitkomst.
Regels worden **op volgorde** geëvalueerd, eerste match wint. Absurde regels
staan bovenaan, de goede regel vangt de rest af. Elke tag komt in minstens één
regel voor (de testsuite controleert dat), dus er is altijd een uitkomst.

**ChoiceScene** — dialoogkeuzes met punten tegen een drempel. Opties kunnen een
`when` dragen, zodat sommige antwoorden alleen voor bepaalde personages bestaan.

**CableBoard** — klik twee knooppunten om een kabel te leggen, nog eens om hem
weg te halen. Extra kabels tellen als fout.

**WhackAHorse** — de arcadepiek. Bugpaarden raken telt; een klantpaard raken kost
drie seconden en levert "JE HEBT EEN KLANTPAARD GESLAGEN" op. Nooit meer dan twee
paarden tegelijk; de spawninterval loopt op na elke treffer. Geen game over,
alleen tijd.

**DeployConsole** — de finale. Alle checks lopen op groen, dan faalt de
deployment op precies jouw vakgebied. De variant hergebruikt SlotBoard,
CableBoard of ChoiceScene via `content_override`, zodat er geen elfde mechaniek
nodig is.

## Balans

Alles is in 60–120 seconden te doen en op de eerste of tweede poging haalbaar.

| Minigame | Drempel |
|---|---|
| slotboards | max 2 foute controles |
| klantfeedback | 6 van maximaal 9 punten |
| tagpickers | 4 pogingen |
| paardenbugs | 10 bugs in 60 seconden |
| deployvarianten | 2 van 3 punten |

## QA

Elke mechaniek implementeert `qa_solve()`, die de minigame **langs de echte
winroute** oplost — de juiste kaarten leggen, de veilige tags kiezen, de gevraagde
kabels trekken. De autopilot roept dat aan, zodat een geautomatiseerde
speelbeurt de daadwerkelijke wincondities test en niet een omweg.
