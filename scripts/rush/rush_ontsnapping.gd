class_name RushOntsnapping
extends Node2D
## De ontsnapping: na een gewonnen dag ren je door het échte kantoor naar de
## voordeur. Letterlijk naar vrijheid.
##
## De vloer is `data/floor.json`, tegel voor tegel, getekend door dezelfde
## `WorldBuilder` als het oude avontuur. De indeling ís het level: bureaus,
## plantenkasten en de muur van de entree houden je tegen, en de enige weg
## naar buiten is de deur waar hij in het echt ook zit.
##
## Je loopt vanzelf naar links. Jij stuurt alleen omhoog en omlaag, met één
## duim. Achter je staat het kantoor in brand: een vuurfront rukt van rechts
## op en jaagt je naar de deur. Collega's staan in de weg of stappen je pad in
## ("Heb je even?").
##
## Elke dag van de week is een andere ontsnapping, met een eigen startplek en
## een eigen twist (`RushOntsnapDag`): maandag de gewone weg, dinsdag een
## stand-up dwars door de gang (`RushOntsnapStandup`), woensdag Dirk vlak
## achter je (`RushOntsnapDirk`), donderdag gouden spoedtickets op riskante
## plekken, en vrijdag alles tegelijk plus een plafond dat naar beneden komt
## (`RushOntsnapPlafond`).
##
## Hangt bovenop de rush als kind van RushGame (eigen CanvasLayers, boven de
## rush-HUD op 10), of draait los als scene-root via `--rush-ontsnap`.

signal klaar(seconden: float, gebotst: int, overgeslagen: bool)

enum Fase { WACHT, UITLEG, REN, BUITEN, KLAAR }

const T := 16
## Vanzelf, naar links. De kortste weg van bureau naar deur duurt zo ~20 s;
## wie ergens tegenaan loopt of een opening mist, zit eerder op 25 tot 30.
const SNELHEID := 56.0
## Omhoog en omlaag mag sneller dan vooruit: sturen moet een reactie zijn,
## geen voornemen.
const STUUR := 130.0
## Hoeveel de speler beweegt per pixel duim. Iets meer dan één, zodat je met
## een korte veeg een hele rij opschuift zonder je duim ver te verzetten.
const GEVOELIG := 1.25
## Halve maat van je raakvlak rond de voeten. Smal genoeg voor een deur van
## twee tegels en een gangetje van één.
const HALF := Vector2(5, 4)
## Sta je met een paar pixels tegen een hoek, dan schuif je er vanzelf
## langs. Zonder dit blijf je op een telefoon voortdurend aan randjes haken.
const HOEK := 6.0
const BOOST := 1.5
const BOOST_DUUR := 2.5
const BOTS_STIL := 0.8
## Hoe lang Dirk je vasthoudt. Daarna blijft hij nog even tevreden staan
## (`RushOntsnapDirk.RUST`): anders heeft hij je meteen weer.
const DIRK_STIL := 1.5
const TICKET_BONUS := 1.0
## Een gouden spoedticket is meer waard dan een gewoon kaartje, want het ligt
## altijd ergens waar het pakken iets kan kosten.
const SPOED_BONUS := 1.5
## Een plafondplaat op je hoofd: even knipperen.
const PLAFOND_STIL := 0.7
## Het vuur begint even na de start.
const VUUR_START := 0.8
## Wat het kost als het vuur je inhaalt: tijd erbij, kuchen, en dan ben je er
## net uit en houdt het vuur even in. Geen game over: het moet een rush
## blijven, geen straf.
const VUUR_BOETE := 2.0
const VUUR_KUCH := 0.6
const VUUR_ADEM := 1.2
## Dag, titel en twist lezen kost even; tikken sluit hem eerder.
const UITLEG_DUUR := 2.6

## De binnendeur die altijd openstaat: van De Werkvloer naar de entree. De
## rest zit dicht, want wie naar links rent en een kamer in schiet komt er
## nooit meer uit. Vrijdag gaan de deuren van Weekend erbij open
## (`RushOntsnapDag.deuren`): daar begin je dan.
const OPEN_DEUREN: Array[Vector2i] = [Vector2i(9, 19), Vector2i(9, 20)]

const BALK := 28
const LAAG := 20
const Z_HANGEND := 20
const PROPS_DIR := "res://assets/sprites/props/"

const KOLLEGAS: Array[StringName] = [
	&"daan", &"danny", &"victor", &"jonathan", &"willem", &"bastiaan", &"koen", &"dennis"]

var speler_id: StringName = &"daan"
var dag_index := 0
var bot := false
## Wat vandaag anders is: startplek, vuur, collega's, Dirk en de twist.
var _dag: RushOntsnapDag
var fase := Fase.WACHT
var seconden := 0.0
## Elke keer dat iemand je ophoudt, Dirk je vangt of het vuur je inhaalt.
var gebotst := 0
## Hoe vaak het vuur je had. Telt ook mee in `gebotst`.
var verbrand := 0

var _los := false
var _builder := WorldBuilder.new()
## Per tegel: 1 is voor ons dicht. Niet hetzelfde als `is_solid()`: de
## voordeur is hier open en de binnendeuren dicht.
var _dicht := PackedByteArray()
var _breed := 0
var _hoog := 0

var _achter: CanvasLayer
var _wereldlaag: CanvasLayer
var _wereld: Node2D
var _dingen: Node2D
var _onder: Node2D
var _boven: Node2D
var _speler: Node2D
var _speler_sprite: AnimatedSprite2D
var _dirk: RushOntsnapDirk
## Hoe vaak Dirk je al had: de eerste keer zegt hij altijd hetzelfde.
var _dirk_had := 0
var _standup: RushOntsnapStandup
var _plafond: RushOntsnapPlafond
var _plaat_klok := 2.5
## Net geraakt (door een plaat of het vuur): de volgende platen mikken even
## niet op jou. Eén plaat is pech, drie achter elkaar is pesten.
var _plaat_rust := 0.0
var _collegas: Array[RushOntsnapCollega] = []
var _oppak: Array[Dictionary] = []

var _ui: CanvasLayer
var _wortel: Control
var _tijd_lbl: Label
var _balk: Control
var _uitleg: Control
var _pijlen: Control

var _doel_y := 0.0
var _stil := 0.0
## Net weer los: heel even kan niemand je opnieuw pakken. Anders houdt de een
## je vast tot de ander je heeft, en kom je nooit meer weg.
var _genade := 0.0
var _boost := 0.0
var _sleept := false
var _toets := false
var _anker_vinger := 0.0
var _anker_doel := 0.0
var _schok := 0.0
var _cam_x := 0.0
## Waar je op het scherm staat, van links (zie `RushOntsnapDag.camera`).
var _cam_anker := 0.66
var _vp := Vector2(192, 416)
var _tijd := 0.0
var _fase_t := 0.0
var _start_x := 0.0
var _uit_x := 0.0
var _kijk := &"left"

## Waar je gelopen hebt: Dirk loopt het na.
var _spoor := PackedVector2Array()

var _vuur: Node2D
var _vuur_actief := false
var _vuur_x := INF
var _vuur_adem := 0.0
var _vuur_snelheid := 0.0
var _vonken: Array[Dictionary] = []
var _rook: Array[Dictionary] = []
var _vonk_klok := 0.0
var _rook_scherm: ColorRect

var _stofjes: Array[Dictionary] = []
var _stof_timer := 0.0
var _beweegt := false
var _stap_timer := 0.0
var _muziek := false
var _bot_pad: Array[Vector2i] = []
var _bot_klok := 0.0
## Hoe lang je al niet naar links bent gekomen, en hoe lang het spel nog
## voor je stuurt. Wie niet doorheeft dat je moet slepen, staat anders
## eindeloos tegen een bureau te lopen terwijl het vuur nadert.
var _vast := 0.0
var _hulp := 0.0
var _vast_gezegd := false


func _ready() -> void:
	# Los gestart (`--rush-ontsnap`): dan start hij zichzelf. Als kind van de
	# rush wacht hij op `start()`.
	if get_parent() == get_tree().root:
		_los = true
		_lees_vlaggen()
		start(speler_id, dag_index)


func _lees_vlaggen() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a == "--rush-bot":
			bot = true
		elif a.begins_with("--dag="):
			dag_index = clampi(int(a.get_slice("=", 1)) - 1, 0, 4)
		elif a.begins_with("--speler="):
			speler_id = StringName(a.get_slice("=", 1))


## Bouwt het kantoor en begint. Mag ook vóór `add_child`: dan wacht hij tot
## hij in de boom hangt, want de camera moet de schermmaat kennen.
func start(id: StringName, dag: int) -> void:
	if not is_inside_tree():
		await ready
	speler_id = id
	dag_index = clampi(dag, 0, 4)
	_dag = RushOntsnapDag.voor(dag_index)
	_cam_anker = _dag.camera
	if not _builder.load_floor():
		push_error("RushOntsnapping: geen vloer, dan ook geen ontsnapping")
		_einde(true)
		return
	_breed = _builder.size.x
	_hoog = _builder.size.y
	_bouw_dicht()
	_bouw_lagen()
	_bouw_wereld()
	_bouw_speler()
	_bouw_dirk()
	_bouw_ui()
	_zet_obstakels()
	if AudioDirector.has_music(&"rush_ontsnapping"):
		AudioDirector.set_layer(&"minigame", &"rush_ontsnapping", 0.4)
		_muziek = true
	_pas_camera(0.0, true)
	fase = Fase.UITLEG
	_fase_t = 0.0


func _exit_tree() -> void:
	if _muziek:
		AudioDirector.clear_layer(&"minigame", 0.4)
		_muziek = false


# --- De vloer -------------------------------------------------------------------

func _bouw_dicht() -> void:
	_dicht.resize(_breed * _hoog)
	for y: int in _hoog:
		for x: int in _breed:
			var t := Vector2i(x, y)
			var ch := _builder.char_at(t)
			var dicht := _builder.is_solid(t)
			if ch == "V":
				dicht = false
			elif ch == "D" and not (t in OPEN_DEUREN or t in _dag.deuren):
				dicht = true
			_dicht[y * _breed + x] = 1 if dicht else 0
	_sluit_doodlopers()


