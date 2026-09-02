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
## De tickets die je bent tegengekomen. Alles staat vanaf het begin open, dus
## "welke bestaan er" zegt niets meer; "welke heb ik gevonden" wel. Dit is je
## inventaris: hij vult zich terwijl je de vloer verkent.
var discovered: Array[StringName] = []
## De collega's die nu achter je aan lopen. Bewust runtime-only: bij het laden
## staat iedereen weer op zijn post, dus een bewaarde lijst zou liegen. Dit is de
## scene-loze spiegel van Npc.is_following(), zodat de statische UI-helpers en de
## headless tests hem ook kunnen lezen.
var followers: Array[StringName] = []
## Het ticket dat je zelf gekozen hebt. Stuurt de doelregel, de hint en de
## wijzer in de wereld. Leeg = je hebt nog niets gekozen.
var pinned_ticket: StringName = &""
var counters: Dictionary = {}       ## StringName -> int
## Wat de dag met je heeft gedaan, in getallen. Alleen `Gevolgen` schrijft hier
## en alleen de finale leest eruit; de narratieve gevolgen zijn gewone flags,
## zodat dialoog ze met de bestaande `flags_all`-grammatica kan lezen.
var gevolgen: Dictionary = {}       ## StringName -> Variant
## Hoeveel minuten je vandaag gewerkt hebt. Een eigen veld en niet een
## counter, want dit hoort een signaal uit te sturen zoals elke andere
## mutator hier, en de testsuite moet het kunnen valideren.
var worked_minutes: int = 0
## Hoeveel minuten je officieel geboekt hebt. Loopt bewust achter op
## worked_minutes: dat verschil is waar Dirk over komt praten.
var booked_minutes: int = 0
## Hoeveel systemen de invoer tegelijk op slot hebben. De enige bron van
## waarheid; `input_locked` is er niets anders dan een lezing van.
var _sloten: int = 0

## Staat de invoer op slot? **Alleen lezen** — puur afgeleid van `_sloten`, dus
## er is geen tweede toestand die ermee uit de pas kan lopen. Zetten gaat via
## `lock_input()` en `unlock_input()`; zie daar waarom.
var input_locked: bool : get = _is_input_locked, set = _weiger_directe_zet


# --- Sessiebeheer ---------------------------------------------------------

func start_new(chosen: StringName) -> void:
	character_id = chosen
	flags.clear()
	inventory.clear()
	ticket_states.clear()
	done_order.clear()
	discovered.clear()
	followers.clear()
	pinned_ticket = &""
	counters.clear()
	gevolgen.clear()
	worked_minutes = 0
	booked_minutes = 0
	reset_input_lock()
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


# --- Gevonden tickets (je inventaris) -------------------------------------

func is_discovered(id: StringName) -> bool:
	return id in discovered


## Idempotent: langs een deuropening lopen hertriggert zone_entered op elke
## tile-overgang, dus dit wordt vaak met hetzelfde ticket aangeroepen.
func discover(id: StringName) -> bool:
	if id in discovered:
		return false
	discovered.append(id)
	Bus.ticket_discovered.emit(id)
	return true


func discovered_count() -> int:
	return discovered.size()


# --- Meelopende collega's -------------------------------------------------

func is_following(npc_id: StringName) -> bool:
	return npc_id != &"" and npc_id in followers


func add_follower(npc_id: StringName) -> void:
	if npc_id != &"" and not (npc_id in followers):
		followers.append(npc_id)


func remove_follower(npc_id: StringName) -> void:
	followers.erase(npc_id)


# --- De gekozen -----------------------------------------------------------

func pin(id: StringName) -> void:
	if pinned_ticket == id:
		return
	pinned_ticket = id
	Bus.ticket_pinned.emit(id)


func unpin() -> void:
	pin(&"")


func is_pinned(id: StringName) -> bool:
	return id != &"" and pinned_ticket == id


# --- Urenstaat ------------------------------------------------------------

## Boekt tijd op de dag van vandaag. Het enige wat minuten laat oplopen.
## De HUD hangt aan het signaal, niet aan ticket_completed: de boeking is de
## trigger van de klokrol, want anders is de teller al bijgewerkt voordat de
## animatie begint.
## Wat je in de urenstaat hebt weggeschreven. Nooit meer dan het budget — dat
## is precies waarom er altijd iets overblijft dat je niet kunt boeken.
func book_hours(minutes: int) -> void:
	booked_minutes = clampi(minutes, 0, Urenstaat.BUDGET_MIN)
	set_flag(&"uren_geboekt", booked_minutes > 0)


func book_time(minutes: int, reason: StringName = &"") -> void:
	if minutes == 0:
		return
	worked_minutes += minutes
	Bus.time_booked.emit(minutes, reason, worked_minutes)


# --- Input lock -----------------------------------------------------------

## Zet de invoer op slot. Elke aanroep hoort precies één `unlock_input()` te
## krijgen.
##
## **Waarom een teller en geen bool.** Dit was een bool die vier systemen
## rechtstreeks zetten: de dialoogcontroller, de telefoon van De Klant, het
## vertrek uit het kantoor en de intro. Die kunnen elkaar overlappen, en wie als
## laatste `false` schreef zette de vloer open terwijl een ander er nog op
## rekende. Dat kostte een halve speelbeurt: De Klant meldde zich in het gat
## tussen twee dialogen, en toen zij werd weggetikt vond het wervingsgesprek
## dat eronder liep een open vloer waar het een gesloten verwachtte — Jonathan
## liep nooit mee, zonder één foutmelding.
##
## Met een teller componeren eigenaars. Het signaal valt alleen op de echte
## overgangen 0 -> 1 en 1 -> 0, dus luisteraars zoals de HUD en de knoppenbalk
## merken niets van de tussenliggende lagen.
func lock_input() -> void:
	_sloten += 1
	if _sloten == 1:
		Bus.input_lock_changed.emit(true)


