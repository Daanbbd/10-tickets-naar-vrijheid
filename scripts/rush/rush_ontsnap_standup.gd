class_name RushOntsnapStandup
extends RefCounted
## De stand-up van dinsdag: een groepje collega's dat dwars door de gang staat,
## als een muur van mensen met precies één gat erin.
##
## Ze staan schouder aan schouder over de hele hoogte van de kolom waar ze
## staan, van wand tot wand: over een tafel of bureau heen staat niemand, want
## daar kun jij ook niet langs. Om de zoveel tijd schuift iemand een plekje op,
## en daarmee schuift het gat. En de hele groep schuifelt langzaam heen en
## weer, zoals een stand-up dat doet.
##
## Wie toch tegen iemand aan loopt, wordt erbij getrokken ("Even over de
## architectuur...") en staat langer stil dan bij een losse collega. Daarna is
## die ene collega doorzichtig en kun je erdoor: zo loopt niemand ooit vast,
## ook niet wie nooit stuurt.
##
## Ben je erdoor, dan verkast de hele stand-up een stuk naar voren ("Walking
## stand-up!") en sta je verderop opnieuw voor de muur. De stations liggen ver
## genoeg uit elkaar dat het verhuizen buiten beeld gebeurt.

## Afstand tussen twee mensen in de muur. Met een raakvlak van 12 px hoog (en
## jouw 4) sluit een rij op deze afstand naadloos, en laat één ontbrekende een
## gat van ruim 28 px: anderhalve tegel, goed te halen.
const STAP := 30.0
## Raakvlak van iemand in de stand-up: even breed als een losse collega, maar
## hoger. Ze staan dicht op elkaar, schouder aan schouder.
const HALF := Vector2(5, 12)
## Elke zoveel seconden schuift het gat een plekje op.
const SCHUIF := 1.2
## Zo lang doet iemand over één plekje opschuiven.
const LOOP := 0.45
## Sta je er vlak voor, dan staat de kring even stil: ze hebben je gezien.
## Zonder dat schuift het gat soms net dicht terwijl je erin zit, en dat
## voelt als pech in plaats van als een fout. Mikken moet je vooraf.
const VRIES := 40.0
## Zo snel schuifelt de hele groep heen en weer.
const HEEN_WEER := 9.0
## Hoe lang ze je vasthouden.
const STIL := 1.2

const ZINNEN := [
	"Blokkades?",
	"Gisteren: tickets.",
	"Vandaag: nog meer tickets.",
	"Wie pakt deze op?",
	"Kort rondje!",
	"Ik ben bijna klaar!",
]

## De stand-up loopt een stuk mee naar voren. `p`: waar hij stond.
signal verhuist(p: Vector2, zin: String)

var leden: Array[RushOntsnapCollega] = []
var leider: RushOntsnapCollega
## Het midden van de muur, in wereldpixels.
var x := 0.0
var actief := false

var _stations: Array[Vector2i] = []
var _st := -1
var _x0 := 0.0
var _x1 := 0.0
var _rx := 1.0
## De plekken in de muur, van boven naar onder, en wie er staat (-1: het gat).
var _slots := PackedFloat32Array()
var _bezet := PackedInt32Array()
## Binnen welk stuk van de muur het gat heen en weer schuift: één aaneengesloten
## stuk vloer, zodat niemand over een tafel hoeft te stappen.
var _a := 0
var _b := 0
var _gat := 0
var _richting := 1
var _klok := 0.0
var _van := -1
var _naar := -1
var _praat := 2.0
var _bevroren := false
var _vrij_tegel: Callable
var _hoog := 26


## `vrij_tegel(Vector2i) -> bool`: mag je op deze tegel staan. `speler_y`:
## waar jij begint, want daar hangt het eerste gat van af.
func setup(wie: Array[RushOntsnapCollega], baas: RushOntsnapCollega, stations: Array[Vector2i],
		vrij_tegel: Callable, hoog: int, speler_y: float) -> void:
	leden = wie
	leider = baas
	_stations = stations
	_vrij_tegel = vrij_tegel
	_hoog = hoog
	_naar_station(0, speler_y)


