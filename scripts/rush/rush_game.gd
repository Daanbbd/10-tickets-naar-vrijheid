class_name RushGame
extends Node2D
## De kantoor-rush: één dag van de sprint.
##
## Tickets komen binnen op het bord. Jij tikt ze aan, brengt ze naar de collega
## van het juiste vak, haalt ze op als ze klaar zijn en zet ze live op de
## server. Tien live en je mag naar huis. Laat je er een te lang liggen, dan
## belt De Klant, en dat kost je twintig minuten.
##
## Alles loopt via tikken: tik iets aan en je loopt erheen en doet wat daar te
## doen valt. Tikken stapelt, tot vier acties vooruit.

enum Fase { INTRO, SPEL, KLAAR }
enum Dirk { WEG, KOMT, PRAAT, GAAT }

const WACHTRIJ_MAX := 4
const DIRK_SNELHEID := 30.0
const KLETS_DUUR := 14.0

var dag_index := 0
var dag: Dictionary = {}
var speler_id: StringName = &"daan"
var fase := Fase.INTRO

var veld: Node2D
var kantoor: RushKantoor
var mensen: Node2D
var kaartjes: Node2D
var markers: Node2D
var tint: CanvasModulate
var speler: RushPlayer
var werkers: Array[RushWorker] = []
var hud: RushHud

var bord: Array = []
var tickets: Array[RushTicket] = []
var wachtrij: Array[Dictionary] = []
var huidige: Dictionary = {}
var grid: AStarGrid2D

var minuut: float = RushData.START_MIN
var gespawnd := 0
var geleverd := 0
var gebeld := 0
var nummer := 214
var _spawn_timer := 1.0
var _recent_vakken: Array[int] = []
var _recent_titels: Array[String] = []

var _na_bezig: Callable = Callable()
var _koffie_cd := 0.0
var _klets_timer := 0.0
var _klets_rest := 0.0
var _klets_ballon := 0.0
var _prater: RushWorker = null
var _dirk_timer := 0.0
var _dirk_staat := Dirk.WEG
var _dirk: AnimatedSprite2D = null
var _dirk_pad := PackedVector2Array()
var _dirk_herbereken := 0.0
var _brand_timer := 0.0
var _schok := 0.0
var _rimpels: Array[Dictionary] = []
var _tijd := 0.0
var _tutorial := false
var _laatste_hint := ""
## Deploys achter elkaar zonder dat ze belt. Elke deploy klinkt een tikje hoger.
var _reeks := 0

## De dag ligt vast: iedereen krijgt dezelfde tickets op dezelfde momenten,
## zodat scores in de eregalerij eerlijk te vergelijken zijn. Alleen wat er
## in tekstballonnen gezegd wordt blijft echt toevallig.
var _rng := RandomNumberGenerator.new()

var bot := false
## QA: de bot speelt, maar het spel stopt niet aan het eind (voor schoten).
var bot_blijf := false
## QA: de bot tikt via echte invoergebeurtenissen.
var bot_echt := false


func _ready() -> void:
	RushSave.laad()
	dag_index = clampi(RushSave.dag, 0, RushData.DAGEN.size() - 1)
	dag = RushData.DAGEN[dag_index]
	speler_id = RushSave.karakter if RushSave.karakter != &"" else &"daan"
	_tutorial = dag_index == 0
	_lees_qa_vlaggen()
	_rng.seed = hash("sprint14-dag%d" % dag_index)

	_bouw()
	_pas_layout()
	get_viewport().size_changed.connect(_pas_layout)

	_klets_timer = _rng.randf_range(14.0, 20.0)
	_dirk_timer = _rng.randf_range(12.0, 18.0)
	_brand_timer = _rng.randf_range(16.0, 24.0)

	AudioDirector.stop_music(0.4)
	RushKlank.muziek(StringName(dag["track"]), StringName(dag["muziek"]), 0.8)
	hud.zet(dag["kort"], 0, minuut)
	if bot:
		_begin()
	else:
		hud.toon_intro(dag_index, dag, speler_id)
		hud.start.connect(_begin, CONNECT_ONE_SHOT)


func _lees_qa_vlaggen() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a == "--rush-bot":
			bot = true
		elif a == "--blijf":
			bot_blijf = true
		elif a == "--echt":
			bot_echt = true
		elif a.begins_with("--dag="):
			dag_index = clampi(int(a.get_slice("=", 1)) - 1, 0, 4)
			dag = RushData.DAGEN[dag_index]
			_tutorial = dag_index == 0
		elif a.begins_with("--speler="):
			speler_id = StringName(a.get_slice("=", 1))
		elif a.begins_with("--tempo="):
			Engine.time_scale = float(a.get_slice("=", 1))


func _begin() -> void:
	fase = Fase.SPEL
	hud.mag_pauzeren = true
	_spawn_timer = 0.6
	if _tutorial:
		hud.hint_vast("Er komt een ticket binnen...")


# --- Opbouw -------------------------------------------------------------------

