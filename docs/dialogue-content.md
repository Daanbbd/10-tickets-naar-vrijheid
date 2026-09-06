# Dialogue Content — 10 Tickets naar Vrijheid

Gesprekscontent voor alle characters, georganiseerd per scène. Formaat volgt de JSON node-graph structuur van het spel: elke sectie toont de scène als leesbaar script plus notities over character-specifieke varianten.

Dit document is gegenereerd vanuit de daadwerkelijke spelbestanden (`data/dialogue/npcs.json`, `data/dialogue/tickets.json` en `data/dialogue/wereld.json`) en beschrijft wat er nu daadwerkelijk in het spel staat.

---

## Character Voice Reference

| Character | Stijl | Catchphrase / tic |
|---|---|---|
| **Daan** | Rustig, procesmatig, licht zelfrelativerend | "puur uit interesse", "O-M-Z" |
| **Danny** | Geen hoofdletters, bondig, data-first | "psies", "biem", "lekker insmeren met olijfolie", "o-m-z" |
| **Victor** | Direct, oog voor detail, af en toe vloekt | "manmanman", "godver", "hahaha", "O-M-Z" |
| **Jonathan** | Droog, nauwkeurig, weinig woorden | "ik ga er naartoe kijken", "lokaal werkt het" |
| **Willem** | Warm, sociaal, overdrijft soms | "Absoluta... ehh, Looff", "heeeel", "O-M-Z" |
| **Koen** | Relaxed, gerust, enigszins mysterieus | "lekker ouwe", "piepelienies", "vgm" |
| **Bastiaan** | Enthousiast, vergeet leestekens | ",," (dubbele komma als pauze/afsluiter) |
| **Dennis** | Minimalistisch, scrum-neutraal | "-_-", "oke.", "alvast" |
| **Dirk** | Beleefd, HR-toon, herhaalt getallen terug | "Alvast bedankt!", "Ik noteer het alleen." |

---

## Algemene NPC-dialogen (`data/dialogue/npcs.json`)

De algemene dialogen triggeren wanneer de speler een NPC aanspreekt buiten een actief ticket-moment. Ze reageren op `min_tickets_done`, op flags uit eerdere gesprekken, en op het trait van de gekozen character.

---

### Dennis *(Scrum Master, patrols de gang)*

**Context:** Dennis loopt zijn vaste ronde. Hij heeft het bord al bijgewerkt.

```
Dennis start [bezocht]:  "Oh, jij nog een keer. Bord staat nog goed."
Dennis start [default]:  "Alles staat op het bord. Heb ik vanmorgen alvast bijgewerkt."

Dennis: [< 4 done] "Ik heb de issues alvast nagelopen. Verder heb ik niks nodig."
Dennis: [≥ 4 done] "De helft. Ik heb de rest alvast nagelopen en grof geschat."
Dennis: [≥ 8 done] "Nog twee. Is maar weekje later."

→ [Keuze] "Het gaat goed."
     Dennis: "oke."
     [flag: dennis_bezocht = true]
→ [Keuze] "Het is een puinhoop."
     Dennis: "-_- ik deploy het wel."
     [flag: dennis_weet_het = true, dennis_bezocht = true]
→ [Keuze] "Ik heb even geen tijd."
     Dennis: "oke. andere mogelijkheid is er niet."
     [flag: dennis_bezocht = true]

Dennis slot [dennis_weet_het]: "Ik heb het al aangepast. Zei ik niks over."
Dennis slot [default]: "Cool. thanks is gedaan."
```

---

### Koen *(Backend, Het Patchhok)*

**Context:** Koen zit in het Patchhok. Hij is bezig maar heeft er geen haast mee.

```
Koen start [bezocht + koen_verborgen_voor_jonathan]: "Is Jonathan al weg? Psst. Lekker ouwe."
Koen start [bezocht + koen_piepelienies_uitgelegd + ≥ 6]: "piepelienies lopen nog steeds. heb ze goed ingesteld haha."
Koen start [bezocht]:  "Ah, ben je er weer. Ik zit in een andere rabbit hole. Geen zorg haha."
Koen start [≥ 6]:     "De logs zijn stil. Is weer een pareltje hoor haha."
Koen start [default]: "Ik zal even kijken. Het duurt nog veertig minuten, vgm."

Koen: "Zeg maar niets tegen Jonathan, lekker ouwe. Dan komt hij meekijken."
Koen: [< 6] "Ik kijk straks nog even naar de piepelienies. Iets met een timeout, vgm."
Koen: [≥ 6] "De piepelienies lopen trouwens weer. Took a while haha."

Koen: "Wat is er?"
→ [Keuze] "Wat zijn piepelienies precies?"
     Koen: "piepelienies. ci/cd. build, test, deploy. maar dan lekker. en als ze kapot zijn duurt het veertig minuten, vgm."
     [flag: koen_piepelienies_uitgelegd, koen_bezocht]

→ [Keuze] "Jonathan zoekt je."
     Koen: "Ah nee. Zeg maar dat ik in een call zit, lekker ouwe."
     [flag: koen_verborgen_voor_jonathan, koen_bezocht]

→ [Keuze] "Niets. Ga zo door."
     [flag: koen_bezocht]
```

---

### Bastiaan *(Frontend, De Vloer)*

**Context:** Bastiaan zit voorover gebogen. Hij is ergens mee bezig waar hij zelf niet helemaal uit komt.

```
Bastiaan start [bezocht + bastiaan_component_gevraagd + ≥ 5 done]: "hiya,, de accordion is klaar,, hij klapt perfect,, ik maak er nog een,,"
Bastiaan start [bezocht + bastiaan_komt_meekijken]:                "hiya,, ik kom zo,, ik moet alleen nog even,, ik kom echt zo,,"
Bastiaan start [bezocht + ≥ 7 done]: "hiya,, alles is groen,, ik vertrouw het niet,,"
Bastiaan start [bezocht + ≥ 3 done]: "ah jij nog een keer,, ik ben dezelfde component nog aan het verbeteren,, hij is nu echt goed,,"
Bastiaan start [bezocht]:            "hiya nog een keer,, ik ben er nog,,"
Bastiaan start [≥ 7 done]:          "Ik heb de hele build nagelopen,, er zit niets fout in,, dat vertrouw ik niet."
Bastiaan start [≥ 3 done]:          "Ik heb een component gemaakt die niemand nodig heeft,, nog niet."
Bastiaan start [default]:            "hiya,, ik zit nog in een ticket van vorige week,, ik kom er wel uit."

Bastiaan tweede [trait: technisch]: "Kijk je straks even mee,, niet nu,, straks."
Bastiaan tweede [trait: detail]:    "trouwens,, de marge onderaan is vier pixels te veel,, jij zag dat ook hè."
Bastiaan tweede [default]:          "Je mag het niet doorvertellen,, maar ik vind die blauwe versie ook mooi,,"

Bastiaan: ",,"
→ [Keuze] "Wat bouw je?"
     Bastiaan: "een accordion component,, maar dan eentje die echt goed werkt,, hij klapt uit en in,, niemand heeft hem gevraagd,, maar hij bestaat nu,,"
     [flag: bastiaan_component_gevraagd, bastiaan_bezocht]

→ [Keuze] "Kijk je mee straks?"
     Bastiaan: "ja,, wanneer,, zeg maar wanneer,, ik ben er,,"
     [flag: bastiaan_komt_meekijken, bastiaan_bezocht]

→ [Keuze] "Oke."
     [flag: bastiaan_bezocht]
```

---

### Klant — Mevrouw P. Aardenmens *(Entree)*

**Context:** Ze is te vroeg. Ze heeft elf paarden en één website.

> **Eén klant, twee kanalen.** Wat zij in de entree zegt en wat er via
> `klant_berichten.json` op je telefoon binnenkomt is dezelfde vrouw. Haar
> twee UX-reviewers liggen daarmee vast: de **schoonzus** die het bekeken
> heeft en er iets van vond, en de **neef** die zei dat het in een weekend
> kan. Ze had hier eerst een kleinzoon en een echtgenoot-hovenier, en dan
> zijn het twee verschillende mensen die toevallig dezelfde manege bezitten.

```
Klant: [t03 niet done] "Ik ben iets te vroeg. Dat doe ik altijd."
Klant: [t03 done] "Ik wacht op de taxi. Uw koffie is trouwens erg sterk."

Klant tweede [trait: technisch]: "U bent zeker de computerman. Mijn neef doet ook iets met computers. Hij zei dat het in een weekend kan."
Klant tweede [trait: commercieel]: "U bent van het praten, zie ik. Prettig, dan hoef ik het niet zelf uit te leggen."
Klant tweede [default]: "Ik heb elf paarden en één website. Met de paarden gaat het beter."

Klant: "Mijn schoonzus vindt blauw mooier. Zij doet iets met tuinen, maar ze heeft er wel oog voor."
```

