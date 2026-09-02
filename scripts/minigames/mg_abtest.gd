extends MinigameBase
## A/B-test — meten, lezen, opnieuw. "Komen we maar op 1 manier achter dat het
## werkt: aanzetten."
##
## Het verschil met ChoiceScene zit in wanneer je iets weet: daar tellen
## verborgen punten door tot de afloop, hier komt de uitslag tussen twee
## beslissingen in binnen. Je keuze in ronde twee is een andere keuze omdat je
## ronde een hebt zien uitpakken, en daarom is de meting een animatie en geen
## nieuw getal: een naald die zakt is een ander gevoel dan een min ervoor.

## Lang genoeg om de beweging te zien, kort genoeg om drie keer te doen.
const METING_DUUR := 0.9

var _basis: float = 0.0
var _doel: float = 0.0
var _eenheid: String = ""
## Bovenkant van de balk. Komt uit de data, niet uit een vuistregel: als het
## hoogst haalbare resultaat niet in de balk past, loopt een goede speelbeurt
## tegen de rand aan en zie je de laatste winst niet meer.
var _bovengrens: float = 1.0

## Staan de effecten al op de knoppen? Dit is het voordeel van een CRO'er:
## niet een makkelijker getal maar minder blind kiezen. Zie
## `TraitModifier._abtest()`.
var _toon_effect: bool = false

var _ronde: int = 0
var _conversie: float = 0.0
var _keuzes: Array[String] = []
var _bezig: bool = false
var _qa_loopt: bool = false

var _meting: Tween = null

var _waarde: Label = null
var _vulling: ColorRect = null
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

	_basis = float(c.get("basis", 0.0))
	_doel = float(c.get("doel", 0.0))
	_eenheid = String(c.get("eenheid", ""))
	_toon_effect = bool(c.get("toon_effect", false))
	_conversie = _basis
	_bovengrens = maxf(_doel, _hoogst_haalbaar()) * 1.06

	var body := build_chrome(default_title(), String(c.get("intro", "")))

	# De conversie is het enige getal dat de hele minigame telt, dus die hangt
	# buiten de scroll: wegscrollen mag hij nooit. De vaste plek van de
	# Volgende-knop is dezelfde afspraak voor je duim.
	chrome_header().add_child(_bouw_meter())
	_volgende_knop = _bouw_volgende()
	chrome_footer().add_child(_volgende_knop)

	_vraag = UiKit.label("", UiKit.FS_BODY, UiKit.INK)
	body.add_child(_vraag)

	_varianten = VBoxContainer.new()
	_varianten.add_theme_constant_override("separation", 2)
	body.add_child(_varianten)

	# Danny leest de uitslag voor. Pas als de meting stilstaat, want anders
	# vertelt hij de uitkomst terwijl de balk nog beweegt.
	_regel = UiKit.label("", UiKit.FS_SMALL, UiKit.BLUEBIRD_INK)
	_regel.visible = false
	body.add_child(_regel)

	_zet_conversie(_conversie)
	_toon_ronde()


func _exit_tree() -> void:
	if _meting != null and _meting.is_valid():
		_meting.kill()


# --- Meter ---------------------------------------------------------------

