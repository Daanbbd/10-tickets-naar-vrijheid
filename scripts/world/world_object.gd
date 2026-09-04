class_name WorldObject
extends Node2D
## Muteerbaar wereldobject. Wordt aangesproken via world_id, nooit via NodePath,
## zodat een nieuwe plattegrond geen enkele verwijzing breekt.

## De Label wordt pas aangemaakt zodra er echt tekst op moet: van de 38 objecten
## krijgen er maar tien ooit een set_text, en dat pas nadat hun ticket klaar is.

@export var world_id: StringName = &""

const LABEL_BREEDTE := 108.0

## Ondergrens; de echte hoogte komt uit de tekst. Zie `_meet_label()`.
const LABEL_HOOGTE := 14.0

const SPRITE_NAAM := "Sprite"

## De Sprite2D gaat dezelfde kant op als de Label: hij bestaat alleen als er ook
## echt een beeld voor dit object is. Vandaag heeft geen enkel object er een — de
## meubels staan als losse props op `objects_layer` en dit blijft een onzichtbaar
## anker voor de Interactable. `set_sprite()` is de plek waar dat verandert zodra
## er een spritepad in de data staat, en `op_set_modulate` kleurt de hele node,
## dus vanaf dat moment doet die operatie ook echt iets.
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

func op_set_modulate(c: Color) -> void:
	modulate = c

## Zet tekst op het object zelf: het whiteboard krijgt de user story, het
## serverrack "200 OK". Maakt de Label aan bij de eerste aanroep.
func op_set_text(t: String) -> void:
	if _label == null:
		_label = _maak_label()
	_label.text = t
	_label.visible = t != ""
	_meet_label()


## De hoogte volgt de tekst, en de tekst hangt met zijn onderrand boven het
## object.
##
## Dit stond op een vaste 96x30 met `VERTICAL_ALIGNMENT_BOTTOM`. Negen van de
## tien wereldteksten zijn kort ("A/B: A wint", "productie: live") en pasten
## daar precies in. De tiende is de user story die BBD-201 op het whiteboard
## zet: 85 tekens, op 96 px zes regels van elk twaalf. Die groeiden bóven de
## doos uit, want een Label knipt niet: je kreeg zes regels contourtekst dwars
## over het vergaderhok, de bureaus en de ticketbriefjes heen, zonder
## achtergrond. Dat leest niet als een whiteboard maar als een renderfout.
func _meet_label() -> void:
	if _label == null:
		return
	var hoog := maxf(LABEL_HOOGTE, _label.get_minimum_size().y)
	_label.size = Vector2(LABEL_BREEDTE, hoog)
	_label.position = Vector2(-LABEL_BREEDTE * 0.5, -hoog - 6.0)


func _maak_label() -> Label:
	var l := UiKit.label("", UiKit.FS_SMALL, UiKit.WIT)
	l.name = "Label"
	# Een Control onder een Node2D krijgt geen viewportformaat en geen anchors:
	# formaat en positie moeten hier met de hand, in wereldcoordinaten.
	# `custom_minimum_size.x` en niet alleen `size`: daar rekent
	# `get_minimum_size()` de afgebroken hoogte uit, en die hebben we in
	# `_meet_label()` nodig vóór de eerste layout-pas.
	l.custom_minimum_size = Vector2(LABEL_BREEDTE, 0.0)
	l.size = Vector2(LABEL_BREEDTE, LABEL_HOOGTE)
	l.position = Vector2(-LABEL_BREEDTE * 0.5, -LABEL_HOOGTE - 6.0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Contour én een paneel. De contour stond hier alleen, met als reden dat hij
	# op elke vloertegel leest en geen node kost. Dat klopt voor één regel op een
	# egale vloer; het klopt niet voor vier regels over het dambordpatroon van de
	# vergaderkamer met bureaustoelen eronder. Het paneel is halfdoorzichtig, dus
	# je ziet nog steeds waar het op hangt.
	var vlak := StyleBoxFlat.new()
	vlak.bg_color = Color(UiKit.INK, 0.72)
	vlak.set_corner_radius_all(2)
	vlak.content_margin_left = 3.0
	vlak.content_margin_right = 3.0
	vlak.content_margin_top = 2.0
	vlak.content_margin_bottom = 2.0
	l.add_theme_stylebox_override("normal", vlak)
	l.add_theme_constant_override("outline_size", 2)
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
