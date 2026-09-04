extends MinigameBase
## BBD-207 — A tegen B. Danny's tweede A/B-getinte ticket, maar dit is geen
## meting zoals BBD-206/`mg_abtest.gd`: dit is een gevecht. A moet B binnen
## drie klappen knock-outen. Elke klap is een CRO-tweak die schade doet én
## terugslaat — de vraag is niet of iets werkt, maar of het genoeg werkt om de
## tegenklap waard te zijn. Precies het "aanzetten en kijken" van Danny's
## andere ticket, alleen ziet dit er als een bokspartij uit in plaats van als
## een grafiek.
##
## Verliest A, dan blijft het ticket open en komt Danny terug met een steeds
## absurdere reden om het nog een keer te proberen — data die naar B wijst is
## voor hem per definitie niet datagedreven genoeg. De teller die dat
## bijhoudt (`Session.get_counter(&"ab_pogingen")`) wordt hier opgehoogd; de
## oplopende regels zelf staan in `data/dialogue/tickets.json` bij `t07_fail`,
## niet in deze minigame.

## Lang genoeg om een klap te zien landen, kort genoeg om drie keer te doen.
const MEET_DUUR := 0.5

var _hp_a_max: float = 100.0
var _hp_b_max: float = 100.0
var _hp_a: float = 100.0
var _hp_b: float = 100.0

var _ronde: int = 0
var _keuzes: Array[String] = []
var _bezig: bool = false
var _qa_loopt: bool = false
var _afgerond: bool = false

var _meting: Tween = null

var _vulling_a: ColorRect = null
var _vulling_b: ColorRect = null
var _waarde_a: Label = null
var _waarde_b: Label = null
var _blok: Array[PanelContainer] = []
var _blok_tekst: Array[Label] = []

var _vraag: Label = null
var _varianten: VBoxContainer = null
var _regel: Label = null
var _volgende_knop: Button = null


func _on_setup() -> void:
	var c := content()
	if c.is_empty() or _rondes().is_empty():
		fail()
		return

	_hp_a_max = maxf(1.0, float(c.get("hp_a", 100.0)))
	_hp_b_max = maxf(1.0, float(c.get("hp_b", 100.0)))
	_hp_a = _hp_a_max
	_hp_b = _hp_b_max

	var body := build_chrome(default_title(), String(c.get("intro", "")))

	# Beide levensbalken horen niet in de scroll: dit zijn de twee dingen die
	# je op elk moment nodig hebt, net als de tijdbalk in `mg_standup.gd`. De
	# Volgende-knop is dezelfde afspraak voor je duim.
	chrome_header().add_child(_bouw_meters())
	_volgende_knop = _bouw_volgende()
	chrome_footer().add_child(_volgende_knop)

	# Vraag en Danny's commentaar op de chrome zelf, niet op een witte kaart
	# erboven: WIT en BLUEBIRD_BRIGHT, want INK en bb-blue verdwijnen allebei
	# in het donkere oppervlak. Zelfde keuze als `mg_abtest.gd`.
	_vraag = UiKit.label("", UiKit.FS_BODY, UiKit.WIT)
	body.add_child(_vraag)

	_varianten = VBoxContainer.new()
	_varianten.add_theme_constant_override("separation", 2)
	body.add_child(_varianten)

	_regel = UiKit.label("", UiKit.FS_SMALL, UiKit.BLUEBIRD_BRIGHT)
	_regel.visible = false
	body.add_child(_regel)

	_zet_meters()
	_toon_ronde()


func _exit_tree() -> void:
	if _meting != null and _meting.is_valid():
		_meting.kill()


# --- Meters ----------------------------------------------------------------

func _bouw_meters() -> VBoxContainer:
	var kol := VBoxContainer.new()
	kol.add_theme_constant_override("separation", 3)

	var rij_a := HBoxContainer.new()
	var lbl_a := UiKit.label("A", UiKit.FS_SMALL, UiKit.WIT)
	rij_a.add_child(lbl_a)
	_waarde_a = UiKit.label("", UiKit.FS_SMALL, UiKit.WIT)
	_waarde_a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_waarde_a.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rij_a.add_child(_waarde_a)
	kol.add_child(rij_a)
	var vak_a := Control.new()
	vak_a.custom_minimum_size = Vector2(0, 7)
	vak_a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vak_a.add_child(_spoor())
	_vulling_a = _rect(UiKit.GROEN)
	vak_a.add_child(_vulling_a)
	kol.add_child(vak_a)

	var rij_b := HBoxContainer.new()
	var lbl_b := UiKit.label("B", UiKit.FS_SMALL, UiKit.WIT)
	rij_b.add_child(lbl_b)
	_waarde_b = UiKit.label("", UiKit.FS_SMALL, UiKit.WIT)
	_waarde_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_waarde_b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rij_b.add_child(_waarde_b)
	kol.add_child(rij_b)
	var vak_b := Control.new()
	vak_b.custom_minimum_size = Vector2(0, 7)
	vak_b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vak_b.add_child(_spoor())
	_vulling_b = _rect(UiKit.ROOD)
	vak_b.add_child(_vulling_b)
	kol.add_child(vak_b)

	# Het verloop: drie blokjes die tonen welke ronde je had en of die raakte.
	# Dezelfde vorm als `mg_abtest.gd`'s `_blok`, zodat het gevecht een
	# geschiedenis toont en niet alleen een stand.
	var verloop := HBoxContainer.new()
	verloop.add_theme_constant_override("separation", 2)
	for i: int in _rondes().size():
		var vak := PanelContainer.new()
		vak.add_theme_stylebox_override("panel", UiKit.panel_krap(UiKit.NEUTRAAL_TINT, UiKit.LINE))
		vak.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var t := UiKit.label("·", UiKit.FS_SMALL, UiKit.GRIJS_OP_LICHT)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vak.add_child(t)
		verloop.add_child(vak)
		_blok.append(vak)
		_blok_tekst.append(t)
	kol.add_child(verloop)

	return kol


