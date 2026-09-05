class_name DialogueController
extends Node
## Draait dialoogbomen uit data/dialogue/*.json.
##
## Beheert zijn eigen CanvasLayer en de input-grab.
##
## De invoer loopt hier langs twee kanten, en geen van beide is
## `_unhandled_input` (dat stond hier lang beschreven, maar die methode bestaat
## in dit bestand niet): een tik komt binnen via `_input()`, en de
## bevestigingstoets wordt per frame gepolld in `_next_press()`. Pollen kan hier
## omdat een dialoog toch al frame voor frame op de speler wacht, en het houdt
## het wachten op één regel bij het wachten op een keuze -- die kan niet
## event-gedreven, want daar drukt een Button.
##
## F5-a: dit grijpt zijn invoer via `Session.lock_input()`, niet via
## `get_tree().paused` — dat stond al zo vóórdat een minigame haar eigen pauze
## kwijtraakte, en verandert hier dus niet. Een dialoog zette de klok en de
## collega's nooit stil (alleen `Besturing`/`main.gd` bailen op
## `Session.input_locked`); dat blijft zo. Lezen mag geen straf zijn — het
## enige dat vastzit is de speler zelf, niet het kantoor eromheen.

var _layer: CanvasLayer
var _box: DialogueBox
var _active: bool = false
var _choice_index: int = -1

## Hoeveel geschreven regels en keuzevragen dit gesprek heeft gewéigerd omdat er
## al een gesprek liep. Elke weigering is een regel die de speler nooit ziet, of
## een keuze die als -1 terugkomt en dus stil de eerste optie wordt.
##
## Dit staat er omdat `push_error()` de exitcode niet raakt: op het BBD-203-pad
## vielen alle authored regels én alle drie keuzerondes weg, en de
## geautomatiseerde speelbeurt meldde dat als "10/10, exit 0". Een teller kan de
## speelbeurt wél laten falen -- zie `_speelbeurt()` in main.gd.
var _geweigerd: int = 0


func setup() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 20
	add_child(_layer)
	_box = DialogueBox.new()
	_layer.add_child(_box)
	_box.choice_picked.connect(_on_choice_picked)
	_box.overslaan_gevraagd.connect(overslaan)
	# Een gesprek grijpt de invoer af: je loopt niet meer, je leest. Op mobiel is
	# dat de enige aankondiging die er is, want het venster schuift stil in beeld.
	# Op het signaal en niet bij de drie emits, zodat een losse regel, een
	# keuzevraag en een hele dialoogboom hetzelfde aanvoelen.
	Bus.dialogue_started.connect(_op_dialoog_start)


func is_active() -> bool:
	return _active


## Het aantal geweigerde regels en keuzevragen sinds het begin van de run.
func geweigerd() -> int:
	return _geweigerd


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
	_skip = false
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
## `speaker_id` is optioneel en doet twee dingen. Ten eerste de animatie:
## `npc.gd` luistert op `dialogue_started` om de mond van de juiste collega te
## laten bewegen, en vergelijkt daar op id ("jonathan") en niet op weergavenaam
## ("Jonathan"). Zonder dit staat er bij een briefing wel een naam boven de
## tekst, maar beweegt er niemand.
##
## Ten tweede het portret. Een dialoogboom liet altijd het gezicht van de
## spreker zien -- `play()` roept `_portrait_for()` aan -- maar de losse regel
## niet, en juist de briefing van de eigenaar loopt via deze route. Dat is het
## enige moment vóór een minigame waarop een persoon iets over zijn eigen ticket
## zegt, en daar stond dus een naam zonder gezicht bij terwijl `DialogueBox` het
## portret al kon tonen. `portret` overschrijft de afleiding uit `speaker_id`
## voor een aanroeper die zelf al weet welk gezicht erbij hoort.
func say(speaker: String, text: String, speaker_id: StringName = &"",
		portret: Texture2D = null) -> void:
	# Dezelfde wacht aan de deur als `play()` en `ask_choice()`. Die stond hier
	# niet, en dat is de gevaarlijkste van de drie om te missen: `_play_single()`
	# zet aan het eind onvoorwaardelijk `_active = false` en ontgrendelt de
	# invoer, dus een `say()` binnen een lopend gesprek zou de vloer openzetten
	# terwijl er nog tekst staat. Geen enkele aanroeper doet dat vandaag -- alle
	# drie wachten netjes op elkaar -- maar dan hoort het ook hoorbaar te zijn
	# als er ooit eentje bijkomt, in plaats van als een halve speelbeurt.
	if _active:
		_geweigerd += 1
		push_error("DialogueController: say() tijdens een lopend gesprek: '%s'" % text)
		return
	await _play_single(speaker, text, speaker_id, portret)