func _naar_station(i: int, speler_y: float) -> void:
	_st = i
	if i >= _stations.size():
		actief = false
		for c: RushOntsnapCollega in leden:
			c.visible = false
			c.gesproken = true
		return
	actief = true
	var r := _stations[i]
	# Alleen kolommen met precies dezelfde vrije rijen: dan past de muur overal
	# waar hij heen schuifelt, zonder dat iemand in een bureau belandt.
	var vorm := _vrije_rijen(r.x)
	var x1 := r.x
	while x1 < r.y and _vrije_rijen(x1 + 1) == vorm:
		x1 += 1
	# Niet tot in de meest linkse kolom: links ervan staat vaak een bureau of
	# plantenbak, en wie dan door het gat gaat, staat er meteen tegenaan,
	# midden in de muur. Eén kolom ruimte, en je kunt erachter nog opzij.
	_x0 = (r.x + (1 if x1 > r.x else 0)) * 16.0 + 8.0
	_x1 = x1 * 16.0 + 8.0
	x = _x1
	_rx = 1.0
	_bouw_slots(vorm)
	_verdeel(speler_y, i == 0)
	_klok = 0.0
	_van = -1
	_naar = -1
	_zet_leden(0.0)


func _vrije_rijen(kol: int) -> PackedInt32Array:
	var uit := PackedInt32Array()
	for y: int in _hoog:
		if _vrij_tegel.call(Vector2i(kol, y)):
			uit.append(y)
	return uit


## Per aaneengesloten stuk vrije vloer zo veel plekken dat niemand ertussendoor
## kan: de eerste en laatste net binnen de wanden, de rest gelijk verdeeld op
## hooguit `STAP` van elkaar.
func _bouw_slots(rijen: PackedInt32Array) -> void:
	_slots = PackedFloat32Array()
	var stukken: Array[Vector2i] = []
	var i := 0
	while i < rijen.size():
		var j := i
		while j + 1 < rijen.size() and rijen[j + 1] == rijen[j] + 1:
			j += 1
		stukken.append(Vector2i(rijen[i], rijen[j]))
		i = j + 1
	var beste := -1
	var beste_n := 0
	for s: Vector2i in stukken:
		# Waar het midden van een speler kan zijn: 4 px binnen elke wand.
		var lo := s.x * 16.0 + 4.0
		var hi := (s.y + 1) * 16.0 - 4.0
		var n := maxi(1, ceili((hi - lo) / STAP))
		if n > beste_n:
			beste_n = n
			beste = _slots.size()
		for k: int in n:
			if n == 1:
				_slots.append((lo + hi) / 2.0)
			else:
				_slots.append(lerpf(lo + 14.0, hi - 14.0, float(k) / (n - 1)))
	_a = beste
	_b = beste + beste_n - 1


## Wie waar staat. Bij de eerste stand-up begint het gat aan jouw kant en
## schuift het van je weg: je ziet meteen hoe het werkt. Daarna begint het aan
## de verre kant en schuift het naar je toe, en moet je zelf op tijd sturen.
func _verdeel(speler_y: float, dichtbij: bool) -> void:
	_bezet.resize(_slots.size())
	_bezet.fill(-1)
	_gat = _a
	_richting = 1
	var verder_a := absf(speler_y - _slots[_a]) > absf(speler_y - _slots[_b])
	if dichtbij == verder_a:
		_gat = _b
		_richting = -1
	if _a == _b:
		_richting = 0
	# De leider in het midden van het stuk met het gat: daar is het gesprek.
	var midden := (_a + _b) / 2
	if midden == _gat:
		midden = clampi(midden + (1 if _gat == _a else -1), _a, _b)
	var volgorde: Array[int] = []
	for s: int in _slots.size():
		if s != _gat and s != midden:
			volgorde.append(s)
	if midden != _gat:
		volgorde.push_front(midden)
	var baas := leden.find(leider)
	var rest: Array[int] = []
	for k: int in leden.size():
		if k != baas:
			rest.append(k)
	rest.push_front(baas)
	for k: int in rest.size():
		var c := leden[rest[k]]
		c.herstel()
		c.gesproken = k >= volgorde.size()
		c.visible = k < volgorde.size()
		if k < volgorde.size():
			_bezet[volgorde[k]] = rest[k]