func _bouw() -> void:
	tint = CanvasModulate.new()
	add_child(tint)

	veld = Node2D.new()
	add_child(veld)
	kantoor = RushKantoor.new()
	veld.add_child(kantoor)

	mensen = Node2D.new()
	mensen.y_sort_enabled = true
	veld.add_child(mensen)

	var sloten := 0
	for i: int in RushData.BUREAU_VOLGORDE.size():
		var id: StringName = RushData.BUREAU_VOLGORDE[i]
		var w := RushWorker.new()
		w.position = RushKantoor.BUREAUS[i]
		mensen.add_child(w)
		w.setup(id, id == speler_id)
		w.actief = w.vak in dag["vakken"]
		w.klaar.connect(_op_werker_klaar)
		werkers.append(w)
		sloten += 1

	speler = RushPlayer.new()
	speler.position = Vector2(96, 290)
	mensen.add_child(speler)
	speler.setup(speler_id)
	speler.aangekomen.connect(_aankomst)

	kaartjes = Node2D.new()
	kaartjes.z_index = 40
	veld.add_child(kaartjes)

	markers = Node2D.new()
	markers.z_index = 45
	markers.draw.connect(_teken_markers)
	veld.add_child(markers)

	bord.resize(RushKantoor.BORD_SLOTS)
	bord.fill(null)

	_bouw_grid()

	hud = RushHud.new()
	add_child(hud)
	hud.opnieuw.connect(_opnieuw)
	hud.volgende.connect(_volgende)
	hud.naar_menu.connect(_naar_menu)


func _bouw_grid() -> void:
	grid = AStarGrid2D.new()
	grid.region = Rect2i(0, 0, RushKantoor.KOLOMMEN, RushKantoor.RIJEN)
	grid.cell_size = Vector2(RushKantoor.T, RushKantoor.T)
	grid.offset = Vector2(RushKantoor.T / 2.0, RushKantoor.T / 2.0)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	for y: int in RushKantoor.RIJEN:
		for x: int in RushKantoor.KOLOMMEN:
			if y < RushKantoor.VLOER_BOVEN or y > RushKantoor.VLOER_ONDER:
				grid.set_point_solid(Vector2i(x, y))
	for r: Rect2i in kantoor.blokkades():
		grid.fill_solid_region(r)


func _pas_layout() -> void:
	var vp := get_viewport_rect().size
	var vrij := vp.y - RushHud.BOVEN - RushHud.ONDER - RushKantoor.HOOG
	# Te laag scherm: dan schuift de bovenwand onder de balk, de vloer blijft heel.
	var y := RushHud.BOVEN + (floorf(vrij / 2.0) if vrij >= 0.0 else vrij)
	veld.position = Vector2(floorf((vp.x - RushKantoor.BREED) / 2.0), y)


# --- Invoer -------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if fase != Fase.SPEL or (bot and not bot_echt):
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		# De positie van de gebeurtenis zelf, niet die van de cursor: bij een
		# tik is er geen cursor, en een geparste gebeurtenis verplaatst hem niet.
		_tik(veld.get_global_transform_with_canvas().affine_inverse() * mb.position)
		get_viewport().set_input_as_handled()


func _tik(p: Vector2) -> void:
	_rimpels.append({"p": p, "t": 0.0})

	# Dirk tik je weg; daar loop je niet heen.
	if _dirk_staat == Dirk.KOMT and _dirk != null:
		if Rect2(_dirk.position + Vector2(-12, -38), Vector2(24, 44)).has_point(p):
			_stuur_dirk_weg()
			return

	for i: int in bord.size():
		var t: RushTicket = bord[i]
		if t != null and Rect2(kantoor.slot_positie(i) - Vector2(10, 11), Vector2(20, 24)).has_point(p):
			_plan({"soort": "bord", "slot": i, "ticket": t, "punt": kantoor.slot_benader(i)})
			return

	for w: RushWorker in werkers:
		if w.hit(p):
			_plan({"soort": "werker", "werker": w, "punt": w.benader_punt()})
			return

	if RushKantoor.SERVER_RECT.grow(6).has_point(p):
		_plan({"soort": "server", "punt": kantoor.server_benader()})
		return
	if bool(dag["koffie"]) and RushKantoor.KOFFIE_RECT.grow(4).has_point(p):
		_plan({"soort": "koffie", "punt": kantoor.koffie_benader()})
		return

	var tegel := Vector2i(floori(p.x / RushKantoor.T), floori(p.y / RushKantoor.T))
	if grid.is_in_boundsv(tegel) and not grid.is_point_solid(tegel):
		# Lopen zonder doel vervangt de wachtrij: je wil gewoon dáár staan.
		wachtrij.clear()
		huidige = {}
		_plan({"soort": "loop", "punt": grid.get_point_position(tegel)})


func _plan(actie: Dictionary) -> void:
	RushKlank.sfx(&"rush_tik", &"klik", 0.1, -8.0)
	Haptiek.tril(Haptiek.Sterkte.TIK)
	if wachtrij.size() >= WACHTRIJ_MAX:
		wachtrij.pop_back()
	wachtrij.append(actie)
	_volgende_actie()


func _volgende_actie() -> void:
	if fase == Fase.INTRO or not huidige.is_empty() or speler.bezig > 0.0:
		return
	while not wachtrij.is_empty():
		huidige = wachtrij.pop_front()
		var punt: Vector2 = huidige["punt"]
		var pad := _pad_naar(punt)
		if pad.is_empty():
			huidige = {}
			continue
		speler.pad = pad
		return


func _pad_naar(punt: Vector2) -> PackedVector2Array:
	var van := _tegel_van(speler.position)
	var naar := _tegel_van(punt)
	if van == naar:
		return PackedVector2Array([punt])
	var ids := grid.get_point_path(van, naar)
	if ids.is_empty():
		return PackedVector2Array()
	var uit := PackedVector2Array()
	for i: int in range(1, ids.size() - 1):
		uit.append(ids[i])
	uit.append(punt)
	return uit


