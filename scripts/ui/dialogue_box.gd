class_name DialogueBox
extends Control
## Dialoogvenster met typemachine-effect en keuzes. Bouwt zichzelf op in code
## zodat er geen tweede bron van waarheid in een .tscn ligt.

signal advance_requested()
signal choice_picked(index: int)
## De keuzeklok is op nul gelopen zonder dat er iemand gekozen heeft. Alleen
## bij `show_choices()` met een `timeout_sec` boven nul; zie
## `DialogueController.ask_choice()`.
signal keuze_verlopen()
## De speler wil de rest van dit gesprek overslaan (het "overslaan »" onderin).
signal overslaan_gevraagd()

const CHARS_PER_SEC := 55.0

## Hoogte van de keuzeklok in pixels. Dun genoeg om geen paneel te zijn, dik
## genoeg om op een canvas van 192 px breed nog een kleur te dragen.
const KLOK_HOOGTE := 4.0

## Het paneel groeit omhoog mee met de tekst. Met een vaste hoogte van 70px viel
## langere dialoog onderuit beeld: RichTextLabel scrollt niet en klipt gewoon.
##
## HOOGTE_MAX stond op 156, en dat was precies de hoogte van de langste regel
## *zonder* portret. Een portret kost 32 px breedte plus 5 px tussenruimte van
## een tekstkolom van 156, dus een kwart minder tekens per regel en ruwweg een
## kwart meer regels — en dan viel dezelfde regel er onderuit. Dat gold al voor
## de langere nodes van een dialoogboom (die tonen altijd een gezicht); sinds de
## briefing van de eigenaar er ook een heeft, geldt het voor de langste tekst
## die het spel kent. 210 is de hoogte die BBD-208 met portret nodig heeft, en
## dat is nog altijd de helft van het canvas — de andere helft blijft kantoor.
const MARGE_ONDER := 8.0
const HOOGTE_MIN := 70.0
const HOOGTE_MAX := 210.0

## Zodra er keuzes staan is de helft-van-het-canvas-blijft-kantoor-afspraak
## hierboven niet meer het knelpunt: een quiz met vier knoppen verdringt het
## uitzicht toch al, en de vraag zelf mag dan niet de gedupeerde zijn.
## HOOGTE_MAX klemde de hele box — vraag én keuzeklok én knoppenkolom samen —
## op 210, en een vraag van twee regels plus vier `UiKit.keuzeknop()`-knoppen
## (die zelf ook wrappen) heeft daar ruimschoots meer dan dat voor nodig: het
## label kreeg dan minder over dan zijn eigen twee regels en de tweede regel
## verdween half achter de klokbalk (`p4_klant_balk.png`) — niet uit beeld
## geschoven, maar dichtgeklemd tot buiten het zichtbare stuk van het label.
##
## 240 is gemeten (`_test_vraag_boven_keuzes_leesbaar()`), niet gerekend: een
## echte DialogueBox met de langste `mg_klantfeedback`-vraag (na de afkap
## hierboven dus twee regels) en de bijbehorende vier echte keuzeknoppen —
## die laatste wrappen zelf ook, dus de knoppenkolom alleen al vraagt zo'n
## 184 px — meldde in totaal 232-234, met de keuzeklok meegeteld (die in het
## echte gesprek zichtbaar is: `mg_klantfeedback` roept `ask_choice()` altijd
## met een `ronde_sec` aan). 240 laat een kleine marge, en blijft ruim onder
## de 392 die overblijft tussen `Hud.bovenband_hoogte()` (24, `_test_hudband()`)
## en het canvas van 416 — de box mag hier dus groeien zonder de vaste
## bovenband te raken.
const HOOGTE_MAX_KEUZES := 240.0

## Hoeveel regels de vraag zelf krijgt zodra er keuzes onder staan. Meer dan
## dit vraagt de knoppenkolom op, dus hier geldt `OVERRUN_TRIM_ELLIPSIS` in
## plaats van de volledige tekst.
const MAX_REGELS_VRAAG_MET_KEUZES := 2

var _panel: PanelContainer
var _name: Label
var _text: RichTextLabel
var _klok_vak: Control
var _klok_balk: ColorRect
var _choices: VBoxContainer
var _hint: Label
var _skip_label: Label
var _portrait: TextureRect

var _full_text: String = ""
var _revealed: float = 0.0
var _typing: bool = false

## Hoeveel seconden deze keuze nog heeft, en hoeveel hij er kreeg. Nul betekent
## "geen klok": dat is de gewone keuze, en dat blijft de meeste.
var _klok_over: float = 0.0
var _klok_max: float = 0.0


