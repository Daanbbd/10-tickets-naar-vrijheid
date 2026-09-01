#!/usr/bin/env python3
"""Genereert alle geluidseffecten en muziekloops.

Alleen de standaardbibliotheek: chiptune-achtige synthese naar 16-bit mono WAV.
Muziek wordt daarna met ffmpeg naar OGG omgezet zodat loops klein blijven.
"""
import math, os, struct, subprocess, wave, random

SR = 44100
ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
SFX = os.path.join(ROOT, "assets", "audio", "sfx")
MUS = os.path.join(ROOT, "assets", "audio", "music")


# ---------- basisgolven ----------

def _osc(kind, phase):
    if kind == "sine":   return math.sin(2 * math.pi * phase)
    if kind == "square": return 1.0 if (phase % 1.0) < 0.5 else -1.0
    if kind == "saw":    return 2.0 * (phase % 1.0) - 1.0
    if kind == "tri":
        p = phase % 1.0
        return 4 * p - 1 if p < 0.5 else 3 - 4 * p
    if kind == "noise":  return random.uniform(-1, 1)
    return 0.0


def tone(freq, dur, kind="square", vol=0.5, attack=0.005, decay=None,
         bend=0.0, vibrato=0.0):
    """Eén toon met ADSR-achtige envelope en optionele toonhoogtebuiging."""
    n = int(SR * dur)
    decay = decay if decay is not None else dur * 0.6
    out = [0.0] * n
    phase = 0.0
    for i in range(n):
        t = i / SR
        f = freq * (1.0 + bend * (t / dur))
        if vibrato:
            f *= 1.0 + 0.012 * math.sin(2 * math.pi * vibrato * t)
        phase += f / SR
        # envelope
        if t < attack:
            env = t / attack
        else:
            env = max(0.0, 1.0 - (t - attack) / max(1e-6, decay))
        out[i] = _osc(kind, phase) * env * vol
    return out


def mix(*layers):
    n = max(len(l) for l in layers)
    out = [0.0] * n
    for l in layers:
        for i, v in enumerate(l):
            out[i] += v
    return out


def seq(*parts):
    out = []
    for p in parts:
        out.extend(p)
    return out


def silence(dur):
    return [0.0] * int(SR * dur)


def write(path, samples, normalize=0.85):
    peak = max((abs(s) for s in samples), default=1.0) or 1.0
    g = normalize / peak if peak > normalize else 1.0
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(
            struct.pack("<h", int(max(-1.0, min(1.0, s * g)) * 32767)) for s in samples))


# ---------- noten ----------

def note(name):
    base = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
    n = base[name[0].upper()]
    i = 1
    if len(name) > 1 and name[1] in "#b":
        n += 1 if name[1] == "#" else -1
        i = 2
    octave = int(name[i:])
    return 440.0 * (2 ** ((n - 9) / 12 + (octave - 4)))


# ---------- effecten ----------

def sfx_voetstap():
    n = int(SR * 0.07)
    return [random.uniform(-1, 1) * (1 - i / n) ** 3 * 0.35 for i in range(n)]

def sfx_interactie():
    return mix(tone(note("E5"), 0.09, "square", 0.30),
               tone(note("B5"), 0.07, "tri", 0.16))

def sfx_klik():
    return tone(note("A5"), 0.045, "square", 0.24, decay=0.04)

def sfx_pak():
    return tone(note("D5"), 0.08, "tri", 0.26, bend=0.35)

def sfx_ticket_klaar():
    return seq(tone(note("C5"), 0.10, "square", 0.30),
               tone(note("E5"), 0.10, "square", 0.30),
               tone(note("G5"), 0.10, "square", 0.30),
               tone(note("C6"), 0.24, "square", 0.32, decay=0.22))

def sfx_fout():
    return seq(tone(note("A3"), 0.13, "saw", 0.30),
               tone(note("Eb3"), 0.26, "saw", 0.30, decay=0.24))

def sfx_deur():
    klik = tone(note("C3"), 0.05, "square", 0.30, decay=0.04)
    n = int(SR * 0.35)
    zwaai = [random.uniform(-1, 1) * (1 - i / n) ** 2 * 0.13 for i in range(n)]
    return seq(klik, zwaai)

def sfx_koffie():
    n = int(SR * 0.9)
    sis = [random.uniform(-1, 1) * 0.10 * min(1.0, i / (SR * 0.1)) * (1 - i / n) for i in range(n)]
    return mix(sis, tone(note("G2"), 0.9, "tri", 0.05))

def sfx_genereren():
    parts = []
    for i, nm in enumerate(["C5", "E5", "G5", "B5", "D6", "G5", "B5", "D6"]):
        parts.append(tone(note(nm), 0.075, "tri", 0.16, decay=0.07))
    return seq(*parts)

def sfx_hinnik():
    return mix(tone(note("A4"), 0.34, "saw", 0.20, bend=-0.42, vibrato=22),
               tone(note("E5"), 0.28, "square", 0.09, bend=-0.4, vibrato=18))

