# Dialogue Content — 10 Tickets naar Vrijheid

Gesprekscontent voor alle characters, georganiseerd per scène. Formaat volgt de JSON node-graph structuur van het spel: elke sectie toont de scène als leesbaar script plus notities over character-specifieke varianten.

---

## Character Voice Reference

| Character | Stijl | Catchphrase / tic |
|---|---|---|
| **Daan** | Rustig, procesmatig, licht zelfrelativerend | — |
| **Danny** | Geen hoofdletters, bondig, data-first | "psies", "biem", "lekker insmeren met olijfolie" |
| **Victor** | Direct, oog voor detail, af en toe vloekt | "manmanman", "godver", "hahaha" |
| **Jonathan** | Droog, nauwkeurig, weinig woorden | "ik ga er naartoe kijken", "lokaal werkt het" |
| **Willem** | Warm, sociaal, overdrijft soms | "Absoluta", "heeeel" |
| **Koen** | Relaxed, gerust, enigszins mysterieus | "lekker ouwe", "piepelienies", "vgm" |
| **Bastiaan** | Enthousiast, vergeet leestekens | ",," (dubbele komma als pauze/afsluiter) |
| **Dennis** | Minimalistisch, scrum-neutraal | "-_-", "oke.", "alvast" |

> **Noot over Danny's olijfolie-moment:** "lekker insmeren met olijfolie" hoort thuis in de t06_complete of t06_recruit — het getal klopt, de conversieboost is afgerond, Danny is tevreden. Zie suggestie onder T06.

---

## Algemene NPC-dialogen (`npcs.json`)

De algemene dialogen triggeren wanneer de speler een NPC aanspreekt buiten een actief ticket-moment. Ze reageren op `min_tickets_done` en op het trait van de gekozen character.

---

### Dennis *(Scrum Master, patrols de gang)*

**Context:** Dennis loopt zijn vaste ronde. Hij heeft het bord al bijgewerkt.

```
Dennis start [bezocht]:  "oh jij nog een keer. bord staat nog goed."
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
Dennis slot [default]: "cool. thanks is gedaan."
```

---

### Koen *(Backend, Het Patchhok)*

**Context:** Koen zit in het Patchhok. Hij is bezig maar heeft er geen haast mee.

```
Koen start [bezocht + koen_verborgen_voor_jonathan]: "is jonathan al weg? psst. lekker ouwe."
Koen start [bezocht + koen_piepelienies_uitgelegd + ≥ 6]: "piepelienies lopen nog steeds. heb ze goed ingesteld haha."
Koen start [bezocht]:  "ah ben je er weer. ik zit in een andere rabbit hole. geen zorg haha."
Koen start [≥ 6]:     "De logs zijn stil. Is weer een pareltje hoor haha."
Koen start [default]: "Ik zal even kijken. Het duurt nog veertig minuten, vgm."

Koen: "Zeg maar niets tegen Jonathan, lekker ouwe. Dan komt hij meekijken."
Koen: [< 6] "Ik kijk straks nog even naar de piepelienies. Iets met een timeout, vgm."
Koen: [≥ 6] "De piepelienies lopen trouwens weer. Took a while haha."

Koen: "wat is er?"
→ [Keuze] "Wat zijn piepelienies precies?"
     Koen: "piepelienies. ci/cd. build, test, deploy. maar dan lekker. en als ze kapot zijn duurt het veertig minuten, vgm."
     [flag: koen_piepelienies_uitgelegd, koen_bezocht]

→ [Keuze] "Jonathan zoekt je."
     Koen: "ah nee. zeg maar dat ik in een call zit. lekker ouwe."
     [flag: koen_verborgen_voor_jonathan, koen_bezocht]

→ [Keuze] "Niets. Ga zo door."
     [flag: koen_bezocht]
```

---

### Bastiaan *(Frontend, De Vloer)*

**Context:** Bastiaan zit voorover gebogen. Hij is ergens mee bezig waar hij zelf niet helemaal uit komt.

```
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

```
Klant: [t03 niet done] "Ik ben iets te vroeg. Dat doe ik altijd."
Klant: [t03 done] "Ik wacht op de taxi. Uw koffie is trouwens erg sterk."