func _ready() -> void:
	UiKit.fill_viewport(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiKit.panel())
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = 12
	_panel.offset_right = -12
	_panel.offset_top = -HOOGTE_MIN - MARGE_ONDER
	_panel.offset_bottom = -MARGE_ONDER
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	# Naar bóven groeien, niet naar beneden. Een PanelContainer mag nooit kleiner
	# worden dan zijn inhoud: meldt de inhoud meer dan wij hier neerzetten, dan
	# rekt Godot hem op in de `grow_vertical`-richting, en die staat standaard op
	# END. Dat is precies hoe het venster onderlangs het scherm uit schoof --
	# de onderrand zat op 8px van de bodem, dus alles wat erbij kwam ging buiten
	# beeld. Met BEGIN groeit hij het kantoor in, waar wel ruimte is.
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	_panel.add_child(row)

	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(32, 40)
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_portrait.visible = false
	row.add_child(_portrait)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)

	_name = UiKit.label("", UiKit.FS_BODY, UiKit.BLUEBIRD_INK)
	v.add_child(_name)

	_text = UiKit.rich(UiKit.FS_BODY)
	# fit_content laat het label zijn eigen hoogte melden, zodat het paneel kan
	# meegroeien. scroll_active blijft uit: een dialoogvenster hoort niet te scrollen.
	_text.fit_content = true
	_text.custom_minimum_size = Vector2(0, 24)
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_text)

	# De keuzeklok, tussen de vraag en de knoppen. Vier pixels hoog en over de
	# volle breedte: hij hoort in je ooghoek te staan terwijl je de opties leest,
	# niet in het midden van je blik. Standaard onzichtbaar — een gesprek zonder
	# klok mag er niet anders uitzien dan het altijd deed.
	_klok_vak = Control.new()
	_klok_vak.custom_minimum_size = Vector2(0, KLOK_HOOGTE)
	_klok_vak.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_klok_vak.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_klok_vak.visible = false
	var klok_achter := ColorRect.new()
	klok_achter.color = UiKit.NEUTRAAL_TINT
	klok_achter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.full_rect(klok_achter)
	_klok_vak.add_child(klok_achter)
	# De vulling krimpt via zijn rechteranker en niet via `size`: een Control
	# krijgt zijn formaat van de ouder, dus een size die je zelf zet is het
	# volgende frame weer weg. Zelfde constructie als de stand-upbalk.
	_klok_balk = ColorRect.new()
	_klok_balk.color = UiKit.tijdkleur(1.0)
	_klok_balk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_klok_balk.anchor_left = 0.0
	_klok_balk.anchor_top = 0.0
	_klok_balk.anchor_right = 1.0
	_klok_balk.anchor_bottom = 1.0
	_klok_vak.add_child(_klok_balk)
	v.add_child(_klok_vak)

	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 2)
	v.add_child(_choices)

	# Eén regel, want tikken werkt overal: een muisklik gaat door voor een
	# vingertik zolang er geen aanraakscherm is (`Invoer.muis_als_vinger()`).
	# E doet hetzelfde en staat op de besturingskaart.
	_hint = UiKit.label("tik  verder", UiKit.FS_SMALL, UiKit.GRIJS_OP_LICHT)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Links in dezelfde regel: de uitweg. Een gesprek van vijf regels kostte
	# tien tikken; wie het al kent, tikt hier en de rest loopt door tot de
	# eerste keuze. Esc doet hetzelfde (`DialogueController._input()`). Een
	# label en geen knop: een knop zou de hele regel hoger maken en focus
	# pakken, en de autopilot drukt elke knop met focus in.
	_skip_label = UiKit.label("overslaan »", UiKit.FS_SMALL, UiKit.GRIJS_OP_LICHT)
	# Zonder omloop: in deze rij neemt "tik verder" alle ruimte, en een omlopend
	# label krijgt dan de smalste breedte die het aankan — één letter per regel.
	_skip_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	# Tikdoel: kaal label op FS_SMALL was ~20-28 px hoog, ver onder de 44 px-
	# richtlijn. Geen Button (autopilot-focus, zie hierboven): alleen de maat
	# van het label vergroten.
	_skip_label.custom_minimum_size = Vector2(0, 22)
	_skip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_skip_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_skip_label.gui_input.connect(func(e: InputEvent) -> void:
		var tik := (e is InputEventMouseButton and (e as InputEventMouseButton).pressed
			and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) \
			or (e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed)
		if tik:
			overslaan_gevraagd.emit())
	var onder := HBoxContainer.new()
	onder.add_child(_skip_label)
	onder.add_child(_hint)
	v.add_child(onder)


