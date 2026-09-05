class_name Npc
extends CharacterBody2D
## Collega of bezoeker. Loopt een waypointroute, praat, en kan de speler volgen
## wanneer je hem als expert ophaalt voor een ticket.
##
## Bewust geen NavigationAgent2D: waypoints met move_toward volstaan op een
## kantoorvloer en zijn debugbaar.

signal aangekomen

const WALK_SPEED := 58.0
## Voorop lopen is sneller dan slenteren en trager dan achter iemand aan rennen.
## De speler loopt 96 en moet kunnen bijblijven zonder te hoeven sprinten.
const LEID_SPEED := 74.0
const FOLLOW_SPEED := 104.0
const FOLLOW_DISTANCE := 26.0
const ARRIVE_EPS := 3.0

## Na hoeveel seconden stilstaan iemand één keer zijn eigen bezigheid doet.
## Op het selectiescherm is dat 1,2 s, want daar kijk je iemand aan; hier loop
## je langs, en dan wordt elke twee seconden een tic in plaats van karakter.
##
## Elke NPC krijgt daar een eigen willekeurige voorsprong op. Zonder die spreiding
## staan zeven collega's op dezelfde frame te huilen, te bieren en te padellen,
## en dat leest als een bug in plaats van als een kantoor.
const BEZIG_NA := 6.5
const BEZIG_SPREIDING := 5.0

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var interactable: Interactable = $Interactable

var npc_id: StringName = &""
var def: NpcDef = null

var _route: PackedVector2Array = []
var _leg: int = 0
var _pause_left: float = 0.0
var _following: Node2D = null
var _home: Vector2 = Vector2.ZERO
## Een gerichte wandeling over een uitgerekende route: naar huis na een ticket,
## of naar het bord tijdens de introductie. Vervangt de oude `_returning`-vlag,
## die dezelfde bestemming in een rechte lijn benaderde.
var _koers: PackedVector2Array = []
var _koers_leg: int = 0
var _koers_speed: float = WALK_SPEED
var _builder: WorldBuilder = null
var _facing: Vector2 = Vector2.DOWN
var _stil: float = 0.0
var _bezig_bij: float = 0.0
var _bezig: bool = false
var _praat: bool = false


func setup(d: NpcDef, builder: WorldBuilder) -> void:
	def = d
	npc_id = d.id
	_builder = builder
	name = "Npc_%s" % d.id

	var home_tile := builder.nearest_walkable(d.home_tile)
	_home = builder.tile_to_world(home_tile)
	global_position = _home

	_route = PackedVector2Array()
	for t: Vector2i in d.route:
		_route.append(builder.tile_to_world(builder.nearest_walkable(t)))

	sprite.sprite_frames = CharacterSprites.static_frames(d.static_sprite) \
		if d.static_sprite != "" else CharacterSprites.frames_for(
			d.look, d.color, d.skin, d.hair, d.pants, d.accent)
	sprite.play("idle_down")

	interactable.world_id = StringName("npc_obj_%s" % d.id)
	interactable.kind = Interactable.Kind.TALK
	interactable.label = d.name
	interactable.dialogue_id = d.dialogue_id

	_bezig_bij = BEZIG_NA + randf() * BEZIG_SPREIDING
	sprite.animation_finished.connect(_op_animatie_klaar)
	Bus.dialogue_started.connect(_op_dialoog_start)
	Bus.dialogue_finished.connect(_op_dialoog_eind)


## Wie er praat, zodat de juiste collega zijn mond beweegt en de andere zes
## niet. De dialoog noemt sprekers zonder `npc_`-voorvoegsel ("victor"), de
## NPC's heten `npc_victor`; het dialoog-id is de tweede ingang, want bij een
## wervingsgesprek staat de spreker per node en niet op de boom.
func _op_dialoog_start(dialogue_id: StringName, speaker: StringName) -> void:
	# `def.dialogue_id != &""` erbij, want een lege id is geen match maar een
	# NPC zonder eigen gesprek. De drie paardenbugs uit BBD-209 hebben er geen,
	# en `DialogueController` zendt bij een vertellerregel `dialogue_started`
	# met een lege id: zonder deze wacht gingen alle drie in praatstand bij elke
	# regel die er de rest van de dag viel.
	_praat = (def.dialogue_id != &"" and dialogue_id == def.dialogue_id) \
		or (speaker != &"" and speaker == StringName(String(npc_id).trim_prefix("npc_")))
	if _praat:
		_bezig = false


func _op_dialoog_eind(_dialogue_id: StringName, _outcome: StringName) -> void:
	_praat = false


## `bezig_down` loopt niet, dus na één keer terug naar stilstaan.
func _op_animatie_klaar() -> void:
	if sprite.animation == &"bezig_down":
		_bezig = false
		_stil = 0.0
		_bezig_bij = BEZIG_NA + randf() * BEZIG_SPREIDING


func _physics_process(delta: float) -> void:
	if _following != null:
		_do_follow(delta)
	elif not _koers.is_empty():
		_do_koers()
	else:
		_do_route(delta)

	move_and_slide()
	_animate()


# --- Gedrag ---------------------------------------------------------------

func _do_route(delta: float) -> void:
	if _route.size() < 2:
		velocity = Vector2.ZERO
		return
	if _pause_left > 0.0:
		_pause_left -= delta
		velocity = Vector2.ZERO
		return

	var target := _route[_leg]
	if global_position.distance_to(target) <= ARRIVE_EPS:
		_leg = (_leg + 1) % _route.size()
		_pause_left = def.route_pause
		velocity = Vector2.ZERO
		return
	_move_towards(target, WALK_SPEED)


