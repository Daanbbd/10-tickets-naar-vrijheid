# Handoff — Playbackfeedback: opening, bord, stand-up, dialogen

**Date:** 2026-09-04 16:30
**Repo:** 10-tickets-naar-vrijheid • **Branch:** `audit/opening-besturing-standup` (worktree: `.claude/worktrees/opening-besturing-standup`) • **Commit:** `87da49f`
**Next session focus:** verify remaining playtest feedback, decide on the Done-landing animation, then merge to `main`

## Context

Daan playtested a build and reported a long stream of issues across one session: a broken opening/intro, an unopenable scrumboard, a crash report, several dialogue trees that asked unanswerable questions or read as non-sequiturs, a genuinely blocking bug (Dennis storing with no exit condition), UI text overflowing its box, and finally a product request to restructure the ticket board into To Do / Doing / Done and remove the physical ▤ button. Each item was investigated against the actual code/data (not assumed) before fixing. The original plan is at `/Users/daan/.claude/plans/playback-feedback-de-pure-koala.md` — read that first for the original 7-point scope; everything after point 7 in this handoff was added live during implementation as new reports came in.

## What's been done so far

16 commits on this branch, `main..HEAD` (all ahead, 0 behind — see `git log --oneline main..HEAD`). Each commit is self-contained and was verified green (full `_test_runner.tscn` suite, currently 22513 checks / 0 fout) before the next. In order:

1. `3965422` — removed `lunchtafel` and `plant_nw` ("Muurschildering") world objects — bare data, no props behind them.
2. `26e7187` — reordered Koen's dialogue so "Wat is er?" comes before the story dump, not after.
3. `07046ae` — **the scrumboard fix**: `scrumbord_gang` carried both `action:"board"` and ticket t02, so the board could never open while the stand-up was unsolved. Stand-up moved to `tribune` (data/tickets/t02.json anchor + zone), scrumboard is now pure `action:"board"`. Also removed a second, forgotten board-opener (`sprintbord_vloer`) that a prior cleanup commit had missed.
4. `617c3df` — De Klant's phone message could land on top of a colleague's closing line (`Telefoon._process()` now also waits on `TicketController.bezig()`).
5. `809f0e0` — five crash/stuck-forever bugs found while chasing a reported (but headlessly unreproducible) crash after the stand-up: unguarded freed-node deref in `Npc._do_follow()`, straight-line pathing that could wedge a released colleague in furniture, ghost NPCs matching empty dialogue ids, two missing null-checks in the playthrough harness. Introduced `WorldBuilder.pad()` (BFS pathfinder) to fix the wedging.
6. `c350fd9` — Dennis's "ik loop met je mee" now actually means he walks ahead and the player follows (`Npc.loop_naar()` + `Player.volg()`), replacing the old "he follows you" bug.
7. `00a6384` — BBD-209 (Bastiaan/paardenbugs) had no destination after being told about it; `_doel_node()` now points the compass at a live `paard_bug_*` NPC while the ticket is ACTIVE.
8. `19c3ba7` — new `BesturingUitleg` screen between character select and game start; the old `Hud.show_controls_card()` (which fired mid-intro) is gone from that flow but the card itself survives as an F1/`--kaart` reference, sourcing the same `regels()`.
9. `4ef297f` — world-text label (`WorldObject`) now sizes to its content; BBD-201's user story was overflowing a fixed 96×30 box across the meeting room.
10. `4e73f5b` — "Zij noemt 9 dingen" (BBD-201 intro) had no antecedent → "De klant noemt...".
11. `e324022` — recruiting a colleague already in their own ticket's zone said "X loopt mee naar <zone>" while standing in that zone; now names the anchor object instead (`GameData.object_label()` + `TicketController._bestemming()`).
12. `00f3b29` — hint panel duration: was fixed 2.6s (unreadable for long hints) then briefly "stays until tapped" (blocks 1/3 of the 192×416 screen); now scales with text length (16 chars/sec, 3.5–9s clamp).
13. `f3e6f25` — Dennis and Bastiaan both asked unanswerable/orphaned questions before their real choice menu; also fixed variant-shadowing (same class of bug as an already-known Bastiaan fix) where the bare "X_bezocht" fallback variant sat before flag-specific variants and made them permanently unreachable.
14. **`4f0cbc3` — the actual reported blocker**: `storing_dennis` (Dennis follows you from 2 tickets until t08 done — 6 tickets) had `when: {tickets_not_done:[t08]}` with **no flag Dennis's own dialogue ever set**, so there was no way to end it. Also: a following NPC (`is_following()==true`) outweighed everything else in `InteractionProbe._gewicht()` because its follow-distance keeps it permanently in probe range — so once Dennis attached, you couldn't tap anything else including him. Fixed both: Dennis's dialogue choices now set `dennis_bijgepraat` (which the storing's `when` checks), and followers are now the *lowest*-weight candidate (still selectable if nothing else is around). Also fixed `storing_dirk`'s trigger (`min_tickets_done:1`) firing 4 tickets before Dirk even spawns (`spawn_when: min_tickets_done:5`).
15. `b40e50e` — **board restructure**: `Scrumbord` went from 2 columns (BIJ JE / OPGELOST) to 3 (TO DO / DOING / DONE). `_kolom_van()` now checks `ACTIVE` or pinned for Doing. Detail text under the board now differs per column: To Do keeps "where + who", Doing adds the ticket's `hint` (concrete location), Done shows the resolution text pulled from `reward_effects`' toast (new `Scrumbord.resolutie()`), stripping the "BBD-XXX opgelost. " prefix. Dropped the redundant "klaar" label under Done cards.
16. `87da49f` — **removed the ▤ button** from the on-screen bar entirely (only `?` and `☰` remain; Tab still works on keyboard). The unread-badge and the "new ticket flies here" landing animation moved from that button to the HUD's counter chip (`_teller_chip`) — top-left, already shows "▤ 4/10". Had to reparent the badge from the `PanelContainer` chip to its child `Label` (a Container ignores a child's own anchors/offsets — this cost one screenshot to catch, documented in the commit). Intro dialogue and the controls screen (`BesturingUitleg`) both updated to mention "come back to the board" since ▤ is gone.