func _bouw_meter() -> PanelContainer:
	var kaart := PanelContainer.new()
	kaart.add_theme_stylebox_override("panel", UiKit.panel_krap(UiKit.WIT, UiKit.INK))
	var kol := VBoxContainer.new()
	kol.add_theme_constant_override("separation", 2)
	kaart.add_child(kol)

	var kop := HBoxContainer.new()
	kop.add_theme_constant_override("separation", 2)
	kol.add_child(kop)
	# Dit getal mag niet afbreken: naast een label met EXPAND_FILL krijgt een
	# afbrekend label de smalste breedte die past, en dan staat "1,8%" onder
	# elkaar. Vier tekens brengen de meter niet buiten het canvas.
	_waarde = UiKit.label("", UiKit.FS_HEAD, UiKit.INK)
	_waarde.autowrap_mode = TextServer.AUTOWRAP_OFF
	kop.add_child(_waarde)
	var doel_label := UiKit.label("doel %s" % _getal(_doel), UiKit.FS_SMALL, UiKit.BLUEBIRD_INK)
	doel_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	doel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	doel_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	kop.add_child(doel_label)

	var spoor := Control.new()
	spoor.custom_minimum_size = Vector2(0, 9)
	spoor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kol.add_child(spoor)
	spoor.add_child(_rect(UiKit.NEUTRAAL_TINT))
	_vulling = _rect(UiKit.GROEN)
	spoor.add_child(_vulling)

	# De doelstreep hoort in de balk zelf te staan: een streefwaarde die alleen
	# in de legenda staat moet je omrekenen, een streep waar je net onder zit
	# niet.
	var streep := _rect(UiKit.BLUEBIRD_INK)
	var frac := clampf(_doel / _bovengrens, 0.0, 1.0)
	streep.anchor_left = frac
	streep.anchor_right = frac
	streep.offset_left = -1.0
	streep.offset_right = 1.0
	spoor.add_child(streep)

	# Het verloopje: drie blokjes die vertellen welke rondes je gehad hebt en
	# welke kant ze op gingen. Zonder dat is de balk alleen een stand en niet
	# het verhaal ernaartoe.
	var rij := HBoxContainer.new()
	rij.add_theme_constant_override("separation", 2)
	kol.add_child(rij)
	for i: int in _rondes().size():
		var vak := PanelContainer.new()
		vak.add_theme_stylebox_override("panel", UiKit.panel_krap(UiKit.NEUTRAAL_TINT, UiKit.LINE))
		vak.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var t := UiKit.label("·", UiKit.FS_SMALL, UiKit.GRIJS)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vak.add_child(t)
		rij.add_child(vak)
		_blok.append(vak)
		_blok_tekst.append(t)

	return kaart


