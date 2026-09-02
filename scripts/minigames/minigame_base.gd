class_name MinigameBase
extends Control
## Root van elke minigame. Draait als overlay op Shell/MinigameLayer, met
## `Session.input_locked` aan (`Shell.run_minigame()` zet dat) zodat de speler
## niet weg kan lopen — de wereld eromheen staat sinds F5-a niet meer stil.
## Mag Session LEZEN, nooit schrijven: de uitkomst gaat uitsluitend via
## finish() terug naar de TicketController.

signal finished(result: MinigameResult)

var minigame_id: StringName = &""
var config: Dictionary = {}

var _done: bool = false


func _ready() -> void:
	add_to_group(&"minigame")


## Wordt aangeroepen na add_child, dus @onready-refs bestaan al.
func setup(cfg: Dictionary) -> void:
	config = cfg
	# Inhoud die van buiten komt wint van het bestand. Zo kan een aanroeper
	# dezelfde mechaniek met een andere opgave draaien — dat is precies wat een
	# trait doet — zonder dat elke minigame apart moet weten dat dat bestaat.
	content_override = cfg.get("inhoud", {}) as Dictionary
	_on_setup()


## QA: lost de minigame direct correct op. Overschrijven waar dat kan;
## de standaard slaagt gewoon, zodat de questketen altijd doorloopt.
func qa_solve() -> void:
	succeed(100, {"qa": true})


## Overschrijven in elke minigame.
func _on_setup() -> void:
	push_error("MinigameBase._on_setup() niet overschreven in %s" % scene_file_path)


func succeed(score: int = 0, payload: Dictionary = {}) -> void:
	_finish(GameEnums.Outcome.SUCCESS, score, payload)

func fail(score: int = 0, payload: Dictionary = {}) -> void:
	_finish(GameEnums.Outcome.FAIL, score, payload)

func abort() -> void:
	_finish(GameEnums.Outcome.ABORT, 0, {})


func _finish(oc: GameEnums.Outcome, score: int, payload: Dictionary) -> void:
	if _done:
		return
	_done = true
	finished.emit(MinigameResult.make(minigame_id, oc, score, payload))


## Handige helpers voor de afgeleide minigames.
func player_character() -> CharacterDef:
	return Session.character()

func cfg(key: String, fallback: Variant = null) -> Variant:
	return config.get(key, fallback)


# --- Gedeelde vormgeving -------------------------------------------------

var _body: VBoxContainer = null
var _kolom: VBoxContainer = null
var _scroll: ScrollContainer = null
var _header: VBoxContainer = null
var _footer: VBoxContainer = null
var _status: Label = null
var _banner: PanelContainer = null
var _banner_label: Label = null
var _storing_paneel: PanelContainer = null
var _storing_label: Label = null


