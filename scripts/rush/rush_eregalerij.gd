class_name RushEregalerij
extends Control
## De eregalerij: zoals op een arcadekast, per dag de beste tien van iedereen
## die op dít apparaat gespeeld heeft. Er gaat niets het apparaat uit; wie wil
## opscheppen deelt zelf een scorekaart (RushDeelkaart).
##
## Staat het online scorebord aan (`RushOnline.actief()`), dan komt er een
## tweede bron bij. Die functies (`haal`, `stuur`) bestaan nog niet; ze worden
## daarom dynamisch aangeroepen, zodat dit scherm nu parseert en meteen werkt
## zodra ze er zijn.

signal terug

const ACHTER := Color("#0b0e16")
const GOUD := Color("#ffd23f")
const ZILVER := Color("#c0c8d8")
const BRONS := Color("#cd7f32")
const BLAUW := Color("#3a86ff")
const LICHTBLAUW := Color("#8fb3ff")
const GRIJS := Color("#8a93a8")
const ORANJE := Color("#ff9f43")
const RIJ_H := 46

var _dag := 0
var _online := false
var _tijd := 0.0
var _vraag := 0
var _achter: ColorRect
var _titel: Label
var _onder_titel: Label
var _knipper: Label
var _dagknoppen: Array[Button] = []
var _bronknoppen: Array[Button] = []
var _lijst: VBoxContainer
var _scroll: ScrollContainer
var _kroon: Control = null


func _ready() -> void:
	RushSave.laad()
	_dag = clampi(RushSave.dag, 0, RushData.DAGEN.size() - 1)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_achter = ColorRect.new()
	_achter.color = ACHTER
	_achter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_achter)
	_achter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_achter.draw.connect(_teken_achter)

	var veilig := UiKit.veilige_laag(self)
	var marge := MarginContainer.new()
	veilig.add_child(marge)
	marge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for k: String in ["left", "right"]:
		marge.add_theme_constant_override("margin_" + k, 6)
	marge.add_theme_constant_override(&"margin_top", 10)
	marge.add_theme_constant_override(&"margin_bottom", 8)
	var kol := VBoxContainer.new()
	kol.add_theme_constant_override(&"separation", 4)
	marge.add_child(kol)

	_titel = _lbl("EREGALERIJ", 20, GOUD, true)
	kol.add_child(_titel)
	_onder_titel = _lbl("", 10, GRIJS, true)
	kol.add_child(_onder_titel)

	if RushOnline.actief():
		var bron := HBoxContainer.new()
		bron.add_theme_constant_override(&"separation", 2)
		for i: int in 2:
			var b := _tab(["HIER", "ONLINE"][i])
			b.pressed.connect(func() -> void: _kies_bron(i == 1))
			bron.add_child(b)
			_bronknoppen.append(b)
		kol.add_child(bron)

	var dagen := HBoxContainer.new()
	dagen.add_theme_constant_override(&"separation", 2)
	for i: int in RushData.DAGEN.size():
		var b := _tab(String(RushData.DAGEN[i]["kort"]))
		b.pressed.connect(func() -> void: _kies_dag(i))
		dagen.add_child(b)
		_dagknoppen.append(b)
	kol.add_child(dagen)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	RushVeeg.koppel(_scroll)
	_stijl_balk(_scroll.get_v_scroll_bar())
	kol.add_child(_scroll)
	_lijst = VBoxContainer.new()
	_lijst.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lijst.add_theme_constant_override(&"separation", 3)
	_scroll.add_child(_lijst)

	_knipper = _lbl("- INSERT TICKET -", 10, ORANJE, true)
	kol.add_child(_knipper)
	var weg := _knop("Terug")
	weg.pressed.connect(func() -> void: terug.emit())
	kol.add_child(weg)

	_toon()


func _process(delta: float) -> void:
	_tijd += delta
	# Arcade: de kop wisselt van goud naar oranje en de oproep knippert, maar
	# langzaam genoeg dat je het op een telefoon nog leest.
	_titel.add_theme_color_override(&"font_color", GOUD.lerp(ORANJE, 0.5 + 0.5 * sin(_tijd * 3.0)))
	_knipper.modulate.a = 1.0 if fmod(_tijd, 1.2) < 0.8 else 0.0
	_achter.queue_redraw()
	if is_instance_valid(_kroon):
		_kroon.queue_redraw()


func _kies_dag(i: int) -> void:
	RushKlank.ui(&"rush_knop")
	_dag = i
	_toon()


func _kies_bron(online: bool) -> void:
	RushKlank.ui(&"rush_knop")
	_online = online
	_toon()


func _toon() -> void:
	for i: int in _dagknoppen.size():
		_zet_tab(_dagknoppen[i], i == _dag)
	for i: int in _bronknoppen.size():
		_zet_tab(_bronknoppen[i], (i == 1) == _online)
	_onder_titel.text = "Iedereen die online zette" if _online else "De beste tien van dit apparaat"
	_vraag += 1
	if _online and _kan_online(&"haal"):
		_toon_online(_vraag)
	else:
		_vul(RushSave.scores_van(_dag), false)


