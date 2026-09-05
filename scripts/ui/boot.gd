extends Node
## Eerste scene. Wacht tot GameData geladen is, rapporteert dataproblemen en
## gaat door naar het titelscherm.
##
## QA-sneltoets: start met `-- --speler=daan [--ticket=t05]` om het titelscherm
## en de karakterselectie over te slaan. Alleen bedoeld voor testen.

@onready var _status: Label = $Center/Status


func _ready() -> void:
	await get_tree().process_frame

	if not GameData.load_errors.is_empty():
		_status.text = "Er ging iets mis bij het laden:\n\n" + "\n".join(GameData.load_errors.slice(0, 8))
		push_error("Boot: %d dataproblemen" % GameData.load_errors.size())
		return

	var args := _user_args()
	if args.has("minigame"):
		_quick_minigame(StringName(args["minigame"]), StringName(args.get("speler", "daan")),
			int(args.get("gedaan", 0)))
		return
	if args.has("scherm"):
		match String(args["scherm"]):
			"uitleg": Shell.goto_intro_uitleg()
			"select": Shell.goto_character_select()
			"besturing": Shell.goto_besturing()
			"einde":
				# De aftiteling leest je dag: zonder voortgang zou hij een dag
				# tonen waarin niets gebeurd is.
				QuestEngine.start_run(StringName(args.get("speler", "daan")))
				_speel_vooruit(int(args.get("gedaan", 0)))
				Shell.goto_ending()
			_:        Shell.goto_title()
		return
	if args.has("speler"):
		_quickstart(StringName(args["speler"]), String(args.get("ticket", "")))
		return

	_status.text = "Laden..."
	await get_tree().create_timer(0.2).timeout
	Shell.goto_title()


func _quickstart(character_id: StringName, up_to_ticket: String) -> void:
	if GameData.character(character_id) == null:
		_status.text = "Onbekend personage: %s" % character_id
		push_error("Boot: onbekend personage '%s'" % character_id)
		return

	QuestEngine.start_run(character_id)

	# Alle tickets vóór het opgegeven ticket meteen afvinken, in `order` en niet
	# in ketenvolgorde.
	#
	# Let op: dit is een QA-snelkoppeling en géén geldige speelbeurt. `order` is
	# narratieve nummering (zie `TicketDef.order`), dus deze lus kan tickets
	# afvinken die het echte spel op dat moment nog niet had opengesteld — en
	# `unlock()` erbij zet dat door. Handig om verderop in de dag te beginnen,
	# ongeschikt om conclusies over bereikbaarheid op te baseren; daarvoor is
	# `--playthrough`, die de keten wél respecteert.
	if up_to_ticket != "":
		for id: StringName in GameData.ticket_ids():
			if String(id) == up_to_ticket:
				break
			QuestEngine.unlock(id)
			QuestEngine.complete(id, MinigameResult.make(&"debug", GameEnums.Outcome.SUCCESS))
		# Het doelticket meteen in de inventaris, anders start QA met een leeg
		# bord en zonder doelregel.
		Session.discover(StringName(up_to_ticket))
		Session.pin(StringName(up_to_ticket))

	_status.text = "QA-start als %s" % character_id
	Shell.goto_game()


## QA: draait één minigame los, zonder wereld eromheen.
##
## `gedaan` zet eerst n tickets op opgelost. De urenstaat van Dirk leest je
## voortgang (de regels zijn het werk dat je vandaag echt gedaan hebt), dus
## zonder dat toont hij een dag waarin nog niets gebeurd is.
func _quick_minigame(id: StringName, character_id: StringName, gedaan: int = 0) -> void:
	QuestEngine.start_run(character_id)
	_speel_vooruit(gedaan)
	_status.text = "QA-minigame: %s" % id
	await get_tree().create_timer(0.2).timeout
	# Met --autoplay lost de minigame zichzelf op langs zijn echte winroute, zodat
	# ook de afronding en de payload headless te controleren zijn.
	#
	# M4: één enkele aanroep na 0,6 s loste alleen de dan lopende ronde op.
	# `mg_heatmap.qa_solve()` wacht zelf 1 s en moet daarna per nieuwe ronde
	# opnieuw aangeroepen worden — precies wat de echte `Autopilot` in
	# `main.gd` al doet (elke 0,45 s) en deze losse QA-aanroep niet deed.
	# Elk `--minigame=mg_cro --autoplay`-frame liet daardoor een verliezer
	# zien terwijl een echte speelbeurt hem gewoon oplost. `_klaar` is een
	# array en geen bool: een lambda in GDScript vangt lokale variabelen bij
	# aanmaak, niet erna, dus alleen een referentietype (hier: de array zelf)
	# laat de lus hieronder zien dat `Shell.run_minigame()` klaar is.
	var _klaar := [false]
	if Autopilot.gevraagd():
		_qa_solve_lus(_klaar)
	var res: MinigameResult = await Shell.run_minigame(id, _qa_inhoud(id))
	_klaar[0] = true
	print("[QA] minigame %s -> outcome=%d score=%d payload=%s" % [
		id, res.outcome, res.score, res.payload])
	_status.text = "%s klaar: %s" % [id, "gelukt" if res.is_success() else "niet gelukt"]


## Herhaalt `qa_solve()` op elke node in groep "minigame" elke 0,5 s, tot
## `klaar[0]` waar is. Fire-and-forget: draait naast de `await` op
## `Shell.run_minigame()` hierboven, niet erna.
func _qa_solve_lus(klaar: Array) -> void:
	while not klaar[0]:
		await get_tree().create_timer(0.5, true).timeout
		if klaar[0]:
			return
		for n: Node in get_tree().get_nodes_in_group("minigame"):
			(n as MinigameBase).qa_solve()


## De opgave zoals dit personage hem krijgt, inclusief het voordeel van zijn
## vakgebied.
##
## Zonder dit draaide `--minigame=` altijd de neutrale versie, en was de
## traitvariant met geen enkele vlag te zien — dus ook niet te controleren op
## een screenshot. Dat is precies hoe een voordeel dat niets deed jarenlang
## onopgemerkt kon blijven.
func _qa_inhoud(id: StringName) -> Dictionary:
	for tid: StringName in GameData.ticket_ids():
		var t: TicketDef = GameData.ticket(tid)
		if t == null or t.minigame_id != id:
			continue
		var inhoud: Dictionary = TraitModifier.pas_toe(t)
		if inhoud.is_empty():
			return {}
		print("[QA] %s draait met traitvoordeel: %s" % [id, TraitModifier.voordeel_tekst(t)])
		return {"inhoud": inhoud}
	return {}


## QA: lost de eerste n tickets op, met de uren die daarbij horen. Voor schermen
## die je voortgang lezen (de urenstaat, de aftiteling).
func _speel_vooruit(n: int) -> void:
	for tid: StringName in GameData.ticket_ids():
		if n <= 0:
			return
		# Alleen ophalen wat echt opgehaald moet worden, anders boekt de
		# QA-doorloop 15 minuten zoektijd op je eigen vakgebied en kloppen de
		# uren op het scherm niet met een echte speelbeurt.
		if not QuestEngine.is_own_expertise(tid):
			QuestEngine.mark_helper_present(tid)
		QuestEngine.complete(tid, MinigameResult.new())
		n -= 1


static func _user_args() -> Dictionary:
	var out := {}
	for a: String in OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		if "=" in s:
			var parts := s.split("=", true, 1)
			out[parts[0]] = parts[1]
		else:
			out[s] = true
	return out
