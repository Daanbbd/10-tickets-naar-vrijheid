class_name InteractionProbe
extends Area2D
## Vindt het dichtstbijzijnde interactieve object voor de speler.
##
## Evalueert de overlap elke frame opnieuw in plaats van enter/exit bij te
## houden: Area2D-monitoring staat stil tijdens pause, waardoor exit-events na
## een minigame een frame te laat komen en de prompt blijft hangen.

var _current: Interactable = null


func _ready() -> void:
	monitoring = true
	monitorable = false


func _physics_process(_delta: float) -> void:
	var best: Interactable = null
	var best_d := INF
	for a: Area2D in get_overlapping_areas():
		var it := a as Interactable
		if it == null or not it.is_available():
			continue
		var d := global_position.distance_squared_to(it.global_position)
		if d < best_d:
			best_d = d
			best = it

	if best != _current:
		_current = best
		Bus.interaction_prompt_changed.emit(
			_current.prompt_text() if _current != null else "", _current != null,
			_current.world_id if _current != null else &"")


func current() -> Interactable:
	return _current


## Na een dialoog of minigame: prompt geforceerd verversen.
func refresh() -> void:
	_current = null