## Bouwt het venster en geeft de VBox terug waar de minigame zijn eigen UI in zet.
##
## `intro` wordt hier niet meer getoond: die tekst staat sinds `MinigameIntro`
## op een eigen scherm vóór dit venster opent, met ruimte om te ademen in
## plaats van vaste hoogte af te snoepen van de speelbare kaart eronder. De
## parameter blijft bestaan zodat alle elf aanroepen ongewijzigd blijven —
## zie `scripts/ui/minigame_intro.gd`.
func build_chrome(title: String, _intro: String) -> VBoxContainer:
	UiKit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(UiKit.dimmer(0.72))

	# Donker oppervlak, net als de rest van de shell. Dit was een crème
	# `UiKit.panel()`, en dat maakte de minigames het enige lichte scherm in een
	# spel waarvan het titelscherm, het uitlegscherm, de karakterselectie en de
	# HUD allemaal donker zijn. Je speelt tien keer per beurt zo'n scherm; de
	# flits bij het openen was daarmee het meest voorkomende beeld van het spel.
	#
	# SCHERM_NACHT en niet PANEL_DARK: dit is een scherm en geen paneeltje in de
	# HUD, en het is dezelfde ondergrond als het uitlegscherm en het titelscherm.
	# De rand blijft LINE, zodat het venster nog leest als iets dat bovenop de
	# gedimde wereld ligt in plaats van als de wereld zelf.
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UiKit.panel(UiKit.SCHERM_NACHT, UiKit.LINE))
	UiKit.full_rect(frame)
	frame.offset_left = 4; frame.offset_right = -4
	frame.offset_top = 4; frame.offset_bottom = -4
	add_child(frame)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	frame.add_child(col)
	_kolom = col

	# Titel en status onder elkaar, niet naast elkaar: op 192 px is een kop op
	# FS_HEAD naast een statusregel breder dan het scherm, en een Container
	# groeit buiten zijn ankers om zijn kinderen te laten passen.
	#
	# FS_HEAD is de schermkop van de ladder, en dit is een scherm. Dat een titel
	# van twee woorden hier over twee regels valt is de prijs; de inhoud eronder
	# zit in een ScrollContainer en vangt dat op. Kleur en maat komen van het
	# uitlegscherm: BLUEBIRD_BRIGHT op FS_HEAD, want bb-blue zelf is op een
	# donkere ondergrond niet te lezen.
	var t := UiKit.label(title, UiKit.FS_HEAD, UiKit.BLUEBIRD_BRIGHT)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(t)
	_status = UiKit.label("", UiKit.FS_SMALL, UiKit.GRIJS_OP_DONKER)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(_status)

	# Op een portretcanvas past de inhoud van een minigame lang niet altijd in
	# beeld. Zonder scroll valt de knop onderaan buiten het scherm en is de
	# minigame niet uit te spelen.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_scroll = scroll

	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 3)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(_body)

	# Esc bestaat niet op een telefoon. Zonder een zichtbare uitweg zit een
	# speler vast in een minigame die hij niet kan oplossen, en dat is de enige
	# plek in het spel waar de wereld niet meer bereikbaar is. Dus een knop, op
	# elk apparaat; Esc blijft ernaast werken als sneltoets.
	var stop := UiKit.button("Stoppen", UiKit.FS_SMALL)
	stop.focus_mode = Control.FOCUS_NONE
	stop.pressed.connect(abort)
	col.add_child(stop)

	_banner = PanelContainer.new()
	_banner.add_theme_stylebox_override("panel", UiKit.panel(UiKit.GROEN, UiKit.INK, 2))
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.anchor_left = 0.5; _banner.anchor_right = 0.5
	_banner.anchor_top = 0.5; _banner.anchor_bottom = 0.5
	_banner.offset_left = -92; _banner.offset_right = 92
	_banner.offset_top = -18; _banner.offset_bottom = 18
	_banner.visible = false
	add_child(_banner)
	_banner_label = UiKit.label("", UiKit.FS_BODY, UiKit.INK)
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner.add_child(_banner_label)

	return _body


## Twee stroken die **niet** meescrollen: boven en onder de inhoud.
##
## Vijf minigames hebben hier los van elkaar hetzelfde omheen gebouwd. Een
## meter, een klok, een dashboard of de enige actieknop mag niet wegscrollen —
## dan is hij precies weg op het moment dat je hem nodig hebt — maar
## `build_chrome()` gaf alleen de body *binnen* de ScrollContainer terug. Elke
## implementatie klom daarom via `body.get_parent().get_parent()` naar de kolom
## en schoof zijn node met `move_child()` op de goede index.
##
## Dat werkte, maar het is vijf keer dezelfde aanname over de binnenkant van
## deze klasse: wie hier een node tussenvoegt, breekt vijf minigames stil.
## Vandaar dat de stroken nu deel van het contract zijn.
##
## Beide worden pas gemaakt als je ze opvraagt, en de volgorde waarin dat
## gebeurt doet niet uit: de header landt altijd vóór de scroll en de footer
## altijd erna.
func chrome_header() -> VBoxContainer:
	if _header == null:
		_header = _strook()
		_kolom.add_child(_header)
		_kolom.move_child(_header, _scroll.get_index())
	return _header


func chrome_footer() -> VBoxContainer:
	if _footer == null:
		_footer = _strook()
		_kolom.add_child(_footer)
		_kolom.move_child(_footer, _scroll.get_index() + 1)
	return _footer


static func _strook() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Krimpen naar de inhoud: een strook die verticaal wil groeien vecht met de
	# ScrollContainer ernaast om de resterende hoogte.
	v.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return v