---

### Bezorger *(Verschijnt na BBD-208)*

**Context:** Bezorger komt een doos brengen. Er zit stro in.

```
Bezorger: "Bestelling voor Bluebird Day. Van Manege De Vrije Teugel."
[Omschrijving] "Hij zet een doos neer. Er zit stro in en twaalf potten supplement."

Bezorger [t09 done]: "Mevrouw vroeg of de paarden goed zijn aangekomen. Ik heb gezegd van wel."
Bezorger [default]: "Ze zei: geef maar aan degene die de website doet. Dus veel succes met uitzoeken."
```

---

### Dirk *(HR, verschijnt na 5 opgeloste tickets)*

**Context:** Dirk Schrijver loopt zijn eigen route door de gang en vraagt naar
je urenstaat. Zijn gesprek (`dirk`) is de gewone route via `dialogue_id`; een
tweede boom (`dirk_urenstaat`) wordt nooit gewandeld — die staat er alleen
zodat zijn stem in de data zit voor `_test_karakterstemmen()` en om zijn
slotregel na de urenstaat-minigame te leveren. `ticket_controller.gd::
_dirk_oordeel()` kiest die regel op de payload van de minigame (`op_rest`,
`lege_tickets`), niet op een `Conditions`-vlag — een node kiezen op een getal
in plaats van op een flag.

```
Dirk start [uren_geboekt]:  "Hoi {naam}, ik zie dat je vandaag {geboekt} hebt geboekt. Dank je!"
Dirk start [overwerk]:      "Hoi {naam}, het is {klok}. Ik zie dat je nog aan het werk bent. Dat mag natuurlijk."
Dirk start [default]:       "Hoi {naam}, even een klein seintje. Heb je even?"

Dirk: [uren_geboekt + overwerk] "Er staat nu {geboekt} geboekt en je hebt {gewerkt} gewerkt. Dat verschil kan ik niet boeken. Ik laat het even zo."
Dirk: [uren_geboekt]             "Mocht er later nog iets bij komen, dan vul je het gewoon aan."
Dirk: [overwerk]                 "Er staat vandaag {geboekt} geboekt, terwijl de verwachting rond de {gewerkt} ligt. Je bent nu over je dag heen. Ik noteer het alleen."
Dirk: [default]                  "Er staat vandaag tot nu toe {geboekt} geboekt, terwijl de verwachting rond de {gewerkt} ligt. Zou je je uren aanvullen als er nog wat mist?"

Dirk: [uren_geboekt] "Fijn dat het compleet is. Alvast bedankt!"
Dirk: [default]      "Ik probeer jullie zo goed mogelijk te helpen met de voortgang op projecten, en daarvoor helpt een complete urenregistratie enorm. Alvast bedankt!"

→ [Keuze] "Goed, ik boek ze nu."
     Dirk: "Top. Ik zet je urenstaat er even bij." [outcome: boeken]
→ [Keuze] "Ik loop ergens tegenaan."
     Dirk: "Dat snap ik. [...] Je kunt terecht bij mijn collega Dennis, die denkt graag met je mee."
     Dirk: "Ik loop zelf ook nog even mee, voor het geval het je toch te binnen schiet." [outcome: doorgestuurd]
→ [Keuze] "Ik heb even geen tijd."
     Dirk: "Geen probleem hoor. Ik kom er later op terug."
     Dirk: [overwerk] "Je bent trouwens {gewerkt} aan het werk. Zou je daar {budget} van willen boeken?"
     Dirk: [default]  "Zou je het voor het einde van de dag doen? Dan hoef ik er niet nog een keer over te beginnen." [outcome: afgehouden]
```

Zijn terzijde (`data/npcs.json`, `barks`) geeft het toe: **"Ik ben een
stockfoto. Mijn urenstaat is echt."** (`03f52e1`, na de playtestronde van
4 september) — de enige NPC die zijn eigen kunstmatigheid benoemt.

Dirk deelt zijn `role`-veld ("Scrum Master") met Dennis in `data/npcs.json`,
en dat is geen bug: Dirk is een AI-scrummaster, Dennis de "echte". De grap is
dat ze exact hetzelfde werk doen — Dirk vermindert Dennis' werkdruk met
precies nul. Het gedeelde veld is die grap, niet een copy-paste-foutje.

---

### Collega Daan *(Summit — als NPC voor andere characters)*

```
Daan start [bezocht + daan_op_de_hoogte]: "Heb je dat ding gevonden dat je dwars zat?"
Daan start [bezocht + daan_goed_nieuws + ≥ 6 done]: "Jij zei dat het goed liep. Dat klopt nog steeds, hoop ik."
Daan start [bezocht]:        "Al iets gevonden?"
Daan start [≥ 8 done]:      "Bijna. Ik durf het bijna hardop te zeggen."
Daan start [≥ 5 done]:      "De helft staat. De helft die overblijft is altijd de lastigste helft."
Daan start [≥ 2 done]:      "We hebben scope. Dat is wellicht nieuw voor ons."
Daan start [default]:        "Ik heb de tickets op volgorde gezet. Wilde het mezelf zo makkelijk mogelijk maken."

Daan tweede [trait: technisch]:   "Kom je iets tegen dat niet in het ticket staat? Puur uit interesse: waar kwam dat dan vandaan."
Daan tweede [trait: commercieel]: "Als de klant belt: doorverbinden. Naar Willem. Altijd naar Willem."
Daan tweede [default]:            "Zeg het als iets niet klopt. Liever nu dan bij de oplevering."

Daan: "Hoe zit het?"
→ [Keuze] "Alles loopt goed."
     Daan: "Dat is fijn om te horen. Echt."
     [flag: daan_goed_nieuws, daan_bezocht]

→ [Keuze] "Er is iets wat me dwars zit."
     Daan: "Zeg het maar."
     Speler [trait: technisch]: "De backend gedraagt zich raar."
     Speler [trait: commercieel]: "De klant verwacht meer dan in het ticket staat."
     Speler [default]: "Ik weet het nog niet precies."
     Daan [technisch]: "Jonathan weet dat. Of Jonathan heeft het gemaakt."
     Daan [commercieel]: "Doorverbinden naar Willem. Die weet hoe hij dat landt."
     Daan [default]: "Dan is het waarschijnlijk in een ticket. Zet het er anders in."
     [flag: daan_op_de_hoogte, daan_bezocht]

→ [Keuze] "Niets bijzonders."
     Daan: "Mooi. Dan laat ik je verder met rust."
     [flag: daan_bezocht]
```

---

### Collega Danny *(Basecamp — als NPC voor andere characters)*

```
Danny start [bezocht + danny_tip_gekregen]: "die tip van jou klopt trouwens. heb er een test op gezet."
Danny start [bezocht + danny_test_uitgelegd + ≥ 5 done]: "de test van die knop is klaar. groter wint. psies."
Danny start [bezocht]:        "ah jij nog. psies. ik ben een test aan het analyseren."
Danny start [≥ 8 done]:      "joejoe. de cijfers lopen op. ik beloof nog niets"
Danny start [≥ 4 done]:      "ik heb een test lopen. vraag me over drie dagen wat eruit komt"
Danny start [default]:        "ik kijk naar wat mensen doen, niet naar wat ze zeggen. dat scheelt veel"

Danny tweede [trait: data]:   "psies. meningen zijn ruis. gedrag is data"
Danny tweede [trait: detail]: "de knop staat twee pixels scheef. kost ons niets, maar ik zeg het toch"
Danny tweede [default]:       "alles is een funnel. de gang ook. mensen lopen linksom, altijd"

Danny: "?"
→ [Keuze] "Wat test je?"
     Danny: "kijken of mensen eerder klikken als de knop groter is. of roder. of allebei. drie varianten. morgen weten we het."
     Danny: "wat denk jij?"
     → "Groter."      → Danny: "psies. dat is het. maar bewijs het zelf maar."
     → "Roder."       → Danny: "dat zegt iedereen. data zegt iets anders. biem."
     → "Dat hangt ervan af." → Danny: "ah. je bent een van ons."
     [flag: danny_test_uitgelegd, danny_bezocht]

→ [Keuze] "Ik zag iets in het gedrag van de gebruikers."
     Speler [trait: data]: "Ze haken af op de tweede stap."
     Speler [default]: "Ze scrollen niet naar beneden."
     Danny [data]: "dat weet ik. maar goed dat jij het ziet. zet hem in een segment."
     Danny [default]: "de fold. het is altijd de fold. biem."
     [flag: danny_tip_gekregen, danny_bezocht]

→ [Keuze] "Ga door."
     [flag: danny_bezocht]
```

