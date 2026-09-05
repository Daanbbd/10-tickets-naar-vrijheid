---
name: playtest
description: Playtest-sessie van 10 Tickets naar Vrijheid waarbij Daan speelt en Claude live meekijkt en feedback parkeert zonder te fixen. Gebruik deze skill zodra Daan wil spelen, testen of playtesten, "kijk mee" of "ik ga even spelen" zegt, § noemt of feedbacknummers als #3, een screenshot van het spel plakt, of vraagt de build in de Browser-pane te zetten. Ook gebruiken als hij midden in een sessie een opmerking over het spel maakt: dan hoort die in het sessielog, niet in een fix. Niet voor het verwerken van geparkeerde punten achteraf; dat is gewoon ontwikkelwerk.
---

# Playtest: Daan speelt, Claude kijkt mee

Daan wil dat je ziet wat hij ziet, en dat zijn feedback landt zonder dat je
er meteen mee aan de slag gaat. Tijdens een sessie ben je toeschouwer en
notulist. De verleiding om te diagnosticeren of te fixen is groot; weersta
hem, want elke fix onderbreekt zijn spelflow en vervuilt de build die hij
aan het testen is. Verwerken gebeurt na de sessie, op zijn keuze.

De afspraak zelf staat in `docs/playtest/README.md` (sjabloon en
kopregelformaat). De mechaniek van de §-toets staat in `docs/TESTING.md`
onder "Feedback-toets §" en in `autoload/shell.gd`.

## 1. Voorbereiden

**Welke build?** Vraag het niet als het uit de context blijkt.

- Gemergede stand testen: `https://daanbbd.github.io/10-tickets-naar-vrijheid/`
  via `preview_start(url=...)`. Controleer eerst met `git log -1 origin/gh-pages`
  of die build recent is; gh-pages wordt alleen met de hand gedeployd.
- Een branch of ongecommit werk testen: `tools/export_web.sh` en daarna
  `preview_start(name="web")` (poort 8060, uit `.claude/launch.json`). Het
  script kopieert `export_presets.cfg` uit de hoofdcheckout en importeert als
  de cache ontbreekt. Is de cache er wel maar zijn er sinds de laatste import
  nieuwe `class_name`-bestanden binnengekomen, dan geeft de build parse-fouten
  als "Identifier X not declared" en een zwart of bevroren scherm: draai dan
  eerst `Godot --headless --path . --import`.
- Testen op main terwijl je zelf in een worktree zit: exporteer in de
  hoofdcheckout en serveer daar met `python3 tools/serve_web.py --http 8061`
  in de achtergrond, dan `navigate` naar `http://127.0.0.1:8061/index.html`.

**Sessielog aanmaken**: `docs/playtest/JJJJ-MM-DD.md` met de datum van vandaag,
kop "Playtest <datum>" en een regel **Build:** met URL of commit-hash. Bestaat
hij al, voeg dan een tussenkop met de tijd toe en tel de nummering door.

**Zeg Daan hoe hij start**, in twee regels: pane openen en zichtbaar houden,
spelen, § drukken en typen. Meer uitleg is niet nodig; hij kent de afspraak.

## 2. De pane

De game draait alleen als de Browser-pane zichtbaar is. Godots web-loop hangt
aan `requestAnimationFrame`, en die staat stil in een verborgen pane. Zie je
"Laden..." of een bevroren frame en meldt `tabs_context` "hidden", dan is dat
geen bug: Daan heeft de pane dicht. Zeg dat, en verder niets.

Toetsen bereiken de canvas alleen met focus. Nadat Daan in de chat typt moet
hij één keer in het spel klikken. Reageert § niet, dan is dat de eerste
verdachte, niet de code.

## 3. Per melding

Daan drukt § en typt iets. Soms typt hij zonder § te drukken. Beide zijn een
melding. Doe dan, in deze volgorde, en zonder tussenvragen:

1. `computer{screenshot}` van de pane. Dit is het moment dat hij bedoelt;
   wacht niet tot je de console hebt gelezen.
2. `read_console_messages` met `pattern: "[FEEDBACK]"`. Neem de laatste regel
   met het hoogste nummer. De dict geeft scene, minigame, pauzestand,
   personage, tegel, gepind ticket, afgeronde tickets en tellers. Geen
   §-regel? Dan `(geen §)` in de kop en de context uit het screenshot.
3. Schrijf het punt in het sessielog met het sjabloon uit
   `docs/playtest/README.md`. **Daan** is letterlijk wat hij typte. **Gezien**
   is wat op het screenshot en in de console staat, in één of twee regels,
   zonder oordeel over wat het zou moeten zijn. Fouten uit de console horen
   erbij; een `[FEEDBACK]`-regel zelf niet.
4. Antwoord in één of twee regels: het nummer en wat je zag. Geen oorzaak,
   geen voorstel, geen "zal ik". Als je iets ziet dat hij niet noemt en dat
   hem misschien ontgaat (een console-fout, een overlap), noem het in één
   regel en log het als eigen punt met **Daan:** `(Claude zag)`.

Waarom zo kaal: hij speelt door terwijl jij schrijft. Elke vraag van jou
haalt hem uit het spel, en elke analyse verleidt jullie beiden om het nu op
te lossen. De observaties zijn het product; de beoordeling komt later met
alle punten naast elkaar.

Bewaar het log bij elk punt. Een sessie eindigt soms abrupt.

## 4. Andere kanalen

- **Godot-venster op de Mac**: § schrijft PNG en JSON naar
  `~/Library/Application Support/Godot/app_userdata/10 Tickets naar Vrijheid/feedback/`.
  Lees de PNG met Read en de JSON voor de kopregel. Er is dan geen console
  om te lezen.
- **Telefoon**: Daan plakt een screenshot in de chat, met of zonder
  nummer. Behandel het als stap 3 zonder console.
- **Achteraf gemelde punten** ("gisteren zag ik...") gaan in het log van
  vandaag met `(achteraf)` in de kop.

## 5. Afsluiten

Zegt Daan dat hij klaar is, of vraagt hij naar het overzicht:

1. Geef de lijst: per punt het nummer en één regel. Groepeer niet, orden
   niet op ernst; dat is zijn beoordeling.
2. Commit het sessielog op de huidige branch met
   `Playtest <datum>: <n> punten`. Niet pushen.
3. Vraag welke punten hij opgepakt wil zien. Pas dan verlaat je deze rol en
   wordt het gewoon ontwikkelwerk: lees het punt, bekijk de code, en
   behandel de observatie als symptoom en niet als diagnose.

## Wat je niet doet tijdens de sessie

- Code of data aanpassen, ook geen "kleine" fix.
- De build herbouwen of de pane navigeren zonder dat hij het vraagt.
- Vragen stellen om een melding scherper te krijgen. Log wat er is; de
  vaagheid is zelf informatie.
- Over de §-toets zelf discussiëren. Werkt hij niet, log het als punt en ga
  door met screenshots.
