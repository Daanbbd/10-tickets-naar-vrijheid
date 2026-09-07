#!/usr/bin/env python3
"""Maakt echte schermafbeeldingen van het spel, zonder van het venster af te hangen.

    python3 tools/qa_shot.py                 # alle basisschermen
    python3 tools/qa_shot.py wereld bord     # alleen deze
    python3 tools/qa_shot.py minigames       # de elf minigames + hun introscherm
    python3 tools/qa_shot.py npcs            # alle collega-gesprekken (--praat=)
    python3 tools/qa_shot.py los 3.0 --speler=victor --bord

Extra vlaggen voor `los` (en, waar van toepassing, elke andere modus):
    --uit=<map>     schrijf hier in plaats van docs/audit-shots (bijv. een
                     scratchpad — zo committen agents nooit per ongeluk frames)
    --naam=<naam>   bestandsnaam voor `los` in plaats van het vaste "los"
                     (nodig zodra twee `los`-aanroepen tegelijk lopen)
    --reeks=N       bewaar N gelijk verdeelde frames uit de reeks als
                     <naam>_1..N.png in plaats van alleen het laatste frame —
                     beweging is niet aan één eindbeeld te beoordelen
    QA_SHOT_ZICHTBAAR=1  laat het Movie Maker-venster echt op het scherm zien
                     (standaard rendert het ver buiten beeld, zie `schiet()`)

Waarom niet `-- --shot=`: die QA-vlag hangt aan `RenderingServer.frame_post_draw`,
en macOS staakt het tekenen zodra het Godot-venster niet vooraan staat. Dan
schrijft hij stil geen bestand — het werkt een paar keer en daarna niet meer.
`--write-movie` (Movie Maker) rendert elk frame onvoorwaardelijk naar schijf,
met `--fixed-fps` geforceerd, dus die is niet afhankelijk van compositing.
We schrijven een PNG-reeks, pakken de gevraagde frame(s) en gooien de rest weg.
Elke aanroep krijgt zijn eigen tijdelijke map, zodat parallelle runs (aparte
worktrees) elkaar niet in de weg zitten.
"""
import subprocess, sys, shutil, os, glob, tempfile

GODOT = "/Applications/Godot.app/Contents/MacOS/Godot"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UIT = os.path.join(ROOT, "docs/audit-shots")
FPS = 20
# `--res=BxH` (bijv. --res=360x640) zet de venstermaat van Godot via een
# tijdelijke override.cfg, en daarmee de schermverhouding van het frame. Zonder
# deze vlag: de projectinstelling (384x832, exact 6:13). Sinds `window/stretch/aspect = "expand"` groeit het
# canvas mee met het venster, dus dit is de manier om 9:16, 9:19,5 en 9:21 te
# vergelijken zonder aan het project te draaien.
RES: str | None = None

