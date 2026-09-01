W,H = 72,40
g = [['#']*W for _ in range(H)]

def rect(x0,y0,x1,y1,ch):
    for y in range(y0,y1+1):
        for x in range(x0,x1+1):
            if 0<=x<W and 0<=y<H: g[y][x]=ch

# ---- rooms (floor) ----
rect(1,1,19,14,'.')    # Z1 receptie
rect(1,16,19,38,'.')   # Z2 keuken
rect(21,1,53,7,'.')    # Z3 open kantoor noord
rect(54,1,54,7,'.')    # koppeling Z3<->Z4
rect(55,1,70,38,'.')   # Z4 open kantoor oost
rect(21,8,53,10,'.')   # gang noord
rect(21,29,53,31,'.')  # gang zuid
rect(21,8,23,31,'.')   # gang west
rect(51,8,53,31,'.')   # gang oost
rect(25,12,40,19,'.')  # Z5 vergader
rect(42,12,49,19,'.')  # Z6 server
rect(25,21,32,27,'.')  # Z7 toilet
rect(34,21,49,27,'.')  # Z8 archief
rect(21,33,26,38,'.')  # Z9a belhok A
rect(28,33,33,38,'.')  # Z9b belhok B
rect(35,33,45,38,'.')  # Z9c stilte
rect(47,33,53,38,'.')  # Z9d nooduitgang portaal

# ---- glass ----
rect(29,11,39,11,'=')  # vergader noordgevel glas
rect(24,12,24,19,'=')  # vergader westgevel glas
rect(30,7,43,7,'=')    # open kantoor noord glas naar gang
rect(54,16,54,24,'=')  # open kantoor oost glas naar gang

# ---- doors / openings ----
rect(0,7,0,8,'V')      # VOORDEUR
rect(20,11,20,13,'D')  # receptie -> gang west
rect(20,24,20,26,'D')  # keuken -> gang west
rect(8,15,10,15,'D')   # receptie -> keuken
rect(26,7,28,7,'D'); rect(44,7,46,7,'D')     # open noord -> gang noord
rect(54,13,54,15,'D'); rect(54,25,54,27,'D') # open oost -> gang oost
rect(26,11,27,11,'D')  # vergaderruimte
rect(45,11,46,11,'D')  # serverruimte
rect(24,24,24,25,'D')  # toilet
rect(40,28,41,28,'D')  # archief
rect(23,32,24,32,'D'); rect(30,32,31,32,'D'); rect(39,32,40,32,'D'); rect(49,32,50,32,'D')
rect(50,39,51,39,'N')  # nooduitgang (op slot)

FLOOR_CHARS = '.DEOLGI'  # vloertegels (niet-solide) — kamerkleurzonering-letters horen hierbij
walk = set()
for y in range(H):
    for x in range(W):
        if g[y][x] in FLOOR_CHARS: walk.add((x,y))

# ---- furniture ----
F = [
 (1,1,1,1,'p'),(2,1,3,1,'o'),(12,1,18,1,'o'),(4,3,10,4,'B'),(16,3,17,4,'P'),
 (1,10,1,12,'T'),(3,10,6,11,'c'),(4,12,5,12,'o'),(18,13,18,13,'p'),
 (2,16,12,17,'K'),(13,16,14,17,'f'),(4,22,14,25,'t'),(14,30,18,32,'o'),
 (1,20,1,30,'p'),(16,17,18,17,'x'),(2,34,6,36,'c'),
 (24,2,31,3,'b'),(24,5,31,6,'b'),(36,2,43,3,'b'),(36,5,43,6,'b'),
 (22,1,22,1,'p'),(22,6,22,6,'p'),(47,1,50,1,'m'),(51,5,53,6,'o'),
 (57,10,64,11,'b'),(57,13,64,14,'b'),(57,18,64,19,'b'),(57,21,64,22,'b'),
 (70,11,70,14,'m'),(57,31,62,34,'c'),(64,32,65,33,'o'),(69,1,69,1,'p'),
 (69,25,69,25,'p'),(55,28,55,33,'o'),(55,36,55,36,'p'),
 (28,14,37,17,'t'),(31,19,34,19,'m'),(40,13,40,18,'x'),(26,18,26,18,'p'),
 (43,13,44,18,'S'),(47,13,48,18,'S'),(46,19,46,19,'o'),
 (26,22,27,24,'W'),(29,22,30,24,'W'),(26,27,31,27,'W'),
 (36,22,47,22,'A'),(36,24,47,24,'A'),(35,26,36,27,'P'),(44,26,47,27,'o'),(48,21,48,21,'o'),
 (22,34,23,34,'o'),(31,33,31,33,'o'),(37,35,38,36,'c'),(42,35,43,36,'c'),(40,34,40,34,'p'),
 (48,33,48,33,'o'),(52,37,53,38,'o'),
 (21,8,21,8,'p'),(53,8,53,8,'o'),(52,31,53,31,'x'),(21,31,21,31,'o'),
 (21,19,21,19,'o'),(36,8,36,8,'p'),(53,20,53,20,'p'),
 (55,2,55,2,'T'),  # tweede sprintbord — moet in sync blijven met gen_floor.py
 (15,16,15,16,'H'),  # prikbord — moet in sync blijven met gen_floor.py
]
for (x0,y0,x1,y1,ch) in F:
    for y in range(y0,y1+1):
        for x in range(x0,x1+1):
            if g[y][x]=='.': g[y][x]=ch

