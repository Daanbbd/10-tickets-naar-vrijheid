"""Mockup van het voorgestelde selectiescherm. 192x416, echte assets, echt palet.

Dit is GEEN productiecode: het is een Pillow-mockup om de layout te kunnen zien
zonder hem eerst in Godot te bouwen. Bastiaan staat hier hardgecodeerd omdat hij
nog niet in data/characters.json staat.

    tools/.venv/bin/python agent_docs/.handoffs/2026-09-01-2035-character-select/mockup_select.py victor
"""
import json, os, sys
from PIL import Image, ImageDraw, ImageFont

OUT = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(OUT, "..", "..", ".."))
W, H = 192, 416

BG       = (0x14,0x18,0x24); PANEL_D = (0x1e,0x23,0x33); PANEL_D2 = (0x26,0x2c,0x3e)
LINE     = (0x3a,0x40,0x54); WIT = (0xee,0xf0,0xf4); GRIJS = (0x8a,0x8a,0x8a)
BRIGHT   = (0x3a,0x86,0xff); PANEL = (0xf3,0xf3,0xf3); INK = (0x24,0x24,0x24)
LEEG     = (0x2b,0x31,0x44)

F = ImageFont.truetype(f"{ROOT}/assets/fonts/ark-pixel-10px-proportional-latin.ttf", 10)
chars = json.load(open(f"{ROOT}/data/characters.json"))
BAS = {"id":"bastiaan","name":"Bastiaan","role":"Frontend developer",
 "tagline":"Vindt altijd nog een ding.","owned_tickets":["t09"],
 "color":"#e8e4dc","skin":"#e9b89b","hair":"#4e3a2e","pants":"#34384e","accent":"#e8c547",
 "look":{"body":"slank","hair":"stekels","facial":"","outfit":"hoodie","accessory":"pet"}}
chars.insert(3, BAS)
for c in chars:
    if c["id"] == "jonathan": c["owned_tickets"] = ["t05"]
by_id = {c["id"]: c for c in chars}

STIJL = {
 "bastiaan": "Een ticket zelf. Jij ziet wat niemand anders ziet.",
 "daan":     "Twee tickets zelf. De rest is overleg.",
 "danny":    "Twee tickets zelf. Jij ziet cijfers.",
 "victor":   "Twee tickets zelf. Je zit veel aan je eigen bureau.",
 "jonathan": "Een ticket zelf. Niemand ziet wat je doet.",
 "willem":   "Een ticket zelf. Je loopt de hele dag heen en weer. Dat is het punt.",
}
FWF,FHF,COLS = 18,34,8
VOLGORDE = ["hair_back","body","outfit","hair","facial","accessory"]
ACHTER = {"lang","staart","knot"}
KEYS = {(255,0,0):"skin",(170,0,0):"skin_s",(0,255,0):"hair",(0,170,0):"hair_s",
        (0,0,255):"shirt",(0,0,170):"shirt_s",(255,0,255):"pants",(170,0,170):"pants_s",
        (0,255,255):"accent",(0,170,170):"accent_s"}

def hexc(s):
    s = s.lstrip("#"); return tuple(int(s[i:i+2],16) for i in (0,2,4))
def donker(c,f): return tuple(max(0,int(v*(1-f))) for v in c)
def schaal(im,f): return im.resize((im.width*f,im.height*f), Image.NEAREST)

def sprite(c, col=0, rij=0):
    look = c["look"]
    base = Image.new("RGBA",(FWF*COLS,FHF*4),(0,0,0,0))
    for slot in VOLGORDE:
        var = look.get("hair" if slot=="hair_back" else slot,"")
        if slot=="hair_back" and var not in ACHTER: continue
        if not var: continue
        p = f"{ROOT}/assets/sprites/characters/{slot}_{var}.png"
        if os.path.exists(p): base.alpha_composite(Image.open(p).convert("RGBA"))
    skin,hair,shirt = hexc(c["skin"]),hexc(c["hair"]),hexc(c["color"])
    pants,accent = hexc(c["pants"]),hexc(c["accent"])
    k = {"skin":skin,"skin_s":donker(skin,.28),"hair":hair,"hair_s":donker(hair,.25),
         "shirt":shirt,"shirt_s":donker(shirt,.30),"pants":pants,"pants_s":donker(pants,.30),
         "accent":accent,"accent_s":donker(accent,.30)}
    px = base.load()
    for y in range(base.height):
        for x in range(base.width):
            r,g,b,a = px[x,y]
            if a and (r,g,b) in KEYS: px[x,y] = k[KEYS[(r,g,b)]]+(a,)
    return base.crop((col*FWF,rij*FHF,col*FWF+FWF,rij*FHF+FHF))

