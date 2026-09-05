class_name Player
extends CharacterBody2D
## Speler. 8-richtingen top-down beweging met sprint en een interactie-probe.

signal moved_to_tile(tile: Vector2i)

const WALK_SPEED := 96.0
const SPRINT_SPEED := 148.0
const ACCEL := 1400.0
const FRICTION := 1800.0

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var probe: InteractionProbe = $InteractionProbe

var facing: Vector2 = Vector2.DOWN
## Je staat te werken: een minigame loopt. Dan speelt de bezigheid uit de
## spritesheet (kolom 8-11 van rij `down`) in plaats van de idle — je "werkt"
## niet langer door stil te staan terwijl een formulier over je heen valt.
var _werkt: bool = false



## Wie je vanzelf achterna loopt terwijl de invoer op slot staat. Alleen de
## introductie zet dit: Dennis loopt voorop over een uitgerekende route
## (`Npc.loop_naar()`), en jij komt achter hem aan in plaats van dat je zelf het
## bord moet zien te vinden terwijl hij achter jou aan sloft.
##
## Op deze manier en niet met een eigen route voor de speler: twee losse routes
## lopen uit de pas zodra er iets tussen komt, en achter iemand aan lopen houdt
## je vanzelf op begaanbare vloer waar hij net over gelopen heeft.
var _volgt: Node2D = null
const VOLG_AFSTAND := 22.0
var _last_tile: Vector2i = Vector2i(-999, -999)
var _tile_size: int = 16
var _footstep_t: float = 0.0


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	Bus.minigame_started.connect(func(_id: StringName) -> void: _werkt = true)
	Bus.minigame_finished.connect(func(_id: StringName, _r: MinigameResult) -> void: _werkt = false)


func setup(character: CharacterDef, tile_size: int) -> void:
	_tile_size = tile_size
	if character != null:
		sprite.sprite_frames = CharacterSprites.frames_for(
			character.look, character.color, character.skin, character.hair,
			character.pants, character.accent)
		# Op het keuzescherm speelt de bezigheid één keer; hier loopt hij door
		# zolang het werk duurt. Eigen SpriteFrames, dus dit raakt de rest niet.
		if sprite.sprite_frames.has_animation(&"bezig_down"):
			sprite.sprite_frames.set_animation_loop(&"bezig_down", true)
	_play("idle")


func _physics_process(delta: float) -> void:
	var dir := Vector2.ZERO
	if not Session.input_locked:
		dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	elif is_instance_valid(_volgt):
		var naar := _volgt.global_position - global_position
		if naar.length() > VOLG_AFSTAND:
			dir = naar.normalized()

	var speed := SPRINT_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED

	if dir != Vector2.ZERO:
		dir = dir.normalized()
		facing = dir
		velocity = velocity.move_toward(dir * speed, ACCEL * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)

	move_and_slide()
	_animate(dir, delta)
	_report_tile()


## Loop vanzelf achter deze node aan zolang de invoer op slot staat.
func volg(wie: Node2D) -> void:
	_volgt = wie


func stop_volgen() -> void:
	_volgt = null


func _animate(dir: Vector2, delta: float) -> void:
	var moving := dir != Vector2.ZERO
	if _werkt and not moving:
		_play("bezig_down")
		_footstep_t = 0.0
		return
	_play(("walk_" if moving else "idle_") + _dir_name(facing))
	if moving:
		_footstep_t -= delta * (velocity.length() / WALK_SPEED)
		if _footstep_t <= 0.0:
			_footstep_t = 0.32
			AudioDirector.play_sfx(&"voetstap", 0.14, -8.0)
	else:
		_footstep_t = 0.0


func _play(anim: String) -> void:
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(anim):
		if sprite.animation != anim:
			sprite.play(anim)
	elif sprite.sprite_frames != null and sprite.sprite_frames.has_animation("idle_down"):
		sprite.play("idle_down")


static func _dir_name(v: Vector2) -> String:
	if absf(v.x) > absf(v.y):
		return "right" if v.x > 0.0 else "left"
	return "down" if v.y > 0.0 else "up"


func current_tile() -> Vector2i:
	return Vector2i(floori(global_position.x / _tile_size), floori(global_position.y / _tile_size))


func _report_tile() -> void:
	var t := current_tile()
	if t != _last_tile:
		_last_tile = t
		moved_to_tile.emit(t)
