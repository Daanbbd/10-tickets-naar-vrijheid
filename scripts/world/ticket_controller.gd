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


## Loopt er nu een ticketstroom — oppakken, werven, minigame, afronden?
##
## Voor de QA-harnas. `Session.is_done()` valt vóór de urenrol en de
## afrondingsdialoog, dus daarop wachten betekent dat de doorloop het volgende
## ticket in racet terwijl dit nog loopt — en dan weigert `handle_npc_talk()`
## stil op zijn `_busy`-guard en loopt er dertig seconden later een collega
## "niet mee" zonder oorzaak. Zie `_qa_playthrough()` in main.gd.
func bezig() -> bool:
	return _busy


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
	# Een object kan meerdere tickets dragen (het scrumbord is er zowel voor de
	# planning als voor de paardenbugs), dus kies op basis van de stand van
	# zaken en niet op een vast id. Het slot gaat vóór het kiezen dicht: die
	# keuze kan een dialoogvenster openen, en dan mag er geen tweede E-druk
	# tussendoor komen.
	_busy = true
	var t := await _ticket_for_anchor(source.world_id if source != null else &"", ticket_id)
	if t == null:
		push_error("TicketController: geen ticket voor anker '%s'" % (source.world_id if source else ticket_id))
		_busy = false
		return

	await _handle_inner(t)
	_busy = false


## Volgorde: eerst een ticket waar je nu iets mee kunt, dan een geblokkeerd
## ticket (voor de 'nog niet'-regel), anders het laatst opgeloste.
##
## Draagt dit object er meer dan één die openstaat, dan kiest de speler. Dat
## gebeurt precies op één plek in het spel — het scrumbord in de gang — maar
## zonder deze vraag zou het tweede ticket daar onbereikbaar zijn.
func _ticket_for_anchor(world_id: StringName, fallback: StringName) -> TicketDef:
	var open := QuestEngine.tickets_at_anchor(world_id)
	if open.size() > 1:
		var gekozen := await _kies_uit(open, "Er ligt hier meer dan één ding.")
		if gekozen != null:
			return gekozen
	if open.size() == 1:
		return open[0]

	# Niets open op dit object: val terug op geblokkeerd of opgelost, zodat de
	# speler nog steeds een nette regel krijgt in plaats van stilte.
	var hier: Array[TicketDef] = []
	for id: StringName in GameData.ticket_ids():
		var t: TicketDef = GameData.ticket(id)
		if t != null and t.anchor == world_id:
			hier.append(t)
	if hier.is_empty():
		return GameData.ticket(fallback)
	for t: TicketDef in hier:
		if Session.ticket_state(t.id) == GameEnums.TicketState.LOCKED:
			return t
	return hier[hier.size() - 1]


