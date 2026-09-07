extends MinigameBase
## BBD-207 — A tegen B. Danny's tweede A/B-getinte ticket, maar dit is geen
## meting zoals BBD-206/`mg_heatmap.gd`: dit is een gevecht. A moet B binnen
## drie klappen knock-outen.
##
## **Herontworpen na Daans playtest van 6 september.** Het wás drie keer een
## rijtje van drie knoppen in een `ScrollContainer`, met health bars erboven.
## Zijn oordeel (#28): *"had dit meer als een daadwerkelijke 1v1 arcade
## fighting game verwacht, geen 'snel vragen beantwoorden' ding. met health bar
## en alles en CRO grapjes bij critical hits."* En (#28b): *"wat een
## verwarrende UX."*
##
## Wat er nu staat is een **timingspel**. Elke ronde slingert een marker over
## een baan met een kritieke zone in het midden. Wélke klap je zet blijft jouw
## keuze — daar zit de comedy, want "nog een veld erbij, voor de zekerheid" is
## de grap — maar *wanneer* je hem zet bepaalt of hij aankomt:
##
## | timing | schade | tegenklap | wat je ziet |
## |---|---|---|---|
## | in de kritieke zone | ×1,5 | ×0,5 | CRITICAL, en Danny's regel als de clou |
## | daarbuiten, binnen de baan | ×1 | ×1 | gewoon raak |
## | in de buitenste `MIS_MARGE` | ×0,35 | ×1,4 | mis, en B slaat harder terug |
##
## De zone krimpt per ronde, wat de escalatie in de bestaande teksten volgt
## ("Hij komt overeind", "Maak het af"). De data verandert niet: `schade`,
## `tegenklap` en `regel` per variant blijven precies wat ze waren, dus alle
## geschreven grappen staan er nog.
##
## Ruim genomen, met opzet: dit is een comedy adventure en geen uitdaging (zie
## `docs/GAME_DESIGN.md`). Een totale mis vraagt actief slechte timing, en
## verliezen kost niets dan tijd — Danny komt terug met een steeds absurdere
## reden om het nog eens te proberen. De teller die dat bijhoudt
## (`Session.get_counter(&"ab_pogingen")`) wordt hier opgehoogd; de oplopende
## regels zelf staan in `data/dialogue/tickets.json` bij `t07_fail`.

## Lang genoeg om een klap te zien landen, kort genoeg om drie keer te doen.
const MEET_DUUR := 0.5

## De adempauze tussen twee rondes, waarin Danny's regel staat en de balken
## uitzakken. Zie `_volgende()`.
const NA_RONDE_SEC := 1.5

## Breedte van de kritieke zone per ronde, als deel van de baan. Krimpt mee met
## de escalatie in de rondeteksten.
const ZONE_PER_RONDE: Array[float] = [0.34, 0.26, 0.20]

## De buitenste band aan weerszijden waar een klap mis is.
const MIS_MARGE := 0.15

## Hoe lang de marker over één enkele overtocht doet, per ronde. Korter is
## sneller, dus moeilijker.
const SLINGER_SEC_PER_RONDE: Array[float] = [1.30, 1.05, 0.85]

const CRIT_SCHADE := 1.5
const CRIT_TEGENKLAP := 0.5
const MIS_SCHADE := 0.35
const MIS_TEGENKLAP := 1.4

enum Kwaliteit { CRITICAL, RAAK, MIS }

var _hp_a_max: float = 100.0
var _hp_b_max: float = 100.0
var _hp_a: float = 100.0
var _hp_b: float = 100.0

var _ronde: int = 0
var _keuzes: Array[String] = []
var _bezig: bool = false

## Is de klap van deze ronde al gevallen? Verving de `disabled`-stand van de
## verdwenen "Volgende"-knop als bewaker tegen een tweede klap in één ronde.
var _klap_gevallen: bool = false
var _qa_loopt: bool = false
var _afgerond: bool = false

## Gezet door `qa_solve()`: dwing de volgende klap in de kritieke zone, zodat
## de geautomatiseerde speelbeurt deterministisch wint in plaats van van de
## slingerstand af te hangen.
var _qa_dwing_critical: bool = false

var _meting: Tween = null
var _flits_tween: Tween = null

var _vulling_a: ColorRect = null
var _vulling_b: ColorRect = null
var _waarde_a: Label = null
var _waarde_b: Label = null
var _vechter_a: Control = null
var _vechter_b: Control = null

