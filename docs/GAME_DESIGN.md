# Game design

**10 Tickets naar Vrijheid** — een Nederlandstalige top-down pixel-art comedy
adventure op de echte verdieping van Bluebird Day. Je kiest één collega, lost tien
tickets op rond een webshop voor paardensupplementen, en mag pas naar buiten bij
10/10. Richttijd: ~25 minuten.

## Kernloop

```
verkennen -> ruimte binnenlopen, ticket komt in je inventaris
   -> zelf kiezen wat je oppakt -> juiste persoon/item halen
   -> minigame -> ticket opgelost -> wereld verandert -> weer kiezen
```

Negen van de tien tickets staan vanaf minuut één open. Er is dus geen "volgende
ticket", alleen een volgende keuze. Wat groeit is je inventaris: wat je gevonden
hebt. Alleen de deploy wacht op 9/10 — zie QUESTS.md.

## De eerste minuut

Een nieuwe speler moet binnen een minuut vier dingen weten. Dat gebeurt op een
eigen scherm tussen titel en personagekeuze (`IntroUitleg`,
`scripts/ui/intro_uitleg.gd` + `scenes/boot/intro_uitleg.tscn`), niet pas bij
het spawnen: op de personagekeuze staat de ticketbalk en "twee tickets zelf"
al, en dat leest pas ergens voor wie eerst weet dát er tickets bestaan om zelf
te doen. `TitleScreen._on_start()` routeert er nu doorheen (`Shell.goto_intro_uitleg()`)
vóór `Shell.goto_character_select()`.

1. **Tien tickets, dan mag je naar buiten.** De wincondititie.
2. **Ze liggen verspreid; een ruimte binnenlopen levert er een op.** Zonder dit
   leest "verkennen" niet als de manier om werk te vinden.
3. **Het ticketbord is je inventaris en waar je kiest.** Negen van de tien staan
   vanaf minuut één open — er is geen volgorde, alleen een keuze.
4. **Niet je vakgebied? Dan haal je er iemand bij.** De centrale spanning
   hierboven.

De vier regels staan letterlijk in `IntroUitleg.LESSEN`, los van de
scene-opbouw, zodat `_test_intro()` in `scripts/tests/test_runner.gd` ze kan
controleren zonder de scene te hoeven bouwen. Eén statisch scherm, geen wizard:
vier regels, één knop ("Begrepen") terug naar de personagekeuze.

Wat overblijft in de wereld zelf, in `Main._intro_beat()`
(`scripts/world/main.gd`): geen gesproken tekst meer bij het spawnen, alleen
het mechanische deel. De ticketvondst in de entree (waar de speler al staat)
wordt tijdens de infade vastgehouden en pas daarna getoond, als bordbeat in
plaats van als toast. Zonder dat uitstel vuurt `_report_tile()` op
physics-frame 1 al een toast af over BBD-203: boven de infade, voordat de
speler een stap heeft gezet — precies de omgekeerde les van "verkennen levert
werk op". Pas na het bordbeat verschijnt de besturingskaart
(`Hud.show_controls_card()`).

**Staande regel: nergens in dit scherm of in de nabeat staat een toetsnaam.**
`Besturing` (`scripts/ui/besturing.gd`) is het enige besturingsvlak en staat er
op elk apparaat; een toetsnaam ("druk op E") beschrijft dan iets dat niet
altijd bestaat. `_test_intro()` faalt als `IntroUitleg.LESSEN` alsnog een toets
noemt.

## De centrale spanning

Elk ticket hoort bij precies één vakgebied. Is het jouw vakgebied, dan los je het
direct op (~15 seconden). Is het dat niet, dan moet je eerst de juiste collega
ophalen; die loopt daarna met je mee. Daardoor speelt dezelfde dag anders per
personage zonder dat er vijf questlijnen bestaan.

Richtlijn 70/30: de tien tickets en de vloer zijn gedeeld, de dialoogvarianten en
de finale zijn personagespecifiek.

