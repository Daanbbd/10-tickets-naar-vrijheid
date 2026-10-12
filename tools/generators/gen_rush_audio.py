#!/usr/bin/env python3
"""Muziek en geluidseffecten voor de kantoor-rush.

Draaien, vanuit de projectmap:

    python3 -m venv tools/.venv                    # eenmalig
    tools/.venv/bin/pip install numpy              # eenmalig
    tools/.venv/bin/python tools/generators/gen_rush_audio.py           # alles
    tools/.venv/bin/python tools/generators/gen_rush_audio.py sfx       # alleen effecten
    tools/.venv/bin/python tools/generators/gen_rush_audio.py muziek    # alleen muziek
    tools/.venv/bin/python tools/generators/gen_rush_audio.py meet      # alleen nameten
    ... --mono                                     # muziek mono (halve OGG-grootte)

Nodig: numpy en ffmpeg (met libvorbis). Alles is gezaaid, dus twee keer draaien
geeft twee keer dezelfde bestanden.

Waarom een tweede generator
---------------------------
gen_audio.py maakt chiptune: onbewerkte square- en zaagtandgolven op volle
sterkte. Dat klinkt schel en wordt na een minuut vermoeiend, en de rush laat
zijn muziek en effecten veel langer en vaker horen dan het oude spel. Hier is
alles van zachte bouwstenen gemaakt:

- elektrische piano als FM-sinus die snel van helder naar rond uitklinkt;
- bas als sinus met een paar boventonen en lichte verzadiging, zodat hij ook op
  een telefoonspeakertje te horen is zonder te brommen;
- melodie op een fluitachtige sinus met vertraagd vibrato, of op een pulse die
  al bij de bron is afgerond (boventonen boven ~4 kHz bestaan gewoon niet);
- drums van een sinus-sweep (kick) en gekleurde ruis (snare, hats), kort;
- galm en delay, en een masterfilter dat de scherpe 3-4 kHz iets terugneemt.

Muzikale opzet
--------------
Alles is één familie in F majeur, op twee akkoordenschema's:

  A  | Fmaj9 | Em7 A7 | Dm9 | Gm7 C9 |  (twee keer)    het thema, I-iii-VI-ii-V
  B  | Bbmaj7 | Am7 | Gm7 | Am7 Dm7 | Bbmaj7 | Am7 D7 | Gm7 | C7sus C7 |

Het herkenbare stukje is de kop van de melodie: C-D-F-A, met de A op de
geswingde tel. Die zit in elk stuk, ook in de ontsnapping (in d klein: D-E-F-A)
en in de uitslag. De dagen lopen op in tempo, toonsoort en drukte:

  rush_menu         95 bpm  F    16 maten  luie swing, brushes
  rush_ma          100 bpm  F    24 maten  kaal, rimshots, fluit
  rush_di          108 bpm  G    24 maten  backbeat, aangestoten akkoorden
  rush_wo          116 bpm  Ab   24 maten  loopbas, claps, pulse-lead
  rush_do          126 bpm  Bb   24 maten  four-on-the-floor, shaker, koper
  rush_vr          138 bpm  C    32 maten  zestienden, alles erbij
  rush_ontsnapping 150 bpm  d    16 maten  recht, woodblock, schuiffluitje
  rush_uitslag     120 bpm  F    3 maten fanfare + 8 maten vamp (loopt vanaf 6,0 s)

Naadloos loopen
---------------
Elk loopend stuk wordt op een cirkel gerenderd: een noot die over het einde
heen klinkt, loopt door aan het begin, en galm, delay en EQ zijn circulaire
convoluties (FFT over precies de looplengte). Het einde van het bestand gaat dus
per definitie zonder sprong over in het begin, inclusief de galmstaart van de
laatste maat. LFO's (tremolo van de piano) krijgen een frequentie met een
geheel aantal periodes per loop.
"""
import math
import os
import re
import subprocess
import sys
import wave
import zlib

import numpy as np

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
SFX_DIR = os.path.join(ROOT, "assets", "audio", "sfx")
MUS_DIR = os.path.join(ROOT, "assets", "audio", "music")
FFMPEG = "/opt/homebrew/bin/ffmpeg" if os.path.exists("/opt/homebrew/bin/ffmpeg") else "ffmpeg"

SR_M = 32000          # muziek: de bovenste octaaf is hier toch weggefilterd
SR_S = 44100          # effecten
MUZIEK_LUFS = -18.0
MUZIEK_Q = "4"
TP_MAX = -1.0         # true peak-plafond voor muziek, dBTP
TWO_PI = 2.0 * np.pi


# ---------------------------------------------------------------- noten

NOOT = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def pc(naam):
    """Toonklasse van 'Bb', 'F#', 'C'."""
    n = NOOT[naam[0].upper()]
    for c in naam[1:]:
        n += 1 if c == "#" else -1 if c == "b" else 0
    return n % 12


def midi(naam):
    m = re.fullmatch(r"([A-Ga-g])([#b]*)(-?\d)", naam)
    n = NOOT[m.group(1).upper()] + m.group(2).count("#") - m.group(2).count("b")
    return 12 * (int(m.group(3)) + 1) + n


def hz(m):
    return 440.0 * 2.0 ** ((m - 69) / 12.0)


# Akkoordkwaliteiten. Majeur en de negens zijn grondtoonloos gevoicet: de bas speelt de
# grondtoon al, en zonder hem klinkt de piano open in plaats van modderig.
KWAL = {
    "maj7": [4, 7, 11, 14], "maj9": [4, 7, 11, 14],
    "m7": [0, 3, 7, 10], "m9": [3, 10, 14, 19],      # open: de 9 en de b3 niet naast elkaar
    "7": [0, 4, 7, 10], "9": [4, 7, 10, 14], "7b9": [4, 7, 10, 13],
    "7sus": [0, 5, 7, 10], "maj": [0, 4, 7], "m": [0, 3, 7],
}


def is_mineur(kw):
    return kw.startswith("m") and not kw.startswith("maj")


def akkoordtonen(ak):
    r, kw = ak
    return sorted({(r + i) % 12 for i in [0] + KWAL[kw]})


def voicing(ak, centrum, vorige):
    """Kiest de omkering en octaaf die het dichtst bij het centrum ligt en het
    minst beweegt ten opzichte van het vorige akkoord: stemvoering op gevoel."""
    r, kw = ak
    iv = KWAL[kw]
    beste, kost_b = None, 1e9
    for k in range(len(iv)):
        rot = iv[k:] + [x + 12 for x in iv[:k]]
        for o in range(1, 8):
            noten = [r + 12 * o + x for x in rot]
            gem = sum(noten) / len(noten)
            if abs(gem - centrum) > 7 or min(noten) < 48:
                continue
            kost = 0.6 * abs(gem - centrum)
            # Kleine secundes naast elkaar klinken op een FM-piano als een
            # wrijving, bovenin (waar het oor zit) het meest.
            stappen = [b - a for a, b in zip(noten, noten[1:])]
            kost += 5.0 * stappen.count(1) + (2.0 if stappen[-1] == 1 else 0.0)
            if vorige and len(vorige) == len(noten):
                kost += 0.5 * sum(abs(a - b) for a, b in zip(noten, vorige))
            if kost < kost_b:
                beste, kost_b = noten, kost
    return beste


# ---------------------------------------------------------------- bouwstenen

def _t(n, sr):
    return np.arange(n) / sr


def fase(freq, sr):
    return TWO_PI * np.cumsum(freq) / sr


def aanzet(t, a):
    """Zachte aanzet (sin²), geen lineaire knik."""
    if a <= 0:
        return np.ones_like(t)
    return np.sin(0.5 * np.pi * np.clip(t / a, 0.0, 1.0)) ** 2


def los(t, duur, r):
    """Loslaten: vanaf `duur` exponentieel weg."""
    out = np.ones_like(t)
    m = t > duur
    out[m] = np.exp(-(t[m] - duur) / r)
    return out


def bandruis(n, lo, hi, sr, rng, orde=2):
    """Gekleurde ruis met eenheids-RMS, gefilterd in het frequentiedomein."""
    n = max(int(n), 8)
    w = np.fft.rfft(rng.standard_normal(n))
    f = np.fft.rfftfreq(n, 1.0 / sr)
    h = np.ones_like(f)
    if lo:
        x = f / lo
        h *= x ** orde / np.sqrt(1.0 + x ** (2 * orde))
    if hi:
        h /= np.sqrt(1.0 + (f / hi) ** (2 * orde))
    y = np.fft.irfft(w * h, n)
    return y / (np.sqrt(np.mean(y ** 2)) + 1e-12)


def additief(ph, amps, f0, sr, kmax_hz):
    """Som van harmonischen tot kmax_hz; amps(k) mag een array in de tijd zijn."""
    y = np.zeros_like(ph)
    k = 1
    while k * f0 < min(kmax_hz, 0.45 * sr):
        y += amps(k) * np.sin(k * ph)
        k += 1
    return y


# ---------------------------------------------------------------- instrumenten
# Elke functie: (freq, duur, vel, sr, rng) -> mono array inclusief uitklinken.

def ep(f, duur, vel, sr, rng):
    """Elektrische piano: FM 1:1 waarvan de index snel terugvalt, plus een
    klein 'tine'-tikje. Lage noten klinken langer na dan hoge, net als echt."""
    n = int((duur + 0.3) * sr)
    t = _t(n, sr)
    tau = float(np.clip(1.5 * (262.0 / f) ** 0.6, 0.4, 3.0))
    amp = aanzet(t, 0.002) * np.exp(-t / tau) * los(t, duur, 0.07)
    idx = (0.5 + 1.4 * vel) * np.exp(-t / 0.25) + 0.3
    ph = TWO_PI * f * t
    y = np.sin(ph + idx * np.sin(ph))
    if 7 * f < 0.4 * sr:
        y += 0.1 * vel * np.exp(-t / 0.015) * np.sin(7 * ph)
    return y * amp * vel


def bas(f, duur, vel, sr, rng):
    """Sinus met tweede en derde boventoon en een tanh: rond, maar met genoeg
    boventonen om op een telefoon nog als bas te lezen."""
    n = int((duur + 0.15) * sr)
    t = _t(n, sr)
    fr = f * (1.0 + 0.012 * np.exp(-t / 0.015))
    ph = fase(fr, sr)
    verval = 0.55 + 0.45 * np.exp(-t / 0.28)
    w = np.sin(ph) + 0.35 * np.sin(2 * ph) + 0.12 * np.sin(3 * ph) \
        + 0.22 * np.exp(-t / 0.035) * np.sin(4 * ph)
    w = np.tanh(1.5 * w * verval) / np.tanh(1.5)
    return w * aanzet(t, 0.004) * los(t, duur, 0.035) * vel


def fluit(f, duur, vel, sr, rng):
    """Zachte lead: bijna sinus, vibrato pas na een kwart seconde, beetje adem."""
    n = int((duur + 0.3) * sr)
    t = _t(n, sr)
    diepte = 0.0055 * np.clip((t - 0.15) / 0.25, 0.0, 1.0)
    fr = f * (1.0 + diepte * np.sin(TWO_PI * 5.3 * t)) * (1.0 - 0.012 * np.exp(-t / 0.025))
    ph = fase(fr, sr)
    w = np.sin(ph) + 0.3 * np.sin(2 * ph) + 0.12 * np.sin(3 * ph) + 0.05 * np.sin(4 * ph) + 0.02 * np.sin(5 * ph)
    adem = bandruis(n, 1200, 4000, sr, rng) * (0.05 * np.exp(-t / 0.06) + 0.012)
    amp = aanzet(t, 0.03) * (0.82 + 0.18 * np.exp(-t / 0.15)) * los(t, duur, 0.06)
    return (w + adem) * amp * vel


def puls(f, duur, vel, sr, rng):
    """Pulse met smalle breedte, maar additief opgebouwd en boven 1,8 kHz al
    afgerond: het karakter van chiptune zonder het geschreeuw."""
    n = int((duur + 0.25) * sr)
    t = _t(n, sr)
    diepte = 0.004 * np.clip((t - 0.12) / 0.2, 0.0, 1.0)
    ph = fase(f * (1.0 + diepte * np.sin(TWO_PI * 5.6 * t)), sr)
    b = 0.3
    helder = 1.0 + 0.6 * np.exp(-t / 0.05)          # knipoog van een filterenvelope
    y = additief(ph, lambda k: (np.sin(np.pi * k * b) / k)
                 / np.sqrt(1.0 + (k * f / (1500.0 * helder)) ** 2), f, sr, 4500)
    amp = aanzet(t, 0.008) * (0.8 + 0.2 * np.exp(-t / 0.12)) * los(t, duur, 0.05)
    return y * amp * vel * 1.6


