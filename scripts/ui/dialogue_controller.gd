class_name DialogueController
extends Node
## Draait dialoogbomen uit data/dialogue/*.json.
##
## Beheert zijn eigen CanvasLayer en de input-grab. Staat bewust ná World in de
## scene-boom zodat _unhandled_input de interactietoets als eerste ziet.

var _layer: CanvasLayer
var _box: DialogueBox
var _active: bool = false
var _choice_index: int = -1


func setup() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 20
	add_child(_layer)
	_box = DialogueBox.new()
	_layer.add_child(_box)
	_box.choice_picked.connect(_on_choice_picked)


func is_active() -> bool:
	return _active


## Speelt een dialoogboom af en geeft de outcome van de eindnode terug.
func play(dialogue_id: StringName, fallback_label: String = "") -> StringName:
	if _active:
		return &""
	var def: DialogueDef = GameData.dialogue(dialogue_id)
	if def == null:
		# Geen dialoog gevonden: laat een nette regel zien in plaats van niets.
		await _play_single("", "Er valt hier weinig over te zeggen." if fallback_label == ""
			else "%s. Verder niets bijzonders." % fallback_label)
		return &""

	_active = true
	Session.input_locked = true
	AudioDirector.duck()
	Bus.dialogue_started.emit(dialogue_id, StringName(_speaker_of(def, def.start_node)))

	var outcome := &""
	var current := def.start_node
	var guard := 0

	while current != &"" and guard < 256:
		guard += 1
		var node := def.node(current)
		if node.is_empty():
			push_error("DialogueController: node '%s' bestaat niet in '%s'" % [current, dialogue_id])
			break

		var variant := Conditions.pick_variant(node.get("variants", []) as Array)
		var text := String(variant.get("text", node.get("text", "")))
		var speaker_id := String(variant.get("speaker", node.get("speaker", "")))
		var speaker := _display_name(speaker_id)

		if text != "":
			await _show_and_wait(speaker, text, _portrait_for(speaker_id))

		QuestEngine.run_effects(node.get("effects", []) as Array)
		QuestEngine.run_effects(variant.get("effects", []) as Array)

		var choices := Conditions.filter_choices(node.get("choices", []) as Array)
		if not choices.is_empty():
			var picked := await _ask(choices)
			var ch := choices[picked] as Dictionary
			QuestEngine.run_effects(ch.get("effects", []) as Array)
			if ch.has("outcome"):
				outcome = StringName(ch["outcome"])
			current = StringName(ch.get("next", ""))
		else:
			if node.has("outcome"):
				outcome = StringName(node["outcome"])
			current = StringName(node.get("next", ""))

	_box.close()
	_active = false
	AudioDirector.unduck()
	# Eén frame wachten zodat de bevestigingstoets niet doorlekt naar de wereld.
	await get_tree().process_frame
	Session.input_locked = false
	Bus.dialogue_finished.emit(dialogue_id, outcome)
	return outcome


## Losse regel zonder dialoogbestand, voor korte onderzoeksteksten.
func say(speaker: String, text: String) -> void:
	await _play_single(speaker, text)


func _play_single(speaker: String, text: String) -> void:
	_active = true
	Session.input_locked = true
	await _show_and_wait(speaker, text)
	_box.close()
	_active = false
	await get_tree().process_frame
	Session.input_locked = false


func _show_and_wait(speaker: String, text: String, portrait: Texture2D = null) -> void:
	_box.show_line(speaker, text, portrait)
	while true:
		await _next_press()
		if _box.typing():
			_box.finish_typing()
		else:
			return


func _ask(choices: Array) -> int:
	var labels: Array[String] = []
	for c: Variant in choices:
		labels.append(String((c as Dictionary).get("text", "...")))
	_choice_index = -1
	_box.show_choices(labels)
	while _choice_index < 0:
		await get_tree().process_frame
	return _choice_index


func _on_choice_picked(index: int) -> void:
	_choice_index = index


func _next_press() -> void:
	while true:
		await get_tree().process_frame
		if Input.is_action_just_pressed("interact"):
			return


func _speaker_of(def: DialogueDef, nid: StringName) -> String:
	return String((def.node(nid)).get("speaker", ""))


## Portret van de spreker, afgeleid uit de echte teamfoto's waar die er zijn.
func _portrait_for(speaker_id: String) -> Texture2D:
	if speaker_id == "":
		return null
	var path := ""
	if speaker_id == "speler":
		var pc := Session.character()
		path = pc.portrait if pc != null else ""
	else:
		var n: NpcDef = GameData.npc(StringName(speaker_id))
		if n != null:
			path = n.portrait
		else:
			var ch: CharacterDef = GameData.character(StringName(speaker_id))
			if ch != null:
				path = ch.portrait
	return load(path) if path != "" and ResourceLoader.exists(path) else null


func _display_name(speaker_id: String) -> String:
	if speaker_id == "":
		return ""
	if speaker_id == "speler":
		var c := Session.character()
		return c.name if c != null else "Jij"
	var n: NpcDef = GameData.npc(StringName(speaker_id))
	if n != null:
		return n.name
	var ch: CharacterDef = GameData.character(StringName(speaker_id))
	if ch != null:
		return ch.name
	return speaker_id.capitalize()
