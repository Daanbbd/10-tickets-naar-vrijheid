extends Node
## Headless testsuite. Draaien met:
##   Godot --headless --path . --scene res://tests/test_runner.tscn
##
## Draait als scene (niet als --script) omdat autoloads anders niet bestaan.

var _fails: Array[String] = []
var _checks: int = 0


func _ready() -> void:
	print("\n=== 10 TICKETS NAAR VRIJHEID — testsuite ===\n")
	_test_data_laadt()
	_test_verwijzingen()
	_test_dialoog()
	_test_minigame_inhoud()
	_test_nederlands()
	_test_wereld()
	_test_karakterstemmen()
	_test_questketen_alle_personages()
	_rapport()


# --- kleine assert-laag ---------------------------------------------------

func _ok(cond: bool, wat: String) -> void:
	_checks += 1
	if not cond:
		_fails.append(wat)


func _kop(t: String) -> void:
	print("-- %s" % t)


func _rapport() -> void:
	print("\n%d controles, %d fout" % [_checks, _fails.size()])
	if _fails.is_empty():
		print("ALLES GOED\n")
	else:
		print("\nFOUTEN:")
		for f: String in _fails:
			print("  x %s" % f)
		print("")
	get_tree().quit(0 if _fails.is_empty() else 1)


# --- tests ----------------------------------------------------------------

func _test_data_laadt() -> void:
	_kop("data laadt")
	_ok(GameData.load_errors.is_empty(), "GameData meldt: %s" % ", ".join(GameData.load_errors))
	_ok(GameData.character_ids().size() == 5, "verwacht 5 personages, kreeg %d" % GameData.character_ids().size())
	_ok(GameData.ticket_ids().size() == 10, "verwacht 10 tickets, kreeg %d" % GameData.ticket_ids().size())
	_ok(GameData.npcs.size() >= 6, "te weinig NPC's: %d" % GameData.npcs.size())
	_ok(not GameData.floor_data.is_empty(), "floor.json is leeg")


func _test_verwijzingen() -> void:
	_kop("verwijzingen")
	var object_ids := _object_ids()

	for id: StringName in GameData.ticket_ids():
		var t: TicketDef = GameData.ticket(id)
		_ok(t.anchor in object_ids, "%s: anchor '%s' bestaat niet als object" % [t.code, t.anchor])
		_ok(GameData.minigame_scene_path(t.minigame_id) != "",
			"%s: minigame '%s' staat niet in minigames.json" % [t.code, t.minigame_id])
		_ok(not MinigameContent.get_config(t.minigame_id).is_empty(),
			"%s: minigame '%s' heeft geen inhoud" % [t.code, t.minigame_id])
		_ok(t.zone_name != "", "%s: geen zone_name" % t.code)
		_ok(t.hint != "", "%s: geen hint" % t.code)

		for e: Variant in t.reward_effects:
			var bad := QuestEngine.unknown_effect_ops([e])
			_ok(bad.is_empty(), "%s: onbekende effect-op %s" % [t.code, bad])
		var badw := WorldMutator.unknown_ops(t.world_changes)
		_ok(badw.is_empty(), "%s: onbekende world_change-op %s" % [t.code, badw])
		for raw: Variant in t.world_changes:
			var c := raw as Dictionary
			var target := StringName(c.get("target", ""))
			if target != &"":
				_ok(GameData.has_world_id(target),
					"%s: world_change wijst naar onbekende id '%s'" % [t.code, target])
		for key: Variant in [t.available_when, t.requirements]:
			var bad_keys := Conditions.unknown_keys(key as Dictionary)
			_ok(bad_keys.is_empty(), "%s: onbekende conditie-key %s" % [t.code, bad_keys])

	# gedeelde ankers zijn toegestaan, maar elk ticket moet er wel bij kunnen
	var per_anker := {}
	for id: StringName in GameData.ticket_ids():
		var t: TicketDef = GameData.ticket(id)
		if not per_anker.has(t.anchor):
			per_anker[t.anchor] = []
		(per_anker[t.anchor] as Array).append(t)
	for anker: Variant in per_anker.keys():
		var lijst: Array = per_anker[anker]
		if lijst.size() < 2:
			continue
		# twee tickets op één object mogen nooit tegelijk open staan
		var orders: Array[int] = []
		for t: Variant in lijst:
			orders.append((t as TicketDef).order)
		orders.sort()
		for i: int in range(orders.size() - 1):
			_ok(orders[i] != orders[i + 1], "anker '%s': twee tickets met dezelfde volgorde" % anker)

	# elk personage bezit tickets die ook echt bestaan
	for cid: StringName in GameData.character_ids():
		var c: CharacterDef = GameData.character(cid)
		for tid: StringName in c.owned_tickets:
			_ok(GameData.ticket(tid) != null, "%s bezit onbekend ticket '%s'" % [c.name, tid])
		_ok(c.finale_id != &"", "%s heeft geen finale_id" % c.name)


