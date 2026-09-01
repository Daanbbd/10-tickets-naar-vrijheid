class_name Npc
extends CharacterBody2D
## Collega of bezoeker. Loopt een waypointroute, praat, en kan de speler volgen
## wanneer je hem als expert ophaalt voor een ticket.
##
## Bewust geen NavigationAgent2D: waypoints met move_toward volstaan op een
## kantoorvloer en zijn debugbaar.

const WALK_SPEED := 58.0
const FOLLOW_SPEED := 104.0
const FOLLOW_DISTANCE := 26.0
const ARRIVE_EPS := 3.0

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var interactable: Interactable = $Interactable

var npc_id: StringName = &""
var def: NpcDef = null

var _route: PackedVector2Array = []
var _leg: int = 0
var _pause_left: float = 0.0
var _following: Node2D = null
var _home: Vector2 = Vector2.ZERO
var _returning: bool = false
var _facing: Vector2 = Vector2.DOWN


func setup(d: NpcDef, builder: WorldBuilder) -> void:
	def = d
	npc_id = d.id
	name = "Npc_%s" % d.id

	var home_tile := builder.nearest_walkable(d.home_tile)
	_home = builder.tile_to_world(home_tile)
	global_position = _home

	_route = PackedVector2Array()
	for t: Vector2i in d.route:
		_route.append(builder.tile_to_world(builder.nearest_walkable(t)))

	sprite.sprite_frames = CharacterSprites.frames_for(
		d.look, d.color, d.skin, d.hair, d.pants, d.accent)
	sprite.play("idle_down")

	interactable.world_id = StringName("npc_obj_%s" % d.id)
	interactable.kind = Interactable.Kind.TALK
	interactable.label = d.name
	interactable.dialogue_id = d.dialogue_id


func _physics_process(delta: float) -> void:
	if _following != null:
		_do_follow(delta)
	elif _returning:
		_do_return(delta)
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


func _do_follow(delta: float) -> void:
	var to := _following.global_position - global_position
	if to.length() <= FOLLOW_DISTANCE:
		velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
		return
	_move_towards(_following.global_position, FOLLOW_SPEED)


func _do_return(delta: float) -> void:
	if global_position.distance_to(_home) <= ARRIVE_EPS * 2.0:
		_returning = false
		velocity = Vector2.ZERO
		return
	_move_towards(_home, WALK_SPEED)


func _move_towards(target: Vector2, speed: float) -> void:
	var dir := (target - global_position).normalized()
	_facing = dir
	velocity = dir * speed


func _animate() -> void:
	var moving := velocity.length() > 6.0
	var anim := ("walk_" if moving else "idle_") + Player._dir_name(_facing)
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(anim):
		if sprite.animation != anim:
			sprite.play(anim)


# --- Volgen ---------------------------------------------------------------

func start_following(who: Node2D) -> void:
	if _following == who:
		return
	_following = who
	_returning = false
	Bus.follower_joined.emit(npc_id)


func stop_following(go_home: bool = true) -> void:
	if _following == null:
		return
	_following = null
	_returning = go_home
	Bus.follower_released.emit(npc_id)


func is_following() -> bool:
	return _following != null
