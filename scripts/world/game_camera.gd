class_name GameCamera
extends Camera2D
## Volgt de speler, maar los van hem zodat hij na een ticket naar het
## veranderde object kan pannen.
##
## De verdieping is 26 tegels = 416 px hoog en de viewport is even hoog, dus
## verticaal valt er niets te volgen: de limieten klemmen Y volledig vast. De
## camera is daarmee een pure horizontale volger. Wel een vooruitblik, want je
## ziet in portrait maar 12 tegels breed.

const FOCUS_SPEED := 260.0
const VOORUITBLIK := 14.0
const VOORUITBLIK_LERP := 3.0

## Hoeveel de wereld maximaal omlaag mag schuiven om onder de HUD vandaan te
## komen, in canvaspixels.
##
## De HUD-chips bovenin staan over rij 0 van de verdieping. Die rij is muur, dus
## daar valt niets te verliezen — maar één pixel lager begint het spel:
## `deploycomputer` op tegel (1,1), `sprintbord_vloer` op (25,1), en de vier
## vergaderkamers waar collega's rondlopen (rijen 1 t/m 6).
##
## **Waarom een plafond, en waarom juist twaalf.** Alles wat er bovenaan bij
## komt, gaat er onderaan af: de verdieping is precies even hoog als de viewport,
## dus dit schuift geen ruimte bij, het verdeelt hem opnieuw. Onderaan staat rij
## 24 met interactables (o.a. `ticketbord` op tegel 13,24) en rij 25 draagt de
## `ticketbord`- en `monitor`-props uit `floor.json`. Twaalf pixels kost de
## onderste driekwart van die muurrij en niets speelbaars; zesentwintig — de
## volle hoogte van de chips — zou de ticketbordknop half onder de knoppenbalk
## duwen.
const MAX_VERSCHUIVING := 12.0

var target: Node2D = null
var _focus_pos: Vector2 = Vector2.ZERO
var _focus_left: float = 0.0
var _vooruit: float = 0.0


func _ready() -> void:
	position_smoothing_enabled = true
	position_smoothing_speed = 6.0
	Bus.camera_focus_requested.connect(_on_focus_requested)


## De wereld onder de HUD-chips vandaan schuiven.
##
## Via `offset` en niet via `position` of de limieten, want dat is de enige knop
## die hier iets doet: de verdieping is 26 tegels en de viewport ook, dus
## `limit_top`/`limit_bottom` klemmen Y onherroepelijk op 208. `Camera2D.offset`
## gaat volgens de documentatie bewust wél voorbij die limieten, en dat is
## precies waar hij hier voor gebruikt wordt.
##
## `main.gd` roept dit aan zodra de HUD staat — die meet zijn eigen balk, zodat
## dit getal niet op twee plekken geraden wordt. Alles wat via
## `get_canvas_transform()` rekent volgt vanzelf mee: `Besturing._probeer_tik()`,
## `ObjectiveMarker._zichtbaar()` en `_geklemde_y()`.
func zak_onder_hud(hud_hoogte: float) -> void:
	offset.y = -minf(maxf(hud_hoogte, 0.0), MAX_VERSCHUIVING)


func setup(follow: Node2D, world: Rect2) -> void:
	target = follow
	limit_left = int(world.position.x)
	limit_top = int(world.position.y)
	limit_right = int(world.end.x)
	limit_bottom = int(world.end.y)
	# Harde grenzen geven een schokkende visuele stop. Valt nu al op aan de
	# randen van de entree, en straks permanent als de vloer smaller wordt.
	limit_smoothed = true
	_vooruit = 0.0
	if target != null:
		global_position = target.global_position
		reset_smoothing()


func _process(delta: float) -> void:
	if _focus_left > 0.0:
		_focus_left -= delta
		global_position = global_position.move_toward(_focus_pos, FOCUS_SPEED * delta)
		return
	if target == null:
		return

	# Alleen X: de vooruitblik in Y zou in een gebouw van 26 tegels hoog steeds
	# tegen de limiet aanlopen en dan schokken.
	var wens := 0.0
	var body := target as CharacterBody2D
	if body != null and absf(body.velocity.x) > 10.0:
		wens = signf(body.velocity.x) * VOORUITBLIK
	_vooruit = lerpf(_vooruit, wens, VOORUITBLIK_LERP * delta)
	global_position = target.global_position + Vector2(_vooruit, 0.0)


func focus_on(pos: Vector2, hold: float) -> void:
	_focus_pos = pos
	_focus_left = hold


func _on_focus_requested(world_id: StringName, hold: float) -> void:
	var reg := get_tree().get_first_node_in_group(&"world_registry") as WorldRegistry
	if reg == null:
		return
	var wo := reg.get_by_id(world_id)
	if wo != null:
		focus_on(wo.global_position, hold)
