class_name MinigameBase
extends Control
## Root van elke minigame. Draait als overlay op Shell/MinigameLayer terwijl de
## wereld gepauzeerd is. Mag Session LEZEN, nooit schrijven: de uitkomst gaat
## uitsluitend via finish() terug naar de TicketController.

signal finished(result: MinigameResult)

var minigame_id: StringName = &""
var config: Dictionary = {}

var _done: bool = false


func _ready() -> void:
	add_to_group(&"minigame")


## Wordt aangeroepen na add_child, dus @onready-refs bestaan al.
func setup(cfg: Dictionary) -> void:
	config = cfg
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
var _status: Label = null
var _banner: PanelContainer = null
var _banner_label: Label = null


## Bouwt het venster en geeft de VBox terug waar de minigame zijn eigen UI in zet.
func build_chrome(title: String, intro: String) -> VBoxContainer:
	UiKit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(UiKit.dimmer(0.72))

	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UiKit.panel())
	UiKit.full_rect(frame)
	frame.offset_left = 4; frame.offset_right = -4
	frame.offset_top = 4; frame.offset_bottom = -4
	add_child(frame)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	frame.add_child(col)

	# Titel en status onder elkaar, niet naast elkaar: op 192 px is een kop op
	# FS_HEAD naast een statusregel breder dan het scherm, en een Container
	# groeit buiten zijn ankers om zijn kinderen te laten passen.
	var t := UiKit.label(title, UiKit.FS_BODY, UiKit.INK)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(t)
	_status = UiKit.label("", UiKit.FS_SMALL, UiKit.GRIJS)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(_status)

	if intro != "":
		var i := UiKit.label(intro, UiKit.FS_SMALL, UiKit.GRIJS)
		i.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(i)

	# Op een portretcanvas past de inhoud van een minigame lang niet altijd in
	# beeld. Zonder scroll valt de knop onderaan buiten het scherm en is de
	# minigame niet uit te spelen.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)

	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 3)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(_body)

	# Esc bestaat niet op een telefoon. Zonder een zichtbare uitweg zit een
	# speler vast in een minigame die hij niet kan oplossen, en dat is de enige
	# plek in het spel waar de wereld niet meer bereikbaar is.
	if Invoer.touch():
		var stop := UiKit.button("Stoppen", UiKit.FS_SMALL)
		stop.custom_minimum_size = Vector2(0, 26)
		stop.focus_mode = Control.FOCUS_NONE
		stop.pressed.connect(abort)
		col.add_child(stop)
	else:
		var foot := UiKit.label("Tik om te kiezen  ·  Esc stoppen",
			UiKit.FS_SMALL, UiKit.GRIJS)
		foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		col.add_child(foot)

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


func set_status(text: String) -> void:
	if _status != null:
		_status.text = text


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
## De finale zet content_override zodat hij dezelfde mechanieken kan hergebruiken
## met een eigen, kortere config.
var content_override: Dictionary = {}

## Titel uit data/minigames.json, zodat elke minigame automatisch de juiste kop krijgt.
func default_title() -> String:
	var m := GameData.minigames.get(minigame_id, {}) as Dictionary
	return String(m.get("title", "Opdracht"))


func content() -> Dictionary:
	return content_override if not content_override.is_empty() else MinigameContent.get_config(minigame_id)
