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

const LABEL_BREEDTE := 108.0

## Ondergrens; de echte hoogte komt uit de tekst. Zie `_meet_label()`.
const LABEL_HOOGTE := 14.0
## Onder deze wereld-y (vijf tegelrijen) hangt een label onder het object in
## plaats van erboven, omdat de HUD-band de bovenste rijen afdekt. Zie
## `_maak_label()`.
const LABEL_ONDER_GRENS := 80.0

## Boven de meubels, onder de gidslaag.
##
## Het label had géén `z_index` — nagerekend: het woord kwam in dit bestand
## niet voor. Het erfde dus 0 en y-sorteerde mee op de positie van zijn
## WorldObject, terwijl props op de ónderrand van hun footprint sorteren
## (`main.gd::_plaats_prop()`). De beamer staat op wereld-y 72 en de
## vergadertafel op 80, dus die tafel werd ná het label getekend en dekte de
## tekst af. Daan (#32): *"Tekst staat achter vergadertafel."*
##
## 21 en niet hoger: props, hangende bordjes, ticketbriefjes en barks zitten
## allemaal op 20, en de doelwijzer en de tikmarker op 60. Dit label hoort boven
## het meubilair en onder alles wat je kunt aantikken.
const LABEL_Z := 21

## Marge tot de schermrand bij het klemmen. Zelfde waarde als
## `TapMarker.RANDMARGE`, want het is hetzelfde probleem.
const LABEL_RANDMARGE := 4.0


## Hoort het label van een object op deze wereld-y onder het object te hangen?
## Statisch zodat de testsuite de grens kaal kan controleren.
static func label_onder(origin_y: float) -> bool:
	return origin_y < LABEL_ONDER_GRENS

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
## Het label horizontaal binnen beeld houden.
##
## Het stond hard op `-LABEL_BREEDTE * 0.5` ten opzichte van het object, dus bij
## een object aan de rand van het zichtbare stuk vloer liep de helft van de
## tekst buiten het canvas. Daan las daardoor "…EN SIGNAAL" (#31, #32),
## "…taging: layout OK" (#23, #29) en "…supplementen …gelijken" (#36) — en dacht
## bij dat laatste dat het restanten van een vastloper waren (#37).
##
## `TapMarker._leg_kaartje()` en `ObjectiveMarker` klemmen zich al zo; dit label
## was de enige wereldtekst die het niet deed. Zelfde rekensom, dezelfde marge.
func _process(_delta: float) -> void:
	if _label == null or not _label.visible:
		return
	var vp := get_viewport()
	if vp == null:
		return
	var zicht := vp.get_canvas_transform().affine_inverse() * \
		Rect2(Vector2.ZERO, vp.get_visible_rect().size)
	if zicht.size.x <= 0.0:
		return
	var half := _label.size.x * 0.5
	var links := zicht.position.x + LABEL_RANDMARGE + half
	var rechts := zicht.end.x - LABEL_RANDMARGE - half
	var x := -half
	if rechts > links:
		x = clampf(global_position.x, links, rechts) - global_position.x - half
	_label.position.x = floorf(x)


func _meet_label() -> void:
	if _label == null:
		return
	var hoog := maxf(LABEL_HOOGTE, _label.get_minimum_size().y)
	_label.size = Vector2(LABEL_BREEDTE, hoog)
	# Onder of boven, dezelfde keuze als in `_maak_label()`.
	#
	# Hier stond die keuze niet: de y werd onvoorwaardelijk op `-hoog - 6` gezet,
	# dus élk label kwam bóven zijn object — ook de labels waarvoor
	# `_maak_label()` net zorgvuldig "eronder" had uitgerekend. `_maak_label()`
	# loopt één keer bij het aanmaken en `_meet_label()` bij elke tekstwijziging,
	# dus de tweede overschreef de eerste altijd.
	#
	# Dat is te zien op `docs/audit-shots/los.png` van 6 september: het
	# whiteboard staat op rij 3 (wereld-y 56) en zijn drie regels tekst kwamen op
	# y 14 uit — midden in de HUD-band, achter de klok. Precies wat
	# `LABEL_ONDER_GRENS` moest voorkomen.
	if label_onder(global_position.y):
		var halve_hoogte := 8.0
		if _sprite != null and _sprite.texture != null:
			halve_hoogte = float(_sprite.texture.get_height()) * 0.5
		_label.position = Vector2(-LABEL_BREEDTE * 0.5, halve_hoogte + 2.0)
	else:
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
	l.z_index = LABEL_Z
	add_child(l)
	# Alleen een object mét label heeft een lus nodig; de andere ~37 blijven
	# stil. Zie `_process()`.
	set_process(true)
	return l

func op_set_locked(v: bool) -> void:
	_locked = v
	var it := get_node_or_null("Interactable") as Interactable
	if it != null:
		it.set_enabled(not v)

func is_locked() -> bool:
	return _locked
