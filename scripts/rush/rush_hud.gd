class_name RushHud
extends CanvasLayer
## Alles wat over de vloer heen ligt: de klok, de tien vakjes, de hintregel,
## de klant aan de telefoon, en de schermen voor en na een dag.

signal start
signal opnieuw
signal volgende
signal naar_menu

const BOVEN := 28
const ONDER := 24

var _dag: Label
var _klok: Label
var _pips: Control
var _hint: Label
var _bel: PanelContainer
var _bel_tekst: Label
var _bel_tween: Tween
var _overlay: Control = null
var _pauze: Control = null

var _geleverd := 0
## Het spel zet dit aan zolang er gespeeld wordt; dan opent het pauzemenu
## vanzelf als je terugkomt uit een andere app.
var mag_pauzeren := false
var _was_weg := false
## De regel van de dag die net gespeeld is, voor de deelkaart.
var _laatste_regel: Dictionary = {}
var _hint_vast := ""
var _hint_tijd := 0.0
var _klok_puls := 0.0
var _pip_puls := 0.0


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	var wortel := Control.new()
	wortel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wortel)
	UiKit.fill_viewport(wortel)

	# Bovenbalk.
	var boven := ColorRect.new()
	boven.color = Color("#141824")
	boven.mouse_filter = Control.MOUSE_FILTER_STOP
	boven.anchor_right = 1.0
	boven.offset_bottom = BOVEN
	wortel.add_child(boven)

	_dag = _lbl("MA", 10, Color("#8fb3ff"))
	_dag.position = Vector2(6, 2)
	boven.add_child(_dag)

	_pips = Control.new()
	_pips.position = Vector2(6, 17)
	_pips.size = Vector2(70, 6)
	_pips.draw.connect(_teken_pips)
	boven.add_child(_pips)

	_klok = _lbl("09:00", 16, Color.WHITE)
	_klok.anchor_left = 1.0
	_klok.anchor_right = 1.0
	_klok.offset_left = -84
	_klok.offset_right = -32
	_klok.offset_top = 4
	_klok.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	boven.add_child(_klok)

	var pauze := Button.new()
	pauze.text = "II"
	pauze.focus_mode = Control.FOCUS_NONE
	pauze.add_theme_font_override(&"font", UiKit.FONT_12)
	pauze.add_theme_font_size_override(&"font_size", 12)
	pauze.add_theme_stylebox_override(&"normal", _vlak(Color("#2a3042")))
	pauze.add_theme_stylebox_override(&"hover", _vlak(Color("#36405a")))
	pauze.add_theme_stylebox_override(&"pressed", _vlak(Color("#4a5677")))
	pauze.anchor_left = 1.0
	pauze.anchor_right = 1.0
	pauze.offset_left = -26
	pauze.offset_right = -4
	pauze.offset_top = 3
	pauze.offset_bottom = 25
	pauze.pressed.connect(_open_pauze)
	boven.add_child(pauze)

	# Onderbalk met de hint.
	var onder := ColorRect.new()
	onder.color = Color("#141824")
	onder.mouse_filter = Control.MOUSE_FILTER_STOP
	onder.anchor_top = 1.0
	onder.anchor_right = 1.0
	onder.anchor_bottom = 1.0
	onder.offset_top = -ONDER
	wortel.add_child(onder)
	_hint = _lbl("", 10, Color("#d6dbe8"))
	_hint.anchor_right = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_left = 4
	_hint.offset_right = -4
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.add_theme_constant_override(&"line_spacing", -2)
	onder.add_child(_hint)

	# De klant: een melding die van boven binnenschuift.
	_bel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#fff7e8")
	sb.border_color = Color("#e5484d")
	sb.set_border_width_all(1)
	sb.border_width_left = 3
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 3
	sb.content_margin_bottom = 4
	_bel.add_theme_stylebox_override(&"panel", sb)
	_bel.position = Vector2(6, 0)
	_bel.visible = false
	_bel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wortel.add_child(_bel)
	var kol := VBoxContainer.new()
	kol.add_theme_constant_override(&"separation", 0)
	_bel.add_child(kol)
	var rij := HBoxContainer.new()
	kol.add_child(rij)
	var wie := _lbl("Manege De Vrije Teugel", 10, Color("#9c3945"))
	wie.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rij.add_child(wie)
	rij.add_child(_lbl("+%d min" % RushData.BEL_BOETE_MIN, 10, Color("#e5484d")))
	_bel_tekst = _lbl("", 10, Color("#242424"))
	_bel_tekst.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	kol.add_child(_bel_tekst)