## Zet elke vrije tegel dicht vanwaar je met alleen links, omhoog en omlaag
## de voordeur niet meer haalt. Op deze vloer is dat precies één hoekje (links
## onder in de entree, achter de bank), maar een nieuwe plattegrond mag geen
## val worden waar je zonder terugweg in vastloopt.
func _sluit_doodlopers() -> void:
	var goed := {}
	var rij: Array[Vector2i] = []
	for y: int in _hoog:
		var t := Vector2i(0, y)
		if _builder.char_at(t) == "V":
			goed[t] = true
			rij.append(t)
	# Achteruit zoeken: wie naar links kan stappen naar een goede tegel, staat
	# zelf goed. Dus vanaf een goede tegel kijken we rechts, boven en onder.
	while not rij.is_empty():
		var t: Vector2i = rij.pop_front()
		for d: Vector2i in [Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n := t + d
			if not goed.has(n) and not _dicht_op(n):
				goed[n] = true
				rij.append(n)
	for y: int in _hoog:
		for x: int in _breed:
			if not goed.has(Vector2i(x, y)):
				_dicht[y * _breed + x] = 1


func _dicht_op(t: Vector2i) -> bool:
	if t.x < 0 or t.y < 0 or t.x >= _breed or t.y >= _hoog:
		return true
	return _dicht[t.y * _breed + t.x] == 1


## Past een raakvlak van `HALF` rond `p`?
func _vrij(p: Vector2) -> bool:
	var x0 := floori((p.x - HALF.x) / T)
	var x1 := floori((p.x + HALF.x - 0.01) / T)
	var y0 := floori((p.y - HALF.y) / T)
	var y1 := floori((p.y + HALF.y - 0.01) / T)
	for ty: int in range(y0, y1 + 1):
		for tx: int in range(x0, x1 + 1):
			if _dicht_op(Vector2i(tx, ty)):
				return false
	return true


func _tegel(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / T), floori(p.y / T))


func _midden(t: Vector2i) -> Vector2:
	return Vector2(t) * T + Vector2(T, T) * 0.5


# --- Opbouw -----------------------------------------------------------------------

func _bouw_lagen() -> void:
	# Eigen lagen boven de rush: die tekent gewoon door onder ons, en zijn HUD
	# zit op 10.
	_achter = CanvasLayer.new()
	_achter.layer = LAAG - 1
	add_child(_achter)
	var vul := ColorRect.new()
	vul.color = Color("#2f3442")
	vul.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_achter.add_child(vul)
	UiKit.fill_viewport(vul)

	_wereldlaag = CanvasLayer.new()
	_wereldlaag.layer = LAAG
	add_child(_wereldlaag)


func _bouw_wereld() -> void:
	_wereld = Node2D.new()
	_wereld.y_sort_enabled = true
	_wereldlaag.add_child(_wereld)
	var ground := TileMapLayer.new()
	ground.z_index = -10
	_wereld.add_child(ground)
	var solid := TileMapLayer.new()
	solid.y_sort_enabled = true
	_wereld.add_child(solid)
	_builder.populate(ground, solid)

	_onder = Node2D.new()
	_onder.z_index = -5
	_onder.draw.connect(_teken_onder)
	_wereld.add_child(_onder)

	_dingen = Node2D.new()
	_dingen.y_sort_enabled = true
	_wereld.add_child(_dingen)
	_zet_props()
	var dak := HokjeDak.new()
	_dingen.add_child(dak)
	dak.setup(_builder)
	# In het avontuur hangt het dak boven alles, want je kon erin. Hier kom je
	# er nooit in, maar loop je er wel vlak onderlangs (de smalle gang van
	# dinsdag en donderdag): dan hoort je hoofd ervóór te staan, niet eronder.
	dak.z_index = 0

	# Het vuur over alles heen, maar onder de ballonnen en de getallen.
	_vuur = Node2D.new()
	_vuur.z_index = 25
	_vuur.draw.connect(_teken_vuur)
	_wereld.add_child(_vuur)

	if _dag.plafond:
		_plafond = RushOntsnapPlafond.new()
		_plafond.valt.connect(_plaat_valt)
		_wereld.add_child(_plafond)

	_boven = Node2D.new()
	_boven.z_index = 30
	_boven.draw.connect(_teken_boven)
	_wereld.add_child(_boven)


## Samengestelde meubels, op dezelfde manier als `Main._spawn_props()`: de
## tegel eronder is de footprint, de sprite het beeld, gesorteerd op de voet.
func _zet_props() -> void:
	var half := Vector2(T, T) * 0.5
	for raw: Variant in _builder.props:
		var p := raw as Dictionary
		var pad := "%s%s.png" % [PROPS_DIR, String(p.get("prop", ""))]
		if not ResourceLoader.exists(pad):
			continue
		var r: Array = p.get("rect", [0, 0, 0, 0])
		var s := Sprite2D.new()
		s.texture = load(pad)
		s.centered = false
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var lb := _builder.tile_to_world(Vector2i(int(r[0]), int(r[1]))) - half
		var voet := Vector2(float(int(r[2]) - int(r[0]) + 1), float(int(r[3]) - int(r[1]) + 1)) * T
		var tex := s.texture.get_size()
		if bool(p.get("hangend", false)):
			s.position = lb + (voet - tex) * 0.5
			s.z_index = Z_HANGEND
		else:
			s.position = Vector2(lb.x + (voet.x - tex.x) * 0.5, lb.y + voet.y)
			s.offset = Vector2(0.0, -(voet.y + tex.y) * 0.5)
		_dingen.add_child(s)


func _bouw_speler() -> void:
	_speler = Node2D.new()
	_speler.position = _midden(_dag.start)
	_dingen.add_child(_speler)
	_speler_sprite = AnimatedSprite2D.new()
	_speler_sprite.offset = Vector2(0, -16)
	_speler_sprite.position = Vector2(0, 3)
	_speler_sprite.sprite_frames = RushOntsnapCollega.frames_voor(speler_id)
	_speler.add_child(_speler_sprite)
	_speler_sprite.play(&"idle_left")
	_doel_y = _speler.position.y
	_start_x = _speler.position.x
	_uit_x = T + HALF.x
	_spoor.append(_speler.position)


func _bouw_dirk() -> void:
	_vuur_snelheid = SNELHEID * _dag.vuur
	if _dag.dirk == RushOntsnapDag.Dirk.GEEN:
		return
	_dirk = RushOntsnapDirk.new()
	_dingen.add_child(_dirk)
	_dirk.setup(_vrij)
	_dirk.duik = _dag.duik
	if _dag.dirk != RushOntsnapDag.Dirk.HIELEN:
		return
	# Hij stond al bij je bureau: een paar tegels rechts van je, met een eigen
	# stukje spoor naar jou toe. Daarna loopt hij precies jouw voetstappen na.
	var weg := PackedVector2Array()
	var t := _dag.start
	for i: int in 3:
		if _dicht_op(t + Vector2i.RIGHT):
			break
		t += Vector2i.RIGHT
	while t.x > _dag.start.x:
		weg.append(_midden(t))
		t += Vector2i.LEFT
	weg.append_array(_spoor)
	_spoor = weg
	_dirk.verschijn_achter(_spoor, 0, "")


# --- Collega's, koffie en kaartjes ------------------------------------------------

## De kortste weg naar buiten met alleen links, omhoog en omlaag. Leeg als
## er geen is. `mijd` zijn tegels die de bot liever niet neemt. Met `naar`
## zoekt hij de weg naar die ene tegel in plaats van naar de voordeur.
func _zoek_pad(van: Vector2i, mijd: Dictionary, naar := Vector2i(-1, -1)) -> Array[Vector2i]:
	var vorige := {van: van}
	var rij: Array[Vector2i] = [van]
	var doel := Vector2i(-1, -1)
	while not rij.is_empty():
		var t: Vector2i = rij.pop_front()
		if t == naar or (naar.x < 0 and _builder.char_at(t) == "V"):
			doel = t
			break
		# Eerst omhoog en omlaag: van alle even korte wegen wint zo die waarop
		# je zo vroeg mogelijk opzij stuurt. Opzij gaat tijdens het rennen
		# vanzelf mee; wie te laat stuurt, loopt ergens tegenaan.
		for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT]:
			var n := t + d
			if vorige.has(n) or _dicht_op(n) or mijd.has(n):
				continue
			vorige[n] = t
			rij.append(n)
	var uit: Array[Vector2i] = []
	if doel.x < 0:
		return uit
	var t := doel
	while t != van:
		uit.append(t)
		t = vorige[t]
	uit.append(van)
	uit.reverse()
	return uit


func _zet_obstakels() -> void:
	var route := _zoek_pad(_dag.start, {})
	if route.is_empty():
		push_error("RushOntsnapping: geen weg van de start naar de deur")
		return
	var mensen: Array[StringName] = []
	for k: StringName in KOLLEGAS:
		if k != speler_id:
			mensen.append(k)
	mensen.shuffle()
	var bezet: Array[int] = []
	if not _dag.standup.is_empty():
		_zet_standup(mensen)
	elif not _dag.vaste.is_empty():
		for i: int in _dag.vaste.size():
			var v: Dictionary = _dag.vaste[i]
			var t: Vector2i = v["t"]
			_zet_collega(mensen[i % mensen.size()], v["g"], t, t)
			bezet.append(t.x)
	else:
		var aantal := _dag.collegas
		var gedragen := _gedragen(aantal)
		for i: int in mini(aantal, mensen.size()):
			var x := roundi(lerpf(_dag.start.x - 8.0, 13.0, (i + 0.5) / aantal))
			var t := _route_op(route, x)
			bezet.append(t.x)
			_zet_collega(mensen[i], gedragen[i], t)
	_zet_oppak(route, bezet)


## De stand-up: iedereen die er vandaag is, met Jonathan als leider (en Koen
## als jij Jonathan bent). Ze beginnen bij het eerste station; de stand-up
## zelf bepaalt waar ze staan.
func _zet_standup(mensen: Array[StringName]) -> void:
	var baas_id := &"koen" if speler_id == &"jonathan" else &"jonathan"
	var leden: Array[RushOntsnapCollega] = []
	var baas: RushOntsnapCollega = null
	for id: StringName in mensen:
		var c := RushOntsnapCollega.new()
		c.position = _midden(_dag.standup[0])
		_dingen.add_child(c)
		c.setup(id, RushOntsnapCollega.Gedrag.KRING, _vrij)
		c.half = RushOntsnapStandup.HALF
		leden.append(c)
		_collegas.append(c)
		if id == baas_id:
			baas = c
	if baas == null and not leden.is_empty():
		baas = leden[0]
	_standup = RushOntsnapStandup.new()
	_standup.setup(leden, baas, _dag.standup, func(t: Vector2i) -> bool: return not _dicht_op(t), _hoog,
		_speler.position.y)
	_standup.verhuist.connect(_standup_verhuist)