## Het online bord, als het er is. `nummer` vangt een oud antwoord af: wie
## tijdens het laden van dag wisselt, wil niet het bord van de vorige dag zien.
func _toon_online(nummer: int) -> void:
	_leeg()
	var laad := _lbl("LADEN...", 12, LICHTBLAUW, true)
	laad.custom_minimum_size = Vector2(0, 60)
	laad.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lijst.add_child(laad)
	var online: Object = RushOnline
	var uit: Variant = await online.call(&"haal", self, _dag)
	if nummer != _vraag or not is_inside_tree():
		return
	var regels: Array[Dictionary] = []
	if uit is Array:
		for r: Variant in uit:
			if r is Dictionary:
				regels.append(r)
	_vul(regels, true)


func _vul(regels: Array, online: bool) -> void:
	_leeg()
	_scroll.scroll_vertical = 0
	if regels.is_empty():
		_lijst.add_child(UiKit.spacer(30))
		_lijst.add_child(_lbl("Nog niemand naar huis gegaan." if not online
			else "Online nog niemand.", 12, Color.WHITE, true))
		var sub := _lbl("Speel %s uit en zet de eerste naam op de kast." %
			String(RushData.DAGEN[_dag]["naam"]).to_lower(), 10, GRIJS, true)
		_lijst.add_child(sub)
		return
	for i: int in mini(regels.size(), RushSave.SCORES_PER_DAG):
		_lijst.add_child(_rij(i + 1, regels[i]))


func _leeg() -> void:
	for k: Node in _lijst.get_children():
		k.queue_free()
	_kroon = null


# --- Eén regel op de kast -------------------------------------------------------

func _rij(plek: int, r: Dictionary) -> Control:
	var kleur := _plekkleur(plek)
	var vak := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = kleur.darkened(0.82) if plek <= 3 else Color("#141824")
	sb.border_color = kleur if plek <= 3 else Color("#2a3042")
	sb.set_border_width_all(2 if plek == 1 else 1)
	sb.content_margin_left = 2
	sb.content_margin_right = 4
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	vak.add_theme_stylebox_override(&"panel", sb)
	vak.custom_minimum_size = Vector2(0, RIJ_H)
	vak.mouse_filter = Control.MOUSE_FILTER_PASS
	var rij := HBoxContainer.new()
	rij.add_theme_constant_override(&"separation", 3)
	vak.add_child(rij)

	# Plek, met een kroontje boven nummer één.
	var nr := Control.new()
	nr.custom_minimum_size = Vector2(18, 0)
	nr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cijfer := _lbl(str(plek), 16 if plek <= 3 else 12, kleur if plek <= 3 else GRIJS, true)
	cijfer.autowrap_mode = TextServer.AUTOWRAP_OFF
	nr.add_child(cijfer)
	cijfer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cijfer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if plek == 1:
		cijfer.offset_top = 8
		_kroon = nr
		nr.draw.connect(func() -> void: _teken_kroon(nr))
	rij.add_child(nr)

	# Het portret op ware grootte, in een lijstje.
	var lijst := PanelContainer.new()
	var lsb := StyleBoxFlat.new()
	lsb.bg_color = Color("#1f2433")
	lsb.border_color = kleur if plek <= 3 else Color("#3a4156")
	lsb.set_border_width_all(1)
	lijst.add_theme_stylebox_override(&"panel", lsb)
	lijst.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lijst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var foto := TextureRect.new()
	foto.custom_minimum_size = Vector2(RushPixel.B, RushPixel.H)
	foto.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	foto.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	foto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var img := RushDeelkaart._portret(r)
	if img != null:
		foto.texture = ImageTexture.create_from_image(img)
	lijst.add_child(foto)
	rij.add_child(lijst)

	# Naam, rol, tijd; sterren rechtsboven.
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override(&"separation", -3)
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rij.add_child(info)
	var boven := HBoxContainer.new()
	boven.add_theme_constant_override(&"separation", 2)
	info.add_child(boven)
	var naam := _lbl(String(r.get("naam", "?")), 12, Color.WHITE)
	_eenregelig(naam)
	naam.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boven.add_child(naam)
	var sterren := clampi(int(r.get("sterren", 0)), 0, 3)
	var st := Control.new()
	st.custom_minimum_size = Vector2(26, 12)
	st.mouse_filter = Control.MOUSE_FILTER_IGNORE
	st.draw.connect(func() -> void:
		for s: int in 3:
			_ster(st, Vector2(4 + s * 9, 7), 4.0, GOUD if s < sterren else Color("#2f3649")))
	boven.add_child(st)
	var rol := _lbl(String(r.get("rol", "")), 10, GRIJS)
	_eenregelig(rol)
	info.add_child(rol)
	var onder := HBoxContainer.new()
	onder.add_theme_constant_override(&"separation", 4)
	info.add_child(onder)
	var klok := _lbl(RushData.klok(float(r.get("minuut", 0.0))), 12, kleur if plek <= 3 else LICHTBLAUW)
	klok.autowrap_mode = TextServer.AUTOWRAP_OFF
	onder.add_child(klok)
	var ontsnap := float(r.get("ontsnap", -1.0))
	if ontsnap >= 0.0:
		var o := _lbl("uit in %.1fs" % ontsnap, 10, ORANJE)
		_eenregelig(o)
		o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		o.size_flags_vertical = Control.SIZE_SHRINK_END
		onder.add_child(o)
	return vak