---

### Collega Victor *(De Vloer — als NPC voor andere characters)*

```
Victor start [bezocht + victor_entree_gemeld]: "Die drie pixels bij de entree. Gefixed. Niemand zag het. Behalve jij. En ik."
Victor start [bezocht + victor_compliment]:    "Ik heb de build nog een keer gecheckt. Klopt nog steeds. Voor nu."
Victor start [bezocht]:        "Oh. Is er iets scheef?"
Victor start [≥ 8 done]:      "De build is groen. Done."
Victor start [≥ 4 done]:      "manmanman. Ik heb vandaag drie dingen rechtgezet die niemand scheef zag staan."
Victor start [default]:        "Ik bouw wat anderen bedenken. Ik vraag alleen of iemand het heeft nagedacht."

Victor tweede [trait: detail]: "Kijk eens naar de tweede rij. Nee? Precies. Dat is het probleem."
Victor tweede [trait: proces]: "Zet het in een ticket. Anders bestaat het niet en doe ik het toch. hahaha"
Victor tweede [default]:       "Als je iets scheef ziet staan, zeg het. Dan zie ik het ook en slaap ik slechter."

Victor: "wat?"
→ [Keuze] "Er zit iets scheef bij de entree."
     Victor: "Welke kant?"
     Speler [trait: detail]: "Links. Drie pixels."
     Speler [default]: "Links, denk ik."
     Victor: "Dat dacht ik al. Ik fix het. Godver."
     [flag: victor_entree_gemeld, victor_bezocht]

→ [Keuze] "De build ziet er goed uit."
     Victor: "Dat zei ik ook. Maar ik vertrouw het nog niet. Hahaha."
     [flag: victor_compliment, victor_bezocht]

→ [Keuze] "Oke."
     [flag: victor_bezocht]
```

---

### Collega Jonathan *(Het Patchhok — als NPC voor andere characters)*

```
Jonathan start [bezocht + jonathan_alert]:   "Die E die je noemde was een W. Ben er toch even naartoe gegaan."
Jonathan start [bezocht + jonathan_logs_ok]: "Logs nog steeds ok. Moet zeggen dat dat me verbaast."
Jonathan start [bezocht]:        "Ik ga er naartoe kijken, voor je het vraagt."
Jonathan start [≥ 8 done]:      "De verbinding staat. Ben benieuwd hoe lang."
Jonathan start [≥ 4 done]:      "Ik heb iets gerepareerd dat niemand kapot heeft zien gaan. Dat is het werk."
Jonathan start [default]:        "Als je mijn werk ziet, is er iets stuk. Dus je ziet me het liefst niet."

Jonathan tweede [trait: technisch]:   "Zie je iets in de logs met een hoofdletter E: dat ben ik niet. Ik ga er wel naartoe kijken."
Jonathan tweede [trait: commercieel]: "Beloof niets over snelheid. Ik weet niet waar die vandaan moet komen."
Jonathan tweede [default]:            "Het werkt lokaal. Moet zeggen dat dat ook iets is."

Jonathan: "."
→ [Keuze] "Er is iets in de logs."
     Jonathan: "Welke letter?"
     Speler [trait: technisch]: "Een E. En er staan er drie."
     Speler [default]: "Een hoofdletter. Weet niet welke."
     Jonathan [technisch]: "Drie E's. Eén is echt, twee zijn gevolgen. Ik ga er naartoe kijken."
     Jonathan [default]: "Als het een E is, ben ik het niet. Anders ook niet. Ik ga er naartoe kijken."
     [flag: jonathan_alert, jonathan_bezocht]

→ [Keuze] "Logs zien er goed uit."
     Jonathan: "Dat zei ik ook. Niemand gelooft het als ik het zeg."
     [flag: jonathan_logs_ok, jonathan_bezocht]

→ [Keuze] "Niets van belang."
     Jonathan: "Mooi. Ben benieuwd."
     [flag: jonathan_bezocht]
```

---

### Collega Willem *(Doorheen kantoor — als NPC voor andere characters)*

```
Willem start [bezocht + willem_klant_blij]:  "Ze heeft nóg een keer gebeld. Absoluta... ehh, Looff. Ook blij. Dat is uitzonderlijk."
Willem start [bezocht + willem_vragen_op]:   "Die vragen van de klant heb ik beantwoord. Twee van de drie kloppen ook."
Willem start [bezocht + willem_wacht]:       "Ze heeft nog niet teruggebeld. Ik sta klaar."
Willem start [bezocht]:        "Ben net terug. Ze is rustig. Voorlopig."
Willem start [≥ 8 done]:      "Ik heb de klant gesproken. Ze is heeeel enthousiast, en dat is nu nog terecht."
Willem start [≥ 4 done]:      "Ik heb drie dingen toegezegd aan Absoluta... ehh, Looff. Twee daarvan kunnen ook echt."
Willem start [default]:        "Ik hou de klant bij je vandaan. Dat is geen grap, dat is de functieomschrijving. En het levert O-M-Z op."

Willem tweede [trait: technisch]: "Zeg tegen mij dat iets niet kan. Ik vertaal het wel naar iets vriendelijkers."
Willem tweede [trait: sociaal]:   "Jij begrijpt het. Nee zeggen kost een uur. Ja zeggen kost een kwartaal."
Willem tweede [default]:          "Als ze belt, ben ik in het hokje. Ook als ik daar niet ben."

Willem: "Heeft ze al gebeld?"
→ [Keuze] "Nog niet."
     Willem: "Dat duurt niet lang meer. Ze belt altijd terug."
     [flag: willem_bezocht]

→ [Keuze] "Ze belde al."
     Willem: "Wat zei ze?"
     → "Blij."        → Willem: "Gelukkig. Anders had ik nu gerend. Heeeel snel."    [flag: willem_klant_blij]
     → "Vragen."      → Willem: "Geef ze maar aan mij. Ik vertaal ze naar iets uitvoerbaars." [flag: willem_vragen_op]
     → "Ze belt terug." → Willem: "Ah. Dan ga ik vast klaarstaan. Absoluta... ehh, Looff."              [flag: willem_wacht]
     [flag: willem_bezocht]

→ [Keuze] "Oke, ga door."
     [flag: willem_bezocht]
```

---

## Wereld-dialogen (`data/dialogue/wereld.json`)

19% van alle dialoog (68 nodes over 28 objecten) en tot nu toe het enige
dialoogbestand dat in dit document ontbrak. Spreker is bijna overal `""`
(de omgeving zelf, geen personage) — dit zijn de dingen die je aantikt in de
wereld, los van een ticket of collega. Twee objecten laten de speler zelf aan
het woord (`nooduitgang`, trait `proces`) of het personage van dat moment
(geen ander object doet dat). Twintig van de 28 hebben maar één node: een
observatie zonder keuze, die via `variants`/`when` meebeweegt met voortgang,
tickets, trait of tijd. Vijf hebben een echte keuze (`nooduitgang`, `prikbord`,
`koffiemachine`, `whiteboard`) — de rest observeert alleen.