var _vraag: Label = null
var _varianten: VBoxContainer = null
var _regel: Label = null

## De slinger. `_slinger` loopt van 0 tot 1 en terug; `_zone_*` is de kritieke
## zone van deze ronde. `_slinger_actief` staat pas op true zodra `_toon_ronde()`
## een ronde toont, dus hij dient ook als bewaakvlag tegen het ene `_process()`-
## frame vóór `_on_setup()` klaar is (zie `mg_standup.gd::_running`).
var _slinger: float = 0.0
var _slinger_heen: bool = true
var _slinger_sec: float = 1.3
var _zone_van: float = 0.33
var _zone_tot: float = 0.67
var _slinger_actief: bool = false

var _baan: Control = null
var _zone_vak: ColorRect = null
var _marker: ColorRect = null

## De rondeklok. Loopt door terwijl je kiest; op nul valt de zwakste klap, en
## die valt dan ook als een mis — te lang twijfelen is hier hetzelfde als
## verkeerd timen.
var _keuze_sec: float = 7.0
var _keuze_tijd: float = 7.0


func _on_setup() -> void:
	var c := content()
	if c.is_empty() or _rondes().is_empty():
		fail()
		return

	_hp_a_max = maxf(1.0, float(c.get("hp_a", 100.0)))
	_hp_b_max = maxf(1.0, float(c.get("hp_b", 100.0)))
	_hp_a = _hp_a_max
	_hp_b = _hp_b_max
	_keuze_sec = maxf(1.0, float(c.get("keuze_sec", 7.0)))

	# De veldvorm en niet de lijstvorm: dit is een gevecht en geen formulier.
	# Zie `MinigameBase.build_chrome_veld()`.
	var body := build_chrome_veld(default_title(), String(c.get("intro", "")))

	# De rondetekst bóven de arena en niet eronder: de arena houdt hoogte over
	# boven de vechters, en die ruimte hoort de aankondiging te dragen in plaats
	# van leeg te staan. Onder de vechters is bovendien geen plek meer — daar
	# begint de slingerbaan.
	_vraag = UiKit.label("", UiKit.FS_SMALL, UiKit.WIT)
	_vraag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_vraag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_vraag)

	body.add_child(_bouw_arena())

	body.add_child(_bouw_baan())

	_varianten = VBoxContainer.new()
	_varianten.add_theme_constant_override("separation", 2)
	_varianten.size_flags_vertical = Control.SIZE_SHRINK_END
	body.add_child(_varianten)

	_regel = UiKit.label("", UiKit.FS_SMALL, UiKit.BLUEBIRD_BRIGHT)
	_regel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_regel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_regel.visible = false
	body.add_child(_regel)

	_zet_meters()
	_toon_ronde()


func _exit_tree() -> void:
	if _meting != null and _meting.is_valid():
		_meting.kill()
	if _flits_tween != null and _flits_tween.is_valid():
		_flits_tween.kill()


## De slinger en de rondeklok lopen samen: zolang er gekozen mag worden beweegt
## de marker, en tikt de klok. Op nul valt de zwakste klap als een mis.
func _process(delta: float) -> void:
	if not _slinger_actief:
		return

	var stap := delta / maxf(0.05, _slinger_sec)
	if _slinger_heen:
		_slinger += stap
		if _slinger >= 1.0:
			_slinger = 1.0
			_slinger_heen = false
	else:
		_slinger -= stap
		if _slinger <= 0.0:
			_slinger = 0.0
			_slinger_heen = true
	_zet_marker()

	_keuze_tijd -= delta
	set_status("Ronde %d/%d  ·  %ds" % [_ronde + 1, _rondes().size(), maxi(0, ceili(_keuze_tijd))])
	if _keuze_tijd <= 0.0:
		_slinger_actief = false
		_tijd_op()


func _tijd_op() -> void:
	if _bezig or _afgerond:
		return
	var index := _zwakste_index(_ronde)
	if index < 0:
		return
	_kies(index, Kwaliteit.MIS, true)


# --- Meters ----------------------------------------------------------------