func _tegel_van(p: Vector2) -> Vector2i:
	var t := Vector2i(floori(p.x / RushKantoor.T), floori(p.y / RushKantoor.T))
	t.x = clampi(t.x, 0, RushKantoor.KOLOMMEN - 1)
	t.y = clampi(t.y, RushKantoor.VLOER_BOVEN, RushKantoor.VLOER_ONDER)
	if grid.is_point_solid(t):
		# Kan alleen als je net naast een blokkade staat; zoek de dichtste vrije.
		for d: Vector2i in [Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT,
				Vector2i(1, 1), Vector2i(-1, 1)]:
			if grid.is_in_boundsv(t + d) and not grid.is_point_solid(t + d):
				return t + d
	return t


# --- Aankomen en doen ---------------------------------------------------------

func _aankomst() -> void:
	if huidige.is_empty():
		return
	var a := huidige
	huidige = {}
	match String(a["soort"]):
		"bord": _pak_van_bord(int(a["slot"]), a["ticket"])
		"werker": _bij_werker(a["werker"])
		"server": _bij_server()
		"koffie": _bij_koffie()
	_volgende_actie()


func _pak_van_bord(slot: int, t: RushTicket) -> void:
	speler.kijk(&"up")
	if bord[slot] != t:
		return
	if not speler.vrije_hand():
		_ballon_speler("Handen vol!")
		RushKlank.sfx(&"rush_fout", &"fout", 0.05, -6.0)
		return
	bord[slot] = null
	t.staat = RushTicket.Staat.HAND
	t.scale = Vector2(1.5, 1.5)
	speler.handen.append(t)
	RushKlank.sfx(&"rush_pak", &"pak")
	Haptiek.tril(Haptiek.Sterkte.STOOT)
	hud.meld("%s · %s" % [t.code(), t.titel], 2.6)


func _bij_werker(w: RushWorker) -> void:
	speler.kijk(&"up")
	if w == _prater:
		_kap_af()

	var open := _in_hand(w.vak, false)
	if w.is_eigen:
		if open != null:
			_zelf_doen(open)
		elif not speler.handen.is_empty():
			_ballon_speler("Dit is niet mijn vak.")
		return

	if w.ticket != null and w.is_klaar:
		if speler.vrije_hand() or open != null:
			var klaar_t := w.neem()
			if open != null:
				_geef(w, open)
			speler.handen.append(klaar_t)
			klaar_t.staat = RushTicket.Staat.KLAAR
			klaar_t.scale = Vector2(1.5, 1.5)
			RushKlank.sfx(&"rush_pak", &"pak")
			Haptiek.tril(Haptiek.Sterkte.STOOT)
		else:
			_ballon_speler("Handen vol!")
			RushKlank.sfx(&"rush_fout", &"fout", 0.05, -6.0)
	elif w.ticket != null:
		RushPop.ballon_op(veld, w.hoofd(), "Ik ben al bezig!", 1.3)
	elif open != null:
		_geef(w, open)
	elif not speler.handen.is_empty():
		var k := _eerste_open()
		if k != null:
			RushPop.ballon_op(veld, w.hoofd(), "Ik doe %s, geen %s." % [
				RushData.VAK_NAAM[w.vak], RushData.VAK_NAAM[k.vak]], 1.8)
			RushKlank.sfx(&"rush_fout", &"fout", 0.05, -4.0)
			Haptiek.tril(Haptiek.Sterkte.SLAG)
	else:
		RushPop.ballon_op(veld, w.hoofd(), "Niks voor mij?", 1.2)


func _geef(w: RushWorker, t: RushTicket) -> void:
	speler.handen.erase(t)
	w.geef(t)
	RushKlank.sfx(&"rush_geef", &"interactie", 0.08)
	Haptiek.tril(Haptiek.Sterkte.STOOT)
	if randf() < 0.45 and RushData.ONTVANG.has(w.persoon):
		RushPop.ballon_op(veld, w.hoofd(), RushData.kies(RushData.ONTVANG[w.persoon]), 1.6)


func _zelf_doen(t: RushTicket) -> void:
	var kleur: Color = RushData.VAK_KLEUR[t.vak]
	speler.start_bezig(RushData.ZELF_WERKTIJD, kleur.lightened(0.25))
	t.staat = RushTicket.Staat.WERK
	RushKlank.sfx(&"rush_geef", &"interactie", 0.08)
	_na_bezig = func() -> void:
		t.staat = RushTicket.Staat.KLAAR
		t.geduld = maxf(t.geduld, 0.6)
		RushKlank.sfx(&"rush_klaar", &"ticket_klaar")
		_ballon_speler("Zelf gedaan.")


func _bij_server() -> void:
	speler.kijk(&"up")
	if kantoor.brand:
		speler.start_bezig(1.1, Color("#ffd23f"))
		RushKlank.sfx(&"rush_blus", &"genereren", 0.05)
		_ballon_speler("Blussen!")
		_na_bezig = func() -> void:
			kantoor.brand = false
			_brand_timer = _rng.randf_range(20.0, 30.0)
			hud.meld("Brand geblust. Deployen maar.")
			_deploy()
		return
	_deploy()