Klant tweede [trait: technisch]: "U bent zeker de computerman. Mijn kleinzoon doet ook iets met computers."
Klant tweede [trait: commercieel]: "U bent van het praten, zie ik. Prettig, dan hoef ik het niet zelf uit te leggen."
Klant tweede [default]: "Ik heb elf paarden en één website. Met de paarden gaat het beter."

Klant: "Mijn man vindt blauw mooier. Hij is hovenier, maar hij heeft er wel oog voor."
```

---

### Stagiair *(Doorgang entree)*

**Context:** De stagiair loopt mee maar raakt niets aan. Hij heeft vier verschillende antwoorden gekregen op dezelfde vraag.

```
Stagiair: [start] "Ik loop mee. Dat mag. Ik moet alleen niets aanraken."
Stagiair: [≥ 4 done] "Ik heb gevraagd wat een sprint is. Ik heb vier antwoorden gekregen."
Stagiair: [≥ 8 done] "Ik heb alles genoteerd. Ik snap er inmiddels ongeveer een derde van."

Stagiair: "Mag ik iets vragen? Waarom heet het een stand-up als iedereen zit?"

Speler [trait: proces]: "Goede vraag. Bewaar hem voor de retro."
Speler [trait: technisch]: "Omdat het anders een uur duurt."
Speler [default]: "Dat weet niemand meer."
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

### Collega Daan *(Summit — als NPC voor andere characters)*

```
Daan start [bezocht + ≥ 8]: "Ik wil zeggen: bijna. Dan zeg ik het maar gewoon. Bijna."
Daan start [bezocht + ≥ 4]: "Voortgang. Als het zo doorgaat wordt het nog wat."
Daan start [bezocht]:        "Al iets gevonden?"
Daan start [≥ 8 done]:      "Bijna. Ik durf het bijna hardop te zeggen."
Daan start [≥ 5 done]:      "De helft staat. De helft die overblijft is altijd de lastigste helft."
Daan start [≥ 2 done]:      "We hebben scope. Dat is wellicht nieuw voor ons."
Daan start [default]:        "Ik heb de tickets op volgorde gezet. Wilde het mezelf zo makkelijk mogelijk maken."

Daan tweede [trait: technisch]:   "Kom je iets tegen dat niet in het ticket staat? Puur uit interesse: waar kwam dat dan vandaan."
Daan tweede [trait: commercieel]: "Als de klant belt: doorverbinden. Naar Willem. Altijd naar Willem."
Daan tweede [default]:            "Zeg het als iets niet klopt. Liever nu dan bij de oplevering."

Daan: "hoe zit het?"
→ [Keuze] "Alles loopt goed."
     Daan: "dat is fijn om te horen. echt."
     [flag: daan_goed_nieuws, daan_bezocht]

→ [Keuze] "Er is iets wat me dwars zit."
     Daan: "zeg het."
     Speler [trait: technisch]: "De backend gedraagt zich raar."
     Speler [trait: commercieel]: "De klant verwacht meer dan in het ticket staat."
     Speler [default]: "Ik weet het nog niet precies."
     Daan [technisch]: "Jonathan weet dat. Of Jonathan heeft het gemaakt."
     Daan [commercieel]: "Doorverbinden naar Willem. Die weet hoe hij dat landt."
     Daan [default]: "Dan is het waarschijnlijk in een ticket. Zet het er anders in."
     [flag: daan_op_de_hoogte, daan_bezocht]

→ [Keuze] "Niets bijzonders."
     Daan: "mooi."
     [flag: daan_bezocht]
```

---

### Collega Danny *(Basecamp — als NPC voor andere characters)*

