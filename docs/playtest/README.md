# Playtest-sessies

Daan speelt, Claude kijkt mee en parkeert. Wat hier staat is ruw: het wordt
pas na de sessie beoordeeld en opgepakt. Tijdens de sessie wordt niets
gefixt en niets geanalyseerd.

## Werkwijze

1. **Start.** Claude opent de build in de Browser-pane van de Claude-app:
   de gedeployde versie (https://daanbbd.github.io/10-tickets-naar-vrijheid/)
   voor de gemergede stand, of `http://127.0.0.1:8060/index.html` voor een
   lokale build (`tools/export_web.sh`, daarna de "web"-configuratie uit
   `.claude/launch.json`). De pane moet zichtbaar blijven: verborgen bevriest
   Godots web-loop op "Laden...".
2. **Spelen.** Daan speelt. Wil hij iets melden, dan drukt hij **§** en typt
   zijn opmerking in de chat, kort en in zijn eigen woorden. Linksboven
   verschijnt "§ n"; dat nummer mag hij noemen, hoeft niet.
3. **Meekijken.** Claude maakt een screenshot van de pane, leest de
   `[FEEDBACK] #n {...}`-regel uit de browserconsole en schrijft in één regel
   op wat hij ziet.
4. **Parkeren.** Elk punt komt in `docs/playtest/JJJJ-MM-DD.md` met het
   sjabloon hieronder. Na de sessie kiest Daan wat opgepakt wordt.

Bijroutes: in het Godot-venster op de Mac schrijft § een PNG en JSON naar
`~/Library/Application Support/Godot/app_userdata/10 Tickets naar Vrijheid/feedback/`,
die Claude achteraf leest. Op de telefoon blijft het een screenshot in de chat
plakken, met het §-nummer erbij.

## Sjabloon per punt

```
## #3 · 14:12 · wereld, tegel (41,7), ticket T04 gepind
**Daan:** "de hint-knop verspringt als het bord open is"
**Gezien:** hintbriefje overlapt de bordkop met ~6 px; console toont geen fouten.
**Status:** open
```

De kopregel komt uit de `[FEEDBACK]`-dict (scene, `player_tile`,
`pinned_ticket`, eventueel de minigame). **Daan** is letterlijk. **Gezien** is
wat er op het screenshot en in de console staat, niet wat het zou moeten zijn.
**Status** is `open` tot Daan na de sessie iets anders zegt.