func _test_dialoog() -> void:
	_kop("dialoog")
	var gebruikt: Array[StringName] = []

	for id: StringName in GameData.ticket_ids():
		var t: TicketDef = GameData.ticket(id)
		for k: Variant in t.dialogue_ids.keys():
			gebruikt.append(StringName(t.dialogue_ids[k]))
	for nid: Variant in GameData.npcs.keys():
		var n: NpcDef = GameData.npc(StringName(nid))
		if n.dialogue_id != &"":
			gebruikt.append(n.dialogue_id)
	for d: Dictionary in _objects():
		var did := StringName(d.get("dialogue", ""))
		if did != &"":
			gebruikt.append(did)

	for did: StringName in gebruikt:
		_ok(GameData.dialogue(did) != null, "dialoog '%s' ontbreekt" % did)

	# structuur van elke boom
	for key: Variant in GameData.dialogues.keys():
		var def: DialogueDef = GameData.dialogue(StringName(key))
		_ok(def.has_node_id(def.start_node), "dialoog '%s': startnode '%s' ontbreekt" % [key, def.start_node])
		for nid: Variant in def.nodes.keys():
			var node := def.node(StringName(nid))
			var variants: Array = node.get("variants", [])
			if not variants.is_empty():
				var laatste := variants[variants.size() - 1] as Dictionary
				_ok(not laatste.has("when") or (laatste["when"] as Dictionary).is_empty(),
					"dialoog '%s' node '%s': laatste variant heeft een 'when' (geen fallback)" % [key, nid])
			var nxt := StringName(node.get("next", ""))
			if nxt != &"":
				_ok(def.has_node_id(nxt), "dialoog '%s' node '%s': next '%s' bestaat niet" % [key, nid, nxt])
			for raw: Variant in node.get("choices", []):
				var ch := raw as Dictionary
				var cn := StringName(ch.get("next", ""))
				if cn != &"":
					_ok(def.has_node_id(cn), "dialoog '%s' node '%s': keuze-next '%s' bestaat niet" % [key, nid, cn])
				var bad := QuestEngine.unknown_effect_ops(ch.get("effects", []) as Array)
				_ok(bad.is_empty(), "dialoog '%s': onbekende effect-op %s" % [key, bad])
			var bad2 := QuestEngine.unknown_effect_ops(node.get("effects", []) as Array)
			_ok(bad2.is_empty(), "dialoog '%s': onbekende effect-op %s" % [key, bad2])