func _deploy() -> void:
	var klaar_t: Array[RushTicket] = []
	for t: RushTicket in speler.handen:
		if t.staat == RushTicket.Staat.KLAAR:
			klaar_t.append(t)
	if klaar_t.is_empty():
		if speler.handen.is_empty():
			_ballon_speler("Niks om live te zetten.")
		else:
			_ballon_speler("Eerst laten maken!")
			RushKlank.sfx(&"rush_fout", &"fout", 0.05, -6.0)
		return
	for t: RushTicket in klaar_t:
		speler.handen.erase(t)
		t.staat = RushTicket.Staat.LIVE
		geleverd += 1
	kantoor.flits_server()
	_reeks += klaar_t.size()
	RushKlank.toon(&"rush_deploy", &"deploy_ok", 1.0 + minf(_reeks - 1, 8) * 0.06)
	if _reeks >= 3:
		RushPop.getal_op(veld, speler.position + Vector2(0, -52), "Reeks %d!" % _reeks, Color("#8fd3ff"))
	Haptiek.tril(Haptiek.Sterkte.GELUKT)
	var srv := RushKantoor.SERVER_RECT.get_center()
	RushPop.confetti(veld, srv + Vector2(0, -20), 14 + 8 * klaar_t.size())
	RushPop.getal_op(veld, srv + Vector2(0, -44), "+%d live" % klaar_t.size(), Color("#3fd27f"))
	if klaar_t.size() >= 2:
		minuut = maxf(RushData.START_MIN, minuut - 10.0)
		hud.klok_puls()
		RushPop.getal_op(veld, srv + Vector2(-30, -60), "Dubbel! -10 min", Color("#ffd23f"))
		RushKlank.sfx(&"rush_dubbel", &"", 0.0, -2.0)
	_schok = maxf(_schok, 1.5)
	hud.zet(dag["kort"], geleverd, minuut)
	if geleverd >= RushData.DOEL:
		_dag_klaar()
	elif geleverd == RushData.DOEL - 1:
		hud.meld("Nog één! Dan mag je naar huis.", 2.5)


func _bij_koffie() -> void:
	speler.kijk(&"up")
	if _koffie_cd > 0.0:
		_ballon_speler("Hij loopt nog door...")
		return
	speler.start_bezig(0.6, Color("#c08552"))
	RushKlank.sfx(&"rush_koffie", &"koffie")
	_na_bezig = func() -> void:
		speler.boost = 9.0
		_koffie_cd = 22.0
		kantoor.koffie_klaar = false
		_ballon_speler("Koffie!")


# --- De dag ------------------------------------------------------------------

func _process(delta: float) -> void:
	_tijd += delta
	_beweeg_kaartjes(delta)
	_werk_rimpels(delta)
	_werk_schok(delta)
	tint.color = _daglicht(minuut)
	markers.queue_redraw()
	if _dirk != null:
		_werk_dirk(delta)
	if fase != Fase.SPEL:
		if fase == Fase.KLAAR:
			speler.tik(delta)
		return

	var was := minuut
	minuut += float(dag["minuten_per_sec"]) * delta
	if was < RushData.EIND_MIN and minuut >= RushData.EIND_MIN:
		hud.meld("17:00. Iedereen gaat naar huis. Behalve jij.", 3.5)
		RushKlank.sfx(&"rush_vijf", &"deur", 0.0)
		hud.klok_puls()
	speler.tik(delta)
	if speler.bezig <= 0.0 and _na_bezig.is_valid():
		var na := _na_bezig
		_na_bezig = Callable()
		na.call()
	if speler.bezig <= 0.0 and not speler.loopt():
		if bot:
			_bot_kies()
		_volgende_actie()

	var werktijd := RushData.WERKTIJD
	var heeft_klaar := false
	for h: RushTicket in speler.handen:
		if h.staat == RushTicket.Staat.KLAAR:
			heeft_klaar = true
	kantoor.server_gloed = heeft_klaar
	for w: RushWorker in werkers:
		w.gloed = (w.vrij() or w.is_eigen or w.is_klaar) and _in_hand(w.vak, false) != null
		w.tik(delta, werktijd)

	_werk_spawn(delta)
	_werk_geduld(delta)
	_werk_koffie(delta)
	_werk_kletsen(delta)
	_werk_dirk_timer(delta)
	_werk_brand(delta)
	if _tutorial:
		_werk_tutorial()
	hud.zet(dag["kort"], geleverd, minuut)


func _werk_spawn(delta: float) -> void:
	if gespawnd >= RushData.DOEL:
		return
	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return
	var slot := bord.find(null)
	if slot < 0:
		_spawn_timer = 1.0
		return
	_spawn(slot)
	var interval: float = dag["interval"]
	if _tutorial and gespawnd == 1:
		# Op maandag eerst rustig: het eerste ticket mag je in je eentje leren.
		interval = 9.0
	_spawn_timer = interval * _rng.randf_range(0.7, 1.25)


func _spawn(slot: int) -> void:
	var vakken: Array = dag["vakken"]
	var vak: int
	if _tutorial and gespawnd < 2:
		vak = [RushData.Vak.FE, RushData.Vak.BE][gespawnd]
	else:
		var kandidaten: Array = vakken.duplicate()
		if _recent_vakken.size() >= 2 and _recent_vakken[-1] == _recent_vakken[-2]:
			kandidaten.erase(_recent_vakken[-1])
		vak = kandidaten[_rng.randi() % kandidaten.size()]
	_recent_vakken.append(vak)

	var t := RushTicket.new()
	t.vak = vak
	t.nummer = nummer
	nummer += 1
	var titels: Array = RushData.TITELS[vak]
	var titel: String = titels[_rng.randi() % titels.size()]
	for poging: int in 4:
		if not titel in _recent_titels:
			break
		titel = titels[_rng.randi() % titels.size()]
	_recent_titels.append(titel)
	if _recent_titels.size() > 8:
		_recent_titels.pop_front()
	t.titel = titel
	t.position = kantoor.slot_positie(slot) + Vector2(0, -40)
	kaartjes.add_child(t)
	tickets.append(t)
	bord[slot] = t
	gespawnd += 1
	RushKlank.sfx(&"rush_nieuw", &"mg_intro", 0.1, -8.0)
	if not _tutorial:
		hud.meld("Nieuw: %s" % titel, 1.8)
	if vak == RushData.Vak.KLANT and randf() < 0.6:
		RushKlank.sfx(&"rush_hinnik", &"hinnik", 0.1, -6.0)


