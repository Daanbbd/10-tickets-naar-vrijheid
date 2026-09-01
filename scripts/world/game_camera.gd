class_name GameCamera
extends Camera2D
## Volgt de speler, maar los van hem zodat hij na een ticket naar het
## veranderde object kan pannen.

const FOCUS_SPEED := 260.0

var target: Node2D = null
var _focus_pos: Vector2 = Vector2.ZERO
var _focus_left: float = 0.0


func _ready() -> void:
	position_smoothing_enabled = true
	position_smoothing_speed = 6.0
	Bus.camera_focus_requested.connect(_on_focus_requested)


func setup(follow: Node2D, world: Rect2) -> void:
	target = follow
	limit_left = int(world.position.x)
	limit_top = int(world.position.y)
	limit_right = int(world.end.x)
	limit_bottom = int(world.end.y)
	# Harde grenzen geven een schokkende visuele stop. Valt nu al op aan de
	# randen van de entree, en straks permanent als de vloer smaller wordt.
	limit_smoothed = true
	if target != null:
		global_position = target.global_position
		reset_smoothing()


func _process(delta: float) -> void:
	if _focus_left > 0.0:
		_focus_left -= delta
		global_position = global_position.move_toward(_focus_pos, FOCUS_SPEED * delta)
		return
	if target != null:
		global_position = target.global_position


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