func _test_minigame_inhoud() -> void:
	_kop("minigame-inhoud")
	for id: Variant in GameData.minigames.keys():
		var mid := StringName(id)
		var c := MinigameContent.get_config(mid)
		_ok(not c.is_empty(), "minigame '%s' heeft geen inhoud" % mid)
		if c.is_empty():
			continue
		var t := String(c.get("type", ""))
		match t:
			"slotboard":
				var card_ids: Array[String] = []
				for raw: Variant in c.get("cards", []):
					card_ids.append(String((raw as Dictionary).get("id", "")))
				for raw: Variant in c.get("slots", []):
					var sl := raw as Dictionary
					var acc: Array = sl.get("accepts", [])
					_ok(not acc.is_empty(), "%s: slot '%s' accepteert niets" % [mid, sl.get("label", "")])
					for a: Variant in acc:
						_ok(String(a) in card_ids,
							"%s: slot accepteert onbekende kaart '%s'" % [mid, a])
				_ok((c.get("cards", []) as Array).size() > (c.get("slots", []) as Array).size(),
					"%s: niet meer kaarten dan vakken" % mid)
			"tagpicker":
				var tag_ids: Array[String] = []
				for raw: Variant in c.get("tags", []):
					tag_ids.append(String((raw as Dictionary).get("id", "")))
				var goed := 0
				var gedekt := {}
				for raw: Variant in c.get("resultaten", []):
					var r := raw as Dictionary
					if bool(r.get("goed", false)):
						goed += 1
					for a: Variant in r.get("when_any", []):
						_ok(String(a) in tag_ids, "%s: resultaat noemt onbekende tag '%s'" % [mid, a])
						gedekt[String(a)] = true
				_ok(goed >= 1, "%s: geen enkel resultaat is 'goed'" % mid)
				for tg: String in tag_ids:
					_ok(gedekt.has(tg), "%s: tag '%s' komt in geen enkel resultaat voor" % [mid, tg])
				_ok(int(c.get("kies", 0)) > 0 and int(c.get("kies", 0)) < tag_ids.size(),
					"%s: 'kies' is onzinnig" % mid)
			"choicescene":
				var maxpt := 0
				for raw: Variant in c.get("rondes", []):
					var best := 0
					for o: Variant in (raw as Dictionary).get("opties", []):
						best = maxi(best, int((o as Dictionary).get("punten", 0)))
					maxpt += best
				_ok(maxpt >= int(c.get("drempel", 0)),
					"%s: drempel %d is onhaalbaar (max %d)" % [mid, c.get("drempel", 0), maxpt])
			"cableboard":
				var node_ids: Array[String] = []
				for raw: Variant in c.get("nodes", []):
					node_ids.append(String((raw as Dictionary).get("id", "")))
				for raw: Variant in c.get("verbindingen", []):
					for e: Variant in (raw as Array):
						_ok(String(e) in node_ids, "%s: verbinding naar onbekende node '%s'" % [mid, e])
			"whack":
				_ok(int(c.get("doel", 0)) > 0, "%s: doel is 0" % mid)
			"deploy":
				var varianten := c.get("varianten", {}) as Dictionary
				for cid: StringName in GameData.character_ids():
					_ok(varianten.has(String(cid)), "mg_deploy: geen variant voor '%s'" % cid)
				for k: Variant in varianten.keys():
					var v := varianten[k] as Dictionary
					_ok(String(v.get("foutcode", "")) != "", "mg_deploy/%s: geen foutcode" % k)
					_ok(not (v.get("config", {}) as Dictionary).is_empty(), "mg_deploy/%s: lege config" % k)


func _test_nederlands() -> void:
	_kop("Nederlandse teksten")
	# Losse Engelse woorden die in spelerteksten bijna altijd op een
	# placeholder wijzen. Vaktermen als 'frontend' of 'deployment' mogen wel.
	var verdacht: Array[String] = ["TODO", "PLACEHOLDER", "Lorem ipsum", "lorem ipsum",
		"TBD", "FIXME", "XXX"]
	var teksten: Array[String] = []

	for id: StringName in GameData.ticket_ids():
		var t: TicketDef = GameData.ticket(id)
		teksten.append_array([t.title, t.summary, t.hint, t.zone_name])
	for key: Variant in GameData.dialogues.keys():
		var def: DialogueDef = GameData.dialogue(StringName(key))
		for nid: Variant in def.nodes.keys():
			var n := def.node(StringName(nid))
			teksten.append(String(n.get("text", "")))
			for raw: Variant in n.get("variants", []):
				teksten.append(String((raw as Dictionary).get("text", "")))
			for raw: Variant in n.get("choices", []):
				teksten.append(String((raw as Dictionary).get("text", "")))

	for s: String in teksten:
		for v: String in verdacht:
			_ok(not (v in s), "placeholdertekst gevonden: '%s' in \"%s\"" % [v, s.substr(0, 60)])


## Per personage de signature tics uit de BBD Character Handover. Zonder deze
## test blijft de stembijbel een document dat niemand naleeft: alle 277
## dialoogvarianten splitsten al af per personage en klonken toch identiek.
const TICS := {
	"jonathan":  ["ben benieuwd", "naartoe kijken", "moet zeggen", "nogmaals"],
	"danny":     ["joejoe", "psies", "biem", "ein-de-lijk", "olijfolie"],
	"victor":    ["manmanman", "godver", "ff kijken", "hahaha", "done."],
	"willem":    ["absoluta", "heeee", "wegens succes", "helemaal goed", "credits"],
	"koen":      ["ik zal", "ik check", "weet niet zeker", "lekker ouwe", "vgm", "pareltje"],
	"daan":      ["puur uit interesse", "wellicht", "ait", "makkelijk mogelijk"],
	"bastiaan":  [",,", "hiya", "trouwens", "planning is toch ver leeg", "tikkie"],
	"dennis":    ["oke", "thanks is gedaan", "-_-", "weekje later", "andere mogelijkheid", "deploy het wel"],
}