func tik(delta: float, speler: Vector2) -> void:
	if not actief:
		return
	# Voorbij? Dan loopt de stand-up mee naar voren.
	if speler.x < x - HALF.x - 14.0:
		_verhuis(speler)
		return
	_bevroren = bevroren(speler)
	if _bevroren:
		# Wie nog onderweg was, maakt zijn stapje af; daarna geen nieuwe.
		_klok = minf(_klok + delta, SCHUIF - 0.01)
	else:
		x += _rx * HEEN_WEER * delta
		if x > _x1:
			x = _x1
			_rx = -1.0
		elif x < _x0:
			x = _x0
			_rx = 1.0
		_klok += delta
		if _klok >= SCHUIF and _richting != 0:
			_klok -= SCHUIF
			_schuif()
	_zet_leden(_klok)
	_babbel(delta, speler)


func bevroren(speler: Vector2) -> bool:
	return speler.x - x < VRIES and speler.x > x - HALF.x * 2.0 - 4.0


## Iemand naast het gat stapt erin, en het gat zit nu waar hij stond.
func _schuif() -> void:
	var n := _gat + _richting
	if n < _a or n > _b:
		_richting = -_richting
		n = _gat + _richting
	_van = n
	_naar = _gat
	_bezet[_gat] = _bezet[n]
	_bezet[n] = -1
	_gat = n


func _zet_leden(klok: float) -> void:
	var f := clampf(klok / LOOP, 0.0, 1.0)
	f = f * f * (3.0 - 2.0 * f)
	for s: int in _slots.size():
		var k := _bezet[s]
		if k < 0:
			continue
		var c := leden[k]
		var y := _slots[s]
		var loopt := s == _naar and f < 1.0
		if loopt:
			y = lerpf(_slots[_van], _slots[_naar], f)
		# Een kring, van bovenaf half gezien: het midden staat wat naar voren,
		# en om en om een tikje heen en weer, zodat het een groepje is en geen
		# rij soldaten.
		var boog := 5.0 * sin(PI * float(s) / maxf(1.0, _slots.size() - 1.0))
		c.position = Vector2(roundf(x + boog + (2.0 if s % 2 == 0 else -2.0)), roundf(y))
		var anim := &"idle_right" if s % 2 == 0 else &"idle_left"
		if s == 0 or (s > 0 and _slots[s] - _slots[s - 1] > STAP + 8.0):
			anim = &"idle_down"
		elif s == _slots.size() - 1:
			anim = &"idle_up"
		if _bevroren:
			# Ze hebben je gezien en kijken allemaal jouw kant op.
			anim = &"idle_right"
		if c == leider and not c.gesproken:
			anim = &"talk_right" if _bevroren else &"talk_left"
		if loopt:
			anim = &"walk_down" if _slots[_naar] > _slots[_van] else &"walk_up"
		if c.sprite.animation != anim:
			c.sprite.play(anim)


## Af en toe zegt iemand iets: een stand-up is nooit stil. Alleen als je in de
## buurt bent, en nooit twee tegelijk.
func _babbel(delta: float, speler: Vector2) -> void:
	_praat -= delta
	if _praat > 0.0:
		return
	_praat = randf_range(2.2, 3.4)
	if absf(speler.x - x) > 170.0:
		return
	var wie: Array[RushOntsnapCollega] = []
	for c: RushOntsnapCollega in leden:
		if c.visible and not c.gesproken:
			wie.append(c)
	if wie.is_empty():
		return
	RushOntsnapBallon.zeg(wie[randi() % wie.size()], ZINNEN[randi() % ZINNEN.size()], 1.3)


## Je liep er tegenaan. De leider begint over zijn onderwerp, wie je raakte
## draait zich naar je om en laat je daarna door.
func heeft_je(c: RushOntsnapCollega) -> void:
	c.heeft_je(false)
	if leider != null and leider.visible:
		RushOntsnapBallon.zeg(leider, leider_zin(), 1.8)
	else:
		RushOntsnapBallon.zeg(c, leider_zin(), 1.8)