func _process(delta: float) -> void:
	_klok_tik(delta)
	if not _typing:
		return
	_revealed += delta * CHARS_PER_SEC
	var total := float(_text.get_total_character_count())
	_text.visible_characters = int(_revealed)
	if _revealed >= total:
		_typing = false
		_text.visible_characters = -1
		_hint.visible = true
		_skip_label.visible = true


func show_line(speaker: String, text: String, portrait: Texture2D = null) -> void:
	visible = true
	_klok_stop()
	_name.text = speaker
	_name.visible = speaker != ""
	_portrait.texture = portrait
	_portrait.visible = portrait != null
	_full_text = text
	_text.text = text
	_text.visible_characters = 0
	_revealed = 0.0
	_typing = true
	_hint.visible = false
	_skip_label.visible = false
	_clear_choices()
	# Awaiten om dezelfde reden als in `show_choices()`: zonder dat bleef een
	# fire-en-vergeet `_pas_hoogte_aan()` van déze regel nog in de lucht hangen
	# terwijl `ask_choice()` meteen daarna `show_choices()` aanroept. Beide
	# metingen liepen dan door elkaar — de oude, met `met_keuzes` nog vals
	# vastgelegd vóórdat de keuzeknoppen erbij kwamen, won soms de race en zette
	# het paneel terug op `HOOGTE_MAX` terwijl de knoppen al stonden. Dat gaf
	# precies het beeld uit `p4_klant_balk.png`, nu via een tweede pad.
	await _pas_hoogte_aan()


## De keuzes tonen, eventueel met een klok erboven.
##
## `timeout_sec` boven nul zet de balk aan; loopt die leeg voordat er iemand
## drukt, dan komt `keuze_verlopen` eruit en is het aan de aanroeper om de box
## te sluiten. Nul is de gewone keuze: geen balk, geen signaal, wachten tot er
## gekozen wordt.
func show_choices(options: Array[String], timeout_sec: float = 0.0) -> void:
	_clear_choices()
	_hint.visible = false
	_skip_label.visible = false
	_klok_start(timeout_sec)
	for i: int in options.size():
		var b := UiKit.keuzeknop(options[i], UiKit.FS_SMALL)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_on_choice.bind(i))
		_choices.add_child(b)
	if _choices.get_child_count() > 0:
		(_choices.get_child(0) as Button).grab_focus()
	# Awaiten, niet vuur-en-vergeet: `_pas_hoogte_aan()` knipt de vraag terug
	# vóórdat hij meet, en dat kost sinds de keuzeklok twee frames in plaats
	# van één. Riep deze aanroep niet mee, dan rendert de box tussentijds met
	# de knoppen al zichtbaar maar de vraag nog ongekapt en het paneel nog op
	# zijn oude (kleinere) hoogte — precies het beeld uit `p4_klant_balk.png`,
	# nu als een paar frames flits in plaats van een blijvende toestand. Zie
	# `DialogueController._wait_for_choice()`, de enige aanroeper.
	await _pas_hoogte_aan()


## Meet wat de inhoud nodig heeft en zet de bovenrand daarop. Eerst een frame
## wachten: containers weten hun minimum pas na een layout-pass.
func _pas_hoogte_aan() -> void:
	# Altijd mét fit_content meten. Staat die van een vorige, te lange regel nog
	# uit, dan meldt het label 24px en meet deze regel de hoogte van de vorige.
	_text.fit_content = true
	_text.scroll_active = false

	var met_keuzes := _choices.get_child_count() > 0
	if met_keuzes:
		# Mét keuzes krijgt de vraag zijn eigen regelbudget vóórdat er iets
		# gemeten wordt: anders is `nodig` de hoogte van de hele, ongekapte
		# vraag, en klemt de clamp verderop precies zoals hij deed vóór deze
		# fix — alleen dan tegen een hoger plafond.
		await _beperk_vraag_tot_regels(MAX_REGELS_VRAAG_MET_KEUZES)
	else:
		# Zonder keuzes moet een eerdere afkap ongedaan gemaakt worden: anders
		# blijft de vraag van de vórige beurt met keuzes hier hangen met een
		# ellipsis terwijl er niets meer is dat om ruimte vraagt.
		_text.text = _full_text

	await get_tree().process_frame
	if not is_instance_valid(_panel):
		return
	var nodig: float = _panel.get_combined_minimum_size().y
	var grens := HOOGTE_MAX_KEUZES if met_keuzes else HOOGTE_MAX

	# HOOGTE_MAX was een clamp die niets klemde. `fit_content` laat het label
	# zijn volledige teksthoogte als minimum melden, en een Control kan niet
	# onder zijn minimum: het paneel werd alsnog zo hoog als de tekst, hoe laag
	# we `offset_top` ook zetten. `scroll_active` alleen repareert dat niet --
	# scrollen mag, maar zolang fit_content aanstaat vráágt het label de ruimte
	# nog steeds op. Past het niet, dan gaat fit_content dus uit; pas dan zakt
	# het minimum terug naar `custom_minimum_size` en klemt de clamp echt.
	var past := nodig <= grens
	_text.fit_content = past
	_text.scroll_active = not past

	var h: float = clampf(nodig, HOOGTE_MIN, grens)
	_panel.offset_top = -h - MARGE_ONDER
	_panel.offset_bottom = -MARGE_ONDER


