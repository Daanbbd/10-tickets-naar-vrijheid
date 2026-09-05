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

Vier van de tien tickets staan vanaf minuut één open (`available_when` in
`data/tickets/`, zie QUESTS.md). Er is dus geen "volgende ticket", alleen een
volgende keuze. Wat groeit is je inventaris: wat je gevonden
hebt. Alleen de deploy wacht — op 8/10, en dat is bewust één te vroeg: de
deploycomputer telt de hele dag mee ("DEPLOY 3/8") en staat open terwijl er nog
een ticket ligt. Wat je dan laat liggen gaat ongetest en half mee live, telt in
de oplevering als bug en wordt in het slot bij naam genoemd. De wijzer blijft
naar het open werk wijzen; deployen is een keuze op het bord, geen halte.

## De eerste minuut

Een nieuwe speler moet binnen een minuut weten **wat er gebouwd wordt** en
**hoe dit spel werkt**. Dat gebeurt op een eigen scherm tussen titel en
personagekeuze (`IntroUitleg`, `scripts/ui/intro_uitleg.gd` +
`scenes/boot/intro_uitleg.tscn`), niet pas bij het spawnen: op de
personagekeuze staat de ticketbalk en "twee tickets zelf" al, en dat leest pas
ergens voor wie eerst weet dát er tickets bestaan om zelf te doen.
`TitleScreen._on_start()` routeert er doorheen
(`Shell.goto_intro_uitleg()`) vóór `Shell.goto_character_select()`.

**Haar berichtje** — het waarom en het wat, in `IntroUitleg.bericht()`:

Om 09:12 gaat de telefoon. Het kaartje van Manege De Vrije Teugel glijdt binnen
met het hinnikgeluid dat `Telefoon` de hele dag maakt, in dezelfde behuizing:
*"Hoi! Morgen gaat de webshop voor de supplementen live, toch? Ik heb het al
aan iedereen doorgestuurd. Ook aan de dierenarts."* Daarmee staan het waarom
(morgen live), het wat (de webshop voor paardensupplementen) en de toon van de
dag (ze heeft het al aan de dierenarts verteld) in haar eigen stem, en herkent
de speler dat geluid later als "zij weer". Daaronder één regel context
(`opdracht()`): laatste dag van sprint veertien, jij werkt vandaag mee bij
Bluebird Day.

Dit blok ontbrak lang volledig, en dat was het gat waar de hele dag onlogisch
van werd: het eerste ticket dat je vond was "de klant heeft feedback", op een
product waar je nog nooit van had gehoord. Elke grap in dit spel hangt aan die
opdracht — de webshop, het paard dat naar links moet, de AI-video.

**HOE DIT WERKT** — twee regels, in `IntroUitleg.lessen()`:

1. **Tien tickets, verspreid door het kantoor. Dennis hangt je eerste twee op
   het ticketbord; daarna staan er vier open — kies zelf.** De wincondititie,
   het verkennen en het bord in één adem.
2. **Niet jouw vak? Haal er een collega bij. Alle tien af, dan mag je naar
   buiten.** De centrale spanning hierboven.

Twee regels en geen vier: de rest leer je in de wereld zelf, waar Dennis met je
meeloopt naar het bord en de tickets erop landen (zie hieronder). De teksten
staan als functie los van de scene-opbouw, zodat `_test_intro()` in
`scripts/tests/test_runner.gd` ze kan controleren zonder de scene te bouwen —
en zodat het getal in regel 1 uit de ticketdata komt in plaats van uit de
tekst. Eén scherm, één knop ("Aan het werk") naar de personagekeuze.

Wat overblijft in de wereld zelf, in `Main._intro_beat()`
(`scripts/world/main.gd`), is een reeks beats in plaats van één regel:

1. **De deadline**, uit een mond in plaats van van een dia. Daan (of Dennis,
   als je Daan zelf speelt) zegt dat de webshop morgen live moet en dat dit de
   laatste dag van sprint veertien is. Dat is de klok van de hele dag, en die
   stond nergens.
2. **Dennis komt je halen.** Hij is scrum master, dus het bord is zijn bord.
   Hij staat nooit zelf in de zeven speelbare personages, dus deze beat werkt
   voor elke speelbeurt zonder uitzondering — in tegenstelling tot elke andere
   collega, die wegvalt zodra je hém speelt.
3. **De tocht naar het bord.** De besturing blijft vrij: de wijzer wijst al
   naar `scrumbord_gang` (BBD-202 is Daans eigen ticket en staat al open),
   Dennis is gezelschap, geen gids. Aankomst hangt aan de speler.
4. **Het bord is leeg**, en dat is bewust: het spel moet leren dát het bestaat
   vóórdat het iets bevat.
5. **BBD-201 en BBD-202 landen**, één voor één, met de detailtekst van het
   ticket zelf als toelichting — geen dialoogbox over het bord heen.
6. **Kiezen.** Dennis zegt één regel over pinnen, dan de besturingskaart
   (`Hud.show_controls_card()`).

Zone-vondsten die tijdens de tocht naar het bord toch vallen (bijvoorbeeld
BBD-204, gewoon door over De Werkvloer te lopen) worden vastgehouden en pas na
de bordonthulling gemeld, op de normale lichte manier — anders zou een gewone
zone-toast de aankomst bij het bord al spoilen. Zonder dat uitstel vuurt
`_report_tile()` bovendien op physics-frame 1 al een toast af boven de infade,
voordat de speler een stap heeft gezet.

**Staande regel: nergens in dit scherm of in de nabeat staat een toetsnaam.**
Dit scherm en alle dialoog tonen op elk apparaat dezelfde tekst, dus een
toetsnaam ("druk op E") beschrijft daar iets dat niet altijd bestaat.
`_test_intro()` faalt als `IntroUitleg.lessen()` alsnog een toets noemt.

