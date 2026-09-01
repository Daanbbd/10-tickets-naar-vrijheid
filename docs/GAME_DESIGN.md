# Game design

**10 Tickets naar Vrijheid** — een Nederlandstalige top-down pixel-art comedy
adventure op de echte verdieping van Bluebird Day. Je kiest één collega, lost tien
tickets op rond een webshop voor paardensupplementen, en mag pas naar buiten bij
10/10. Richttijd: ~25 minuten.

## Kernloop

```
verkennen -> object of collega vinden -> probleem herkennen
   -> juiste persoon/item halen -> minigame -> ticket opgelost
   -> wereld verandert -> volgende ticket
```

## De centrale spanning

Elk ticket hoort bij precies één vakgebied. Is het jouw vakgebied, dan los je het
direct op (~15 seconden). Is het dat niet, dan moet je eerst de juiste collega
ophalen; die loopt daarna met je mee. Daardoor speelt dezelfde dag anders per
personage zonder dat er vijf questlijnen bestaan.

Richtlijn 70/30: de tien tickets en de vloer zijn gedeeld, de dialoogvarianten en
de finale zijn personagespecifiek.

## Toon

Droog, herkenbaar, understated. De humor komt uit serieuze mensen die volstrekt
normaal doen over een absurde situatie — niet uit grappen per regel.

> "De deur zit op slot. Boven de klink hangt een briefje: 'Nog even.'"
> "Nog even. Dat briefje hangt er sinds maart."

## Feedback en voortgang

- **Ticketteller** linksboven, altijd zichtbaar.
- **Ticketbord** (TAB): alle tien de tickets, met zone, of jij het zelf kunt, en een hint.
- **Hint** (Q): wijst het eerstvolgende logische doel aan.
- **Zonenaam** verschijnt kort bij binnenkomst in een nieuwe ruimte.
- **Wereldveranderingen**: elk opgelost ticket verandert iets zichtbaars of
  hoorbaars (zie QUESTS.md).

## Bewust niet gebouwd

Combat, multiplayer, crafting, meerdere verdiepingen, dag/nachtcyclus, economie,
minimap. Geen daarvan dient de kernervaring. Een minimap van een strook is
bovendien een plaatje van een lijn: de doelregel en de doelwijzer doen dat werk.

## Faalbeleid

Falen kost nooit voortgang. Een mislukte minigame levert een grappige regel op en
je mag direct opnieuw. Dit is een comedy adventure, geen uitdaging.