func _test_karakterstemmen() -> void:
	_kop("karakterstemmen")
	# Alle tekst per spreker verzamelen, over alle dialoogbomen heen.
	var per_spreker: Dictionary = {}
	for key: Variant in GameData.dialogues.keys():
		var def: DialogueDef = GameData.dialogue(StringName(key))
		for nid: Variant in def.nodes.keys():
			var n := def.node(StringName(nid))
			var basis := String(n.get("speaker", ""))
			_verzamel(per_spreker, basis, String(n.get("text", "")))
			for raw: Variant in n.get("variants", []):
				var v := raw as Dictionary
				_verzamel(per_spreker, String(v.get("speaker", basis)), String(v.get("text", "")))

	for wie: Variant in TICS.keys():
		var naam := String(wie)
		# de collega-NPC's heten npc_<naam>, de losse NPC's gewoon <naam>
		var tekst := String(per_spreker.get(naam, "")) + " " + String(per_spreker.get("npc_%s" % naam, ""))
		if tekst.strip_edges() == "":
			continue   # dit personage spreekt nergens; niets te controleren
		var gevonden := false
		for t: Variant in (TICS[wie] as Array):
			if String(t) in tekst:
				gevonden = true
				break
		_ok(gevonden, "%s heeft geen enkele signature tic in zijn dialoog" % naam)

	# Bastiaans dubbele komma is mechanisch te testen: geen enkele losse komma.
	var bas := String(per_spreker.get("bastiaan", ""))
	if bas != "":
		var los := 0
		for i: int in bas.length():
			if bas[i] != ",":
				continue
			var vorige_komma := i > 0 and bas[i - 1] == ","
			var volgende_komma := i + 1 < bas.length() and bas[i + 1] == ","
			if not vorige_komma and not volgende_komma:
				los += 1
		_ok(los == 0, "Bastiaan gebruikt %d losse komma('s); bij hem zijn het er altijd twee" % los)


static func _verzamel(bak: Dictionary, spreker: String, tekst: String) -> void:
	if spreker == "" or tekst == "":
		return
	bak[spreker] = String(bak.get(spreker, "")) + " " + tekst.to_lower()


func _test_wereld() -> void:
	_kop("wereld")
	var f := GameData.floor_data
	var grid: Array = f.get("grid", [])
	var size: Array = f.get("size", [0, 0])
	var legend := f.get("legend", {}) as Dictionary
	_ok(grid.size() == int(size[1]), "grid heeft %d regels, size zegt %d" % [grid.size(), size[1]])

	var onbekend := {}
	for row: Variant in grid:
		var r := String(row)
		_ok(r.length() == int(size[0]), "gridregel is %d breed, verwacht %d" % [r.length(), size[0]])
		for i: int in r.length():
			if not legend.has(r[i]):
				onbekend[r[i]] = true
	_ok(onbekend.is_empty(), "tekens zonder legenda: %s" % str(onbekend.keys()))

	# spawnpunt en objecten mogen niet in een muur staan
	var sp: Array = f.get("spawn", [0, 0])
	_ok(not _solide(grid, legend, int(sp[0]), int(sp[1])), "spawnpunt staat in een muur")
	for d: Dictionary in _objects():
		var t: Array = d.get("tile", [0, 0])
		_ok(not _solide(grid, legend, int(t[0]), int(t[1])),
			"object '%s' staat op een solide tegel" % d.get("world_id", "?"))
		_ok(GameData.has_world_id(StringName(d.get("world_id", ""))),
			"object '%s' staat niet in world_ids.json" % d.get("world_id", "?"))

	# Elke legenda-letter moet een atlas-coordinaat hebben. Zonder dit valt een
	# nieuw teken stil terug op de gewone vloertegel: world_builder._coord_for()
	# geeft Vector2i(0,0) voor onbekende tekens, en dat is tegel '.'.
	var atlas := _read_atlas_coords()
	_ok(not atlas.is_empty(), "assets/tilesets/office_atlas.json kon niet gelezen worden")
	for ch: Variant in legend.keys():
		_ok(atlas.has(ch), "legenda-teken '%s' heeft geen atlas-tegel (rendert stil als vloer)" % ch)

	# NPC-standplaatsen moeten bereikbaar zijn
	for nid: Variant in GameData.npcs.keys():
		var n: NpcDef = GameData.npc(StringName(nid))
		_ok(not _solide(grid, legend, n.home_tile.x, n.home_tile.y),
			"NPC '%s' staat op een solide tegel %s" % [n.id, n.home_tile])
		# Ook elk waypoint: nearest_walkable() snapt een fout punt stil weg,
		# waardoor een route ongemerkt ergens anders gaat lopen dan bedoeld.
		for wp: Vector2i in n.route:
			_ok(not _solide(grid, legend, wp.x, wp.y),
				"NPC '%s' heeft een waypoint op een solide tegel %s" % [n.id, wp])


