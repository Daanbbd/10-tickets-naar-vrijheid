#!/usr/bin/env python3
"""Genereert alle geluidseffecten en muziekloops.

Alleen de standaardbibliotheek: chiptune-achtige synthese naar 16-bit mono WAV.
Muziek wordt daarna met ffmpeg naar OGG omgezet zodat loops klein blijven.

Muziekopzet
-----------
Het kantoor is het hoofdthema en het enige dat vrij rondspeelt. Al het andere is
een variant op datzelfde akkoordenschema, zodat het spel als één stuk muziek
klinkt in plaats van als een verzameling losse deuntjes:

  kantoor            hoofdthema, lange vorm met wisselende secties
  kantoor_merksound  hetzelfde thema, maar na BBD-207 met de merksound eroverheen
  gesprek            rustige uitkleding voor tijdens dialoog
  intro              duidelijke opening voor het titelscherm
  overwinning        duidelijke afloop als de dag erop zit
  mg_*               per minigame een eigen spanningsvariant

'Geen repeat' is hier een ontwerpeis, geen bijvangst: het kantoorthema duurt een
minuut, heeft negen secties die niet hetzelfde zijn, en krijgt kantoorruis op
gezaaide willekeurige plekken. De AudioDirector hervat de loop bovendien op de
positie waar hij hem verliet, zodat je nooit steeds dezelfde openingsmaat hoort.
"""
import math, os, struct, subprocess, wave, random

SR = 44100
ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
SFX = os.path.join(ROOT, "assets", "audio", "sfx")
MUS = os.path.join(ROOT, "assets", "audio", "music")

# Muziek gaat als 32 kHz de export in. Chiptune heeft de bovenste octaaf niet
# nodig en het scheelt de webbuild ongeveer een derde aan bestandsgrootte.
MUSIC_RATE = "32000"
MUSIC_Q = "3"


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


def write(path, samples, peak=0.85, force=False):
    """Schrijft 16-bit mono WAV. Zonder force wordt alleen naar beneden
    geschaald, zodat een zacht bedoeld effect zacht blijft."""
    top = max((abs(s) for s in samples), default=1.0) or 1.0
    g = peak / top if (force or top > peak) else 1.0
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
    """De win-state van een minigame. Moet als winst te herkennen zijn zonder
    naar het scherm te kijken: opgaande cadens, en dan een akkoord dat blijft
    staan in plaats van een losse piep."""
    aanloop = seq(tone(note("C5"), 0.09, "square", 0.26, decay=0.08),
                  tone(note("E5"), 0.09, "square", 0.26, decay=0.08),
                  tone(note("G5"), 0.09, "square", 0.28, decay=0.08))
    slot = mix(tone(note("C6"), 0.62, "square", 0.26, decay=0.56),
               tone(note("E6"), 0.62, "tri", 0.17, decay=0.56),
               tone(note("G5"), 0.62, "tri", 0.14, decay=0.56),
               tone(note("C5"), 0.62, "sine", 0.13, decay=0.56))
    return seq(aanloop, slot)

def sfx_mg_intro():
    """De intro van een minigame: 'let op, dit telt'. Bewust het spiegelbeeld
    van ticket_klaar -- neergaand en open, waar de win opgaat en sluit."""
    aanloop = seq(tone(note("G4"), 0.07, "tri", 0.20, decay=0.06),
                  tone(note("C5"), 0.07, "tri", 0.22, decay=0.06))
    stoot = mix(tone(note("A4"), 0.34, "square", 0.22, decay=0.30),
                tone(note("E5"), 0.34, "tri", 0.13, decay=0.30),
                tone(note("A3"), 0.34, "saw", 0.11, decay=0.30))
    return seq(aanloop, stoot)

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


# ---------- muziekmotor ----------

BAR = 4          # tellen per maat