func _rect(kleur: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = kleur
	UiKit.full_rect(r)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _zet_meters() -> void:
	_waarde_a.text = "%d" % maxi(0, roundi(_hp_a))
	_vulling_a.anchor_right = clampf(_hp_a / _hp_a_max, 0.0, 1.0)
	_waarde_b.text = "%d" % maxi(0, roundi(_hp_b))
	_vulling_b.anchor_right = clampf(_hp_b / _hp_b_max, 0.0, 1.0)


# --- De arena ---------------------------------------------------------------

## A en B als twee webshoppagina's die tegenover elkaar staan, want dat zíjn
## ze: twee versies van dezelfde pagina. Twee mensen met vuisten zou grappig
## zijn maar niet waar, en het paardensupplement staat in de hero.
##
## Een `Control` en geen `HBoxContainer`: een container herplaatst zijn
## kinderen, en dan vecht de terugslag-tween met de layout. Hier staan ze op
## ankers en beweegt alleen `scale`/`rotation`/`modulate`, wat ná de layout
## wordt toegepast en er dus niet mee botst.
## Hoe hoog een vechterpagina is. Genoeg voor een adresbalk, een hero, twee
## tekstregels en een bestelknop; niet zo hoog dat de hero een vlak wordt.
const PAGINA_HOOGTE := 148.0


func _bouw_arena() -> Control:
	var arena := Control.new()
	# `EXPAND_FILL` en niet een vaste hoogte: de arena is het enige dat mág
	# groeien, dus de vrije ruimte gaat naar de vechters in plaats van naar een
	# gat onderaan. De minimumhoogte is de bodem waaronder een pagina niet meer
	# als pagina leest.
	arena.custom_minimum_size = Vector2(0, PAGINA_HOOGTE + 8.0)
	arena.size_flags_vertical = Control.SIZE_EXPAND_FILL
	arena.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arena.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Vaste hoogte, verticaal gecentreerd: liet ik de pagina de hele arena
	# vullen, dan rekte de hero uit tot een gekleurd blok van 200 px en las het
	# niet meer als een pagina. De ruimte die overblijft staat er nu boven en
	# onder, als kophoogte in een arena.
	_vechter_a = _bouw_pagina(UiKit.BLUEBIRD_BRIGHT, true)
	_plaats_vechter(_vechter_a, 0.02, 0.46)
	arena.add_child(_vechter_a)

	_vechter_b = _bouw_pagina(UiKit.ORANJE, false)
	_plaats_vechter(_vechter_b, 0.54, 0.98)
	arena.add_child(_vechter_b)

	return arena


## Op de bodem van de arena en niet in het midden: de ruimte die de arena
## overhoudt hoort boven de vechters te staan als kophoogte, niet als twee
## gaten van 70 px boven én onder. Nu staan ze ergens op.
func _plaats_vechter(v: Control, links: float, rechts: float) -> void:
	v.anchor_left = links
	v.anchor_right = rechts
	v.anchor_top = 1.0
	v.anchor_bottom = 1.0
	v.offset_left = 0.0
	v.offset_right = 0.0
	v.offset_top = -PAGINA_HOOGTE
	v.offset_bottom = 0.0


## Eén pagina: naam en levensbalk bovenaan, dan een hero en een bestelknop.
##
## De levensbalken zaten hiervóór als eigen strook boven de arena, plus drie
## verloopblokjes eronder. Dat was 44 px chrome boven een gevecht van 104 px, en
## precies het soort stapeling waar Daan over klaagde ("hele scherm vol"). Nu
## staat het leven óp de vechter, waar het hoort: je kijkt naar de pagina die
## klappen krijgt en ziet daar hoe hij ervoor staat.
func _bouw_pagina(accent: Color, is_a: bool) -> Control:
	var kader := PanelContainer.new()
	kader.add_theme_stylebox_override("panel", UiKit.panel(UiKit.PANEL, UiKit.LINE))
	kader.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var kol := VBoxContainer.new()
	kol.add_theme_constant_override("separation", 2)
	kader.add_child(kol)

	var kop := HBoxContainer.new()
	kop.add_theme_constant_override("separation", 2)
	# Autowrap uit, zelfde reden als in `build_chrome_veld()`: met afbreken aan
	# is de minimumbreedte één teken, en dan valt "100" hier als 1/0/0 onder
	# elkaar in een pagina van 77 px.
	var naam := UiKit.label("A" if is_a else "B", UiKit.FS_SMALL, accent.darkened(0.25))
	naam.autowrap_mode = TextServer.AUTOWRAP_OFF
	naam.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kop.add_child(naam)
	var waarde := UiKit.label("", UiKit.FS_SMALL, UiKit.GRIJS_OP_LICHT)
	waarde.autowrap_mode = TextServer.AUTOWRAP_OFF
	waarde.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	kop.add_child(waarde)
	kol.add_child(kop)

	var vak := Control.new()
	vak.custom_minimum_size = Vector2(0, 5)
	vak.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vak.add_child(_rect(UiKit.NEUTRAAL_TINT))
	var vulling := _rect(accent)
	vak.add_child(vulling)
	kol.add_child(vak)

	var hero := ColorRect.new()
	hero.color = accent
	hero.custom_minimum_size = Vector2(0, 22)
	hero.size_flags_vertical = Control.SIZE_EXPAND_FILL
	kol.add_child(hero)

	for i: int in 2:
		var regel := ColorRect.new()
		regel.color = UiKit.NEUTRAAL_TINT
		regel.custom_minimum_size = Vector2(0, 3)
		kol.add_child(regel)

	var knop := ColorRect.new()
	knop.color = accent.darkened(0.2)
	knop.custom_minimum_size = Vector2(0, 8)
	kol.add_child(knop)

	if is_a:
		_vulling_a = vulling
		_waarde_a = waarde
	else:
		_vulling_b = vulling
		_waarde_b = waarde
	return kader


## De terugslag. `pivot_offset` op het midden, zodat de pagina om zijn eigen as
## kantelt in plaats van om zijn linkerbovenhoek.
func _klap_op(vechter: Control, zwaar: bool) -> void:
	if vechter == null or vechter.size == Vector2.ZERO:
		return
	if _flits_tween != null and _flits_tween.is_valid():
		_flits_tween.kill()
	vechter.pivot_offset = vechter.size * 0.5
	var kant := -1.0 if vechter == _vechter_b else 1.0
	var hoek := deg_to_rad(9.0 if zwaar else 4.0) * kant
	vechter.modulate = Color(1.8, 1.5, 1.5) if zwaar else Color(1.3, 1.2, 1.2)
	_flits_tween = create_tween()
	_flits_tween.set_parallel(true)
	_flits_tween.tween_property(vechter, "rotation", hoek, 0.06)
	_flits_tween.tween_property(vechter, "modulate", Color.WHITE, 0.3)
	_flits_tween.chain().tween_property(vechter, "rotation", 0.0, 0.28) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


# --- De baan ---------------------------------------------------------------

## De slingerbaan met de kritieke zone. Dit is de enige tijdsdruk in beeld: de
## gedeelde `bouw_klokbalk()` staat er bewust níet bij, want twee balken die
## allebei iets over tijd zeggen is precies de schermvervuiling waar Daan over
## klaagde. De rondeklok staat als getal in de statusregel.
func _bouw_baan() -> Control:
	_baan = Control.new()
	_baan.custom_minimum_size = Vector2(0, 12)
	_baan.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_baan.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var spoor := _rect(UiKit.PANEL_DARK)
	_baan.add_child(spoor)

	# De misbanden aan weerszijden, zodat je ziet waar het niet moet.
	for links: bool in [true, false]:
		var mis := ColorRect.new()
		mis.color = Color(UiKit.ROOD, 0.30)
		mis.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mis.anchor_top = 0.0
		mis.anchor_bottom = 1.0
		mis.anchor_left = 0.0 if links else 1.0 - MIS_MARGE
		mis.anchor_right = MIS_MARGE if links else 1.0
		mis.offset_left = 0.0
		mis.offset_right = 0.0
		mis.offset_top = 0.0
		mis.offset_bottom = 0.0
		_baan.add_child(mis)

	_zone_vak = ColorRect.new()
	_zone_vak.color = UiKit.GROEN
	_zone_vak.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_zone_vak.anchor_top = 0.0
	_zone_vak.anchor_bottom = 1.0
	_baan.add_child(_zone_vak)

	_marker = ColorRect.new()
	_marker.color = UiKit.WIT
	_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marker.anchor_top = 0.0
	_marker.anchor_bottom = 1.0
	_marker.offset_left = -1.0
	_marker.offset_right = 2.0
	_baan.add_child(_marker)

	return _baan


func _zet_zone() -> void:
	var breed: float = ZONE_PER_RONDE[mini(_ronde, ZONE_PER_RONDE.size() - 1)]
	_zone_van = 0.5 - breed * 0.5
	_zone_tot = 0.5 + breed * 0.5
	if _zone_vak != null:
		_zone_vak.anchor_left = _zone_van
		_zone_vak.anchor_right = _zone_tot
		_zone_vak.offset_left = 0.0
		_zone_vak.offset_right = 0.0


func _zet_marker() -> void:
	if _marker == null:
		return
	_marker.anchor_left = _slinger
	_marker.anchor_right = _slinger


## Waar de marker stond toen je sloeg.
func _kwaliteit_nu() -> Kwaliteit:
	if _qa_dwing_critical:
		return Kwaliteit.CRITICAL
	if _slinger >= _zone_van and _slinger <= _zone_tot:
		return Kwaliteit.CRITICAL
	if _slinger < MIS_MARGE or _slinger > 1.0 - MIS_MARGE:
		return Kwaliteit.MIS
	return Kwaliteit.RAAK


# --- Rondes ------------------------------------------------------------

func _toon_ronde() -> void:
	var rondes := _rondes()
	var r := rondes[_ronde] as Dictionary
	_vraag.text = String(r.get("vraag", ""))
	_regel.text = ""
	_regel.visible = false
	_klap_gevallen = false
	_keuze_tijd = _keuze_sec
	_slinger = 0.0
	_slinger_heen = true
	_slinger_sec = SLINGER_SEC_PER_RONDE[mini(_ronde, SLINGER_SEC_PER_RONDE.size() - 1)]
	_zet_zone()
	_zet_marker()
	set_status("Ronde %d/%d  ·  %ds" % [_ronde + 1, rondes.size(), roundi(_keuze_sec)])
	_slinger_actief = true

	for oud: Node in _varianten.get_children():
		_varianten.remove_child(oud)
		oud.queue_free()

	var varianten := r.get("varianten", []) as Array
	for i: int in varianten.size():
		var v := varianten[i] as Dictionary
		var b := UiKit.keuzeknop(_variant_label(v), UiKit.FS_SMALL)
		b.custom_minimum_size = Vector2(0, 26)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_stylebox_override("disabled", UiKit.panel(UiKit.NEUTRAAL_TINT, UiKit.LINE))
		b.add_theme_color_override("font_disabled_color", UiKit.GRIJS)
		b.pressed.connect(_sla.bind(i))
		_varianten.add_child(b)

	if _varianten.get_child_count() > 0:
		(_varianten.get_child(0) as Button).grab_focus()


## Een klap van de speler: de kwaliteit wordt hier bevroren, op de stand van de
## marker op dit exacte frame.
func _sla(index: int) -> void:
	_kies(index, _kwaliteit_nu(), false)


## `automatisch`: de klok koos (`_tijd_op()`), niet de speler. Zet dan Danny's
## commentaarregel niet zichtbaar — zijn tekst komt wel te staan (onschuldig),
## maar `_regel.visible = true` op dit exacte moment liet de layout-engine
## vastlopen in een resize-lus die het spel deed crashen; zie de commit
## "de zwakste klap" en playtest 2026-09-06. De statusregel draagt de melding al.
func _kies(index: int, kwaliteit: Kwaliteit, automatisch: bool) -> void:
	if _bezig or _afgerond or _klap_gevallen:
		return
	var v := _variant(_ronde, index)
	if v.is_empty():
		return

	_slinger_actief = false
	_qa_dwing_critical = false
	_klap_gevallen = true
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
	match kwaliteit:
		Kwaliteit.CRITICAL:
			schade *= CRIT_SCHADE
			tegenklap *= CRIT_TEGENKLAP
		Kwaliteit.MIS:
			schade *= MIS_SCHADE
			tegenklap *= MIS_TEGENKLAP
		_:
			pass

	set_status(_kop_voor(kwaliteit))

	# De klap eerst voelen, dan de balken laten zakken.
	if schade > 0.0:
		_klap_op(_vechter_b, kwaliteit == Kwaliteit.CRITICAL)
		Juice.schok(1.6 if kwaliteit == Kwaliteit.CRITICAL else 1.0, 0.15)
		AudioDirector.play_sfx(&"raak")
	if tegenklap > 0.0:
		_klap_op(_vechter_a, kwaliteit == Kwaliteit.MIS)

	await _meet(schade, tegenklap)
	if not is_inside_tree():
		return

	# De CRO-grap is de belofte van een critical: bij een voltreffer krijg je
	# Danny's regel als clou, bij een gewone klap ook, maar bij een mis staat
	# de reden in de kop en niet in zijn mond.
	_regel.text = String(v.get("regel", ""))
	_regel.visible = not automatisch
	AudioDirector.play_ui(&"pak")
	_bezig = false

	if _hp_a <= 0.0 or _hp_b <= 0.0:
		await _afronden()
		return

	await _volgende()


func _kop_voor(kwaliteit: Kwaliteit) -> String:
	match kwaliteit:
		Kwaliteit.CRITICAL:
			return "CRITICAL"
		Kwaliteit.MIS:
			return "Mis. Hij slaat terug."
		_:
			return "Raak."


## De klap moet landen, niet alleen een nieuw getal tonen: beide balken bewegen
## tegelijk, want dezelfde klap kost en levert in één beweging.
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
	# Pollen en niet `await _meting.finished`: `_exit_tree()` en een volgende
	# `_meet()` doen allebei `_meting.kill()`, en een gekillde Tween emit
	# `finished` nooit meer. Deze await keerde dan niet terug, `_bezig` bleef
	# aanstaan en het gevecht stond stil — met `Shell.run_minigame()` die nooit
	# terugkomt en `TicketController._busy` die daarna voorgoed dicht blijft.
	# Zelfde fout als in `Hud.toon_urenrol()`; zie playtest 2026-09-06 #37/#38.
	while _meting != null and _meting.is_valid() and _meting.is_running():
		await get_tree().process_frame
	_hp_a = naar_a
	_hp_b = naar_b
	_zet_meters()


## Doorlopen zonder knop. Er stond een "Volgende" onder de drie klappen, en die
## kostte 24 px speelveld plus een tik per ronde — in een gevecht is dat een
## rem. `NA_RONDE_SEC` is lang genoeg om Danny's regel te lezen en de balken te
## zien zakken, kort genoeg om niet als wachten te voelen.
func _volgende() -> void:
	if _afgerond:
		return
	await _wacht(NA_RONDE_SEC)
	if not is_inside_tree() or _afgerond:
		return
	_ronde += 1
	if _ronde >= _rondes().size() or _hp_a <= 0.0 or _hp_b <= 0.0:
		await _afronden()
	else:
		_toon_ronde()


## A wint als B eerder nul staat dan A. Blijft B overeind tot de laatste ronde
## voorbij is, dan wint B op punten.
func _afronden() -> void:
	if _afgerond:
		return
	_afgerond = true
	_slinger_actief = false
	var c := content()
	var a_wint := _hp_b <= 0.0 and _hp_a > 0.0

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
## opgelopen).
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


## De variant met de laagste schade — de zwakste klap, die de rondeklok laat
## vallen als niemand op tijd slaat.
func _zwakste_index(ronde: int) -> int:
	var rondes := _rondes()
	if ronde < 0 or ronde >= rondes.size():
		return -1
	var varianten := (rondes[ronde] as Dictionary).get("varianten", []) as Array
	var zwakste := -1
	var minimum := INF
	for i: int in varianten.size():
		var vr := varianten[i] as Dictionary
		var schade := float(vr.get("schade", 0.0))
		if schade < minimum:
			minimum = schade
			zwakste = i
	return zwakste


# --- QA ------------------------------------------------------------------

## Speelt het gevecht echt uit: steeds de beste klap, en die klap wordt
## deterministisch een critical.
##
## `_qa_dwing_critical` en niet "wacht tot de marker in de zone staat": een
## harnas dat op een slingerstand wacht is een harnas dat soms mist, en dan is
## een rode speelbeurt geen bewijs meer van een echte fout. De timing zelf is
## niet headless te toetsen — dat hoort in `_test_abgevecht_timing()`, die de
## rekenkant kaal narekent.
func qa_solve() -> void:
	if _qa_loopt or _varianten == null:
		return
	_qa_loopt = true
	var totaal := _rondes().size()
	while _ronde < totaal and not _afgerond:
		if _klap_gevallen or _bezig:
			await get_tree().process_frame
			continue
		_qa_dwing_critical = true
		await _kies(_beste_index(_ronde), Kwaliteit.CRITICAL, false)
		if not is_inside_tree():
			return
	_qa_loopt = false


## `await get_tree().create_timer(...)` en niet een Tween: een timer die ook
## tijdens een gepauzeerde tree doorloopt, want de wereld pauzeert niet tijdens
## een minigame maar de shell kan dat wel doen. Zelfde vorm als in
## `mg_standup.gd`.
func _wacht(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout
