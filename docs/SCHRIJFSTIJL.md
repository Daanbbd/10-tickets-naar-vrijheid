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

## Bekende afwijkingen (niet in deze ronde meegenomen)

Een grep op em-dash (`—`) in `data/` en `scripts/` vond, naast de al
gefixte titelbalk in `scripts/ui/hud.gd`, nog een aantal bestaande
plekken die deze regel evenmin volgen: de personagebeschrijvingen in
`data/minigame_content.json` (mg_choicescene-personages), het sprintlabel
in `data/tickets/t02.json`, de hint-toast in `scripts/ui/hud.gd` en de
detailkop in `scripts/ui/character_select.gd`. Dat is bestaande
flavor-tekst, niet onderdeel van deze MVP-ronde (die zich beperkt tot
kleur/tone-of-voice-infrastructuur, geen contentherschrijving) — gebruik
deze checklist om ze in een aparte ronde te herschrijven.
