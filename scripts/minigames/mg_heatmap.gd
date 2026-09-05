extends MinigameBase
## BBD-206 — Waar klikken ze? Danny's CRO-ticket ("Niemand koopt iets").
##
## Dit was `mg_abtest`: drie rondes een variant aanzetten en een naald zien
## bewegen — hetzelfde spel als BBD-207 (`mg_abgevecht`), met zeven van de negen
## dezelfde antwoorden, achter elkaar te spelen. Nu is het een ander werkwoord:
## kijken en slepen, onder tijd. Op een wireframe van de productpagina landen
## de klikken van bezoekers als hittepunten. Eén element trekt ze allemaal —
## en het is geen knop. Sleep de Bestellen-knop daarheen voordat de ronde om
## is. Drie rondes, drie plekken, en elke ronde meer ruis.
##
## Geen lijst met antwoorden: het antwoord staat op het scherm, maar je moet
## het zien terwijl het gebeurt. Danny (trait `data`) ziet per element een
## teller staan (`toon_tellers`); de rest leest de hitte.
##
## De uitkomst blijft dezelfde als vroeger, zodat `Gevolgen.boek()` niets hoeft
## te weten: `conversie` (float) en `boven_doel` (bool) in de payload.

const VELD_MAAT := Vector2(164.0, 190.0)
## Hoe lang een hittepunt zichtbaar blijft, en hoe vaak er een landt.
const DOT_LEVEN := 1.6
const DOT_INTERVAL := 0.11
## Adem tussen twee rondes: lang genoeg om Danny's regel te lezen.
const TUSSEN_RONDES := 1.4
## Welk deel van de knop over het hete element moet liggen om te tellen.
const RAAK_DEEL := 0.4


## De laag waarop de hittepunten getekend worden. Als laatste kind van het veld,
## zodat de punten óver de elementen en de knop heen liggen — een `_draw()` op
## het veld zelf zou onder zijn kinderen verdwijnen.
class Hitte extends Control:
	var punten: Array = []  # [Vector2, leeftijd]

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func land(p: Vector2) -> void:
		punten.append([p, 0.0])

	func wis() -> void:
		punten.clear()
		queue_redraw()

	func _process(delta: float) -> void:
		var over: Array = []
		for d: Array in punten:
			d[1] = float(d[1]) + delta
			if float(d[1]) < DOT_LEVEN:
				over.append(d)
		punten = over
		queue_redraw()

	func _draw() -> void:
		for d: Array in punten:
			var t := float(d[1]) / DOT_LEVEN
			var pos := d[0] as Vector2
			var buiten := UiKit.ORANJE
			buiten.a = (1.0 - t) * 0.55
			draw_circle(pos, 2.5 + t * 3.0, buiten)
			var kern := UiKit.ROOD
			kern.a = 1.0 - t
			draw_circle(pos, 1.3, kern)


## Het veld: ontvangt aanrakingen en slepen, in beide gebeurtenisfamilies
## (touch én muis), net als `mg_uitlijnen.Vel`.
class Veld extends Control:
	signal aangeraakt(punt: Vector2)
	signal gesleept(punt: Vector2)
	signal losgelaten()

	func _init(maat: Vector2) -> void:
		custom_minimum_size = maat
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventScreenTouch:
			var t := event as InputEventScreenTouch
			if t.pressed:
				aangeraakt.emit(t.position)
			else:
				losgelaten.emit()
			accept_event()
		elif event is InputEventScreenDrag:
			gesleept.emit((event as InputEventScreenDrag).position)
			accept_event()
		elif event is InputEventMouseButton:
			var m := event as InputEventMouseButton
			if m.button_index != MOUSE_BUTTON_LEFT:
				return
			if m.pressed:
				aangeraakt.emit(m.position)
			else:
				losgelaten.emit()
			accept_event()
		elif event is InputEventMouseMotion:
			gesleept.emit((event as InputEventMouseMotion).position)


var _basis: float = 0.0
var _doel: float = 0.0
var _eenheid: String = ""
var _ronde_sec: float = 9.0
var _toon_tellers: bool = false

var _conversie: float = 0.0
var _ronde: int = 0
var _tijd_over: float = 0.0
var _bezig: bool = false
var _qa_loopt: bool = false
var _keuzes: Array[String] = []

var _veld: Veld = null
var _hitte: Hitte = null
var _elementen: Dictionary = {}       ## id -> Panel
var _rects: Dictionary = {}           ## id -> Rect2 (veldcoördinaten)
var _tellers: Dictionary = {}         ## id -> int
var _teller_labels: Dictionary = {}   ## id -> Label
var _knop: Panel = null
var _knop_maat: Vector2 = Vector2(64.0, 20.0)

