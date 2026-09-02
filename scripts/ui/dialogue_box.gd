class_name DialogueBox
extends Control
## Dialoogvenster met typemachine-effect en keuzes. Bouwt zichzelf op in code
## zodat er geen tweede bron van waarheid in een .tscn ligt.

signal advance_requested()
signal choice_picked(index: int)

const CHARS_PER_SEC := 55.0

## Het paneel groeit omhoog mee met de tekst. Met een vaste hoogte van 70px viel
## langere dialoog onderuit beeld: RichTextLabel scrollt niet en klipt gewoon.
const MARGE_ONDER := 8.0
const HOOGTE_MIN := 70.0
const HOOGTE_MAX := 156.0

var _panel: PanelContainer
var _name: Label
var _text: RichTextLabel
var _choices: VBoxContainer
var _hint: Label
var _portrait: TextureRect

var _full_text: String = ""
var _revealed: float = 0.0
var _typing: bool = false


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

	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 2)
	v.add_child(_choices)

	# Eén regel, want tikken werkt overal: een muisklik gaat door voor een
	# vingertik zolang er geen aanraakscherm is (`Invoer.muis_als_vinger()`).
	# E doet hetzelfde en staat op de besturingskaart.
	_hint = UiKit.label("tik  verder", UiKit.FS_SMALL, UiKit.GRIJS_OP_LICHT)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(_hint)


func _process(delta: float) -> void:
	if not _typing:
		return
	_revealed += delta * CHARS_PER_SEC
	var total := float(_text.get_total_character_count())
	_text.visible_characters = int(_revealed)
	if _revealed >= total:
		_typing = false
		_text.visible_characters = -1
		_hint.visible = true


func show_line(speaker: String, text: String, portrait: Texture2D = null) -> void:
	visible = true
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
	_clear_choices()
	_pas_hoogte_aan()


func show_choices(options: Array[String]) -> void:
	_clear_choices()
	_hint.visible = false
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
	await get_tree().process_frame
	if not is_instance_valid(_panel):
		return
	var nodig: float = _panel.get_combined_minimum_size().y
	var h: float = clampf(nodig, HOOGTE_MIN, HOOGTE_MAX)
	_panel.offset_top = -h - MARGE_ONDER
	_panel.offset_bottom = -MARGE_ONDER
	# Past het echt niet, dan mag hij alsnog scrollen in plaats van klippen.
	_text.scroll_active = nodig > HOOGTE_MAX


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
	_clear_choices()


func _clear_choices() -> void:
	for c: Node in _choices.get_children():
		c.queue_free()
		_choices.remove_child(c)


func _on_choice(index: int) -> void:
	AudioDirector.play_ui(&"klik")
	choice_picked.emit(index)
