class_name WorldMutator
extends Node
## Vertaalt world_change-dicts naar wereldmutaties.
##
## Alle ops MOETEN idempotent zijn: replay_all() draait ze opnieuw bij elke
## wereld-load, zodat de wereld altijd een pure functie van Session is.

const OPS: Array[String] = [
	"set_visible", "set_text", "set_modulate", "set_locked",
	"spawn_npc", "despawn_npc", "set_ambience", "cue", "camera_focus",
]

var _registry: WorldRegistry = null
var _npc_layer: NpcLayer = null


func setup(registry: WorldRegistry, npc_layer: NpcLayer) -> void:
	_registry = registry
	_npc_layer = npc_layer
	Bus.ticket_completed.connect(_on_ticket_completed)
	Bus.world_changes_requested.connect(_on_changes_requested)


## Herbouwt de wereld uit Session. Instant, zonder animatie of geluid.
func replay_all() -> void:
	for tid: StringName in Session.completed_tickets_in_order():
		var t: TicketDef = GameData.ticket(tid)
		if t != null:
			apply(t.world_changes, false)


func apply(changes: Array, animated: bool) -> void:
	for raw: Variant in changes:
		var c := raw as Dictionary
		if c == null:
			continue
		var op := String(c.get("op", ""))
		var target_id := StringName(c.get("target", ""))
		var target: WorldObject = null

		if target_id != &"":
			target = _registry.get_by_id(target_id)
			if target == null and not (op in ["spawn_npc", "despawn_npc", "set_ambience", "cue"]):
				push_error("WorldMutator: world_id '%s' niet gevonden (op '%s')" % [target_id, op])
				continue

		match op:
			"set_visible":
				target.op_set_visible(bool(c.get("value", true)))
			"set_text":
				target.op_set_text(String(c.get("value", "")))
			"set_modulate":
				target.op_set_modulate(Color(String(c.get("value", "#ffffff"))))
			"set_locked":
				target.op_set_locked(bool(c.get("value", false)))
			"spawn_npc":
				_spawn_npc(StringName(c.get("npc", "")))
			"despawn_npc":
				_despawn_npc(StringName(c.get("npc", "")))
			"set_ambience":
				if animated:
					AudioDirector.set_base(StringName(c.get("value", "")))
			"cue":
				if animated:
					Bus.audio_cue_requested.emit(StringName(c.get("cue", "")))
			"camera_focus":
				if animated:
					Bus.camera_focus_requested.emit(target_id, float(c.get("hold", 1.5)))
			_:
				push_error("WorldMutator: onbekende op '%s'" % op)



static func unknown_ops(changes: Array) -> Array[String]:
	var bad: Array[String] = []
	for raw: Variant in changes:
		var c := raw as Dictionary
		if c != null and not (String(c.get("op", "")) in OPS):
			bad.append(String(c.get("op", "")))
	return bad


func _on_ticket_completed(ticket_id: StringName, _r: MinigameResult) -> void:
	var t: TicketDef = GameData.ticket(ticket_id)
	if t != null:
		apply(t.world_changes, true)


func _on_changes_requested(changes: Array) -> void:
	apply(changes, true)


# --- NPC spawn/despawn ----------------------------------------------------

func _spawn_npc(npc_id: StringName) -> void:
	if npc_id == &"" or _npc_layer == null:
		return
	if _npc_layer.find_npc(npc_id) != null:
		return   # bestaat al: idempotent
	var def: NpcDef = GameData.npc(npc_id)
	if def == null:
		push_error("WorldMutator: onbekende npc '%s'" % npc_id)
		return
	_npc_layer.spawn_npc(def)


func _despawn_npc(npc_id: StringName) -> void:
	if _npc_layer == null:
		return
	var n := _npc_layer.find_npc(npc_id)
	if n != null:
		n.queue_free()