var _sleept: bool = false
var _greep: Vector2 = Vector2.ZERO
var _spawn_t: float = 0.0

var _waarde: Label = null
var _balk_houder: Control = null
var _balk: ColorRect = null
var _regel: Label = null


func _on_setup() -> void:
	var c := content()
	if c.is_empty() or _rondes().is_empty() or (c.get("elementen", []) as Array).is_empty():
		fail()
		return

	_basis = float(c.get("basis", 0.0))
	_doel = float(c.get("doel", 0.0))
	_eenheid = String(c.get("eenheid", ""))
	_ronde_sec = maxf(3.0, float(c.get("ronde_sec", 9.0)))
	_toon_tellers = bool(c.get("toon_tellers", false))
	_conversie = _basis

	var body := build_chrome(default_title(), String(c.get("intro", "")))

	# De conversie en de rondeklok horen niet mee te scrollen: dat zijn de twee
	# dingen die je elk moment nodig hebt.
	chrome_header().add_child(_bouw_meter())

	# Het veld gecentreerd op een licht paneel, zodat het als "de pagina" leest
	# en niet als het donkere chrome eromheen.
	var kader := PanelContainer.new()
	# `panel_krap`: de gewone paneelmarge maakt 164 px veld tot 196 px paneel, en
	# dat is breder dan het canvas.
	kader.add_theme_stylebox_override("panel", UiKit.panel_krap(UiKit.PANEL, UiKit.LINE))
	body.add_child(kader)
	var midden := CenterContainer.new()
	kader.add_child(midden)
	_veld = Veld.new(VELD_MAAT)
	midden.add_child(_veld)
	_veld.aangeraakt.connect(_op_aanraking)
	_veld.gesleept.connect(_op_sleep)
	_veld.losgelaten.connect(_op_los)

	for raw: Variant in c.get("elementen", []) as Array:
		_bouw_element(raw as Dictionary)
	_bouw_knop(c.get("knop", {}) as Dictionary)

	_hitte = Hitte.new()
	_veld.add_child(_hitte)

	# Danny leest de uitslag voor, in het footer zodat hij niet wegscrollt.
	_regel = UiKit.label("", UiKit.FS_SMALL, UiKit.BLUEBIRD_BRIGHT)
	_regel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_regel.visible = false
	chrome_footer().add_child(_regel)

	_zet_conversie(_conversie)
	_start_ronde()


func _rondes() -> Array:
	return content().get("rondes", []) as Array


func _bouw_meter() -> PanelContainer:
	var paneel := PanelContainer.new()
	paneel.add_theme_stylebox_override("panel", UiKit.panel(UiKit.PANEL, UiKit.LINE))
	var kolom := VBoxContainer.new()
	kolom.add_theme_constant_override("separation", 3)
	paneel.add_child(kolom)
	var rij := HBoxContainer.new()
	kolom.add_child(rij)
	_waarde = UiKit.label("", UiKit.FS_SUB, UiKit.INK)
	_waarde.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_waarde.autowrap_mode = TextServer.AUTOWRAP_OFF
	rij.add_child(_waarde)
	# Zonder autowrap: in een HBox krijgt een omlopend label de smalste breedte
	# die het aankan, en dan staat "doel 2,7%" als één letter per regel.
	var doel := UiKit.label("doel %s" % _formatteer(_doel), UiKit.FS_SMALL, UiKit.GRIJS_OP_LICHT)
	doel.autowrap_mode = TextServer.AUTOWRAP_OFF
	doel.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	rij.add_child(doel)
	# De rondeklok: een balk die leegloopt. In een gewone Control, want een
	# Container zou de breedte van de balk zelf uitdelen.
	_balk_houder = Control.new()
	_balk_houder.custom_minimum_size = Vector2(0.0, 5.0)
	_balk_houder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kolom.add_child(_balk_houder)
	var achter := ColorRect.new()
	achter.color = UiKit.NEUTRAAL_TINT
	achter.set_anchors_preset(Control.PRESET_FULL_RECT)
	achter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_balk_houder.add_child(achter)
	_balk = ColorRect.new()
	_balk.color = UiKit.GROEN
	_balk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_balk_houder.add_child(_balk)
	return paneel


