extends Node
## Muteerbare runtime-state van één playthrough.
## De wereld is een pure functie hiervan: world = f(Session).
## Bevat state + dunne API; de queststroom-logica zit in QuestEngine.

const SAVE_PATH := "user://sessie.json"

var character_id: StringName = &""
var flags: Dictionary = {}          ## StringName -> bool
var inventory: Dictionary = {}      ## StringName -> int
var ticket_states: Dictionary = {}  ## StringName -> GameEnums.TicketState
var done_order: Array[StringName] = []
var counters: Dictionary = {}       ## StringName -> int
var input_locked: bool = false : set = _set_input_locked


# --- Sessiebeheer ---------------------------------------------------------

func start_new(chosen: StringName) -> void:
	character_id = chosen
	flags.clear()
	inventory.clear()
	ticket_states.clear()
	done_order.clear()
	counters.clear()
	input_locked = false
	Bus.character_selected.emit(character_id)


func character() -> CharacterDef:
	return GameData.character(character_id)


func character_traits() -> Array[StringName]:
	var c := character()
	return c.traits if c != null else [] as Array[StringName]


# --- Flags ----------------------------------------------------------------

func get_flag(f: StringName) -> bool:
	return bool(flags.get(f, false))


func set_flag(f: StringName, value: bool = true) -> void:
	if bool(flags.get(f, false)) == value:
		return
	flags[f] = value
	Bus.flag_changed.emit(f, value)


# --- Inventory ------------------------------------------------------------

func has_item(i: StringName) -> bool:
	return int(inventory.get(i, 0)) > 0


func item_count(i: StringName) -> int:
	return int(inventory.get(i, 0))


func add_item(i: StringName, n: int = 1) -> void:
	inventory[i] = int(inventory.get(i, 0)) + n
	Bus.item_added.emit(i, int(inventory[i]))


func remove_item(i: StringName, n: int = 1) -> void:
	var left := maxi(0, int(inventory.get(i, 0)) - n)
	if left == 0:
		inventory.erase(i)
	else:
		inventory[i] = left
	Bus.item_removed.emit(i, left)


func items_owned() -> Array[StringName]:
	var out: Array[StringName] = []
	for k: Variant in inventory.keys():
		out.append(StringName(k))
	return out


# --- Counters -------------------------------------------------------------

func get_counter(c: StringName) -> int:
	return int(counters.get(c, 0))


func add_counter(c: StringName, n: int = 1) -> void:
	counters[c] = int(counters.get(c, 0)) + n


# --- Tickets (delegatie naar QuestEngine) ---------------------------------

func ticket_state(id: StringName) -> GameEnums.TicketState:
	return ticket_states.get(id, GameEnums.TicketState.LOCKED) as GameEnums.TicketState

func is_done(id: StringName) -> bool:
	return ticket_state(id) == GameEnums.TicketState.DONE

func is_available(id: StringName) -> bool:
	var s := ticket_state(id)
	return s == GameEnums.TicketState.AVAILABLE or s == GameEnums.TicketState.ACTIVE

func done_count() -> int:
	return done_order.size()

func total_tickets() -> int:
	return GameData.ticket_ids().size()

func all_done() -> bool:
	return done_count() >= total_tickets()

func completed_tickets_in_order() -> Array[StringName]:
	return done_order.duplicate()

func owns_ticket(id: StringName) -> bool:
	var t := GameData.ticket(id)
	return t != null and t.owner_character == character_id


# --- Input lock -----------------------------------------------------------

func _set_input_locked(v: bool) -> void:
	if input_locked == v:
		return
	input_locked = v
	Bus.input_lock_changed.emit(v)


# --- Persistence (licht: crash-vangnet + dev-shortcuts) -------------------

func to_dict() -> Dictionary:
	return {
		"character_id": String(character_id),
		"flags": _sn_keys_to_str(flags),
		"inventory": _sn_keys_to_str(inventory),
		"ticket_states": _sn_keys_to_str(ticket_states),
		"counters": _sn_keys_to_str(counters),
		"done_order": done_order.map(func(s: StringName) -> String: return String(s)),
	}


func from_dict(d: Dictionary) -> void:
	character_id = StringName(d.get("character_id", ""))
	flags = _str_keys_to_sn(d.get("flags", {}))
	inventory = _str_keys_to_sn(d.get("inventory", {}))
	ticket_states = _str_keys_to_sn(d.get("ticket_states", {}))
	counters = _str_keys_to_sn(d.get("counters", {}))
	done_order.clear()
	for s: Variant in d.get("done_order", []):
		done_order.append(StringName(s))


func save_to_disk() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Session: kon sessie niet opslaan (%s)" % SAVE_PATH)
		return
	f.store_string(JSON.stringify(to_dict(), "\t"))
	f.close()


func load_from_disk() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var txt := FileAccess.get_file_as_string(SAVE_PATH)
	var parsed: Variant = JSON.parse_string(txt)
	if not (parsed is Dictionary):
		return false
	from_dict(parsed)
	return true


static func _sn_keys_to_str(d: Dictionary) -> Dictionary:
	var out := {}
	for k: Variant in d.keys():
		out[String(k)] = d[k]
	return out


static func _str_keys_to_sn(d: Dictionary) -> Dictionary:
	var out := {}
	for k: Variant in d.keys():
		out[StringName(k)] = d[k]
	return out
