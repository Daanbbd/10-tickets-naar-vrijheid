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
	_pas_hoogte_aan()


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
	_pas_hoogte_aan()


## Meet wat de inhoud nodig heeft en zet de bovenrand daarop. Eerst een frame
## wachten: containers weten hun minimum pas na een layout-pass.
func _pas_hoogte_aan() -> void:
	# Altijd mét fit_content meten. Staat die van een vorige, te lange regel nog
	# uit, dan meldt het label 24px en meet deze regel de hoogte van de vorige.
	_text.fit_content = true
	_text.scroll_active = false
	await get_tree().process_frame
	if not is_instance_valid(_panel):
		return
	var nodig: float = _panel.get_combined_minimum_size().y

	# HOOGTE_MAX was een clamp die niets klemde. `fit_content` laat het label
	# zijn volledige teksthoogte als minimum melden, en een Control kan niet
	# onder zijn minimum: het paneel werd alsnog zo hoog als de tekst, hoe laag
	# we `offset_top` ook zetten. `scroll_active` alleen repareert dat niet --
	# scrollen mag, maar zolang fit_content aanstaat vráágt het label de ruimte
	# nog steeds op. Past het niet, dan gaat fit_content dus uit; pas dan zakt
	# het minimum terug naar `custom_minimum_size` en klemt de clamp echt.
	var past := nodig <= HOOGTE_MAX
	_text.fit_content = past
	_text.scroll_active = not past

	var h: float = clampf(nodig, HOOGTE_MIN, HOOGTE_MAX)
	_panel.offset_top = -h - MARGE_ONDER
	_panel.offset_bottom = -MARGE_ONDER


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