| Object | Nodes | Keuze? | Opent met |
|---|---|---|---|
| `voordeur` | 3 | nee | "De deur staat open. Buiten is het nog licht." |
| `nooduitgang` | 4 | **ja** | "Nooduitgang. Op het bordje staat: alleen bij brand." |
| `ticketbord` | 3 | nee | "Het ticketbord. Tien tickets, allemaal met BBD ervoor." |
| `printer` | 2 | nee | "De printer meldt een storing. Welke storing staat er niet bij." |
| `prijzenkast` | 2 | nee | "Een kast met vier prijzen. Twee ervan zijn van een bureau dat is overgenomen." |
| `kapstok` | 2 | nee | "Vier jassen. Drie ervan hangen hier het hele jaar." |
| `prikbord` | 4 | **ja** | "Een prikbord vol losse briefjes. Niemand weet meer welke nog geldig zijn." |
| `scherm_entree` | 2 | nee | "Op het scherm rent een paard door een weiland. De lus duurt twaalf seconden." |
| `koffiemachine` | 5 | **ja** | "De koffiemachine. Er zit een sticker op: niet de middelste knop." |
| `koelkast` | 2 | nee | "In de koelkast staat melk met een naam erop. De naam is doorgestreept." |
| `bureau_victor` | 2 | nee | "Twee schermen, precies even hoog afgesteld. Met een waterpas." |
| `bureau_bastiaan` | 2 | nee | "Zes koffiebekers, netjes op een rij. Van links naar rechts steeds ouder." |
| `bureau_danny` | 2 | nee | "Drie dashboards en één plant. De plant heeft geen dashboard." |
| `loungehoek` | 2 | nee | "Twee banken en een lage tafel. Op tafel ligt een boek over merkstrategie." |
| `beamer` | 2 | nee | "De beamer staat aan sinds de vorige vergadering." |
| `whiteboard` | 4 | **ja** | "Op het whiteboard staan een pijl, een wolk en het woord 'later'." |
| `serverrack_b` | 2 | nee | "Het tweede rack. Er hangt een label op: oud, niet uitzetten." |
| `badgelezer` | 2 | nee | "De badgelezer bij het Patchhok. Groen lampje, dus vandaag doet hij het." |
| `wc_poster` | 2 | nee | "Een poster naast de spiegel: elk idee begint met een goede vraag." |
| `wastafel` | 2 | nee | "De kraan loopt drie seconden na. Elke keer precies drie." |
| `plotter` | 2 | nee | "De grootformaatplotter. Aangeschaft voor één klant, in 2019." |
| `gang_plant` | 2 | nee | "Een plant in de gang. Kunststof, en toch krijgt hij water." |
| `plantenkast` | 3 | nee | "De plantenkast. Het speelgoedpaard staat er nog." |
| `urinoirs` | 2 | nee | "Twee urinoirs en één pot, in een ruimte zo groot als een vergaderzaal." |
| `tribune` | 2 | nee | "De tribune. Teal, met kussens die niemand rechtlegt." |
| `blauwe_tijger` | 2 | nee | "Een blauwe tijger, levensgroot, midden in de gang." |
| `samen_bingo_poster` | 2 | nee | "Op de houten zijde van het hokje hangt een poster: SAMEN BINGO." |
| `hokje_telefoon` | 2 | nee | "Een vaste telefoon in het vergaderhokje. Er zit nog een snoer aan." |

Twee volledig uitgeschreven, als voorbeeld van hoe de rest is opgebouwd:

```
### nooduitgang — tijdlek, gedicht in Fase 1 (kost_tijd: 15, ongated → één keer)

start: "Nooduitgang. Op het bordje staat: alleen bij brand."
→ [Keuze] "De deur opendoen." [flags_none: alarm_af]
     "Het alarm gaat. Iedereen loopt naar buiten, ook de mensen van het bureau
     hiernaast. Dennis telt ze. Er is geen brand, en dat moet ook geteld
     worden." [kost_tijd: 15, toast: "Iedereen staat buiten. Vijftien minuten.",
     flag: alarm_af]
→ [Keuze] "Er niet aan komen."
     [trait: proces] Speler: "Dit is geen brand. Dit is een sprint."
     [default]        Speler: "Er staat niet bij wat je moet doen als het geen
                       brand is."

Herbezoek [alarm_af]: "De stang zit op borsthoogte. Er hangt nu een briefje op:
NIET NOG EEN KEER. Dennis."
Herbezoek [default]:  "De stang zit op borsthoogte. Er hangt geen slot op."
```

```
### koffiemachine

start: "De koffiemachine. Er zit een sticker op: niet de middelste knop."
→ [Keuze] "De middelste knop indrukken." [flags_none: koffie_middelste]
     "Er gebeurt drie seconden niets. Dan komt er koffie uit, gewoon koffie,
     en een geluid dat een machine niet hoort te maken. De sticker hangt er
     nog." [kost_tijd: 5, flag: koffie_middelste]
→ [Keuze] "Gewoon een koffie halen." [flags_none: koffie_gehaald]
     [kost_tijd: 5, flag: koffie_gehaald]
→ [Keuze] "Niets nemen."

Herbezoek [koffie_middelste]: "De middelste knop doet het gewoon. Je zegt er
niets over."
Herbezoek [koffie_gehaald]:   "Je hebt vandaag al koffie gehad. Dat weerhoudt
niemand hier."
Herbezoek [t07 done]:         "Uit de speaker komt de nieuwe merksound. Iemand
heeft het volume alweer lager gezet."
Herbezoek [≥3 tickets]:       "Er staat een schaal koeken naast. Briefje van
Dennis: omdat ik gisteren weer een jaartje ouder ben geworden."
Herbezoek [trait: detail]:    "Nergens staat waarom niet. Dat is erger dan de
knop zelf."
Herbezoek [default]:          "Je drukt de tweede knop. Er komt soep uit. Dat
is bekend."
```

---

## Ticket-dialogen (`data/dialogue/tickets.json`)

Per ticket: 6 fases. `offer` = aanbieding, `fetch` = tussenstand, `recruit` = collega ophalen
(begint altijd bij de **speler**, die het ticketnummer noemt en zegt waar hij vastloopt --
elk personage dat die werving kan spelen heeft daar zijn eigen regel; de eigenaar niet,
die haalt zichzelf nooit op), `complete` = succes, `fail` = mislukking, `done` = al opgelost.

> Varianten staan gemarkeerd met `[character]` of `[trait]`. Default variant = geen condition.

---

## T01 — BBD-201: Wat moeten we eigenlijk bouwen?
**Owner:** Daan | **Locatie:** Z5 Summit | **Minigame:** mg_user_story

### t01_offer

```
[Omschrijving] Op de vergadertafel ligt een A4. Er staat een zin op. Nergens een 'zodat'.

Speler [daan]: "Ik heb dit zelf opgeschreven. Tussen twee gesprekken door. Dat is te zien."
Speler [trait: technisch]: "Ik kan dit bouwen. Ik weet alleen niet wat 'dit' is."
Speler [trait: data]: "Er staat geen doel in. Dan valt er straks niets te meten."
Speler [default]: "Dit is geen user story. Dit is een wens."

[Omschrijving, daan]: "Niemand spreekt je tegen. Dat is het vervelende aan Product Owner zijn."
Daan [anderen]: "Het is een wens. Van de klant. Dus het is een risico."

Speler [daan]: "Dan schrijf ik hem nu opnieuw. Met een 'zodat'."
Speler [default]: "Dan maken we er een zin van waar iemand iets aan heeft."
```

### t01_fetch

```
[Omschrijving] Het A4 ligt er nog. Eén zin. Jij mag hier eigenlijk niets van vinden.

Speler [trait: technisch]: "Ik kan het bouwen. Ik kan het niet bedenken. Daar is Daan voor."
Speler [default]: "Scope is van Daan. Ik ga hem halen."
```

### t01_recruit

```
Speler [Danny]: "daan, BBD-201. er ligt een story van één zin. ik ga daar geen funnel op bouwen."
Speler [Victor]: "Daan, BBD-201. Er staat één zin in. Ik ga daar geen scherm van bouwen."
Speler [Jonathan]: "Daan, ik loop vast op BBD-201. Er staat een wens, geen criterium. Ben benieuwd wat jij ervan maakt."
Speler [Willem]: "Heeee Daan. BBD-201. Ik kan de klant niet vertellen wat we bouwen zolang het er niet staat."
Speler [Bastiaan]: "daan,, BBD-201,, ik weet niet wat ik moet bouwen,, er staat één zin,,"
Speler [Koen]: "Daan, ik check BBD-201 even met je. Eén zin, geen story. Dat wil ik niet gokken."
Speler [default]: "Daan, ik loop vast op BBD-201. Er ligt een user story die geen user story is, en ik ga niet zelf verzinnen wat er bedoeld wordt."

Daan: "Wat ligt er?"
Speler: "Eén zin."
Daan: "Dan is het geen story. Ait. Ik loop mee."
```

### t01_complete

```
Speler [daan]: "Er staat nu een 'zodat' in. Dit is letterlijk waar ik voor word betaald."
Daan [anderen]: "Er staat nu een 'zodat' in. Dat is mijn hele vak, in vijf letters."

[Omschrijving] Op het whiteboard staat één zin. Iedereen leest hem twee keer. Niemand vraagt iets.

Speler [trait: technisch]: "Nu kan ik het bouwen."
Speler [trait: commercieel]: "Nu kan ik het uitleggen aan de klant."
Speler [default]: "Dat is dan afgesproken."
```

### t01_fail

```
Speler [daan]: "Er staan nu twee wensen in één zin. Dat heet een epic. Dat is erger."
Speler [trait: technisch]: "Dit is nog steeds niet te bouwen."
[Omschrijving, default]: "De zin is langer geworden. Duidelijker is hij niet."

[Omschrijving, daan]: "Je pakt de stift terug."
Daan [anderen]: "Nog een keer. Korter."
```

