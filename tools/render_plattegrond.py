"""Rendert de hele verdieping uit data/floor.json met de echte tile-atlas en
propsprites, volgens dezelfde regels als world_builder.populate() en
main._spawn_props(). Pure stdlib: geen PIL."""
import json, zlib, struct, os, sys

# Uit __file__ en niet hardgecodeerd: dit script wordt naar een worktree
# gekopieerd (fun-db draait het vanuit /Users/daan/Documents/fun-vloer), en een
# vast pad rendert daar stil de hóófdcheckout — je kijkt dan naar een vloer die
# je niet aan het veranderen bent, zonder foutmelding.
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# ---------- PNG lezen ----------
def png_read(path):
    d = open(path, "rb").read()
    assert d[:8] == b"\x89PNG\r\n\x1a\n", path
    pos, idat, plte, trns = 8, b"", None, None
    w = h = bd = ct = il = 0
    while pos < len(d):
        ln = struct.unpack(">I", d[pos:pos+4])[0]
        typ = d[pos+4:pos+8]; body = d[pos+8:pos+8+ln]; pos += 12 + ln
        if typ == b"IHDR":
            w, h, bd, ct, _, _, il = struct.unpack(">IIBBBBB", body)
        elif typ == b"PLTE": plte = body
        elif typ == b"tRNS": trns = body
        elif typ == b"IDAT": idat += body
        elif typ == b"IEND": break
    assert il == 0, "interlaced niet ondersteund: " + path
    assert bd == 8, "bitdepth %d niet ondersteund: %s" % (bd, path)
    nch = {0:1, 2:3, 3:1, 4:2, 6:4}[ct]
    raw = zlib.decompress(idat)
    stride = w * nch
    out = bytearray(w * h * 4)
    prev = bytearray(stride)
    p = 0
    for y in range(h):
        f = raw[p]; p += 1
        line = bytearray(raw[p:p+stride]); p += stride
        if f == 1:
            for i in range(nch, stride): line[i] = (line[i] + line[i-nch]) & 255
        elif f == 2:
            for i in range(stride): line[i] = (line[i] + prev[i]) & 255
        elif f == 3:
            for i in range(stride):
                a = line[i-nch] if i >= nch else 0
                line[i] = (line[i] + ((a + prev[i]) >> 1)) & 255
        elif f == 4:
            for i in range(stride):
                a = line[i-nch] if i >= nch else 0
                b = prev[i]; c = prev[i-nch] if i >= nch else 0
                pa, pb, pc = abs(b-c), abs(a-c), abs(a+b-2*c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pr) & 255
        for x in range(w):
            s = x * nch; o = (y*w + x) * 4
            if ct == 6:   out[o:o+4] = line[s:s+4]
            elif ct == 2: out[o:o+3] = line[s:s+3]; out[o+3] = 255
            elif ct == 4: v = line[s]; out[o:o+4] = bytes((v,v,v,line[s+1]))
            elif ct == 0: v = line[s]; out[o:o+4] = bytes((v,v,v,255))
            elif ct == 3:
                i = line[s]; out[o:o+3] = plte[i*3:i*3+3]
                out[o+3] = trns[i] if (trns and i < len(trns)) else 255
        prev = line
    return w, h, out

def png_write(path, w, h, buf):
    rows = bytearray()
    for y in range(h):
        rows.append(0)
        rows += buf[y*w*4:(y+1)*w*4]
    def chunk(t, b):
        c = struct.pack(">I", len(b)) + t + b
        return c + struct.pack(">I", zlib.crc32(t + b) & 0xffffffff)
    png = (b"\x89PNG\r\n\x1a\n"
           + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(bytes(rows), 9))
           + chunk(b"IEND", b""))
    open(path, "wb").write(png)

