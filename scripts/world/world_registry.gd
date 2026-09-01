class_name WorldRegistry
extends Node
## Index van alle WorldObjects op logische id. Gebouwd door Main bij _ready.

var _by_id: Dictionary = {}


func build() -> void:
	_by_id.clear()
	for n: Node in get_tree().get_nodes_in_group(&"world_object"):
		var wo := n as WorldObject
		if wo == null or wo.world_id == &"":
			continue
		if _by_id.has(wo.world_id):
			push_warning("WorldRegistry: dubbele world_id '%s'" % wo.world_id)
		_by_id[wo.world_id] = wo


func register(wo: WorldObject) -> void:
	if wo != null and wo.world_id != &"":
		_by_id[wo.world_id] = wo


func get_by_id(id: StringName) -> WorldObject:
	return _by_id.get(id, null) as WorldObject


func has(id: StringName) -> bool:
	return _by_id.has(id)


func all_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for k: Variant in _by_id.keys():
		out.append(StringName(k))
	return out