func set_status(text: String) -> void:
	if _status != null:
		_status.text = text


## F5-b: een storing landt hier, niet als overlay erboven. De telefoon (laag
## 30) en de HUD-toast (laag 10) liggen allebei onder de minigame (laag 50),
## dus onzichtbaar zolang dit scherm openstaat — `Storingen` roept dit aan op
## `Shell.active_minigame()` in plaats van de gewone wereldmelding te tonen.
##
## `kosten` is aan de minigame: een seconde van de klok, een mislukte
## handeling, een bug erbij. Deze basisklasse doet er niets mee — hij toont
## alleen de tekst in `chrome_header()`, wat het contract al vervult ("moet
## minstens visueel landen"). Een minigame die `kosten` wél wil verwerken
## overschrijft dit en roept `super.storing(tekst, kosten)` aan zodat de strook
## blijft verschijnen.
func storing(tekst: String, _kosten: Dictionary) -> void:
	var strook := chrome_header()
	if _storing_paneel == null:
		_storing_paneel = PanelContainer.new()
		_storing_paneel.add_theme_stylebox_override("panel", UiKit.panel(UiKit.ROOD, UiKit.INK))
		_storing_label = UiKit.label("", UiKit.FS_SMALL, UiKit.INK)
		_storing_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_storing_paneel.add_child(_storing_label)
		strook.add_child(_storing_paneel)
	_storing_label.text = tekst
	AudioDirector.play_ui(&"fout")
	Haptiek.tril(Haptiek.Sterkte.STOOT)


## Toont de uitslag en sluit daarna af.
func finish_with_banner(ok: bool, text: String, score: int = 0, payload: Dictionary = {}) -> void:
	if _done:
		return
	if _banner != null:
		_banner.add_theme_stylebox_override("panel",
			UiKit.panel(UiKit.GROEN if ok else UiKit.ROOD, UiKit.INK, 2))
		_banner_label.text = text
		_banner.visible = true
	AudioDirector.play_ui(&"ticket_klaar" if ok else &"fout")
	# De banner is groen of rood, maar op een telefoon in de trein is het geluid
	# uit en zit het scherm halverwege achter een duim. De trilling draagt hier
	# dezelfde uitslag: lang voor gelukt, kort en hard voor mislukt.
	Haptiek.tril(Haptiek.Sterkte.GELUKT if ok else Haptiek.Sterkte.SLAG)
	# F5-a: `process_always = true` was hier nodig zolang de wereld gepauzeerd
	# stond terwijl deze minigame liep. Dat geldt sinds F5-a niet meer voor een
	# gewone speelbeurt, maar backgrounden pauzeert de tree nog altijd wél,
	# ongeacht of er een minigame loopt (zie `Shell._naar_achtergrond()`).
	# Blijft op `true` staan: dat is ook Godot's eigen standaard voor
	# `create_timer()`, en elke ongeflagde timer in `main.gd` gedraagt zich nu
	# al zo. Dit hier anders laten gedragen dan de rest van de codebase is geen
	# scope van F5 — zie dezelfde afweging bij `Shell._qa_shot()` en
	# `mg_oplevering.gd::_pauze()`.
	await get_tree().create_timer(1.9 if ok else 1.6, true).timeout
	if ok:
		succeed(score, payload)
	else:
		fail(score, payload)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		abort()


## Inhoud uit data/minigame_content.json, per minigame-id.
##
## Gezet door `setup()` uit de configsleutel `inhoud`, en anders leeg. De enige
## aanroeper vandaag is `TraitModifier` via `TicketController`: die leest de
## inhoud uit het bestand, past het voordeel van je vakgebied toe en geeft het
## geheel terug. Leeg = het bestand, ongewijzigd.
var content_override: Dictionary = {}

## Titel uit data/minigames.json, zodat elke minigame automatisch de juiste kop krijgt.
func default_title() -> String:
	var m := GameData.minigames.get(minigame_id, {}) as Dictionary
	return String(m.get("title", "Opdracht"))


func content() -> Dictionary:
	return content_override if not content_override.is_empty() else MinigameContent.get_config(minigame_id)
