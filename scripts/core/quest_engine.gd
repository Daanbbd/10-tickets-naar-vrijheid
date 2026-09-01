class_name QuestEngine
extends RefCounted
## Ticketstroom-logica en state-effecten. Volledig statisch en scene-loos, dus
## headless testbaar. Alle state leeft in de Session-autoload.
##
## Strikte scheiding:
##   run_effects()  -> state-mutaties, draaien exact een keer
##   world_changes  -> visueel, idempotent (zie WorldMutator)

const EFFECT_OPS: Array[String] = [
	"set_flag", "add_item", "remove_item", "add_counter",
	"unlock_ticket", "toast", "cue",
]


# --- Ticketstroom ---------------------------------------------------------

## Zet alle tickets op hun beginstaat. Tickets zonder available_when starten open.
static func initialise_tickets() -> void:
	for id: StringName in GameData.ticket_ids():
		Session.ticket_states[id] = GameEnums.TicketState.LOCKED
	refresh_availability()


## Promoveert LOCKED -> AVAILABLE zodra available_when klopt. Idempotent.
static func refresh_availability() -> void:
	for id: StringName in GameData.ticket_ids():
		if Session.ticket_state(id) != GameEnums.TicketState.LOCKED:
			continue
		var t: TicketDef = GameData.ticket(id)
		if t == null:
			continue
		if Conditions.check(t.available_when):
			_set_state(id, GameEnums.TicketState.AVAILABLE)


static func unlock(id: StringName) -> void:
	if Session.ticket_state(id) == GameEnums.TicketState.LOCKED:
		_set_state(id, GameEnums.TicketState.AVAILABLE)


static func activate(id: StringName) -> void:
	if Session.ticket_state(id) == GameEnums.TicketState.AVAILABLE:
		_set_state(id, GameEnums.TicketState.ACTIVE)
		Bus.ticket_activated.emit(id)


## Kan het gekozen personage dit ticket zelf oplossen, of moet er een collega bij?
## Een ticket zonder eigenaar (de finale) is voor iedereen eigen werk: elk
## personage krijgt daar zijn eigen variant van.
static func is_own_expertise(id: StringName) -> bool:
	var t: TicketDef = GameData.ticket(id)
	if t == null:
		return false
	if t.owner_character == &"":
		return true
	return t.owner_character == Session.character_id


static func helper_flag(id: StringName) -> StringName:
	return StringName("helper_bij_%s" % id)


static func mark_helper_present(id: StringName) -> void:
	Session.set_flag(helper_flag(id), true)


## Zijn de voorwaarden vervuld om de minigame te mogen starten?
static func requirements_met(id: StringName) -> bool:
	var t: TicketDef = GameData.ticket(id)
	if t == null:
		return false
	if not Conditions.check(t.requirements):
		return false
	if is_own_expertise(id):
		return true
	return Session.get_flag(helper_flag(id))


## Welke collega moet je ophalen voor dit ticket? Leeg = niemand.
static func required_helper(id: StringName) -> StringName:
	var t: TicketDef = GameData.ticket(id)
	if t == null or is_own_expertise(id):
		return &""
	return StringName("npc_%s" % t.owner_character)


static func complete(id: StringName, result: MinigameResult) -> void:
	if Session.is_done(id):
		return
	var t: TicketDef = GameData.ticket(id)
	if t == null:
		push_error("QuestEngine: onbekend ticket '%s'" % id)
		return

	_set_state(id, GameEnums.TicketState.DONE)
	if not (id in Session.done_order):
		Session.done_order.append(id)

	run_effects(t.reward_effects)
	for u: StringName in t.unlocks:
		unlock(u)
	refresh_availability()

	Bus.ticket_completed.emit(id, result)
	Session.save_to_disk()

	if Session.all_done():
		Session.set_flag(&"alle_tickets_klaar", true)
		Bus.all_tickets_done.emit()


## Het eerstvolgende logische doel, voor de hintvogel en het ticketbord.
static func next_hint_ticket() -> TicketDef:
	var best: TicketDef = null
	for id: StringName in GameData.ticket_ids():
		var st: GameEnums.TicketState = Session.ticket_state(id)
		if st == GameEnums.TicketState.ACTIVE:
			return GameData.ticket(id)
		if st == GameEnums.TicketState.AVAILABLE and best == null:
			best = GameData.ticket(id)
	return best


static func open_tickets() -> Array[TicketDef]:
	var out: Array[TicketDef] = []
	for id: StringName in GameData.ticket_ids():
		if Session.is_available(id):
			out.append(GameData.ticket(id))
	return out


static func _set_state(id: StringName, st: GameEnums.TicketState) -> void:
	if Session.ticket_states.get(id, -1) == st:
		return
	Session.ticket_states[id] = st
	Bus.ticket_state_changed.emit(id, st)


# --- Effecten (state-mutaties) -------------------------------------------

static func run_effects(list: Array) -> void:
	for raw: Variant in list:
		var e := raw as Dictionary
		if e == null:
			continue
		match String(e.get("op", "")):
			"set_flag":
				Session.set_flag(StringName(e.get("flag", "")), bool(e.get("value", true)))
			"add_item":
				Session.add_item(StringName(e.get("item", "")), int(e.get("count", 1)))
			"remove_item":
				Session.remove_item(StringName(e.get("item", "")), int(e.get("count", 1)))
			"add_counter":
				Session.add_counter(StringName(e.get("counter", "")), int(e.get("value", 1)))
			"unlock_ticket":
				unlock(StringName(e.get("ticket", "")))
			"toast":
				Bus.toast_requested.emit(String(e.get("text", "")), StringName(e.get("icon", "")))
			"cue":
				Bus.audio_cue_requested.emit(StringName(e.get("cue", "")))
			_:
				push_error("QuestEngine: onbekende effect-op '%s'" % e.get("op", ""))


static func unknown_effect_ops(list: Array) -> Array[String]:
	var bad: Array[String] = []
	for raw: Variant in list:
		var e := raw as Dictionary
		if e != null and not (String(e.get("op", "")) in EFFECT_OPS):
			bad.append(String(e.get("op", "")))
	return bad