func _spoor() -> ColorRect:
	var r := _rect(UiKit.NEUTRAAL_TINT)
	return r


func _rect(kleur: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = kleur
	UiKit.full_rect(r)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _zet_meters() -> void:
	_waarde_a.text = "%d/%d" % [maxi(0, roundi(_hp_a)), roundi(_hp_a_max)]
	_vulling_a.anchor_right = clampf(_hp_a / _hp_a_max, 0.0, 1.0)
	_waarde_b.text = "%d/%d" % [maxi(0, roundi(_hp_b)), roundi(_hp_b_max)]
	_vulling_b.anchor_right = clampf(_hp_b / _hp_b_max, 0.0, 1.0)


func _bouw_volgende() -> Button:
	var b := UiKit.knop_primair("Volgende", UiKit.FS_SMALL)
	b.custom_minimum_size = Vector2(0, 26)
	b.add_theme_stylebox_override("disabled", UiKit.panel(UiKit.NEUTRAAL_TINT, UiKit.LINE))
	b.add_theme_color_override("font_disabled_color", UiKit.GRIJS)
	b.disabled = true
	b.pressed.connect(_volgende)
	return b


# --- Rondes ------------------------------------------------------------

func _toon_ronde() -> void:
	var rondes := _rondes()
	var r := rondes[_ronde] as Dictionary
	_vraag.text = String(r.get("vraag", ""))
	set_status("Ronde %d/%d" % [_ronde + 1, rondes.size()])
	_regel.text = ""
	_regel.visible = false
	_volgende_knop.text = "Afronden" if _ronde == rondes.size() - 1 else "Volgende"
	_volgende_knop.disabled = true

	for oud: Node in _varianten.get_children():
		_varianten.remove_child(oud)
		oud.queue_free()

	var varianten := r.get("varianten", []) as Array
	for i: int in varianten.size():
		var v := varianten[i] as Dictionary
		var b := UiKit.keuzeknop(_variant_label(v), UiKit.FS_SMALL)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_stylebox_override("disabled", UiKit.panel(UiKit.NEUTRAAL_TINT, UiKit.LINE))
		b.add_theme_color_override("font_disabled_color", UiKit.GRIJS)
		b.pressed.connect(_kies.bind(i))
		_varianten.add_child(b)

	if _varianten.get_child_count() > 0:
		(_varianten.get_child(0) as Button).grab_focus()


func _kies(index: int) -> void:
	if _bezig or _afgerond or _volgende_knop == null or not _volgende_knop.disabled:
		return
	var v := _variant(_ronde, index)
	if v.is_empty():
		return

	_bezig = true
	AudioDirector.play_ui(&"klik")
	_keuzes.append(String(v.get("label", "")))

	for i: int in _varianten.get_child_count():
		var b := _varianten.get_child(i) as Button
		b.disabled = true
		if i == index:
			b.add_theme_stylebox_override("disabled", UiKit.panel(UiKit.BLUEBIRD_TINT, UiKit.INK))
			b.add_theme_color_override("font_disabled_color", UiKit.INK)

	var schade := float(v.get("schade", 0.0))
	var tegenklap := float(v.get("tegenklap", 0.0))
	await _meet(schade, tegenklap)
	if not is_inside_tree():
		return

	_zet_verloop(_ronde, schade, tegenklap)
	_regel.text = String(v.get("regel", ""))
	_regel.visible = true
	AudioDirector.play_ui(&"pak")
	_bezig = false

	# Een KO onderbreekt het gevecht meteen — geen reden om op "Volgende" te
	# wachten als er niets meer te kiezen valt.
	if _hp_a <= 0.0 or _hp_b <= 0.0:
		await _afronden()
		return

	_volgende_knop.disabled = false
	_volgende_knop.grab_focus()


## De klap moet landen, niet alleen een nieuw getal tonen: beide balken
## bewegen tegelijk, want dezelfde klap kost en levert in één beweging.
func _meet(schade: float, tegenklap: float) -> void:
	var van_a := _hp_a
	var van_b := _hp_b
	var naar_a := maxf(0.0, van_a - tegenklap)
	var naar_b := maxf(0.0, van_b - schade)
	if _meting != null and _meting.is_valid():
		_meting.kill()
	_meting = create_tween()
	_meting.set_parallel(true)
	var zet_a := func(v: float) -> void:
		_hp_a = v
		_zet_meters()
	var zet_b := func(v: float) -> void:
		_hp_b = v
		_zet_meters()
	_meting.tween_method(zet_a, van_a, naar_a, MEET_DUUR) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_meting.tween_method(zet_b, van_b, naar_b, MEET_DUUR) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _meting.finished
	_hp_a = naar_a
	_hp_b = naar_b
	_zet_meters()


func _zet_verloop(ronde: int, schade: float, tegenklap: float) -> void:
	if ronde >= _blok.size():
		return
	var raak := schade > tegenklap
	_blok[ronde].add_theme_stylebox_override("panel",
		UiKit.panel_krap(UiKit.GROEN if raak else UiKit.ROOD, UiKit.INK))
	_blok_tekst[ronde].text = "%+d" % roundi(schade - tegenklap)
	_blok_tekst[ronde].add_theme_color_override("font_color", UiKit.INK)


func _volgende() -> void:
	if _bezig or _afgerond:
		return
	_ronde += 1
	if _ronde >= _rondes().size() or _hp_a <= 0.0 or _hp_b <= 0.0:
		await _afronden()
	else:
		_toon_ronde()


## A wint als B eerder nul staat dan A. Blijft B overeind tot de laatste
## ronde voorbij is, dan wint B op punten — precies zoals "niets doen" in
## `mg_abtest.gd` de doelstelling nooit haalt.
func _afronden() -> void:
	if _afgerond:
		return
	_afgerond = true
	var c := content()
	var a_wint := _hp_b <= 0.0 and _hp_a > 0.0
	_volgende_knop.disabled = true

	if not a_wint:
		Session.add_counter(&"ab_pogingen")

	await finish_with_banner(a_wint,
		String(c.get("success" if a_wint else "failure", "")),
		maxi(0, roundi(_hp_a)),
		{
			&"a_wint": a_wint,
			&"hp_a_over": _hp_a,
			&"hp_b_over": _hp_b,
			&"keuzes": _keuzes,
		})


# --- Data ----------------------------------------------------------------

func _rondes() -> Array:
	return content().get("rondes", []) as Array


## Het label van een variant, met bij eigen vakgebied de tegenklap erachter —
## nooit de schade. Danny weet dus wat een klap kost, niet wat hij oplevert:
## genoeg om een dure klap te mijden, niet genoeg om de opgave over te slaan.
## Zie `TraitModifier._abgevecht()`.
func _variant_label(v: Dictionary) -> String:
	var label := String(v.get("label", "..."))
	if not bool(content().get("toon_tegenklap", false)):
		return label
	return "%s   (-%d terug)" % [label, roundi(float(v.get("tegenklap", 0.0)))]


func _variant(ronde: int, index: int) -> Dictionary:
	var rondes := _rondes()
	if ronde < 0 or ronde >= rondes.size():
		return {}
	var varianten := (rondes[ronde] as Dictionary).get("varianten", []) as Array
	if index < 0 or index >= varianten.size():
		return {}
	return varianten[index] as Dictionary


## De variant met het beste netto-effect (schade toegebracht minus tegenklap
## opgelopen) — het equivalent van `mg_abtest.gd`'s `_beste_index()`.
func _beste_index(ronde: int) -> int:
	var rondes := _rondes()
	if ronde < 0 or ronde >= rondes.size():
		return -1
	var varianten := (rondes[ronde] as Dictionary).get("varianten", []) as Array
	var beste := -1
	var beste_netto := -INF
	for i: int in varianten.size():
		var vr := varianten[i] as Dictionary
		var netto := float(vr.get("schade", 0.0)) - float(vr.get("tegenklap", 0.0))
		if netto > beste_netto:
			beste_netto = netto
			beste = i
	return beste


# --- QA ------------------------------------------------------------------

## Speelt het gevecht echt uit: steeds de beste klap, de meting uitwachten,
## door naar de volgende — of naar de afronding als een KO eerder valt. Zelfde
## opzet als `mg_abtest.gd::qa_solve()`.
func qa_solve() -> void:
	if _qa_loopt or _varianten == null or _volgende_knop == null:
		return
	_qa_loopt = true
	var totaal := _rondes().size()
	while _ronde < totaal and not _afgerond:
		await _kies(_beste_index(_ronde))
		if not is_inside_tree():
			return
		if _afgerond:
			return
		if _volgende_knop.disabled:
			_qa_loopt = false
			return
		if _ronde + 1 >= totaal:
			await _volgende()
			return
		await _volgende()