d = None
def tx(xy,s,kleur,center=None):
    x,y = xy
    if center is not None: x = center - d.textlength(s,font=F)/2
    d.text((x,y),s,font=F,fill=kleur)
def wrap(s, maxw):
    regels,cur = [],""
    for w in s.split():
        p = (cur+" "+w).strip()
        if d.textlength(p,font=F) <= maxw: cur = p
        else: regels.append(cur); cur = w
    if cur: regels.append(cur)
    return regels

SEL = sys.argv[1] if len(sys.argv)>1 else "victor"
img = Image.new("RGB",(W,H),BG); d = ImageDraw.Draw(img)
c = by_id[SEL]; accent = hexc(c["accent"])

tx((0,3),"WIE BEN JIJ VANDAAG?",BRIGHT,center=W/2)

# 1. de vloer -----------------------------------------------------------------
S = (6,17,185,122)
d.rectangle(S,fill=PANEL_D,outline=LINE)
vloer = Image.open(f"{ROOT}/assets/tilesets/office_atlas.png").convert("RGBA").crop((0,0,16,16))
for tx0 in range(7,185,16):
    for ty in range(90,122,16):
        img.paste(vloer.crop((0,0,min(16,185-tx0),min(16,122-ty))),(tx0,ty))
mw = Image.open(f"{ROOT}/assets/sprites/props/monitorwand_4x1.png").convert("RGBA")
img.paste(mw,(14,72),mw)
bur = Image.open(f"{ROOT}/assets/sprites/props/bureau_4x4.png").convert("RGBA")
bur = bur.resize((bur.width//2,bur.height//2),Image.NEAREST)
img.paste(bur,(122,84),bur)
d.rectangle(S,outline=LINE)
d.ellipse((70,112,122,122),fill=tuple(int(v*.18+b*.82) for v,b in zip(accent,PANEL_D)))
sch = schaal(Image.open(f"{ROOT}/assets/sprites/props/schaduw_karakter.png").convert("RGBA"),3)
img.paste(sch,(75,113),sch)
sp = schaal(sprite(c,0,0),3)
img.paste(sp,(69,18),sp)

# 2. wie het is ---------------------------------------------------------------
y = 127
for r in wrap('"%s"' % c["tagline"],176):
    tx((0,y),r,accent,center=W/2); y += 11

# 3. de ticketbalk ------------------------------------------------------------
y += 6
eigen = set(c["owned_tickets"])
alle = ["t01","t02","t03","t04","t05","t06","t07","t08","t09","t10"]
bw,gap = 15,3
for i,t in enumerate(alle):
    x = 9 + i*(bw+gap)
    aan = t in eigen
    d.rectangle((x,y,x+bw-1,y+10),fill=accent if aan else LEEG,outline=accent if aan else LINE)
    if aan: d.rectangle((x+3,y+3,x+bw-4,y+7),fill=PANEL_D)
y += 15
for r in wrap(STIJL[SEL],174):
    tx((9,y),r,WIT); y += 10

# 4. de rij ------------------------------------------------------------------
y += 6
for cid in [x["id"] for x in chars]:
    cc = by_id[cid]; gek = cid == SEL; a = hexc(cc["accent"])
    d.rectangle((8,y,184,y+25),fill=PANEL_D2 if gek else PANEL_D,outline=a if gek else LINE)
    if gek: d.rectangle((8,y,10,y+25),fill=a)
    po = Image.open(f"{ROOT}/assets/sprites/portraits/{cid}.png").convert("RGB").resize((16,20),Image.NEAREST)
    img.paste(po,(15,y+3))
    tx((37,y+3),cc["name"],WIT if gek else GRIJS)
    tx((37,y+13),cc["role"],GRIJS)
    tx((0,y+8),"%d/10" % len(cc["owned_tickets"]),a if gek else GRIJS,center=169)
    y += 28

# 5. de knop -----------------------------------------------------------------
y += 3
d.rectangle((8,y,184,y+27),fill=PANEL,outline=INK)
tx((0,y+9),"Aan het werk",INK,center=W/2)
y += 30

img.save(f"{OUT}/zes_{SEL}_1x.png"); schaal(img,3).save(f"{OUT}/zes_{SEL}_3x.png")
print(SEL,"laatste y:",y+10,"van",H)