De besturingskaart is de uitzondering, en bewust: die kiest op
`DisplayServer.is_touchscreen_available()` tussen de duimversie en de
toetsenbordversie (`Hud.kaartregels()`). De regel hierboven bestaat om te
voorkomen dat het spel over een toets praat die er niet is — niet om te
verzwijgen wélke besturing je in je handen hebt. Op een laptop was de enige
uitleg die het spel gaf "Duim rechts → lopen", over een joystick die daar
sinds `Invoer.muis_stuurt_stick()` niet eens meer bestaat.

## De centrale spanning

Elk ticket hoort bij precies één vakgebied. Is het jouw vakgebied, dan los je het
direct op (~15 seconden). Is het dat niet, dan moet je eerst de juiste collega
ophalen; die loopt daarna met je mee. Daardoor speelt dezelfde dag anders per
personage zonder dat er vijf questlijnen bestaan.

Richtlijn 70/30: de tien tickets en de vloer zijn gedeeld, de dialoogvarianten en
de finale zijn personagespecifiek.

## De boog: vrije volgorde, oplopende druk

Vier tickets staan vanaf minuut één open; de rest ontgrendelt naarmate je
vordert (`available_when` in `data/tickets/`). Maar de tien tickets zijn geen
tien losse sketches: het is één dag die verder uit de hand loopt. Die twee
dingen botsen alleen als je de escalatie aan de *volgorde* hangt, en dat doet
dit spel niet — hij hangt aan je **voortgang** en aan je
**keuzes**.

| Wat | Waar het aan hangt |
|---|---|
| wanneer de druk oploopt | hoeveel tickets je klaar hebt: 1, 3, 5, 6, 7, 9 (`Gevolgen.DREMPELS`) |
| hoe de druk klinkt | wat je onderweg besloten hebt |
| hoe de druk voelt | een steeds warmere gloed over elke zone (`Gevolgen.tint()`, toegepast in `_tint_zone()` in `scripts/world/main.gd`) — subtiel, puur sfeer: de urenstaat/voortgang blokkeert nooit iets, dit ook niet |
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

### En de wereld vraagt ook iets

Lang gold dit alleen voor minigames en voor de collega's. `wereld.json` had
**nul** keuzes: elk object was een tweeslag die je las en daarna achterliet. Dat
is waar "keuzes hebben geen gevolgen" vandaan kwam — niet omdat het systeem niet
werkte, maar omdat de wereld je nooit iets vroeg.

Vier objecten vragen nu wél iets, en ze delen dezelfde inzet: **tijd** (je dag is
acht uur en je haalt het nooit) en **wat collega's later over je zeggen**.

| Waar | Wat je kiest | Wat het kost | Waar het terugkomt |
|---|---|---|---|
| Koffiemachine | de verboden middelste knop, of gewoon koffie | 5 min | Victor hoort het geluid; de machine onthoudt je bezoek |
| Prikbord | je naam bij padel zetten | niets | Willem, die padel zelf aankaartte in de stand-up |
| Whiteboard | NIET UITVEGEN uitvegen | niets | Daan, die niet meer weet wat er stond |
| Nooduitgang | de deur opendoen | 15 min, het hele kantoor staat buiten | Dennis, die ze geteld heeft |

**Niet alle dertig objecten krijgen er een.** Een poster is aankleding, en een
keuze bij een poster is een keuze zonder inzet — precies het probleem dat we
hier oplossen, dan in het klein.

De regel die dit afdwingt staat in de testsuite: een vlag die door een keuze
gezet wordt maar door geen enkele conditie gelezen, is per definitie een keuze
zonder gevolg, en de suite laat die niet door. De vier vlaggen hierboven zijn
alle vier op die eis stukgelopen voordat de terugkomers er waren.

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
- **Klok** rechtsboven, naast de ticketteller. Hij tikt zachtjes door (één
  minuut per twintig seconden) en rolt na een opgelost ticket zichtbaar vooruit
  — zie De urenstaat. Het licht op de verdieping volgt hem.

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

Falen kost nooit voortgang — het kost tijd, en het stelt je een vraag. Een
mislukte minigame levert een grappige regel op, een kwartier van je dag, en dan
de keuze: *nog een keer*, of *"Goed genoeg. Shippen."* Dat tweede sluit het
ticket alsnog, maar het telt als gebrekkig geshipt: elke keer is een bug erbij
in de oplevering, en het slot leest het je voor. Dit is een comedy adventure,
geen uitdaging — maar wat je afraffelt komt terug, en dat is de grap.

Tijd is op dezelfde manier een gevolg en geen muur. Niets gaat op slot na
vijven, maar een ticket dat je na je acht uur afsluit is *ongetest*, en de
oplevering rekent dat door (zie QUESTS.md, De urenstaat). Het daglicht op de
verdieping loopt met de klok mee — koel om negen uur, goud om vijf, tl-blauw
als je er dan nog staat — zodat je de tijd ziet zonder op de klok te kijken.

Daarom rolt de klok alleen zichtbaar vooruit bij een *opgelost* ticket. Een volle
animatie op een mislukte poging leest als straf; die boeking gaat stil, met een
toast.

Dat geldt ook voor de gevolgen. Jonathan afkappen, de webshop uit de scope
laten, de credits verbranden: geen daarvan blokkeert iets. Ze maken de
oplevering duurder. De finale heeft geen game over — de eerste deploy kan
misgaan (een rollback, een kwartier, nog een keer), de tweede nooit — en **elke geslaagde uitkomst heet
"OPGELEVERD"** — alleen de tekst eronder verschilt, van "het staat live en het
werkt" tot "dat is het enige wat je er nu over kunt zeggen". Je levert altijd
op. De vraag is wat.
