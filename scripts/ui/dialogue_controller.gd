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
	# Een gesprek grijpt de invoer af: je loopt niet meer, je leest. Op mobiel is
	# dat de enige aankondiging die er is, want het venster schuift stil in beeld.
	# Op het signaal en niet bij de drie emits, zodat een losse regel, een
	# keuzevraag en een hele dialoogboom hetzelfde aanvoelen.
	Bus.dialogue_started.connect(_op_dialoog_start)


func is_active() -> bool:
	return _active


func _op_dialoog_start(_dialogue_id: StringName, _speaker_id: StringName) -> void:
	Haptiek.tril(Haptiek.Sterkte.STOOT)


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
	Session.lock_input()
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
	# Eén frame wachten zodat de bevestigingstoets niet doorlekt naar de wereld.
	await get_tree().process_frame
	Session.unlock_input()
	Bus.dialogue_finished.emit(dialogue_id, outcome)
	return outcome


## Losse regel zonder dialoogbestand, voor korte onderzoeksteksten.
##
## `speaker_id` is optioneel en alleen voor de animatie: `npc.gd` luistert op
## `dialogue_started` om de mond van de juiste collega te laten bewegen, en
## vergelijkt daar op id ("jonathan") en niet op weergavenaam ("Jonathan").
## Zonder dit staat er bij een briefing wel een naam boven de tekst, maar
## beweegt er niemand.
func say(speaker: String, text: String, speaker_id: StringName = &"") -> void:
	await _play_single(speaker, text, speaker_id)


## Ook een losse regel is een gesprek. Het signaal gaat er daarom net zo goed
## uit als bij een hele dialoogboom -- de AudioDirector zet de muziek erop terug
## en zonder deze emit blijft het kantoor gewoon doorspelen onder de tekst.
func _play_single(speaker: String, text: String, speaker_id: StringName = &"") -> void:
	_active = true
	Session.lock_input()
	Bus.dialogue_started.emit(&"", speaker_id if speaker_id != &"" else StringName(speaker))
	await _show_and_wait(speaker, text)
	_box.close()
	_active = false
	await get_tree().process_frame
	Session.unlock_input()
	Bus.dialogue_finished.emit(&"", &"")


func _show_and_wait(speaker: String, text: String, portrait: Texture2D = null) -> void:
	_box.show_line(speaker, vul_in(text), portrait)
	while true:
		await _next_press()
		if _box.typing():
			_box.finish_typing()
		else:
			return


## Een losse keuzevraag, buiten een dialoogboom om. Nodig sinds alle tickets
## tegelijk openstaan: één object kan er twee dragen (het scrumbord in de gang
## is er zowel voor de planning als voor de paardenbugs), en dan moet de speler
## zeggen welke hij bedoelt. Hergebruikt de keuzeknoppen van de dialoogbox.
func ask_choice(vraag: String, labels: Array[String]) -> int:
	if _active or labels.is_empty():
		return -1
	_active = true
	Session.lock_input()
	Bus.dialogue_started.emit(&"", &"")
	_box.show_line("", vraag)
	_box.finish_typing()
	var keuze := await _wait_for_choice(labels)
	_box.close()
	_active = false
	await get_tree().process_frame
	Session.unlock_input()
	Bus.dialogue_finished.emit(&"", &"")
	return keuze


func _ask(choices: Array) -> int:
	var labels: Array[String] = []
	for c: Variant in choices:
		labels.append(vul_in(String((c as Dictionary).get("text", "..."))))
	return await _wait_for_choice(labels)


func _wait_for_choice(labels: Array[String]) -> int:
	_choice_index = -1
	_box.show_choices(labels)
	while _choice_index < 0:
		await get_tree().process_frame
	return _choice_index


func _on_choice_picked(index: int) -> void:
	_choice_index = index


## Op een aanraakscherm is de hele dialoog de knop. Een speler die op een
## telefoon een tekstblok ziet tikt erop; die tik moet doorzetten in plaats
## van naar de actieknop rechtsonder te verwijzen.
var _getikt: bool = false


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		_getikt = true
	elif Invoer.muis_als_vinger() and event is InputEventMouseButton \
			and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_getikt = true


func _next_press() -> void:
	_getikt = false
	while true:
		await get_tree().process_frame
		if Input.is_action_just_pressed("interact") or _getikt:
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


## Vult de tokens in die pas tijdens het spelen bestaan.
##
## Dirk bestaat bij de gratie van een exact getal — "er staat {geboekt} geboekt,
## terwijl de verwachting rond de {gewerkt} ligt" — en hij begint altijd met je
## naam. Met zeven speelbare personages en een lopende klok kan dat niet in
## vaste strings. Onbekende accolades laat dit staan, zodat een typefout in de
## data zichtbaar is in plaats van stil te verdwijnen.
##
## Statisch, zodat de testsuite hem zonder scene kan controleren.
static func vul_in(text: String) -> String:
	if not text.contains("{"):
		return text
	var naam := ""
	var c: CharacterDef = Session.character()
	if c != null:
		naam = c.name
	return text \
		.replace("{naam}", naam) \
		.replace("{gewerkt}", Urenstaat.formatteer_duur(Session.worked_minutes)) \
		.replace("{geboekt}", Urenstaat.formatteer_duur(Session.booked_minutes)) \
		.replace("{budget}", Urenstaat.formatteer_duur(Urenstaat.BUDGET_MIN)) \
		.replace("{klok}", Urenstaat.formatteer(Urenstaat.nu()))


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