func _werk_geduld(delta: float) -> void:
	var geduld: float = dag["geduld"]
	for t: RushTicket in tickets:
		var snelheid := 0.0
		if t.staat == RushTicket.Staat.BORD:
			snelheid = 1.0
		elif t.staat == RushTicket.Staat.KLAAR and t.werker != null and (t.werker as RushWorker).ticket == t:
			# Klaar maar niet opgehaald: ze wacht nog steeds, iets geduldiger.
			snelheid = 0.6
		if snelheid <= 0.0:
			continue
		if _tutorial and geleverd == 0:
			snelheid *= 0.35
		t.geduld -= delta * snelheid / (geduld * pow(0.85, t.gebeld))
		if t.geduld <= 0.0:
			_belt(t)


func _belt(t: RushTicket) -> void:
	t.gebeld += 1
	t.geduld = 1.0
	gebeld += 1
	_reeks = 0
	minuut += RushData.BEL_BOETE_MIN
	hud.klok_puls()
	hud.bel(RushData.kies(RushData.KLANT_BELT))
	RushKlank.sfx(&"rush_bel", &"hinnik")
	Haptiek.tril(Haptiek.Sterkte.SLAG)
	_schok = maxf(_schok, 2.5)
	var p := t.position if t.visible else speler.position + Vector2(0, -40)
	RushPop.getal_op(veld, p + Vector2(0, -10), "+%d min" % RushData.BEL_BOETE_MIN, Color("#ff6b7a"))


func _op_werker_klaar(w: RushWorker) -> void:
	RushKlank.sfx(&"rush_klaar", &"ticket_klaar", 0.05, -3.0)
	if randf() < 0.35 and RushData.KLAAR.has(w.persoon):
		RushPop.ballon_op(veld, w.hoofd() + Vector2(0, -8), RushData.kies(RushData.KLAAR[w.persoon]), 1.3)


func _werk_koffie(delta: float) -> void:
	if _koffie_cd > 0.0:
		_koffie_cd -= delta
		if _koffie_cd <= 0.0:
			kantoor.koffie_klaar = true


# --- Jonathan begint te praten --------------------------------------------------

func _werk_kletsen(delta: float) -> void:
	if not bool(dag["kletsen"]):
		return
	if _prater == null:
		_klets_timer -= delta
		if _klets_timer <= 0.0:
			_start_kletsen()
		return
	_klets_rest -= delta
	_klets_ballon -= delta
	if _klets_ballon <= 0.0:
		_klets_ballon = 2.4
		RushPop.ballon_op(veld, _prater.hoofd(), RushData.kies(RushData.KLETS), 2.2)
	if _klets_rest <= 0.0:
		_stop_kletsen()


func _start_kletsen() -> void:
	var wie := &"jonathan" if speler_id != &"jonathan" else &"koen"
	for w: RushWorker in werkers:
		if w.persoon == wie:
			_prater = w
	if _prater == null:
		return
	_prater.praat = true
	_klets_rest = KLETS_DUUR
	_klets_ballon = 0.0
	for w: RushWorker in werkers:
		if w != _prater and is_equal_approx(w.position.y, _prater.position.y):
			w.stilgelegd = true
	hud.meld("%s houdt een stand-up en zijn rij ligt stil. Tik hem: afkappen!" % _prater.naam, 3.5)
	RushKlank.sfx(&"rush_nieuw", &"mg_intro", 0.0, -4.0)


func _kap_af() -> void:
	if _prater == null:
		return
	RushPop.ballon_op(veld, _prater.hoofd(), "...oké.", 1.2)
	_ballon_speler("Dank je! Volgende!")
	RushKlank.sfx(&"rush_afkappen", &"raak")
	Haptiek.tril(Haptiek.Sterkte.STOOT)
	_stop_kletsen()


func _stop_kletsen() -> void:
	if _prater != null:
		_prater.praat = false
	for w: RushWorker in werkers:
		w.stilgelegd = false
	_prater = null
	_klets_timer = _rng.randf_range(20.0, 30.0)


# --- Dirk wil je uren -----------------------------------------------------------

func _werk_dirk_timer(delta: float) -> void:
	if not bool(dag["dirk"]) or _dirk_staat != Dirk.WEG:
		return
	_dirk_timer -= delta
	if _dirk_timer <= 0.0:
		_start_dirk()


func _start_dirk() -> void:
	if _dirk == null:
		_dirk = AnimatedSprite2D.new()
		_dirk.offset = Vector2(0, -16)
		var d: NpcDef = GameData.npc(&"dirk")
		if d != null:
			_dirk.sprite_frames = CharacterSprites.frames_for(d.look, d.color, d.skin, d.hair, d.pants, d.accent)
		mensen.add_child(_dirk)
	_dirk.visible = true
	_dirk.position = kantoor.deur_punt()
	_dirk_staat = Dirk.KOMT
	_dirk_pad = PackedVector2Array()
	_dirk_herbereken = 0.0
	kantoor.deur_open = true
	RushKlank.sfx(&"rush_dirk", &"deur")
	RushPop.ballon_op(veld, _dirk.position + Vector2(0, -40), "Heb je even?", 1.5)
	hud.meld("Dirk wil je uren. Tik hem weg voor hij je te pakken heeft!", 3.0)