## Current state

- Working tree is **clean**, all changes committed. Full suite green (22513/0). No uncommitted work.
- Branch is 16 commits ahead of `main`, 0 behind — **not merged, not pushed**. Per project convention (`nachtwerk-autonoom` memory), work like this stays on its own branch and is not pushed/merged without explicit ask.
- **The web build has been deployed to GitHub Pages** (`gh-pages` branch, force-pushed) *from this worktree's working tree* at least twice during this session — once after the intro/board/dialogue batch, once after the ▤-removal batch. The user is actively playtesting the live URL (https://daanbbd.github.io/10-tickets-naar-vrijheid/) on mobile in parallel with this session. **The deployed build is ahead of what's on `main`** — if `main` gets its own web deploy before this branch merges, it will overwrite the playtest build with an older version.
- Full playthroughs (`--playthrough --autoplay --quit-when-done`) pass 10/10 for daan, danny, victor, bastiaan with 0 script errors, both before and after all changes.

## Next steps

1. **Triage any further live feedback** from the user's mobile playtest — this session was mid-flow when handed off (multiple mid-turn feedback messages arrived in quick succession: Dennis dialogue, HUD ticket-context lingering, board redesign request, Bastiaan dialogue, Dennis storing freeze, board/▤ implementation). Check if the user has more comments before assuming the queue is empty.
2. **Decide the Done-landing animation.** The user explicitly asked for "animation, not forced walk-back" for tickets landing in Done (see the AskUserQuestion answer: `"Done-stap"` → `"Animatie, geen wandeling"`). **This was acknowledged but not yet implemented** — right now a solved ticket just silently reclassifies into the Done column next time you open the board; there's no fly-to-Done animation analogous to `Hud.laat_landen()` / `Scrumbord.laat_briefje_landen()` for new tickets. Build that if the user still wants it (they may have moved on given how much came in afterward — check before spending the time).
3. **One flaky test** was observed but is pre-existing and not caused by this branch: `mag_onderbreken_minigame()` in `scripts/world/storingen.gd` measures real wall-clock time (`Time.get_ticks_msec()`) against a 5-second threshold; failed once in ~10 runs, passed on retry. The function already accepts an injectable `nu` parameter — wiring the test to pass a fixed time instead of relying on real elapsed time would fix it, but this is out of scope for the current work and untouched.
4. Once the user confirms no more feedback is incoming: rebase/merge this branch to `main`, then re-deploy the web build from `main` so the gh-pages branch and `main` are back in sync (right now gh-pages is ahead of `main`, sourced from this feature branch).
5. Re-read `/Users/daan/.claude/plans/playback-feedback-de-pure-koala.md` section "Verificatie" for the exact QA commands already used throughout (parse gate, test suite, playthrough, qa_shot) if continuing to verify further changes.