func _bouw_element(d: Dictionary) -> void:
	var id := String(d.get("id", ""))
	var r: Array = d.get("rect", [])
	if id == "" or r.size() != 4:
		return
	var rect := Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
	var paneel := Panel.new()
	paneel.add_theme_stylebox_override("panel", UiKit.panel_krap(UiKit.NEUTRAAL_TINT, UiKit.LINE))
	paneel.position = rect.position
	paneel.size = rect.size
	paneel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veld.add_child(paneel)
	var tekst := UiKit.label(String(d.get("label", "")), UiKit.FS_SMALL, UiKit.GRIJS_OP_LICHT)
	tekst.set_anchors_preset(Control.PRESET_FULL_RECT)
	tekst.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tekst.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tekst.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tekst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paneel.add_child(tekst)
	# Danny's teller: rechtsboven in het element, alleen met de trait.
	var teller := UiKit.label("", UiKit.FS_SMALL, UiKit.ROOD_OP_LICHT)
	teller.position = Vector2(rect.size.x - 22.0, -1.0)
	teller.size = Vector2(20.0, 12.0)
	teller.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	teller.visible = _toon_tellers
	teller.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paneel.add_child(teller)
	_elementen[id] = paneel
	_rects[id] = rect
	_tellers[id] = 0
	_teller_labels[id] = teller


func _bouw_knop(d: Dictionary) -> void:
	var maat: Array = d.get("maat", [64, 20])
	var start: Array = d.get("start", [50, 160])
	_knop_maat = Vector2(float(maat[0]), float(maat[1]))
	_knop = Panel.new()
	_knop.add_theme_stylebox_override("panel", UiKit.panel_krap(UiKit.BLUEBIRD_BRIGHT, UiKit.BLUEBIRD_INK))
	_knop.size = _knop_maat
	_knop.position = Vector2(float(start[0]), float(start[1]))
	_knop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veld.add_child(_knop)
	var tekst := UiKit.label(String(d.get("label", "Bestellen")), UiKit.FS_SMALL, UiKit.WIT)
	tekst.set_anchors_preset(Control.PRESET_FULL_RECT)
	tekst.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tekst.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tekst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_knop.add_child(tekst)


# --- Rondes ---------------------------------------------------------------

func _start_ronde() -> void:
	var r := _huidige()
	if r.is_empty():
		return
	for id: String in _tellers:
		_tellers[id] = 0
		(_teller_labels[id] as Label).text = ""
	if _hitte != null:
		_hitte.wis()
	_knop.modulate = Color.WHITE
	_regel.visible = false
	_tijd_over = _ronde_sec
	_spawn_t = 0.2
	_bezig = true
	set_status("ronde %d/%d  ·  kijk waar ze klikken" % [_ronde + 1, _rondes().size()])


func _huidige() -> Dictionary:
	var rs := _rondes()
	return rs[_ronde] as Dictionary if _ronde < rs.size() else {}


func _process(delta: float) -> void:
	if not _bezig:
		return
	_tijd_over -= delta
	_teken_klok()
	_spawn_t -= delta
	while _spawn_t <= 0.0 and _bezig:
		_land_klik()
		_spawn_t += DOT_INTERVAL
	if _tijd_over <= 0.0:
		_rond_af()


func _teken_klok() -> void:
	if _balk == null or _balk_houder == null:
		return
	var deel := clampf(_tijd_over / _ronde_sec, 0.0, 1.0)
	_balk.position = Vector2.ZERO
	_balk.size = Vector2(_balk_houder.size.x * deel, _balk_houder.size.y)
	_balk.color = UiKit.GROEN if deel > 0.4 else (UiKit.ORANJE if deel > 0.15 else UiKit.ROOD)


## Eén bezoeker klikt. Meestal op het hete element, soms ergens anders — hoe
## verder in het spel, hoe meer ruis (`ruis` per ronde).
func _land_klik() -> void:
	var r := _huidige()
	var heet := String(r.get("heet", ""))
	var ruis := clampf(float(r.get("ruis", 0.3)), 0.0, 0.9)
	var id := heet
	if randf() < ruis or not _rects.has(heet):
		var anderen: Array = []
		for k: String in _rects:
			if k != heet:
				anderen.append(k)
		if not anderen.is_empty():
			id = anderen[randi() % anderen.size()]
	if not _rects.has(id):
		return
	var rect: Rect2 = _rects[id]
	var binnen := rect.grow(-3.0)
	var p := Vector2(randf_range(binnen.position.x, binnen.end.x),
		randf_range(binnen.position.y, binnen.end.y))
	_hitte.land(p)
	_tellers[id] = int(_tellers[id]) + 1
	if _toon_tellers:
		(_teller_labels[id] as Label).text = str(_tellers[id])