func _process(delta: float) -> void:
	# Shell zet max_fps op 1 zolang de app op de achtergrond staat.
	if Engine.max_fps == 1:
		_was_weg = true
	elif _was_weg:
		_was_weg = false
		if mag_pauzeren:
			_open_pauze()
	if _hint_tijd > 0.0:
		_hint_tijd -= delta
		if _hint_tijd <= 0.0:
			_hint.text = _hint_vast
	if _pip_puls > 0.0:
		_pip_puls = maxf(0.0, _pip_puls - delta * 2.5)
		_pips.queue_redraw()
	if _klok_puls > 0.0:
		_klok_puls = maxf(0.0, _klok_puls - delta * 2.0)
		_klok.scale = Vector2.ONE * (1.0 + _klok_puls * 0.25)
		_klok.pivot_offset = _klok.size / 2.0


func zet(dagkort: String, geleverd: int, minuut: float) -> void:
	_dag.text = dagkort
	if geleverd != _geleverd:
		_pip_puls = 1.0 if geleverd > _geleverd else 0.0
		_geleverd = geleverd
		_pips.queue_redraw()
	_klok.text = RushData.klok(minuut)
	var k := Color.WHITE
	if minuut > RushData.EIND_MIN:
		k = Color("#ff7aa8")
	elif minuut > RushData.EIND_MIN - 60:
		k = Color("#ffd27a")
	_klok.add_theme_color_override(&"font_color", k)


func klok_puls() -> void:
	_klok_puls = 1.0


## Een hint die blijft staan tot er een andere komt.
func hint_vast(t: String) -> void:
	_hint_vast = t
	if _hint_tijd <= 0.0:
		_hint.text = t


## Een melding die even voorgaat op de vaste hint.
func meld(t: String, duur: float = 2.2) -> void:
	_hint.text = t
	_hint_tijd = duur


