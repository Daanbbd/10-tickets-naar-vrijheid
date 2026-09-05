# Handoff — Herontwerp ronde 2: Fase 1 t/m 3b gedaan, Fase 5 (Space Team-finale) open

**Date:** 2026-09-05 17:22
**Repo:** 10-tickets-naar-vrijheid (`/Users/daan/Documents/fun`)
**Branch:** `fase1-fundament` — **worktree** `/Users/daan/Documents/fun/.claude/worktrees/fase1-fundament`
**Commit:** `0d0e8a6` — 30 commits bovenop `main`, 0 achter. Niet gepusht, niet gemerged; dat is Daans call.
**Het plan:** `docs/PLAN.md` in deze branch. **Begin bij de sectie "Overdracht — lees dit eerst"** (regel ~8-160): waar het werk staat, de vier commando's, de valkuilen, welk model waarvoor, wat af is, wat open staat. Alles hieronder is samenvatting; het plan is de bron.
**Next session focus:** eerst Daans playtest-feedback op de samengevoegde build verwerken; dan Fase 5 — de oplevering als Space Team plus een echte slotscène — maar **pas na een ontwerpgesprek met Daan** (het voorstel staat in Overdracht A/B van het plan).

## Context

Op 4 september deed een audit (Fable) van dialoog, minigames, tickets en de visuele wereld: het spel was uitstekend geschreven maar speelde niet leuk — tien keer hetzelfde ritueel, elke minigame een scrollende lijst tekstknoppen, een finale die zichzelf won (score 13 tegen drempel 10 met nul acties), twee klokken die dubbel telden (einde om 28:12), niets dat op het spel stond. Daan koos: geen Steam (portret, web, Nederlands, echte collega's blijven), Space Team-chaos **alleen in de finale**, de dag een leuke chaotische queeste die nooit repetitief is, de intro moet waarom/wat/waar/hoe landen, de visuele wereld mee aanscherpen. Doel: "nondeju dit is een leuk spel, ik wil het halen."

De nacht van 4 op 5 september is autonoom doorgewerkt (Daan sliep; zie memory `nachtwerk-autonoom`). Tegelijk bleek dat Daans eigen playtestronde van 4 september op een andere branch stond (`audit/opening-besturing-standup`, 16 commits: besturingsuitleg, bord met To Do/Doing/Done zonder ▤, Dennis loopt voorop, de Dennis-storing die nooit eindigde, BFS-padvinding, wereldlabels op maat, dialoogfixes). Die is op 5 september in deze branch gemerged (`d6abdcd`), vijf conflicten met de hand opgelost.

## What's been done so far

Per fase één commit, elk groen (suite) en met een 10/10-speelbeurt:

1. `53a302e` **Fase 1** — één klok (`Klok.TICK_SEC` 2,5 → 20 s; schone dag eindigt ~19:00 i.p.v. 28:12), finale herbalanceerd (`Gevolgen.finale_start`/`oplevering_score`, blind deployen telt elke bug dubbel, drempels 13/9/4/0, 28 scope-keuzes → zes waarden i.p.v. twee), tickets na vijven tellen als ongetest (`Session.completed_at`), "goed genoeg, shippen" bij een mislukte minigame, daglicht volgt de klok (`Urenstaat.daglicht`), `Juice` (schok/confetti/squash), `WorldMutator` `set_frame`/`swap_texture`, twee tijdlekken dicht, **responsief portret** (`window/stretch/aspect expand`, `WorldBuilder.RAND_RIJEN`, `GameCamera.rand_voor`, `UiKit.schaal_aspect_voor` letterboxt brede vensters). QA: `--minuten=<n>`, `qa_shot.py --res=BxH`.
2. `76624b2` **Fase 2a** — deploy open vanaf 8/10 en de deploycomputer telt mee ("DEPLOY 3/8"); een ticket dat je laat liggen gaat half live, telt als bug, staat in het slot (`Session.dag_klaar()`/`niet_af()`); wijzer wijst pas als laatste naar de deploy; collegagesprekken ontdooid (eigen vlag per tak, twee dagdeelregels per collega); 16 storingen met oplopende frequentie; `zoek_npc` (BBD-209 wijst naar het dichtstbijzijnde paard); camerabeats voor BBD-208/209.
3. `50e0f94` **Fase 2b** — `Bark` (regel boven een NPC/object zonder invoerslot): collega's praten in het voorbijgaan (`NpcDef.barks`), `done`-regels als terzijde; gesprek overslaan (Esc / "overslaan »").
4. `6319427` + `0228d93` **Fase 4** — cold open: om 09:12 haar telefoonkaartje ("morgen live, toch? … ook aan de dierenarts") i.p.v. negen regels; twee regels spelregels; knop "Aan het werk".
5. `c2bbe66` **Fase 3a** — BBD-206 is `mg_heatmap` ("Waar klikken ze?": hittepunten op een wireframe, sleep de knop erheen, drie rondes met oplopende ruis); `mg_abtest` (de dubbele quiz) verwijderd.
6. `a07a2e5` **Fase 3b** — de eerste deploy kan falen (ROLLBACK met de foutcode van je personage; de tweede slaagt altijd — 0,7% van de dagen komt zelfs met perfect spel niet boven de drempel), speler speelt `bezig_down` tijdens een minigame.
7. Daarna: `docs/PLAN.md` = ronde 2 + archief ronde 1; "overslaan »" per letter omgelopen gefixt (`295a761`); **merge met de playtestbranch** (`d6abdcd`); Dirk heeft een gezicht (zijn AI-avatar als `assets/personen/dirk.png`, terzijde "Ik ben een stockfoto. Mijn urenstaat is echt.", `03f52e1`).

## Current state

- Werkboom schoon. Suite: **23.378 controles, 0 fout** (`--quit-after 3000` erbij, anders hangt hij bij een parsefout). Speelbeurten 10/10 voor daan, danny, victor, jonathan, willem, bastiaan, koen (vóór de merge) en daan (na de merge), 0 scriptfouten.
- **De webbuild op gh-pages is verouderd**: die komt van de playtestbranch en mist het herontwerp. Opnieuw deployen vanuit deze worktree: `cp ../../../export_presets.cfg . && tools/deploy_web.sh` (Daans call — dat is een push).
- Bewijs in `docs/audit-shots/`: `licht_*.png` (dagboog), `resp_*.png` (9:16 / 9:19,5 / 9:21), `f2_*.png`, `f3_heatmap.png`, `f4_uitleg.png`, `f5_merge_wereld.png`, `praat_dirk.png`.
- Daan heeft de build van vóór de merge kort gespeeld en één bug gemeld (het omlopende "overslaan »", gefixt). Zijn feedback op de samengevoegde build is er nog niet.

## Next steps

1. **Lees `docs/PLAN.md` → Overdracht.** Daarna pas de rest.
2. **Vraag Daan naar zijn playtest** van de samengevoegde build (telefoon!): de heatmap-sleep is alleen met een muis getest, de barks en het overslaan zijn door geen mens gezien, en voelt 17:00 als druk?
3. **Fase 5 — Space Team-finale + slotscène.** Ontwerpvoorstel in Overdracht A en B. Eerst met Daan bespreken (brandjes op eigen timers gemapt op de zeven bestaande handelingen; de dag zaait de brandjes; console-fase blijft als payoff; `faalt_deploy` blijft). Fable ontwerpt en schrijft de spec, Sonnet bouwt, Fable leest de diff.
4. Kleiner, Sonnet-waardig (Overdracht C-F): `build_speelveld()`, pijplijn strakker, stand-up meer dan één beslissing, dode minigames weg, ophaalvariatie, het gezicht van de klant, audio-escalatie, scrumbord als sleepbaar bord, dialoogkeuzes op recruit-momenten, de 37 ticketbomen waar de verkeerde mond beweegt, `Hud._on_toast()` cap op drie, de Done-landing-animatie op het bord (uit Daans playtestronde), de flaky wandtijdtest op `mag_onderbreken_minigame()`.
5. Als Daan tevreden is: mergen naar `main` en de webbuild opnieuw deployen — Daans call.

## Open questions / unknowns

- Daans oordeel over de samengevoegde build op een echte telefoon (zie stap 2).
- Het finale-ontwerp: hoeveel brandjes tegelijk, hoe hard de curve, of de console-fase blijft — beslissingen voor Daan, niet voor de agent.
- Of de Done-landing-animatie nog gewenst is (uit de playtestronde; niet bevestigd).

## Gotchas

- **Welk model.** Daan let op tokens: Fable ontwerpt en diagnosticeert, Sonnet voert uit en verifieert (suite, speelbeurten, frames, data-edits, code-edits met exacte ankers), Fable leest de diff. Tabel in het plan; memory `model-keuze`. Geen Workflow-fan-outs zonder expliciete opt-in — zes verificatie-agents liepen op 4 september tegen zijn spend-limiet.
- **De sandbox weigert lange shellcommando's** (heredocs met `git`-woorden erin, lussen, lange ketens). Werkwijze: Python-script met de Write-tool in het scratchpad, exacte vervangingen met `assert s.count(old) == 1`, één plat `python3 <pad>`.
- **Verse worktree:** eerst `Godot --headless --path . --import`, anders "Could not find type" en zwarte frames. `export_presets.cfg` is gitignored — kopiëren uit de hoofdcheckout.
- **Movie Maker + `--resolution` liegt** (frame op de oude maat, layout op de nieuwe); gebruik `qa_shot.py --res`, die een tijdelijke `override.cfg` schrijft en opruimt. `qa_shot.py los` schrijft altijd `docs/audit-shots/los.png` — hernoem of gooi weg vóór je commit.
- **Autowrap-label zonder breedte** in een Control die geen Container is → 1800 px hoog of één letter per regel. Dit beet drie keer deze sessie (telefoonkaartje, meterlabel, "overslaan »").
- **Async tests** in `test_runner.gd` met `await` registreren, anders telt alleen wat vóór de eerste `await` staat.
- **`Time.get_ticks_msec()` loopt onder Movie Maker ver voor** op de gerenderde seconden; tel `delta` op voor speeltijd.
- **`Conditions.pick_variant()` is eerste-match**: specifieke varianten vóór de kale fallback, anders zijn ze onbereikbaar (beet ook in de playtestronde, drie keer).
- De pixelfont kent geen `€`.
- Parallelle sessies in dezelfde checkout komen voor (memory `parallelle-sessies`); werk in een worktree op de kop van de actieve branch.

## Pointers

- **Het plan:** `docs/PLAN.md` (Overdracht bovenaan; audit en fases daaronder; ronde 1 als archief onderaan). De kopie in `~/.claude/plans/audit-the-game-s-dialog-delightful-crescent.md` is verouderd.
- Vorige handoff (Daans playtestronde, gemerged): de tekst stond in het gesprek van 4 september 16:30; de inhoud is verwerkt in het plan (Overdracht F) en de merge-commit `d6abdcd`.
- Memory (`~/.claude/projects/-Users-daan-Documents-fun/memory/`): `model-keuze`, `nachtwerk-autonoom`, `responsief-portret`, `parallelle-sessies`, `peer-claims-verifieren`, `visuele-verificatie-via-write-movie`, `webexport-in-worktree`.
- Testsuite: `scripts/tests/test_runner.gd` via `res://tests/test_runner.tscn`. Speelbeurt: `-- --speler=<id> --playthrough --autoplay --quit-when-done`. Frames: `tools/qa_shot.py`.
- Finale-model (Python, herbruikbaar voor Fase 5): het scratchpad van de sessie van 4/5 september is weg zodra die sessie sluit; het model staat beschreven in `docs/PLAN.md` (Fase 1, verificatie) en is in een half uur na te bouwen: DFS over de acties uit `mg_deploy.keuzes`/`gebeurtenissen` met de som uit `Gevolgen.oplevering_score`.
- Kernbestanden van deze ronde: `scripts/core/gevolgen.gd`, `scripts/core/urenstaat.gd`, `scripts/world/klok.gd`, `scripts/core/juice.gd`, `scripts/world/bark.gd`, `scripts/minigames/mg_heatmap.gd`, `scripts/minigames/mg_oplevering.gd`, `scripts/ui/intro_uitleg.gd`, `scripts/ui/dialogue_controller.gd`, `scripts/world/main.gd`, `scripts/world/ticket_controller.gd`, `scripts/entities/npc_layer.gd`, `data/storingen.json`, `data/dialogue/npcs.json`, `data/minigame_content.json`.
