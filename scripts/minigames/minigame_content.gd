class_name MinigameContent
extends RefCounted
## Laadt data/minigame_content.json: de puzzelinhoud van alle tien de minigames.
## Gescheiden van data/minigames.json, dat alleen id -> scene mapt.

const PATH := "res://data/minigame_content.json"

static var _data: Dictionary = {}
static var _loaded: bool = false


static func get_config(id: StringName) -> Dictionary:
	_ensure()
	var d := _data.get(String(id), {}) as Dictionary
	if d.is_empty():
		push_error("MinigameContent: geen inhoud voor '%s' in %s" % [id, PATH])
	return d


static func all_ids() -> Array[String]:
	_ensure()
	var out: Array[String] = []
	for k: Variant in _data.keys():
		out.append(String(k))
	out.sort()
	return out


static func reload() -> void:
	_loaded = false
	_ensure()


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(PATH):
		push_error("MinigameContent: %s ontbreekt" % PATH)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if parsed is Dictionary:
		_data = parsed
	else:
		push_error("MinigameContent: %s bevat geen geldig JSON-object" % PATH)