func _werk_dirk(delta: float) -> void:
	match _dirk_staat:
		Dirk.KOMT:
			if fase != Fase.SPEL:
				_dirk_staat = Dirk.GAAT
				return
			_dirk_herbereken -= delta
			if _dirk_herbereken <= 0.0:
				_dirk_herbereken = 0.4
				_dirk_pad = _pad_tussen(_dirk.position, speler.position)
			_loop_dirk(DIRK_SNELHEID * delta)
			if _dirk.position.distance_to(speler.position) < 11.0:
				_dirk_vangt()
		Dirk.GAAT:
			if _dirk_pad.is_empty():
				_dirk_pad = _pad_tussen(_dirk.position, kantoor.deur_punt())
			_loop_dirk(DIRK_SNELHEID * 2.2 * delta)
			if _dirk.position.distance_to(kantoor.deur_punt()) < 3.0:
				_dirk.visible = false
				_dirk_staat = Dirk.WEG
				kantoor.deur_open = fase == Fase.KLAAR
				_dirk_timer = _rng.randf_range(22.0, 32.0)
		Dirk.PRAAT:
			_dirk.play(&"talk_up" if speler.position.y < _dirk.position.y else &"talk_down")


func _loop_dirk(stap: float) -> void:
	var r := _dirk.position
	while stap > 0.0 and not _dirk_pad.is_empty():
		var naar := _dirk_pad[0] - _dirk.position
		if naar.length() <= stap:
			_dirk.position = _dirk_pad[0]
			stap -= naar.length()
			_dirk_pad.remove_at(0)
		else:
			_dirk.position += naar.normalized() * stap
			stap = 0.0
	var v := _dirk.position - r
	if v.length() > 0.01:
		var dir := (&"right" if v.x > 0 else &"left") if absf(v.x) > absf(v.y) else (&"down" if v.y > 0 else &"up")
		_dirk.play(StringName("walk_" + dir))
	else:
		_dirk.play(&"idle_down")


func _pad_tussen(van: Vector2, naar: Vector2) -> PackedVector2Array:
	var ids := grid.get_point_path(_tegel_van(van), _tegel_van(naar))
	var uit := PackedVector2Array()
	for i: int in range(1, ids.size()):
		uit.append(ids[i])
	uit.append(naar)
	return uit


func _dirk_vangt() -> void:
	_dirk_staat = Dirk.PRAAT
	# Waar je heen liep onthouden, dan ga je na Dirk gewoon verder.
	if not huidige.is_empty():
		wachtrij.push_front(huidige)
		huidige = {}
	speler.pad = PackedVector2Array()
	speler.start_bezig(2.4, Color("#8a93a8"))
	RushPop.ballon_op(veld, _dirk.position + Vector2(0, -40), RushData.kies(RushData.DIRK), 2.2)
	RushKlank.sfx(&"rush_bots", &"fout")
	Haptiek.tril(Haptiek.Sterkte.SLAG)
	_na_bezig = func() -> void:
		_ballon_speler("Ja, Dirk.")
		_dirk_staat = Dirk.GAAT
		_dirk_pad = PackedVector2Array()


func _stuur_dirk_weg() -> void:
	_dirk_staat = Dirk.GAAT
	_dirk_pad = PackedVector2Array()
	RushPop.ballon_op(veld, _dirk.position + Vector2(0, -40), "Oké, straks!", 1.2)
	_ballon_speler("Straks, Dirk!")
	RushKlank.sfx(&"rush_weg", &"raak")
	Haptiek.tril(Haptiek.Sterkte.STOOT)


# --- Brand in de serverkast -----------------------------------------------------

func _werk_brand(delta: float) -> void:
	if not bool(dag["brand"]) or kantoor.brand:
		return
	_brand_timer -= delta
	if _brand_timer <= 0.0:
		kantoor.brand = true
		RushKlank.sfx(&"rush_brand", &"fout")
		_schok = maxf(_schok, 2.0)
		hud.meld("De server staat in brand! Eerst blussen.", 3.0)


# --- Einde van de dag -------------------------------------------------------------

func _dag_klaar() -> void:
	fase = Fase.KLAAR
	hud.mag_pauzeren = false
	wachtrij.clear()
	huidige = {}
	_stop_kletsen()
	var sterren := RushData.sterren_voor(minuut)
	var regel := _score_regel(sterren)
	if not bot:
		RushSave.noteer(dag_index, sterren)
	hud.meld("10/10. Naar huis!", 10.0)
	kantoor.deur_open = true
	RushKlank.sfx(&"rush_deur", &"deur")
	_ballon_speler("Vrijheid!")
	speler.pad = _pad_naar(kantoor.deur_punt())
	speler.pad.append(kantoor.deur_punt() + Vector2(0, 16))
	RushPop.confetti(veld, speler.position + Vector2(0, -30), 30)
	if bot and not bot_blijf:
		print("RUSH-BOT dag=%d speler=%s klaar=%s sterren=%d gebeld=%d" % [
			dag_index + 1, speler_id, RushData.klok(minuut), sterren, gebeld])
		get_tree().quit()
		return
	await get_tree().create_timer(1.4).timeout

	# En dan naar buiten, door het echte kantoor, met het vuur op je hielen.
	var ontsnap_sec := -1.0
	var record := false
	if not bot or bot_blijf:
		var o := RushOntsnapping.new()
		o.bot = bot
		add_child(o)
		o.start(speler_id, dag_index)
		var uit: Array = await o.klaar
		o.queue_free()
		if bot:
			print("RUSH-ONTSNAP sec=%.1f gebotst=%d" % [float(uit[0]), int(uit[1])])
			get_tree().quit()
		if not bool(uit[2]):
			ontsnap_sec = float(uit[0])
			record = RushSave.noteer_ontsnapping(dag_index, ontsnap_sec)
	regel["ontsnap"] = ontsnap_sec
	var plek := 0 if bot else RushSave.noteer_score(regel)
	RushKlank.laag(&"overwinning", &"rush_uitslag", &"overwinning", 0.3)
	hud.toon_resultaat(dag_index, minuut, sterren, gebeld, dag_index == RushData.DAGEN.size() - 1,
		ontsnap_sec, record, plek, regel)