## Knipt `_text` terug tot maximaal `regels` zichtbare regels, met een
## ellipsis als er iets wegvalt. `RichTextLabel` kent — anders dan `Label` —
## geen `max_lines_visible`/`text_overrun_behavior`: die twee zijn een
## Label-eigenschap en werken hier niet. Vandaar gemeten in plaats van gezet:
## de volledige vraag neerzetten, één layoutronde wachten, `get_line_count()`
## aflezen, en bij een overschrijding terugknippen tot waar `get_line_range()`
## zegt dat regel `regels - 1` eindigt.
##
## Die eerste knip plus een toegevoegde ellipsis kan zelf weer net over de
## regelgrens heen wippen (het teken kost zelf ook breedte), dus de lus knipt
## daarna karakter voor karakter terug tot het weer past. Voor de vraagteksten
## die dit spel kent (ruim onder de honderd tekens) is dat een handvol stappen.
func _beperk_vraag_tot_regels(regels: int) -> void:
	_text.text = _full_text
	await get_tree().process_frame
	if _text.get_line_count() <= regels:
		return

	var eind := _text.get_line_range(regels - 1).y
	var kort := _full_text.substr(0, eind).strip_edges()
	while kort.length() > 0:
		_text.text = kort + "…"
		await get_tree().process_frame
		if _text.get_line_count() <= regels:
			return
		kort = kort.substr(0, kort.length() - 1).strip_edges()
	_text.text = "…"


func typing() -> bool:
	return _typing


## Maakt de regel in één keer af in plaats van hem te laten uittikken.
func finish_typing() -> void:
	_typing = false
	_text.visible_characters = -1
	_hint.visible = true


func has_choices() -> bool:
	return _choices.get_child_count() > 0


func close() -> void:
	visible = false
	_klok_stop()
	_clear_choices()


func _clear_choices() -> void:
	for c: Node in _choices.get_children():
		c.queue_free()
		_choices.remove_child(c)


func _on_choice(index: int) -> void:
	_klok_stop()
	AudioDirector.play_ui(&"klik")
	choice_picked.emit(index)


## De klok voor deze keuze zetten. Nul of minder laat alles zoals het was.
func _klok_start(sec: float) -> void:
	_klok_max = maxf(0.0, sec)
	_klok_over = _klok_max
	_klok_vak.visible = _klok_max > 0.0
	_klok_balk.anchor_right = 1.0
	_klok_balk.color = UiKit.tijdkleur(1.0)


func _klok_stop() -> void:
	_klok_over = 0.0
	_klok_max = 0.0
	if _klok_vak != null:
		_klok_vak.visible = false


## Een frame van de keuzeklok. De kleur loopt mee met wat er over is
## (`UiKit.tijdkleur()`), zodat "bijna op" te zien is zonder een getal te lezen.
func _klok_tik(delta: float) -> void:
	if _klok_over <= 0.0:
		return
	_klok_over = maxf(0.0, _klok_over - delta)
	var deel := clampf(_klok_over / maxf(0.001, _klok_max), 0.0, 1.0)
	_klok_balk.anchor_right = deel
	_klok_balk.color = UiKit.tijdkleur(deel)
	if _klok_over > 0.0:
		return
	# Eerst stoppen, dan melden: de luisteraar sluit de box, en een klok die dan
	# nog loopt vuurt het volgende frame nog een keer.
	_klok_stop()
	keuze_verlopen.emit()