```
Danny start [bezocht + ≥ 8]: "de curve gaat omhoog. nu niet verpesten."
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
Victor start [bezocht + ≥ 8]: "Build is groen. Heb hem drie keer gecheckt. Heb hem nogmaals gecheckt."
Victor start [bezocht]:        "Oh. Is er iets scheef?"
Victor start [≥ 8 done]:      "De build is groen. Done."
Victor start [≥ 4 done]:      "manmanman. Ik heb vandaag drie dingen rechtgezet die niemand scheef zag staan."
Victor start [default]:        "Ik bouw wat anderen bedenken. Ik vraag alleen of iemand het heeft nagedacht."

Victor tweede [trait: detail]: "Kijk eens naar de tweede rij. Nee? Precies. Dat is het probleem."
Victor tweede [trait: proces]: "Zet het in een ticket. Anders bestaat het niet en doe ik het toch. hahaha"
Victor tweede [default]:       "Als je iets scheef ziet staan, zeg het. Dan zie ik het ook en slaap ik slechter."

Victor: "wat?"
→ [Keuze] "Er zit iets scheef bij de entree."
     Victor: "welke kant?"
     Speler [trait: detail]: "Links. Drie pixels."
     Speler [default]: "Links, denk ik."
     Victor: "dat dacht ik al. ik fix het. godver."
     [flag: victor_entree_gemeld, victor_bezocht]

→ [Keuze] "De build ziet er goed uit."
     Victor: "dat zei ik ook. maar ik vertrouw het nog niet. hahaha."
     [flag: victor_compliment, victor_bezocht]

→ [Keuze] "Oke."
     [flag: victor_bezocht]
```

---

### Collega Jonathan *(Het Patchhok — als NPC voor andere characters)*

```
Jonathan start [bezocht + ≥ 8]: "Nog een keer. De verbinding staat nog."
Jonathan start [bezocht]:        "Ik ga er naartoe kijken, voor je het vraagt."
Jonathan start [≥ 8 done]:      "De verbinding staat. Ben benieuwd hoe lang."
Jonathan start [≥ 4 done]:      "Ik heb iets gerepareerd dat niemand kapot heeft zien gaan. Dat is het werk."
Jonathan start [default]:        "Als je mijn werk ziet, is er iets stuk. Dus je ziet me het liefst niet."

Jonathan tweede [trait: technisch]:   "Zie je iets in de logs met een hoofdletter E: dat ben ik niet. Ik ga er wel naartoe kijken."
Jonathan tweede [trait: commercieel]: "Beloof niets over snelheid. Ik weet niet waar die vandaan moet komen."
Jonathan tweede [default]:            "Het werkt lokaal. Moet zeggen dat dat ook iets is."

Jonathan: "."
→ [Keuze] "Er is iets in de logs."
     Jonathan: "welke letter?"
     Speler [trait: technisch]: "Een E. En er staan er drie."
     Speler [default]: "Een hoofdletter. Weet niet welke."
     Jonathan [technisch]: "drie E's. één is echt, twee zijn gevolgen. ik ga er naartoe kijken."
     Jonathan [default]: "als het een E is ben ik het niet. anders ook niet. ik kijk even."
     [flag: jonathan_alert, jonathan_bezocht]

→ [Keuze] "Logs zien er goed uit."
     Jonathan: "dat zei ik ook. niemand gelooft het als ik het zeg."
     [flag: jonathan_logs_ok, jonathan_bezocht]

→ [Keuze] "Niets van belang."
     Jonathan: "mooi."
     [flag: jonathan_bezocht]
```

---

### Collega Willem *(Doorheen kantoor — als NPC voor andere characters)*

```
Willem start [bezocht + ≥ 8]: "Ze heeft net gebeld. Positief. Dat is nu ook terecht, zei ze zelf."
Willem start [bezocht]:        "Ben net terug. Ze is rustig. Voorlopig."
Willem start [≥ 8 done]:      "Ik heb de klant gesproken. Ze is heeeel enthousiast, en dat is nu nog terecht."
Willem start [≥ 4 done]:      "Ik heb drie dingen toegezegd. Twee daarvan kunnen ook echt. Absoluta."
Willem start [default]:        "Ik hou de klant bij je vandaan. Dat is geen grap, dat is de functieomschrijving."

Willem tweede [trait: technisch]: "Zeg tegen mij dat iets niet kan. Ik vertaal het wel naar iets vriendelijkers."
Willem tweede [trait: sociaal]:   "Jij begrijpt het. Nee zeggen kost een uur. Ja zeggen kost een kwartaal."
Willem tweede [default]:          "Als ze belt, ben ik in het hokje. Ook als ik daar niet ben."

Willem: "heeft ze al gebeld?"
→ [Keuze] "Nog niet."
     Willem: "dat duurt niet lang meer. absoluta."
     [flag: willem_bezocht]

→ [Keuze] "Ze belde al."
     Willem: "wat zei ze?"
     → "Blij."        → Willem: "gelukkig. anders had ik nu gerend. heeeel snel."    [flag: willem_klant_blij]
     → "Vragen."      → Willem: "geef ze mij maar. ik vertaal ze naar iets uitvoerbaars." [flag: willem_vragen_op]
     → "Ze belt terug." → Willem: "ah. dan ga ik vast staan. absoluta."              [flag: willem_wacht]
     [flag: willem_bezocht]

→ [Keuze] "Oke, ga door."
     [flag: willem_bezocht]
```

---

## Ticket-dialogen (`tickets.json`)

Per ticket: 6 fases. `offer` = aanbieding, `fetch` = tussenstand, `recruit` = collega ophalen, `complete` = succes, `fail` = mislukking, `done` = al opgelost.

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

[Omschrijving, daan] Niemand spreekt je tegen. Dat is het vervelende aan Product Owner zijn.
Daan [anderen]: "Het is een wens. Van de klant. Dus het is een risico."

Speler [daan]: "Dan schrijf ik hem nu opnieuw. Met een 'zodat'."
Speler [trait: technisch]: "Zodat ik iets kan bouwen."
Speler [trait: commercieel]: "Zodat de klant iets kan kopen."
Speler [default]: "Iemand moet dit herschrijven."
```

### t01_fetch

```
[Omschrijving] Het A4 ligt er nog. Eén zin. Jij mag hier eigenlijk niets van vinden.

Speler [trait: technisch]: "Ik kan het bouwen. Ik kan het niet bedenken. Daar is Daan voor."
Speler [default]: "Scope is van Daan. Ik ga hem halen."
```

### t01_recruit

```
Daan [anderen]: "Wacht even."
Speler: "Er staat geen zodat."
Daan: "Ik kom. Vijf minuten."
```

> *Suggestie uitbreiding:* Voeg toe `[daan als speler]` — hij vindt zijn eigen A4 en kreunt.

### t01_complete

```
Daan [daan als speler]: "User story compleet. Geschreven door mij. Over mijzelf. Dit vertelt iets."
Daan [anderen]: "Goed. Nu weten we tenminste waarvoor we 's ochtends opstaan."

[Omschrijving] Op het whiteboard staat een echte user story.

Speler [trait: proces]: "Nu kan er gebouwd worden."
Speler [trait: data]: "Nu hebben we een meetpunt."
Speler [default]: "Dat scheelt."
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
**Owner:** Daan | **Locatie:** Z9 De Vloer | **Minigame:** mg_planning

### t02_offer

```
[Omschrijving] Op het scrumbord hangt een vel papier. In drie kolommen staan namen en taken.
               De speler staat er driemaal op. In dezelfde kolom.

Speler [daan]: "Dit is mijn planning. Dit verklaart mijn stemming van deze week."
Speler [trait: technisch]: "Dit is mijn naam. Dit is de kolom 'In Progress'. Ik doe dit allemaal tegelijk."
Speler [trait: data]: "Drie taken, één persoon, één sprint. Rekenkundig onmogelijk."
Speler [default]: "Er staat iets mis. Daan weet dit."

Daan [daan als speler]: "Ik weet het. Ik heb het zelf zo gezet. Tijdens een gesprek."
Daan [anderen]: "Het klopt niet. Was een tussenstap. Maar goed."

Speler [daan]: "Ik verplaats mezelf. Één kaartje tegelijk."
Speler [trait: technisch]: "Ik verplaats de prioriteit. Die van mij."
Speler [default]: "Er moet iemand bij. Of er moet iets af."
```

### t02_fetch

```
[Omschrijving] Het bord hangt scheef. Jouw naam staat er drie keer op.

Speler [trait: technisch]: "Ik ga geen kaartjes verplaatsen. Dat is van Daan."
Speler [default]: "De planning is van Daan. Zonder hem verschuif ik hier niets."
```

### t02_recruit

```
Daan [anderen]: "Het bord?"
Speler: "Je naam staat er drie keer op."
Daan: "Ah. Ja. Dat weet ik. Ik kom."
```

### t02_complete

```
Daan [daan als speler]: "Eén naam per taak. Zo simpel. Had ik eerder kunnen bedenken."
Daan [anderen]: "Het bord klopt. Dat is het beste gevoel van de week."

[Omschrijving] De kaartjes staan goed. Dennis zal dit zien en niets zeggen.

Speler [trait: proces]: "Nu ziet iedereen wie wat doet."
Speler [trait: sociaal]: "Dit geeft ruimte."
Speler [default]: "Dat is beter."
```

### t02_fail

```
Speler [daan]: "Nu staat mijn naam er vier keer op. Dat is progressie in de verkeerde richting."
[Omschrijving, default]: "Het bord klopt nog steeds niet. Er is nu wel een Extra kolom."

Daan [anderen]: "Probeer het opnieuw. Begin bij de bovenste."
```

### t02_done

```
[Omschrijving] Het scrumbord klopt. Eén naam per taak. Dennis heeft er 'goed' bij geschreven in groen.
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
     [flag: klant_prioriteit]

→ [Keuze] "Vragen wat haar man ervan vindt."
     Klant: "Mijn man vindt blauw mooier. Mijn man heeft een hoveniersbedrijf."
     [flag: klant_echtgenoot]

→ [Keuze] "Niets zeggen. Alles opschrijven."
     [Omschrijving] Je schrijft elf punten over. Mevrouw P. Aardenmens vindt dat een prettige werkwijze.

Speler [willem]: "Wij gaan hiermee aan de slag. In deze volgorde."
Willem [anderen]: "Wij gaan hiermee aan de slag. In een volgorde."
```

### t03_fetch

```
[Omschrijving] De entree is leeg. Het mapje ligt op de balie.

Speler [trait: commercieel]: "Willem weet dit al. Hier heb ik hem voor nodig."
Speler [default]: "Dit is de klant haar werk. Het uitvoeren is het onze. Dat doet Willem."
```

### t03_recruit

```
Willem: "Zit ze er al?"
Speler: "Met een mapje."
Willem: "Dan zijn het elf punten. Absoluta. Ik kom eraan."
```

### t03_complete

```
Willem [willem als speler]: "Elf punten. Drie ervan spreken elkaar tegen. Dat heb ik aan haar uitgelegd. Dat ging prima."
Willem [anderen]: "Ze is blij. Ze begrijpt niet precies wat we gaan doen. Maar ze is blij."

[Omschrijving] De klant loopt naar de uitgang. De receptiebalie staat op 'Bezoek: afgerond'.

Speler [trait: commercieel]: "Dat was goed werk, Willem."
Speler [trait: technisch]: "Kunnen we nu beginnen?"
Speler [default]: "Dat is geregeld."
```

### t03_fail

```
Willem [willem als speler]: "Ik heb hem uitgelegd. Ze heeft het opgeschreven. Er zijn nu veertien punten."
[Omschrijving, default]: "Het gesprek heeft nieuwe input opgeleverd. En drie extra punten."

Willem [anderen]: "Nog een keer. Voorzichtiger dit keer."
```

### t03_done

```
[Omschrijving] Mevrouw P. Aardenmens is weg. De balie staat op 'Bezoek: afgerond'. De koffie staat er nog.
```

---

## T04 — BBD-204: De frontend is stuk
**Owner:** Victor | **Locatie:** Z9 De Vloer | **Minigame:** mg_frontend_fix

### t04_offer

```
[Omschrijving] De wandmonitor toont de staging. Het paard staat boven de header.
               De CTA staat onder de footer. De productfoto is 4000 pixels breed.

Speler [victor]: "Dit heb ik gisteren gebouwd. Dit heb ik gisteren niet getest."
Speler [trait: technisch]: "De layout is gebroken. Ik zie drie problemen. Ze hangen samen."
Speler [trait: data]: "4000 pixels breed. Dat is groter dan de meeste schermen."
Speler [default]: "Er is iets mis met de pagina. Heel erg mis."

Victor [victor als speler]: "Godver. Wacht, ik weet het al."
Victor [anderen]: "Dit is de merge van gisteren. Dat weet ik zeker."

Speler [victor]: "Ik open het bestand. Ik los het op."
Speler [trait: detail]: "Eén voor één. Niet alles tegelijk."
Speler [default]: "Victor moet dit zien."
```

### t04_fetch

```
[Omschrijving] De monitor staat er nog. Victor staat ernaast. Hij kijkt niet blij.

Speler [trait: detail]: "Eén ding. We beginnen met één ding."
Speler [default]: "Hij weet het. Ik haal hem."
```

### t04_recruit

```
Victor: "Welke pagina?"
Speler: "De productpagina."
Victor: "Godver. Ik weet het al. Ff kijken, ik loop mee."
```

