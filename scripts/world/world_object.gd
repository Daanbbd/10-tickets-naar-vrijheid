class_name WorldObject
extends Node2D
## Muteerbaar wereldobject. Wordt aangesproken via world_id, nooit via NodePath,
## zodat een nieuwe plattegrond geen enkele verwijzing breekt.

## De Label wordt pas aangemaakt zodra er echt tekst op moet: van de 38 objecten
## krijgen er maar tien ooit een set_text, en dat pas nadat hun ticket klaar is.

@export var world_id: StringName = &""

const LABEL_BREEDTE := 96.0
const LABEL_HOOGTE := 20.0

@onready var _sprite: Sprite2D = get_node_or_null("Sprite") as Sprite2D

var _label: Label = null
var _locked: bool = false


func _ready() -> void:
	add_to_group(&"world_object")
	_label = get_node_or_null("Label") as Label


# --- Idempotente operaties, aangeroepen door WorldMutator -----------------

func op_set_visible(v: bool) -> void:
	visible = v

func op_swap_texture(path: String) -> void:
	if _sprite != null and ResourceLoader.exists(path):
		_sprite.texture = load(path)

func op_set_modulate(c: Color) -> void:
	modulate = c

## Zet tekst op het object zelf: het whiteboard krijgt de user story, het
## serverrack "200 OK". Maakt de Label aan bij de eerste aanroep.
func op_set_text(t: String) -> void:
	if _label == null:
		_label = _maak_label()
	_label.text = t
	_label.visible = t != ""


func _maak_label() -> Label:
	var l := UiKit.label("", UiKit.FS_SMALL, UiKit.WIT)
	l.name = "Label"
	# Een Control onder een Node2D krijgt geen viewportformaat en geen anchors:
	# formaat en positie moeten hier met de hand, in wereldcoordinaten.
	l.size = Vector2(LABEL_BREEDTE, LABEL_HOOGTE)
	l.position = Vector2(-LABEL_BREEDTE * 0.5, -LABEL_HOOGTE - 6.0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Contour in plaats van een paneel: leest op elke vloertegel, kost geen node.
	l.add_theme_constant_override("outline_size", 3)
	l.add_theme_color_override("font_outline_color", UiKit.INK)
	add_child(l)
	return l

func op_set_locked(v: bool) -> void:
	_locked = v
	var it := get_node_or_null("Interactable") as Interactable
	if it != null:
		it.set_enabled(not v)

func is_locked() -> bool:
	return _locked