# naam -> (seconden speeltijd, QA-vlaggen)
SCHERMEN = {
    "titel":   (2.0, []),
    "uitleg":  (1.5, ["--scherm=uitleg"]),
    "select":  (2.0, ["--scherm=select"]),
    "besturing": (1.5, ["--scherm=besturing"]),
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
    "mg_abgevecht": "danny", "mg_video": "koen", "mg_paarden": "bastiaan",
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


def schiet(naam: str, seconden: float, vlaggen: list[str],
           uit: str = UIT, reeks: int = 0) -> bool:
    # Eigen tijdelijke map per aanroep, onder .godot/ (gitignored, geen import):
    # twee parallelle qa_shot-runs (bijv. losse agents in eigen worktrees) delen
    # anders hetzelfde vaste pad en trekken elkaars framereeks weg.
    tmp = tempfile.mkdtemp(prefix="qa_shot_", dir=os.path.join(ROOT, ".godot"))
    try:
        frames = max(2, int(seconden * FPS))
        # `--position` ver buiten elk scherm: Movie Maker heeft een echt venster
        # nodig (headless rendert niets), en dat venster kwam op 7 september over een
        # presentatie van Daan heen staan. Off-screen renderen doet het net zo goed.
        # Zet QA_SHOT_ZICHTBAAR=1 als je juist wél wilt meekijken.
        plaats = [] if os.environ.get("QA_SHOT_ZICHTBAAR") else ["--position", "-4000,-4000"]
        cmd = [GODOT, "--path", ROOT, "--write-movie", os.path.join(tmp, "f.png"),
               "--fixed-fps", str(FPS), "--quit-after", str(frames)] + plaats + ["--"] + vlaggen
        # `--resolution` is hier onbruikbaar: Movie Maker schrijft het frame op de
        # maat van `window/size/window_*_override` uit project.godot, terwijl de
        # layout wél de opgegeven maat volgt — je krijgt dan een afgesneden beeld
        # op de oude maat. `override.cfg` (dat Godot bovenop project.godot leest)
        # verandert de echte venstermaat, en daarmee zowel layout als frame.
        # Ook dit bestand is gedeeld (repo-root): parallelle `--res=`-runs botsen
        # hierop, maar dat is een bestaande beperking die deze taak niet oplost.
        override = os.path.join(ROOT, "override.cfg")
        if RES:
            b, h = RES.lower().split("x")
            with open(override, "w") as f:
                f.write("[display]\n"
                        f"window/size/window_width_override={int(b)}\n"
                        f"window/size/window_height_override={int(h)}\n")
        try:
            p = subprocess.run(cmd, capture_output=True, text=True)
        finally:
            if RES and os.path.exists(override):
                os.remove(override)
        kaal = [r for r in p.stderr.splitlines() + p.stdout.splitlines()
                if "SCRIPT ERROR" in r or "Parse Error" in r]
        got = sorted(glob.glob(os.path.join(tmp, "f*.png")))
        if not got:
            print(f"  {naam}: GEEN FRAMES — {p.stderr.strip()[-300:]}")
            return False
        os.makedirs(uit, exist_ok=True)
        if reeks > 0:
            # N gelijk verdeelde frames uit de reeks, niet alleen het laatste:
            # beweging (een lopende straat, een schuddende schok) is niet aan
            # één eindbeeld te beoordelen.
            n = min(reeks, len(got))
            idx = [round(i * (len(got) - 1) / max(1, n - 1)) for i in range(n)]
            for i, gi in enumerate(idx, start=1):
                shutil.copyfile(got[gi], os.path.join(uit, f"{naam}_{i}.png"))
            print(f"  {naam}_1..{n}.png  ({len(got)} frames @ {FPS}fps = {seconden}s speeltijd)"
                  + ("  LET OP: scriptfouten" if kaal else ""))
        else:
            doel = os.path.join(uit, f"{naam}.png")
            shutil.copyfile(got[-1], doel)
            print(f"  {naam}.png  ({len(got)} frames @ {FPS}fps = {seconden}s speeltijd)"
                  + ("  LET OP: scriptfouten" if kaal else ""))
        for r in kaal[:3]:
            print("    " + r)
        return True
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def main() -> int:
    global RES
    args = sys.argv[1:]
    uit = UIT
    naam = "los"
    reeks = 0
    for a in list(args):
        if a.startswith("--res="):
            RES = a[len("--res="):]
            args.remove(a)
        elif a.startswith("--uit="):
            # Eigen uitvoermap (bijv. een scratchpad): zo committen agents nooit
            # per ongeluk frames in het getrackte docs/audit-shots/.
            uit = a[len("--uit="):]
            args.remove(a)
        elif a.startswith("--naam="):
            # Alleen voor `los`: standaard heet dat bestand altijd `los.png`,
            # waardoor twee parallelle `los`-aanroepen elkaar overschrijven.
            naam = a[len("--naam="):]
            args.remove(a)
        elif a.startswith("--reeks="):
            reeks = int(a[len("--reeks="):])
            args.remove(a)
    if args and args[0] == "los":
        return 0 if schiet(naam, float(args[1]), args[2:], uit=uit, reeks=reeks) else 1
    if args and args[0] == "minigames":
        for mg, wie in MINIGAMES.items():
            schiet(f"intro_{mg}", 2.0, [f"--minigame={mg}", f"--speler={wie}"], uit=uit)
            schiet(mg, 0.7, [f"--minigame={mg}", f"--speler={wie}", "--autoplay"], uit=uit)
        return 0
    if args and args[0] == "npcs":
        # Ronde C, dialoogplan: NPC-gesprekken waren visueel niet te controleren
        # (`--auto=` bereikt geen NPC's). `--praat=` lost dat op; dit schiet ze allemaal.
        for npc_id, wie in NPCS.items():
            schiet(f"praat_{npc_id}", 3.0, [f"--speler={wie}", f"--praat={npc_id}"], uit=uit)
        return 0
    namen = args or list(SCHERMEN)
    for n in namen:
        if n not in SCHERMEN:
            print(f"  onbekend scherm: {n} (keuze: {', '.join(SCHERMEN)}, minigames, npcs, los)")
            continue
        sec, vl = SCHERMEN[n]
        schiet(n, sec, vl, uit=uit)
    return 0


if __name__ == "__main__":
    sys.exit(main())