## De boog: vrije volgorde, oplopende druk

Negen tickets staan vanaf minuut één open en dat blijft zo. Maar de tien
tickets zijn geen tien losse sketches: het is één dag die verder uit de hand
loopt. Die twee dingen botsen alleen als je de escalatie aan de *volgorde*
hangt, en dat doet dit spel niet — hij hangt aan je **voortgang** en aan je
**keuzes**.

| Wat | Waar het aan hangt |
|---|---|
| wanneer de druk oploopt | hoeveel tickets je klaar hebt: 3, 5, 7, 9 |
| hoe de druk klinkt | wat je onderweg besloten hebt |
| hoe zwaar de finale begint | de opgetelde gevolgen van je hele dag |

Dat is de reden dat er geen enkel ticket achter een ander zit en er toch een
boog is. Wie in een andere volgorde speelt krijgt dezelfde vier beats op
dezelfde momenten, met andere teksten.

> **Nooit hard-locken.** Een verkeerde keuze brengt je in een slechtere
> positie; hij sluit nooit een deur. Zie het faalbeleid onderaan.

## De Klant is een telefoonscherm

Ze komt niet in het kantoor. Ze heeft geen sprite, geen bureau en geen
standplaats — een klant die je kunt opzoeken is een collega, en een klant die
je opzoekt kan wachten. Ze bestaat als melding die binnenkomt terwijl je iets
anders aan het doen was: op 3, 5, 7 en 9 tickets, met een deinend paard, een
tijdstip dat opvalt (21:47) en een typing-indicator die ook knippert als ze
niets stuurt.

Ze is niet onaardig. Dat is het lastigste. Ze vindt volstrekt normaal wat voor
het team absurd is, en daar komt alle humor uit — niet uit boosaardigheid.

`scripts/ui/telefoon.gd` is de enige plek waar zij bestaat, en
`data/klant_berichten.json` het enige waar ze iets zegt. Haar varianten staan
achter dezelfde `when`-condities als alle dialoog, dus wat ze stuurt volgt uit
je keuzes.

## Keuzes hebben gevolgen

Elke minigame geeft een payload terug. `scripts/core/gevolgen.gd` is de enige
plek die daar betekenis aan geeft, en splitst dat in twee soorten:

- **Narratieve feiten worden gewone flags** (`gevolg_jonathan_gemist`,
  `gevolg_geen_webshop`, …). Dialoog filtert daarop met de bestaande
  `flags_all`-grammatica, dus er is geen nieuwe conditie-key nodig en de
  validator dekt het meteen. Acht collega's hebben er een eigen regel voor.
- **Getallen komen in `Session.gevolgen`**, en daar leest alleen de finale uit.

Het duidelijkste voorbeeld staat in BBD-201. Het paard naar links kost één punt
en maakt haar het blijst van alles, dus je kunt de scope halen door het paard
en Comic Sans te beloven en de webshop weg te laten. Dat is geen gat in de
balans — dat is de grap, en hij komt drie keer terug: Bastiaan heeft er een
mening over, zij vraagt op de avond voor de oplevering of mensen wel iets
kunnen kopen, en de finale begint met minder vertrouwen.

## Toon

Droog, herkenbaar, understated. De humor komt uit serieuze mensen die volstrekt
normaal doen over een absurde situatie — niet uit grappen per regel.

> "De deur zit op slot. Boven de klink hangt een briefje: 'Nog even.'"
> "Nog even. Dat briefje hangt er sinds maart."

## Feedback en voortgang

- **Ticketteller** linksboven, altijd zichtbaar, met de ▤-glyph van de knop die
  het bord opent — teller en knop wijzen naar hetzelfde ding.