### t01_done

```
[Omschrijving] Op het whiteboard staat een echte user story. Iemand heeft er een hartje bij getekend.
```

---

## T02 — BBD-202: Waarom sta ik hier eigenlijk?
**Owner:** iedereen (sinds 5 sep 2026; briefer: Daan, niet op te halen) | **Locatie:** Z9 De Vloer | **Minigame:** mg_planning

### t02_offer

```
[Omschrijving] Op het scrumbord staat jouw naam drie keer. Twee keer bij een project dat vorig jaar is opgeleverd.

Speler [daan]: "Ik heb deze planning zelf gemaakt. Dat wil ik even benoemd hebben."
Speler [trait: data]: "Drie keer ingepland, één persoon. Dat is driehonderd procent bezetting."
Speler [trait: technisch]: "Ik sta op een project dat niet meer bestaat."
Speler [default]: "Sta ik hier nou wel of niet?"

Dennis: "Dat is bewust. Dat heet flexibel plannen."

Speler: "Ik wil op één project staan. Dit project."
```

### t02_complete

```
Speler [daan]: "Eén naam, één project, één sprint. Dit is mijn werk in drie woorden."
Speler [default]: "Eén naam, één project, één sprint. Meer is het niet."

Dennis: "Mooi. Ik zet hem ook in de tool. Daar staat hij dan anders."

Speler [trait: proces]: "Dan passen we de tool aan."
Speler [trait: technisch]: "Dan is de tool stuk."
Speler [default]: "Daar kijken we later naar."
```

### t02_fail

```
Speler [daan]: "Ik sta nu op vier projecten. Dat is groei."
Speler [trait: data]: "De bezetting staat nu op vierhonderd procent. Dat is meetbaar fout."
[Omschrijving, default]: "Je staat nu op vier projecten. Eén daarvan is de kerstborrel."

Dennis: "Zullen we opnieuw beginnen? Zonder oordeel."
```

### t02_done

```
[Omschrijving] Op het bord staat SPRINT 14. Jouw naam staat er één keer op. Dat blijft wennen.
```

---

## T03 — BBD-203: De klant heeft feedback
**Owner:** Willem | **Locatie:** Z1 Entree | **Minigame:** mg_klantfeedback

### t03_offer — Gesprek met Mevrouw P. Aardenmens

```
Klant: "Ik heb even wat puntjes opgeschreven. Het zijn er niet veel."
[Omschrijving] Het zijn er elf.
Klant: "Het logo mag groter. Maar niet te groot. En het moet premium worden. Maar ook speels."

→ [Keuze] "Vragen welk punt het belangrijkst is."
     Klant: "Ze zijn allemaal even belangrijk. Punt zeven is iets belangrijker."

→ [Keuze] "Vragen wat haar schoonzus ervan vindt."
     Klant: "Mijn schoonzus vindt blauw mooier. Mijn schoonzus doet iets met tuinen."

→ [Keuze] "Niets zeggen. Alles opschrijven."
     [Omschrijving] Je schrijft elf punten over. Mevrouw P. Aardenmens vindt dat een prettige werkwijze.

Speler [willem]: "Wij gaan hiermee aan de slag. In deze volgorde."
Willem [anderen]: "Wij gaan hiermee aan de slag. In een volgorde."
```

### t03_fetch

```
[Omschrijving] Mevrouw P. Aardenmens kijkt op. Ze heeft een mapje bij zich.

Speler [trait: technisch]: "Ik ga hier niets zeggen. Ik haal Willem."
Speler [default]: "Klanten zijn van Willem. Ik ga hem halen."
```

### t03_recruit

```
Speler [Daan]: "Willem, BBD-203. Ze zit in de entree met elf punten. Sorry wat moet ik daarmee."
Speler [Danny]: "willem, BBD-203. elf punten, drie spreken elkaar tegen. dat is jouw taal, niet de mijne."
Speler [Victor]: "Willem, BBD-203. Ze zit er. Elf punten. Godver."
Speler [Jonathan]: "Willem, BBD-203. Ze heeft elf punten en drie ervan sluiten elkaar uit. Ik ga daar niets over zeggen."
Speler [Bastiaan]: "willem,, BBD-203,, ze zit in de entree,, met een mapje,, ik durf niet,,"
Speler [Koen]: "Willem, BBD-203. Elf punten van de klant, drie kloppen niet samen. Ik weet niet zeker wat ik mag beloven."
Speler [default]: "Willem, ik loop vast op BBD-203. De klant zit in de entree met elf punten, en drie ervan spreken elkaar tegen."

Willem: "Zit ze er al?"
Speler: "Met een mapje."
Willem: "Dan zijn het elf punten van Absoluta... ehh, Looff. Ik kom eraan."
```

### t03_complete

```
Speler [willem]: "Elf punten, vier acties. Hier besta ik voor. Dit is O-M-Z."
Willem [anderen]: "Elf punten, vier acties. De rest was twee keer hetzelfde punt. En het is O-M-Z."

Klant: "Fijn dat u zo goed luistert."

[Omschrijving, willem]: "Je hebt niet alles beloofd. Voor jou is dat een goede dag."
Speler [trait: technisch]: "Ik ga terug naar iets dat gewoon een foutmelding geeft."
Speler [default]: "Ze heeft ja gezegd. Volgens mij."
```

### t03_fail

```
Speler [willem]: "Ik heb punt vier en punt negen allebei toegezegd. Die sluiten elkaar uit."
[Omschrijving, default]: "Punt vier en punt negen zijn allebei doorgevoerd. Ze sluiten elkaar uit."

Klant: "Het logo is nu groter en kleiner. Dat is knap."

Speler [willem]: "Ik doe het opnieuw. En nu kies ik."
Willem [anderen]: "Nog een keer. En nu kiezen we."
```

### t03_done

```
[Omschrijving] De bank is leeg. Het mapje ligt er nog. Niemand raakt het aan.
```

---

## T04 — BBD-204: De frontend is stuk
**Owner:** Victor | **Locatie:** Z9 De Vloer | **Minigame:** mg_frontend_fix

### t04_offer

```
[Omschrijving] Op de wandmonitor toont de staging. Het paard staat boven de header.

Speler [victor]: "En de CTA staat onder de footer. Dan is het geen CTA meer, maar een voetnoot."
Victor [anderen]: "En de CTA staat onder de footer. Dan is het geen CTA meer, maar een voetnoot."

[Omschrijving] De productfoto is 4000 pixels breed. De pagina laadt in elf seconden.

Speler [victor]: "Ik weet precies welke regel dit is. Ik weet ook wie hem heeft geschreven."
Speler [trait: data]: "Elf seconden. Daar wacht niemand op."
Speler [default]: "Kom, we zetten het recht."
```

### t04_fetch

```
[Omschrijving] Het paard staat boven de header. Het kijkt je aan.

Speler [trait: technisch]: "Ik kan CSS lezen. Ik kan deze CSS niet lezen. Ik haal Victor."
Speler [default]: "Dit is frontend. Dus dit is Victor."
```

### t04_recruit

```
Speler [Daan]: "Victor, BBD-204. Het paard staat boven de header. En ja, ik weet wat ik altijd roep. Nu even niet."
Speler [Danny]: "victor, BBD-204. de cta staat onder de footer. dan converteert hij nul. psies."
Speler [Jonathan]: "Victor, BBD-204. De productfoto is 4000 pixels breed. Niet mijn laag, maar het valt wel op."
Speler [Willem]: "Heeee Victor. BBD-204. Ik kan dit zo niet in een deck laten zien."
Speler [Bastiaan]: "victor,, BBD-204,, het paard staat boven de header,, dat is jouw ding,, niet het mijne,,"
Speler [Koen]: "Victor, BBD-204. De frontend ligt eruit en ik weet niet welke regel het is. Jij vgm wel."
Speler [default]: "Victor, ik loop vast op BBD-204. Het paard staat boven de header, de CTA onder de footer, en de productfoto is 4000 pixels breed."

Victor: "Welke pagina?"
Speler: "De productpagina."
Victor: "Godver. Ik weet het al. Ff kijken, ik loop mee."
```

### t04_complete

```
Speler [victor]: "Header boven, CTA in beeld, foto van 900 pixels. Dit is mijn werk en nu is het stil."
Victor [anderen]: "Header boven, CTA in beeld, foto van 900 pixels. Zo hoort het."

[Omschrijving] Op de wandmonitor staat: layout OK.

Speler [trait: data]: "Van elf seconden naar twee. Dat scheelt de mensen die anders weglopen."
Speler [trait: proces]: "Dan kan dit naar de review."
Speler [default]: "Het staat recht."
```

