extends Node
## Laadt alle JSON één keer bij boot en parset naar getypte modellen.
## Na load_all() read-only. Gameplay-code raakt nooit een rauwe Dictionary aan.

var characters: Dictionary = {}   ## StringName -> CharacterDef
var npcs: Dictionary = {}         ## StringName -> NpcDef
var items: Dictionary = {}        ## StringName -> ItemDef
var tickets: Dictionary = {}      ## StringName -> TicketDef
var dialogues: Dictionary = {}    ## StringName -> DialogueDef
var minigames: Dictionary = {}    ## StringName -> Dictionary {scene, title}
var world_ids: Array[StringName] = []
var floor_data: Dictionary = {}

## De ruwe regels uit data/objects.json. `main.gd` bouwt hier zijn WorldObjects
## uit, en `QuestEngine` leest er de tegel van een anker uit om afstanden te
## kunnen wegen. Stond eerder alleen in `Main._spawn_objects()`, dat het bestand
## zelf parste — met een tweede lezer wordt dat twee keer dezelfde JSON en twee
## plekken die uit elkaar kunnen lopen.
var objects: Array = []
var _object_tiles: Dictionary = {}   ## StringName -> Vector2i

var load_errors: Array[String] = []
var _ticket_order: Array[StringName] = []


func _ready() -> void:
	load_all()


func load_all() -> void:
	load_errors.clear()
	characters.clear(); npcs.clear(); items.clear()
	tickets.clear(); dialogues.clear(); minigames.clear()
	world_ids.clear(); _ticket_order.clear()
	objects.clear(); _object_tiles.clear()

	_load_characters("res://data/characters.json")
	_load_npcs("res://data/npcs.json")
	_load_items("res://data/items.json")
	_load_minigames("res://data/minigames.json")
	_load_world_ids("res://data/world_ids.json")
	_load_objects("res://data/objects.json")
	floor_data = _read_json("res://data/floor.json") as Dictionary

	for path: String in _files_in("res://data/tickets", ".json"):
		_load_ticket(path)
	for path: String in _files_in("res://data/dialogue", ".json"):
		_load_dialogue(path)

	_ticket_order.clear()
	for k: Variant in tickets.keys():
		_ticket_order.append(StringName(k))
	_ticket_order.sort_custom(func(a: StringName, b: StringName) -> bool:
		return (tickets[a] as TicketDef).order < (tickets[b] as TicketDef).order)

	if not load_errors.is_empty():
		for e: String in load_errors:
			push_error("GameData: %s" % e)


# --- Accessors ------------------------------------------------------------

func character(id: StringName) -> CharacterDef:
	return characters.get(id, null) as CharacterDef

func character_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for k: Variant in characters.keys():
		out.append(StringName(k))
	return out

func npc(id: StringName) -> NpcDef:
	return npcs.get(id, null) as NpcDef

func item(id: StringName) -> ItemDef:
	return items.get(id, null) as ItemDef

func ticket(id: StringName) -> TicketDef:
	return tickets.get(id, null) as TicketDef

func ticket_ids() -> Array[StringName]:
	return _ticket_order.duplicate()

func dialogue(id: StringName) -> DialogueDef:
	return dialogues.get(id, null) as DialogueDef

func minigame_scene_path(id: StringName) -> String:
	var m := minigames.get(id, {}) as Dictionary
	return String(m.get("scene", ""))

## De tegel van een object, of (-1, -1) als het niet bestaat. Vector2i en niet
## een positie in pixels: afstanden horen in tegels gewogen te worden, want
## `meters_per_pixel()` heeft sinds de ingekorte vloer een eigen maat voor de
## lengterichting en dan meet je door die correctie heen.
func object_tile(world_id: StringName) -> Vector2i:
	return _object_tiles.get(world_id, Vector2i(-1, -1))


func has_world_id(id: StringName) -> bool:
	return id in world_ids


# --- Parsers --------------------------------------------------------------

