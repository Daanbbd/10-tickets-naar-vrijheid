class_name NpcLayer
extends Node2D
## Houdt alle NPC's vast en spawnt ze conditioneel uit data/npcs.json.

const NPC_SCENE := "res://scenes/entities/npc.tscn"

var _builder: WorldBuilder = null


func setup(builder: WorldBuilder) -> void:
	_builder = builder


## Spawnt iedereen die nu zichtbaar hoort te zijn.
## Slaat de NPC-versie van het gekozen personage over: die ben jij.
func spawn_initial() -> void:
	for id: StringName in _all_npc_ids():
		var d: NpcDef = GameData.npc(id)
		if d == null:
			continue
		if d.id == StringName("npc_%s" % Session.character_id):
			continue
		if not Conditions.check(d.spawn_when):
			continue
		spawn_npc(d)


## Idempotent: bestaat de NPC al, dan gebeurt er niets.
func spawn_npc(d: NpcDef) -> Npc:
	var existing := find_npc(d.id)
	if existing != null:
		return existing
	var n := (load(NPC_SCENE) as PackedScene).instantiate() as Npc
	add_child(n)
	n.setup(d, _builder)
	return n


func find_npc(id: StringName) -> Npc:
	for c: Node in get_children():
		var n := c as Npc
		if n != null and n.npc_id == id:
			return n
	return null


## De dichtstbijzijnde NPC wiens id met `prefix` begint, gemeten vanaf `vanaf`
## (wereldcoördinaten). Voor tickets met `zoek_npc`: de wijzer wijst dan naar
## het ding dat je moet vinden, niet naar het anker waar je het meldt.
func dichtstbijzijnde_met_prefix(prefix: String, vanaf: Vector2) -> Npc:
	var beste: Npc = null
	var beste_d := INF
	for c: Node in get_children():
		var n := c as Npc
		if n == null or not String(n.npc_id).begins_with(prefix):
			continue
		var d := n.global_position.distance_squared_to(vanaf)
		if d < beste_d:
			beste = n
			beste_d = d
	return beste


func followers() -> Array[Npc]:
	var out: Array[Npc] = []
	for c: Node in get_children():
		var n := c as Npc
		if n != null and n.is_following():
			out.append(n)
	return out


func release_all(go_home: bool = true) -> void:
	for n: Npc in followers():
		n.stop_following(go_home)


## Roept spawn_initial opnieuw aan zodat conditionele NPC's alsnog verschijnen.
func refresh_conditional() -> void:
	for id: StringName in _all_npc_ids():
		var d: NpcDef = GameData.npc(id)
		if d == null or d.spawn_when.is_empty():
			continue
		if d.id == StringName("npc_%s" % Session.character_id):
			continue
		if Conditions.check(d.spawn_when):
			spawn_npc(d)


func _all_npc_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for k: Variant in GameData.npcs.keys():
		out.append(StringName(k))
	out.sort()
	return out