### t04_fail

```
Speler [victor]: "Nu staat het paard náást de header. Technisch gezien is dat vooruitgang."
[Omschrijving, default]: "Het paard staat nu naast de header. De footer is verdwenen."

[Omschrijving, victor]: "Je opent het bestand opnieuw. Je zegt niets."
Victor [anderen]: "Terug. En nu één ding tegelijk."
```

### t04_done

```
[Omschrijving] De wandmonitor staat op groen. 'staging: layout OK'. Victor heeft het niet meer aangepast.
```

---

## T05 — BBD-205: De backend is stuk
**Owner:** Jonathan | **Locatie:** Z3 Het Patchhok | **Minigame:** mg_backend_fix

### t05_offer

```
[Omschrijving] Op het schermpje van het rack: Product: undefined. Prijs: NaN. Voorraad: null.

Speler [jonathan]: "Lokaal werkt het."
Jonathan [anderen]: "Lokaal werkt het."

[Omschrijving, jonathan]: "Je hoort jezelf het zeggen. Het helpt niet."
Speler [anderen]: "De klant zit niet op jouw laptop."

Speler [jonathan]: "Ik volg de datastroom terug. Dit is letterlijk mijn werk."
Speler [trait: data]: "NaN is geen prijs. NaN is een excuus."
Jonathan [anderen]: "Geef me twee minuten en niemand die meekijkt."
```

### t05_fetch

```
[Omschrijving] Het rack staat er stil bij. De foutmelding ook.

Speler [trait: technisch]: "Dit is een datastroom. Ik volg hem terug. Dat doe ik zelf."
Speler [default]: "Jonathan moet dit oplossen. Ik ga hem halen."
```

### t05_recruit

```
Speler [Daan]: "Jonathan, BBD-205. De webshop verkoopt niets aan niemand. Sorry wat."
Speler [Danny]: "jonathan, BBD-205. prijs is NaN. dan meet ik niks meer. biem."
Speler [Victor]: "Jonathan, BBD-205. Undefined, NaN en null. Godver, Janny."
Speler [Willem]: "Heeee Jonathan. BBD-205. De webshop verkoopt op dit moment niets. Dat is wel top, maar dan andersom."
Speler [Bastiaan]: "jonathan,, BBD-205,, de prijs is NaN,, daar kan ik geen euroteken voor zetten,,"
Speler [Koen]: "Jonathan, BBD-205. Product undefined, prijs NaN, voorraad null. Verder check ik niet, dat is jouw laag."
Speler [default]: "Jonathan, ik loop vast op BBD-205. Product undefined, prijs NaN, voorraad null. De webshop verkoopt op dit moment niets aan niemand."

Jonathan: "Wat staat er?"
Speler: "Undefined, NaN en null."
Jonathan: "Alle drie. Moet zeggen dat dat bijna netjes is. Ik ga er naartoe kijken."
```

### t05_complete

```
Speler [jonathan]: "Vier producten, echte prijzen, echte voorraad. Als mijn werk opvalt is er iets stuk."
Jonathan [anderen]: "Vier producten, echte prijzen, echte voorraad. Nu valt het weer niet op."

[Omschrijving] Op het rack staat: productservice 200 OK.

Speler [trait: commercieel]: "Dan kunnen we het eindelijk verkopen."
Speler [trait: detail]: "De prijzen kloppen tot achter de komma."
Speler [default]: "Er staat weer iets in de webshop."
```

### t05_fail

```
Speler [jonathan]: "De prijs staat nu op nul euro. Technisch gezien is het opgelost."
[Omschrijving, default]: "De prijs staat nu op nul euro. De voorraad op min drie."

[Omschrijving, jonathan]: "Je rolt terug. Niemand heeft het gezien."
Jonathan [anderen]: "Rollback. En nu langzaam."
```

### t05_done

```
[Omschrijving] Het rack staat op groen. 'productservice: 200 OK'. Jonathan loopt er drie keer per dag langs om dat te controleren.
```

---

## T06 — BBD-206: Niemand koopt iets
**Owner:** Danny | **Locatie:** Z6 Basecamp | **Minigame:** mg_cro

### t06_offer

```
[Omschrijving] Op de dashboardmuur staat de conversie van deze week. Nul komma nul vier procent.

Speler [danny]: "Dat is geen conversie. Dat is een ongeluk."
Danny [anderen]: "Dat is geen conversie. Dat is een ongeluk."

Danny [danny als speler]: "Vierduizend bezoekers, één bestelling. Vanaf een IP-adres binnen dit pand."
Danny [anderen]: "Vierduizend bezoekers, één bestelling. Vanaf een IP-adres binnen dit pand."

Speler [danny]: "We kijken waar ze afhaken. We vragen niet waarom."
Speler [trait: technisch]: "De pagina doet het gewoon. Dat is dus niet genoeg."
Speler [default]: "Ergens tussen kijken en kopen gaat het mis."
```

### t06_fetch

```
[Omschrijving] Nul komma nul vier procent. Het staat er in grote cijfers bij.

Speler [trait: technisch]: "Ik lees liever logs dan mensen. Danny doet mensen."
Speler [default]: "Dit is conversie. Dus dit is Danny."
```

### t06_recruit

```
Speler [Daan]: "Danny, BBD-206. De conversie staat op nul komma nul vier. Ik werd helemaal waus."
Speler [Victor]: "Danny, BBD-206. Nul komma nul vier procent. Manmanman."
Speler [Jonathan]: "Danny, BBD-206. De webshop werkt technisch, dus dit is niet mijn laag. Ben benieuwd wat jij ziet."
Speler [Willem]: "Heeee Danny. BBD-206. De conversie is nul komma nul vier. Dat ga ik zo niet vertellen."
Speler [Bastiaan]: "danny,, BBD-206,, de shop werkt gewoon,, en toch koopt niemand iets,,"
Speler [Koen]: "Danny, BBD-206. Alles staat live en werkt, en de conversie is 0,04 procent. Het gedrag check ik niet, dat doe jij."
Speler [default]: "Danny, ik loop vast op BBD-206. De webshop werkt, en de conversie is nul komma nul vier procent. Dat is statistisch gezien niemand."

Danny: "Welk getal?"
Speler: "Nul komma nul vier."
Danny: "psies. dan is het de knop. het is altijd de knop. biem, ik loop mee"
```

### t06_complete

```
Danny [danny als speler]: "pluszeventien. lekker insmeren met olijfolie en gaan. dat is o-m-z"
Danny [anderen]: "pluszeventien procent o-m-z. de knop stond verkeerd. hij stond al jaren verkeerd."

[Omschrijving] Op de muur springt het getal om. Iemand in de loungehoek kijkt op en gaat weer verder.

Speler [trait: proces]: "Dan zet ik die wijziging in de sprint."
Speler [trait: detail]: "De knop staat nu ook recht."
Speler [default]: "Zeventien procent van bijna niets is nog steeds meer."
```

### t06_fail

```
Danny [danny als speler]: "De conversie staat nu op nul komma nul drie. Dat is ook een uitkomst."
[Omschrijving, default]: "De conversie staat nu op nul komma nul drie procent. Lager dan daarvoor."

[Omschrijving, danny]: "Je zet het terug. Je vertelt niemand hoe laag het even stond."
Danny [anderen]: "Terugzetten. En dan één ding tegelijk testen."
```

### t06_done

```
[Omschrijving] Conversie plus zeventien procent. Danny heeft er al een presentatie over. Elf slides.
```

---

## T07 — BBD-207: A tegen B
**Owner:** iedereen (sinds 5 sep 2026; briefer: Danny, niet op te halen) | **Locatie:** Z4 Koffiecorner | **Minigame:** mg_abgevecht

### t07_offer

```
[Omschrijving] In de koffiecorner staat een scherm aan. Op het scherm: A tegen B. In Jira staat verder niets.

Speler [danny]: "Ik heb dit ticket zelf aangemaakt. In maart. Ik weet niet meer waarom."
Speler [trait: technisch]: "Er staat geen aanvrager bij. Er staat helemaal niets bij."
Speler [default]: "Niemand weet waar dit vandaan komt. Het staat in Jira, dus het gebeurt."

[Omschrijving] Je zet het scherm aan. A tegen B. Drie klappen, meer niet.
```

### t07_complete