- **Een ticket krijgen** is een briefje dat in beeld komt met zijn afzender erop
  ("Van Victor", of de ruimte waar je het vond) en dat daarna naar de ▤-knop
  vliegt. Op die knop blijft staan hoeveel je nog niet bekeken hebt.

  Dit is met opzet géén bord dat zelf opengaat. Dat deed het wel, bij elk ticket
  dat je kreeg: elf keer per speelbeurt nam het spel het scherm over zonder dat
  er stond waarom, en dan is het bord iets dat jou overkomt in plaats van de
  plek waar jij kiest. Eén uitzondering blijft: de intro-beat opent het bord één
  keer, want dat is de enige plek waar het spel moet leren dát het er is.
- **Ticketbord** (▤ op de knoppenbalk, sneltoets Tab): je inventaris en je
  keuzescherm — de tickets die je gevonden hebt, met zone, of jij het zelf kunt,
  en een hint. Een briefje aantikken maakt het je doel, en de knop onderaan zegt
  dan "Aan de slag" in plaats van "Sluiten". Eronder staat hoeveel er nog ergens
  op de vloer liggen en hoeveel er nog achter ander werk wachten. Een briefje
  dat je nog niet bekeken hebt heeft een blauwe rand — dezelfde blauwe als de
  ring op een object dat je nog nooit hebt aangetikt en als de badge op ▤.
- **Doelregel**: je keuze, of hoeveel je kunt kiezen, of "loop rond" als je nog
  niets gevonden hebt. De ruimte staat er één keer in: noemt de opdracht de plek
  al ("Haal Victor uit De Vloer"), dan zegt de regel hem niet nóg een keer.

  Hij staat er niet permanent. Hij klapt vier seconden uit zodra hij iets anders
  te zeggen heeft, en een tik op de ticketteller haalt hem terug. De reden is
  ruimte: de camera klemt verticaal vast, dus alles wat bovenin permanent staat,
  staat over de vergaderkamers.
- **Kompasstrip**, tussen de teller en de klok in: de hele verdieping op één
  regel, één pixel per tegel, met jouw plek en je doel erop. Zie Navigatie.
- **Wat een tik doet** staat op het object zelf, bij de pulserende ring: "Praten
  met Victor", "Onderzoeken". Niet onderaan het scherm — daar stond het toen er
  nog een actieknop was die de tekst droeg.
- **Doelwijzer** in de wereld: een driehoekje boven je doel, en zodra dat doel
  buiten beeld ligt een pijl tegen de schermrand met de ruimtenaam en de afstand
  erbij.
- **Hint** (? op de knoppenbalk, sneltoets Q): je gekozen ticket, of de ruimte waar nog werk ligt.
- **Zonenaam** verschijnt kort bij binnenkomst in een nieuwe ruimte.
- **Wereldveranderingen**: elk opgelost ticket verandert iets zichtbaars of
  hoorbaars (zie QUESTS.md).
- **Klok** rechtsboven, naast de ticketteller. Na een opgelost ticket rolt hij
  zichtbaar vooruit — zie De urenstaat.

## Navigatie

De verdieping is 130 tegels lang en de camera toont er twaalf. Je kijkt dus naar
9% van het gebouw, en de andere 91% is waar je doel meestal staat. Twee dingen
lossen dat op, en ze zeggen allebei hetzelfde in een andere taal.

**De doelwijzer klemt tegen de schermrand.** Staat het doel in beeld, dan hangt
het driehoekje erboven zoals altijd. Staat het buiten beeld — bijna altijd — dan
schuift het naar de rand, wijst het die kant op, en zet het er de ruimtenaam en
de afstand bij: "Birdhouse 36 m". Alleen horizontaal, want de vloer is precies
even hoog als het scherm en verticaal valt er nooit iets buiten beeld. Hij klemt
zich onder de HUD-balken, niet erachter.

**De kompasstrip** staat in de HUD onder de doelregel: één pixel per tegel, met
streepjes op de kamergrenzen, jouw plek in wit en je doel in oranje. Het aantal
tegels komt uit `floor.json`, dus een herontworpen vloer levert vanzelf een
andere strip op.