def marimba(f, duur, vel, sr, rng):
    """Mallet: grondtoon met de typische boventonen op ~4x en ~10x die snel
    wegsterven. Het Animal Crossing-randje van het geheel."""
    tau = float(np.clip(0.42 * (440.0 / f) ** 0.6, 0.12, 0.9))
    n = int(min(duur + 4 * tau, 2.5) * sr)
    t = _t(n, sr)
    ph = TWO_PI * f * t
    y = np.sin(ph) * np.exp(-t / tau)
    if 3.93 * f < 0.42 * sr:
        y += 0.2 * np.sin(3.93 * ph) * np.exp(-t / (tau * 0.2))
    if 9.4 * f < 0.42 * sr:
        y += 0.05 * np.sin(9.4 * ph) * np.exp(-t / (tau * 0.07))
    return y * aanzet(t, 0.0015) * los(t, duur + 0.25, 0.12) * vel


def koper(f, duur, vel, sr, rng):
    """Zacht koper: zaagtand waarvan de helderheid opengaat bij de aanzet
    ('bwah'), twee licht ontstemde stemmen."""
    n = int((duur + 0.3) * sr)
    t = _t(n, sr)
    B = 1.0 + (1.5 + 3.5 * vel) * (1.0 - np.exp(-t / 0.035)) * (0.7 + 0.3 * np.exp(-t / 0.3))
    vib = 1.0 + 0.004 * np.clip((t - 0.25) / 0.2, 0, 1) * np.sin(TWO_PI * 5.0 * t)
    y = np.zeros(n)
    for cent in (-4.0, 4.0):
        fr = f * 2 ** (cent / 1200.0) * vib
        ph = fase(fr, sr) + rng.uniform(0, TWO_PI)
        y += additief(ph, lambda k: np.exp(-(k - 1) / B) / k, f, sr, 5000)
    amp = aanzet(t, 0.025) * los(t, duur, 0.06)
    return 0.6 * y * amp * vel


def pad(freqs, duur, vel, sr, rng):
    """Stereo pad: per noot twee iets ontstemde zaagtanden met weinig
    boventonen, links en rechts. Langzame aanzet."""
    n = int((duur + 1.1) * sr)
    t = _t(n, sr)
    out = np.zeros((2, n))
    for f in freqs:
        for ch, cent in ((0, -7.0), (1, 7.0)):
            fr = f * 2 ** (cent / 1200.0)
            ph = TWO_PI * fr * t + rng.uniform(0, TWO_PI)
            out[ch] += additief(ph, lambda k: 1.0 / k ** 1.7, fr, sr, 2500)
    amp = aanzet(t, min(0.4, duur * 0.5)) * los(t, duur, 0.25)
    return out * amp * vel / max(1, len(freqs)) ** 0.5


def schuiffluit(f0, f1, duur, vel, sr, rng):
    """Het schuiffluitje van de achtervolging: sinus die omhoog glijdt."""
    n = int((duur + 0.2) * sr)
    t = _t(n, sr)
    x = np.clip(t / duur, 0, 1)
    fr = f0 * (f1 / f0) ** (x ** 1.3) * (1.0 + 0.012 * np.sin(TWO_PI * 6.5 * t))
    ph = fase(fr, sr)
    y = np.sin(ph) + 0.12 * np.sin(2 * ph)
    return y * aanzet(t, 0.03) * los(t, duur, 0.04) * vel


# ---------------------------------------------------------------- drums

def _kick(sr, rng):
    n = int(0.8 * sr)
    t = _t(n, sr)
    f = 52.0 + 115.0 * np.exp(-t / 0.028)
    y = np.sin(fase(f, sr)) * np.exp(-t / 0.24) * aanzet(t, 0.0015)
    y += 0.22 * bandruis(n, 1000, 5000, sr, rng) * np.exp(-t / 0.004)
    return np.tanh(1.5 * y) / np.tanh(1.5)


def _snare(sr, rng):
    n = int(0.3 * sr)
    t = _t(n, sr)
    lijf = 0.55 * np.sin(TWO_PI * 185 * t) * np.exp(-t / 0.045) \
        + 0.25 * np.sin(TWO_PI * 330 * t) * np.exp(-t / 0.03)
    sis = 0.6 * bandruis(n, 1400, 6000, sr, rng) * np.exp(-t / 0.09)
    return (lijf + sis) * aanzet(t, 0.0012)


def _rim(sr, rng):
    n = int(0.09 * sr)
    t = _t(n, sr)
    y = 0.6 * np.sin(TWO_PI * 1650 * t) * np.exp(-t / 0.011) \
        + 0.5 * np.sin(TWO_PI * 480 * t) * np.exp(-t / 0.02) \
        + 0.3 * bandruis(n, 2000, 5000, sr, rng) * np.exp(-t / 0.005)
    return y * aanzet(t, 0.0008)


def _brush(sr, rng):
    n = int(0.25 * sr)
    t = _t(n, sr)
    return bandruis(n, 1500, 7000, sr, rng) * aanzet(t, 0.022) * np.exp(-t / 0.08)


def _hat(sr, rng):
    n = int(0.08 * sr)
    t = _t(n, sr)
    return bandruis(n, 7000, 12000, sr, rng) * np.exp(-t / 0.022) * aanzet(t, 0.0008)


def _ohat(sr, rng):
    n = int(0.6 * sr)
    t = _t(n, sr)
    return bandruis(n, 6500, 12000, sr, rng) * np.exp(-t / 0.14) * aanzet(t, 0.001)


def _shaker(sr, rng):
    n = int(0.15 * sr)
    t = _t(n, sr)
    return bandruis(n, 4000, 10000, sr, rng) * aanzet(t, 0.012) * np.exp(-t / 0.035)


def _clap(sr, rng):
    n = int(0.25 * sr)
    t = _t(n, sr)
    env = np.zeros(n)
    for d in (0.0, 0.011, 0.022):
        m = t >= d
        env[m] += np.exp(-(t[m] - d) / 0.005)
    env += 0.5 * np.exp(-np.maximum(t - 0.022, 0) / 0.07) * (t >= 0.022)
    return bandruis(n, 900, 3000, sr, rng) * env * 0.6


def _tom(f):
    def maak(sr, rng):
        n = int(0.7 * sr)
        t = _t(n, sr)
        y = np.sin(fase(f * (1 + 0.35 * np.exp(-t / 0.02)), sr)) * np.exp(-t / 0.17)
        y += 0.08 * bandruis(n, 300, 3000, sr, rng) * np.exp(-t / 0.01)
        return y * aanzet(t, 0.0015)
    return maak


def _crash(sr, rng):
    n = int(2.2 * sr)
    t = _t(n, sr)
    return bandruis(n, 3000, 11000, sr, rng) * np.exp(-t / 0.75) * aanzet(t, 0.003)


def _blok(sr, rng):
    n = int(0.1 * sr)
    t = _t(n, sr)
    y = np.sin(TWO_PI * 950 * t) * np.exp(-t / 0.025) + 0.35 * np.sin(TWO_PI * 2180 * t) * np.exp(-t / 0.012)
    return y * aanzet(t, 0.0008)


# naam: (maker, stem, pan, niveau binnen de stem)
KIT = {
    "kick": (_kick, "kick", 0.0, 1.0),
    "snare": (_snare, "snare", 0.05, 1.0),
    "rim": (_rim, "snare", -0.1, 0.7),
    "brush": (_brush, "snare", 0.1, 0.55),
    "clap": (_clap, "snare", 0.15, 0.8),
    "tomh": (_tom(210), "snare", -0.25, 0.9),
    "tomm": (_tom(160), "snare", 0.0, 0.9),
    "toml": (_tom(120), "snare", 0.25, 0.95),
    "hat": (_hat, "perc", 0.3, 1.0),
    "ohat": (_ohat, "perc", 0.3, 0.8),
    "shaker": (_shaker, "perc", -0.35, 0.8),
    "crash": (_crash, "perc", -0.2, 0.6),
    "blok": (_blok, "perc", -0.3, 1.3),
}


# ---------------------------------------------------------------- het stuk