func _test_questketen_alle_personages() -> void:
	_kop("questketen voor alle vijf personages")
	for cid: StringName in GameData.character_ids():
		var naam := GameData.character(cid).name
		Session.start_new(cid)
		QuestEngine.initialise_tickets()

		var open_bij_start := QuestEngine.open_tickets().size()
		_ok(open_bij_start >= 1, "%s: geen enkel ticket open bij de start" % naam)

		var rondes := 0
		while not Session.all_done() and rondes < 40:
			rondes += 1
			var todo := QuestEngine.open_tickets()
			_ok(not todo.is_empty(), "%s: vastgelopen op %d/10" % [naam, Session.done_count()])
			if todo.is_empty():
				break
			for t: TicketDef in todo:
				QuestEngine.activate(t.id)
				# niet-eigen vakgebied: de expert moet opgehaald zijn
				if not QuestEngine.is_own_expertise(t.id):
					var helper := QuestEngine.required_helper(t.id)
					_ok(helper == &"" or GameData.npc(helper) != null,
						"%s: %s vraagt om onbekende collega '%s'" % [naam, t.code, helper])
					_ok(not QuestEngine.requirements_met(t.id),
						"%s: %s is oplosbaar zonder de expert erbij" % [naam, t.code])
					QuestEngine.mark_helper_present(t.id)
				# t10 vraagt de deploysleutel uit het magazijn
				if not Conditions.check(t.requirements):
					for item: Variant in (t.requirements.get("has_item", []) as Array):
						Session.add_item(StringName(item))
				_ok(QuestEngine.requirements_met(t.id),
					"%s: %s blijft geblokkeerd" % [naam, t.code])
				QuestEngine.complete(t.id, MinigameResult.make(t.minigame_id, GameEnums.Outcome.SUCCESS))

		_ok(Session.all_done(), "%s: haalt maar %d/10 tickets" % [naam, Session.done_count()])
		_ok(Session.get_flag(&"alle_tickets_klaar"), "%s: vlag alle_tickets_klaar staat niet aan" % naam)
		_ok(Session.done_order.size() == 10, "%s: done_order telt %d" % [naam, Session.done_order.size()])

		# elk personage moet minstens één ticket zelf kunnen (eigen vakgebied)
		var eigen := 0
		for id: StringName in GameData.ticket_ids():
			if GameData.ticket(id).owner_character == cid:
				eigen += 1
		_ok(eigen >= 1, "%s heeft geen enkel eigen ticket" % naam)
		print("   %-9s %d/10 tickets, %d eigen vakgebied" % [naam, Session.done_count(), eigen])


# --- hulpjes --------------------------------------------------------------

static func _read_atlas_coords() -> Dictionary:
	var txt := FileAccess.get_file_as_string("res://assets/tilesets/office_atlas.json")
	var parsed: Variant = JSON.parse_string(txt)
	if not (parsed is Dictionary):
		return {}
	return (parsed as Dictionary).get("coords", {}) as Dictionary


static func _solide(grid: Array, legend: Dictionary, x: int, y: int) -> bool:
	if y < 0 or y >= grid.size():
		return true
	var r := String(grid[y])
	if x < 0 or x >= r.length():
		return true
	return bool((legend.get(r[x], {}) as Dictionary).get("solid", true))


func _objects() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/objects.json"))
	for raw: Variant in (parsed as Array if parsed is Array else []):
		out.append(raw as Dictionary)
	return out


func _object_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for d: Dictionary in _objects():
		out.append(StringName(d.get("world_id", "")))
	return out