### t04_complete

```
Victor [victor als speler]: "Paard weg. Footer terug. Foto is achtentachtig pixels. Done."
Victor [anderen]: "Het staat recht. Zoals het hoort."

[Omschrijving] De wandmonitor toont: staging: layout OK.

Speler [trait: detail]: "Het klopt nu."
Speler [trait: commercieel]: "Nu ziet het er uit alsof we weten wat we doen."
Speler [default]: "Dat is beter."
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
Speler [jonathan]: "Nog steeds undefined. Maar nu ook een stack trace. Dat is meer informatie."
[Omschrijving, default]: "Het rack staat nog op rood. Er zijn nu meer foutregels."

Jonathan [anderen]: "Wacht. Ik zie het. Vijf regels omhoog."
```

### t05_done

```
[Omschrijving] Het rack staat op groen. 'productservice: 200 OK'. Jonathan heeft er niets bij geschreven.
```

---

## T06 — BBD-206: Niemand koopt iets
**Owner:** Danny | **Locatie:** Z6 Basecamp | **Minigame:** mg_cro

### t06_offer

```
[Omschrijving] Op de dashboardmuur staat de conversie van deze week: 0,04%.

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
[Omschrijving] De dashboardmuur staat er nog. 0,04%.

Speler [trait: data]: "Ik weet wat er mis is. Danny ook. Maar hij moet het zelf oplossen."
Speler [default]: "Danny ziet dit soort dingen. Ik haal hem erbij."
```

### t06_recruit

```
Danny: "Welk getal?"
Speler: "Nul komma nul vier."
Danny: "psies. dan is het de knop. het is altijd de knop. biem, ik loop mee"
```

### t06_complete

```
Danny [danny als speler]: "pluszeventien. lekker insmeren met olijfolie en gaan. zo werkt dat."
Danny [anderen]: "pluszeventien procent. de knop stond verkeerd. hij stond al jaren verkeerd."

[Omschrijving] De dashboardmuur staat op: conversie +17%. Het getal staat groen.

Speler [trait: data]: "Zeventien procent op een week. Dat is meetbaar."
Speler [trait: commercieel]: "De klant gaat dit fijn vinden."
Speler [default]: "Goed gedaan."
```

### t06_fail

```
Danny [danny als speler]: "zes procent. dat is niet zeventien. maar dat is ook niet nul komma nul vier."
[Omschrijving, default]: "De muur staat op pluszes procent. Danny kijkt er schuin naar."

Danny [anderen]: "nog een iteratie. we zijn er bijna"
```

### t06_done

```
[Omschrijving] De dashboardmuur staat op +17%. Danny heeft er 'biem' bij getypt op een sticky.
```

---

## T07 — BBD-207: We hebben muziek nodig
**Owner:** Danny | **Locatie:** Z4 Koffiecorner | **Minigame:** mg_muziek

### t07_offer

```
[Omschrijving] In de koffiecorner hangt een speaker. In Jira staat: merksound. Er staat verder niets.

Speler [danny]: "Ik heb dit ticket zelf aangemaakt. In maart. Ik weet niet meer waarom."
Speler [trait: technisch]: "Er staat geen aanvrager bij. Er staat helemaal niets bij."
Speler [default]: "Niemand weet waar dit vandaan komt. Het staat in Jira, dus het gebeurt."

[Omschrijving, danny]: "Je opent de generator. Elf seconden, niet langer."
Danny [anderen]: "Elf seconden. Niet langer. Anders wordt het een liedje."
```

### t07_fetch

```
[Omschrijving] De speaker hangt er. Hij is nog stil.

Speler [danny]: "Ik doe het zelf. Elf seconden."
Speler [default]: "Danny weet hoe lang het mag duren. Ik haal hem."
```

### t07_recruit

```
Danny: "De merksound."
Speler: "Ja."
Danny: "ein-de-lijk. ik weet nog steeds niet waarom. biem"
```

### t07_complete

```
Danny [danny als speler]: "elf seconden. drie klanken. doet het. psies."
Danny [anderen]: "elf seconden. drie klanken. niemand klaagt."

[Omschrijving] De speaker staat aan. Er klinkt iets dat klinkt als een paard dat positief verrast is.

Speler [trait: detail]: "Het is subtiel."
Speler [trait: commercieel]: "De klant zal dit mooi vinden."
Speler [default]: "Dat klinkt goed genoeg."
```