class Stuk:
    """Tijdlijn per stem (stereo). `rond` betekent: het einde loopt door in
    het begin, zodat de loop klopt inclusief alles wat over het einde klinkt."""

    def __init__(self, naam, bpm, maten, swing=0.6, rond=True, staart=0.0, sr=SR_M):
        self.naam, self.bpm, self.maten, self.swing = naam, bpm, maten, swing
        self.rond, self.sr = rond, sr
        self.tel_s = 60.0 / bpm
        self.L = int(round(maten * 4 * self.tel_s * sr))
        self.n = self.L + (0 if rond else int(staart * sr))
        self.stems = {}
        self.rng = np.random.default_rng(zlib.crc32(naam.encode()))
        self.akk = []           # per maat: [(tel, (grond, kwaliteit))]
        self.kit = {k: [v[0](sr, self.rng) for _ in range(3)] for k, v in KIT.items()}

    def tijd(self, maat, tel):
        """Tel naar seconden, met swing op de achtsten."""
        heel = math.floor(tel + 1e-9)
        fr = tel - heel
        sw = self.swing
        g = fr / 0.5 * sw if fr < 0.5 else sw + (fr - 0.5) / 0.5 * (1.0 - sw)
        return (maat * 4 + heel + g) * self.tel_s

    def leg(self, stem, t, y, pan=0.0):
        if y.ndim == 1:
            a = (pan + 1.0) * np.pi / 4.0
            y = np.vstack([y * np.cos(a), y * np.sin(a)]) * math.sqrt(2.0)
        # Elke klank eindigt op een korte cos²-flank: een staart die op 5 % van
        # zijn piek wordt afgeknipt is in een loop van een minuut een tik.
        k = min(int(0.01 * self.sr), y.shape[1] // 4)
        if k > 1:
            y = y.copy()
            y[:, -k:] *= np.cos(0.5 * np.pi * np.linspace(0, 1, k)) ** 2
        buf = self.stems.get(stem)
        if buf is None:
            buf = self.stems[stem] = np.zeros((2, self.n))
        i0 = int(round(t * self.sr))
        m = y.shape[1]
        if self.rond:
            pos = 0
            while pos < m:
                s = (i0 + pos) % self.L
                k = min(m - pos, self.L - s)
                buf[:, s:s + k] += y[:, pos:pos + k]
                pos += k
        else:
            if i0 < 0:
                y, i0 = y[:, -i0:], 0
            k = min(y.shape[1], self.n - i0)
            if k > 0:
                buf[:, i0:i0 + k] += y[:, :k]

    def noot(self, stem, instr, maat, tel, duur, m, vel, pan=0.0, jitter=0.004):
        t0 = self.tijd(maat, tel)
        t1 = self.tijd(maat, tel + duur)
        t0 += self.rng.normal(0.0, jitter) if jitter else 0.0
        vel *= 1.0 + self.rng.normal(0.0, 0.05)
        y = instr(hz(m), max(0.03, t1 - t0), vel, self.sr, self.rng)
        self.leg(stem, t0, y, pan)

    def drum(self, naam, maat, tel, vel):
        maker, stem, pan, niv = KIT[naam]
        y = self.kit[naam][self.rng.integers(3)]
        vel *= 1.0 + self.rng.normal(0.0, 0.06)
        self.leg(stem, self.tijd(maat, tel) + self.rng.normal(0.0, 0.002), y * vel * niv, pan)

    # -- akkoorden
    def akkoord_op(self, maat, tel):
        """(akkoord, eindtel binnen de maat) op een plek in het stuk."""
        rij = self.akk[maat % len(self.akk)]
        huidig, eind = rij[0][1], 4.0
        for i, (b, ak) in enumerate(rij):
            if tel >= b - 1e-9:
                huidig = ak
                eind = rij[i + 1][0] if i + 1 < len(rij) else 4.0
        return huidig, eind

    def volgend_akkoord(self, maat, tel):
        _, eind = self.akkoord_op(maat, tel)
        if eind < 4.0:
            return self.akkoord_op(maat, eind)[0]
        return self.akkoord_op(maat + 1, 0.0)[0]


def progressie(rijen, transp):
    """['Fmaj9', ['Em7', 'A7'], ...] -> per maat [(tel, (grond, kwal))]."""
    uit = []
    for r in rijen:
        delen = r if isinstance(r, list) else [r]
        stap = 4.0 / len(delen)
        maat = []
        for i, sym in enumerate(delen):
            m = re.fullmatch(r"([A-G][#b]?)(.*)", sym)
            maat.append((i * stap, ((pc(m.group(1)) + transp) % 12, m.group(2) or "maj")))
        uit.append(maat)
    return uit


# ---------------------------------------------------------------- het materiaal
# Akkoordenschema's en melodieën staan in F majeur (de ontsnapping in d klein);
# de dagen transponeren ze. Melodienotatie: (maat, tel, duur in tellen, noot).

PROG_A = ["Fmaj9", ["Em7", "A7"], "Dm9", ["Gm7", "C9"]] * 2
PROG_B = ["Bbmaj7", "Am7", "Gm7", ["Am7", "Dm7"], "Bbmaj7", ["Am7", "D7"], "Gm7", ["C7sus", "C7"]]

# Het thema. Maat 1 is de kop die overal terugkomt: C-D-F-A.
HAAK = [
    (0, 0.0, 0.5, "C5"), (0, 0.5, 0.5, "D5"), (0, 1.0, 0.5, "F5"), (0, 1.5, 1.5, "A5"), (0, 3.5, 0.5, "G5"),
    (1, 0.0, 1.0, "E5"), (1, 1.0, 0.5, "G5"), (1, 1.5, 0.5, "E5"), (1, 2.0, 1.5, "C#5"), (1, 3.5, 0.5, "D5"),
    (2, 0.0, 0.5, "E5"), (2, 0.5, 0.5, "F5"), (2, 1.0, 0.5, "A5"), (2, 1.5, 1.5, "E5"), (2, 3.5, 0.5, "D5"),
    (3, 0.0, 1.0, "D5"), (3, 1.0, 0.5, "Bb4"), (3, 1.5, 0.5, "G4"), (3, 2.0, 0.5, "E4"), (3, 2.5, 0.5, "G4"),
    (3, 3.0, 0.5, "Bb4"), (3, 3.5, 0.5, "D5"),
    (4, 0.0, 0.5, "C5"), (4, 0.5, 0.5, "D5"), (4, 1.0, 0.5, "F5"), (4, 1.5, 1.5, "A5"), (4, 3.5, 0.5, "G5"),
    (5, 0.0, 0.5, "A5"), (5, 0.5, 0.5, "G5"), (5, 1.0, 0.5, "E5"), (5, 1.5, 0.5, "D5"), (5, 2.0, 0.5, "E5"),
    (5, 2.5, 1.5, "G5"),
    (6, 0.0, 1.5, "F5"), (6, 1.5, 0.5, "E5"), (6, 2.0, 1.0, "D5"), (6, 3.0, 1.0, "A4"),
    (7, 0.0, 1.0, "Bb4"), (7, 1.0, 1.0, "A4"), (7, 2.0, 2.0, "G4"),
]

# De brug: langere noten, zingt meer.
BRUG = [
    (0, 0.0, 1.5, "D5"), (0, 1.5, 0.5, "F5"), (0, 2.0, 2.0, "A5"),
    (1, 0.0, 0.5, "G5"), (1, 0.5, 0.5, "E5"), (1, 1.0, 2.0, "C5"), (1, 3.0, 1.0, "E5"),
    (2, 0.0, 1.5, "F5"), (2, 1.5, 0.5, "D5"), (2, 2.0, 2.0, "Bb4"),
    (3, 0.0, 1.0, "C5"), (3, 1.0, 1.0, "E5"), (3, 2.0, 1.0, "F5"), (3, 3.0, 1.0, "A5"),
    (4, 0.0, 1.5, "A5"), (4, 1.5, 0.5, "G5"), (4, 2.0, 1.0, "F5"), (4, 3.0, 1.0, "D5"),
    (5, 0.0, 1.0, "E5"), (5, 1.0, 1.0, "C5"), (5, 2.0, 1.0, "F#5"), (5, 3.0, 1.0, "A5"),
    (6, 0.0, 2.0, "G5"), (6, 2.0, 0.5, "F5"), (6, 2.5, 0.5, "D5"), (6, 3.0, 1.0, "Bb4"),
    (7, 0.0, 1.5, "F5"), (7, 1.5, 0.5, "E5"), (7, 2.0, 1.0, "G5"), (7, 3.0, 1.0, "E5"),
]

# De kale A-sectie: alleen de kop op marimba, met korte antwoorden.
KOP = [(0, 0.0, 0.5, "C5"), (0, 0.5, 0.5, "D5"), (0, 1.0, 0.5, "F5"), (0, 1.5, 1.0, "A5")]
ANTWOORD = KOP + [(4 + m, tl, d, n) for (m, tl, d, n) in KOP] + [
    (1, 2.5, 0.5, "C#5"), (1, 3.0, 0.5, "E5"), (1, 3.5, 0.5, "G5"),
    (3, 2.5, 0.5, "E5"), (3, 3.0, 0.5, "G5"), (3, 3.5, 0.5, "Bb5"),
    (5, 2.5, 0.5, "E5"), (5, 3.0, 0.5, "G5"), (5, 3.5, 0.5, "A5"),
    (7, 2.0, 0.5, "G5"), (7, 2.5, 0.5, "E5"), (7, 3.0, 0.5, "D5"), (7, 3.5, 0.5, "Bb4"),
]

# Achtervolging in d klein: dezelfde kop, D-E-F-A.
PROG_JA = ["Dm9", ["Bbmaj7", "A7b9"], "Dm7", ["Gm7", "A7b9"]] * 2
PROG_JB = ["Gm7", "Dm7", "Ebmaj7", "A7b9", "Gm7", "Dm7", "Bbmaj7", "A7b9"]
JAAG = [
    (0, 0.0, 0.5, "D5"), (0, 0.5, 0.5, "E5"), (0, 1.0, 0.5, "F5"), (0, 1.5, 1.5, "A5"), (0, 3.5, 0.5, "G5"),
    (1, 0.0, 1.0, "F5"), (1, 1.0, 0.5, "D5"), (1, 1.5, 0.5, "Bb4"), (1, 2.0, 1.0, "C#5"), (1, 3.0, 1.0, "E5"),
    (2, 0.0, 0.5, "F5"), (2, 0.5, 0.5, "E5"), (2, 1.0, 0.5, "D5"), (2, 1.5, 1.5, "A4"), (2, 3.5, 0.5, "C5"),
    (3, 0.0, 1.0, "Bb4"), (3, 1.0, 0.5, "A4"), (3, 1.5, 0.5, "G4"), (3, 2.0, 0.5, "C#5"), (3, 2.5, 0.5, "E5"),
    (3, 3.0, 0.5, "G5"), (3, 3.5, 0.5, "A5"),
    (4, 0.0, 0.5, "D5"), (4, 0.5, 0.5, "E5"), (4, 1.0, 0.5, "F5"), (4, 1.5, 1.5, "A5"), (4, 3.5, 0.5, "G5"),
    (5, 0.0, 1.0, "F5"), (5, 1.0, 0.5, "D5"), (5, 1.5, 0.5, "Bb4"), (5, 2.0, 1.0, "C#5"), (5, 3.0, 1.0, "E5"),
    (6, 0.0, 0.5, "F5"), (6, 0.5, 0.5, "A5"), (6, 1.0, 0.5, "D6"), (6, 1.5, 1.5, "A5"), (6, 3.5, 0.5, "F5"),
    (7, 0.0, 0.5, "E5"), (7, 0.5, 0.5, "F5"), (7, 1.0, 0.5, "E5"), (7, 1.5, 0.5, "D5"), (7, 2.0, 1.0, "C#5"),
    (7, 3.0, 1.0, "A4"),
]
# Het sluipstuk: op de tel, staccato, op marimba.
SLUIP = [
    (0, 0, 0.5, "G4"), (0, 1, 0.5, "Bb4"), (0, 2, 0.5, "D5"), (0, 3, 0.5, "F5"),
    (1, 0, 0.5, "A5"), (1, 1, 0.5, "F5"), (1, 2, 0.5, "D5"), (1, 3, 0.5, "A4"),
    (2, 0, 0.5, "G4"), (2, 1, 0.5, "Bb4"), (2, 2, 0.5, "D5"), (2, 3, 0.5, "G5"),
    (3, 0, 0.5, "A5"), (3, 0.5, 0.5, "G5"), (3, 1, 0.5, "F5"), (3, 1.5, 0.5, "E5"), (3, 2, 1, "C#5"), (3, 3, 1, "A4"),
    (4, 0, 0.5, "G4"), (4, 1, 0.5, "Bb4"), (4, 2, 0.5, "D5"), (4, 3, 0.5, "F5"),
    (5, 0, 0.5, "A5"), (5, 1, 0.5, "F5"), (5, 2, 0.5, "D5"), (5, 3, 0.5, "A4"),
    (6, 0, 0.5, "D5"), (6, 0.5, 0.5, "F5"), (6, 1, 0.5, "A5"), (6, 1.5, 0.5, "F5"), (6, 2, 0.5, "D5"),
    (6, 2.5, 0.5, "Bb4"), (6, 3, 1, "F4"),
    (7, 0, 0.5, "E5"), (7, 0.5, 0.5, "C#5"), (7, 1, 0.5, "A4"), (7, 1.5, 0.5, "G4"),
]

# Uitslag: fanfare in drie maten, daarna een rustige vamp van acht.
PROG_FANFARE = ["F", ["Bbmaj7", "C9"], "Fmaj9"]
FANFARE = [
    (0, 0.0, 0.3, "C5"), (0, 1 / 3, 0.3, "C5"), (0, 2 / 3, 0.3, "C5"), (0, 1.0, 0.9, "F5"),
    (0, 2.0, 0.6, "A5"), (0, 2 + 2 / 3, 0.3, "G5"), (0, 3.0, 0.95, "A5"),
    (1, 0.0, 0.5, "Bb5"), (1, 0.5, 0.5, "A5"), (1, 1.0, 0.5, "G5"), (1, 1.5, 0.5, "F5"),
    (1, 2.0, 0.6, "E5"), (1, 2 + 2 / 3, 0.3, "G5"), (1, 3.0, 0.95, "Bb5"),
    (2, 0.0, 2.6, "A5"),
]
PROG_VAMP = ["Fmaj9", "Dm9", "Gm7", "C9", "Fmaj9", "Dm9", "Gm7", ["C7sus", "C9"]]


# ---------------------------------------------------------------- patronen
# Begeleiding per maat, (tel, duur, vel[, aangestoten]). Aangestoten = het
# akkoord van de volgende maat al op de 'en' van vier.

COMP = {
    "lui": [[(0, 2.0, 0.62), (2.5, 1.2, 0.45)], [(0.5, 1.3, 0.5), (2.0, 1.8, 0.58)]],
    "duw": [[(0, 1.0, 0.65), (1.5, 0.5, 0.5), (2.5, 0.5, 0.55), (3.5, 1.0, 0.65, True)],
            [(1.0, 0.5, 0.45), (1.5, 0.9, 0.55), (2.5, 0.5, 0.5), (3.0, 0.9, 0.55)]],
    "funk": [[(0, 0.35, 0.7), (0.75, 0.2, 0.42), (1.5, 0.35, 0.58), (2.5, 0.3, 0.58), (3.0, 0.2, 0.42),
              (3.5, 0.35, 0.58)]],
    "stoot": [[(0.5, 0.3, 0.62), (1.5, 0.3, 0.55), (2.5, 0.3, 0.62), (3.5, 0.5, 0.66, True)],
              [(0.5, 0.3, 0.58), (1.5, 0.3, 0.52), (2.0, 0.25, 0.45), (2.5, 0.3, 0.6)]],
    "jacht": [[(0, 0.3, 0.72), (0.5, 0.25, 0.42), (1.5, 0.3, 0.62), (2.0, 0.25, 0.48), (2.5, 0.3, 0.62),
               (3.5, 0.5, 0.68, True)]],
    "achter": [[(0.5, 0.18, 0.6), (1.5, 0.18, 0.52), (2.5, 0.18, 0.6), (3.5, 0.18, 0.52)]],
}

# Bas: (tel, duur, toon). R grondtoon, 8 octaaf, 5 kwint, 3 terts, 6 sext,
# b7 kleine septiem, A naderingsnoot naar het volgende akkoord.
BAS = {
    "twee": [[(0, 1.5, "R"), (2, 1.4, "5"), (3.5, 0.5, "A")]],
    "twee+": [[(0, 1.0, "R"), (1.5, 0.45, "8"), (2, 0.9, "5"), (3, 0.45, "R"), (3.5, 0.5, "A")]],
    "loop": [[(0, 0.9, "R"), (1, 0.9, "3"), (2, 0.9, "5"), (3, 0.9, "A")],
             [(0, 0.9, "R"), (1, 0.9, "5"), (2, 0.9, "6"), (3, 0.9, "A")]],
    "funk": [[(0, 0.7, "R"), (0.75, 0.2, "R"), (1.5, 0.45, "8"), (2, 0.45, "5"), (2.5, 0.25, "b7"),
              (3, 0.45, "8"), (3.5, 0.45, "A")]],
    "jacht": [[(0, 0.45, "R"), (0.5, 0.4, "R"), (1, 0.4, "8"), (1.5, 0.4, "R"), (2, 0.45, "5"),
               (2.5, 0.4, "R"), (3, 0.4, "8"), (3.5, 0.45, "A")]],
    "achter": [[(i * 0.5, 0.3, "R" if i % 2 == 0 else "8") for i in range(8)]],
    "vamp": [[(0, 2.4, "R"), (2.5, 0.45, "5"), (3, 0.9, "8")], [(0, 1.5, "R"), (2, 1.4, "5"), (3.5, 0.5, "A")]],
}


def _achtsten(vel, aan=0.75):
    return [(i * 0.5, vel * (aan if i % 2 == 0 else 1.0)) for i in range(8)]


def _zestienden(vel):
    return [(i * 0.25, vel * (1.0 if i % 4 == 2 else 0.8 if i % 2 == 0 else 0.55)) for i in range(16)]


DRUMS = {
    "brush": {"kick": [(0, 0.55), (2.5, 0.3)], "brush": [(1, 0.5), (3, 0.55)], "hat": _achtsten(0.22, 0.6)},
    "ma": {"kick": [(0, 0.75), (2.5, 0.45)], "rim": [(1, 0.5), (3, 0.55)], "hat": _achtsten(0.3, 0.6)},
    "di": {"kick": [(0, 0.85), (2, 0.6), (2.5, 0.45)], "snare": [(1, 0.6), (3, 0.65)], "hat": _achtsten(0.34)},
    "wo": {"kick": [(0, 0.9), (1.5, 0.45), (2.5, 0.65)],
           "snare": [(1, 0.7), (3, 0.72), (0.75, 0.13), (2.75, 0.13)],
           "clap": [(3, 0.45)], "hat": _achtsten(0.36), "ohat": [(3.5, 0.35)]},
    "do": {"kick": [(0, 0.9), (1, 0.8), (2, 0.85), (3, 0.8)], "snare": [(1, 0.68), (3, 0.72)],
           "clap": [(1, 0.38), (3, 0.42)], "shaker": _zestienden(0.32),
           "ohat": [(0.5, 0.28), (1.5, 0.28), (2.5, 0.28), (3.5, 0.32)]},
    "vr": {"kick": [(0, 0.95), (1, 0.75), (2, 0.9), (2.5, 0.55), (3, 0.75)],
           "snare": [(1, 0.75), (3, 0.8)], "clap": [(1, 0.42), (3, 0.48)],
           "hat": _zestienden(0.3), "ohat": [(3.5, 0.38)], "shaker": _achtsten(0.22)},
    "jacht": {"kick": [(0, 0.85), (1, 0.8), (2, 0.85), (3, 0.8)], "snare": [(1, 0.7), (3, 0.75)],
              "hat": _achtsten(0.34, 0.7), "blok": [(0.5, 0.35), (2.5, 0.3), (3.5, 0.25)]},
}

# Breaks in de laatste maat van een sectie: vanaf `vanaf` zwijgen kick en
# snare uit het patroon en speelt dit.
FILLS = {
    "brush": (4.0, []),
    "ma": (3.5, [("rim", 3.5, 0.4), ("rim", 3.75, 0.3)]),
    "di": (3.0, [("snare", 3.0, 0.55), ("snare", 3.5, 0.5), ("kick", 3.5, 0.5)]),
    "wo": (2.5, [("snare", 2.5, 0.45), ("tomh", 3.0, 0.55), ("tomm", 3.5, 0.55), ("snare", 3.75, 0.35)]),
    "do": (2.5, [("tomh", 2.5, 0.6), ("tomm", 3.0, 0.6), ("toml", 3.5, 0.65), ("snare", 3.75, 0.4)]),
    "vr": (2.0, [("snare", 2.0 + i * 0.25, 0.25 + 0.06 * i) for i in range(7)] + [("toml", 3.75, 0.7)]),
    "jacht": (2.0, [("snare", 2.0 + i * 0.25, 0.22 + 0.07 * i) for i in range(8)]),
}


# ---------------------------------------------------------------- arrangeren

def bas_toon(stuk, token, maat, tel, ak, oneven):
    def grond(a):
        # C2 t/m B2: laag genoeg voor een bas, hoog genoeg dat de grondtoon
        # en zijn boventonen op een telefoon nog doorkomen.
        g = a[0] + 12 * 3
        while g < 36:
            g += 12
        while g >= 48:
            g -= 12
        return g
    r = grond(ak)
    if token == "R":
        return r
    if token == "8":
        return r + 12
    if token == "5":
        return r + 7 if r + 7 <= 52 else r - 5
    if token == "3":
        return r + (3 if is_mineur(ak[1]) else 4)
    if token == "6":
        return r + 9
    if token == "b7":
        return r + (11 if ak[1].startswith("maj") else 10)
    if token == "A":
        doel = grond(stuk.volgend_akkoord(maat, tel))
        return doel + (1 if oneven else -1)
    raise ValueError(token)


def leg_bas(stuk, maat, patroon, vel=0.8):
    pat = BAS[patroon][maat % len(BAS[patroon])]
    for (tel, duur, tok) in pat:
        ak, eind = stuk.akkoord_op(maat, tel)
        wissel = [b for (b, _) in stuk.akk[maat % len(stuk.akk)] if b > 0]
        if tok != "A" and tel in wissel:
            tok = "R"                          # op de akkoordwissel altijd de grondtoon
        duur = min(duur, eind - tel - 0.05) if tok != "A" else duur
        m = bas_toon(stuk, tok, maat, tel, ak, maat % 2)
        stuk.noot("bas", bas, maat, tel, max(duur, 0.2), m, vel * (1.0 if tel % 1 == 0 else 0.8), jitter=0.003)


def leg_comp(stuk, maat, patroon, centrum=62, rol=0.0, stem="ep", instr=ep, vel_f=1.0):
    pat = COMP[patroon][maat % len(COMP[patroon])]
    for hit in pat:
        tel, duur, vel = hit[:3]
        duw = len(hit) > 3 and hit[3]
        if duw:
            ak = stuk.akkoord_op(maat + 1, 0.0)[0]
        else:
            ak, eind = stuk.akkoord_op(maat, tel)
            duur = min(duur, eind - tel - 0.05)
        noten = voicing(ak, centrum, getattr(stuk, "_vorige_v", None))
        stuk._vorige_v = noten
        for i, m in enumerate(noten):
            t0 = stuk.tijd(maat, tel) + i * rol + stuk.rng.normal(0, 0.003)
            t1 = stuk.tijd(maat, tel + duur)
            v = vel * vel_f * (1.0 + stuk.rng.normal(0, 0.05)) * (0.85 if i == 0 else 1.0)
            y = instr(hz(m), max(0.05, t1 - t0), v, stuk.sr, stuk.rng)
            stuk.leg(stem, t0, y, pan=(i - 1.5) * 0.12)


def leg_melodie(stuk, start, mel, stem, instr, transp, vel=0.8, art=1.0, pan=0.0, filter_tel=None):
    for (m, tel, duur, n) in mel:
        if filter_tel is not None and tel not in filter_tel:
            continue
        stuk.noot(stem, instr, start + m, tel, duur * art, midi(n) + transp, vel, pan=pan)


def leg_pad(stuk, maat, centrum=60, vel=0.5, instr=None):
    for (b, ak) in stuk.akk[maat % len(stuk.akk)]:
        _, eind = stuk.akkoord_op(maat, b)
        noten = voicing(ak, centrum, None)
        t0 = stuk.tijd(maat, b)
        t1 = stuk.tijd(maat, eind)
        if instr is None:
            stuk.leg("pad", t0, pad([hz(m) for m in noten], t1 - t0, vel, stuk.sr, stuk.rng))
        else:
            for i, m in enumerate(noten[1:]):
                y = instr(hz(m), t1 - t0 - 0.05, vel, stuk.sr, stuk.rng)
                stuk.leg("koper", t0, y, pan=(i - 1) * 0.3)


def leg_drums(stuk, maat, stijl, fill=False, crash=False):
    vanaf, extra = FILLS[stijl]
    for naam, hits in DRUMS[stijl].items():
        for (tel, vel) in hits:
            if fill and tel >= vanaf and naam in ("kick", "snare", "clap", "rim", "brush"):
                continue
            stuk.drum(naam, maat, tel, vel)
    if fill:
        for (naam, tel, vel) in extra:
            stuk.drum(naam, maat, tel, vel)
    if crash:
        stuk.drum("crash", maat, 0.0, 0.5)


# ---------------------------------------------------------------- mixen

# Niveaus per stem als 'actieve RMS' in dB, ten opzichte van de lead. Blind
# mixen gaat zo: elke stem wordt eerst naar zijn eigen doel gebracht, gemeten
# over de stukken waar hij echt speelt.
NIVEAU = dict(kick=-6.0, snare=-9.0, perc=-15.0, bas=-5.0, ep=-7.0, lead=-1.0,
              marimba=-6.0, pad=-14.0, koper=-8.0, fx=-9.0)
# (galm, delay)-send per stem
SEND = dict(kick=(0.0, 0.0), snare=(0.25, 0.0), perc=(0.12, 0.0), bas=(0.03, 0.0),
            ep=(0.3, 0.0), lead=(0.32, 0.25), marimba=(0.35, 0.15), pad=(0.5, 0.0),
            koper=(0.3, 0.0), fx=(0.4, 0.2))


def actief_rms(x, sr):
    mono = x.mean(axis=0)
    fr = int(0.05 * sr)
    k = len(mono) // fr
    r = np.sqrt(np.mean(mono[:k * fr].reshape(k, fr) ** 2, axis=1))
    drempel = r.max() * 10 ** (-30 / 20)
    return float(np.sqrt(np.mean(r[r > drempel] ** 2))) + 1e-12


def galm_ir(sr, rt, rng):
    """Stereo galm-impulsrespons: per band eigen nagalm (hoog sterft eerder),
    een paar vroege reflecties en 18 ms predelay."""
    n = int(rt * 1.4 * sr)
    t = _t(n, sr)
    ir = np.zeros((2, n))
    for ch in (0, 1):
        for lo, hi, fac in ((None, 400, 1.15), (400, 1500, 1.0), (1500, 4500, 0.65), (4500, 11000, 0.35)):
            ir[ch] += bandruis(n, lo, hi, sr, rng) * np.exp(-6.91 * t / (rt * fac))
        ir[ch] *= aanzet(t, 0.012)
    pre = int(0.018 * sr)
    ir = np.concatenate([np.zeros((2, pre)), ir], axis=1)
    for d, g, ch in ((0.007, 0.5, 0), (0.011, 0.45, 1), (0.019, 0.35, 0), (0.023, 0.3, 1)):
        ir[ch, int(d * sr)] += g * 8.0
    return ir / np.sqrt(np.sum(ir ** 2) / 2.0)


def conv_rond(x, h, n):
    """Circulaire convolutie over lengte n (de looplengte)."""
    if h.shape[-1] > n:
        h2 = np.zeros(h.shape[:-1] + (n,))
        for i in range(0, h.shape[-1], n):
            blok = h[..., i:i + n]
            h2[..., :blok.shape[-1]] += blok
        h = h2
    return np.fft.irfft(np.fft.rfft(x, n=n) * np.fft.rfft(h, n=n), n=n)


def delay_stereo(x, sr, tijd, terug=0.38, n_tik=8):
    """Ping-pong delay als frequentierespons: elke herhaling iets donkerder,
    om en om links en rechts."""
    n = len(x)
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(n, 1.0 / sr)
    stap = terug / (1.0 + 1j * f / 3200.0) * np.exp(-1j * TWO_PI * f * tijd)
    hl = np.zeros_like(X)
    hr = np.zeros_like(X)
    c = np.ones_like(X)
    for i in range(1, n_tik + 1):
        c = c * stap
        if i % 2:
            hl += c
        else:
            hr += c
    return np.vstack([np.fft.irfft(X * hl, n), np.fft.irfft(X * hr, n)])


def master_eq(x, sr):
    """Laag onder 40 Hz eruit, top zacht afgerond boven 12 kHz, een kleine dip
    rond 3,5 kHz (daar zit het schelle waar Daan last van had) en daaronder een
    brede, lichte verheffing van 1-2 kHz zodat piano en melodie niet dof worden."""
    n = x.shape[-1]
    f = np.fft.rfftfreq(n, 1.0 / sr)
    hp = f ** 2 / np.sqrt(f ** 4 + 40.0 ** 4)
    lp = 1.0 / np.sqrt(1.0 + (f / 12000.0) ** 4)
    dip = 10 ** (-1.5 / 20 * np.exp(-np.log2(np.maximum(f, 1.0) / 3500.0) ** 2 / (2 * 0.45 ** 2)))
    lucht = 10 ** (2.0 / 20 * np.exp(-np.log2(np.maximum(f, 1.0) / 1500.0) ** 2 / (2 * 0.7 ** 2)))
    return np.fft.irfft(np.fft.rfft(x, axis=-1) * (hp * lp * dip * lucht), n, axis=-1)


def mixdown(stuk, galm_rt=1.3, galm_db=-13.0, niveau=None, send=None, delay_tel=0.75, tremolo=0.22):
    niveau = {**NIVEAU, **(niveau or {})}
    send = {**SEND, **(send or {})}
    sr, n = stuk.sr, stuk.n
    droog = np.zeros((2, n))
    galm_in = np.zeros(n)
    dly_in = np.zeros(n)
    rapport = []
    for naam, buf in stuk.stems.items():
        if naam == "ep" and tremolo:
            # Koffer-tremolo: piano zwaait tussen links en rechts. Geheel aantal
            # periodes per loop, anders tikt het looppunt.
            per = stuk.L / sr
            freq = max(1, round(4.2 * per)) / per
            lfo = tremolo * np.sin(TWO_PI * freq * np.arange(n) / sr)
            buf = buf * np.vstack([1 + lfo, 1 - lfo])
        g = 10 ** (niveau[naam] / 20) / actief_rms(buf, sr)
        droog += g * buf
        s_g, s_d = send[naam]
        galm_in += g * s_g * buf.mean(axis=0)
        dly_in += g * s_d * buf.mean(axis=0)
        rapport.append(naam)
    dly = delay_stereo(dly_in, sr, delay_tel * stuk.tel_s) if dly_in.any() else np.zeros((2, n))
    galm_in += 0.5 * dly.mean(axis=0)
    ir = galm_ir(sr, galm_rt, np.random.default_rng(zlib.crc32((stuk.naam + "galm").encode())))
    nat = np.vstack([conv_rond(galm_in, ir[0], n), conv_rond(galm_in, ir[1], n)])
    # Galm op een vast niveau onder de droge mix: blind is dit veiliger dan sends gokken.
    nat *= np.sqrt(np.mean(droog ** 2)) * 10 ** (galm_db / 20) / (np.sqrt(np.mean(nat ** 2)) + 1e-12)
    mix = master_eq(droog + dly + nat, sr)
    mix /= np.abs(mix).max() + 1e-12
    mix = np.tanh(1.1 * mix * 0.7) / np.tanh(1.1 * 0.7) * 0.7        # beetje lijm, toppen afgerond
    return mix


# ---------------------------------------------------------------- de stukken

def _sectie(stuk, start, soort, cfg):
    """Eén sectie van acht maten. Soorten:
    A0 kaal (kop op marimba), A1 thema op de lead, A2 thema met marimba-verdubbeling,
    B1 brug op de lead met pad, B0 brug zonder lead (pad + marimba-echo)."""
    tr, lo = cfg["transp"], cfg.get("lead_oct", 0)
    lead_instr = {"fluit": fluit, "puls": puls}[cfg.get("lead", "fluit")]
    koper_aan = cfg.get("koper", False)
    for i in range(8):
        maat = start + i
        leg_drums(stuk, maat, cfg["drums"], fill=(i == 7 and cfg["drums"] != "brush"),
                  crash=(i == 0 and cfg.get("crash", False)))
        leg_bas(stuk, maat, cfg["bas"])
        # Zonder lead mag de piano iets meer naar voren: de kale A-sectie moet
        # een adempauze zijn, geen gat.
        leg_comp(stuk, maat, cfg["comp"], centrum=cfg.get("centrum", 62), rol=cfg.get("rol", 0.0),
                 vel_f=1.2 if soort == "A0" else 1.0)
        if soort.startswith("B"):
            leg_pad(stuk, maat, centrum=60, vel=0.5, instr=koper if koper_aan else None)
    if soort == "A0":
        leg_melodie(stuk, start, ANTWOORD, "marimba", marimba, tr + lo, vel=0.7, pan=-0.25)
        if koper_aan:
            for i in (3, 7):
                leg_comp(stuk, start + i, "stoot", centrum=66, stem="koper", instr=koper, vel_f=0.8)
    elif soort in ("A1", "A2"):
        leg_melodie(stuk, start, HAAK, "lead", lead_instr, tr + lo, vel=cfg.get("lead_vel", 0.8),
                    art=cfg.get("art", 0.95))
        if soort == "A2":
            leg_melodie(stuk, start, HAAK, "marimba", marimba, tr + lo + 12, vel=0.45, pan=-0.3)
    elif soort == "B1":
        leg_melodie(stuk, start, BRUG, "lead", lead_instr, tr + lo, vel=cfg.get("lead_vel", 0.8))
    elif soort == "B0":
        leg_melodie(stuk, start, BRUG, "marimba", marimba, tr + lo, vel=0.55, pan=-0.2, filter_tel=(0.0, 2.0))


DAGEN = {
    "rush_menu": dict(bpm=95, transp=0, swing=0.64, drums="brush", bas="twee", comp="lui", rol=0.012,
                      plan=["A1", "B0"], lead="fluit", lead_vel=0.62, galm=(1.8, -11.0),
                      niveau=dict(perc=-18.0, kick=-8.0)),
    "rush_ma": dict(bpm=100, transp=0, swing=0.62, drums="ma", bas="twee", comp="lui", rol=0.008,
                    plan=["A0", "A1", "B1"], lead="fluit", galm=(1.5, -12.0)),
    "rush_di": dict(bpm=108, transp=2, swing=0.61, drums="di", bas="twee+", comp="duw",
                    plan=["A0", "A1", "B1"], lead="fluit", galm=(1.4, -13.0)),
    "rush_wo": dict(bpm=116, transp=3, swing=0.60, drums="wo", bas="loop", comp="funk",
                    plan=["A0", "A1", "B1"], lead="puls", lead_vel=0.75, galm=(1.3, -13.0)),
    "rush_do": dict(bpm=126, transp=5, lead_oct=-12, swing=0.57, drums="do", bas="funk", comp="stoot",
                    plan=["A0", "A1", "B1"], lead="puls", koper=True, crash=True, galm=(1.2, -14.0),
                    niveau=dict(perc=-14.0)),
    "rush_vr": dict(bpm=138, transp=7, lead_oct=-12, swing=0.55, drums="vr", bas="jacht", comp="jacht",
                    plan=["A0", "A1", "B1", "A2"], lead="puls", koper=True, crash=True, galm=(1.1, -15.0),
                    niveau=dict(perc=-13.0, kick=-5.0, snare=-8.0)),
}


def maak_dag(naam):
    cfg = DAGEN[naam]
    plan = cfg["plan"]
    stuk = Stuk(naam, cfg["bpm"], 8 * len(plan), swing=cfg["swing"])
    rijen = []
    for s in plan:
        rijen += PROG_A if s.startswith("A") else PROG_B
    stuk.akk = progressie(rijen, cfg["transp"])
    for i, s in enumerate(plan):
        _sectie(stuk, 8 * i, s, cfg)
    rt, gdb = cfg["galm"]
    # De marimba draagt de kop in de kale A-sectie en staat daarom hoger dan
    # in de andere stukken.
    return mixdown(stuk, galm_rt=rt, galm_db=gdb, niveau={"marimba": -3.0, **cfg.get("niveau", {})})


def maak_ontsnapping():
    """Achtervolging: recht (geen swing), octaafbas, woodblock, en aan het eind
    van het sluipstuk een schuiffluitje omhoog dat de loop weer instuurt."""
    stuk = Stuk("rush_ontsnapping", 150, 16, swing=0.5)
    stuk.akk = progressie(PROG_JA + PROG_JB, 0)
    for maat in range(16):
        leg_drums(stuk, maat, "jacht", fill=(maat in (7, 15)), crash=(maat == 0))
        leg_bas(stuk, maat, "achter", vel=0.75)
        leg_comp(stuk, maat, "achter", centrum=63)
    leg_melodie(stuk, 0, JAAG, "lead", puls, 0, vel=0.8, art=0.7)
    leg_melodie(stuk, 8, SLUIP, "marimba", marimba, 0, vel=0.75, art=0.6, pan=-0.15)
    leg_melodie(stuk, 8, [(m, tl, d, n) for (m, tl, d, n) in SLUIP if tl in (0, 2)], "lead", puls, -12,
                vel=0.45, art=0.4)
    t0 = stuk.tijd(15, 2.0)
    stuk.leg("fx", t0, schuiffluit(hz(midi("A4")), hz(midi("D6")), stuk.tijd(15, 4.0) - t0 - 0.02, 0.7,
                                   stuk.sr, stuk.rng))
    return mixdown(stuk, galm_rt=0.9, galm_db=-16.0, niveau=dict(perc=-14.0, marimba=-5.0), tremolo=0.0)


def maak_menu():
    return maak_dag("rush_menu")


def harmonie_onder(top, ak, afstand=3):
    """Hoogste akkoordtoon minstens `afstand` halve tonen onder de top."""
    tonen = akkoordtonen(ak)
    m = top - afstand
    while m % 12 not in tonen:
        m -= 1
    return m


def maak_uitslag():
    """Fanfare (3 maten, eenmalig) + vamp (8 maten, loopt). Geeft (audio,
    loopstart in seconden)."""
    bpm = 120
    fan = Stuk("rush_uitslag_fanfare", bpm, 3, swing=0.5, rond=False, staart=3.0)
    fan.akk = progressie(PROG_FANFARE, 0)
    for (m, tel, duur, n) in FANFARE:
        top = midi(n)
        ak = fan.akkoord_op(m, tel)[0]
        h1 = harmonie_onder(top, ak)
        h2 = harmonie_onder(h1, ak)
        fan.noot("lead", koper, m, tel, duur, top, 0.85, jitter=0.0)
        fan.noot("koper", koper, m, tel, duur, h1, 0.7, pan=-0.25, jitter=0.002)
        fan.noot("koper", koper, m, tel, duur, h2, 0.6, pan=0.25, jitter=0.002)
    for (m, tel, duur, n) in [(0, 0, 0.3, "F2"), (0, 1, 0.9, "F2"), (0, 2, 0.9, "C2"), (0, 3, 0.9, "F2"),
                              (1, 0, 1.8, "Bb1"), (1, 2, 1.8, "C2"), (2, 0, 2.8, "F1")]:
        fan.noot("bas", bas, m, tel, duur, midi(n), 0.85, jitter=0.0)
    for tel in (0, 1 / 3, 2 / 3):
        fan.drum("snare", 0, tel, 0.35 + tel * 0.3)
    for (m, tel, v) in [(0, 1, 0.85), (0, 3, 0.6), (1, 0, 0.8), (1, 2, 0.7), (2, 0, 0.95)]:
        fan.drum("kick", m, tel, v)
    fan.drum("crash", 0, 1, 0.45)
    fan.drum("crash", 2, 0, 0.6)
    fan.drum("tomm", 1, 3.5, 0.5)
    fan.drum("toml", 1, 3.75, 0.6)
    noten = voicing(fan.akk[2][0][1], 62, None)
    for i, mm in enumerate(noten):
        fan.leg("ep", fan.tijd(2, 0) + 0.035 * i, ep(hz(mm), 3.0 * fan.tel_s, 0.6, fan.sr, fan.rng))
    for i, n in enumerate(["F5", "A5", "C6", "E6", "G6"]):
        fan.noot("marimba", marimba, 2, 0.5 + i * 0.25, 0.25, midi(n), 0.5 + 0.06 * i, pan=-0.2, jitter=0.0)
    kop = mixdown(fan, galm_rt=1.6, galm_db=-11.0, niveau=dict(lead=-1.0, koper=-5.0, perc=-14.0), tremolo=0.0)
    kop = kop[:, :fan.L]
    t = _t(fan.L, fan.sr)
    eind = fan.L / fan.sr
    kop *= np.where(t > eind - 0.8, np.cos(0.5 * np.pi * np.clip((t - (eind - 0.8)) / 0.8, 0, 1)) ** 2, 1.0)

    vamp = Stuk("rush_uitslag_vamp", bpm, 8, swing=0.6)
    vamp.akk = progressie(PROG_VAMP, 0)
    for maat in range(8):
        leg_drums(vamp, maat, "brush")
        leg_bas(vamp, maat, "vamp", vel=0.75)
        leg_comp(vamp, maat, "lui", centrum=63, rol=0.014)
        leg_pad(vamp, maat, centrum=60, vel=0.4)
    leg_melodie(vamp, 0, KOP, "marimba", marimba, 0, vel=0.6, pan=-0.2)
    leg_melodie(vamp, 4, KOP + [(1, 2.5, 0.5, "F5"), (1, 3.0, 0.5, "E5"), (1, 3.5, 0.5, "C5")], "marimba",
                marimba, 12, vel=0.4, pan=-0.2)
    lus = mixdown(vamp, galm_rt=1.6, galm_db=-11.0, niveau=dict(perc=-18.0, kick=-9.0))
    return kop, lus, fan.L / fan.sr


# ---------------------------------------------------------------- ffmpeg

def ff_meet(x, sr):
    """(integrated LUFS, true peak dBTP) via ffmpeg ebur128."""
    kan = x.shape[0] if x.ndim == 2 else 1
    data = (x.T if x.ndim == 2 else x).astype("<f4").tobytes()
    p = subprocess.run([FFMPEG, "-hide_banner", "-nostats", "-f", "f32le", "-ar", str(sr), "-ac", str(kan),
                        "-i", "pipe:0", "-af", "ebur128=peak=true", "-f", "null", "-"],
                       input=data, capture_output=True)
    err = p.stderr.decode()
    lufs = float(re.findall(r"I:\s+(-?[\d.]+|-inf) LUFS", err)[-1])
    tp = re.findall(r"Peak:\s+(-?[\d.]+|-inf) dBFS", err)
    return lufs, float(tp[-1]) if tp else float("nan")


def ff_ogg(x, sr, pad):
    kan = x.shape[0]
    data = x.T.astype("<f4").tobytes()
    subprocess.run([FFMPEG, "-y", "-hide_banner", "-loglevel", "error", "-f", "f32le", "-ar", str(sr),
                    "-ac", str(kan), "-i", "pipe:0", "-c:a", "libvorbis", "-q:a", MUZIEK_Q,
                    # bitexact: vast serienummer in de OGG, zodat opnieuw draaien geen git-diff geeft
                    "-fflags", "+bitexact", "-flags:a", "+bitexact", pad],
                   input=data, check=True)


def ff_lees(pad, sr=None):
    """Decodeert een bestand naar float (kanalen, n)."""
    info = subprocess.run([FFMPEG, "-hide_banner", "-i", pad], capture_output=True).stderr.decode()
    kan = 2 if "stereo" in info else 1
    sr = sr or int(re.search(r"(\d+) Hz", info).group(1))
    p = subprocess.run([FFMPEG, "-hide_banner", "-loglevel", "error", "-i", pad, "-f", "f32le", "-ac", str(kan),
                        "-ar", str(sr), "-"], capture_output=True, check=True)
    return np.frombuffer(p.stdout, "<f4").reshape(-1, kan).T.astype(np.float64), sr


def normaliseer(x, sr, doel):
    lufs, tp = ff_meet(x, sr)
    g = 10 ** ((doel - lufs) / 20)
    x = x * g
    tp += 20 * math.log10(g)
    if tp > TP_MAX:
        # Zachte begrenzer per sample: geheugenloos, dus loopveilig.
        drempel = 10 ** ((TP_MAX - 3) / 20)
        a = np.abs(x)
        boven = a > drempel
        x[boven] = np.sign(x[boven]) * (drempel + (1 - drempel) * np.tanh((a[boven] - drempel) / (1 - drempel)))
        x *= 10 ** (TP_MAX / 20 - 0.02)
    return x


# ---------------------------------------------------------------- muziek schrijven

def schrijf_muziek(mono=False):
    os.makedirs(MUS_DIR, exist_ok=True)
    stukken = {
        "rush_menu": maak_menu,
        "rush_ma": lambda: maak_dag("rush_ma"),
        "rush_di": lambda: maak_dag("rush_di"),
        "rush_wo": lambda: maak_dag("rush_wo"),
        "rush_do": lambda: maak_dag("rush_do"),
        "rush_vr": lambda: maak_dag("rush_vr"),
        "rush_ontsnapping": maak_ontsnapping,
    }
    for naam, fn in stukken.items():
        x = fn()
        if mono:
            x = x.mean(axis=0, keepdims=True)
        x = normaliseer(x, SR_M, MUZIEK_LUFS)
        ff_ogg(x, SR_M, os.path.join(MUS_DIR, naam + ".ogg"))
        print("muziek %-18s %5.1f s" % (naam, x.shape[1] / SR_M))
    kop, lus, start = maak_uitslag()
    if mono:
        kop, lus = kop.mean(axis=0, keepdims=True), lus.mean(axis=0, keepdims=True)
    kop = normaliseer(kop, SR_M, MUZIEK_LUFS + 2.0)      # de fanfare mag er even bovenuit
    lus = normaliseer(lus, SR_M, MUZIEK_LUFS - 1.0)
    ff_ogg(np.concatenate([kop, lus], axis=1), SR_M, os.path.join(MUS_DIR, "rush_uitslag.ogg"))
    print("muziek %-18s %5.1f s  (loop vanaf %.3f s)" % ("rush_uitslag", (kop.shape[1] + lus.shape[1]) / SR_M,
                                                         start))


# ---------------------------------------------------------------- effecten
# Alles mono, 44,1 kHz. Elk effect geeft een array; afwerken() doet DC, filter,
# randen en niveau. Het niveau is een piekdoel per effect: tikjes en stappen
# bewust zachter dan de rest.

def svf_bp(x, fc, q, sr):
    """Bandpass met in de tijd verschuivende middenfrequentie (Chamberlin)."""
    f = (2.0 * np.sin(np.pi * np.minimum(fc, sr / 6.0) / sr)).tolist()
    qq = 1.0 / q
    lp = bp = 0.0
    uit = [0.0] * len(x)
    for i, v in enumerate(x.tolist()):
        hp = v - lp - qq * bp
        bp += f[i] * hp
        lp += f[i] * bp
        uit[i] = bp
    return np.array(uit)


def lijn(n, *punten):
    """Lineaire curve door (fractie, waarde)-punten over n samples."""
    xs, ys = zip(*punten)
    return np.interp(np.linspace(0, 1, n), xs, ys)


def bel(f, duur, sr, index=0.8, ratio=2.0, tau=0.4, a=0.001):
    t = _t(int(duur * sr), sr)
    idx = index * np.exp(-t / (tau * 0.35)) + 0.1
    y = np.sin(TWO_PI * f * t + idx * np.sin(TWO_PI * ratio * f * t))
    return y * np.exp(-t / tau) * aanzet(t, a)


def stemklank(f0, formanten, sr, kmax=4000.0):
    """Klinker: harmonischen van f0 (array) gewogen door formanten. `formanten`
    is een lijst (F, B, A) met F mogelijk een array in de tijd."""
    ph = fase(f0, sr)
    y = np.zeros_like(f0)
    k = 1
    while k * f0.min() < kmax:
        fk = k * f0
        g = np.zeros_like(f0)
        for (F, B, A) in formanten:
            g += A / (1.0 + ((fk - F) / B) ** 2)
        y += g * (fk < kmax) * np.sin(k * ph) / k ** 0.5
        k += 1
    return y


def plak(n, *delen):
    """Telt (start_s, array)-delen op in een buffer van n samples."""
    uit = np.zeros(n)
    for (t0, y) in delen:
        i = int(t0 * SR_S)
        k = min(len(y), n - i)
        uit[i:i + k] += y[:k]
    return uit


def sfx_tik(rng):
    sr = SR_S
    n = int(0.05 * sr)
    t = _t(n, sr)
    ph = fase(1400.0 * (1 + 0.3 * np.exp(-t / 0.003)), sr)
    y = np.sin(ph) * np.exp(-t / 0.009) + 0.25 * np.sin(2.6 * ph) * np.exp(-t / 0.004)
    y += 0.25 * bandruis(n, 1500, 6000, sr, rng) * np.exp(-t / 0.0015)
    return y * aanzet(t, 0.0006)


def sfx_knop(rng):
    sr = SR_S
    n = int(0.12 * sr)
    t = _t(n, sr)
    f = 520.0 * (1.5 ** np.clip(t / 0.025, 0, 1))
    ph = fase(f, sr)
    y = (np.sin(ph) + 0.15 * np.sin(2 * ph)) * np.exp(-t / 0.04)
    y += 0.4 * np.sin(TWO_PI * 260 * t) * np.exp(-t / 0.018)
    return y * aanzet(t, 0.002)


def sfx_nieuw(rng):
    sr = SR_S
    n = int(0.3 * sr)
    t1 = _t(int(0.07 * sr), sr)
    swish = bandruis(len(t1), 1500, 6000, sr, rng) * aanzet(t1, 0.012) * np.exp(-t1 / 0.025) * 0.35
    t2 = _t(int(0.12 * sr), sr)
    pop_ph = fase(380.0 * (260.0 / 380.0) ** np.clip(t2 / 0.04, 0, 1), sr)
    pop = (np.sin(pop_ph) + 0.3 * np.sin(2 * pop_ph)) * np.exp(-t2 / 0.035) * aanzet(t2, 0.002)
    pling = marimba(hz(midi("E6")), 0.1, 0.22, sr, rng)
    return plak(n, (0.0, swish), (0.045, pop), (0.05, pling))


def sfx_pak(rng):
    sr = SR_S
    n = int(0.17 * sr)
    t = _t(n, sr)
    f = 330.0 * (2.6 ** np.clip(t / 0.09, 0, 1))
    ph = fase(f, sr)
    y = np.sin(ph) + 0.25 * np.sin(2 * ph) * np.exp(-t / 0.05)
    return y * aanzet(t, 0.004) * np.where(t < 0.06, 1.0, np.exp(-(t - 0.06) / 0.035))


def sfx_geef(rng):
    sr = SR_S
    n = int(0.38 * sr)
    t1 = _t(int(0.09 * sr), sr)
    ph = fase(900.0 * (520.0 / 900.0) ** np.clip(t1 / 0.07, 0, 1), sr)
    glij = np.sin(ph) * aanzet(t1, 0.003) * np.exp(-t1 / 0.04) * 0.5
    papier = bandruis(int(0.04 * sr), 2000, 6000, sr, rng) * np.exp(-_t(int(0.04 * sr), sr) / 0.01) * 0.12
    e = ep(hz(midi("E5")), 0.08, 0.7, sr, rng)
    c = ep(hz(midi("C5")), 0.22, 0.75, sr, rng) + 0.6 * ep(hz(midi("G4")), 0.22, 0.6, sr, rng)
    return plak(n, (0.0, papier), (0.0, glij), (0.05, e), (0.12, c))


def sfx_klaar(rng):
    sr = SR_S
    n = int(0.5 * sr)
    a = bel(hz(midi("G5")), 0.3, sr, index=0.7, ratio=3.0, tau=0.18)
    b = bel(hz(midi("C6")), 0.38, sr, index=0.7, ratio=3.0, tau=0.25)
    return plak(n, (0.0, a), (0.1, b))


def sfx_deploy(rng):
    """'Kaching', maar digitaal. Blijft onder ~5 kHz zodat hij op 1,5x pitch
    (een lange reeks) nog niet gaat snerpen."""
    sr = SR_S
    n = int(0.55 * sr)
    tk = _t(int(0.02 * sr), sr)
    ka = bandruis(len(tk), 1500, 4000, sr, rng) * np.exp(-tk / 0.005) * 0.3
    c5 = marimba(hz(midi("C5")), 0.05, 0.6, sr, rng)
    g5 = marimba(hz(midi("G5")), 0.05, 0.6, sr, rng)
    glans = np.zeros(int(0.48 * sr))
    for nm, v in (("C6", 0.7), ("E6", 0.5)):
        for cent in (-6.0, 6.0):
            glans += v * bel(hz(midi(nm)) * 2 ** (cent / 1200), 0.48, sr, index=0.5, ratio=2.0, tau=0.22)
    top = bel(hz(midi("G6")), 0.3, sr, index=0.3, ratio=2.0, tau=0.12) * 0.25
    return plak(n, (0.0, ka), (0.0, c5), (0.035, g5), (0.07, glans), (0.11, top))


def sfx_dubbel(rng):
    sr = SR_S
    n = int(0.7 * sr)
    delen = []
    for nm in ("G4", "B4", "D5"):
        delen.append((0.0, koper(hz(midi(nm)), 0.08, 0.7, sr, rng)))
    for nm in ("C5", "E5", "G5"):
        delen.append((0.11, koper(hz(midi(nm)), 0.38, 0.85, sr, rng)))
    for i, nm in enumerate(("C6", "E6", "G6")):
        delen.append((0.14 + 0.035 * i, 0.5 * marimba(hz(midi(nm)), 0.1, 0.6, sr, rng)))
    return plak(n, *delen)


def sfx_bel(rng):
    """Telefoon: twee korte rinkels met een 25 Hz-klepel tussen twee tonen."""
    sr = SR_S
    n = int(0.62 * sr)
    delen = []
    for t0 in (0.0, 0.32):
        m = int(0.25 * sr)
        t = _t(m, sr)
        wissel = (np.sin(TWO_PI * 25 * t) > 0).astype(float)
        wissel = np.convolve(wissel, np.ones(40) / 40, mode="same")          # zachte overgang
        f = 740.0 + (932.0 - 740.0) * wissel
        ph = fase(f, sr)
        toon = np.sin(ph) + 0.25 * np.sin(3 * ph)
        klepel = 0.6 + 0.4 * np.abs(np.sin(np.pi * 25 * t))
        zoem = np.tanh(2 * np.sin(fase(np.full(m, 175.0), sr))) * 0.12
        env = aanzet(t, 0.005) * np.where(t > 0.22, np.exp(-(t - 0.22) / 0.01), 1.0)
        delen.append((t0, (toon * klepel + zoem) * env))
    return plak(n, *delen)


def sfx_hinnik(rng):
    """Klein synthetisch paard: hoog begin, toonhoogtevalt, en het snelle
    trillen van een hinnik als vibrato én tremolo."""
    sr = SR_S
    n = int(0.55 * sr)
    t = _t(n, sr)
    x = t / t[-1]
    basis = np.where(t < 0.06, 640 + (860 - 640) * t / 0.06, 860 * (400 / 860) ** ((t - 0.06) / (t[-1] - 0.06)))
    trilf = 15 + 5 * x
    trilfase = fase(trilf, sr)
    diepte = 0.03 + 0.07 * x
    f0 = basis * (1 + diepte * np.sin(trilfase))
    F1 = 900 - 250 * x
    F2 = 1750 - 550 * x
    y = stemklank(f0, [(F1, 180, 1.0), (F2, 260, 0.6), (2700.0, 400, 0.2)], sr)
    trem = 1.0 - 0.35 * (0.5 + 0.5 * np.sin(trilfase)) * x
    adem = bandruis(n, 1000, 5000, sr, rng) * 0.08 * (np.exp(-t / 0.05) + 0.6 * x ** 3)
    env = aanzet(t, 0.03) * np.where(t > 0.42, np.cos(0.5 * np.pi * (t - 0.42) / (t[-1] - 0.42)) ** 2, 1.0)
    return (y / np.abs(y).max() * trem + adem) * env


def sfx_fout(rng):
    """Een zachte 'bwonk': houtachtige FM-toon die even zakt."""
    sr = SR_S
    n = int(0.3 * sr)
    t = _t(n, sr)
    f = 196.0 + (330.0 - 196.0) * np.exp(-t / 0.025)
    f *= 1 - 0.015 * np.sin(TWO_PI * 7 * t) * np.clip((t - 0.08) / 0.1, 0, 1)
    ph = fase(f, sr)
    idx = 1.8 * np.exp(-t / 0.06) + 0.3
    y = np.sin(ph + idx * np.sin(ph))
    return y * aanzet(t, 0.003) * np.exp(-t / 0.11)


def sfx_koffie(rng):
    """Slurp (ruis door een omhoog schuivend bandfilter) met bubbeltjes."""
    sr = SR_S
    n = int(0.62 * sr)
    t = _t(n, sr)
    fc = 600 * (1800 / 600) ** np.clip(t / 0.35, 0, 1)
    slurp = svf_bp(rng.standard_normal(n), fc, 4.0, sr)
    flutter = 0.6 + 0.4 * np.interp(t, np.linspace(0, t[-1], 30), rng.uniform(0, 1, 30))
    env = aanzet(t, 0.2) * np.where(t > 0.36, np.exp(-(t - 0.36) / 0.03), 1.0)
    slurp = slurp / (np.abs(slurp).max() + 1e-9) * flutter * env * 0.5
    delen = [(0.0, slurp)]
    for i in range(6):
        t0 = 0.08 + 0.08 * i + rng.uniform(-0.02, 0.02)
        f0 = rng.uniform(500, 1000)
        tb = _t(int(0.05 * sr), sr)
        b = np.sin(fase(f0 * (1 + 2.5 * tb / 0.05), sr)) * np.exp(-tb / 0.014) * aanzet(tb, 0.001)
        delen.append((t0, 0.35 * b))
    return plak(n, *delen)


def sfx_brand(rng):
    """Alarmpje: drie keer 'dwie' omhoog, met wat knetteren eronder."""
    sr = SR_S
    n = int(0.62 * sr)
    delen = []
    for i in range(3):
        m = int(0.16 * sr)
        t = _t(m, sr)
        f = 660 * (1.5 ** (t / t[-1]))
        ph = fase(f, sr)
        toon = np.sin(ph) + 0.3 * np.sin(2 * ph) + 0.1 * np.sin(3 * ph)
        delen.append((i * 0.2, toon * aanzet(t, 0.006) * np.where(t > 0.13, np.exp(-(t - 0.13) / 0.01), 1.0)))
    t = _t(n, sr)
    knetter = np.zeros(n)
    for _ in range(26):
        i = rng.integers(0, n - 400)
        knetter[i:i + 400] += rng.uniform(0.3, 1) * np.exp(-np.arange(400) / 40.0) * rng.standard_normal(400)
    knetter = np.convolve(knetter, np.hanning(9) / 4.5, mode="same") * 0.25
    rommel = bandruis(n, 100, 400, sr, rng) * 0.12 * aanzet(t, 0.2)
    return plak(n, *delen, (0.0, knetter + rommel))


def sfx_blus(rng):
    """Blussen: ruis door een bandfilter dat van hoog naar laag zakt."""
    sr = SR_S
    n = int(0.6 * sr)
    t = _t(n, sr)
    fc = 2600 * (700 / 2600) ** (t / t[-1])
    y = svf_bp(rng.standard_normal(n), fc, 1.2, sr)
    y = y / (np.abs(y).max() + 1e-9)
    sis = bandruis(n, 4000, 9000, sr, rng) * 0.08 * np.exp(-t / 0.2)
    env = aanzet(t, 0.025) * np.where(t > 0.3, np.cos(0.5 * np.pi * (t - 0.3) / (t[-1] - 0.3)) ** 2, 1.0)
    tp = _t(int(0.2 * sr), sr)
    pf = np.sin(fase(110 * 0.5 ** (tp / 0.2), sr)) * np.exp(-tp / 0.06) * aanzet(tp, 0.005) * 0.4
    return plak(n, (0.0, (y + sis) * env), (0.33, pf))


def sfx_dirk(rng):
    """'Ahem': twee lettergrepen uit een kleine formantstem."""
    sr = SR_S
    m1 = int(0.11 * sr)
    t1 = _t(m1, sr)
    a = stemklank(np.linspace(135, 145, m1), [(650.0, 90, 1.0), (1100.0, 110, 0.6), (2400.0, 200, 0.15)], sr)
    a *= aanzet(t1, 0.02) * np.where(t1 > 0.08, np.exp(-(t1 - 0.08) / 0.012), 1.0)
    m2 = int(0.26 * sr)
    t2 = _t(m2, sr)
    x = t2 / t2[-1]
    f0 = 165 * (128 / 165) ** x
    nasaal = np.clip((x - 0.6) / 0.15, 0, 1)
    F1 = 520 - 270 * nasaal
    F2 = 1750 - 550 * nasaal
    hem = stemklank(f0, [(F1, 90, 1.0), (F2, 130, 0.5 * (1 - 0.7 * nasaal)), (2500.0, 200, 0.12 * (1 - nasaal))],
                    sr)
    hem *= aanzet(t2, 0.03) * np.where(t2 > 0.2, np.exp(-(t2 - 0.2) / 0.025), 1.0)
    th = _t(int(0.04 * sr), sr)
    h = bandruis(len(th), 1200, 3000, sr, rng) * aanzet(th, 0.01) * 0.04
    a /= np.abs(a).max()
    hem /= np.abs(hem).max()
    return plak(int(0.42 * sr), (0.0, 0.85 * a), (0.13, h), (0.15, hem))


def sfx_weg(rng):
    sr = SR_S
    n = int(0.3 * sr)
    t = _t(n, sr)
    x = t / t[-1]
    fc = np.where(x < 0.45, 600 * (2400 / 600) ** (x / 0.45), 2400 * (1300 / 2400) ** ((x - 0.45) / 0.55))
    y = svf_bp(rng.standard_normal(n), fc, 1.5, sr)
    y = y / (np.abs(y).max() + 1e-9) * np.sin(np.pi * x) ** 2
    zip_ = np.sin(fase(500 * (1400 / 500) ** x, sr)) * np.sin(np.pi * x) ** 2 * 0.08
    return y + zip_


def sfx_afkappen(rng):
    """Plaat-scratch: een pianoakkoord dat heen en weer onder de naald door gaat."""
    sr = SR_S
    bron = np.zeros(int(1.0 * sr))
    for nm in ("C4", "E4", "G4", "Bb4"):
        y = ep(hz(midi(nm)), 0.9, 0.8, sr, rng)
        bron[:len(y)] += y[:len(bron)]
    bron += 0.15 * bandruis(len(bron), 800, 4000, sr, rng)
    n = int(0.32 * sr)
    t = _t(n, sr)
    snelheid = np.where(t < 0.05, 1.0, 3.2 * np.sin(TWO_PI * 7.0 * (t - 0.05)) * np.exp(-(t - 0.05) / 0.25))
    pos = 0.15 * sr + np.cumsum(snelheid)
    y = np.interp(pos, np.arange(len(bron)), bron)
    wrijf = bandruis(n, 1000, 5000, sr, rng) * np.abs(snelheid) * 0.05
    env = np.where(t > 0.27, np.cos(0.5 * np.pi * (t - 0.27) / 0.05) ** 2, 1.0)
    return (y + wrijf) * env


def sfx_deur(rng):
    sr = SR_S
    n = int(0.5 * sr)
    delen = []
    for t0, v in ((0.0, 1.0), (0.032, 0.6)):
        tk = _t(int(0.04 * sr), sr)
        k = 0.5 * bandruis(len(tk), 1000, 5000, sr, rng) * np.exp(-tk / 0.004) \
            + np.sin(TWO_PI * 1300 * tk) * np.exp(-tk / 0.012)
        delen.append((t0, v * k * aanzet(tk, 0.0005)))
    # Kraak: stick-slip, een reeks gedempte tikjes die steeds sneller komen.
    t = 0.07
    while t < 0.4:
        x = (t - 0.07) / 0.33
        tk = _t(int(0.012 * sr), sr)
        tik = np.sin(TWO_PI * (720 + 80 * x) * tk) * np.exp(-tk / 0.004)
        delen.append((t, 0.22 * np.sin(np.pi * x) * tik))
        t += 1.0 / (35 + 55 * np.sin(np.pi * min(x, 0.7)))
    tl = _t(n, sr)
    lucht = bandruis(n, 150, 800, sr, rng) * 0.06 * np.sin(np.pi * np.clip((tl - 0.08) / 0.4, 0, 1))
    return plak(n, *delen, (0.0, lucht))


def sfx_vijf(rng):
    """Klokslag: 'ding-dong' op een klokje met een lage brom eronder."""
    sr = SR_S
    n = int(1.5 * sr)
    delen = []
    for t0, nm in ((0.0, "E5"), (0.38, "C5")):
        f = hz(midi(nm))
        m = int(1.1 * sr)
        t = _t(m, sr)
        y = np.zeros(m)
        for r, a, tau in ((0.5, 0.25, 1.0), (1.0, 1.0, 0.65), (2.0, 0.4, 0.35), (3.0, 0.18, 0.22),
                          (4.16, 0.1, 0.14), (5.43, 0.05, 0.09)):
            y += a * np.sin(TWO_PI * r * f * t) * np.exp(-t / tau)
        delen.append((t0, y * aanzet(t, 0.002)))
    return plak(n, *delen)


def sfx_ster(rng):
    sr = SR_S
    n = int(0.55 * sr)
    delen = []
    for i, nm in enumerate(("G5", "C6", "E6", "G6")):
        delen.append((0.045 * i, (0.6 + 0.13 * i) * bel(hz(midi(nm)), 0.4, sr, index=0.45, ratio=2.0, tau=0.15)))
    t = _t(n, sr)
    flikker = np.interp(t, np.linspace(0, t[-1], 60), rng.uniform(0, 1, 60)) ** 2
    glinster = bandruis(n, 6000, 10000, sr, rng) * flikker * 0.06 * np.exp(-t / 0.18) * aanzet(t, 0.04)
    return plak(n, *delen, (0.0, glinster))


def sfx_stap(rng):
    sr = SR_S
    n = int(0.08 * sr)
    t = _t(n, sr)
    y = bandruis(n, 80, 900, sr, rng) * np.exp(-t / 0.016) * 0.5
    y += 0.6 * np.sin(fase(70 * (50 / 70) ** (t / t[-1]), sr)) * np.exp(-t / 0.025)
    y += 0.12 * bandruis(n, 1000, 3000, sr, rng) * np.exp(-t / 0.005)
    return y * aanzet(t, 0.002)


def sfx_bots(rng):
    """Zachte bonk met een 'oef' erachteraan. De bonk zit rond 150-250 Hz in
    plaats van in het sublaag: een telefoonspeaker laat onder 200 Hz weinig over."""
    sr = SR_S
    n = int(0.34 * sr)
    tb = _t(int(0.2 * sr), sr)
    bonk = np.sin(fase(110 + 140 * np.exp(-tb / 0.025), sr)) * np.exp(-tb / 0.07) * aanzet(tb, 0.002)
    bonk += 0.35 * bandruis(len(tb), 200, 1200, sr, rng) * np.exp(-tb / 0.018)
    m = int(0.18 * sr)
    tv = _t(m, sr)
    oef = stemklank(np.linspace(270, 185, m), [(340.0, 70, 1.0), (820.0, 100, 0.55), (2300.0, 200, 0.08)], sr)
    oef = oef / np.abs(oef).max() * aanzet(tv, 0.012) * np.exp(-tv / 0.08)
    tf = _t(int(0.07 * sr), sr)
    f_ = bandruis(len(tf), 1200, 4000, sr, rng) * aanzet(tf, 0.02) * np.exp(-tf / 0.025) * 0.06
    return plak(n, (0.0, bonk), (0.03, 0.85 * oef), (0.17, f_))


# naam: (functie, luidheid, galm-aandeel, laagdoorlaat Hz). Luidheid is de
# RMS van het luidste 50 ms-venster in dBFS: op piek normaliseren maakt een
# sinus-bloop veel luider dan een ruisvlaag met dezelfde piek. De piek wordt
# daarna nog op PIEK_MAX begrensd. De effecten die honderden keren per sessie
# klinken (tik, stap, knop, pak, geef, nieuw) zitten bewust onderaan.
PIEK_MAX = -3.0
EFFECTEN = {
    "rush_tik": (sfx_tik, -24.0, 0.0, 9000),
    "rush_knop": (sfx_knop, -17.0, 0.06, 8000),
    "rush_nieuw": (sfx_nieuw, -16.0, 0.08, 9000),
    "rush_pak": (sfx_pak, -16.0, 0.06, 8000),
    "rush_geef": (sfx_geef, -15.0, 0.1, 8000),
    "rush_klaar": (sfx_klaar, -14.0, 0.12, 9000),
    "rush_deploy": (sfx_deploy, -13.0, 0.12, 7000),
    "rush_dubbel": (sfx_dubbel, -13.0, 0.12, 8000),
    "rush_bel": (sfx_bel, -13.0, 0.08, 6000),
    "rush_hinnik": (sfx_hinnik, -13.0, 0.1, 7000),
    "rush_fout": (sfx_fout, -16.0, 0.06, 6000),
    "rush_koffie": (sfx_koffie, -16.0, 0.06, 7000),
    "rush_brand": (sfx_brand, -13.0, 0.08, 6000),
    "rush_blus": (sfx_blus, -15.0, 0.05, 9000),
    "rush_dirk": (sfx_dirk, -14.0, 0.08, 6000),
    "rush_weg": (sfx_weg, -17.0, 0.0, 6000),
    "rush_afkappen": (sfx_afkappen, -15.0, 0.05, 7000),
    "rush_deur": (sfx_deur, -16.0, 0.1, 8000),
    "rush_vijf": (sfx_vijf, -12.0, 0.1, 8000),
    "rush_ster": (sfx_ster, -14.0, 0.12, 10000),
    "rush_stap": (sfx_stap, -28.0, 0.0, 5000),
    "rush_bots": (sfx_bots, -15.0, 0.05, 6000),
}


def luidste_rms(y, sr):
    fr = int(0.05 * sr)
    if len(y) <= fr:
        return float(np.sqrt(np.mean(y ** 2)))
    c = np.concatenate([[0.0], np.cumsum(y ** 2)])
    return float(np.sqrt((c[fr:] - c[:-fr]).max() / fr))


def kamer_ir(sr, rng):
    """Een klein kamertje: 0,3 s nagalm, genoeg om effecten 'in de ruimte' te zetten."""
    n = int(0.3 * sr)
    t = _t(n, sr)
    ir = (bandruis(n, None, 2500, sr, rng) * np.exp(-6.91 * t / 0.28)
          + 0.5 * bandruis(n, 2500, 8000, sr, rng) * np.exp(-6.91 * t / 0.12)) * aanzet(t, 0.004)
    return np.concatenate([np.zeros(int(0.01 * sr)), ir]) / np.sqrt(np.sum(ir ** 2))


def afwerken(y, luid_db, galm, lp, rng):
    sr = SR_S
    y = np.asarray(y, dtype=np.float64)
    y = y / (np.abs(y).max() + 1e-12)
    if galm > 0:
        nat = np.convolve(y, kamer_ir(sr, rng))
        nat *= np.sqrt(np.mean(y ** 2)) / (np.sqrt(np.mean(nat ** 2)) + 1e-12)
        y = np.concatenate([y, np.zeros(len(nat) - len(y))]) + galm * nat * 2.0
    # Laagdoorlaat en DC weg, in het frequentiedomein met ruim opvulling.
    pad = 2048
    z = np.concatenate([np.zeros(pad), y, np.zeros(pad)])
    f = np.fft.rfftfreq(len(z), 1.0 / sr)
    h = (f ** 2 / np.sqrt(f ** 4 + 30.0 ** 4)) / np.sqrt(1.0 + (f / lp) ** 4)
    y = np.fft.irfft(np.fft.rfft(z) * h, len(z))[pad:]
    # Staart inkorten tot waar hij onhoorbaar is, en zachte randen.
    a = np.abs(y)
    stil = np.nonzero(a > a.max() * 10 ** (-45 / 20))[0]
    y = y[:stil[-1] + 1] if len(stil) else y
    nin, nuit = int(0.0005 * sr), min(int(0.008 * sr), len(y) // 4)
    y[:nin] *= np.linspace(0, 1, nin)
    y[-nuit:] *= np.cos(0.5 * np.pi * np.linspace(0, 1, nuit)) ** 2
    y -= y.mean()
    y *= 10 ** (luid_db / 20) / luidste_rms(y, sr)
    piek = np.abs(y).max()
    if piek > 10 ** (PIEK_MAX / 20):
        y *= 10 ** (PIEK_MAX / 20) / piek
    return y


def schrijf_wav(pad, y, sr):
    data = np.clip(np.round(y * 32767), -32767, 32767).astype("<i2")
    with wave.open(pad, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(data.tobytes())


def schrijf_sfx():
    os.makedirs(SFX_DIR, exist_ok=True)
    for naam, (fn, luid, galm, lp) in EFFECTEN.items():
        rng = np.random.default_rng(zlib.crc32(naam.encode()))
        y = afwerken(fn(rng), luid, galm, lp, rng)
        schrijf_wav(os.path.join(SFX_DIR, naam + ".wav"), y, SR_S)
        print("sfx    %-18s %5.2f s" % (naam, len(y) / SR_S))


# ---------------------------------------------------------------- nameten

def db(x):
    return 20 * math.log10(max(x, 1e-9))


def spectrum(y, sr):
    """Spectraal zwaartepunt (Hz) en het aandeel energie boven 4 kHz (%)."""
    Y = np.abs(np.fft.rfft(y)) ** 2
    f = np.fft.rfftfreq(len(y), 1.0 / sr)
    return float((f * Y).sum() / Y.sum()), float(100 * Y[f > 4000].sum() / Y.sum())


def meet():
    print("\nEFFECTEN               duur   piek    RMS*   DC        clip  zwaartepunt >4k")
    for naam in EFFECTEN:
        p = os.path.join(SFX_DIR, naam + ".wav")
        if not os.path.exists(p):
            continue
        with wave.open(p) as w:
            sr, n = w.getframerate(), w.getnframes()
            raw = np.frombuffer(w.readframes(n), "<i2")
        y = raw / 32768.0
        rms = luidste_rms(y, sr)
        zw, hoog = spectrum(y, sr)
        print("  %-18s %5.2f s %6.1f %6.1f  %+.5f  %d    %5.0f   %4.1f" % (
            naam, n / sr, db(np.abs(y).max()), db(rms), y.mean(), int(np.sum(np.abs(raw) >= 32767)), zw, hoog))
    print("  (* RMS = luidste 50 ms-venster, dBFS; zwaartepunt = spectraal zwaartepunt in Hz;"
          " >4k = % energie boven 4 kHz)")

    print("\nMUZIEK                 duur    LUFS   dBTP   piek   DC        naad   rms begin/eind  kB")
    for naam in ("rush_menu", "rush_ma", "rush_di", "rush_wo", "rush_do", "rush_vr", "rush_ontsnapping",
                 "rush_uitslag"):
        p = os.path.join(MUS_DIR, naam + ".ogg")
        if not os.path.exists(p):
            continue
        x, sr = ff_lees(p)
        lufs, tp = ff_meet(x, sr)
        # Naad: de sprong van laatste naar eerste sample, afgezet tegen de
        # gewone sample-tot-sample-verschillen in het stuk. ~1 of lager = naadloos.
        d = np.abs(np.diff(x, axis=1))
        typisch = np.percentile(d, 99)
        if naam == "rush_uitslag":
            s0 = int(round(6.0 * sr))
            sprong = np.abs(x[:, -1] - x[:, s0]).max()
            begin = x[:, s0:s0 + int(0.01 * sr)]
        else:
            sprong = np.abs(x[:, -1] - x[:, 0]).max()
            begin = x[:, :int(0.01 * sr)]
        eind = x[:, -int(0.01 * sr):]
        r0 = db(np.sqrt(np.mean(begin ** 2)))
        r1 = db(np.sqrt(np.mean(eind ** 2)))
        print("  %-18s %5.2f s %6.1f %6.1f %6.1f  %+.5f  %5.2f   %5.1f/%5.1f  %4.0f" % (
            naam, x.shape[1] / sr, lufs, tp, db(np.abs(x).max()), x.mean(), sprong / typisch, r0, r1,
            os.path.getsize(p) / 1024))
    print("  (naad = sprong over het looppunt / 99e percentiel van gewone samplestappen)")


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    mono = "--mono" in sys.argv
    wat = args[0] if args else "alles"
    if wat in ("alles", "sfx"):
        schrijf_sfx()
    if wat in ("alles", "muziek"):
        schrijf_muziek(mono=mono)
    meet()


if __name__ == "__main__":
    main()
