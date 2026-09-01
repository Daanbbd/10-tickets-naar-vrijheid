class_name TicketController
extends Node
## Regelt wat er gebeurt als de speler een ticket-object of een collega
## aanspreekt: oppakken, collega ophalen, minigame draaien, ticket afronden.

var _registry: WorldRegistry
var _npcs: NpcLayer
var _builder: WorldBuilder
var _dialogue: DialogueController
var _hud: Hud
var _busy: bool = false


func setup(registry: WorldRegistry, npcs: NpcLayer, builder: WorldBuilder) -> void:
	_registry = registry
	_npcs = npcs
	_builder = builder
	_dialogue = get_parent().get_node("DialogueController") as DialogueController
	_hud = get_parent().get_node("HUD") as Hud


# --- Ticketobject aanspreken ---------------------------------------------

func handle(ticket_id: StringName, source: Interactable) -> void:
	if _busy:
		return
	# Een object kan in de loop van de dag meerdere tickets dragen (het
	# scrumbord is er zowel voor de planning als voor de paardenbugs), dus
	# kies op basis van de stand van zaken en niet op een vast id.
	var t := _ticket_for_anchor(source.world_id if source != null else &"", ticket_id)
	if t == null:
		push_error("TicketController: geen ticket voor anker '%s'" % (source.world_id if source else ticket_id))
		return

	_busy = true
	await _handle_inner(t)
	_busy = false


## Volgorde: eerst een ticket waar je nu iets mee kunt, dan een geblokkeerd
## ticket (voor de 'nog niet'-regel), anders het laatst opgeloste.
func _ticket_for_anchor(world_id: StringName, fallback: StringName) -> TicketDef:
	var hier: Array[TicketDef] = []
	for id: StringName in GameData.ticket_ids():
		var t: TicketDef = GameData.ticket(id)
		if t != null and t.anchor == world_id:
			hier.append(t)
	if hier.is_empty():
		return GameData.ticket(fallback)

	for t: TicketDef in hier:
		if Session.is_available(t.id):
			return t
	for t: TicketDef in hier:
		if Session.ticket_state(t.id) == GameEnums.TicketState.LOCKED:
			return t
	return hier[hier.size() - 1]


func _handle_inner(t: TicketDef) -> void:
	if Session.is_done(t.id):
		await _line(_dlg(t, &"done", "Dit is opgelost. Even niet aan zitten."))
		return

	if Session.ticket_state(t.id) == GameEnums.TicketState.LOCKED:
		await _line(_dlg(t, &"locked", "Hier is nu niets te doen."))
		return

	QuestEngine.activate(t.id)
	# Het briefje op het bord zien landen, vóór de dialoog. Dit is het moment
	# waarop een ticket iets wordt in plaats van een regel in een lijst.
	if _hud != null:
		await _hud.toon_nieuw_briefje(t)

	# Niet jouw vakgebied? Dan moet de eigenaar meegelopen zijn.
	if not QuestEngine.is_own_expertise(t.id):
		var helper_id := QuestEngine.required_helper(t.id)
		var helper := _npcs.find_npc(helper_id)
		if helper != null and helper.is_following():
			QuestEngine.mark_helper_present(t.id)
			helper.stop_following(true)
		elif not Session.get_flag(QuestEngine.helper_flag(t.id)):
			await _play_or_line(_dlg(t, &"fetch", &""),
				_fetch_hint(t, helper_id))
			return

	if not Conditions.check(t.requirements):
		await _play_or_line(_dlg(t, &"blocked", &""),
			"Je mist hier nog iets voor. %s" % t.hint)
		return

	var offer := _dlg(t, &"offer", &"")
	if offer != &"":
		await _dialogue.play(offer)

		# Eigen vakgebied geeft een makkelijkere opgave, nooit een moeilijkere.
	var voordeel := TraitModifier.voordeel_tekst(t)
	if voordeel != "":
		Bus.toast_requested.emit(voordeel, &"trait")
	var result: MinigameResult = await Shell.run_minigame(
		t.minigame_id, TraitModifier.pas_toe(t))

	match result.outcome:
		GameEnums.Outcome.SUCCESS:
			QuestEngine.complete(t.id, result)
			AudioDirector.play_sfx(&"ticket_klaar")
			var done := _dlg(t, &"complete", &"")
			if done != &"":
				await _dialogue.play(done)
		GameEnums.Outcome.FAIL:
			AudioDirector.play_sfx(&"fout")
			var fail := _dlg(t, &"fail", &"")
			if fail != &"":
				await _dialogue.play(fail)
			else:
				await _line("Dat werkte niet. Probeer het nog een keer.")
		_:
			pass   # afgebroken: ticket blijft ACTIVE, opnieuw proberen mag


# --- Collega aanspreken ---------------------------------------------------

func handle_npc_talk(source: Interactable) -> void:
	if _busy:
		return
	var npc := source.get_parent() as Npc
	if npc == null:
		return

	_busy = true
	# Is dit de expert die de speler nodig heeft voor een lopend ticket?
	var wanted := _ticket_waiting_for(npc.npc_id)
	if wanted != null:
		var d := _dlg(wanted, &"recruit", &"")
		if d != &"":
			await _dialogue.play(d)
		else:
			await _line("%s: \"Kom, ik loop wel even mee kijken.\"" % npc.def.name)
		npc.start_following(get_parent().get("player") as Node2D)
		Bus.toast_requested.emit("%s loopt met je mee" % npc.def.name, &"volgen")
	elif npc.def.dialogue_id != &"":
		await _dialogue.play(npc.def.dialogue_id, npc.def.name)
	else:
		await _line("%s heeft het te druk om te praten." % npc.def.name)
	_busy = false


## Het actieve of open ticket waarvoor deze NPC de eigenaar is.
func _ticket_waiting_for(npc_id: StringName) -> TicketDef:
	for id: StringName in GameData.ticket_ids():
		if not Session.is_available(id):
			continue
		var t: TicketDef = GameData.ticket(id)
		if t == null or QuestEngine.is_own_expertise(id):
			continue
		if QuestEngine.required_helper(id) != npc_id:
			continue
		if Session.get_flag(QuestEngine.helper_flag(id)):
			continue
		return t
	return null


# --- Hulpjes --------------------------------------------------------------

func _dlg(t: TicketDef, key: StringName, fallback: Variant) -> StringName:
	var v: Variant = t.dialogue_ids.get(key, fallback)
	return StringName(v) if v is StringName or v is String else &""


func _fetch_hint(t: TicketDef, helper_id: StringName) -> String:
	var d: NpcDef = GameData.npc(helper_id)
	var who := d.name if d != null else "de juiste collega"
	var role := t.owner_role if t.owner_role != "" else "specialist"
	return "Dit is niet jouw vakgebied. Je hebt %s nodig, de %s." % [who, role.to_lower()]


func _line(text: String) -> void:
	await _dialogue.say("", text)


func _play_or_line(dialogue_id: StringName, fallback: String) -> void:
	if dialogue_id != &"":
		await _dialogue.play(dialogue_id)
	else:
		await _line(fallback)
