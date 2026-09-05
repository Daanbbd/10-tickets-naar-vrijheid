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

## De schok van `schok()`: amplitude in canvaspixels, hoeveel tijd er nog over
## is en hoe lang hij in totaal duurt, zodat de amplitude lineair kan uitsterven.
var _schok_amp: float = 0.0
var _schok_over: float = 0.0
var _schok_duur: float = 0.0
## De rustwaarde van `offset.y` uit `zak_onder_hud()`. De schok tekent hier
## omheen en zet `offset` er na afloop op terug.
var _offset_basis_y: float = 0.0
## De vloer en hoeveel wandrand er daarbuiten getekend is (in px, per kant),
## voor `_pas_limieten_aan()`.
var _vloer: Rect2 = Rect2()
var _rand_max: float = 0.0
var _limieten_verbonden: bool = false


func _ready() -> void:
	position_smoothing_enabled = true
	position_smoothing_speed = 6.0
	Bus.camera_focus_requested.connect(_on_focus_requested)
	# `Juice.schok()` vindt de camera via deze groep; niemand geeft hem door.
	add_to_group(&"game_camera")
	# Is `setup()` al vóór het toevoegen aan de boom aangeroepen, dan is de
	# viewport-koppeling toen overgeslagen; haal dat hier in.
	if _vloer.has_area() and not _limieten_verbonden:
		_pas_limieten_aan()
		get_viewport().size_changed.connect(_pas_limieten_aan)
		_limieten_verbonden = true


## De wereld onder de HUD-chips vandaan schuiven.
##
## Via `offset` en niet via `position` of de limieten, want dat is de enige knop
## die hier iets doet: de verdieping is 26 tegels en de viewport op een 6:13-
## toestel ook, dus `limit_top`/`limit_bottom` klemmen Y daar onherroepelijk op
## 208 (op een hoger toestel krijgen ze `rand_voor()` speling, maar dat is
## symmetrisch en verschuift het midden niet). `Camera2D.offset`
## gaat volgens de documentatie bewust wél voorbij die limieten, en dat is
## precies waar hij hier voor gebruikt wordt.
##
## `main.gd` roept dit aan zodra de HUD staat — die meet zijn eigen balk, zodat
## dit getal niet op twee plekken geraden wordt. Alles wat via
## `get_canvas_transform()` rekent volgt vanzelf mee: `Besturing._probeer_tik()`,
## `ObjectiveMarker._zichtbaar()` en `_geklemde_y()`.
func zak_onder_hud(hud_hoogte: float) -> void:
	_offset_basis_y = -minf(maxf(hud_hoogte, 0.0), MAX_VERSCHUIVING)
	offset.y = _offset_basis_y


## De camera even laten schokken; `Juice.schok()` komt hier via de groep uit.
##
## Klein houden, twee tot drie pixels. Het canvas snapt op hele pixels, dus
## een amplitude van 2 is geen zachte trilling maar een tik van hele
## beeldpixels heen en terug — en dat is precies het impactframe dat je wil.
## Meer dan dat leest als een camera die stuk is. De amplitude sterft lineair
## uit over `duur`; een nieuwe schok tijdens een lopende houdt de grootste
## amplitude en neemt de nieuwe duur.
func schok(px: float, duur: float) -> void:
	_schok_amp = maxf(_schok_amp, px)
	_schok_over = duur
	_schok_duur = maxf(0.01, duur)


## `world` is de vloer; `met_rand` is de vloer plus de getekende wandrand
## boven en onder (`WorldBuilder.world_rect_met_rand()`). Op een canvas van
## precies 416 px maakt dat tweede rect niets uit: de camera klemt dan zoals
## altijd op de vloer. Op een hoger toestel (`window/stretch/aspect = "expand"`,
## bijvoorbeeld 9:21 = 448 px) mag hij precies het verschil erbij zien, gelijk
## verdeeld over boven en onder — zie `rand_voor()`.
func setup(follow: Node2D, world: Rect2, met_rand: Rect2 = Rect2()) -> void:
	target = follow
	_vloer = world
	_rand_max = maxf(0.0, (met_rand.size.y - world.size.y) * 0.5) if met_rand.has_area() else 0.0
	limit_left = int(world.position.x)
	limit_right = int(world.end.x)
	_pas_limieten_aan()
	# Buiten de boom (de testsuite bouwt camera's los) is er geen viewport om op
	# te letten; dan gelden de vloergrenzen en verbinden we later, in `_ready`.
	if not _limieten_verbonden and is_inside_tree():
		get_viewport().size_changed.connect(_pas_limieten_aan)
		_limieten_verbonden = true
	# Harde grenzen geven een schokkende visuele stop. Valt nu al op aan de
	# randen van de entree, en straks permanent als de vloer smaller wordt.
	limit_smoothed = true
	_vooruit = 0.0
	if target != null:
		global_position = target.global_position
		reset_smoothing()


## Hoeveel de camera boven en onder de vloer mag kijken: precies de helft van
## wat het canvas hoger is dan de vloer, en nooit meer dan de getekende rand.
## Op een toestel van exact 416 px is dat nul en verandert er niets; op 448 px
## komt er 16 px muur boven en onder, en blijft de vloer gecentreerd. Statisch
## en zonder engine-state, zodat `_test_responsief()` hem kaal kan doorrekenen.
static func rand_voor(canvas_h: float, vloer_h: float, rand_max: float) -> float:
	return clampf((canvas_h - vloer_h) * 0.5, 0.0, rand_max)


## De verticale limieten opnieuw uitrekenen; ook aangeroepen als het venster van
## maat verandert (draaien, een browservenster dat groeit).
func _pas_limieten_aan() -> void:
	if not _vloer.has_area():
		return
	var canvas_h := get_viewport_rect().size.y if is_inside_tree() else _vloer.size.y
	var r := rand_voor(canvas_h, _vloer.size.y, _rand_max)
	limit_top = int(floorf(_vloer.position.y - r))
	limit_bottom = int(ceilf(_vloer.end.y + r))


func _process(delta: float) -> void:
	# De schok loopt over `offset`, net als de HUD-verschuiving, en los van de
	# volgroutine hieronder: die schrijft `global_position`, dit schrijft
	# `offset`, dus ze zitten elkaar niet in de weg. Vandaar geen return — een
	# schok tijdens een focus-pan hoort de pan niet stil te zetten.
	if _schok_over > 0.0:
		_schok_over -= delta
		if _schok_over <= 0.0:
			offset = Vector2(0.0, _offset_basis_y)
			_schok_amp = 0.0
		else:
			var a := _schok_amp * (_schok_over / _schok_duur)
			offset = Vector2(randf_range(-a, a), _offset_basis_y + randf_range(-a, a))
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