func _rond_af() -> void:
	_bezig = false
	_sleept = false
	var r := _huidige()
	var heet := String(r.get("heet", ""))
	var raak := _knop_raakt(heet)
	var c := content()
	if raak:
		_conversie += float(r.get("effect", 0.0))
		_zet_conversie(_conversie)
		_knop.modulate = UiKit.GROEN.lightened(0.3)
		AudioDirector.play_ui(&"pak")
		Juice.schok(1.0, 0.15)
		_regel.text = String(r.get("regel", ""))
	else:
		_knop.modulate = UiKit.ROOD.lightened(0.2)
		AudioDirector.play_ui(&"fout")
		_regel.text = String(c.get("mis_regel", ""))
	_regel.visible = _regel.text != ""
	_keuzes.append(heet if raak else "mis")
	set_status("ronde %d/%d  ·  %s" % [_ronde + 1, _rondes().size(), "raak" if raak else "mis"])

	await get_tree().create_timer(TUSSEN_RONDES).timeout
	if not is_inside_tree():
		return
	_ronde += 1
	if _ronde < _rondes().size():
		_start_ronde()
	else:
		_afronden()


## Ligt de knop genoeg over het hete element? Overlap in oppervlak, niet het
## middelpunt: een knop die half op het paard ligt is ook "op het paard".
func _knop_raakt(heet: String) -> bool:
	if not _rects.has(heet) or _knop == null:
		return false
	var knop := Rect2(_knop.position, _knop.size)
	var overlap: Rect2 = (_rects[heet] as Rect2).intersection(knop)
	if not overlap.has_area():
		return false
	return overlap.get_area() >= RAAK_DEEL * knop.get_area()


func _afronden() -> void:
	var c := content()
	var gelukt := _haalt_doel()
	await finish_with_banner(gelukt,
		String(c.get("success" if gelukt else "failure", "")),
		int(round(_conversie * 10.0)),
		{
			&"conversie": _conversie,
			&"boven_doel": gelukt,
			&"keuzes": _keuzes,
		})


## Drie keer optellen laat een float net onder een gelijke uitkomst landen, en
## precies op de doelstelling uitkomen mag geen verlies zijn.
func _haalt_doel() -> bool:
	return _conversie >= _doel or is_equal_approx(_conversie, _doel)


func _zet_conversie(v: float) -> void:
	if _waarde != null:
		_waarde.text = _formatteer(v)
		_waarde.add_theme_color_override("font_color",
			UiKit.GROEN_OP_LICHT if _haalt_doel() else UiKit.INK)


func _formatteer(v: float) -> String:
	return "%s%s" % [String.num(v, 1).replace(".", ","), _eenheid]


# --- Slepen -----------------------------------------------------------------

func _op_aanraking(punt: Vector2) -> void:
	if not _bezig or _knop == null:
		return
	# Je hoeft de knop niet exact te raken: een tik ernaast pakt hem ook, want op
	# een telefoon is 20 px hoog een dun doelwit.
	if Rect2(_knop.position, _knop.size).grow(8.0).has_point(punt):
		_sleept = true
		_greep = punt - _knop.position
		AudioDirector.play_ui(&"klik")


func _op_sleep(punt: Vector2) -> void:
	if not _sleept or _knop == null:
		return
	var doel := punt - _greep
	doel.x = clampf(doel.x, 0.0, VELD_MAAT.x - _knop.size.x)
	doel.y = clampf(doel.y, 0.0, VELD_MAAT.y - _knop.size.y)
	_knop.position = doel


func _op_los() -> void:
	_sleept = false


# --- QA ---------------------------------------------------------------------

## De autopilot legt de knop op het hete element en laat de ronde meteen
## aflopen; elke tik van de autopilot doet dat voor de dan lopende ronde.
func qa_solve() -> void:
	if not _bezig or _qa_loopt or _knop == null:
		return
	# Eerst een seconde kijken, dan pas slepen: zo staat er in een QA-frame ook
	# echt hitte op het scherm, en niet alleen een knop die al verhuisd is.
	if _ronde_sec - _tijd_over < 1.0:
		return
	var heet := String(_huidige().get("heet", ""))
	if not _rects.has(heet):
		return
	_qa_loopt = true
	var rect: Rect2 = _rects[heet]
	_knop.position = rect.get_center() - _knop.size * 0.5
	_tijd_over = 0.0
	_qa_loopt = false