### t07_fail

```
Danny [danny als speler]: "dat waren twaalf seconden. dat is een liedje."
[Omschrijving, default]: "De speaker speelt iets af. Het duurt twaalf seconden. Danny kijkt bedenkelijk."

Danny [anderen]: "opnieuw. korter. begin bij de tweede klank"
```

### t07_done

```
[Omschrijving] De speaker staat aan. Iemand heeft de timer op tien seconden gezet, voor de zekerheid.
```

---

## T08 — BBD-208: De klant wil een AI-video
**Owner:** Victor | **Locatie:** Z8 Het Vergaderhokje | **Minigame:** mg_video

### t08_offer

```
[Omschrijving] Op de iPad in het hokje staat de briefing: een paard dat gelukkig door een weiland rent.
               Er staat verder niets.

Speler [victor]: "Dit is alles. Er staat geen kleur. Er staat geen lengte. Er staat geen paard."
Speler [trait: detail]: "Er staat geen specificatie. Er staat een gevoel."
Speler [trait: technisch]: "De input is één zin. De output moet overtuigend zijn. Dat is krap."
Speler [default]: "De klant wil een video. Meer briefing is er niet."

Victor [victor als speler]: "manmanman. We gaan genereren. Dan zien we wat er uitkomt."
Victor [anderen]: "Ik tel de benen. Als het paard vier benen heeft, is het goed."
```

### t08_fetch

```
[Omschrijving] De iPad ligt er. Er staat een promptveld open.

Speler [trait: technisch]: "Ik kan dit proberen. Victor kan controleren."
Speler [default]: "Victor telt de benen. Ik haal hem erbij."
```

### t08_recruit

```
Victor: "De paardenvideo."
Speler: "Ja."
Victor: "manmanman. Ik ga mee. Iemand moet de benen tellen."
```

### t08_complete

```
Victor [victor als speler]: "Vier benen. Goed weiland. Geen tekst over supplementen, maar dat hoeft ook niet van de briefing."
Victor [anderen]: "Vier benen, één weiland, nul supplementen. De klant zei: precies."

[Omschrijving] Op het scherm van de entree staat: 'Nu te zien: paard in weiland (4 benen)'.

Speler [trait: detail]: "Het klopt visueel."
Speler [trait: commercieel]: "De klant is blij. Dat is genoeg."
Speler [default]: "Goed genoeg."
```

### t08_fail

```
Victor [victor als speler]: "Zes benen. Nee. Opnieuw."
[Omschrijving, default]: "Het paard heeft zes benen. Victor telt ze twee keer."

Victor [anderen]: "Andere prompt. En zeg er dit keer bij: geen insecten."
```

### t08_done

```
[Omschrijving] Het scherm in de entree toont een paard met vier benen. Gelukkig. In een weiland.
```

---

## T09 — BBD-209: Er lopen paardenbugs door het kantoor
**Owner:** Jonathan | **Locatie:** Z9 De Vloer | **Minigame:** mg_paarden

### t09_offer

```
[Omschrijving] Er staat een pony bij de printer. In de gang staat er nog een. Ze zijn er since de laatste release.

Speler [jonathan]: "Dit komt uit mijn seed-data. Dat wordt een lange middag."
Jonathan [anderen]: "Dit komt uit de seed-data. En nee, dat is niet grappig."

[Omschrijving] De pony bij de printer drukt met zijn neus op Kopiëren. Er komen elf pagina's uit.

Speler [trait: proces]: "We zetten ze in de vergaderruimte. Dan is het een bezetting en geen storing."
Speler [trait: data]: "Acht stuks. Dat is precies de testset."
Speler [default]: "Kom, we drijven ze bij elkaar."
```

### t09_fetch

```
[Omschrijving] Er loopt nog een pony door de gang. Hij doet niemand kwaad. Hij is er gewoon.

Speler [jonathan]: "Ik weet waar ze vandaan komen. En ik weet hoe ik ze wegkrijg."
Speler [default]: "Jonathan gaat dit oplossen. Logisch. Het zijn zijn paarden."
```

### t09_recruit

```
Jonathan: "Hoeveel?"
Speler: "Acht."
Jonathan: "Moet zeggen dat dat er precies acht te veel zijn. Ik ga er naartoe kijken."
```