## Heb je er al één gekozen op het bord, dan is dat het antwoord en vraagt het
## spel niet alsnog.
func _kies_uit(opties: Array[TicketDef], vraag: String) -> TicketDef:
	for t: TicketDef in opties:
		if Session.is_pinned(t.id):
			return t

	# Zonder het "BBD-"-voorvoegsel: op het bord staat er ook alleen een nummer
	# op een briefje, en dat scheelt hier vier tekens op een canvas van 192 px.
	var labels: Array[String] = []
	for t: TicketDef in opties:
		labels.append("%s  ·  %s" % [t.code.replace("BBD-", ""), t.title])
	var i := await _dialogue.ask_choice(vraag, labels)
	return opties[i] if i >= 0 and i < opties.size() else null


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

	# En dan zegt de eigenaar wat hij van zijn eigen ticket weet. Alleen als het
	# niet jouw vakgebied is: dan heb je hem opgehaald, en dít is waarvoor. Is
	# het wél jouw vakgebied, dan krijg je in plaats daarvan het voordeel in de
	# mechaniek (TraitModifier) — twee routes, in beide gevallen komt er iets
	# van een persoon.
	await _briefing(t)

		# Eigen vakgebied geeft een makkelijkere opgave, nooit een moeilijkere.
	var voordeel := TraitModifier.voordeel_tekst(t)
	if voordeel != "":
		Bus.toast_requested.emit(voordeel, &"trait")
	# Het voordeel gaat als `inhoud` mee en niet als losse sleutels: een minigame
	# leest zijn opgave uit `content()`, en die kijkt naar `content_override`.
	# Losse sleutels in `config` komen daar nooit aan, en dat is jarenlang de
	# reden geweest dat traits niets deden.
	var mg_config: Dictionary = {}
	var inhoud: Dictionary = TraitModifier.pas_toe(t)
	if not inhoud.is_empty():
		mg_config["inhoud"] = inhoud
	# Boven op de trait-aanpassing komt wat de dag heeft opgeleverd. Voor negen
	# tickets levert dat niets op; de finale begint er zijn hele toestand mee.
	mg_config.merge(Gevolgen.minigame_config(t.id), true)
	var result: MinigameResult = await Shell.run_minigame(t.minigame_id, mg_config)

	match result.outcome:
		GameEnums.Outcome.SUCCESS:
			# complete() boekt de uren zelf, vóór zijn eigen save. De HUD is al
			# aan het rollen op dat signaal; hier wachten we hem alleen uit,
			# zodat je je dag ziet weglopen vóór je personage reageert.
			QuestEngine.complete(t.id, result)
			AudioDirector.play_sfx(&"ticket_klaar")
			if _hud != null:
				await _hud.toon_urenrol()
			var done := _dlg(t, &"complete", &"")
			if done != &"":
				await _dialogue.play(done)
		GameEnums.Outcome.FAIL:
			AudioDirector.play_sfx(&"fout")
			# Falen kost tijd, nooit voortgang — en bewust géén klokrol: die
			# hoort bij een opgelost ticket. Een volle animatie op een mislukte
			# poging leest als straf en botst met het faalbeleid.
			Session.book_time(Urenstaat.FOUT_MIN, &"fout")
			Bus.toast_requested.emit(
				"+%s" % Urenstaat.formatteer_duur(Urenstaat.FOUT_MIN), &"tijd")
			var fail := _dlg(t, &"fail", &"")
			if fail != &"":
				await _dialogue.play(fail)
			else:
				await _line("Dat werkte niet. Probeer het nog een keer.")
		_:
			pass   # afgebroken: ticket blijft ACTIVE, opnieuw proberen mag


## Eén waar feit over dit ticket, in de stem van degene van wie het is.
##
## De feiten komen uit dezelfde config die de minigame straks draait, dus deze
## regel kan niet verouderen; zie `Briefing`.
func briefing(t: TicketDef) -> void:
	await _briefing(t)


func _briefing(t: TicketDef) -> void:
	if QuestEngine.is_own_expertise(t.id):
		return
	var tekst := Briefing.regel(t)
	if tekst == "":
		return
	var d: NpcDef = GameData.npc(QuestEngine.required_helper(t.id))
	if d == null:
		return
	# `owner_character` is hier het derde argument en niet zomaar een extraatje:
	# `say()` leidt daar zowel de pratende mond als het portret uit af. Dit is het
	# gezicht dat vlak voor de minigame in beeld komt.
	await _dialogue.say(d.name, tekst, t.owner_character)


# --- Collega aanspreken ---------------------------------------------------

func handle_npc_talk(source: Interactable) -> void:
	if _busy:
		return
	var npc := source.get_parent() as Npc
	if npc == null:
		return

	_busy = true
	# Is dit de expert die de speler nodig heeft voor een lopend ticket?
	var wanted := await _ticket_waiting_for(npc.npc_id)
	if wanted != null:
		# Een collega ophalen ís het aannemen van de opdracht. Zonder deze twee
		# regels veranderde er niets zichtbaars: het ticket zat niet in je
		# inventaris, was je doel niet, en de doelregel bleef naar iets anders
		# wijzen terwijl er iemand achter je aan liep.
		QuestEngine.activate(wanted.id)
		Session.pin(wanted.id)

		var d := _dlg(wanted, &"recruit", &"")
		if d != &"":
			await _dialogue.play(d)
		else:
			await _line("%s: \"Kom, ik loop wel even mee kijken.\"" % npc.def.name)
		npc.start_following(get_parent().get("player") as Node2D)
		# De bestemming erbij: de toast is vluchtig, dus hij moet iets zeggen wat
		# nergens anders staat. Wie er meeloopt staat vanaf nu permanent op de
		# doelregel en op het bord.
		Bus.toast_requested.emit("%s loopt mee naar %s" % [npc.def.name, wanted.zone_name], &"volgen")
		# Het briefje ná het gesprek: bij een object is het briefje de vondst,
		# hier is het gesprek de werving en het briefje het gevolg.
		if _hud != null:
			await _hud.toon_nieuw_briefje(wanted)
	elif npc.def.dialogue_id != &"":
		var uitkomst := await _dialogue.play(npc.def.dialogue_id, npc.def.name)
		# Dirk is de enige NPC met een minigame achter zijn gesprek. Welke van
		# zijn drie antwoorden je koos staat in de uitkomst; alleen "boeken"
		# opent de urenstaat. De andere twee laten hem gewoon meelopen.
		if uitkomst == &"boeken":
			await _urenstaat(npc)
	else:
		await _line("%s heeft het te druk om te praten." % npc.def.name)
	_busy = false