def sfx_raak():
    return seq(tone(note("G5"), 0.05, "square", 0.30),
               tone(note("C6"), 0.11, "square", 0.28, decay=0.10))

def sfx_deploy_ok():
    return seq(tone(note("C5"), 0.12, "tri", 0.28),
               tone(note("G5"), 0.12, "tri", 0.28),
               tone(note("C6"), 0.12, "tri", 0.30),
               mix(tone(note("E6"), 0.5, "tri", 0.26, decay=0.45),
                   tone(note("C6"), 0.5, "square", 0.13, decay=0.45)))


# ---------- muziek ----------

def loop_kantoor():
    """Rustige, licht saaie kantoorloop. Mag nooit opdringerig worden."""
    bass = ["C3", "C3", "A2", "A2", "F2", "F2", "G2", "G2"]
    lead = ["E4", "G4", "E4", "C4", "F4", "A4", "G4", "E4"]
    beat = 0.42
    b = seq(*[tone(note(x), beat, "tri", 0.20, decay=beat * 0.8) for x in bass])
    l = seq(*[seq(silence(beat * 0.25),
                  tone(note(x), beat * 0.6, "square", 0.085, decay=beat * 0.5),
                  silence(beat * 0.15)) for x in lead])
    return mix(b, l)


def loop_titel():
    bass = ["C3", "G2", "A2", "F2"] * 2
    lead = ["C5", "E5", "G5", "E5", "F5", "A5", "G5", "C5"]
    beat = 0.36
    b = seq(*[tone(note(x), beat, "saw", 0.16, decay=beat * 0.7) for x in bass])
    l = seq(*[tone(note(x), beat, "square", 0.15, decay=beat * 0.65) for x in lead])
    return mix(b, l)


def loop_merksound():
    """De 'merksound' uit BBD-207. Bewust net iets te veel van het goede."""
    beat = 0.30
    lead = ["G4", "A4", "B4", "D5", "B4", "A4", "G4", "D5",
            "G5", "D5", "B4", "G4", "A4", "B4", "D5", "G5"]
    l = seq(*[tone(note(x), beat, "tri", 0.20, decay=beat * 0.8, vibrato=5) for x in lead])
    pad = seq(*[tone(note(x), beat * 4, "sine", 0.10, decay=beat * 3.6)
                for x in ["G3", "D3", "E3", "C3"]])
    hoef = []
    while len(hoef) < len(l):
        hoef.extend(sfx_voetstap())
        hoef.extend(silence(beat - 0.07))
    return mix(l, pad, hoef[:len(l)])


def loop_paarden():
    """Polka voor de wack-a-mole. Snel, dom, aanstekelijk."""
    beat = 0.19
    bass = ["C3", "G3"] * 8
    lead = ["E5", "G5", "E5", "C5", "D5", "F5", "D5", "B4",
            "C5", "E5", "G5", "E5", "D5", "B4", "C5", "C5"]
    b = seq(*[tone(note(x), beat, "square", 0.17, decay=beat * 0.6) for x in bass])
    l = seq(*[tone(note(x), beat, "square", 0.17, decay=beat * 0.7) for x in lead])
    return mix(b, l)


def main():
    os.makedirs(SFX, exist_ok=True)
    os.makedirs(MUS, exist_ok=True)
    random.seed(7)

    effects = {
        "voetstap": sfx_voetstap, "interactie": sfx_interactie, "klik": sfx_klik,
        "pak": sfx_pak, "ticket_klaar": sfx_ticket_klaar, "fout": sfx_fout,
        "deur": sfx_deur, "koffie": sfx_koffie, "genereren": sfx_genereren,
        "hinnik": sfx_hinnik, "raak": sfx_raak, "deploy_ok": sfx_deploy_ok,
    }
    for name, fn in effects.items():
        p = os.path.join(SFX, f"{name}.wav")
        write(p, fn())
        print(f"sfx   {name:14s} {os.path.getsize(p)/1024:6.1f} kB")

    music = {"kantoor": loop_kantoor, "titel": loop_titel,
             "merksound": loop_merksound, "paarden": loop_paarden}
    have_ffmpeg = subprocess.run(["which", "ffmpeg"], capture_output=True).returncode == 0
    for name, fn in music.items():
        wav = os.path.join(MUS, f"{name}.wav")
        write(wav, fn())
        if have_ffmpeg:
            ogg = os.path.join(MUS, f"{name}.ogg")
            subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav,
                            "-c:a", "libvorbis", "-q:a", "4", ogg], check=True)
            os.remove(wav)
            print(f"muziek {name:13s} {os.path.getsize(ogg)/1024:6.1f} kB (ogg)")
        else:
            print(f"muziek {name:13s} {os.path.getsize(wav)/1024:6.1f} kB (wav)")


if __name__ == "__main__":
    main()