```
Speler [danny]: "A wint. Drie klappen, meer had ik niet nodig. Dat was de hele opdracht."
Speler [default]: "A wint. Drie klappen, meer had je niet nodig."

[Omschrijving] Het scherm toont de uitslag. Twee mensen kijken op en gaan verder met hun brood.

Speler [trait: detail]: "B stond bij de laatste klap al op tien procent. Dat had niemand gevraagd."
Speler [trait: commercieel]: "Dit kan ook onder de video."
Speler [default]: "A staat erop."
```

### t07_fail

Vier oplopende varianten, gestuurd door `Session.get_counter(&"ab_pogingen")`
(opgehoogd door `mg_abgevecht.gd` bij elk verlies, vóór deze dialoog speelt).
Data die naar B wijst is voor Danny per definitie niet datagedreven genoeg —
elke poging krijgt een absurdere reden om het nog een keer te proberen. Speel
je niet als Danny, dan zeg je zijn redenering zelf (`speler`, geen kale
Danny-spreker meer: het ticket is sinds 5 sep 2026 van iedereen).

```
Speler [danny, ≥4 verliezen]: "ik heb mijn hypothese aangepast. de hypothese is nu dat b wint. dus als b wint, heb ik niets geleerd. dus meet ik opnieuw."
Speler [danny, ≥3]: "oké. b wint drie keer op rij. dat is precies wat een outlier doet als je hem drie keer meet. door."
Speler [danny, ≥2]: "b wint weer. maar de steekproef is klein. en het was maandag. nog een keer."
Speler [danny, default]: "b wint. dat is data. één meting is geen meting."

Speler [anderen, ≥4]: "ik heb de hypothese aangepast. de hypothese is nu dat b wint. dus als b wint, hebben we niets geleerd. dus meten we opnieuw"
Speler [anderen, ≥3]: "oké. b wint consistent. dat is precies wat een outlier doet als je hem drie keer meet. we gaan door"
Speler [anderen, ≥2]: "b wint weer. maar de steekproef is klein. en het was maandag. nog een keer"
Speler [anderen, default]: "b wint. dat is data. laten we het nog een keer meten, want één meting is geen meting"
```

### t07_done

```
[Omschrijving] Op het scherm in de koffiecorner staat nog steeds A tegen B, met A als winnaar. Niemand heeft het uitgezet.
```

---

## T08 — BBD-208: De klant wil een AI-video
**Owner:** Koen | **Locatie:** Z8 Het Vergaderhokje | **Minigame:** mg_video

### t08_offer

```
[Omschrijving] In het vergaderhokje ligt een iPad. Op het briefje ernaast: paard rent gelukkig door weiland.

Speler [koen]: "Hoe zie je aan een paard dat het gelukkig is. Aan de oren, vgm."
Koen [anderen]: "Hoe zie je aan een paard dat het gelukkig is? Aan de oren."

[Omschrijving, koen]: "Er staat verder niets op het briefje."
Speler [anderen]: "Dat staat er niet bij."

Speler [koen]: "Dan tel ik de benen en noem ik het een pareltje."
Koen [anderen]: "Ik let op de benen. Vier is genoeg, lekker ouwe."
```

### t08_fetch

```
[Omschrijving] De iPad ligt in het vergaderhokje. Iemand heeft er een geeltje op geplakt: AI-VIDEO.

Speler [trait: technisch]: "Ik doe servers, geen paarden. Koen blijft daar rustiger onder."
Speler [default]: "Dit is iets voor Koen. Die heeft er waarschijnlijk al iets voor."
```

### t08_recruit

```
Speler [Daan]: "Koen, BBD-208. Een gelukkig paard in een weiland, met onze supplementen. Meer briefing is er niet."
Speler [Danny]: "koen, BBD-208. de klant wil een ai-video van een paard. aanzetten en kijken."
Speler [Victor]: "Koen, BBD-208. Een AI-paard. Manmanman."
Speler [Jonathan]: "Koen, BBD-208. Er moet een AI-video komen en ik weet niet waar dat draait. Ben benieuwd."
Speler [Willem]: "Heeee Koen. BBD-208. Een paard dat gelukkig door een weiland rent. Dat is de hele briefing."
Speler [Bastiaan]: "koen,, BBD-208,, de klant wil een ai-video,, van een paard,, met supplementen,,"
Speler [default]: "Koen, ik loop vast op BBD-208. Een paard dat gelukkig door een weiland rent terwijl het onze supplementen gebruikt. Meer briefing is er niet."

Koen: "Ah. De paardenvideo."
Speler: "Ja."
Koen: "Ik loop wel even mee, lekker ouwe. Iemand moet de benen tellen."
```

### t08_complete

```
Speler [koen]: "Vier benen, één staart, één paard. Ik heb er twee uur rustig naar zitten kijken."
Koen [anderen]: "Vier benen, één staart, één paard. Toch een pareltje, vgm."

[Omschrijving] Op het scherm in de entree rent een paard door een weiland. Het is grotendeels overtuigend.

Speler [trait: commercieel]: "Dit gaat de klant prachtig vinden."
Speler [trait: detail]: "In seconde zes doet het gras iets. Daar kijken we overheen."
Speler [default]: "Goed genoeg."
```

### t08_fail

```
Speler [koen]: "Vijf benen. Geen zorg. Dat krijgen we er wel af."
[Omschrijving, default]: "Het paard heeft vijf benen. Eén ervan loopt uit de maat."

[Omschrijving, koen]: "Je start de generatie opnieuw."
Koen [anderen]: "Gewoon opnieuw, lekker ouwe. En zet 'weiland' er nog een keer in."
```

### t08_done

```
[Omschrijving] De video draait in de entree. Elke ronde tel je de benen. Elke keer weer vier.
```

---

## T09 — BBD-209: Er lopen paardenbugs door het kantoor
**Owner:** Bastiaan | **Locatie:** Z9 De Vloer | **Minigame:** mg_paarden

### t09_offer

```
[Omschrijving] Er staat een pony bij de printer. In de gang staat er nog een. Ze zijn er sinds de laatste release.

Speler [bastiaan]: "ze zitten in mijn build,, ik heb ze niet gemaakt,, ze zijn er gewoon,,"
Bastiaan [anderen]: "ze komen uit de build,, ik heb het drie keer nagekeken,, ze renderen gewoon,,"

[Omschrijving] De pony bij de printer drukt met zijn neus op Kopiëren. Er komen elf pagina's uit.

Speler [bastiaan]: "we drijven ze bij elkaar,, en dan tel ik ze nog een keer,,"
Speler [trait: proces]: "We zetten ze in de vergaderruimte. Dan is het een bezetting en geen storing."
Speler [trait: data]: "Acht stuks. Dat is precies de testset."
Speler [default]: "Kom, we drijven ze bij elkaar."
```

### t09_fetch

```
[Omschrijving] Een pony kijkt je aan vanuit de gang. Hij kauwt op een sprintplanning.

Speler [trait: detail]: "Ze staan niet eens netjes uitgelijnd. Dat is iets voor Bastiaan."
Speler [default]: "Ze komen uit de build. Dus dit is Bastiaan."
```

### t09_recruit

```
Speler [Daan]: "Bastiaan, BBD-209. Er lopen paarden door het kantoor. Sorry wat."
Speler [Danny]: "bastiaan, BBD-209. er staan paarden in de build. op de verdieping. biem."
Speler [Victor]: "Bastiaan, BBD-209. Er lopen paarden. In de build. Godver."
Speler [Jonathan]: "Bastiaan, BBD-209. Er zitten paarden in de build. Niet deze sprint, maar wel structureel."
Speler [Willem]: "Heeee Bastiaan. BBD-209. Er lopen paarden door het kantoor. Daar ga ik geen screenshot van maken."
Speler [Koen]: "Bastiaan, BBD-209. Er lopen paardenbugs rond en ik weet niet hoeveel. Jij telt beter dan ik."
Speler [default]: "Bastiaan, ik loop vast op BBD-209. Door alle wijzigingen zijn er letterlijk paarden in de build gekomen. Ze staan nu op de verdieping."

Bastiaan: "hoeveel,,"
Speler: "Acht. Denk ik."
Bastiaan: "dat is precies de testset,, wacht ik kom,, ik neem mijn laptop mee,,"
```

### t09_complete

