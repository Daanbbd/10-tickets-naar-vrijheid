extends Control
## Titel, personagekeuze en de week. Drie schermen in één scene: er valt te
## weinig te kiezen om er drie losse scenes van te maken.

const GAME := "res://scenes/rush/rush_game.tscn"
const PAARD := preload("res://assets/sprites/props/paard_klant.png")

var _inhoud: Control
var _gekozen: StringName = &""
var _tijd := 0.0
var _deco: Control


func _ready() -> void:
	RushSave.laad()
	UiKit.fill_viewport(self)
	var bg := ColorRect.new()
	bg.color = Color("#141824")
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# De aankleding tekent op de achtergrond zelf, zodat hij er gegarandeerd
	# onder ligt.
	_deco = bg
	_deco.draw.connect(_teken_deco)
	_inhoud = MarginContainer.new()
	add_child(_inhoud)
	_inhoud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for k: String in ["left", "right"]:
		_inhoud.add_theme_constant_override("margin_" + k, 10)
	_inhoud.add_theme_constant_override(&"margin_top", 14)
	_inhoud.add_theme_constant_override(&"margin_bottom", 12)
	AudioDirector.stop_music(0.3)
	AudioDirector.set_base(&"intro", 0.6)
	_titel()


func _process(delta: float) -> void:
	_tijd += delta
	_deco.queue_redraw()


func _leeg() -> VBoxContainer:
	for k: Node in _inhoud.get_children():
		k.queue_free()
	var kol := VBoxContainer.new()
	kol.add_theme_constant_override(&"separation", 4)
	_inhoud.add_child(kol)
	return kol


# --- Titel ----------------------------------------------------------------------

func _titel() -> void:
	var kol := _leeg()
	kol.alignment = BoxContainer.ALIGNMENT_CENTER
	kol.add_child(_vul())
	kol.add_child(_lbl("10 TICKETS", 30, Color("#3a86ff"), true))
	kol.add_child(_lbl("NAAR VRIJHEID", 16, Color("#8fb3ff"), true))
	kol.add_child(UiKit.spacer(6))
	var sub := _lbl("De webshop voor paardensupplementen moet vrijdag live. De klant heeft het al aan de dierenarts verteld.", 10, Color("#b0b4c2"), true)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	kol.add_child(sub)
	kol.add_child(_vul())
	var sterren := RushSave.totaal()
	if sterren > 0:
		kol.add_child(_lbl("%d van 15 sterren" % sterren, 10, Color("#ffd23f"), true))
	var spelen := _knop("Spelen", true)
	spelen.pressed.connect(func() -> void:
		if RushSave.karakter == &"":
			_kies()
		else:
			_week())
	kol.add_child(spelen)
	if RushSave.karakter != &"":
		var wissel := _knop("Wie ben jij?", false)
		wissel.pressed.connect(_kies)
		kol.add_child(wissel)
	kol.add_child(UiKit.spacer(4))
	kol.add_child(_lbl("Een spel over een werkweek bij Bluebird Day", 10, Color("#5a6278"), true))


# --- Wie ben jij ----------------------------------------------------------------

func _kies() -> void:
	_gekozen = RushSave.karakter if RushSave.karakter != &"" else &"victor"
	_toon_kies()


func _toon_kies() -> void:
	var kol := _leeg()
	kol.add_child(_lbl("WIE BEN JIJ?", 20, Color("#3a86ff"), true))
	kol.add_child(_lbl("Jouw eigen vak doe je zelf. De rest breng je rond.", 10, Color("#b0b4c2"), true))
	kol.add_child(UiKit.spacer(4))

	var raster := GridContainer.new()
	raster.columns = 4
	raster.add_theme_constant_override(&"h_separation", 4)
	raster.add_theme_constant_override(&"v_separation", 4)
	var midden := CenterContainer.new()
	midden.add_child(raster)
	kol.add_child(midden)
	for id: StringName in RushData.BUREAU_VOLGORDE:
		raster.add_child(_portretknop(id))

	kol.add_child(UiKit.spacer(6))
	var def: CharacterDef = GameData.character(_gekozen)
	var vak := RushData.vak_van(_gekozen)
	var kleur: Color = RushData.VAK_KLEUR[vak]
	kol.add_child(_lbl(def.name if def != null else String(_gekozen), 16, Color.WHITE, true))
	kol.add_child(_lbl(def.role if def != null else "", 10, Color("#b0b4c2"), true))
	kol.add_child(_lbl("Jouw vak: %s" % RushData.VAK_NAAM[vak], 12, kleur.lightened(0.2), true))
	if def != null and def.tagline != "":
		var tag := _lbl("\"%s\"" % def.tagline, 10, Color("#f4a259"), true)
		tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		kol.add_child(tag)
	kol.add_child(_vul())
	var ok := _knop("Dit ben ik", true)
	ok.pressed.connect(func() -> void:
		RushSave.karakter = _gekozen
		RushSave.bewaar()
		_week())
	kol.add_child(ok)
	var terug := _knop("Terug", false)
	terug.pressed.connect(_titel)
	kol.add_child(terug)