func unlock_input() -> void:
	if _sloten <= 0:
		push_error("Session: unlock_input() zonder bijbehorende lock_input()")
		return
	_sloten -= 1
	if _sloten == 0:
		Bus.input_lock_changed.emit(false)


## Alles losgooien, ongeacht hoeveel eigenaars er waren. Voor een scenewissel of
## een nieuwe speelbeurt: daar overleeft geen enkele aanroeper zijn eigen slot,
## en een achtergebleven slot maakt de volgende scene onbestuurbaar.
func reset_input_lock() -> void:
	if _sloten == 0:
		return
	_sloten = 0
	Bus.input_lock_changed.emit(false)


func _is_input_locked() -> bool:
	return _sloten > 0


## `Session.input_locked = x` is geen geldige schrijfactie. Hardop, want een
## stille toewijzing die de teller omzeilt is precies de bug die de teller moet
## uitsluiten.
func _weiger_directe_zet(_v: bool) -> void:
	push_error("Session: zet input_locked niet direct; gebruik lock_input() / unlock_input()")


# --- Persistence (licht: crash-vangnet + dev-shortcuts) -------------------

func to_dict() -> Dictionary:
	return {
		"character_id": String(character_id),
		"flags": _sn_keys_to_str(flags),
		"inventory": _sn_keys_to_str(inventory),
		"ticket_states": _states_naar_namen(ticket_states),
		"counters": _sn_keys_to_str(counters),
		"gevolgen": _sn_keys_to_str(gevolgen),
		"worked_minutes": worked_minutes,
		"booked_minutes": booked_minutes,
		"done_order": done_order.map(func(s: StringName) -> String: return String(s)),
		"discovered": discovered.map(func(s: StringName) -> String: return String(s)),
		"pinned_ticket": String(pinned_ticket),
	}


func from_dict(d: Dictionary) -> void:
	character_id = StringName(d.get("character_id", ""))
	flags = _str_keys_to_sn(d.get("flags", {}))
	inventory = _str_keys_to_sn(d.get("inventory", {}))
	ticket_states = _namen_naar_states(d.get("ticket_states", {}))
	counters = _str_keys_to_sn(d.get("counters", {}))
	gevolgen = _str_keys_to_sn(d.get("gevolgen", {}))
	worked_minutes = int(d.get("worked_minutes", 0))
	booked_minutes = int(d.get("booked_minutes", 0))
	done_order.clear()
	for s: Variant in d.get("done_order", []):
		done_order.append(StringName(s))
	discovered.clear()
	for s: Variant in d.get("discovered", []):
		discovered.append(StringName(s))
	# Niet geserialiseerd: na het laden staat iedere collega weer op zijn post.
	followers.clear()
	pinned_ticket = StringName(d.get("pinned_ticket", ""))


func save_to_disk() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Session: kon sessie niet opslaan (%s)" % SAVE_PATH)
		return
	f.store_string(JSON.stringify(to_dict(), "\t"))
	f.close()


func load_from_disk() -> bool:
	var d := lees_save()
	if d.is_empty():
		return false
	from_dict(d)
	return true


## De save zoals hij op schijf staat, of een lege dictionary als er niets bruikbaars
## ligt. Apart van `load_from_disk()` omdat het titelscherm wil weten óf er iets is
## zonder de lopende sessie te overschrijven.
func lees_save() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not (parsed is Dictionary):
		return {}
	return parsed as Dictionary


## Ligt er een speelbeurt om naar terug te keren? Niet "het bestand bestaat":
## een save zonder `character_id` is een lege sessie die per ongeluk is
## weggeschreven, en daar hoort geen knop "Doorgaan" bij die je in een wereld
## zonder personage zet.
func has_saved_run() -> bool:
	return String(lees_save().get("character_id", "")) != ""


# --- Ticketstanden op naam ------------------------------------------------

## De ticketstand gaat als **naam** de save in, niet als getal.
##
## `GameEnums.TicketState` is een enum, en een enum is een volgorde. Zet iemand
## er een stand tussen of hernoemt hij er een, dan wijst elke save op schijf
## ineens naar een andere stand: een opgelost ticket komt terug als LOCKED, het
## ticketbord is leeg en de speler mist de helft van zijn dag. Zoiets crasht
## niet en meldt niets. Een naam overleeft een herordening.
static func _states_naar_namen(d: Dictionary) -> Dictionary:
	var out := {}
	for k: Variant in d.keys():
		out[String(k)] = _state_naam(int(d[k]))
	return out


## Leest zowel de naam als de rauwe int. Dat tweede is het migratiepad: saves
## van vóór deze wijziging staan al op schijf en horen gewoon door te spelen.
static func _namen_naar_states(d: Dictionary) -> Dictionary:
	var out := {}
	for k: Variant in d.keys():
		out[StringName(k)] = _state_waarde(d[k])
	return out


static func _state_naam(waarde: int) -> String:
	var tabel: Dictionary = GameEnums.TicketState
	for naam: Variant in tabel.keys():
		if int(tabel[naam]) == waarde:
			return String(naam)
	push_warning("Session: ticketstand %d heeft geen naam" % waarde)
	return "LOCKED"


static func _state_waarde(rauw: Variant) -> GameEnums.TicketState:
	if rauw is float or rauw is int:
		return int(rauw) as GameEnums.TicketState
	var tabel: Dictionary = GameEnums.TicketState
	var naam := String(rauw)
	if not tabel.has(naam):
		push_warning("Session: onbekende ticketstand '%s' in de save" % naam)
		return GameEnums.TicketState.LOCKED
	return int(tabel[naam]) as GameEnums.TicketState


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