func _load_characters(path: String) -> void:
	for raw: Variant in _array_of(path):
		var d := raw as Dictionary
		var c := CharacterDef.new()
		c.id = StringName(d.get("id", ""))
		c.name = String(d.get("name", ""))
		c.role = String(d.get("role", ""))
		c.tagline = String(d.get("tagline", ""))
		c.description = String(d.get("description", ""))
		c.stijl = String(d.get("stijl", ""))
		c.traits = _sn_array(d.get("traits", []))
		c.specialisms = _str_array(d.get("specialisms", []))
		c.owned_tickets = _sn_array(d.get("owned_tickets", []))
		c.finale_id = StringName(d.get("finale_id", ""))
		c.color = _color(d.get("color", "#ffffff"))
		c.skin = _color(d.get("skin", "#dbb38f"))
		c.hair = _color(d.get("hair", "#402e21"))
		c.sheet = StringName(d.get("sheet", "plain"))
		c.look = CharacterSprites.normaliseer_look(
			d.get("look", {}) as Dictionary, c.sheet)
		c.pants = _color(d.get("pants", "#34384e"))
		c.portrait = String(d.get("portrait", ""))
		c.accent = _color(d.get("accent", "#3a86ff"))
		if c.id == &"":
			load_errors.append("character zonder id in %s" % path)
			continue
		characters[c.id] = c


func _load_npcs(path: String) -> void:
	for raw: Variant in _array_of(path):
		var d := raw as Dictionary
		var n := NpcDef.new()
		n.id = StringName(d.get("id", ""))
		n.name = String(d.get("name", ""))
		n.role = String(d.get("role", ""))
		n.home_tile = _tile(d.get("home_tile", [0, 0]))
		n.zone = StringName(d.get("zone", ""))
		n.dialogue_id = StringName(d.get("dialogue_id", ""))
		n.route_pause = float(d.get("route_pause", 2.0))
		n.can_follow = bool(d.get("can_follow", false))
		n.is_playable_colleague = bool(d.get("is_playable_colleague", false))
		n.color = _color(d.get("color", "#ffffff"))
		n.skin = _color(d.get("skin", "#dbb38f"))
		n.hair = _color(d.get("hair", "#402e21"))
		n.sheet = StringName(d.get("sheet", "plain"))
		n.look = CharacterSprites.normaliseer_look(
			d.get("look", {}) as Dictionary, n.sheet)
		n.pants = _color(d.get("pants", "#34384e"))
		n.accent = _color(d.get("accent", "#f4a259"))
		n.portrait = String(d.get("portrait", ""))
		n.spawn_when = d.get("spawn_when", {}) as Dictionary
		n.static_sprite = String(d.get("static_sprite", ""))
		var route: Array[Vector2i] = []
		for p: Variant in d.get("route", []):
			route.append(_tile(p))
		n.route = route
		if n.id == &"":
			load_errors.append("npc zonder id in %s" % path)
			continue
		npcs[n.id] = n


func _load_items(path: String) -> void:
	for raw: Variant in _array_of(path):
		var d := raw as Dictionary
		var it := ItemDef.new()
		it.id = StringName(d.get("id", ""))
		it.name = String(d.get("name", ""))
		it.description = String(d.get("description", ""))
		it.icon = StringName(d.get("icon", ""))
		it.vindplaats = StringName(d.get("vindplaats", ""))
		it.zone = StringName(d.get("zone", ""))
		items[it.id] = it


func _load_minigames(path: String) -> void:
	var d := _read_json(path) as Dictionary
	for k: Variant in d.keys():
		minigames[StringName(k)] = d[k] as Dictionary


func _load_world_ids(path: String) -> void:
	for raw: Variant in _array_of(path):
		world_ids.append(StringName(raw))


## Alleen inlezen en de tegels indexeren; wat een object verder ís (kind, label,
## dialoog) blijft de zaak van `Main._spawn_objects()`.
func _load_objects(path: String) -> void:
	for raw: Variant in _array_of(path):
		var d := raw as Dictionary
		objects.append(d)
		var wid := StringName(d.get("world_id", ""))
		var t: Array = d.get("tile", [])
		if wid == &"":
			load_errors.append("object zonder world_id in %s" % path)
			continue
		if t.size() != 2:
			load_errors.append("object '%s' heeft geen tile" % wid)
			continue
		_object_tiles[wid] = Vector2i(int(t[0]), int(t[1]))