class Canvas:
    """Tijdlijn waar je losse tonen op een absoluut tijdstip in prikt.

    seq()/mix() werken alleen voor korte effecten: zodra lagen elkaar
    overlappen op eigen tijdstippen is optellen op index het enige dat schaalt.
    """

    def __init__(self, dur):
        self.buf = [0.0] * int(SR * dur)

    def add(self, t, samples):
        buf = self.buf
        n = len(buf)
        i0 = int(SR * t)
        for i, v in enumerate(samples):
            j = i0 + i
            if j >= n:
                break
            if j >= 0:
                buf[j] += v

    def out(self):
        return self.buf


def wrap(buf, dur, start=0.0):
    """Knipt op de looplengte en vouwt de uitklinkende staart terug naar het
    looppunt. Zonder dit hoor je bij elke ronde de laatste noot afgekapt worden.

    `start` is waar de loop begint bij een stuk met een eigen kop: de staart
    hoort dan terug te vallen op de vamp, niet op de aanloop die je maar één
    keer te horen krijgt. Zie LOOP_START in autoload/audio_director.gd.
    """
    n = int(SR * dur)
    s0 = int(SR * start)
    head = buf[:n]
    for i, v in enumerate(buf[n:]):
        j = s0 + i
        if j >= n:
            break
        head[j] += v
    return head


CHORDS = {
    "Am": ("A", "C", "E"), "C":  ("C", "E", "G"), "Dm": ("D", "F", "A"),
    "Em": ("E", "G", "B"), "F":  ("F", "A", "C"), "G":  ("G", "B", "D"),
    "A":  ("A", "C#", "E"), "E": ("E", "G#", "B"), "Bb": ("Bb", "D", "F"),
}


def ct(chord, degree, octave):
    """Akkoordtoon: degree 0 = grondtoon, 1 = terts, 2 = kwint."""
    return "%s%d" % (CHORDS[chord][degree % 3], octave)


# De ruggengraat. Alles in het spel loopt over deze drie reeksen, zodat de
# gesprekversie en de minigames hoorbaar hetzelfde stuk zijn als het kantoor.
A1 = ["Am", "F", "C", "G"]      # het thema zelf
B1 = ["Dm", "Am", "F", "G"]     # beweging
C1 = ["F", "G", "Am", "Em"]     # optrekken


def lay_bass(cv, t0, chords, beat, kind="tri", vol=0.20, hits=(0.0, 2.0)):
    for i, ch in enumerate(chords):
        b0 = t0 + i * BAR * beat
        for k, pos in enumerate(hits):
            n = ct(ch, 0, 2) if k % 2 == 0 else ct(ch, 2, 2)
            cv.add(b0 + pos * beat, tone(note(n), beat * 1.7, kind, vol, decay=beat * 1.4))


def lay_pad(cv, t0, chords, beat, kind="sine", vol=0.085, octave=3):
    for i, ch in enumerate(chords):
        b0 = t0 + i * BAR * beat
        dur = BAR * beat
        for d in range(3):
            oc = octave + (1 if d == 2 else 0)
            cv.add(b0, tone(note(ct(ch, d, oc)), dur, kind, vol,
                            attack=0.12, decay=dur * 0.95))