# ---------- blit ----------
def blit(dst, dw, dh, src, sw, sh, dx, dy):
    for y in range(sh):
        ty = dy + y
        if ty < 0 or ty >= dh: continue
        for x in range(sw):
            tx = dx + x
            if tx < 0 or tx >= dw: continue
            so = (y*sw + x) * 4
            a = src[so+3]
            if a == 0: continue
            do = (ty*dw + tx) * 4
            if a == 255:
                dst[do:do+4] = src[so:so+4]
            else:
                for c in range(3):
                    dst[do+c] = (src[so+c]*a + dst[do+c]*(255-a)) // 255
                dst[do+3] = max(dst[do+3], a)

# ---------- data ----------
floor = json.load(open(os.path.join(ROOT, "data/floor.json")))
meta  = json.load(open(os.path.join(ROOT, "assets/tilesets/office_atlas.json")))
coords = meta["coords"]
legend = floor["legend"]
grid   = floor["grid"]
TS     = floor["tile_size"]
W, H   = floor["size"]

aw, ah, atlas = png_read(os.path.join(ROOT, "assets/tilesets/office_atlas.png"))
tiles = {}
for ch, c in coords.items():
    cx, cy = int(c[0]), int(c[1])
    t = bytearray(TS*TS*4)
    for y in range(TS):
        so = ((cy*TS + y)*aw + cx*TS) * 4
        t[y*TS*4:(y+1)*TS*4] = atlas[so:so + TS*4]
    tiles[ch] = t

VAR = [".", ",", ";"]
def vloer_variant(x, y):
    return VAR[abs((x*73856093) ^ (y*19349663)) % 3]

IMG_W, IMG_H = W*TS, H*TS
img = bytearray(IMG_W*IMG_H*4)

missing = set()
def put(ch, x, y):
    t = tiles.get(ch)
    if t is None:
        missing.add(ch); return
    blit(img, IMG_W, IMG_H, t, TS, TS, x*TS, y*TS)

for y in range(H):
    row = grid[y]
    for x in range(W):
        ch = row[x]
        info = legend.get(ch, {})
        kind = info.get("kind", "floor")
        if kind in ("wall", "exit"):
            put(ch, x, y)
        elif kind == "floor":
            put(vloer_variant(x, y) if ch == "." else ch, x, y)
        else:                      # prop-tegel: vloer eronder, teken erop
            put(vloer_variant(x, y), x, y)
            put(ch, x, y)

# props, gesorteerd op voet zodat overlap klopt
props = sorted(floor.get("props", []), key=lambda p: p["rect"][3])
for p in props:
    naam = p["prop"]
    path = os.path.join(ROOT, "assets/sprites/props", naam + ".png")
    if not os.path.exists(path):
        print("ONTBREEKT:", path); continue
    sw, sh, spr = png_read(path)
    r = p["rect"]
    fpw = (r[2]-r[0]+1)*TS; fph = (r[3]-r[1]+1)*TS
    dx = r[0]*TS + (fpw - sw)//2
    dy = r[1]*TS + (fph - sh)//2
    blit(img, IMG_W, IMG_H, spr, sw, sh, dx, dy)

if missing:
    print("legenda-tekens zonder atlas-coord (renderen stil als leeg):", sorted(missing))

out = os.path.join(ROOT, "docs/audit-shots/plattegrond_1x.png")
png_write(out, IMG_W, IMG_H, img)
print("geschreven:", out, IMG_W, "x", IMG_H)

if "--no3x" in sys.argv:
    print("(--no3x: 3x-upscale overgeslagen)")
    raise SystemExit(0)

# 3x nearest-neighbour voor leesbaarheid
S = 3
bw, bh = IMG_W*S, IMG_H*S
big = bytearray(bw*bh*4)
for y in range(IMG_H):
    for x in range(IMG_W):
        o = (y*IMG_W + x)*4
        px = img[o:o+4]
        for dy in range(S):
            ro = ((y*S+dy)*bw + x*S)*4
            for dx in range(S):
                big[ro+dx*4:ro+dx*4+4] = px
out3 = os.path.join(ROOT, "docs/audit-shots/plattegrond_3x.png")
png_write(out3, bw, bh, big)
print("geschreven:", out3, bw, "x", bh)