func bel(t: String) -> void:
	_bel_tekst.text = "\"%s\"" % t
	if _bel_tween != null and _bel_tween.is_valid():
		_bel_tween.kill()
	# Van onderen omhoog, net boven de hintregel. Bovenin zou hij het bord
	# afdekken, en dat is precies waar je op dat moment naar moet kijken.
	var vp := get_viewport().get_visible_rect().size
	_bel.size = Vector2(vp.x - 12.0, 0.0)
	_bel.reset_size()
	_bel.size.x = vp.x - 12.0
	_bel.visible = true
	_bel.position = Vector2(6.0, vp.y + 4.0)
	var doel := vp.y - ONDER - _bel.size.y - 4.0
	_bel_tween = create_tween()
	_bel_tween.tween_property(_bel, ^"position:y", doel, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_bel_tween.tween_interval(2.4)
	_bel_tween.tween_property(_bel, ^"position:y", vp.y + 4.0, 0.25)
	_bel_tween.tween_callback(func() -> void: _bel.visible = false)


func _teken_pips() -> void:
	for i: int in RushData.DOEL:
		var r := Rect2(i * 7, 0, 5, 6)
		if i < _geleverd:
			if i == _geleverd - 1 and _pip_puls > 0.0:
				r = r.grow(_pip_puls * 2.0)
				_pips.draw_rect(r, Color("#3fd27f").lerp(Color.WHITE, _pip_puls * 0.6))
				continue
			_pips.draw_rect(r, Color("#3fd27f"))
		else:
			_pips.draw_rect(r, Color("#2a3042"))
			_pips.draw_rect(r, Color("#4a5677"), false, 1.0)


# --- Schermen ---------------------------------------------------------------

func toon_intro(dag_index: int, dag: Dictionary, speler: StringName) -> void:
	var paneel := _maak_overlay(0.55)
	var kol := paneel.get_child(0) as VBoxContainer
	kol.add_child(_lbl("DAG %d VAN 5" % (dag_index + 1), 10, Color("#8fb3ff"), true))
	kol.add_child(_lbl(String(dag["naam"]).to_upper(), 20, Color.WHITE, true))
	kol.add_child(UiKit.spacer(4))
	var nieuw := _lbl(String(dag["nieuw"]), 10, Color("#d6dbe8"), true)
	nieuw.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	kol.add_child(nieuw)
	var eigen_vak := RushData.vak_van(speler)
	if eigen_vak in dag["vakken"]:
		kol.add_child(UiKit.spacer(2))
		var zelf := _lbl("%s is jouw vak: dat doe je zelf, aan je eigen bureau." %
			RushData.VAK_NAAM[eigen_vak], 10, RushData.VAK_KLEUR[eigen_vak].lightened(0.3), true)
		zelf.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		kol.add_child(zelf)
	kol.add_child(UiKit.spacer(6))
	kol.add_child(_lbl("10 tickets live, dan mag je naar huis.", 10, Color("#8a93a8"), true))
	kol.add_child(_lbl("Voor 17:00 is drie sterren.", 10, Color("#8a93a8"), true))
	kol.add_child(UiKit.spacer(8))
	var knop := _knop("Aan de slag", true)
	knop.pressed.connect(func() -> void:
		_sluit_overlay()
		start.emit())
	kol.add_child(knop)


func toon_resultaat(dag_index: int, minuut: float, sterren: int, gebeld: int, laatste: bool,
		ontsnap_sec: float = -1.0, record: bool = false, plek: int = 0,
		score: Dictionary = {}) -> void:
	_laatste_regel = score
	var paneel := _maak_overlay(0.6)
	var kol := paneel.get_child(0) as VBoxContainer
	kol.add_child(_appje(RushData.KLANT_AVOND[dag_index], minuut))
	kol.add_child(UiKit.spacer(4))
	if laatste:
		kol.add_child(_lbl("VRIJHEID!", 20, Color("#3fd27f"), true))
		kol.add_child(_lbl("De webshop staat live.", 10, Color("#d6dbe8"), true))
	else:
		kol.add_child(_lbl("10/10", 20, Color("#3fd27f"), true))
		kol.add_child(_lbl("%s zit erop." % String(RushData.DAGEN[dag_index]["naam"]), 10, Color("#d6dbe8"), true))
	kol.add_child(UiKit.spacer(4))
	var sterrij := Control.new()
	sterrij.custom_minimum_size = Vector2(0, 22)
	sterrij.set_meta(&"te_zien", 0.0)
	sterrij.draw.connect(func() -> void: _teken_sterren(sterrij, sterren))
	kol.add_child(sterrij)
	# De sterren komen één voor één, met een tikje: dat is het moment van de dag.
	var tw := sterrij.create_tween()
	tw.tween_interval(0.35)
	for i: int in sterren:
		tw.tween_callback(func() -> void: RushKlank.sfx(&"rush_ster", &"pak", 0.0, -2.0))
		tw.tween_method(func(v: float) -> void:
			sterrij.set_meta(&"te_zien", v)
			sterrij.queue_redraw(), float(i), float(i + 1), 0.28)
	kol.add_child(UiKit.spacer(2))
	kol.add_child(_lbl("Naar huis om %s" % RushData.klok(minuut), 12, Color.WHITE, true))
	var regel := "Ze heeft niet gebeld." if gebeld == 0 else (
		"Ze belde 1 keer." if gebeld == 1 else "Ze belde %d keer." % gebeld)
	kol.add_child(_lbl(regel, 10, Color("#8a93a8"), true))
	if ontsnap_sec >= 0.0:
		var t := "Ontsnapt in %.1f s" % ontsnap_sec
		kol.add_child(_lbl(t + ("  · record!" if record else ""), 10,
			Color("#ff9f43") if record else Color("#8a93a8"), true))
	if sterren < 3:
		kol.add_child(_lbl("Drie sterren: thuis voor 17:00.", 10, Color("#8a93a8"), true))
	if laatste:
		kol.add_child(UiKit.spacer(2))
		kol.add_child(_lbl("Sprint 14: %d van de 15 sterren." % RushSave.totaal(), 12, Color("#ffd23f"), true))
	if plek > 0:
		kol.add_child(_lbl("#%d in de eregalerij van %s" % [plek, String(RushData.DAGEN[dag_index]["naam"]).to_lower()],
			10, Color("#ffd23f") if plek == 1 else Color("#8fb3ff"), true))
	kol.add_child(UiKit.spacer(8))
	if not laatste:
		var verder := _knop("Volgende dag", true)
		verder.pressed.connect(func() -> void: volgende.emit())
		kol.add_child(verder)
	else:
		var verder := _knop("Naar het weekend", true)
		verder.pressed.connect(func() -> void: naar_menu.emit())
		kol.add_child(verder)
	var nog := _knop("Nog een keer", false)
	nog.pressed.connect(func() -> void: opnieuw.emit())
	kol.add_child(nog)
	if not laatste:
		var menu := _knop("Menu", false)
		menu.pressed.connect(func() -> void: naar_menu.emit())
		kol.add_child(menu)
	# Even wachten voor de knoppen reageren: wie nog aan het tikken was,
	# drukt anders per ongeluk op "Nog een keer".
	for k: Node in kol.get_children():
		if k is Button:
			(k as Button).disabled = true
			get_tree().create_timer(0.6, true).timeout.connect(func() -> void:
				if is_instance_valid(k):
					(k as Button).disabled = false)


## Haar berichtje van die avond, als telefoonmelding.
func _appje(tekst: String, minuut: float) -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#fff7e8")
	sb.border_color = Color("#3fd27f")
	sb.set_border_width_all(1)
	sb.border_width_left = 3
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 3
	sb.content_margin_bottom = 4
	p.add_theme_stylebox_override(&"panel", sb)
	var kol := VBoxContainer.new()
	kol.add_theme_constant_override(&"separation", 0)
	p.add_child(kol)
	var rij := HBoxContainer.new()
	kol.add_child(rij)
	var wie := _lbl("Manege De Vrije Teugel", 10, Color("#1d7a52"))
	wie.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rij.add_child(wie)
	rij.add_child(_lbl(RushData.klok(minuut + 37.0), 10, Color("#8a8a8a")))
	var t := _lbl(tekst, 10, Color("#242424"))
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	kol.add_child(t)
	return p


func _teken_sterren(c: Control, n: int) -> void:
	var midden := c.size.x / 2.0
	var te_zien: float = c.get_meta(&"te_zien", 3.0)
	for i: int in 3:
		var p := Vector2(midden + (i - 1) * 24, 11)
		_ster(c, p, 9.0, Color("#3a4156"))
		if i < n and te_zien > i:
			# Even te groot, dan op maat: een stempel.
			var f := clampf(te_zien - i, 0.0, 1.0)
			var r := 9.0 * (1.0 + 0.6 * sin(f * PI) * (1.0 - f) + 0.0) if f < 1.0 else 9.0
			_ster(c, p, r, Color("#ffd23f"))


func _ster(c: Control, p: Vector2, r: float, k: Color) -> void:
	var pts := PackedVector2Array()
	for i: int in 10:
		var a := -PI / 2.0 + i * PI / 5.0
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(p + Vector2(cos(a), sin(a)) * rr)
	c.draw_colored_polygon(pts, k)


func _open_pauze() -> void:
	if _pauze != null or _overlay != null:
		return
	get_tree().paused = true
	var paneel := _maak_overlay(0.6, true)
	_pauze = paneel.get_parent()
	var kol := paneel.get_child(0) as VBoxContainer
	kol.add_child(_lbl("PAUZE", 20, Color.WHITE, true))
	kol.add_child(UiKit.spacer(8))
	var door := _knop("Doorgaan", true)
	door.pressed.connect(_sluit_pauze)
	kol.add_child(door)
	var nog := _knop("Dag opnieuw", false)
	nog.pressed.connect(func() -> void:
		_sluit_pauze()
		opnieuw.emit())
	kol.add_child(nog)
	var menu := _knop("Naar het menu", false)
	menu.pressed.connect(func() -> void:
		_sluit_pauze()
		naar_menu.emit())
	kol.add_child(menu)


func _sluit_pauze() -> void:
	if _pauze != null:
		_pauze.queue_free()
		_pauze = null
	get_tree().paused = false


func _sluit_overlay() -> void:
	if _overlay != null:
		_overlay.queue_free()
		_overlay = null


## Een dimlaag met een paneel in het midden. Geeft het paneel terug; zijn
## eerste kind is de kolom waar de inhoud in komt.
func _maak_overlay(dim: float, is_pauze: bool = false) -> PanelContainer:
	var laag := Control.new()
	laag.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(laag)
	UiKit.fill_viewport(laag)
	if not is_pauze:
		_sluit_overlay()
		_overlay = laag
	var dimmer := ColorRect.new()
	dimmer.color = Color(0.04, 0.05, 0.08, dim)
	dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	laag.add_child(dimmer)
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var midden := CenterContainer.new()
	midden.mouse_filter = Control.MOUSE_FILTER_IGNORE
	laag.add_child(midden)
	midden.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var paneel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#141824")
	sb.border_color = Color("#3a86ff")
	sb.set_border_width_all(1)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	paneel.add_theme_stylebox_override(&"panel", sb)
	paneel.custom_minimum_size = Vector2(170, 0)
	midden.add_child(paneel)
	var kol := VBoxContainer.new()
	kol.add_theme_constant_override(&"separation", 3)
	kol.custom_minimum_size = Vector2(150, 0)
	paneel.add_child(kol)

	paneel.scale = Vector2(0.9, 0.9)
	paneel.modulate.a = 0.0
	var tw := paneel.create_tween().set_parallel()
	tw.tween_property(paneel, ^"modulate:a", 1.0, 0.15)
	tw.tween_property(paneel, ^"scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	paneel.resized.connect(func() -> void: paneel.pivot_offset = paneel.size / 2.0)
	return paneel


func _lbl(t: String, maat: int, k: Color, midden: bool = false) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override(&"font", UiKit.font_voor(maat))
	l.add_theme_font_size_override(&"font_size", maat)
	l.add_theme_color_override(&"font_color", k)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if midden:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		# Gecentreerde regels mogen afbreken: anders duwt één lange zin het
		# hele paneel breder dan het scherm.
		if maat <= 12:
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _knop(t: String, primair: bool) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 28)
	b.add_theme_font_override(&"font", UiKit.FONT_12)
	b.add_theme_font_size_override(&"font_size", 12)
	var kleur := Color("#3a86ff") if primair else Color("#2a3042")
	b.add_theme_stylebox_override(&"normal", _vlak(kleur))
	b.add_theme_stylebox_override(&"hover", _vlak(kleur.lightened(0.12)))
	b.add_theme_stylebox_override(&"pressed", _vlak(kleur.darkened(0.15)))
	b.add_theme_stylebox_override(&"disabled", _vlak(kleur.darkened(0.3)))
	b.add_theme_color_override(&"font_color", Color.WHITE)
	b.add_theme_color_override(&"font_hover_color", Color.WHITE)
	b.add_theme_color_override(&"font_pressed_color", Color.WHITE)
	b.pressed.connect(func() -> void: RushKlank.ui(&"rush_knop"))
	return b


func _vlak(k: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = k
	sb.border_color = k.darkened(0.35)
	sb.set_border_width_all(1)
	return sb