## Ook een losse regel is een gesprek. Het signaal gaat er daarom net zo goed
## uit als bij een hele dialoogboom -- de AudioDirector zet de muziek erop terug
## en zonder deze emit blijft het kantoor gewoon doorspelen onder de tekst.
func _play_single(speaker: String, text: String, speaker_id: StringName = &"",
		portret: Texture2D = null) -> void:
	_active = true
	_skip = false
	Session.lock_input()
	Bus.dialogue_started.emit(&"", speaker_id if speaker_id != &"" else StringName(speaker))
	await _show_and_wait(speaker, text,
		portret if portret != null else _portrait_for(String(speaker_id)))
	_box.close()
	_active = false
	await get_tree().process_frame
	Session.unlock_input()
	Bus.dialogue_finished.emit(&"", &"")


func _show_and_wait(speaker: String, text: String, portrait: Texture2D = null) -> void:
	_box.show_line(speaker, vul_in(text), portrait)
	# Overslaan: de regel staat één frame volledig in beeld en gaat door. De
	# effects van de node draaien gewoon (die staan in de lus in `play()`), een
	# keuze wacht altijd (`_wait_for_choice()` zet de vlag weer uit).
	if _skip:
		_box.finish_typing()
		await get_tree().process_frame
		return
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
	if _active:
		# Alleen deze helft telt als weigering: een lege labellijst is een
		# aanroepfout van de opgave zelf, geen regel die door een lopend
		# gesprek wordt platgedrukt.
		_geweigerd += 1
		push_error("DialogueController: ask_choice() tijdens een lopend gesprek: '%s'" % vraag)
		return -1
	if labels.is_empty():
		return -1
	_active = true
	_skip = false
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
	_skip = false
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
## Overslaan: de rest van het lopende gesprek in één beweging, tot de eerste
## keuze. Een gesprek van vijf regels kostte tien tikken (één om het typen af te
## maken, één om door te gaan), en wie het al kent wil eruit. Esc en het
## "overslaan »" in de box komen hier allebei uit.
var _skip: bool = false


func overslaan() -> void:
	if _active:
		_skip = true


## Een regel boven iets in de wereld, zonder de wereld stil te zetten: geen
## invoerslot, geen tik, geen signaal. Zie `Bark`.
func bark(tekst: String, bij: Node2D) -> void:
	Bark.toon(bij, vul_in(tekst))


## Kan deze boom als terzijde? Eén node, geen keuze, geen vervolg, geen effect —
## ook niet in een variant. Alles wat meer is hoort in de box: effecten moeten
## zichtbaar landen en een keuze moet wachten.
static func is_bark_geschikt(def: DialogueDef) -> bool:
	if def == null or def.nodes.size() != 1:
		return false
	var node: Dictionary = def.node(def.start_node)
	if node.is_empty() or node.has("choices"):
		return false
	if not (node.get("effects", []) as Array).is_empty():
		return false
	if String(node.get("next", "")) != "":
		return false
	for raw: Variant in node.get("variants", []) as Array:
		var v := raw as Dictionary
		if v != null and not (v.get("effects", []) as Array).is_empty():
			return false
	return true


## Speelt `dialogue_id` als terzijde boven `bij` als de boom daar geschikt voor
## is, en zegt met false dat de aanroeper hem gewoon modaal moet spelen als dat
## niet zo is (of als er al een gesprek loopt).
func speel_of_bark(dialogue_id: StringName, bij: Node2D) -> bool:
	if _active or bij == null or dialogue_id == &"":
		return false
	var def: DialogueDef = GameData.dialogue(dialogue_id)
	if not is_bark_geschikt(def):
		return false
	var node: Dictionary = def.node(def.start_node)
	var variant := Conditions.pick_variant(node.get("variants", []) as Array)
	var tekst := String(variant.get("text", node.get("text", "")))
	if tekst == "":
		return false
	bark(tekst, bij)
	return true

var _getikt: bool = false


func _input(event: InputEvent) -> void:
	# Esc tijdens een gesprek zonder open keuze: de rest van het gesprek
	# overslaan. Afgevangen vóór `Main._unhandled_input()`, anders opent
	# dezelfde druk het pauzemenu.
	if _active and event.is_action_pressed("cancel") and not _box.has_choices():
		_skip = true
		get_viewport().set_input_as_handled()
		return
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