De afstand in meters komt uit `WorldBuilder.KORTE_AS_M` — de ankermaat uit
LEVEL.md, niet een tweede kopie van de schaal.

Wat de strip **niet** doet is het doel bepalen. Dat blijft
`QuestEngine.next_hint_ticket()`, precies zoals de doelregel en de hintknop; de
strip krijgt een positie doorgegeven en tekent hem.

## De urenstaat

Je komt om 9:12 binnen en je hebt acht uur. Er is meer werk dan uren — voor elk
personage, altijd — dus om vijf uur ga je niet naar huis. Je gaat overwerken en
de klok loopt gewoon door.

> **Eén harde regel: tijd blokkeert nooit iets en kan het spel nooit onwinbaar
> maken. De urenstaat is een scorebord en een grap, geen grondstof.**

Dat is geen detail maar de reden dat dit ding mag bestaan naast "economie" in de
lijst hieronder. Zodra de klok een ticket, een deur of een collega afsluit botst
hij met het faalbeleid, en dan moet hij eruit. `scripts/core/urenstaat.gd` is de
enige plek waar tijd betekenis krijgt; het grootboek staat in QUESTS.md.

De dag heeft daardoor voor het eerst een vorm: je begint met acht uur, halverwege
komt Dirk vragen waar je uren blijven, rond vijven raakt je budget op, en de
aftiteling telt op wat je werkte tegen wat je mocht boeken.

Dat de goedkoopst mogelijke dag van elk personage boven de acht uur uitkomt is
een ontwerpinvariant, niet een balansdetail: `_test_urenstaat()` faalt als een
herbalancering van ticket-eigendom hem stilletjes zou slopen.

## Bewust niet gebouwd

Combat, multiplayer, crafting, meerdere verdiepingen, dag/nachtcyclus, economie,
een tweede inventarisscherm voor voorwerpen (die staan als regel onder het
ticketbord). Geen daarvan dient de kernervaring.

Hier stond **minimap** ook in, met als reden: "een minimap van een strook is een
plaatje van een lijn". Dat klopte, en het was het verkeerde antwoord. Deze vloer
*ís* een lijn — 130 bij 26, waarvan de camera 12 breed toont — dus een plaatje
van een lijn is hier geen versimpeling maar de plattegrond op ware schaal, en
hij past op één regel van 130 pixels. Wat het argument in werkelijkheid afwees
is een tweede scherm met een tweede wereldweergave, en dat is de kompasstrip
niet: hij is de doelregel met een afstand erbij. Zie Navigatie.

De doelregel en de doelwijzer zouden dit werk doen, zei die zin er nog bij. De
doelregel noemt een ruimtenaam die je alleen kunt plaatsen als je het kantoor al
kent, en de doelwijzer stond in een wereld waarvan 91% buiten beeld ligt: die
zag je één keer, op het moment dat je er al voor stond.

De urenstaat is de uitzondering die de regel bevestigt: het is geen economie,
want je kunt er niets mee kopen en het kan je niets kosten. Het is een getal dat
meekijkt.

## Faalbeleid

Falen kost nooit voortgang — het kost alleen tijd, en tijd is geen voortgang.
Een mislukte minigame levert een grappige regel op, een kwartier van je dag, en
je mag direct opnieuw. Dit is een comedy adventure, geen uitdaging.

Daarom rolt de klok alleen zichtbaar vooruit bij een *opgelost* ticket. Een volle
animatie op een mislukte poging leest als straf; die boeking gaat stil, met een
toast.

Dat geldt ook voor de gevolgen. Jonathan afkappen, de webshop uit de scope
laten, de credits verbranden: geen daarvan blokkeert iets. Ze maken de
oplevering duurder. De finale heeft geen game over en **elke uitkomst heet
"OPGELEVERD"** — alleen de tekst eronder verschilt, van "het staat live en het
werkt" tot "dat is het enige wat je er nu over kunt zeggen". Je levert altijd
op. De vraag is wat.