func _load_ticket(path: String) -> void:
	var d := _read_json(path) as Dictionary
	if d.is_empty():
		return
	var t := TicketDef.new()
	t.id = StringName(d.get("id", ""))
	t.code = String(d.get("code", ""))
	t.order = int(d.get("order", 0))
	t.title = String(d.get("title", ""))
	t.summary = String(d.get("summary", ""))
	t.zone = StringName(d.get("zone", ""))
	t.zone_name = String(d.get("zone_name", ""))
	t.anchor = StringName(d.get("anchor", ""))
	t.owner_character = StringName(d.get("owner_character", ""))
	# De rol komt uit het personage en niet uit het ticket. Hij stond op beide
	# plekken en de twee kopieen weken af; sindsdien is `data/characters.json` de
	# enige bron, en erft een ticket de rol van zijn eigenaar bij het laden.
	# `npcs.json` draagt dezelfde titel voor het bordje op de vloer —
	# `_test_briefings()` bewaakt dat die drie gelijk blijven. Personages laden
	# voor tickets, dus de eigenaar is hier al bekend.
	var eigenaar: CharacterDef = characters.get(t.owner_character, null) as CharacterDef
	t.owner_role = eigenaar.role if eigenaar != null else ""
	t.available_when = d.get("available_when", {}) as Dictionary
	t.requirements = d.get("requirements", {}) as Dictionary
	t.dialogue_ids = _sn_dict(d.get("dialogue_ids", {}))
	t.minigame_id = StringName(d.get("minigame_id", ""))
	t.minigame_config = d.get("minigame_config", {}) as Dictionary
	t.reward_effects = d.get("reward_effects", []) as Array
	t.unlocks = _sn_array(d.get("unlocks", []))
	t.world_changes = d.get("world_changes", []) as Array
	t.hint = String(d.get("hint", ""))
	t.wereldhandeling = bool(d.get("wereldhandeling", false))
	if t.id == &"":
		load_errors.append("ticket zonder id: %s" % path)
		return
	# Het eerste bestand wint, en het tweede meldt zich. Dit was een stille
	# overschrijving: twee bestanden met hetzelfde id lieten `total_tickets()`
	# op negen uitkomen, waarmee `all_done()` één ticket te vroeg waar wordt en
	# er een anker op de vloer staat dat naar een ticket wijst dat niet meer
	# bestaat. `WorldRegistry.build()` doet dit voor world_id's al wel.
	if tickets.has(t.id):
		load_errors.append("dubbel ticket-id '%s' in %s" % [t.id, path])
		return
	tickets[t.id] = t


func _load_dialogue(path: String) -> void:
	var d := _read_json(path) as Dictionary
	for key: Variant in d.keys():
		var tree := d[key] as Dictionary
		var dd := DialogueDef.new()
		dd.id = StringName(key)
		dd.start_node = StringName(tree.get("start", "start"))
		var nodes := {}
		for nid: Variant in (tree.get("nodes", {}) as Dictionary).keys():
			nodes[StringName(nid)] = (tree["nodes"] as Dictionary)[nid]
		dd.nodes = nodes
		dialogues[dd.id] = dd


# --- Helpers --------------------------------------------------------------

func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		load_errors.append("bestand ontbreekt: %s" % path)
		return {}
	var txt := FileAccess.get_file_as_string(path)
	var j := JSON.new()
	var err := j.parse(txt)
	if err != OK:
		load_errors.append("JSON-fout in %s regel %d: %s" % [path, j.get_error_line(), j.get_error_message()])
		return {}
	return j.data


func _array_of(path: String) -> Array:
	var v: Variant = _read_json(path)
	return v as Array if v is Array else []


func _files_in(dir_path: String, ext: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		load_errors.append("map ontbreekt: %s" % dir_path)
		return out
	for f: String in dir.get_files():
		# Godot hernoemt geïmporteerde bestanden in exports naar .remap
		var clean := f.trim_suffix(".remap")
		if clean.ends_with(ext):
			out.append("%s/%s" % [dir_path, clean])
	out.sort()
	return out


static func _sn_array(v: Variant) -> Array[StringName]:
	var out: Array[StringName] = []
	for e: Variant in (v as Array if v is Array else []):
		out.append(StringName(e))
	return out


static func _str_array(v: Variant) -> Array[String]:
	var out: Array[String] = []
	for e: Variant in (v as Array if v is Array else []):
		out.append(String(e))
	return out


static func _sn_dict(v: Variant) -> Dictionary:
	var out := {}
	for k: Variant in (v as Dictionary if v is Dictionary else {}).keys():
		out[StringName(k)] = StringName((v as Dictionary)[k])
	return out


static func _tile(v: Variant) -> Vector2i:
	if v is Array and (v as Array).size() >= 2:
		return Vector2i(int(v[0]), int(v[1]))
	return Vector2i.ZERO


static func _color(v: Variant) -> Color:
	return Color(String(v)) if String(v).begins_with("#") else Color.WHITE