func _plekkleur(plek: int) -> Color:
	match plek:
		1: return GOUD
		2: return ZILVER
		3: return BRONS
	return GRIJS


func _teken_kroon(c: Control) -> void:
	# Drie punten en een band, met een glinstering die rondloopt.
	var m := Vector2(c.size.x / 2.0, 7.0 + sin(_tijd * 4.0) * 0.6)
	var pts := PackedVector2Array([
		m + Vector2(-6, 3), m + Vector2(-6, -3), m + Vector2(-3, 0), m + Vector2(0, -5),
		m + Vector2(3, 0), m + Vector2(6, -3), m + Vector2(6, 3)])
	c.draw_colored_polygon(pts, GOUD)
	c.draw_rect(Rect2(m + Vector2(-6, 3), Vector2(13, 2)), ORANJE)
	var glim := int(_tijd * 3.0) % 3
	c.draw_rect(Rect2(m + Vector2(-6 + glim * 6, -4 + (1 if glim == 1 else 0) * -1), Vector2(1, 1)), Color.WHITE)


func _teken_achter() -> void:
	# Scanlijnen en een dun kader, zoals het glas van een kast.
	var s := _achter.size
	var k := Color(1, 1, 1, 0.025)
	var y := 0.0
	while y < s.y:
		_achter.draw_rect(Rect2(0, y, s.x, 1), k)
		y += 3.0
	var rand := GOUD.lerp(ORANJE, 0.5 + 0.5 * sin(_tijd * 3.0))
	rand.a = 0.6
	_achter.draw_rect(Rect2(1, 1, s.x - 2, s.y - 2), rand, false, 1.0)


# --- Bouwstenen -----------------------------------------------------------------

## Een rijtje dat je moet kunnen lezen, niet afbreken: met puntjes als het te
## lang is (zie het geheugen over labels die in een HBox worden platgeknepen).
func _eenregelig(l: Label) -> void:
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.custom_minimum_size = Vector2(10, 0)


func _kan_online(functie: StringName) -> bool:
	var online: Object = RushOnline
	return RushOnline.actief() and online.has_method(functie)


func _tab(t: String) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 26)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_override(&"font", UiKit.FONT_12)
	b.add_theme_font_size_override(&"font_size", 12)
	return b


func _zet_tab(b: Button, aan: bool) -> void:
	var kleur := Color("#3a2f0c") if aan else Color("#1a1f2e")
	var rand := GOUD if aan else Color("#2f3649")
	for s: String in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = kleur.lightened(0.08) if s == "hover" and not aan else kleur
		sb.border_color = rand
		sb.set_border_width_all(1)
		if aan:
			sb.border_width_bottom = 3
		b.add_theme_stylebox_override(s, sb)
	var tekst := GOUD if aan else GRIJS
	for s: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color"]:
		b.add_theme_color_override(s, tekst)


func _stijl_balk(balk: VScrollBar) -> void:
	balk.custom_minimum_size = Vector2(3, 0)
	var leeg := StyleBoxFlat.new()
	leeg.bg_color = Color("#1a1f2e")
	balk.add_theme_stylebox_override(&"scroll", leeg)
	for s: StringName in [&"grabber", &"grabber_highlight", &"grabber_pressed"]:
		var g := StyleBoxFlat.new()
		g.bg_color = GOUD.darkened(0.3)
		balk.add_theme_stylebox_override(s, g)


func _lbl(t: String, maat: int, k: Color, midden: bool = false) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override(&"font", UiKit.font_voor(maat))
	l.add_theme_font_size_override(&"font_size", maat)
	l.add_theme_color_override(&"font_color", k)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if midden:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if maat <= 12:
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _knop(t: String) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 30)
	b.add_theme_font_override(&"font", UiKit.FONT_12)
	b.add_theme_font_size_override(&"font_size", 12)
	var kleur := Color("#2a3042")
	for s: String in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = kleur.lightened(0.1) if s == "hover" else (kleur.darkened(0.15) if s == "pressed" else kleur)
		sb.border_color = kleur.darkened(0.35)
		sb.set_border_width_all(1)
		b.add_theme_stylebox_override(s, sb)
	b.add_theme_color_override(&"font_color", Color.WHITE)
	b.add_theme_color_override(&"font_hover_color", Color.WHITE)
	b.add_theme_color_override(&"font_pressed_color", Color.WHITE)
	b.pressed.connect(func() -> void: RushKlank.ui(&"rush_knop"))
	return b


func _ster(c: Control, p: Vector2, r: float, k: Color) -> void:
	var pts := PackedVector2Array()
	for i: int in 10:
		var a := -PI / 2.0 + i * PI / 5.0
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(p + Vector2(cos(a), sin(a)) * rr)
	c.draw_colored_polygon(pts, k)