```
Speler [bastiaan]: "acht pony's,, één ruimte,, in productie was dit niemand opgevallen,,"
Bastiaan [anderen]: "acht pony's,, één ruimte,, nu staan ze waar ik ze kan zien,,"

[Omschrijving] In de vergaderruimte staan acht pony's. Ze staan er rustiger bij dan de meeste vergaderingen.

Speler [bastiaan]: "acht,, ik heb ze twee keer geteld,, het klopt nu,,"
Speler [trait: sociaal]: "Ik verplaats de vergadering wel naar het hokje."
Speler [trait: proces]: "Ik zet de ruimte op bezet. Tot nader order."
Speler [default]: "Dat is dan geregeld."
```

### t09_fail

```
Speler [bastiaan]: "er zijn er nu negen,, dat kan niet,, en toch is het zo,,"
[Omschrijving, default]: "Er lopen er nu negen. Niemand weet waar de negende vandaan komt."

[Omschrijving, bastiaan]: "Je begint opnieuw. Bij de printer."
Bastiaan [anderen]: "opnieuw,, en doe de deur van de koffiecorner dicht,,"
```

### t09_done

```
[Omschrijving] Op de deur van de vergaderruimte hangt een blad: BEZET tot nader order. Er staat geen naam bij.
```

---

## T10 — BBD-210: Naar productie
**Owner:** (alle characters) | **Locatie:** Z7 Birdhouse | **Minigame:** mg_deploy
**Vereist:** deploysleutel uit de plantenkast

### t10_blocked — De deploysleutel

```
[Omschrijving] De deploymentcomputer vraagt om de deploysleutel. Een echte sleutel. Van metaal.

Speler [trait: technisch]: "Tweefactor, uitgevoerd in staal. Hij ligt in de plantenkast, onder het speelgoedpaard."
Speler [trait: proces]: "Dat is ooit zo besloten. De sleutel ligt in de plantenkast, onder het speelgoedpaard."
Speler [default]: "Hij ligt in de plantenkast. Onder het speelgoedpaard."
```

### t10_offer

```
[Omschrijving] Op de deploymentcomputer staat één rode regel. De rest is groen.

[Rode regel, daan]: "BLOCKED: scope not approved."
[Rode regel, danny]: "WARNING: checkout conversion critical."
[Rode regel, victor]: "ERROR: frontend build failed."
[Rode regel, jonathan]: "FATAL: production database connection failed."
[Rode regel, willem]: "HOLD: client approval required."
[Rode regel, koen]: "BLOCKED: ai output not reviewed."
[Rode regel, bastiaan]: "FAILED: visual regression detected."
[Rode regel, default]: "ERROR: deployment failed."

Speler [daan]: "Natuurlijk. Van alle regels die er konden staan, staat die van mij er."
Speler [danny]: "Eén rode regel, en het is mijn getal."
Speler [victor]: "Het is de build. Het is altijd de build."
Speler [jonathan]: "De verbinding. Dat los ik niet lokaal op."
Speler [willem]: "Er ontbreekt een akkoord. Dat is precies mijn functie."
Speler [koen]: "Niemand heeft ernaar gekeken. Ik kijk wel even, vgm."
Speler [bastiaan]: "een visuele regressie,, dat ben ik,, dat is altijd ik,,"
Speler [default]: "Eén ding. Er is altijd één ding."

[Omschrijving] Achter je is het stil geworden. Iedereen staat te kijken.
```

### t10_complete

```
[Omschrijving] De balk loopt vol. DEPLOYMENT SUCCESSFUL.

Speler [daan]: "De scope is goedgekeurd. Door mij. Dat mag ook een keer."
Speler [danny]: "Nu gaan we pas meten."
Speler [victor]: "Hij staat recht. In productie. Op elk scherm."
Speler [jonathan]: "Het werkt niet meer alleen lokaal."
Speler [willem]: "Ik bel de klant. Nu het nog goed nieuws is."
Speler [koen]: "Het staat live. Toch een pareltje, lekker ouwe."
Speler [bastiaan]: "hij staat live,, en er is niets verschoven,, ik heb gekeken,,"
Speler [default]: "Het staat live."

[Omschrijving] Niemand juicht. Iemand zet koffie. Hier is dat hetzelfde.
[Omschrijving] In de entree klikt de voordeur van het slot.
```

### t10_fail

```
[Omschrijving] De balk stopt op 94%. Daarna gaat hij terug naar nul.

Speler [daan]: "Rollback. Dat is ook een besluit."
Speler [danny]: "Vierennegentig procent. Bijna. Bijna is nul."
Speler [victor]: "Ergens staat een puntkomma die er niet hoort."
Speler [jonathan]: "Ik zie het al. Vier regels lager."
Speler [willem]: "Ik zeg tegen de klant dat we in de laatste fase zitten."
Speler [koen]: "Terug. Geen zorg, we hebben er nog veertig minuten voor."
Speler [bastiaan]: "één pixel,, ergens,, ik vind hem wel,,"
Speler [default]: "Terug naar nul. Nog een keer."

[Omschrijving] Achter je zegt niemand iets. Dat is hier een vorm van steun.
```

### t10_done

```
[Omschrijving] Productie staat live. Niemand durft de muis aan te raken.
```

---

## Schrijfnoten

**Stijlconsistentie:**
- Danny schrijft en spreekt altijd zonder hoofdletters. Ook in omschrijvingen over hem: kleine letter.
- Bastiaan gebruikt `,,` als pauze-marker. Nooit een punt aan het einde van zijn zin.
- Jonathan is economisch: één zin per gedachte. Nooit twee vragen tegelijk.
- Koen is nooit gehaast. "Vgm" en "lekker ouwe" voelen niet geforceerd; ze zitten in één zin.
- Dennis reageert altijd op het minimum. "oke." is een heel antwoord voor hem.
- Victor mag vloeken. "Godver" en "manmanman" horen bij hem; gebruik ze spaarzaam zodat ze gewicht houden.
- Willem overdrijft positief. "heeeel" is zijn tell.
- **Absoluta is geen bevestiging maar een klantnaam die Willem verhaspelt.** De klant is Mevrouw P. Aardenmens van Manege De Vrije Teugel; Willem noemt haar Absoluta, corrigeert zichzelf naar Looff, en komt er nooit uit. Niemand verbetert hem. Het vaste patroon is `"Absoluta... ehh, Looff."` — alleen die twee namen, geen derde. Zonder de correctie is het weer een bevestiging, en dan is de grap weg. `_test_omz_en_absoluta` bewaakt dat.
- **O-M-Z is van Willem, Danny, Daan en Victor.** Die vier willen omzet verdienen maar noemen het nooit zo; ze spellen het. Danny schrijft zonder hoofdletters, dus bij hem is het `o-m-z`. Koen en Bastiaan doen niet mee en mogen gewoon "omzet" zeggen. Dezelfde test bewaakt dat die vier het woord nergens kaal gebruiken.
- Daan is de rustigste. Hij ziet problemen voor ze uitgesproken zijn, maar zegt er dan ook weinig over.

> **Let op — nog niet overal doorgevoerd:** Danny's eigen regels in `t06_fail` (`data/dialogue/tickets.json`) staan nog met hoofdletters ("De conversie staat nu op..." / "Terugzetten. En dan..."). Dat is inconsistent met de stijlregel hierboven en zou op termijn naar zijn kleine-letters-conventie gebracht moeten worden, zoals net gedaan is voor `t06_complete`.

**Catchphrases — ingebouwd:**
- Jonathan "ik ga er naartoe kijken" → t05_recruit, collega_jonathan
- Koen "lekker ouwe" → koen algemeen
- Danny "psies" / "biem" → t06_recruit, collega_danny (t07_recruit bestaat niet meer: BBD-207 is sinds 5 sep 2026 van iedereen)
- Danny "lekker insmeren met olijfolie" → t06_complete
- Bastiaan `,,` → bastiaan algemeen
- Willem "Absoluta... ehh, Looff" → t03_recruit, collega_willem
- Koen "vgm" / "pareltje" → t08 compleet, collega_koen
- Bastiaan `,,` → t09 compleet, collega_bastiaan
- O-M-Z → collega_willem, collega_danny, collega_daan, collega_victor, t03_complete, t06_complete, user story-minigame

**Varianten-logica:**
- `[character]` overrides `[trait]` — character-specifieke reactie gaat voor alles
- `[trait]` wordt alleen gebruikt als er geen character-match is
- `[default]` is altijd aanwezig als fallback
- Narrator-regels (omschrijvingen) hebben geen speaker; ze zijn altijd in tegenwoordige tijd, altijd droog
- Flag-combinatievarianten (bv. `daan_bezocht + daan_op_de_hoogte`) worden gecontroleerd vóór de losse `min_tickets_done`-varianten — een speler die al iets heeft opgebiecht krijgt bij een volgend bezoek voorrang op een generieke voortgangsregel