def lay_arp(cv, t0, chords, beat, step=0.5, kind="tri", vol=0.10, octaves=(4, 5)):
    for i, ch in enumerate(chords):
        b0 = t0 + i * BAR * beat
        for s in range(int(round(BAR / step))):
            oc = octaves[(s // 3) % len(octaves)]
            cv.add(b0 + s * step * beat,
                   tone(note(ct(ch, s % 3, oc)), step * beat * 1.15, kind, vol,
                        decay=step * beat * 0.9))


def lay_melody(cv, t0, mel, beat, kind="square", vol=0.13, **kw):
    t = t0
    for nm, dur in mel:
        if nm is not None:
            cv.add(t, tone(note(nm), dur * beat * 0.94, kind, vol,
                           decay=dur * beat * 0.72, **kw))
        t += dur * beat


def click(dur=0.03, vol=0.10, curve=3):
    n = max(1, int(SR * dur))
    return [random.uniform(-1, 1) * (1 - i / n) ** curve * vol for i in range(n)]


def thump(freq=90.0, dur=0.13, vol=0.22):
    return tone(freq, dur, "sine", vol, attack=0.002, decay=dur * 0.8, bend=-0.55)


# Vier maten per melodie, zodat ze op elke sectie van de ruggengraat passen.
MEL_MAIN = [("E5", 1), ("G5", .5), ("E5", .5), ("C5", 1), (None, 1),
            ("D5", 1), ("F5", .5), ("D5", .5), ("A4", 1.5), (None, .5),
            ("C5", 1), ("E5", .5), ("G5", .5), ("E5", 1), (None, 1),
            ("D5", 1), ("B4", 1), ("G4", 1.5), (None, .5)]

MEL_B = [("A4", 1), ("C5", 1), ("D5", 1), ("F5", 1),
         ("E5", 1.5), ("C5", .5), ("A4", 2),
         ("F4", 1), ("A4", 1), ("C5", 1), ("E5", 1),
         ("D5", 2), ("C5", 2)]

MEL_LIFT = [("F5", 1), ("G5", 1), ("A5", 2),
            ("G5", 1), ("E5", 1), ("C5", 2),
            ("D5", .5), ("E5", .5), ("F5", 1), ("E5", 2),
            ("C5", 1), ("B4", 1), ("A4", 2)]

MEL_COUNTER = [("A3", 2), ("C4", 2), ("D4", 2), ("F4", 2),
               ("E4", 2), ("C4", 2), ("G3", 2), ("B3", 2)]

# Het thema met alleen de lange noten: herkenbaar, maar het praat niet mee.
MEL_RUST = [(nm if d >= 1 else None, d) for nm, d in MEL_MAIN]

# BBD-207. Bewust net iets te veel van het goede.
MEL_MERK = [("G4", .5), ("A4", .5), ("B4", .5), ("D5", .5), ("B4", .5), ("A4", .5), ("G4", 1),
            ("D5", .5), ("G5", .5), ("D5", .5), ("B4", .5), ("A4", 1), ("B4", 1),
            ("G4", .5), ("A4", .5), ("B4", .5), ("D5", .5), ("G5", 1), ("D5", 1),
            ("B4", .5), ("A4", .5), ("G4", 1), ("D4", 2)]

MEL_SPAAR = [("E5", 2), (None, 2), ("D5", 2), (None, 2),
             ("C5", 2), (None, 2), ("B4", 1), ("C5", 3)]

MEL_WIN = [("A4", .5), ("C5", .5), ("E5", 1), ("A5", 2),
           ("G5", 1), ("E5", 1), ("D5", 2),
           ("E5", .5), ("A5", .5), ("C6", 1), ("A5", 2),
           ("E5", 2), ("A5", 2)]


# ---------- het kantoorthema ----------

# Negen secties van vier maten. Geen twee achter elkaar hetzelfde: dat is wat
# de loop van een minuut voorkomt dat hij als een loop klinkt.
KANTOOR_PLAN = [
    (A1, "aanloop"), (A1, "thema"), (B1, "beweging"),
    (A1, "thema"),   (A1, "tegen"), (C1, "optrekken"),
    (B1, "beweging"), (A1, "thema"), (A1, "uitloop"),
]


def loop_kantoor(merksound=False):
    """Het hoofdthema. Rustig, kantoorachtig, maar het blijft bewegen."""
    beat = 0.44
    seclen = len(A1) * BAR * beat            # vier maten
    dur = len(KANTOOR_PLAN) * seclen         # ~63 s
    cv = Canvas(dur + 2.0)

    for i, (chords, rol) in enumerate(KANTOOR_PLAN):
        t0 = i * seclen
        lay_pad(cv, t0, chords, beat, "sine", 0.072)

        if rol == "aanloop":
            lay_bass(cv, t0, chords, beat, "tri", 0.17, hits=(0.0,))
        elif rol == "uitloop":
            lay_bass(cv, t0, chords, beat, "tri", 0.16, hits=(0.0, 2.0))
        else:
            lay_bass(cv, t0, chords, beat, "tri", 0.19, hits=(0.0, 1.5, 2.0, 3.5))

        if rol == "thema":
            lay_melody(cv, t0, MEL_MAIN, beat, "square", 0.105)
        elif rol == "beweging":
            lay_melody(cv, t0, MEL_B, beat, "square", 0.10)
        elif rol == "tegen":
            lay_melody(cv, t0, MEL_MAIN, beat, "square", 0.088)
            lay_melody(cv, t0, MEL_COUNTER, beat, "tri", 0.075)
        elif rol == "optrekken":
            lay_melody(cv, t0, MEL_LIFT, beat, "square", 0.12)

        # Kantoorruis: iemand typt, een stoel schuift. Te zacht om op te merken,
        # luid genoeg om elke ronde net anders te maken.
        if rol != "aanloop":
            for _ in range(random.randint(3, 6)):
                cv.add(t0 + random.uniform(0.0, seclen),
                       click(0.02, random.uniform(0.020, 0.048)))

        if merksound:
            lay_melody(cv, t0, MEL_MERK, beat, "tri", 0.095, vibrato=5.5)
            t = t0
            while t < t0 + seclen:
                cv.add(t, click(0.05, 0.055, curve=2))
                t += beat

    return wrap(cv.out(), dur)


def loop_kantoor_merksound():
    return loop_kantoor(merksound=True)


# ---------- de varianten ----------

def loop_gesprek():
    """Rustig, voor tijdens een gesprek. Hetzelfde thema, uitgekleed tot een pad
    en een enkele bel: het mag nooit om aandacht vragen terwijl er tekst staat."""
    beat = 0.62
    plan = [A1, B1, A1, C1]
    seclen = len(A1) * BAR * beat
    dur = len(plan) * seclen                 # ~40 s
    cv = Canvas(dur + 2.5)

    for i, chords in enumerate(plan):
        t0 = i * seclen
        lay_pad(cv, t0, chords, beat, "sine", 0.090, octave=3)
        lay_bass(cv, t0, chords, beat, "tri", 0.115, hits=(0.0,))
        if i % 2 == 1:
            lay_melody(cv, t0, MEL_RUST, beat, "sine", 0.070)

    return wrap(cv.out(), dur)


def loop_intro():
    """Het titelscherm. Begint met een opgaande greep zodat er geen twijfel is
    dat het spel begint, en zet daarna het thema neer zoals het bedoeld is."""
    beat = 0.36
    bar = BAR * beat
    plan = [(A1, MEL_MAIN), (B1, MEL_B), (C1, MEL_LIFT), (A1, MEL_MAIN)]
    seclen = len(A1) * bar
    aanloop = 2 * bar
    dur = aanloop + len(plan) * seclen       # ~26 s
    cv = Canvas(dur + 2.0)

    greep = ["A2", "C3", "E3", "A3", "C4", "E4", "A4", "C5", "E5", "A5"]
    for i, nm in enumerate(greep):
        cv.add(i * beat * 0.25,
               tone(note(nm), beat * 0.55, "square", 0.17, decay=beat * 0.42))
    for d in range(3):
        cv.add(2.6 * beat, tone(note(ct("Am", d, 3 + (1 if d == 2 else 0))),
                                bar * 1.3, "saw", 0.075, attack=0.02, decay=bar * 1.2))

    for i, (chords, mel) in enumerate(plan):
        t0 = aanloop + i * seclen
        lay_pad(cv, t0, chords, beat, "sine", 0.065)
        lay_bass(cv, t0, chords, beat, "saw", 0.145, hits=(0.0, 1.5, 2.0, 3.5))
        lay_melody(cv, t0, mel, beat, "square", 0.135)
        if i >= 2:
            lay_melody(cv, t0, MEL_COUNTER, beat, "tri", 0.070)

    return wrap(cv.out(), dur, aanloop)


def loop_overwinning():
    """De dag zit erop. Cadens naar A groot -- het thema staat het hele spel in
    mineur, dus de wissel naar majeur is het duidelijkste 'gewonnen' dat er is."""
    beat = 0.34
    cadens = ["F", "G", "Am", "Am"]
    vamp = ["A", "E", "A", "E"]
    seclen = len(cadens) * BAR * beat
    dur = 2 * seclen                          # ~11 s
    cv = Canvas(dur + 2.5)

    lay_pad(cv, 0.0, cadens, beat, "sine", 0.075)
    lay_bass(cv, 0.0, cadens, beat, "tri", 0.20, hits=(0.0, 2.0))
    lay_melody(cv, 0.0, MEL_WIN, beat, "square", 0.145)
    for pos in (0.0, 4.0, 8.0):
        cv.add(pos * beat, thump(96.0, 0.16, 0.20))

    t1 = seclen
    lay_pad(cv, t1, vamp, beat, "sine", 0.085)
    lay_bass(cv, t1, vamp, beat, "tri", 0.155, hits=(0.0, 2.0))
    lay_arp(cv, t1, vamp, beat, step=1.0, kind="tri", vol=0.075, octaves=(5,))

    return wrap(cv.out(), dur, t1)


# ---------- spanning per minigame ----------
#
# Alle tien staan op dezelfde ruggengraat als het kantoor, maar elk heeft zijn
# eigen spanningstruc. Je moet aan het geluid kunnen horen welke opgave er
# voor je staat, ook als je net van het scherm wegkeek.

def mg_user_story():
    """De klok. Een tik op elke achtste en een melodie die te weinig noten
    heeft: leegte onder een metronoom is spannender dan drukte."""
    beat = 0.30
    plan = [A1, B1, A1]
    seclen = len(A1) * BAR * beat
    dur = len(plan) * seclen
    cv = Canvas(dur + 1.5)

    t = 0.0
    while t < dur:
        cv.add(t, click(0.018, 0.055))
        t += beat * 0.5

    for i, chords in enumerate(plan):
        t0 = i * seclen
        lay_pad(cv, t0, chords, beat, "sine", 0.050)
        lay_bass(cv, t0, chords, beat, "square", 0.155, hits=(0.0, 2.0))
        lay_melody(cv, t0, MEL_SPAAR, beat, "square", 0.10)

    return wrap(cv.out(), dur)


def mg_planning():
    """Schuiven. De bas staat op de tegenmaat en de akkoorden vallen ernaast:
    het blijft net niet op zijn plek liggen, zoals de sprint zelf."""
    beat = 0.26
    plan = [A1, B1, A1]
    seclen = len(A1) * BAR * beat
    dur = len(plan) * seclen
    cv = Canvas(dur + 1.5)

    for i, chords in enumerate(plan):
        t0 = i * seclen
        lay_bass(cv, t0, chords, beat, "square", 0.150, hits=(0.5, 1.5, 2.5, 3.5))
        for b, ch in enumerate(chords):
            b0 = t0 + b * BAR * beat
            for pos in (1.0, 2.75):
                for d in range(3):
                    cv.add(b0 + pos * beat,
                           tone(note(ct(ch, d, 4)), beat * 0.5, "square", 0.055,
                                decay=beat * 0.4))
        lay_melody(cv, t0, MEL_B, beat, "square", 0.095)

    return wrap(cv.out(), dur)


def mg_klantfeedback():
    """Onrust. Een lage drone die niet oplost, met daarboven een motief dat elke
    maat een trede hoger vraagt en nooit antwoord krijgt."""
    beat = 0.34
    bars = 12
    dur = bars * BAR * beat
    cv = Canvas(dur + 2.0)

    ladder = ["A4", "C5", "D5", "E5", "G5", "A5"]
    for b in range(bars):
        b0 = b * BAR * beat
        if b % 4 == 0:
            cv.add(b0, tone(note("A2"), BAR * beat * 4, "saw", 0.105,
                            attack=0.25, decay=BAR * beat * 4, vibrato=0.7))
        start = b % 4
        for k in range(3):
            cv.add(b0 + (0.5 + k * 0.75) * beat,
                   tone(note(ladder[(start + k) % len(ladder)]), beat * 0.8, "tri",
                        0.115, decay=beat * 0.6))
        cv.add(b0 + 3.0 * beat, tone(note("E3"), beat * 1.2, "square", 0.075,
                                     decay=beat))

    return wrap(cv.out(), dur)


def mg_frontend_fix():
    """Glitch. Een arpeggio die blijft haken en een tweede stem die net niet
    gestemd staat -- de layout is stuk en dat hoor je."""
    beat = 0.28
    plan = [A1, A1, B1]
    seclen = len(A1) * BAR * beat
    dur = len(plan) * seclen
    cv = Canvas(dur + 1.5)

    for i, chords in enumerate(plan):
        t0 = i * seclen
        lay_bass(cv, t0, chords, beat, "square", 0.145, hits=(0.0, 2.0))
        for b, ch in enumerate(chords):
            b0 = t0 + b * BAR * beat
            for s in range(16):
                t = b0 + s * 0.25 * beat
                if random.random() < 0.18:
                    continue                      # weggevallen frame
                f = note(ct(ch, s % 3, 4 + (s // 6) % 2))
                cv.add(t, tone(f, beat * 0.28, "square", 0.095, decay=beat * 0.22))
                if random.random() < 0.16:        # blijft haken
                    cv.add(t + beat * 0.12,
                           tone(f, beat * 0.16, "square", 0.075, decay=beat * 0.13))
                cv.add(t, tone(f * 1.012, beat * 0.28, "square", 0.045,
                               decay=beat * 0.22))

    return wrap(cv.out(), dur)


def mg_backend_fix():
    """Datastroom. Onafgebroken zestienden door het akkoord heen: het loopt, en
    zolang het loopt mag je niet stoppen."""
    beat = 0.30
    plan = [A1, B1, A1]
    seclen = len(A1) * BAR * beat
    dur = len(plan) * seclen
    cv = Canvas(dur + 1.5)

    for i, chords in enumerate(plan):
        t0 = i * seclen
        lay_arp(cv, t0, chords, beat, step=0.25, kind="tri", vol=0.085,
                octaves=(4, 5, 5))
        lay_bass(cv, t0, chords, beat, "square", 0.155, hits=(0.0,))
        for b, ch in enumerate(chords):
            b0 = t0 + b * BAR * beat
            cv.add(b0 + 3.5 * beat, tone(note(ct(ch, 2, 6)), beat * 0.6, "sine",
                                         0.075, decay=beat * 0.5))

    return wrap(cv.out(), dur)


def mg_cro():
    """Opdrijven. De bas kruipt chromatisch omhoog en de melodie schuift mee:
    er is geen rustpunt, alleen een volgend procent."""
    beat = 0.28
    bars = 12
    dur = bars * BAR * beat
    cv = Canvas(dur + 1.5)

    klim = ["A2", "Bb2", "B2", "C3"]
    top = ["E5", "F5", "G5", "A5"]
    for b in range(bars):
        b0 = b * BAR * beat
        laag = klim[b % len(klim)]
        for pos in (0.0, 1.0, 2.0, 3.0):
            cv.add(b0 + pos * beat, tone(note(laag), beat * 0.85, "saw",
                                         0.135, decay=beat * 0.65))
        hoog = top[b % len(top)]
        for k, pos in enumerate((0.0, 1.5, 2.5)):
            cv.add(b0 + pos * beat,
                   tone(note(hoog), beat * 0.7, "square", 0.10 + k * 0.012,
                        decay=beat * 0.55))
        cv.add(b0 + 3.5 * beat, click(0.03, 0.075))

    return wrap(cv.out(), dur)


def mg_abgevecht():
    """Hergebruikt de oude mg_muziek-track (BBD-207 heette 'We hebben muziek
    nodig' vóór Deel 3 er een gevecht van maakte): te veel noten, te veel
    vibrato, en op de achtergrond loopt er alvast een paard mee. Geen nieuwe
    compositie voor het gevecht zelf — dit voorkomt dat de minigame in
    stilte speelt (zie AudioDirector._op_minigame_start())."""
    beat = 0.27
    plan = [A1, B1, A1]
    seclen = len(A1) * BAR * beat
    dur = len(plan) * seclen
    cv = Canvas(dur + 1.5)

    for i, chords in enumerate(plan):
        t0 = i * seclen
        lay_pad(cv, t0, chords, beat, "sine", 0.055)
        lay_bass(cv, t0, chords, beat, "tri", 0.140, hits=(0.0, 2.0))
        lay_melody(cv, t0, MEL_MERK, beat, "tri", 0.115, vibrato=6.5)
        t = t0
        while t < t0 + seclen:
            cv.add(t, click(0.05, 0.065, curve=2))
            t += beat

    return wrap(cv.out(), dur)


def mg_video():
    """Renderen. Een pad die aanzwelt en weer wegvalt, met daaronder een
    ostinaat dat gewoon doortelt tot het klaar is."""
    beat = 0.32
    plan = [A1, C1, A1]
    seclen = len(A1) * BAR * beat
    dur = len(plan) * seclen
    cv = Canvas(dur + 2.0)

    for i, chords in enumerate(plan):
        t0 = i * seclen
        for b, ch in enumerate(chords):
            b0 = t0 + b * BAR * beat
            # aanzwellende laag: lange noot met trage vibrato per akkoordtoon
            for d in range(3):
                cv.add(b0, tone(note(ct(ch, d, 3 + (1 if d == 2 else 0))),
                                BAR * beat * 1.1, "saw", 0.060,
                                attack=BAR * beat * 0.45, decay=BAR * beat * 0.7,
                                vibrato=1.4))
            for s in range(8):
                cv.add(b0 + s * 0.5 * beat,
                       tone(note(ct(ch, 0, 4)) if s % 2 == 0 else note(ct(ch, 2, 4)),
                            beat * 0.4, "square", 0.075, decay=beat * 0.32))
            cv.add(b0 + 2.0 * beat, tone(note(ct(ch, 1, 6)), beat * 0.9, "sine",
                                         0.055, decay=beat * 0.8))

    return wrap(cv.out(), dur)


def mg_paarden():
    """Polka voor de wack-a-mole. Snel, dom, aanstekelijk -- en net iets te
    hard doorgetrapt om er rustig bij te blijven."""
    beat = 0.185
    plan = [A1, A1, B1, A1]
    seclen = len(A1) * BAR * beat
    dur = len(plan) * seclen
    cv = Canvas(dur + 1.2)

    polka = [("E5", 1), ("G5", 1), ("E5", 1), ("C5", 1),
             ("D5", 1), ("F5", 1), ("D5", 1), ("B4", 1),
             ("C5", 1), ("E5", 1), ("G5", 1), ("E5", 1),
             ("D5", 1), ("B4", 1), ("C5", 2)]
    for i, chords in enumerate(plan):
        t0 = i * seclen
        lay_bass(cv, t0, chords, beat, "square", 0.150, hits=(0.0, 1.0, 2.0, 3.0))
        lay_melody(cv, t0, polka, beat, "square", 0.115)
        t = t0
        while t < t0 + seclen:
            cv.add(t, click(0.035, 0.050, curve=2))
            t += beat * 2

    return wrap(cv.out(), dur)


def mg_deploy():
    """Productie. De hoogste inzet van de dag: een halve toon die heen en weer
    schuurt, een mars eronder, en niets dat oplost tot je klaar bent."""
    beat = 0.29
    bars = 12
    dur = bars * BAR * beat
    cv = Canvas(dur + 1.6)

    for b in range(bars):
        b0 = b * BAR * beat
        for s in range(8):
            n = "A2" if s % 2 == 0 else "Bb2"
            cv.add(b0 + s * 0.5 * beat,
                   tone(note(n), beat * 0.42, "saw", 0.130, decay=beat * 0.34))
        for pos in (1.0, 3.0):
            cv.add(b0 + pos * beat, click(0.055, 0.085, curve=2))
        cv.add(b0, thump(84.0, 0.14, 0.155))

        if b % 4 == 3:
            for d, nm in enumerate(("A4", "C5", "E5", "F5")):
                cv.add(b0 + d * beat, tone(note(nm), beat * 0.9, "square", 0.105,
                                           decay=beat * 0.7))
        else:
            cv.add(b0 + 2.0 * beat, tone(note("E5"), beat * 1.6, "square", 0.095,
                                         decay=beat * 1.3, vibrato=5.0))
            cv.add(b0 + 2.0 * beat, tone(note("F5"), beat * 1.6, "tri", 0.048,
                                         decay=beat * 1.3))

    return wrap(cv.out(), dur)


# ---------- bouwen ----------

EFFECTS = {
    "voetstap": sfx_voetstap, "interactie": sfx_interactie, "klik": sfx_klik,
    "pak": sfx_pak, "ticket_klaar": sfx_ticket_klaar, "fout": sfx_fout,
    "deur": sfx_deur, "koffie": sfx_koffie, "genereren": sfx_genereren,
    "hinnik": sfx_hinnik, "raak": sfx_raak, "deploy_ok": sfx_deploy_ok,
    "mg_intro": sfx_mg_intro,
}

# De piek per stuk is een mengbeslissing, geen normalisatie: het gesprek moet
# onder de tekst blijven en een minigame moet de wereld overstemmen.
MUSIC = {
    "kantoor":           (loop_kantoor, 0.72),
    "kantoor_merksound": (loop_kantoor_merksound, 0.74),
    "gesprek":           (loop_gesprek, 0.44),
    "intro":             (loop_intro, 0.86),
    "overwinning":       (loop_overwinning, 0.88),
    "mg_user_story":     (mg_user_story, 0.74),
    "mg_planning":       (mg_planning, 0.82),
    "mg_klantfeedback":  (mg_klantfeedback, 0.82),
    "mg_frontend_fix":   (mg_frontend_fix, 0.82),
    "mg_backend_fix":    (mg_backend_fix, 0.82),
    "mg_cro":            (mg_cro, 0.82),
    "mg_abgevecht":      (mg_abgevecht, 0.82),
    "mg_video":          (mg_video, 0.82),
    "mg_paarden":        (mg_paarden, 0.70),
    "mg_deploy":         (mg_deploy, 0.86),
}


def _opruimen():
    """Muziek die niet meer in MUSIC staat hoort niet in de export te blijven
    hangen, inclusief het .import-bestand dat Godot ernaast zet."""
    houden = set(MUSIC)
    for f in sorted(os.listdir(MUS)):
        stam, ext = os.path.splitext(f)
        if ext in (".ogg", ".wav") and stam not in houden:
            for p in (os.path.join(MUS, f), os.path.join(MUS, f + ".import")):
                if os.path.exists(p):
                    os.remove(p)
            print("verwijderd %s" % f)


def main():
    os.makedirs(SFX, exist_ok=True)
    os.makedirs(MUS, exist_ok=True)
    random.seed(7)

    for name, fn in EFFECTS.items():
        p = os.path.join(SFX, "%s.wav" % name)
        write(p, fn())
        print("sfx    %-18s %6.1f kB" % (name, os.path.getsize(p) / 1024))

    have_ffmpeg = subprocess.run(["which", "ffmpeg"], capture_output=True).returncode == 0
    totaal = 0
    for name, (fn, piek) in MUSIC.items():
        random.seed(name)                     # per stuk reproduceerbaar
        wav = os.path.join(MUS, "%s.wav" % name)
        samples = fn()
        write(wav, samples, peak=piek, force=True)
        duur = len(samples) / SR
        if have_ffmpeg:
            ogg = os.path.join(MUS, "%s.ogg" % name)
            subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav,
                            "-ar", MUSIC_RATE, "-c:a", "libvorbis", "-q:a", MUSIC_Q,
                            ogg], check=True)
            os.remove(wav)
            kb = os.path.getsize(ogg) / 1024
        else:
            kb = os.path.getsize(wav) / 1024
        totaal += kb
        print("muziek %-18s %6.1f kB  %5.1f s" % (name, kb, duur))
    print("muziek totaal %.0f kB" % totaal)

    # De looppunten staan ook in LOOP_START in autoload/audio_director.gd. Ze
    # volgen uit het arrangement, dus als je hier aan een tempo of een sectie
    # draait moeten ze daar mee. Vandaar dat ze meegeprint worden.
    print("looppunten (LOOP_START in autoload/audio_director.gd): "
          "intro %.2f s, overwinning %.2f s" % (2 * BAR * 0.36, BAR * BAR * 0.34))

    _opruimen()


if __name__ == "__main__":
    main()