func _rect(kleur: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = kleur
	UiKit.full_rect(r)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _bouw_volgende() -> Button:
	var b := UiKit.button("Volgende", UiKit.FS_SMALL)
	b.custom_minimum_size = Vector2(0, 26)
	b.add_theme_stylebox_override("disabled", UiKit.panel(UiKit.NEUTRAAL_TINT, UiKit.LINE))
	b.add_theme_color_override("font_disabled_color", UiKit.GRIJS)
	b.disabled = true
	b.pressed.connect(_volgende)
	return b


# --- Rondes --------------------------------------------------------------

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


## Het label van een variant, met bij eigen vakgebied het verwachte effect
## erachter. Achter het label en niet ervoor: je leest nog steeds eerst wat je
## aanzet, en het getal is een tweede overweging en niet de eerste.
func _variant_label(v: Dictionary) -> String:
	var label := String(v.get("label", "..."))
	if not _toon_effect:
		return label
	return "%s   %s" % [label, _effect_tekst(float(v.get("effect", 0.0)))]


## Een effect draagt altijd zijn teken, ook als het nul is: "0,0" zonder teken
## leest als een meetwaarde en niet als "hier verandert niets".
func _effect_tekst(e: float) -> String:
	return "%s%s" % ["+" if e >= 0.0 else "-", _getal(absf(e))]


func _kies(index: int) -> void:
	# Twee keer tikken mag niet nog een meting starten, en een ronde die al een
	# uitslag heeft is klaar.
	if _bezig or _volgende_knop == null or not _volgende_knop.disabled:
		return
	var v := _variant(_ronde, index)
	if v.is_empty():
		return

	_bezig = true
	AudioDirector.play_ui(&"klik")
	_keuzes.append(String(v.get("label", "")))

	# De twee andere varianten blijven staan maar vervallen: wat je deze ronde
	# niet hebt aangezet is geen optie meer, en dat hoort te zien te zijn.
	for i: int in _varianten.get_child_count():
		var b := _varianten.get_child(i) as Button
		b.disabled = true
		if i == index:
			b.add_theme_stylebox_override("disabled", UiKit.panel(UiKit.BLUEBIRD_TINT, UiKit.INK))
			b.add_theme_color_override("font_disabled_color", UiKit.INK)

	var effect := float(v.get("effect", 0.0))
	await _meet(effect)
	if not is_inside_tree():
		return

	_zet_verloop(_ronde, effect)
	_regel.text = String(v.get("regel", ""))
	_regel.visible = true
	AudioDirector.play_ui(&"pak")
	_bezig = false
	_volgende_knop.disabled = false
	_volgende_knop.grab_focus()


## De naald moet lopen. Een speler die alleen een nieuw getal ziet staan leest
## een uitslag; een speler die de balk ziet zakken heeft iets gemeten.
func _meet(effect: float) -> void:
	var van := _conversie
	var naar := maxf(0.0, van + effect)
	_vulling.color = UiKit.GROEN if effect >= 0.0 else UiKit.ROOD
	if _meting != null and _meting.is_valid():
		_meting.kill()
	_meting = create_tween()
	_meting.tween_method(_zet_conversie, van, naar, METING_DUUR) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _meting.finished
	_conversie = naar


func _zet_conversie(v: float) -> void:
	_waarde.text = _getal(v)
	# Anchor plus offset, want de balkbreedte is pas na de layout bekend en een
	# vaste pixelbreedte klopt daarna niet meer.
	_vulling.anchor_right = clampf(v / _bovengrens, 0.0, 1.0)
	_vulling.offset_left = 0.0
	_vulling.offset_right = 0.0


func _zet_verloop(ronde: int, effect: float) -> void:
	if ronde >= _blok.size():
		return
	var omhoog := effect >= 0.0
	_blok[ronde].add_theme_stylebox_override("panel",
		UiKit.panel_krap(UiKit.GROEN if omhoog else UiKit.ROOD, UiKit.INK))
	_blok_tekst[ronde].text = _delta(effect)
	_blok_tekst[ronde].add_theme_color_override("font_color", UiKit.INK)


func _volgende() -> void:
	if _bezig:
		return
	_ronde += 1
	if _ronde >= _rondes().size():
		await _afronden()
	else:
		_toon_ronde()


func _afronden() -> void:
	var c := content()
	var gelukt := _haalt_doel()
	_volgende_knop.disabled = true
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


# --- Data ----------------------------------------------------------------

func _rondes() -> Array:
	return content().get("rondes", []) as Array


func _variant(ronde: int, index: int) -> Dictionary:
	var rondes := _rondes()
	if ronde < 0 or ronde >= rondes.size():
		return {}
	var varianten := (rondes[ronde] as Dictionary).get("varianten", []) as Array
	if index < 0 or index >= varianten.size():
		return {}
	return varianten[index] as Dictionary


func _beste_index(ronde: int) -> int:
	var rondes := _rondes()
	if ronde < 0 or ronde >= rondes.size():
		return -1
	var varianten := (rondes[ronde] as Dictionary).get("varianten", []) as Array
	var beste := -1
	var beste_effect := -INF
	for i: int in varianten.size():
		var e := float((varianten[i] as Dictionary).get("effect", 0.0))
		if e > beste_effect:
			beste_effect = e
			beste = i
	return beste


func _hoogst_haalbaar() -> float:
	var som := _basis
	for ronde: int in _rondes().size():
		var i := _beste_index(ronde)
		if i >= 0:
			som += float(_variant(ronde, i).get("effect", 0.0))
	return som


## Een punt in een conversiecijfer leest hier als een fout.
func _getal(v: float) -> String:
	return ("%.1f" % v).replace(".", ",") + _eenheid


func _delta(e: float) -> String:
	return ("%+.1f" % e).replace(".", ",")


# --- QA ------------------------------------------------------------------

## Speelt de drie rondes echt af: beste variant kiezen, de meting uitwachten,
## door naar de volgende. Dat test de winroute zelf en niet een kortsluiting
## naar succeed(). De autopilot tikt elke 0.45 s aan, dus dit moet één keer
## starten en daarna z'n eigen tempo houden.
func qa_solve() -> void:
	if _qa_loopt or _varianten == null or _volgende_knop == null:
		return
	_qa_loopt = true
	var totaal := _rondes().size()
	while _ronde < totaal:
		await _kies(_beste_index(_ronde))
		if not is_inside_tree():
			return
		if _volgende_knop.disabled:
			# Ronde niet doorgekomen; volgende tik mag het opnieuw proberen.
			_qa_loopt = false
			return
		if _ronde + 1 >= totaal:
			# De laatste ronde rondt af en daarna bestaat deze node niet meer,
			# dus hier niet meer op wachten.
			_volgende()
			return
		await _volgende()
