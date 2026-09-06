# Schrijfstijl — BBD-huisstijl in tekst

Alle speler-gerichte tekst (dialoog, ticketomschrijvingen, UI-strings, toasts)
volgt de tone-of-voice-regels uit de officiële BBD-huisstijl ("Bluebird Day —
Thema 2025"). Loop deze checklist langs voor je nieuwe content commit:

1. **Eindigt geen enkele titel/kop op een punt?** ("Sample title", niet
   "Sample title.")
2. **Staat er een cijfer waar het ook een woord had kunnen zijn?** ("45
   specialisten", niet "vijfenveertig specialisten")
3. **Geen AI-cliché-taal** — "empoweren", "transformeren", "seamless",
   "best-in-class", "powered by AI".
4. **Geen em-dash (—)?** Gebruik een punt, komma, of twee zinnen.
5. **Geen emoji** in UI-strings of dialoog.
6. **Geen drieledige opsomming/slogan-ritme** ("snel, slim en schaalbaar").
7. **Draagt hoofdlettergebruik/grootte de nadruk** — geen bold geforceerd
   voor emfase in een titel.
8. **Klinkt de zin droog/zelfverzekerd**, niet overtuigend-verkoperig.

Bestaande dialoog is het ijkpunt, niet iets dat herschreven moet worden —
bijvoorbeeld `data/dialogue/tickets.json`, node `t01_offer`:

> "Dit is geen user story. Dit is een wens."

Kort, droog, direct. Geen opsmuk, geen verkooppraatje.

## Uitleg: wat zie je, wat doe je, wanneer ben je klaar

- Elke uitlegtekst beantwoordt in deze volgorde: wat zie je, wat doe je,
  wanneer ben je klaar. Het uitlegscherm vóór een minigame heeft daarvoor de
  koppen "Zo werkt het" en "Klaar als" (velden `intro` en `klaar_als` in
  `data/minigame_content.json`).
- Geen levensles, geen moraal, geen woordspeling in een regel die een regel
  uitlegt. "Een paar pixels schelen lijkt onbelangrijk, tot iemand er met de
  neus bovenop staat" was zo'n regel, en zei niets over wat je moest doen.
- Noem het ding op het scherm bij de naam die erop staat: de knop heet
  Afkappen, de balk heet Gehoord. Controleer het knoplabel in de code voordat
  je het in tekst noemt.
- Noem personen bij naam of rol. Nooit "zij" of "hij" zonder dat de klant of
  collega net genoemd is.
- Getallen komen uit de data via `{plaatshouder}` en `Briefing.vul()`, nooit
  hardgecodeerd in de zin.
- Een briefing is een persoon die praat, in zijn stem en met zijn tics. Een
  intro is het spel dat praat: neutraal, kort, zonder tics.
- Lengtes die de suite bewaakt: intro ≤ 220 tekens, "Klaar als" ≤ 120,
  briefing ≤ 220, en nergens een em-dash (`_test_schrijfstijl_geen_emdash`).

## Bekende afwijkingen (niet in deze ronde meegenomen)

Een eerdere grep op em-dash (`—`) in `data/` en `scripts/` vond, naast de al
gefixte titelbalk in `scripts/ui/hud.gd`, nog een aantal bestaande plekken
die deze regel evenmin volgden. Bij controle voor deze ronde bleken ze
allemaal al verdwenen: de personagebeschrijvingen in
`data/minigame_content.json` (mg_choicescene-personages) zijn herschreven,
het sprintlabel in `data/tickets/t02.json` bevat geen em-dash meer, en de
hint-toast in `scripts/ui/hud.gd` en de detailkop in
`scripts/ui/character_select.gd` zijn eveneens al schoon (de resterende
em-dashes in die twee bestanden staan alleen nog in commentaar, niet in
speler-zichtbare tekst). Geen bekende afwijkingen meer op dit moment; een
volgende grep kan deze sectie leeg bevestigen.