## Eén regel voor de eregalerij: wie, wanneer klaar, en het pixelportret als
## RushPixel-code.
func _score_regel(sterren: int) -> Dictionary:
	var naam := String(speler_id).capitalize()
	var rol := ""
	var portret: Image = null
	if speler_id == RushProfiel.ID:
		naam = RushProfiel.naam
		rol = RushProfiel.ROL_NAAM[RushProfiel.rol]
		portret = RushProfiel.portret
	else:
		var def: CharacterDef = GameData.character(speler_id)
		if def != null:
			naam = def.name
			rol = def.role
			if def.portrait != "" and ResourceLoader.exists(def.portrait):
				portret = (load(def.portrait) as Texture2D).get_image()
	var code := RushPixel.naar_code(portret) if portret != null else ""
	return {"dag": dag_index, "naam": naam, "wie": String(speler_id), "rol": rol,
		"minuut": snappedf(minuut, 0.1), "sterren": sterren, "gebeld": gebeld,
		"ontsnap": -1.0, "portret": code}


func _opnieuw() -> void:
	AudioDirector.clear_layer(&"overwinning", 0.2)
	RushSave.dag = dag_index
	get_tree().paused = false
	get_tree().reload_current_scene()


func _volgende() -> void:
	AudioDirector.clear_layer(&"overwinning", 0.2)
	RushSave.dag = mini(dag_index + 1, RushData.DAGEN.size() - 1)
	get_tree().reload_current_scene()


func _naar_menu() -> void:
	AudioDirector.clear_layer(&"overwinning", 0.2)
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/rush/rush_menu.tscn")


# --- Tutorial (maandag) --------------------------------------------------------

func _werk_tutorial() -> void:
	var t := _tutorial_doel()
	var tekst: String = t.get("tekst", "")
	if geleverd >= 2:
		tekst = ""
		_tutorial = false
	if tekst != _laatste_hint:
		_laatste_hint = tekst
		hud.hint_vast(tekst)


## Waar de pijl op maandag naar wijst, en wat eronder staat.
func _tutorial_doel() -> Dictionary:
	for h: RushTicket in speler.handen:
		if h.staat == RushTicket.Staat.KLAAR:
			return {"p": RushKantoor.SERVER_RECT.get_center() + Vector2(0, -44),
				"tekst": "Klaar! Tik op de server: live ermee."}
	for w: RushWorker in werkers:
		if w.is_klaar and speler.vrije_hand():
			return {"p": w.hoofd() + Vector2(0, -16), "tekst": "%s is klaar. Tik op hem om het op te halen." % w.naam}
	var open := _eerste_open()
	if open != null:
		for w: RushWorker in werkers:
			if w.vak == open.vak and (w.vrij() or w.is_eigen):
				var wie := "je eigen bureau" if w.is_eigen else w.naam
				return {"p": w.hoofd() + Vector2(0, -6), "tekst": "%s is %s. Breng het naar %s." % [
					open.code(), RushData.VAK_NAAM[open.vak], wie]}
	for i: int in bord.size():
		if bord[i] != null and speler.vrije_hand():
			return {"p": kantoor.slot_positie(i) + Vector2(0, -12), "tekst": "Tik op het ticket op het bord."}
	for w: RushWorker in werkers:
		if w.ticket != null and not w.is_klaar:
			return {"tekst": "%s is ermee bezig. Pak alvast de volgende." % w.naam}
	return {}


# --- Hulpjes ------------------------------------------------------------------------

func _in_hand(vak: int, klaar: bool) -> RushTicket:
	for t: RushTicket in speler.handen:
		if t.vak == vak and (t.staat == RushTicket.Staat.KLAAR) == klaar:
			return t
	return null


func _eerste_open() -> RushTicket:
	for t: RushTicket in speler.handen:
		if t.staat == RushTicket.Staat.HAND:
			return t
	return null


func _ballon_speler(t: String) -> void:
	RushPop.ballon_op(veld, speler.position + Vector2(0, -38 - (14 if not speler.handen.is_empty() else 0)), t, 1.3)


func _beweeg_kaartjes(delta: float) -> void:
	var k := 1.0 - exp(-delta * 18.0)
	for i: int in range(tickets.size() - 1, -1, -1):
		var t := tickets[i]
		var doel := t.position
		match t.staat:
			RushTicket.Staat.BORD:
				var slot := bord.find(t)
				doel = kantoor.slot_positie(slot)
				t.visible = true
				t.scale = Vector2.ONE
			RushTicket.Staat.HAND, RushTicket.Staat.KLAAR, RushTicket.Staat.WERK:
				var idx := speler.handen.find(t)
				if idx >= 0:
					doel = speler.position + speler.hand_positie(idx)
					t.visible = true
					t.scale = t.scale.lerp(Vector2.ONE, k * 0.6)
				elif t.werker != null:
					doel = (t.werker as RushWorker).position + Vector2(-11, -10)
					if t.position.distance_to(doel) < 2.0:
						t.visible = false
			RushTicket.Staat.LIVE:
				doel = RushKantoor.SERVER_RECT.get_center() + Vector2(0, -10)
				t.scale = t.scale.lerp(Vector2.ZERO, k * 0.5)
				if t.position.distance_to(doel) < 3.0 or t.scale.x < 0.1:
					tickets.remove_at(i)
					t.queue_free()
					continue
		t.position = t.position.lerp(doel, k)


