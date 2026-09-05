class_name WorldObject
extends Node2D
## Muteerbaar wereldobject. Wordt aangesproken via world_id, nooit via NodePath,
## zodat een nieuwe plattegrond geen enkele verwijzing breekt.

## De Label wordt pas aangemaakt zodra er echt tekst op moet: van de 38 objecten
## krijgen er maar tien ooit een set_text, en dat pas nadat hun ticket klaar is.
##
## Twee ops veranderen het beeld van een object echt, niet alleen zijn kleur of
## zichtbaarheid: `swap_texture` wisselt de hele texture, `set_frame` kiest een
## ander frame in de spritesheet. Zo kan elk opgelost ticket pixels verzetten.

@export var world_id: StringName = &""

const LABEL_BREEDTE := 96.0
## Onder deze wereld-y (vijf tegelrijen) hangt een label onder het object in
## plaats van erboven, omdat de HUD-band de bovenste rijen afdekt. Zie
## `_maak_label()`.
const LABEL_ONDER_GRENS := 80.0


## Hoort het label van een object op deze wereld-y onder het object te hangen?
## Statisch zodat de testsuite de grens kaal kan controleren.
static func label_onder(origin_y: float) -> bool:
	return origin_y < LABEL_ONDER_GRENS
const LABEL_HOOGTE := 30.0

const SPRITE_NAAM := "Sprite"

## De Sprite2D gaat dezelfde kant op als de Label: hij bestaat alleen als er ook
## echt een beeld voor dit object is. Vandaag heeft geen enkel object er een — de
## meubels staan als losse props op `objects_layer` en dit blijft een onzichtbaar
## anker voor de Interactable. `set_sprite()` is de plek waar dat verandert zodra
## er een spritepad in de data staat; `op_swap_texture` en `op_set_frame` werken
## daarna op dit kind, en `op_set_modulate` kleurt de hele node, dus vanaf dat
## moment doet ook die operatie echt iets.
@onready var _sprite: Sprite2D = get_node_or_null(SPRITE_NAAM) as Sprite2D

var _label: Label = null
var _locked: bool = false


func _ready() -> void:
	add_to_group(&"world_object")
	_label = get_node_or_null("Label") as Label
	# Een WorldObject wordt in code gebouwd (`Main._spawn_objects`), dus het kind
	# kan er vóór of ná `_ready` bij komen. Niet vertrouwen op @onready alleen.
	if _sprite == null:
		_sprite = get_node_or_null(SPRITE_NAAM) as Sprite2D


# --- Beeld ----------------------------------------------------------------

## Geeft dit object een beeld. Maakt de Sprite2D aan bij de eerste aanroep en
## hergebruikt hem daarna, zodat een replay hetzelfde eindplaatje oplevert.
##
## Een leeg pad is de normale toestand en doet niets. Een pad dat niet bestaat
## laat het object staan zoals het stond en meldt zich in de log: de propdata
## mag vooruitlopen op een PNG die nog gegenereerd moet worden, zonder dat de
## hele vloer erop wacht.
func set_sprite(path: String) -> void:
	if path == "" or not ResourceLoader.exists(path):
		if path != "":
			push_warning("WorldObject %s: sprite ontbreekt: %s" % [world_id, path])
		return
	if _sprite == null:
		_sprite = get_node_or_null(SPRITE_NAAM) as Sprite2D
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.name = SPRITE_NAAM
		_sprite.centered = true
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# Vóór de Label en de Interactable: tekst hoort over het beeld heen.
		add_child(_sprite)
		move_child(_sprite, 0)
	_sprite.texture = load(path)


# --- Idempotente operaties, aangeroepen door WorldMutator -----------------

func op_set_visible(v: bool) -> void:
	visible = v

## Wisselt het beeld, en maakt het kind alsnog aan als dit object er nog geen
## had. Anders is een `swap_texture` op een spriteloos object een stille no-op —
## precies het soort verandering dat niemand mist tot de replay hem overslaat.
func op_swap_texture(path: String) -> void:
	set_sprite(path)

## Kiest een frame in de spritesheet van dit object. hframes/vframes zetten de
## sheet-indeling als ze > 0 zijn; anders blijft de huidige staan. Zonder sprite
## (het object is nog een onzichtbaar anker) alleen een waarschuwing.
func op_set_frame(frame: int, hframes: int = 0, vframes: int = 0) -> void:
	if _sprite == null:
		_sprite = get_node_or_null(SPRITE_NAAM) as Sprite2D
	if _sprite == null:
		push_warning("WorldObject %s: set_frame zonder sprite" % world_id)
		return
	if hframes > 0:
		_sprite.hframes = hframes
	if vframes > 0:
		_sprite.vframes = vframes
	_sprite.frame = clampi(frame, 0, maxi(0, _sprite.hframes * _sprite.vframes - 1))

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
	# Boven het object, behalve op de bovenste tegelrijen: daar dekt de HUD-band
	# alles af wat boven het object hangt (de deploycomputer op rij 1, het
	# whiteboard op rij 3, de koffiemachine op rij 4), en las je "DEPLOY 3/8" of
	# "productie: live" nooit. Daar hangt het label onder het object, op de vloer.
	if label_onder(global_position.y):
		var halve_hoogte := 8.0
		if _sprite != null and _sprite.texture != null:
			halve_hoogte = float(_sprite.texture.get_height()) * 0.5
		l.position = Vector2(-LABEL_BREEDTE * 0.5, halve_hoogte + 2.0)
		l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	else:
		l.position = Vector2(-LABEL_BREEDTE * 0.5, -LABEL_HOOGTE - 6.0)
		l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