func leider_zin() -> String:
	if leider == null:
		return "Even over de architectuur..."
	return String(RushOntsnapCollega.EIGEN.get(leider.persoon, "Even over de architectuur..."))


func _verhuis(speler: Vector2) -> void:
	var verder := _st + 1
	# Geen ballon aan de leider: die verhuist zo meteen mee, en dan hangt zijn
	# zin ineens verderop in de gang.
	verhuist.emit(Vector2(x, speler.y), "Walking stand-up!" if verder < _stations.size() else "Klaar, iedereen!")
	# Even uitfaden, dan staan ze verderop klaar. Geen await op de tween: die
	# kan gekild worden en dan komt hij nooit terug.
	for c: RushOntsnapCollega in leden:
		var tw := c.create_tween()
		tw.tween_property(c.sprite, ^"modulate:a", 0.0, 0.25)
	actief = false
	# Aan een tween op een van hen, niet aan een losse timer: eindigt de
	# ontsnapping halverwege, dan gaat de tween mee en roept niemand een
	# vrijgegeven collega aan.
	var tw := leden[0].create_tween()
	tw.tween_interval(0.3)
	tw.tween_callback(func() -> void:
		_naar_station(verder, speler.y))


# --- Voor de bot -----------------------------------------------------------------

## Waar de mensen in de muur staan over `t` seconden, wie nog iets wil. Het
## schuiven gaat volgens een vast ritme, dus dat is exact te voorspellen.
## `vries`: over hoeveel seconden jij vlak voor de muur staat (en hij stopt).
func ys_over(t: float, vries := INF) -> PackedFloat32Array:
	var uit := PackedFloat32Array()
	if not actief:
		return uit
	var gat := _gat
	var r := _richting
	var bezet := _bezet.duplicate()
	var van := _van
	var naar := _naar
	var k := _klok
	var tijd := 0.0
	var rest := t
	while r != 0:
		var tot := SCHUIF - k
		if tot > rest:
			k += rest
			break
		if tijd + tot >= vries:
			k = minf(k + rest, SCHUIF - 0.01)
			break
		tijd += tot
		rest -= tot
		k = 0.0
		var n := gat + r
		if n < _a or n > _b:
			r = -r
			n = gat + r
		van = n
		naar = gat
		bezet[gat] = bezet[n]
		bezet[n] = -1
		gat = n
	var f := clampf(k / LOOP, 0.0, 1.0)
	f = f * f * (3.0 - 2.0 * f)
	for s: int in _slots.size():
		var m := bezet[s]
		if m < 0 or leden[m].gesproken:
			continue
		var y := _slots[s]
		if s == naar and f < 1.0:
			y = lerpf(_slots[van], _slots[naar], f)
		uit.append(y)
	return uit


## Over hoeveel seconden je vlak voor de muur staat (en hij stilvalt) als je
## vanaf `speler_x` met `snel` px/s naar links blijft lopen, en waar de muur
## dan staat. Het heen-en-weer schuifelen gaat ook volgens een vast ritme.
func vooruit(speler_x: float, snel: float) -> Vector2:
	var xs := x
	var r := _rx
	var t := 0.0
	while t < 10.0:
		if speler_x - snel * t - xs < VRIES:
			return Vector2(t, xs)
		xs += r * HEEN_WEER * 0.02
		if xs > _x1:
			xs = _x1
			r = -1.0
		elif xs < _x0:
			xs = _x0
			r = 1.0
		t += 0.02
	return Vector2(INF, xs)


## Hoe ver hoogte `y` van iedereen in de muur af blijft, de hele tijd van
## `t0` tot `t1` (groot = veilig).
func ruimte(y: float, t0: float, t1: float, vries := INF) -> float:
	var minst := INF
	for i: int in 5:
		var t := lerpf(t0, t1, i / 4.0)
		for m: float in ys_over(t, vries):
			minst = minf(minst, absf(m - y))
	return minst


## De plekken in de muur: waar het gat ooit kan zitten.
func slots() -> PackedFloat32Array:
	return _slots