# ---- kamerkleurzonering (moet in sync blijven met gen_floor.py's ACCENT_ROOMS) ----
ACCENT = [
 (1,1,19,14,'E'),(1,16,19,38,'O'),(25,12,40,19,'L'),
 (21,33,26,38,'I'),(28,33,33,38,'I'),(35,33,45,38,'G'),
]
for (x0,y0,x1,y1,ch) in ACCENT:
    for y in range(y0,y1+1):
        for x in range(x0,x1+1):
            if g[y][x]=='.': g[y][x]=ch

# ---- print ----
print('    '+''.join(str(x//10%10) if x%5==0 else ' ' for x in range(W)))
print('    '+''.join(str(x%10) if x%5==0 else '.' for x in range(W)))
for y in range(H):
    print(f'{y:3d} '+''.join(g[y]))

# ---- reachability + diameter ----
import heapq
solid = set()
for y in range(H):
    for x in range(W):
        if g[y][x] not in FLOOR_CHARS + 'V': solid.add((x,y))
free = [(x,y) for y in range(H) for x in range(W) if (x,y) not in solid and g[y][x]!='V']

def dij(src):
    dist={src:0.0}; pq=[(0.0,src)]
    while pq:
        d,(x,y)=heapq.heappop(pq)
        if d>dist.get((x,y),1e9): continue
        for dx in(-1,0,1):
            for dy in(-1,0,1):
                if dx==0 and dy==0: continue
                n=(x+dx,y+dy)
                if n in solid or not(0<=n[0]<W and 0<=n[1]<H): continue
                if g[n[1]][n[0]]=='V': continue
                if dx and dy:
                    if (x+dx,y) in solid or (x,y+dy) in solid: continue
                nd=d+(1.4142 if dx and dy else 1.0)
                if nd<dist.get(n,1e9): dist[n]=nd; heapq.heappush(pq,(nd,n))
    return dist

start=(1,8)
d0=dij(start)
unreach=[p for p in free if p not in d0]
print('\nonbereikbare vloertegels:',len(unreach), unreach[:20])

# approximate diameter: max over a sample of sources
import random
random.seed(1)
best=(0,None,None)
srcs=[start,(1,1),(1,38),(18,38),(70,1),(70,38),(46,16),(31,25),(23,36),(52,37),(55,1)]
for s in srcs:
    if s in solid: continue
    dd=dij(s)
    for p,v in dd.items():
        if v>best[0]: best=(v,s,p)
print('langste route (tiles):',round(best[0],1),'van',best[1],'naar',best[2])
for spd,name in [(6.0,'lopen 96px/s'),(9.0,'sprint 144px/s')]:
    print(f'  {name}: {best[0]/spd:.1f}s')

# typical trips
pairs=[((1,8),(6,7),'voordeur->balie'),((6,7),(26,4),'balie->Victor bureau'),
 ((26,4),(46,16),'Victor->serverruimte'),((46,16),(8,19),'server->koffiemachine'),
 ((8,19),(33,13),'keuken->vergadertafel'),((33,13),(58,12),'vergader->Danny'),
 ((58,12),(23,36),'Danny->belhok A'),((23,36),(44,26),'belhok->archief'),
 ((44,26),(28,23),'archief->toilet'),((28,23),(1,8),'toilet->voordeur')]
tot=0
for a,b,lbl in pairs:
    dd=dij(a); v=dd.get(b)
    tot+=v
    print(f'  {lbl:28s} {v:6.1f} tiles  {v/6.0:4.1f}s')
print('som van deze 10 trips:',round(tot/6.0,1),'s lopen')