### t09_complete

```
Speler [jonathan]: "Acht pony's, één ruimte. In productie was dit niemand opgevallen."
Jonathan [anderen]: "Acht pony's, één ruimte. Nu staan ze waar ik ze kan zien."

[Omschrijving] In de vergaderruimte staan acht pony's. Ze staan er rustiger bij dan de meeste vergaderingen.

Speler [trait: sociaal]: "Ik verplaats de vergadering wel naar het hokje."
Speler [trait: proces]: "Ik zet de ruimte op bezet. Tot nader order."
Speler [default]: "Dat is dan geregeld."
```

### t09_fail

```
Jonathan [jonathan als speler]: "Ze lopen door de gang. Dat was niet de bedoeling."
[Omschrijving, default]: "De pony's staan nu in twee ruimtes. En de gang."

Jonathan [anderen]: "Drijf ze naar links. Ze gaan altijd naar links."
```

### t09_done

```
[Omschrijving] In de vergaderruimte staan acht pony's. Dennis heeft ze als blokkade gezet op het bord.
```

---

## T10 — BBD-210: Naar productie
**Owner:** (alle characters) | **Locatie:** Z7 Birdhouse | **Minigame:** mg_deploy
**Vereist:** deploysleutel uit de plantenkast

### t10_blocked — Geen deploysleutel

```
[Omschrijving] De deploymentcomputer vraagt om een sleutel. Die heb je niet.

Speler [daan]: "De deploysleutel staat niet in het ticket. Dat is een gat in de scope."
Speler [danny]: "geen sleutel, geen deploy. psies."
Speler [victor]: "Er is een sleutelgat. Ik had een sleutel verwacht. Er is geen sleutel."
Speler [jonathan]: "Ik heb dit eerder gezien. De sleutel zit ergens waar hij niet hoort."
Speler [willem]: "Ik zou dit uitzoeken, maar de klant belt zo."
Speler [default]: "Er ontbreekt iets."
```

### t10_offer

```
[Omschrijving] Op de deploymentcomputer staat één rode regel. De rest is groen.

[Rode regel, daan]: "BLOCKED: scope not approved."
[Rode regel, danny]: "WARNING: checkout conversion critical."
[Rode regel, victor]: "ERROR: frontend build failed."
[Rode regel, jonathan]: "FATAL: production database connection failed."
[Rode regel, willem]: "HOLD: client approval required."

Speler [daan]: "Natuurlijk. Van alle regels die er konden staan, staat die van mij er."
Speler [danny]: "Eén rode regel, en het is mijn getal."
Speler [victor]: "Het is de build. Het is altijd de build."
Speler [jonathan]: "De verbinding. Dat los ik niet lokaal op."
Speler [willem]: "Er ontbreekt een akkoord. Dat is precies mijn functie."
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
Speler [default]: "Terug naar nul. Nog een keer."

[Omschrijving] Achter je zegt niemand iets. Dat is hier een vorm van steun.
```

### t10_done

```
[Omschrijving] Op de deploymentcomputer staat: productie: live. De deur staat open.
               Iemand heeft een sticky geplakt: 'goed gedaan' — in het handschrift van Dennis.
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
- Willem overdrijft positief. "Absoluta" en "heeeel" zijn zijn tells.
- Daan is de rustigste. Hij ziet problemen voor ze uitgesproken zijn, maar zegt er dan ook weinig over.

**Catchphrases — ingebouwd:**
- Jonathan "ik ga er naartoe kijken" → t05_recruit, t09_recruit, collega_jonathan
- Koen "lekker ouwe" → koen algemeen
- Danny "psies" / "biem" → t06_recruit, t07_recruit, collega_danny
- Danny "lekker insmeren met olijfolie" → t06_complete (nieuw toegevoegd)
- Bastiaan `,,` → bastiaan algemeen
- Willem "Absoluta" → t03_recruit, collega_willem

**Varianten-logica:**
- `[character]` overrides `[trait]` — character-specifieke reactie gaat voor alles
- `[trait]` wordt alleen gebruikt als er geen character-match is
- `[default]` is altijd aanwezig als fallback
- Narrator-regels (omschrijvingen) hebben geen speaker; ze zijn altijd in tegenwoordige tijd, altijd droog
