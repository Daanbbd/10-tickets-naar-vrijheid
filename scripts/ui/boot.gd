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
		_quick_minigame(StringName(args["minigame"]), StringName(args.get("speler", "daan")))
		return
	if args.has("scherm"):
		match String(args["scherm"]):
			"select": Shell.goto_character_select()
			"einde":  Shell.goto_ending()
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

	Session.start_new(character_id)
	QuestEngine.initialise_tickets()

	# Alle tickets vóór het opgegeven ticket meteen afvinken.
	if up_to_ticket != "":
		for id: StringName in GameData.ticket_ids():
			if String(id) == up_to_ticket:
				break
			QuestEngine.unlock(id)
			QuestEngine.complete(id, MinigameResult.make(&"debug", GameEnums.Outcome.SUCCESS))

	_status.text = "QA-start als %s" % character_id
	Shell.goto_game()


## QA: draait één minigame los, zonder wereld eromheen.
func _quick_minigame(id: StringName, character_id: StringName) -> void:
	Session.start_new(character_id)
	QuestEngine.initialise_tickets()
	_status.text = "QA-minigame: %s" % id
	# Deze route slaat _change_scene over, en daarmee ook de fade-in. Zonder dit
	# blijft het zwarte overgangsvlak liggen en zie je de minigame niet.
	await Shell.fade_in()
	await get_tree().create_timer(0.2).timeout
	var res: MinigameResult = await Shell.run_minigame(id, {})
	print("[QA] minigame %s -> outcome=%d score=%d" % [id, res.outcome, res.score])
	_status.text = "%s klaar: %s" % [id, "gelukt" if res.is_success() else "niet gelukt"]


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
