#!/usr/bin/env python3
"""Maakt echte schermafbeeldingen van het spel, zonder van het venster af te hangen.

    python3 tools/qa_shot.py                 # alle basisschermen
    python3 tools/qa_shot.py wereld bord     # alleen deze
    python3 tools/qa_shot.py minigames       # de elf minigames + hun introscherm
    python3 tools/qa_shot.py npcs            # alle collega-gesprekken (--praat=)
    python3 tools/qa_shot.py los 3.0 --speler=victor --bord

Waarom niet `-- --shot=`: die QA-vlag hangt aan `RenderingServer.frame_post_draw`,
en macOS staakt het tekenen zodra het Godot-venster niet vooraan staat. Dan
schrijft hij stil geen bestand — het werkt een paar keer en daarna niet meer.
`--write-movie` (Movie Maker) rendert elk frame onvoorwaardelijk naar schijf,
met `--fixed-fps` geforceerd, dus die is niet afhankelijk van compositing.
We schrijven een PNG-reeks, pakken het laatste frame en gooien de rest weg.
"""
import subprocess, sys, shutil, os, glob

GODOT = "/Applications/Godot.app/Contents/MacOS/Godot"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UIT = os.path.join(ROOT, "docs/audit-shots")
TMP = os.path.join(ROOT, ".godot", "qa_shot_tmp")
FPS = 20

# naam -> (seconden speeltijd, QA-vlaggen)
SCHERMEN = {
    "titel":   (2.0, []),
    "uitleg":  (1.5, ["--scherm=uitleg"]),
    "select":  (2.0, ["--scherm=select"]),
    "wereld":  (7.0, ["--speler=daan"]),
    # `--kijk=` laat `_intro_beat()` vroeg terugkeren. Zonder dat vechten twee
    # openers om hetzelfde bord: `_qa_bord()` opent het op 0,5 s en de
    # intro-beat togglet het daarna weer dicht.
    "bord":    (1.5, ["--speler=daan", "--kijk=2,17", "--bord"]),
    "einde":   (3.0, ["--scherm=einde", "--speler=daan", "--gedaan=10"]),
}

# minigame-id -> personage dat hem bezit (voor de traitvariant)
MINIGAMES = {
    "mg_user_story": "daan", "mg_planning": "daan", "mg_klantfeedback": "willem",
    "mg_frontend_fix": "victor", "mg_backend_fix": "jonathan", "mg_cro": "danny",
    "mg_muziek": "danny", "mg_video": "koen", "mg_paarden": "bastiaan",
    "mg_deploy": "daan", "mg_urenstaat": "daan",
}

# npc_id (data/npcs.json) -> personage om als te spelen. `NpcLayer.spawn_initial()`
# spawnt geen NPC voor je eigen personage, dus "daan" kan niet zichzelf zien:
# collega_daan wordt daarom als danny gedaan. De rest is onderling uitwisselbaar,
# dus daan volstaat als vaste speler voor de rest.
NPCS = {
    "npc_daan": "danny", "npc_danny": "daan", "npc_victor": "daan",
    "npc_jonathan": "daan", "npc_willem": "daan", "npc_bastiaan": "daan",
    "npc_koen": "daan", "dennis": "daan", "dirk": "daan",
}


def schiet(naam: str, seconden: float, vlaggen: list[str]) -> bool:
    shutil.rmtree(TMP, ignore_errors=True)
    os.makedirs(TMP, exist_ok=True)
    frames = max(2, int(seconden * FPS))
    cmd = [GODOT, "--path", ROOT, "--write-movie", os.path.join(TMP, "f.png"),
           "--fixed-fps", str(FPS), "--quit-after", str(frames), "--"] + vlaggen
    p = subprocess.run(cmd, capture_output=True, text=True)
    kaal = [r for r in p.stderr.splitlines() + p.stdout.splitlines()
            if "SCRIPT ERROR" in r or "Parse Error" in r]
    got = sorted(glob.glob(os.path.join(TMP, "f*.png")))
    if not got:
        print(f"  {naam}: GEEN FRAMES — {p.stderr.strip()[-300:]}")
        return False
    os.makedirs(UIT, exist_ok=True)
    doel = os.path.join(UIT, f"{naam}.png")
    shutil.copyfile(got[-1], doel)
    shutil.rmtree(TMP, ignore_errors=True)
    print(f"  {naam}.png  ({len(got)} frames @ {FPS}fps = {seconden}s speeltijd)"
          + ("  LET OP: scriptfouten" if kaal else ""))
    for r in kaal[:3]:
        print("    " + r)
    return True


def main() -> int:
    args = sys.argv[1:]
    if args and args[0] == "los":
        return 0 if schiet("los", float(args[1]), args[2:]) else 1
    if args and args[0] == "minigames":
        for mg, wie in MINIGAMES.items():
            schiet(f"intro_{mg}", 2.0, [f"--minigame={mg}", f"--speler={wie}"])
            schiet(mg, 0.7, [f"--minigame={mg}", f"--speler={wie}", "--autoplay"])
        return 0
    if args and args[0] == "npcs":
        # Ronde C, dialoogplan: NPC-gesprekken waren visueel niet te controleren
        # (`--auto=` bereikt geen NPC's). `--praat=` lost dat op; dit schiet ze allemaal.
        for npc_id, wie in NPCS.items():
            schiet(f"praat_{npc_id}", 3.0, [f"--speler={wie}", f"--praat={npc_id}"])
        return 0
    namen = args or list(SCHERMEN)
    for n in namen:
        if n not in SCHERMEN:
            print(f"  onbekend scherm: {n} (keuze: {', '.join(SCHERMEN)}, minigames, npcs, los)")
            continue
        sec, vl = SCHERMEN[n]
        schiet(n, sec, vl)
    return 0


if __name__ == "__main__":
    sys.exit(main())