func _portretknop(id: StringName) -> Control:
	var def: CharacterDef = GameData.character(id)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(40, 52)
	var kleur: Color = RushData.VAK_KLEUR[RushData.vak_van(id)]
	var gekozen := id == _gekozen
	var sb := StyleBoxFlat.new()
	sb.bg_color = kleur.darkened(0.55) if gekozen else Color("#1f2433")
	sb.border_color = kleur if gekozen else Color("#2f3649")
	sb.set_border_width_all(2 if gekozen else 1)
	for s: String in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(s, sb)
	if def != null and def.portrait != "" and ResourceLoader.exists(def.portrait):
		var foto := TextureRect.new()
		foto.texture = load(def.portrait)
		foto.position = Vector2(4, 3)
		foto.size = Vector2(32, 40)
		foto.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(foto)
	var band := ColorRect.new()
	band.color = kleur
	band.position = Vector2(4, 45)
	band.size = Vector2(32, 3)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(band)
	b.pressed.connect(func() -> void:
		AudioDirector.play_ui(&"klik")
		Haptiek.tril(Haptiek.Sterkte.TIK)
		_gekozen = id
		_toon_kies())
	return b


# --- De week --------------------------------------------------------------------

func _week() -> void:
	var kol := _leeg()
	kol.add_child(_lbl("SPRINT 14", 20, Color("#3a86ff"), true))
	var def: CharacterDef = GameData.character(RushSave.karakter)
	kol.add_child(_lbl("Jij bent %s. Tien tickets per dag." % (def.name if def != null else "?"), 10, Color("#b0b4c2"), true))
	kol.add_child(UiKit.spacer(6))
	var open := RushSave.open_dag()
	for i: int in RushData.DAGEN.size():
		kol.add_child(_dagknop(i, i == open))
	kol.add_child(_vul())
	kol.add_child(_lbl("Drie sterren: voor 17:00 thuis.", 10, Color("#8a93a8"), true))
	var terug := _knop("Terug", false)
	terug.pressed.connect(_titel)
	kol.add_child(terug)


func _dagknop(i: int, is_volgende: bool) -> Control:
	var d: Dictionary = RushData.DAGEN[i]
	var open := RushSave.is_open(i)
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 40)
	b.disabled = not open
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#22304f") if is_volgende else Color("#1f2433")
	sb.border_color = Color("#3a86ff") if is_volgende else Color("#2f3649")
	sb.set_border_width_all(1)
	for s: String in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(s, sb)
	var naam := _lbl(String(d["naam"]), 12, Color.WHITE if open else Color("#4a5268"))
	naam.position = Vector2(8, 5)
	b.add_child(naam)
	var uitleg := _lbl(_dag_samenvatting(i) if open else "Eerst de dag ervoor", 10,
		Color("#8a93a8") if open else Color("#3a4156"))
	uitleg.position = Vector2(8, 21)
	b.add_child(uitleg)
	var sterren: int = RushSave.sterren[i]
	var st := Control.new()
	st.mouse_filter = Control.MOUSE_FILTER_IGNORE
	st.position = Vector2(0, 0)
	st.size = Vector2(172, 40)
	st.draw.connect(func() -> void:
		for s: int in 3:
			_ster(st, Vector2(st.size.x - 34 + s * 11, 13), 4.5,
				Color("#ffd23f") if s < sterren else Color("#2f3649")))
	b.add_child(st)
	b.resized.connect(func() -> void: st.size = b.size)
	b.pressed.connect(func() -> void:
		AudioDirector.play_ui(&"klik")
		RushSave.dag = i
		get_tree().change_scene_to_file(GAME))
	return b


func _dag_samenvatting(i: int) -> String:
	return ["Frontend en backend", "+ Danny en koffie", "+ Willem en de stand-up",
		"+ Daan en Dirk", "Livegang"][i]


func _ster(c: Control, p: Vector2, r: float, k: Color) -> void:
	var pts := PackedVector2Array()
	for i: int in 10:
		var a := -PI / 2.0 + i * PI / 5.0
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(p + Vector2(cos(a), sin(a)) * rr)
	c.draw_colored_polygon(pts, k)


# --- Aankleding: tickets die rustig door het beeld zweven -----------------------

func _teken_deco() -> void:
	var s := _deco.size
	var kleuren: Array = RushData.VAK_KLEUR.values()
	for i: int in 9:
		var f := fmod(_tijd * (0.04 + i * 0.006) + i * 0.137, 1.0)
		var x := fmod(i * 47.0 + sin(_tijd * 0.5 + i) * 6.0, s.x)
		var y := s.y + 20 - f * (s.y + 40)
		var k: Color = kleuren[i % kleuren.size()]
		var a := 0.22
		_deco.draw_rect(Rect2(x, y, 12, 14), Color(0.98, 0.97, 0.94, a))
		_deco.draw_rect(Rect2(x, y, 12, 4), Color(k.r, k.g, k.b, a))
	_deco.draw_texture(PAARD, Vector2(s.x - 40, s.y - 44 + sin(_tijd * 2.0) * 2.0), Color(1, 1, 1, 0.5))


# --- Bouwstenen -----------------------------------------------------------------

func _vul() -> Control:
	var c := Control.new()
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


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
	b.custom_minimum_size = Vector2(0, 30)
	b.add_theme_font_override(&"font", UiKit.FONT_12)
	b.add_theme_font_size_override(&"font_size", 12)
	var kleur := Color("#3a86ff") if primair else Color("#2a3042")
	for s: String in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = kleur.lightened(0.1) if s == "hover" else (kleur.darkened(0.15) if s == "pressed" else kleur)
		sb.border_color = kleur.darkened(0.35)
		sb.set_border_width_all(1)
		b.add_theme_stylebox_override(s, sb)
	b.add_theme_color_override(&"font_color", Color.WHITE)
	b.add_theme_color_override(&"font_hover_color", Color.WHITE)
	b.add_theme_color_override(&"font_pressed_color", Color.WHITE)
	b.pressed.connect(func() -> void: AudioDirector.play_ui(&"klik"))
	return b