## `is_instance_valid()` en niet alleen de null-check die `_physics_process()`
## al doet: niets zet `_following` terug op null als het gevolgde object wordt
## opgeruimd. `_exit_tree()` hieronder ruimt alleen de volger-kant op, en de
## drie plekken die `start_following()` aanroepen (de intro, een geworven
## collega, een storing) laten allemaal een verwijzing achter die deze node
## overleeft. Dit is de enige plek in dit bestand die daarop "attempt to call
## function on a previously freed instance" kan geven.
func _do_follow(delta: float) -> void:
	if not is_instance_valid(_following):
		stop_following(true)
		return
	var to := _following.global_position - global_position
	if to.length() <= FOLLOW_DISTANCE:
		velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
		return
	_move_towards(_following.global_position, FOLLOW_SPEED)


## Onderweg naar een bestemming, punt voor punt.
##
## Hier stond `_do_return()`: `_move_towards(_home, WALK_SPEED)`, een rechte
## lijn. Een collega die bij het scrumbord wordt vrijgelaten koerst daarmee op
## Summit (35,6) aan dwars door twee bureau-eilanden en de gangmuur;
## `move_and_slide()` laat hem daarlangs glijden tot hij in een hoek klem staat
## en er niets meer beweegt. Zie `WorldBuilder.pad()`.
func _do_koers() -> void:
	if _koers_leg >= _koers.size():
		_koers = PackedVector2Array()
		velocity = Vector2.ZERO
		aangekomen.emit()
		return
	var doel := _koers[_koers_leg]
	if global_position.distance_to(doel) <= ARRIVE_EPS * 2.0:
		_koers_leg += 1
		velocity = Vector2.ZERO
		return
	_move_towards(doel, _koers_speed)


## Loop over de vloer naar deze plek. Zonder loopbare route toch rechtstreeks:
## een NPC die niets doet is erger dan een NPC die tegen een muur duwt, en
## `pad()` trekt een doel in een muur al naar de dichtstbijzijnde tegel.
func loop_naar(doel: Vector2, snelheid: float = WALK_SPEED) -> void:
	_koers_speed = snelheid
	_koers_leg = 0
	_koers = PackedVector2Array()
	if _builder != null:
		_koers = _builder.pad(
			_builder.world_to_tile(global_position), _builder.world_to_tile(doel))
	if _koers.is_empty():
		_koers = PackedVector2Array([doel])


func onderweg() -> bool:
	return not _koers.is_empty()


func _move_towards(target: Vector2, speed: float) -> void:
	var dir := (target - global_position).normalized()
	_facing = dir
	velocity = dir * speed


## Vier toestanden, in deze volgorde van voorrang: lopen, praten, bezig, stil.
##
## Praten en bezig zijn allebei animaties die al in de spritesheets zaten maar
## nergens gespeeld werden — `talk_<dir>` helemaal niet, en `bezig_down` alleen
## op het selectiescherm. Dat is zeven keer handwerk dat maar op één scherm te
## zien was; de bezigheden staan in `data/characters.json` onder `look`:
##
##   Daan huilt · Danny bier · Victor hobbyhorse · Jonathan gamen
##   Willem padel · Bastiaan zoekglas · Koen peuk
##
## Praten is feedback: je hoort te zien wie er aan het woord is zonder de naam
## te lezen. Bezig is karakter: je loopt langs een bureau en iemand doet iets
## dat alleen bij hem past. Geen van beide is beweging om de beweging.
func _animate() -> void:
	var moving := velocity.length() > 6.0
	if moving:
		_stil = 0.0
		_bezig = false
	else:
		_stil += get_physics_process_delta_time()

	if sprite.sprite_frames == null:
		return

	# De bezigheidsframes staan alleen in de `down`-rij, dus dit werkt enkel
	# voor iemand die naar de speler toe gekeerd staat. Dat is precies de
	# geposteerde collega waar je voor komt te staan.
	if not _bezig and not moving and not _praat and _stil >= _bezig_bij \
			and Player._dir_name(_facing) == "down" \
			and sprite.sprite_frames.has_animation(&"bezig_down"):
		_bezig = true
		sprite.play(&"bezig_down")
		return
	if _bezig:
		return

	var voorvoegsel := "walk_" if moving else ("talk_" if _praat else "idle_")
	var anim := StringName(voorvoegsel + Player._dir_name(_facing))
	if sprite.sprite_frames.has_animation(anim) and sprite.animation != anim:
		sprite.play(anim)


# --- Volgen ---------------------------------------------------------------

func start_following(who: Node2D) -> void:
	if _following == who:
		return
	_following = who
	_koers = PackedVector2Array()
	Session.add_follower(npc_id)
	Bus.follower_joined.emit(npc_id)


func stop_following(go_home: bool = true) -> void:
	if _following == null:
		return
	_following = null
	if go_home:
		loop_naar(_home)
	Session.remove_follower(npc_id)
	Bus.follower_released.emit(npc_id)


func is_following() -> bool:
	return _following != null


## WorldMutator.despawn_npc() doet queue_free() zonder los te laten. Zonder deze
## opruiming zou Session een collega blijven melden die niet meer bestaat.
func _exit_tree() -> void:
	Session.remove_follower(npc_id)