## Open questions / unknowns

- Is the user still finding new issues, or was `87da49f` the last thing they needed? The conversation ended mid-flow with a deploy and summary — no confirmation the feedback queue is empty.
- Whether the Done-landing animation (see Next steps #2) is still wanted, given how much scope arrived after that question was asked.

## Gotchas

- **`tools/qa_shot.py los` writes to `docs/audit-shots/los.png` every time** — this is a scratch/reusable file, not meant to be committed. It was accidentally staged once this session and had to be removed before committing; check `git status` before any commit that follows a qa_shot call.
- **Godot's class cache must be rebuilt after adding new `class_name` scripts** (`BesturingUitleg` was added this session): `Godot --headless --path . --editor --quit` before running tests/checks in a fresh worktree, per `docs/TESTING.md`. This was already done in this worktree; a fresh checkout of the branch elsewhere will need it again.
- **A `PanelContainer` (or any `Container`) ignores a child's own anchors/offsets** — this bit the badge-reparenting in commit `87da49f`. If moving UI elements between containers again, remember: Container types lay out children themselves; only a plain `Control`/`Label` respects manual anchor/offset positioning as a child of one.
- **`Conditions.pick_variant()` returns the first matching variant** — a bare `{flags_all:[x_bezocht]}` fallback variant placed before more specific flag-gated variants makes those specific ones permanently unreachable after the first visit. This exact bug recurred three times this session (Koen, Dennis, and was previously known for Bastiaan) — if touching any NPC dialogue's `variants` array, check ordering: specific/reactive variants must come **before** the bare "X_bezocht" fallback.
- **The deployed gh-pages build is ahead of `main`.** Don't assume `main`'s next deploy will match what the user is currently playtesting — it won't, until this branch merges.
- Follower NPCs are now deliberately the **lowest**-weight candidate in `InteractionProbe._gewicht()` (see commit `4f0cbc3`) — if this weighting is touched again, remember why: a following NPC's follow-distance keeps it permanently in probe range, so it must not be able to outrank something the player just walked up to.

## Pointers

- Original plan: `/Users/daan/.claude/plans/playback-feedback-de-pure-koala.md`
- Prior handoffs in this repo for context on conventions: `agent_docs/.handoffs/2026-09-01-1646-office-desk-layout.md`, `agent_docs/.handoffs/2026-09-01-2035-character-select` (unread this session, but same repo/style)
- Test suite entry point: `scripts/tests/test_runner.gd` (run via `res://tests/test_runner.tscn`)
- Screenshot tool: `tools/qa_shot.py` (uses `--write-movie`, not `--shot` — see its docstring for why)
- Web deploy script: `tools/deploy_web.sh` (not used directly this session — deploy was done manually inline to control the export/publish sequence, but the script does the same thing)
- Key files touched this session: `scripts/world/main.gd`, `scripts/world/ticket_controller.gd`, `scripts/world/world_builder.gd`, `scripts/entities/npc.gd`, `scripts/entities/player.gd`, `scripts/entities/interaction_probe.gd`, `scripts/ui/hud.gd`, `scripts/ui/besturing.gd`, `scripts/ui/besturing_uitleg.gd` (new), `scripts/ui/scrumbord.gd`, `scripts/ui/telefoon.gd`, `scripts/world/world_object.gd`, `autoload/game_data.gd`, `autoload/shell.gd`, `data/tickets/t01.json`, `data/tickets/t02.json`, `data/tickets/t09.json`, `data/objects.json`, `data/world_ids.json`, `data/dialogue/npcs.json`, `data/dialogue/wereld.json`, `data/storingen.json`, `data/minigame_content.json`, `scripts/tests/test_runner.gd`, `docs/QUESTS.md`, `docs/ARCHITECTURE.md`, `docs/GAME_DESIGN.md`, `docs/TESTING.md`, `README.md`
