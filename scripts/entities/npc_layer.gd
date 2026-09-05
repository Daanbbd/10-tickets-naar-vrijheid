class_name NpcLayer
extends Node2D
## Houdt alle NPC's vast en spawnt ze conditioneel uit data/npcs.json.

const NPC_SCENE := "res://scenes/entities/npc.tscn"

var _builder: WorldBuilder = null

## Voor de terzijdes: wie er langsloopt, en wanneer wie voor het laatst iets
## zei. Per collega een eigen wachttijd (dezelfde regel twee keer achter elkaar
## is geen grap meer) en één gedeelde (twee collega's die door elkaar heen
## praten lezen als ruis).
const BARK_AFSTAND := 44.0
const BARK_WACHT_PER_NPC := 45.0
const BARK_WACHT_GEDEELD := 8.0
const BARK_CHECK := 0.6
var _speler: Node2D = null
## Eigen klok in speeltijd (opgeteld uit `delta`), niet `Time.get_ticks_msec()`:
## die loopt door tijdens een pauze en loopt onder Movie Maker (`--write-movie`)
## ver voor op de gerenderde seconden, zodat een terzijde al weg was voordat het
## frame op schijf stond.
var _tijd: float = 0.0
var _bark_check: float = 0.0
var _bark_vrij_vanaf: float = 3.0
var _bark_vrij_per_npc: Dictionary = {}


func setup(builder: WorldBuilder) -> void:
	_builder = builder


## Wie er langs de collega's loopt. Zonder speler geen terzijdes — de testsuite
## en de QA-schermen zetten hem niet, en dan blijft het stil.
func zet_speler(speler: Node2D) -> void:
	_speler = speler


func _process(delta: float) -> void:
	if _speler == null:
		return
	_tijd += delta
	_bark_check -= delta
	if _bark_check > 0.0:
		return
	_bark_check = BARK_CHECK
	_probeer_bark()


## Eén collega binnen armlengte die niet volgt en niet praat, zegt één regel —
## niet tijdens een gesprek of een minigame, en niet vaker dan de wachttijden
## toelaten. Wie het dichtst bij staat wint.
func _probeer_bark() -> void:
	if Session.input_locked or Shell.minigame_active():
		return
	var nu := _tijd
	if nu < _bark_vrij_vanaf:
		return
	var beste: Npc = null
	var beste_d := BARK_AFSTAND * BARK_AFSTAND
	for c: Node in get_children():
		var n := c as Npc
		if n == null or n.def == null or n.def.barks.is_empty() or n.is_following():
			continue
		if nu < float(_bark_vrij_per_npc.get(n.npc_id, 0.0)):
			continue
		var d := n.global_position.distance_squared_to(_speler.global_position)
		if d < beste_d:
			beste = n
			beste_d = d
	if beste == null:
		return
	var regels := beste.def.barks
	Bark.toon(beste, regels[randi() % regels.size()])
	_bark_vrij_per_npc[beste.npc_id] = nu + BARK_WACHT_PER_NPC
	_bark_vrij_vanaf = nu + BARK_WACHT_GEDEELD


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