func _werk_rimpels(delta: float) -> void:
	for i: int in range(_rimpels.size() - 1, -1, -1):
		_rimpels[i]["t"] = float(_rimpels[i]["t"]) + delta
		if float(_rimpels[i]["t"]) > 0.35:
			_rimpels.remove_at(i)


func _werk_schok(delta: float) -> void:
	_schok = maxf(0.0, _schok - delta * 8.0)
	_pas_layout()
	if _schok > 0.0:
		veld.position += Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _schok


func _daglicht(m: float) -> Color:
	# Koel in de ochtend, goud om vijf uur, tl-blauw als je dan nog zit.
	var ochtend := Color(0.97, 0.99, 1.0)
	var middag := Color(1.0, 1.0, 0.98)
	var vijf := Color(1.0, 0.9, 0.78)
	var avond := Color(0.78, 0.82, 1.0)
	if m < 12 * 60:
		return ochtend.lerp(middag, (m - 9 * 60) / 180.0)
	if m < 17 * 60:
		return middag.lerp(vijf, (m - 12 * 60) / 300.0)
	return vijf.lerp(avond, clampf((m - 17 * 60) / 90.0, 0.0, 1.0))


func _teken_markers() -> void:
	# Waar je naartoe gaat: genummerde stippen.
	var doelen: Array[Vector2] = []
	if not huidige.is_empty():
		doelen.append(huidige["punt"])
	for a: Dictionary in wachtrij:
		doelen.append(a["punt"])
	for i: int in doelen.size():
		var p := doelen[i] + Vector2(0, 2)
		markers.draw_circle(p, 4.0, Color(0.23, 0.53, 1.0, 0.85))
		markers.draw_circle(p, 4.0, Color(1, 1, 1, 0.9), false, 1.0)
		markers.draw_string(UiKit.FONT_10, p + Vector2(-2.5, 3.5), str(i + 1),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
	for r: Dictionary in _rimpels:
		var f := float(r["t"]) / 0.35
		markers.draw_arc(r["p"], 3.0 + f * 9.0, 0, TAU, 16, Color(1, 1, 1, 0.8 * (1.0 - f)), 1.0)
	if _tutorial and fase == Fase.SPEL:
		var d := _tutorial_doel()
		if d.has("p"):
			var p: Vector2 = d["p"] + Vector2(0, -absf(sin(_tijd * 5.0)) * 4.0)
			markers.draw_colored_polygon(PackedVector2Array([
				p + Vector2(-5, -7), p + Vector2(5, -7), p]), Color("#ffd23f"))
			markers.draw_polyline(PackedVector2Array([
				p + Vector2(-5, -7), p + Vector2(5, -7), p, p + Vector2(-5, -7)]), Color("#7a5a00"), 1.0)


# --- Bot: speelt zelf, voor balans en tests ------------------------------------

func _bot_kies() -> void:
	if not wachtrij.is_empty() or not huidige.is_empty():
		return
	if _dirk_staat == Dirk.KOMT:
		_bot_tik(_dirk.position + Vector2(0, -16))
	if _prater != null:
		_bot_tik(_prater.position + Vector2(0, -24))
		return
	var klaar_n := 0
	for t: RushTicket in speler.handen:
		if t.staat == RushTicket.Staat.KLAAR:
			klaar_n += 1
	# Afgewerkt werk ophalen.
	for w: RushWorker in werkers:
		if w.is_klaar and (speler.vrije_hand() or _in_hand(w.vak, false) != null):
			_bot_tik(w.position + Vector2(0, -24))
			return
	if klaar_n > 0 and (not speler.vrije_hand() or _eerste_open() == null):
		_bot_tik(RushKantoor.SERVER_RECT.get_center())
		return
	var open := _eerste_open()
	if open != null:
		for w: RushWorker in werkers:
			if w.vak == open.vak and (w.vrij() or w.is_eigen):
				_bot_tik(w.position + Vector2(0, -24))
				return
	if speler.vrije_hand():
		var beste := -1
		for i: int in bord.size():
			if bord[i] != null and (beste < 0 or (bord[i] as RushTicket).geduld < (bord[beste] as RushTicket).geduld):
				beste = i
		if beste >= 0:
			_bot_tik(kantoor.slot_positie(beste))
			return
	if klaar_n > 0:
		_bot_tik(RushKantoor.SERVER_RECT.get_center())
		return
	if bool(dag["koffie"]) and _koffie_cd <= 0.0:
		_bot_tik(RushKantoor.KOFFIE_RECT.get_center())


## De bot tikt zoals een duim: met `--echt` via een echte muisgebeurtenis door
## de hele invoerketen, anders rechtstreeks op dezelfde raakvlakken.
func _bot_tik(p: Vector2) -> void:
	if not bot_echt:
		_tik(p)
		return
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	# Vensterpixels: Godot rekent de gebeurtenis zelf terug naar het canvas.
	ev.position = get_viewport().get_final_transform() * (veld.get_global_transform_with_canvas() * p)
	Input.parse_input_event(ev)
	var los := ev.duplicate() as InputEventMouseButton
	los.pressed = false
	Input.parse_input_event(los)