## Je bent erdoor; de stand-up loopt mee naar voren. Even in beeld zeggen,
## vlak achter je, want daar stonden ze.
func _standup_verhuist(p: Vector2, zin: String) -> void:
	var b := UiKit.FONT_10.get_string_size(zin, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	var x := clampf(p.x, _cam_x + b / 2.0 + 4.0, _cam_x + _vp.x - b / 2.0 - 4.0)
	RushOntsnapBallon.getal(_boven, Vector2(x, p.y - 34.0), zin, Color("#8fb3ff"))


## Welke soorten collega's er vandaag staan. Maandag staan ze vooral stil;
## vrijdag stapt het merendeel je pad in.
func _gedragen(aantal: int) -> Array[RushOntsnapCollega.Gedrag]:
	var stappers := _dag.stappers
	var ijsberen := _dag.ijsberen
	var uit: Array[RushOntsnapCollega.Gedrag] = []
	for i: int in aantal:
		if i < stappers:
			uit.append(RushOntsnapCollega.Gedrag.STAPPEN)
		elif i < stappers + ijsberen:
			uit.append(RushOntsnapCollega.Gedrag.IJSBEREN)
		else:
			uit.append(RushOntsnapCollega.Gedrag.STAAN)
	uit.shuffle()
	# De eerste die je tegenkomt staat stil: daar leer je sturen.
	var eerste := uit.find(RushOntsnapCollega.Gedrag.STAAN)
	if eerste > 0:
		var wissel := uit[0]
		uit[0] = uit[eerste]
		uit[eerste] = wissel
	return uit


## De routetegel in kolom `x`, of de dichtstbijzijnde.
func _route_op(route: Array[Vector2i], x: int) -> Vector2i:
	var beste := route[0]
	for t: Vector2i in route:
		if absi(t.x - x) < absi(beste.x - x):
			beste = t
	return beste


## `vast`: precies op deze tegel, in plaats van naast de route.
func _zet_collega(id: StringName, g: RushOntsnapCollega.Gedrag, t: Vector2i, vast := Vector2i(-1, -1)) -> void:
	var plek := t
	var baan := Vector2i.ZERO
	if vast.x >= 0:
		if g == RushOntsnapCollega.Gedrag.IJSBEREN:
			baan = _kolom_baan(t)
	elif g == RushOntsnapCollega.Gedrag.STAPPEN:
		# Twee of drie rijen naast de route, zodat hij erin kan stappen.
		plek = _naast(t, [3, -3, 2, -2])
		if plek == t:
			g = RushOntsnapCollega.Gedrag.STAAN
	elif g == RushOntsnapCollega.Gedrag.IJSBEREN:
		baan = _kolom_baan(t)
		if baan.y - baan.x < 2:
			g = RushOntsnapCollega.Gedrag.STAAN
	var c := RushOntsnapCollega.new()
	c.position = _midden(plek)
	_dingen.add_child(c)
	c.setup(id, g, _vrij)
	c.snelheid = _dag.stap_snel
	c.opmerk = RushOntsnapCollega.OPMERK + _dag.opmerk
	if g == RushOntsnapCollega.Gedrag.IJSBEREN:
		c.snelheid = 26.0 + 0.15 * _dag.stap_snel
		c.zet_baan(_midden(Vector2i(t.x, baan.x)).y, _midden(Vector2i(t.x, baan.y)).y)
	_collegas.append(c)


## Een vrije tegel `n` rijen boven of onder `t`, met vrije vloer ertussen.
func _naast(t: Vector2i, afstanden: Array) -> Vector2i:
	for n: int in afstanden:
		var ok := true
		for i: int in range(1, absi(n) + 1):
			if _dicht_op(t + Vector2i(0, i * signi(n))):
				ok = false
				break
		if ok:
			return t + Vector2i(0, n)
	return t


## Hoe ver je in deze kolom omhoog en omlaag kunt, hooguit drie rijen.
func _kolom_baan(t: Vector2i) -> Vector2i:
	var boven := t.y
	while boven > t.y - 3 and not _dicht_op(Vector2i(t.x, boven - 1)):
		boven -= 1
	var onder := t.y
	while onder < t.y + 3 and not _dicht_op(Vector2i(t.x, onder + 1)):
		onder += 1
	return Vector2i(boven, onder)


## Koffie en kaartjes op de route, niet in de kolom van een collega: wie
## koffie pakt hoort niet meteen tegen iemand op te lopen. Om en om, gelijk
## verdeeld over de weg. De gouden spoedtickets liggen juist wél op riskante
## plekken, en die staan per dag vast (`RushOntsnapDag.spoed`).
func _zet_oppak(route: Array[Vector2i], bezet: Array[int]) -> void:
	var soorten: Array[String] = []
	var k := _dag.koffie
	var tk := _dag.kaartjes
	while k > 0 or tk > 0:
		if tk > 0:
			soorten.append("ticket")
			tk -= 1
		if k > 0:
			soorten.append("koffie")
			k -= 1
	for i: int in soorten.size():
		var f := lerpf(0.2, 0.95, float(i) / maxf(1.0, soorten.size() - 1.0))
		var x := roundi(lerpf(_dag.start.x - 4.0, 4.0, f))
		for poging: int in 4:
			var vrij := true
			for b: int in bezet:
				if absi(b - x) < 2:
					vrij = false
			if vrij:
				break
			x -= 1
		var t := _route_op(route, x)
		if soorten[i] == "ticket":
			# Een rij ernaast: een kaartje pak je met een klein stuurtje.
			t = _naast(t, [1, -1])
		_oppak.append({"p": _midden(t), "soort": soorten[i], "weg": false})
	for t: Vector2i in _dag.spoed:
		if _dicht_op(t):
			push_warning("RushOntsnapping: spoedticket op een dichte tegel %s" % t)
			continue
		# Hetzelfde gouden kaartje dat klopt als op het bord.
		var kaart := RushTicket.new()
		kaart.spoed = true
		kaart.staat = RushTicket.Staat.WERK
		kaart.vak = randi() % RushData.VAK_KLEUR.size()
		kaart.position = _midden(t) + Vector2(0, -6)
		_boven.add_child(kaart)
		_oppak.append({"p": _midden(t), "soort": "spoed", "weg": false, "kaart": kaart})


# --- De UI ---------------------------------------------------------------------------

func _bouw_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = LAAG + 1
	add_child(_ui)
	# Het hele scherm vangt de duim: sturen kan overal, ook op de balk.
	_wortel = Control.new()
	_wortel.mouse_filter = Control.MOUSE_FILTER_STOP
	_ui.add_child(_wortel)
	UiKit.fill_viewport(_wortel)
	_wortel.gui_input.connect(_op_invoer)

	# Rook in beeld als het vuur je inhaalt.
	_rook_scherm = ColorRect.new()
	_rook_scherm.color = Color(0.16, 0.13, 0.12, 0.0)
	_rook_scherm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wortel.add_child(_rook_scherm)
	_rook_scherm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var boven := ColorRect.new()
	boven.color = Color("#141824", 0.94)
	boven.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wortel.add_child(boven)
	boven.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	boven.offset_bottom = BALK

	var kop := _lbl("NAAR HUIS", 10, Color("#8fb3ff"))
	kop.position = Vector2(6, 2)
	boven.add_child(kop)

	_balk = Control.new()
	_balk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_balk.draw.connect(_teken_balk)
	boven.add_child(_balk)
	_balk.anchor_right = 1.0
	_balk.offset_left = 6
	_balk.offset_right = -104
	_balk.offset_top = 16
	_balk.offset_bottom = 24

	_tijd_lbl = _lbl("0,0", 16, Color.WHITE)
	_tijd_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	boven.add_child(_tijd_lbl)
	_tijd_lbl.anchor_left = 1.0
	_tijd_lbl.anchor_right = 1.0
	_tijd_lbl.offset_left = -100
	_tijd_lbl.offset_right = -58
	_tijd_lbl.offset_top = 4

	var over := Button.new()
	over.text = "Overslaan"
	over.focus_mode = Control.FOCUS_NONE
	over.add_theme_font_override(&"font", UiKit.FONT_10)
	over.add_theme_font_size_override(&"font_size", 10)
	over.add_theme_stylebox_override(&"normal", _vlak(Color("#2a3042")))
	over.add_theme_stylebox_override(&"hover", _vlak(Color("#36405a")))
	over.add_theme_stylebox_override(&"pressed", _vlak(Color("#4a5677")))
	over.add_theme_color_override(&"font_color", Color("#d6dbe8"))
	boven.add_child(over)
	over.anchor_left = 1.0
	over.anchor_right = 1.0
	over.offset_left = -54
	over.offset_right = -4
	over.offset_top = 4
	over.offset_bottom = 24
	over.pressed.connect(_sla_over)

	_bouw_uitleg()


func _bouw_uitleg() -> void:
	_uitleg = Control.new()
	_uitleg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wortel.add_child(_uitleg)
	_uitleg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var midden := CenterContainer.new()
	midden.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_uitleg.add_child(midden)
	midden.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	# Boven de route, in de gang: zo zie je jezelf en de eerste collega nog.
	# Boven de route, zodat je jezelf en wat eraan komt nog ziet. Begin je
	# bovenin (donderdag), dan eronder.
	_vp = get_viewport().get_visible_rect().size
	var boven := _dag.start.y < 13
	midden.offset_top = BALK + (230 if boven else 60)
	midden.offset_bottom = midden.offset_top + 100
	var paneel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#141824", 0.94)
	sb.border_color = Color("#3a86ff")
	sb.set_border_width_all(1)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 7
	paneel.add_theme_stylebox_override(&"panel", sb)
	paneel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	midden.add_child(paneel)
	var kol := VBoxContainer.new()
	kol.add_theme_constant_override(&"separation", 2)
	paneel.add_child(kol)
	# Drie regels: welke dag het is, wat er vandaag anders is, en hoe je stuurt.
	# Op een smal toestel valt de titel terug op de kleinere snit.
	var ruimte := minf(_vp.x - 36.0, 176.0)
	var kop := "%s · %s" % [_dag.naam, _dag.titel]
	var maat := 12 if UiKit.FONT_12.get_string_size(kop, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x <= ruimte else 10
	var t0 := _lbl(kop, maat, Color("#8fb3ff"))
	t0.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t0.autowrap_mode = TextServer.AUTOWRAP_OFF
	kol.add_child(t0)
	var t1 := _lbl(_dag.regel, 10, Color("#ff8a3d"))
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t1.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t1.custom_minimum_size.x = ruimte
	kol.add_child(t1)
	var t2 := _lbl("Sleep om te sturen.", 10, Color.WHITE)
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t2.autowrap_mode = TextServer.AUTOWRAP_OFF
	kol.add_child(t2)
	_pijlen = Control.new()
	_pijlen.custom_minimum_size = Vector2(0, 14)
	_pijlen.draw.connect(_teken_pijlen)
	kol.add_child(_pijlen)


func _teken_pijlen() -> void:
	# Een duim die op en neer veegt: twee pijltjes en een stip.
	var c := _pijlen
	var m := Vector2(c.size.x / 2.0, 7)
	var f := sin(_tijd * 6.0) * 2.0
	var k := Color("#8fb3ff")
	c.draw_colored_polygon(PackedVector2Array([
		m + Vector2(-4, -3 + f), m + Vector2(4, -3 + f), m + Vector2(0, -7 + f)]), k)
	c.draw_colored_polygon(PackedVector2Array([
		m + Vector2(-4, 3 + f), m + Vector2(4, 3 + f), m + Vector2(0, 7 + f)]), k)
	c.draw_circle(m + Vector2(0, f), 2.0, Color.WHITE)


func _lbl(t: String, maat: int, k: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override(&"font", UiKit.font_voor(maat))
	l.add_theme_font_size_override(&"font_size", maat)
	l.add_theme_color_override(&"font_color", k)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _vlak(k: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = k
	sb.border_color = k.darkened(0.35)
	sb.set_border_width_all(1)
	return sb


# --- Invoer --------------------------------------------------------------------------

## Relatief slepen, overal op het scherm. Waar je duim begint maakt niet uit;
## alleen hoe ver je hem omhoog of omlaag haalt. Zo zit je duim nooit over je
## eigen poppetje of over de collega die eraan komt, en hoef je niet te mikken
## op een plek naast een figuurtje van 18 pixels. Tikken-boven-of-onder lijkt
## eenvoudiger, maar dan dekt je duim precies af waar je heen wil.
func _op_invoer(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		_sleept = mb.pressed
		if mb.pressed:
			_anker_vinger = mb.position.y
			_anker_doel = _speler.position.y if _speler != null else 0.0
			_doel_y = _anker_doel
			if fase == Fase.UITLEG:
				_sluit_uitleg()
		return
	var mm := event as InputEventMouseMotion
	if mm != null and _sleept and not bot:
		_doel_y = _klem_y(_anker_doel + (mm.position.y - _anker_vinger) * GEVOELIG)


func _klem_y(y: float) -> float:
	return clampf(y, T + HALF.y, (_hoog - 1) * T - HALF.y)


## Pijltjes op een toetsenbord, voor wie op een laptop speelt.
func _toetsen() -> void:
	var k := Input.get_axis(&"ui_up", &"ui_down")
	if not is_zero_approx(k):
		_toets = true
		_doel_y = _klem_y(_speler.position.y + k * 10.0)
	elif _toets:
		_toets = false
		_doel_y = _speler.position.y


func _sla_over() -> void:
	if fase == Fase.KLAAR:
		return
	AudioDirector.play_ui(&"klik")
	_einde(true)


func _sluit_uitleg() -> void:
	if fase != Fase.UITLEG:
		return
	fase = Fase.REN
	_fase_t = 0.0
	if _dag.plafond:
		# Vrijdag: het brandalarm, want nu brandt écht alles.
		AudioDirector.play_sfx(&"rush_brand", 0.02, -4.0)
	if _dirk != null and _dirk.actief():
		RushOntsnapBallon.zeg(_dirk, "Uren al geboekt?", 1.6)
		AudioDirector.play_sfx(&"rush_dirk", 0.05, -2.0)
	var tw := _uitleg.create_tween()
	tw.tween_property(_uitleg, ^"modulate:a", 0.0, 0.2)
	tw.tween_callback(_uitleg.hide)


# --- Het rennen --------------------------------------------------------------------

func _process(delta: float) -> void:
	if fase == Fase.WACHT:
		return
	# In kleine stapjes: botsen tegen een tegel van 16 px mag niet afhangen
	# van een trage telefoon die maar 20 beelden per seconde haalt.
	var rest := minf(delta, 0.1)
	while rest > 0.0:
		var stap := minf(rest, 1.0 / 60.0)
		rest -= stap
		_stap(stap)
	_pas_camera(delta, false)
	_onder.queue_redraw()
	_vuur.queue_redraw()
	_boven.queue_redraw()
	_balk.queue_redraw()
	if _uitleg.visible:
		_pijlen.queue_redraw()


func _stap(delta: float) -> void:
	_tijd += delta
	_fase_t += delta
	match fase:
		Fase.UITLEG:
			if _fase_t >= UITLEG_DUUR:
				_sluit_uitleg()
		Fase.REN:
			_ren(delta)
		Fase.BUITEN:
			_naar_buiten(delta)
	_werk_stof(delta)
	_werk_vonken(delta)


func _ren(delta: float) -> void:
	seconden += delta
	_tijd_lbl.text = _tekst_tijd(seconden)
	if bot or _hulp > 0.0:
		_bot_stuur(delta)
		_hulp = maxf(0.0, _hulp - delta)
	else:
		_toetsen()
	_boost = maxf(0.0, _boost - delta)
	_genade = maxf(0.0, _genade - delta)
	if _stil > 0.0:
		_stil -= delta
		if _stil <= 0.0:
			_genade = 0.4
			if _kijk == &"right":
				RushOntsnapBallon.zeg(_speler, "Ja, Dirk.", 0.9)
	else:
		_beweeg(delta)
	if _standup != null:
		_standup.tik(delta, _speler.position)
	for c: RushOntsnapCollega in _collegas:
		c.tik(delta, _speler.position)
		if _stil <= 0.0 and _genade <= 0.0 and c.raakt(_speler.position, HALF):
			_bots(c)
	_werk_vuur(delta)
	_werk_dirk(delta)
	_werk_plafond(delta)
	_werk_oppak()
	if _speler.position.x - HALF.x < T:
		_buiten()


func _beweeg(delta: float) -> void:
	var oud := _speler.position
	var vx := SNELHEID * (BOOST if _boost > 0.0 else 1.0) * delta
	var nx := oud + Vector2(-vx, 0)
	if _vrij(nx):
		_speler.position = nx
	else:
		_hoek(nx)
	var dy := clampf(_doel_y - _speler.position.y, -STUUR * delta, STUUR * delta)
	if not is_zero_approx(dy):
		_stap_y(dy)
	var d := _speler.position - oud
	if d.x > -0.05 * delta * 60.0:
		_vast += delta
		if _vast > 1.0 and not _vast_gezegd:
			_vast_gezegd = true
			RushOntsnapBallon.zeg(_speler, "Sleep omhoog of omlaag!", 1.4)
		if _vast > 1.8:
			_vast = 0.0
			_hulp = 1.2
	else:
		_vast = 0.0
	_animeer(d)
	_beweegt = d.length() > 0.05
	if _beweegt:
		if _speler.position.distance_to(_spoor[_spoor.size() - 1]) >= 3.0:
			_spoor.append(_speler.position)
		_stof_timer -= delta
		_stap_timer -= delta
	if _stap_timer <= 0.0:
		_stap_timer = 0.28 if _boost <= 0.0 else 0.2
		AudioDirector.play_sfx(&"rush_stap", 0.12, -12.0)


## Tegen iets aan: past het met een paar pixels op of neer, dan glij je er
## langs. Eerst de kant op waar je heen stuurt.
func _hoek(nx: Vector2) -> void:
	var kant := signf(_doel_y - _speler.position.y)
	if kant == 0.0:
		kant = -1.0
	var volgorde: Array[float] = [kant, -kant]
	for k: int in range(1, int(HOEK) + 1):
		for s: float in volgorde:
			var p := nx + Vector2(0, s * k)
			if _vrij(p) and _vrij(_speler.position + Vector2(0, s * k)):
				_speler.position = p
				if signf(_doel_y - p.y) != s:
					_doel_y = p.y
				return


## Omhoog of omlaag tot waar het past.
func _stap_y(dy: float) -> void:
	var p := _speler.position + Vector2(0, dy)
	if _vrij(p):
		_speler.position = p
		return
	var s := signf(dy)
	var rest := absf(dy)
	while rest > 0.0:
		var stap := minf(1.0, rest)
		if not _vrij(_speler.position + Vector2(0, s * stap)):
			return
		_speler.position.y += s * stap
		rest -= stap


func _animeer(d: Vector2) -> void:
	var anim := &"idle_left"
	if d.x < -0.05:
		anim = &"walk_left"
	elif absf(d.y) > 0.05:
		anim = &"walk_down" if d.y > 0.0 else &"walk_up"
	_kijk = &"left"
	if _speler_sprite.animation != anim:
		_speler_sprite.play(anim)
	_speler_sprite.speed_scale = 1.6 if _boost > 0.0 else 1.3


func _bots(c: RushOntsnapCollega) -> void:
	gebotst += 1
	_stil = BOTS_STIL
	if c.gedrag == RushOntsnapCollega.Gedrag.KRING:
		# De stand-up trekt je erbij, en dat duurt.
		_stil = RushOntsnapStandup.STIL
		_standup.heeft_je(c)
		AudioDirector.play_sfx(&"rush_afkappen", 0.05, -4.0)
	else:
		c.heeft_je()
	_speler_sprite.play(&"idle_left")
	_flits(Color(1.0, 0.6, 0.6))
	RushOntsnapBallon.getal(_boven, _speler.position + Vector2(12, -18), "oef!", Color("#ff6b7a"))
	AudioDirector.play_sfx(&"rush_bots")
	Haptiek.tril(Haptiek.Sterkte.STOOT)
	_schok = maxf(_schok, 2.0)
	_stof_wolk(_speler.position, 6)


func _flits(k: Color) -> void:
	_speler_sprite.modulate = k
	var tw := _speler_sprite.create_tween()
	tw.tween_property(_speler_sprite, ^"modulate", Color.WHITE, 0.35)


# --- Dirk ---------------------------------------------------------------------------

func _werk_dirk(delta: float) -> void:
	if _dirk == null:
		return
	if not _dirk.actief():
		if _dag.dirk == RushOntsnapDag.Dirk.HALVERWEGE and _voortgang(_speler.position.x) >= 0.45:
			_dirk_halverwege()
		return
	var vuur := _vuur_x if _vuur_actief else INF
	if _dirk.tik(delta, _speler.position, _spoor, _stil > 0.0 or _genade > 0.0, vuur, _cam_x + _vp.x):
		_dirk_vangt()
	# Zit hij achter je aan, dan schuift het beeld een stukje op: je moet hem
	# kunnen zien aankomen.
	var jaagt := _dirk.position.x > _speler.position.x and _dirk.staat != RushOntsnapDirk.Staat.TEGEMOET
	var anker := minf(_dag.camera, 0.56) if jaagt else _dag.camera
	_cam_anker = lerpf(_cam_anker, anker, 1.0 - exp(-delta * 2.0))


## Vrijdag, halverwege: Dirk duikt op. De ene keer komt hij je van voren
## tegemoet, de andere keer rent hij je van achteren op.
func _dirk_halverwege() -> void:
	if randf() < 0.5:
		# Van voren: net buiten beeld links, op de weg die jij zou nemen.
		var pad := _zoek_pad(_tegel(_speler.position), {})
		var x := _speler.position.x - _vp.x * _cam_anker - 18.0
		var plek := Vector2.ZERO
		for t: Vector2i in pad:
			if _midden(t).x <= x and not _iemand_bij(_midden(t), 28.0):
				plek = _midden(t)
				break
		if plek != Vector2.ZERO and plek.x > 12.0 * T:
			_dirk.verschijn_voor(plek, "UREN!")
			return
	# Van achteren: een eind terug op je spoor, net buiten beeld rechts.
	var i := _spoor.size() - 1
	var a := 0.0
	while i > 0 and a < 90.0:
		a += _spoor[i].distance_to(_spoor[i - 1])
		i -= 1
	_dirk.verschijn_achter(_spoor, i, "UREN! Wacht!")


func _dirk_vangt() -> void:
	gebotst += 1
	_stil = DIRK_STIL
	_kijk = &"right"
	_speler_sprite.play(&"idle_right")
	_flits(Color(0.75, 0.8, 1.0))
	_dirk.praat("Uren al geboekt?" if _dirk_had == 0 else RushData.kies(RushData.DIRK))
	_dirk_had += 1
	RushOntsnapBallon.getal(_boven, _speler.position + Vector2(-14, -18), "Dirk!", Color("#ff6b7a"))
	AudioDirector.play_sfx(&"rush_dirk")
	Haptiek.tril(Haptiek.Sterkte.SLAG)
	_schok = maxf(_schok, 3.0)


# --- Het plafond (vrijdag) -------------------------------------------------------

## Om de anderhalve à twee seconden komt er een plaat naar beneden, vlak voor
## je uit: waar je over `AANLOOP` seconden ongeveer bent, in jouw rij of een
## ernaast. Nooit waar je er niet omheen kunt, en niet meer in de entree.
func _werk_plafond(delta: float) -> void:
	if _plafond == null or _fase_t < 2.5:
		return
	_plaat_rust = maxf(0.0, _plaat_rust - delta)
	_plaat_klok -= delta
	if _plaat_klok > 0.0:
		return
	_plaat_klok = randf_range(1.1, 1.9)
	var x := _speler.position.x - SNELHEID * RushOntsnapPlafond.AANLOOP - randf_range(0.0, 28.0)
	var tx := floori(x / T)
	if tx <= 11:
		return
	var ty := _tegel(_speler.position).y
	var rijen: Array[int] = [0, 0, 1, -1]
	if _plaat_rust > 0.0 or _stil > 0.0:
		rijen = [2, -2, 3, -3]
	rijen.shuffle()
	rijen.append_array([1, -1, 2, -2])
	for d: int in rijen:
		var t := Vector2i(tx, ty + d)
		if _dicht_op(t):
			continue
		if _dicht_op(t + Vector2i.UP) and _dicht_op(t + Vector2i.DOWN):
			continue
		_plafond.laat_vallen(_midden(t))
		AudioDirector.play_sfx(&"rush_weg", 0.1, -10.0)
		return


func _plaat_valt(p: Vector2) -> void:
	if fase != Fase.REN:
		return
	var d := _speler.position - p
	if absf(d.x) < 8.0 + HALF.x and absf(d.y) < 8.0 + HALF.y and _stil <= 0.0 and _genade <= 0.0:
		gebotst += 1
		_stil = PLAFOND_STIL
		_speler_sprite.play(&"idle_left")
		_flits(Color(1.0, 0.55, 0.25))
		RushOntsnapBallon.zeg(_speler, "Au! Heet!", 0.9)
		_plaat_rust = 2.5
		RushOntsnapBallon.getal(_boven, _speler.position + Vector2(12, -18), "au!", Color("#ff8a3d"))
		AudioDirector.play_sfx(&"rush_bots")
		Haptiek.tril(Haptiek.Sterkte.SLAG)
		_schok = maxf(_schok, 3.0)
		_stof_wolk(p, 8)
	elif d.length() < 90.0:
		AudioDirector.play_sfx(&"rush_bots", 0.1, -9.0)
		_schok = maxf(_schok, 1.2)
		_stof_wolk(p, 5)


# --- Het vuur -------------------------------------------------------------------------

## Hoe ver het vuur hooguit achter je zit: rond de rechterrand van het
## scherm, zodat je de gloed altijd ziet en de vlammen zodra je treuzelt.
## Op vrijdag zit het dichter op je huid.
func _vuur_gat() -> float:
	return _dag.vuur_gat


func _werk_vuur(delta: float) -> void:
	if not _vuur_actief:
		if _fase_t < VUUR_START:
			return
		_vuur_actief = true
		_vuur_x = _speler.position.x + _dag.vuur_begin
	if _vuur_adem > 0.0:
		_vuur_adem -= delta
	else:
		_vuur_x -= _vuur_snelheid * delta
	# Elastiek: loop je ver vooruit, dan raast het bij. Het jaagt, altijd.
	_vuur_x = minf(_vuur_x, _speler.position.x + _vuur_gat())
	if _stil > 0.0:
		# Wie stilstaat voelt de hitte al, maar het pakt je pas als je weer
		# kunt bewegen: dan telt het niet dubbel met wie je ophield.
		_vuur_x = maxf(_vuur_x, _speler.position.x + HALF.x + 1.0)
	elif _vuur_x <= _speler.position.x + HALF.x:
		_vuur_raakt()


func _vuur_raakt() -> void:
	gebotst += 1
	verbrand += 1
	seconden += VUUR_BOETE
	_stil = VUUR_KUCH
	_vuur_x = _speler.position.x + _vuur_gat()
	_vuur_adem = VUUR_ADEM
	# Elke keer dat het je inhaalt, zakt het een tikje in. Wie goed loopt
	# merkt er niets van; wie blijft haken, raakt niet in een spiraal van
	# steeds weer verbranden waar hij nooit meer uitkomt.
	_vuur_snelheid = maxf(SNELHEID * 0.6, _vuur_snelheid * 0.95)
	_plaat_rust = 2.5
	_speler_sprite.play(&"idle_left")
	_speler_sprite.modulate = Color(0.3, 0.27, 0.27)
	var tw := _speler_sprite.create_tween()
	tw.tween_property(_speler_sprite, ^"modulate", Color.WHITE, 1.4)
	RushOntsnapBallon.zeg(_speler, "Kuch! Heet!", 1.0)
	RushOntsnapBallon.getal(_boven, _speler.position + Vector2(-14, -20), "+2 s", Color("#ff6b7a"))
	for i: int in 10:
		_rook.append({"p": _speler.position + Vector2(randf_range(-8, 8), randf_range(-26, 0)),
			"v": Vector2(randf_range(-14, 6), randf_range(-22, -8)), "t": 0.0, "r": randf_range(3, 6)})
	_rook_scherm.color.a = 0.55
	var rk := _rook_scherm.create_tween()
	rk.tween_property(_rook_scherm, ^"color:a", 0.0, 1.2)
	AudioDirector.play_sfx(&"rush_bots", 0.05)
	Haptiek.tril(Haptiek.Sterkte.SLAG)
	_schok = maxf(_schok, 3.5)


## Vonken en rook langs het front. Ze leven in wereldcoördinaten en worden
## alleen rond het beeld gemaakt: buiten beeld rook tekenen is zonde.
func _werk_vonken(delta: float) -> void:
	if _vuur_actief:
		_vonk_klok -= delta
		while _vonk_klok <= 0.0:
			_vonk_klok += 0.035
			_maak_vonk()
	_werk_deeltjes(_vonken, 0.7, delta)
	_werk_deeltjes(_rook, 1.6, delta)


func _werk_deeltjes(lijst: Array[Dictionary], leven: float, delta: float) -> void:
	for i: int in range(lijst.size() - 1, -1, -1):
		var d := lijst[i]
		d["t"] = float(d["t"]) + delta
		d["p"] = (d["p"] as Vector2) + (d["v"] as Vector2) * delta
		if float(d["t"]) > leven:
			lijst.remove_at(i)


func _maak_vonk() -> void:
	var boven := -float(WorldBuilder.RAND_RIJEN * T)
	var onder := float((_hoog + WorldBuilder.RAND_RIJEN) * T)
	var y := randf_range(boven, onder)
	_vonken.append({"p": Vector2(_vuur_x + randf_range(-10, 10), y),
		"v": Vector2(randf_range(-55, -15), randf_range(-40, 10)), "t": 0.0})
	if randf() < 0.45:
		_rook.append({"p": Vector2(_vuur_x + randf_range(0, 30), y),
			"v": Vector2(randf_range(-18, -4), randf_range(-26, -12)), "t": 0.0, "r": randf_range(4, 8)})


## Een muur van vlammen over de hele hoogte. Onderin een gekartelde rand die
## naar links likt; daarop rijen losse vlammen die omhoog lekken, elk in drie
## lagen (rood, oranje, gele kern). De tijd loopt in stapjes van twaalf per
## seconde en alles staat op hele pixels: zo flakkert het als pixelart in
## plaats van te vloeien als een filter.
func _teken_vuur() -> void:
	if not _vuur_actief:
		return
	var x0 := roundf(_vuur_x)
	var boven := -float(WorldBuilder.RAND_RIJEN * T)
	var onder := float((_hoog + WorldBuilder.RAND_RIJEN) * T)
	var rechts := _cam_x + _vp.x + 40.0
	var tq := floorf(_tijd * 12.0) / 12.0
	var puls := 0.85 + 0.15 * sin(tq * 11.0)
	# Rode gloed op de vloer voor het front uit.
	for i: int in 10:
		var a := 0.028 * (i + 1) * puls
		_vuur.draw_rect(Rect2(x0 - 100.0 + i * 10.0, boven, 10.0, onder - boven), Color(1.0, 0.32, 0.08, a))
	# Wat al gebrand heeft: verkoold, met nagloeiende kooltjes.
	if rechts > x0 + 8.0:
		_vuur.draw_rect(Rect2(x0 + 8.0, boven, rechts - x0 - 8.0, onder - boven), Color(0.09, 0.04, 0.03, 0.78))
		_teken_kooltjes(x0 + 40.0, rechts, boven, onder, tq)
	var y := boven
	var rij := 0
	while y < onder:
		_teken_rand(x0, y, rij, tq)
		y += 4.0
		rij += 1
	y = boven + 6.0
	rij = 0
	while y < onder + 20.0:
		for kol: int in [2, 1, 0]:
			_teken_vlam(x0, y, rij, kol, tq)
		y += 9.0
		rij += 1
	for v: Dictionary in _vonken:
		var f := float(v["t"]) / 0.7
		var k := Color("#ffd23f").lerp(Color("#ff6b2b"), f)
		k.a = 1.0 - f
		_vuur.draw_rect(Rect2((v["p"] as Vector2).round(), Vector2(2, 2)), k)
	for r: Dictionary in _rook:
		var f := float(r["t"]) / 1.6
		var m := roundf(float(r["r"]) * (1.0 + f * 1.5))
		_vuur.draw_rect(Rect2((r["p"] as Vector2).round() - Vector2(m, m), Vector2(m, m) * 2.0),
			Color(0.22, 0.2, 0.2, 0.32 * (1.0 - f)))


## De gekartelde voet van het vuur: per vier pixels een tong naar links.
func _teken_rand(x0: float, y: float, rij: int, tq: float) -> void:
	var n := sin(tq * 9.0 + rij * 0.9) + 0.6 * sin(tq * 14.3 + rij * 2.3)
	var lang := snappedf(10.0 + n * 5.0, 2.0)
	_vuur.draw_rect(Rect2(x0 - lang, y, lang + 30.0, 4), Color("#b8282a"))
	_vuur.draw_rect(Rect2(x0 - snappedf(lang * 0.6, 2.0), y, 18.0, 4), Color("#ff6b2b"))
	_vuur.draw_rect(Rect2(x0 - snappedf(lang * 0.25, 2.0), y + 1, 6.0, 2), Color("#ffd23f"))


## Eén vlam: een druppel die naar links overhelt, in drie lagen. `kol` 0 staat
## vooraan op het front, verder naar rechts zijn ze lager en donkerder.
func _teken_vlam(x0: float, y: float, rij: int, kol: int, tq: float) -> void:
	var zaad := float(rij * 7 + kol * 13)
	var cx := roundf(x0 + kol * 11.0 + sin(zaad) * 3.0)
	var cy := roundf(y + (kol % 2) * 4.0)
	var hoog := (22.0 - kol * 5.0) * (0.75 + 0.25 * sin(tq * 12.0 + zaad)) + 4.0 * sin(tq * 23.0 + zaad * 1.7)
	var breed := 6.0 - kol * 0.5
	var donker := kol * 0.12
	_druppel(Vector2(cx, cy), breed, hoog, Color("#c8302c").darkened(donker))
	_druppel(Vector2(cx - 1, cy), breed * 0.64, hoog * 0.68, Color("#ff6b2b").darkened(donker))
	if kol < 2:
		_druppel(Vector2(cx - 1, cy), breed * 0.32, hoog * 0.38, Color("#ffd23f"))


func _druppel(b: Vector2, w: float, h: float, k: Color) -> void:
	var leun := roundf(h * 0.3)
	_vuur.draw_colored_polygon(PackedVector2Array([
		b + Vector2(-roundf(w), 0), b + Vector2(-roundf(w * 0.8), -roundf(h * 0.4)),
		b + Vector2(-leun, -roundf(h)), b + Vector2(roundf(w * 0.5), -roundf(h * 0.45)),
		b + Vector2(roundf(w), 0), b + Vector2(0, 2)]), k)


## Nagloeiende plekjes in het verkoolde deel, vast per plek, knipperend.
func _teken_kooltjes(van: float, tot: float, boven: float, onder: float, tq: float) -> void:
	var x := floorf(van / 12.0) * 12.0
	while x < tot:
		var y := boven
		while y < onder:
			var h := absi(int(x) * 73856093 ^ int(y) * 19349663) % 11
			if h < 3:
				var a := 0.4 + 0.4 * sin(tq * 6.0 + h + x * 0.1)
				_vuur.draw_rect(Rect2(x + h, y + h, 2, 2), Color(1.0, 0.42 + h * 0.1, 0.12, a))
			y += 12.0
		x += 12.0


# --- Oppakken -------------------------------------------------------------------------

func _werk_oppak() -> void:
	for o: Dictionary in _oppak:
		if o.has("kaart"):
			var p: Vector2 = o["p"]
			(o["kaart"] as Node2D).position = (p + Vector2(0, -7 + sin(_tijd * 4.0 + p.x * 0.1) * 1.5)).round()
		if not o["weg"] and (o["p"] as Vector2).x > _vuur_x - 4.0:
			# Verbrand. Jammer van de koffie.
			_weg(o)
		if o["weg"] or (o["p"] as Vector2).distance_to(_speler.position) > 11.0:
			continue
		_weg(o)
		if o["soort"] == "koffie":
			_boost = BOOST_DUUR
			RushOntsnapBallon.getal(_boven, o["p"] + Vector2(0, -10), "Koffie!", Color("#ffd27a"))
			AudioDirector.play_sfx(&"rush_koffie")
			if _dirk != null and _dirk.position.distance_to(_speler.position) < 160.0:
				_dirk.koffie()
		elif o["soort"] == "spoed":
			seconden = maxf(0.0, seconden - SPOED_BONUS)
			RushOntsnapBallon.getal(_boven, o["p"] + Vector2(0, -14), "SPOED! -1,5s", Color("#ffd23f"))
			RushPop.confetti(_boven, o["p"] + Vector2(0, -8), 14)
			AudioDirector.play_sfx(&"rush_ster", 0.04)
			Haptiek.tril(Haptiek.Sterkte.GELUKT)
			_schok = maxf(_schok, 1.0)
			continue
		else:
			seconden = maxf(0.0, seconden - TICKET_BONUS)
			RushOntsnapBallon.getal(_boven, o["p"] + Vector2(0, -10), "-1 s", Color("#3fd27f"))
			AudioDirector.play_sfx(&"rush_ster", 0.08)
		Haptiek.tril(Haptiek.Sterkte.TIK)


func _weg(o: Dictionary) -> void:
	o["weg"] = true
	if o.has("kaart"):
		(o["kaart"] as Node).queue_free()
		o.erase("kaart")


# --- Naar buiten ----------------------------------------------------------------------

func _buiten() -> void:
	fase = Fase.BUITEN
	_fase_t = 0.0
	_tijd_lbl.text = _tekst_tijd(seconden)
	AudioDirector.play_sfx(&"rush_deur")
	Haptiek.tril(Haptiek.Sterkte.GELUKT)
	var deur := Vector2(T, _speler.position.y)
	RushPop.confetti(_boven, deur + Vector2(4, -20), 36)
	RushPop.confetti(_boven, deur + Vector2(30, -24), 24)
	if _dirk != null and _dirk.actief():
		RushOntsnapBallon.zeg(_dirk, "Dan morgen!", 1.8)
	_toon_vrijheid()


func _naar_buiten(delta: float) -> void:
	# Door de deur, het licht in. Geen muren meer.
	_speler.position.x -= SNELHEID * 0.8 * delta
	_speler_sprite.play(&"walk_left")
	_speler_sprite.modulate.a = clampf(1.0 - _fase_t / 0.6, 0.0, 1.0)
	if _dirk != null and _dirk.actief():
		_dirk.sprite.play(&"idle_left")
	if _fase_t >= 2.0:
		_einde(false)


func _toon_vrijheid() -> void:
	# Een donkere band dwars over het beeld: de tekst moet staan, wat er ook
	# achter ligt.
	var band := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#141824", 0.88)
	sb.border_color = Color("#3fd27f")
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	band.add_theme_stylebox_override(&"panel", sb)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wortel.add_child(band)
	band.set_anchors_and_offsets_preset(Control.PRESET_HCENTER_WIDE)
	band.offset_top = -32
	band.offset_bottom = 32
	var kol := VBoxContainer.new()
	kol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kol.add_theme_constant_override(&"separation", 2)
	band.add_child(kol)
	# De 16px-snit op 32: een heel veelvoud, dus scherp.
	var titel := _lbl("VRIJHEID!", 16, Color("#3fd27f"))
	titel.add_theme_font_size_override(&"font_size", 32)
	titel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kol.add_child(titel)
	var regel := "%s s · %s" % [_tekst_tijd(seconden), _wie_had_je()]
	var sub := _lbl(regel, 10, Color("#d6dbe8"))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kol.add_child(sub)
	# Klein, een tikje te groot, dan terug: een plof.
	titel.resized.connect(func() -> void: titel.pivot_offset = titel.size / 2.0)
	titel.scale = Vector2(0.4, 0.4)
	var tw := titel.create_tween()
	tw.tween_property(titel, ^"scale", Vector2(1.15, 1.15), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(titel, ^"scale", Vector2.ONE, 0.1)


func _wie_had_je() -> String:
	if gebotst == 0:
		return "niemand had je"
	if verbrand > 0 and verbrand == gebotst:
		return "%dx door het vuur" % verbrand
	return "%dx opgehouden" % gebotst


func _einde(overgeslagen: bool) -> void:
	if fase == Fase.KLAAR:
		return
	fase = Fase.KLAAR
	if _muziek:
		AudioDirector.clear_layer(&"minigame", 0.6)
		_muziek = false
	klaar.emit(seconden, gebotst, overgeslagen)
	if not _los:
		return
	print("ONTSNAP klaar=%.1f gebotst=%d verbrand=%d dag=%d speler=%s%s" % [
		seconden, gebotst, verbrand, dag_index + 1, speler_id, " overgeslagen" if overgeslagen else ""])
	if bot:
		get_tree().quit()
		return
	# Los gespeeld zonder bot: nog een keer, dan kun je oefenen.
	await get_tree().create_timer(1.2).timeout
	get_tree().reload_current_scene()


func _tekst_tijd(s: float) -> String:
	return ("%.1f" % s).replace(".", ",")


# --- Camera en effecten ---------------------------------------------------------------

## Alleen horizontaal: de vloer is 26 tegels = 416 px en past altijd in
## hoogte. Je staat op tweederde van links, zodat je ver vooruit kijkt.
func _pas_camera(delta: float, meteen: bool) -> void:
	_vp = get_viewport().get_visible_rect().size
	var breed := float(_breed * T)
	var doel := clampf(_speler.position.x - _vp.x * _cam_anker, 0.0, maxf(0.0, breed - _vp.x))
	if breed < _vp.x:
		doel = -(_vp.x - breed) / 2.0
	_cam_x = doel if meteen else lerpf(_cam_x, doel, 1.0 - exp(-delta * 10.0))
	# Verticaal: de vloer zo onder de balk als het canvas toelaat, en op een
	# heel lang toestel in het midden. Erboven en eronder staan de wandrijen
	# van `WorldBuilder.populate()`.
	var over := _vp.y - _hoog * T
	var y := maxf(minf(BALK, maxf(0.0, over)), floorf(over / 2.0))
	_schok = maxf(0.0, _schok - delta * 8.0)
	var schud := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _schok
	_wereldlaag.offset = Vector2(-roundf(_cam_x), y) + schud


func _werk_stof(delta: float) -> void:
	if fase == Fase.REN and _stil <= 0.0 and _beweegt and _stof_timer <= 0.0:
		_stof_timer = 0.07 if _boost > 0.0 else 0.11
		_stofjes.append({"p": _speler.position + Vector2(randf_range(3, 6), randf_range(1, 4)),
			"t": 0.0, "r": randf_range(1.5, 2.5)})
	for i: int in range(_stofjes.size() - 1, -1, -1):
		_stofjes[i]["t"] = float(_stofjes[i]["t"]) + delta
		if float(_stofjes[i]["t"]) > 0.45:
			_stofjes.remove_at(i)


func _stof_wolk(p: Vector2, n: int) -> void:
	for i: int in n:
		var a := TAU * i / n
		_stofjes.append({"p": p + Vector2(cos(a) * 5.0, sin(a) * 2.0 + 2.0), "t": 0.0, "r": 3.0})


func _teken_onder() -> void:
	# Schaduwen onder iedereen, en stof achter je hakken.
	for c: RushOntsnapCollega in _collegas:
		_onder.draw_rect(Rect2(c.position + Vector2(-6, 2), Vector2(12, 3)), Color(0, 0, 0, 0.22))
	if _dirk != null and _dirk.visible:
		_onder.draw_rect(Rect2(_dirk.position + Vector2(-6, 2), Vector2(12, 3)), Color(0, 0, 0, 0.22))
		if _dirk.duikt_of_loert():
			_teken_duiklijn()
	if fase != Fase.BUITEN:
		_onder.draw_rect(Rect2(_speler.position + Vector2(-6, 2), Vector2(12, 3)), Color(0, 0, 0, 0.28))
	for s: Dictionary in _stofjes:
		var f := float(s["t"]) / 0.45
		var p: Vector2 = s["p"] + Vector2(f * 4.0, -f * 3.0)
		_onder.draw_circle(p, float(s["r"]) * (1.0 + f), Color(0.86, 0.87, 0.9, 0.55 * (1.0 - f)))
	if _boost > 0.0 and fase == Fase.REN:
		# Snelheidsstreepjes: je hebt koffie op.
		for i: int in 3:
			var y := -4.0 - i * 7.0 + sin(_tijd * 20.0 + i) * 1.0
			var x := 8.0 + fmod(_tijd * 60.0 + i * 5.0, 8.0)
			_onder.draw_line(_speler.position + Vector2(x, y), _speler.position + Vector2(x + 8, y),
				Color(1, 0.85, 0.5, 0.6), 1.0)


func _teken_boven() -> void:
	for o: Dictionary in _oppak:
		if not o["weg"]:
			_teken_oppak(o)
	if fase == Fase.REN and not bot and absf(_doel_y - _speler.position.y) > 4.0:
		_teken_stuur()
	if _stil > 0.0 and fase == Fase.REN:
		_teken_sterretjes()
	_teken_uitgang()
	if fase == Fase.BUITEN:
		_teken_licht()
	_teken_standup_bord()
	_teken_dirk_teken()
	_teken_dirk_wijzer()


func _teken_oppak(o: Dictionary) -> void:
	var p: Vector2 = o["p"]
	var bob := sin(_tijd * 4.0 + p.x * 0.1) * 1.5
	_boven.draw_rect(Rect2(p + Vector2(-4, 4), Vector2(8, 2)), Color(0, 0, 0, 0.2))
	var q := p + Vector2(0, -4 + bob)
	if o["soort"] == "spoed":
		# Het kaartje tekent zichzelf (`RushTicket`); hier alleen het deinen
		# en een gouden glans op de vloer, zodat je hem van ver ziet liggen.
		var a := 0.18 + 0.12 * sin(_tijd * 9.0)
		_boven.draw_rect(Rect2(p + Vector2(-8, 2), Vector2(16, 5)), Color(1.0, 0.82, 0.25, a))
		return
	if o["soort"] == "koffie":
		# Een bekertje met een oor en een sliertje stoom.
		_boven.draw_rect(Rect2(q + Vector2(-3, -3), Vector2(6, 7)), Color("#f4f5f7"))
		_boven.draw_rect(Rect2(q + Vector2(-3, -3), Vector2(6, 2)), Color("#6b4a2e"))
		_boven.draw_rect(Rect2(q + Vector2(-3, 0), Vector2(6, 2)), Color("#e5484d"))
		_boven.draw_arc(q + Vector2(4, 1), 2.0, -PI / 2.0, PI / 2.0, 6, Color("#f4f5f7"), 1.0)
		var f := fmod(_tijd * 1.2, 1.0)
		_boven.draw_circle(q + Vector2(0, -5 - f * 5.0), 1.2, Color(1, 1, 1, 0.6 * (1.0 - f)))
	else:
		# Een ticketkaartje, zoals op het bord.
		_boven.draw_rect(Rect2(q + Vector2(-5, -4), Vector2(10, 8)), Color("#ffd23f"))
		_boven.draw_rect(Rect2(q + Vector2(-5, -4), Vector2(10, 8)), Color("#7a5a00"), false, 1.0)
		_boven.draw_line(q + Vector2(-3, -1), q + Vector2(3, -1), Color("#7a5a00"))
		_boven.draw_line(q + Vector2(-3, 1), q + Vector2(1, 1), Color("#7a5a00"))


func _teken_stuur() -> void:
	# Waar je heen stuurt: een pijltje voor je uit op de hoogte van je duim.
	var p := Vector2(_speler.position.x - 12.0, _doel_y)
	var k := Color(1, 1, 1, 0.55)
	_boven.draw_colored_polygon(PackedVector2Array([
		p + Vector2(-4, 0), p + Vector2(1, -3), p + Vector2(1, 3)]), k)
	_boven.draw_line(Vector2(p.x + 2, p.y), Vector2(p.x + 2, _speler.position.y), Color(1, 1, 1, 0.2), 1.0)


func _teken_sterretjes() -> void:
	for i: int in 3:
		var a := _tijd * 7.0 + TAU * i / 3.0
		var p := _speler.position + Vector2(cos(a) * 7.0, -34.0 + sin(a) * 2.0)
		_boven.draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), Color("#ffd23f"))


func _teken_licht() -> void:
	# Daglicht dat door de open voordeur naar binnen valt.
	var a := clampf(_fase_t * 2.0, 0.0, 1.0)
	var top := 15.0 * T
	var hoog := 3.0 * T
	_boven.draw_colored_polygon(PackedVector2Array([
		Vector2(0, top), Vector2(T, top), Vector2(T * 4.0, top + hoog + 10.0), Vector2(0, top + hoog)]),
		Color(1.0, 0.95, 0.7, 0.35 * a))
	_boven.draw_rect(Rect2(0, top, T, hoog), Color(1.0, 0.98, 0.85, 0.85 * a))


## Een groen nooduitgangbordje boven de voordeur en knipperende pijltjes bij
## de deur naar de entree: in de echte plattegrond zijn die twee gaten
## bescheiden, en je moet ze in volle ren kunnen vinden.
func _teken_uitgang() -> void:
	var voordeur := Rect2(0, 15.0 * T, T, 3.0 * T)
	var puls := 0.5 + 0.5 * sin(_tijd * 6.0)
	_boven.draw_rect(voordeur, Color(0.55, 1.0, 0.6, 0.12 + 0.16 * puls))
	var bord := Rect2(2, 15.0 * T - 13.0, 28, 10)
	_boven.draw_rect(bord, Color("#1d7a52"))
	_boven.draw_rect(bord, Color("#0e3d29"), false, 1.0)
	_boven.draw_string(UiKit.FONT_10, bord.position + Vector2(11, 8), "UIT",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
	_boven.draw_colored_polygon(PackedVector2Array([bord.position + Vector2(3, 5),
		bord.position + Vector2(8, 2), bord.position + Vector2(8, 8)]), Color.WHITE)
	_pijltjes(Vector2(T * 1.5 + 6.0, 16.5 * T), puls)
	_pijltjes(Vector2(T * 10.0 + 6.0, 20.0 * T), puls)


func _pijltjes(p: Vector2, puls: float) -> void:
	if p.x > _vuur_x - 20.0:
		return
	for i: int in 2:
		var q := p + Vector2(i * 6.0 - puls * 3.0, 0)
		var k := Color(0.6, 1.0, 0.65, 0.35 + 0.4 * (1.0 - i * 0.5))
		_boven.draw_colored_polygon(PackedVector2Array([
			q + Vector2(0, 0), q + Vector2(4, -4), q + Vector2(4, 4)]), k)


## Staat Dirk buiten beeld, dan een rood labeltje aan de rand: je voelt hem
## aankomen voordat je hem ziet. Rechts als hij je achternazit, links als
## hij je van voren tegemoetkomt.
func _teken_dirk_wijzer() -> void:
	if _dirk == null or not _dirk.actief() or fase != Fase.REN:
		return
	var rand := _cam_x + _vp.x
	var links := _cam_x
	var y := clampf(_dirk.position.y - 22.0, T * 2.0, (_hoog - 2) * T)
	if _dirk.position.x > rand - 4.0 and _dirk.position.x < rand + 200.0:
		var dichtbij := clampf(1.0 - (_dirk.position.x - rand) / 160.0, 0.3, 1.0)
		var puls := 0.75 + 0.25 * sin(_tijd * 10.0) if dichtbij > 0.7 else 1.0
		var r := Rect2(rand - 30.0, y - 6.0, 28.0, 12.0)
		var k := Color("#e5484d", dichtbij * puls)
		_boven.draw_rect(r, k)
		_boven.draw_colored_polygon(PackedVector2Array([
			Vector2(rand - 2.0, y - 5.0), Vector2(rand + 2.0, y), Vector2(rand - 2.0, y + 5.0)]), k)
		_boven.draw_string(UiKit.FONT_10, Vector2(r.position.x + 4.0, y + 4.0), "DIRK",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, dichtbij))
	elif _dirk.position.x < links + 4.0 and _dirk.position.x > links - 200.0:
		var puls := 0.75 + 0.25 * sin(_tijd * 10.0)
		var r := Rect2(links + 2.0, y - 6.0, 28.0, 12.0)
		var k := Color("#e5484d", puls)
		_boven.draw_rect(r, k)
		_boven.draw_colored_polygon(PackedVector2Array([
			Vector2(links + 2.0, y - 5.0), Vector2(links - 2.0, y), Vector2(links + 2.0, y + 5.0)]), k)
		_boven.draw_string(UiKit.FONT_10, Vector2(r.position.x + 4.0, y + 4.0), "DIRK",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)


## In beeld: een rood naamkaartje boven zijn hoofd, de eerste seconden en
## telkens als hij gaat duiken. Niet iedereen kent Dirk van gezicht, en
## vandaag moet je weten wie er achter je zit.
func _teken_dirk_teken() -> void:
	if _dirk == null or not _dirk.actief() or fase != Fase.REN:
		return
	var p := _dirk.position + Vector2(0, -38)
	if _dirk.staat == RushOntsnapDirk.Staat.LOERT or _dirk.staat == RushOntsnapDirk.Staat.DUIKT:
		# Een uitroepteken dat trilt.
		var s := roundf(sin(_tijd * 40.0))
		var k := Color("#e5484d")
		_boven.draw_rect(Rect2(p + Vector2(-2 + s, -8), Vector2(4, 8)), k)
		_boven.draw_rect(Rect2(p + Vector2(-2 + s, 2), Vector2(4, 3)), k)
		_boven.draw_rect(Rect2(p + Vector2(-1 + s, -7), Vector2(2, 6)), Color.WHITE)
		_boven.draw_rect(Rect2(p + Vector2(-1 + s, 3), Vector2(2, 1)), Color.WHITE)
		return
	if _dirk.sinds > 3.5:
		return
	var b := UiKit.FONT_10.get_string_size("DIRK", HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	var r := Rect2(p.x - b / 2.0 - 3.0, p.y - 4.0, b + 6.0, 11.0)
	_boven.draw_rect(r, Color("#e5484d"))
	_boven.draw_string(UiKit.FONT_10, Vector2(r.position.x + 3.0, p.y + 5.0), "DIRK",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)


## De rode streep van een duik: door de rij waar hij doorheen gaat, met
## pijltjes naar links. Eerst flauw, dan steeds feller tot hij gaat.
func _teken_duiklijn() -> void:
	var y := roundf(_dirk.lijn_y)
	var x1 := _dirk.position.x - 6.0
	var x0 := x1 - 150.0
	var f := 1.0 if _dirk.staat == RushOntsnapDirk.Staat.DUIKT else _dirk.loer
	var puls := 0.7 + 0.3 * sin(_tijd * lerpf(12.0, 30.0, f))
	_onder.draw_rect(Rect2(x0, y - 5.0, x1 - x0, 10.0), Color(0.9, 0.15, 0.15, (0.12 + 0.2 * f) * puls))
	_onder.draw_rect(Rect2(x0, y - 1.0, x1 - x0, 2.0), Color(1.0, 0.3, 0.3, (0.35 + 0.4 * f) * puls))
	var schuif := fmod(_tijd * 60.0, 12.0)
	var x := x1 - schuif
	while x > x0 + 4.0:
		_onder.draw_colored_polygon(PackedVector2Array([
			Vector2(x - 4.0, y), Vector2(x, y - 3.0), Vector2(x, y + 3.0)]), Color(1, 0.85, 0.85, 0.6 * f * puls))
		x -= 12.0


## Een bordje boven de stand-up, zodat je in één oogopslag ziet wat die rij
## mensen daar doet.
func _teken_standup_bord() -> void:
	if _standup == null or not _standup.actief or fase != Fase.REN:
		return
	var sl := _standup.slots()
	if sl.is_empty():
		return
	var tekst := "STAND-UP"
	var b := UiKit.FONT_10.get_string_size(tekst, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	var p := Vector2(roundf(_standup.x), roundf(sl[0] - 44.0))
	var r := Rect2(p.x - b / 2.0 - 3.0, p.y - 5.0, b + 6.0, 11.0)
	_boven.draw_rect(Rect2(r.position + Vector2(1, 1), r.size), Color(0, 0, 0, 0.3))
	_boven.draw_rect(r, Color("#3a86ff"))
	_boven.draw_string(UiKit.FONT_10, Vector2(r.position.x + 3.0, p.y + 4.0), tekst,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)


## De voortgangsbalk loopt van rechts naar links, net als jij: de deur zit
## links. Dirk is het rode stipje dat achter je aan komt.
func _teken_balk() -> void:
	var w := _balk.size.x
	var h := _balk.size.y
	_balk.draw_rect(Rect2(0, 2, w, h - 4), Color("#2a3042"))
	var f := _voortgang(_speler.position.x)
	var x := w - f * (w - 6.0)
	_balk.draw_rect(Rect2(x, 2, w - x, h - 4), Color("#3fd27f"))
	if _vuur_actief:
		# Wat achter je in brand staat, vreet de balk op.
		var vx := clampf(w - _voortgang(_vuur_x) * (w - 6.0), x, w)
		_balk.draw_rect(Rect2(vx, 2, w - vx, h - 4), Color("#ff6b2b"))
		_balk.draw_rect(Rect2(vx, 1, 2, h - 2), Color("#ffd23f"))
	# De deur.
	_balk.draw_rect(Rect2(0, 0, 5, h), Color("#bfe3a8"))
	_balk.draw_rect(Rect2(0, 0, 5, h), Color("#1d7a52"), false, 1.0)
	if _dirk != null and _dirk.actief():
		var dx := w - _voortgang(_dirk.position.x) * (w - 6.0)
		_balk.draw_rect(Rect2(dx - 1.5, 1, 3, h - 2), Color("#e5484d"))
	_balk.draw_rect(Rect2(x - 2, 0, 4, h), Color.WHITE)


func _voortgang(px: float) -> float:
	return clampf((_start_x - px) / maxf(1.0, _start_x - _uit_x), 0.0, 1.0)


# --- Bot: stuurt zelf, voor tests ----------------------------------------------------

## Zoekt een paar keer per seconde de kortste weg naar de deur om alles heen
## wat hem kan ophouden, en stuurt naar de rij waar de volgende stap naar
## links begint. Het vangnet (`_hulp`) gebruikt hem ook: wie vastzit, wordt
## even net zo slim gestuurd.
func _bot_stuur(delta: float) -> void:
	_bot_klok -= delta
	var hier := _tegel(_speler.position)
	if _bot_klok <= 0.0 or _bot_pad.is_empty():
		_bot_klok = 0.15
		_bot_pad = _bot_route(hier)
	if _bot_pad.is_empty():
		return
	var rij := _bot_pad[0].y
	for i: int in range(1, _bot_pad.size()):
		if _bot_pad[i].x < _bot_pad[i - 1].x:
			rij = _bot_pad[i - 1].y
			break
	_doel_y = _midden(Vector2i(hier.x, rij)).y
	_bot_standup_fijn()


## De weg om alles heen. Lukt dat niet, dan steeds minder kieskeurig: eerst
## zonder vooruit te kijken naar de stand-up, dan dwars door iedereen heen.
## Ligt er een spoedticket vlak bij de weg, en kost het weinig, dan erlangs.
func _bot_route(hier: Vector2i) -> Array[Vector2i]:
	var mijd := _bot_mijd(hier, true)
	var pad := _zoek_pad(hier, mijd)
	if pad.is_empty():
		mijd = _bot_mijd(hier, false)
		pad = _zoek_pad(hier, mijd)
	if pad.is_empty():
		return _zoek_pad(hier, {})
	# Het vuur te dichtbij: geen omwegen.
	if _vuur_actief and _vuur_x - _speler.position.x < 40.0:
		return pad
	var beste := pad
	for o: Dictionary in _oppak:
		if o["weg"] or o["soort"] != "spoed":
			continue
		var t := _tegel(o["p"])
		if t.x > hier.x or hier.x - t.x > 9 or not _spoed_veilig(o["p"]):
			continue
		# De marge rond collega's is voor het uitwijken; een kaartje vlak
		# naast iemand mag hij wel pakken, als hij er maar niet tegenaan loopt.
		var m2 := mijd.duplicate()
		m2.erase(t)
		var heen := _zoek_pad(hier, m2, t)
		if heen.is_empty():
			continue
		var verder := _zoek_pad(t, mijd)
		if verder.is_empty():
			continue
		heen.pop_back()
		heen.append_array(verder)
		if heen.size() <= pad.size() + 6 and (beste == pad or heen.size() < beste.size()):
			beste = heen
	return beste


## Staat er al een collega binnen `r` px? Dan zet je daar niemand anders
## neer: twee mensen op één plek, met twee ballonnen door elkaar, leest niemand.
func _iemand_bij(p: Vector2, r: float) -> bool:
	for c: RushOntsnapCollega in _collegas:
		if not c.gesproken and c.position.distance_to(p) < r:
			return true
	return false


## Kun je hier staan zonder dat iemand je heeft?
func _spoed_veilig(p: Vector2) -> bool:
	for c: RushOntsnapCollega in _collegas:
		if c.gesproken:
			continue
		if absf(c.position.x - p.x) < c.half.x + HALF.x + 3.0 \
				and absf(minf(absf(c.position.y - p.y), absf(c.straks_y() - p.y))) < c.half.y + HALF.y + 3.0:
			return false
	return true


## Tegels waar de bot liever niet komt: rond collega's die nog iets willen
## (plus een kolom ervoor, zodat hij op tijd uitwijkt), de stand-up zoals
## die er staat als hij er aankomt, de rij waar Dirk doorheen gaat duiken, en
## de schaduw van een vallende plaat.
func _bot_mijd(hier: Vector2i, vooruit: bool) -> Dictionary:
	var mijd := {}
	for c: RushOntsnapCollega in _collegas:
		if c.gesproken or c.gedrag == RushOntsnapCollega.Gedrag.KRING:
			continue
		var y0 := minf(c.position.y, c.straks_y()) - HALF.y * 2.0
		var y1 := maxf(c.position.y, c.straks_y()) + HALF.y * 2.0
		var x0 := c.position.x - HALF.x * 2.0
		var x1 := c.position.x + HALF.x * 2.0 + T
		_mijd_vak(mijd, hier, x0, x1, y0, y1)
	if _standup != null and _standup.actief and _speler.position.x > _standup.x - 2.0 * HALF.x - 2.0:
		var sx := _standup.x
		var t0 := 0.0
		var t1 := 0.0
		var vries := 0.0
		if vooruit:
			var v := _bot_standup_tijden()
			vries = v.x
			t0 = v.y
			t1 = v.z
			sx = v.w
		# De kolommen waar je de muur raakt: midden van de tegel binnen 16 px
		# van de muur, en rechts wat ruimer, want het midden van de kring
		# staat een stapje naar voren.
		var kx0 := floori((sx - 16.0 - T / 2.0) / T) + 1
		var kx1 := ceili((sx + 22.0 - T / 2.0) / T) - 1
		for ty: int in _hoog:
			if _standup.ruimte(_midden(Vector2i(0, ty)).y, t0, t1, vries) >= RushOntsnapStandup.HALF.y + HALF.y + 1.0:
				continue
			for tx: int in range(kx0, kx1 + 1):
				var t := Vector2i(tx, ty)
				if t != hier:
					mijd[t] = true
	if _dirk != null and _dirk.actief():
		if _dirk.duikt_of_loert():
			var y := _dirk.lijn_y
			_mijd_vak(mijd, hier, _speler.position.x - 70.0, _dirk.position.x, y - 13.0, y + 13.0)
		elif _dirk.staat == RushOntsnapDirk.Staat.TEGEMOET:
			var p := _dirk.position
			_mijd_vak(mijd, hier, p.x - 3.0 * HALF.x, p.x + 2.0 * HALF.x + T, p.y - 22.0, p.y + 22.0)
	if _plafond != null:
		for p: Vector2 in _plafond.dreigend():
			_mijd_vak(mijd, hier, p.x - T, p.x + T, p.y - 2.0, p.y + 2.0)
	return mijd


func _mijd_vak(mijd: Dictionary, hier: Vector2i, x0: float, x1: float, y0: float, y1: float) -> void:
	for ty: int in range(floori(y0 / T), floori(y1 / T) + 1):
		for tx: int in range(floori(x0 / T), floori(x1 / T) + 1):
			var t := Vector2i(tx, ty)
			if t != hier:
				mijd[t] = true


## Wanneer de stand-up stilvalt, wanneer je hem raakt en weer voorbij bent,
## en waar hij dan staat: (stil, raak, voorbij, x).
func _bot_standup_tijden() -> Vector4:
	var v := _standup.vooruit(_speler.position.x, SNELHEID)
	var t0 := maxf(0.0, (_speler.position.x - v.y - 2.0 * HALF.x) / SNELHEID)
	var t1 := t0 + (4.0 * HALF.x + 4.0) / SNELHEID + 0.12
	return Vector4(v.x, t0, t1, v.y)


## Vlak voor de stand-up: niet het midden van de tegel, maar precies de
## hoogte waar het verst van iedereen af blijft als je erdoor gaat. Binnen
## de rij die de route koos, en alleen waar je ook echt tot voorbij de muur
## kunt lopen.
func _bot_standup_fijn() -> void:
	if _standup == null or not _standup.actief:
		return
	var dx := _speler.position.x - _standup.x
	if dx < 0.0 or dx > 56.0:
		return
	var v := _bot_standup_tijden()
	var vries := v.x
	var t0 := v.y
	var t1 := v.z
	var rij := floorf(_doel_y / T) * T
	var beste := _doel_y
	var ruim := _standup.ruimte(beste, t0, t1, vries)
	var y := rij + HALF.y
	while y <= rij + T - HALF.y:
		var r := _standup.ruimte(y, t0, t1, vries)
		if r > ruim + 0.5 and _vrij(Vector2(_standup.x - 2.0 * HALF.x, y)) \
				and _vrij(Vector2(_standup.x + 2.0 * HALF.x, y)):
			ruim = r
			beste = y
		y += 2.0
	_doel_y = beste