## De urenstaat van Dirk. Geen goed antwoord: elke verdeling wordt aangenomen.
## Hij keurt niets af, hij noteert — en dat is precies wat hier
## passief-agressief betekent.
func _urenstaat(npc: Npc) -> void:
	var result: MinigameResult = await Shell.run_minigame(&"mg_urenstaat", {})
	if result.outcome != GameEnums.Outcome.SUCCESS:
		# Afgebroken. Hij komt er later op terug, want hij komt er altijd op terug.
		return

	var p := result.payload
	Session.book_hours(int(p.get("geboekt_min", 0)))
	AudioDirector.play_sfx(&"ticket_klaar")
	await _line("%s: \"%s\"" % [npc.def.name, _dirk_oordeel(p)])


## Zijn slotregel hangt af van waar je de uren hebt weggeschreven. Nooit een
## verwijt, altijd een observatie met een getal erin.
static func _dirk_oordeel(p: Dictionary) -> String:
	var rest := int(p.get("op_rest", 0))
	var leeg := int(p.get("lege_tickets", 0))
	if rest >= 4 * 60:
		return ("Dank je! Ik zie %s op overige posten staan. Ik zet er een "
			+ "vraagteken bij, dan kijkt Dennis er nog even naar.") % Urenstaat.formatteer_duur(rest)
	if leeg > 0:
		return ("Dank je! Er staan nog %d tickets op nul. Dan is daar niet aan "
			+ "gewerkt, klopt dat?") % leeg
	if rest == 0:
		return "Dank je! Helemaal op het werk zelf geboekt. Dat is netjes."
	return ("Dank je! %s op overig. Dat kan gebeuren. "
		+ "Alvast bedankt!") % Urenstaat.formatteer_duur(rest)


## Het open ticket waarvoor deze NPC de eigenaar is. Danny bezit er twee en Daan
## ook, dus nu alles tegelijk openstaat kan één collega voor meerdere dingen
## gevraagd worden. Je pin wint; anders vraagt hij waar het over gaat.
func _ticket_waiting_for(npc_id: StringName) -> TicketDef:
	var kandidaten: Array[TicketDef] = []
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
		kandidaten.append(t)

	if kandidaten.is_empty():
		return null
	if kandidaten.size() == 1:
		return kandidaten[0]
	return await _kies_uit(kandidaten, "Waar wil je hem voor hebben?")


# --- Hulpjes --------------------------------------------------------------

func _dlg(t: TicketDef, key: StringName, fallback: Variant) -> StringName:
	var v: Variant = t.dialogue_ids.get(key, fallback)
	return StringName(v) if v is StringName or v is String else &""


func _fetch_hint(t: TicketDef, helper_id: StringName) -> String:
	var d: NpcDef = GameData.npc(helper_id)
	var who := d.name if d != null else "de juiste collega"
	# Geen lidwoord voor de rol: die staat nu in de vorm waarin de character
	# bible hem noemt ("Frontend / design systemen"), en "de frontend / design
	# systemen" is geen Nederlands.
	var role := t.owner_role if t.owner_role != "" else "de specialist hiervoor"
	return "Dit is niet jouw vakgebied. Je hebt %s nodig — %s." % [who, role]


func _line(text: String) -> void:
	await _dialogue.say("", text)


func _play_or_line(dialogue_id: StringName, fallback: String) -> void:
	if dialogue_id != &"":
		await _dialogue.play(dialogue_id)
	else:
		await _line(fallback)
