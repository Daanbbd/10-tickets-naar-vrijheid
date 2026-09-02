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
	_test_traits()
	_test_urenstaat()
	_test_gevolgen()
	_test_questketen_alle_personages()
	_test_vrije_volgorde()
	_test_gedeelde_ankers()
	_test_vinden()
	_test_startroutes()
	_test_ankers_bereikbaar()
	_test_ticket_eigenaarschap()
	_test_omz_en_absoluta()
	_test_balkmaat()
	_test_briefings()
	_test_intro()
	_test_save_ronde()
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

func _test_gevolgen() -> void:
	_kop("gevolgen en de telefoon van De Klant")

	QuestEngine.start_run(&"daan")

	# --- de berichten bestaan ---------------------------------------------
	var pad := "res://data/klant_berichten.json"
	_ok(FileAccess.file_exists(pad), "klant_berichten.json ontbreekt")
	var rauw: Variant = JSON.parse_string(FileAccess.get_file_as_string(pad))
	_ok(rauw is Dictionary, "klant_berichten.json is geen JSON-object")
	if not (rauw is Dictionary):
		return
	var berichten := (rauw as Dictionary).get("berichten", {}) as Dictionary
	_ok(String((rauw as Dictionary).get("afzender", "")) != "",
		"geen afzender: haar profielfoto is haar merk, dus die naam moet er staan")

	# Elke drempel moet een bericht hebben, anders valt er stilletjes een fase
	# uit de spanningsboog weg: `Telefoon` zoekt op "k<fase>" en zwijgt als die
	# niet bestaat.
	for i: int in Gevolgen.DREMPELS.size():
		var bid := "k%d" % (i + 1)
		_ok(berichten.has(bid),
			"drempel %d tickets heeft geen bericht '%s'" % [Gevolgen.DREMPELS[i], bid])

	# --- de varianten zijn compleet ---------------------------------------
	for bid: Variant in berichten.keys():
		var b := berichten[bid] as Dictionary
		var varianten := b.get("variants", []) as Array
		_ok(not varianten.is_empty(), "%s heeft geen varianten" % bid)
		if varianten.is_empty():
			continue
		# Zelfde regel als in de dialoog: de laatste variant is de verplichte
		# fallback. Zonder die regel zwijgt ze precies bij de speler wiens
		# keuzes geen enkele conditie raken.
		var laatste := varianten[varianten.size() - 1] as Dictionary
		_ok(not laatste.has("when"),
			"%s eindigt niet op een variant zonder 'when'" % bid)
		_ok(String(b.get("tijd", "")) != "",
			"%s heeft geen tijdstip; zij stuurt altijd op een tijd die opvalt" % bid)

		for v: Variant in varianten:
			var d := v as Dictionary
			_ok(String(d.get("text", "")) != "", "%s: variant zonder tekst" % bid)
			var w := d.get("when", {}) as Dictionary
			for k: String in Conditions.unknown_keys(w):
				_ok(false, "%s: onbekende conditie-key '%s'" % [bid, k])
			# De echte valkuil: een typefout in een vlagnaam is onzichtbaar —
			# die variant valt dan gewoon nooit, en niemand merkt het.
			for lijst: String in ["flags_all", "flags_none"]:
				for f: Variant in w.get(lijst, []):
					_ok(StringName(f) in Gevolgen.VLAGGEN,
						"%s: %s noemt vlag '%s', die Gevolgen nooit zet" % [bid, lijst, f])

	# --- geen enkele gevolgvlag is een typefout ----------------------------
	# Een verkeerd gespelde vlag in een `flags_all` is de vervelendste fout die
	# dit systeem kan hebben: die variant valt dan nooit, er komt geen
	# foutmelding, en het gevolg dat de speler verdiende bestaat gewoon niet.
	# Daarom kijkt dit door ALLE dialoogbomen heen, niet alleen de telefoon.
	for map: String in ["npcs", "tickets", "wereld"]:
		var dpad := "res://data/dialogue/%s.json" % map
		var rd: Variant = JSON.parse_string(FileAccess.get_file_as_string(dpad))
		if not (rd is Dictionary):
			continue
		for gevonden: StringName in _gevolgvlaggen_in(rd):
			_ok(gevonden in Gevolgen.VLAGGEN,
				"dialogue/%s.json noemt vlag '%s', die Gevolgen nooit zet" % [map, gevonden])

	# En de andere kant op: een vlag die Gevolgen wél zet maar die nergens
	# gelezen wordt is dode code — het gevolg is dan onzichtbaar voor de speler.
	var gelezen: Dictionary = {}
	for map: String in ["npcs", "tickets", "wereld"]:
		var rd2: Variant = JSON.parse_string(
			FileAccess.get_file_as_string("res://data/dialogue/%s.json" % map))
		if rd2 is Dictionary:
			for g: StringName in _gevolgvlaggen_in(rd2):
				gelezen[g] = true
	var rk: Variant = JSON.parse_string(FileAccess.get_file_as_string(pad))
	if rk is Dictionary:
		for g2: StringName in _gevolgvlaggen_in(rk):
			gelezen[g2] = true
	for v: StringName in Gevolgen.VLAGGEN:
		_ok(gelezen.has(v),
			"Gevolgen zet '%s', maar geen dialoog of bericht reageert erop" % v)

	# --- de druk loopt op --------------------------------------------------
	_ok(Gevolgen.druk() == 0, "met nul tickets staat de druk niet op 0")
	var vorige := -1
	for n: int in 11:
		Session.done_order.clear()
		for i: int in n:
			Session.done_order.append(GameData.ticket_ids()[i])
		var d := Gevolgen.druk()
		_ok(d >= vorige, "de druk zakt tussen %d en %d tickets" % [n - 1, n])
		_ok(d >= 0 and d <= Gevolgen.DREMPELS.size(),
			"druk %d valt buiten 0..%d" % [d, Gevolgen.DREMPELS.size()])
		vorige = d
	_ok(Gevolgen.druk() == Gevolgen.DREMPELS.size(),
		"bij 10 tickets is de laatste drempel niet gevallen")

	# --- boek() zet de vlaggen die de data verwacht ------------------------
	QuestEngine.start_run(&"daan")
	Gevolgen.boek(&"mg_planning", MinigameResult.make(&"mg_planning",
		GameEnums.Outcome.SUCCESS, 0, {&"gemist": ["jonathan"], &"tijd_over": 3.0}))
	_ok(Session.get_flag(&"gevolg_jonathan_gemist"),
		"Jonathan afkappen zet zijn gevolgvlag niet")
	_ok(not Session.get_flag(&"gevolg_danny_gemist"),
		"Danny krijgt een gevolgvlag zonder afgekapt te zijn")

	Gevolgen.boek(&"mg_user_story", MinigameResult.make(&"mg_user_story",
		GameEnums.Outcome.SUCCESS, 0,
		{&"meegenomen": ["paard", "comicsans", "app", "loyaliteit"],
		 &"weggelaten": ["vergelijker"], &"punten": 17, &"blij": 13}))
	_ok(Session.get_flag(&"gevolg_geen_webshop"),
		"de webshop weglaten levert geen gevolgvlag op — en dat is juist de grap")
	_ok(Session.get_flag(&"gevolg_paard_beloofd"), "het paard beloven wordt niet onthouden")
	_ok(Session.get_flag(&"gevolg_scope_te_groot"),
		"twee zware wensen tellen niet als een te grote scope")
	_ok(int(Gevolgen.getal(&"scope_punten", 0)) == 17,
		"de scope-punten komen niet in Session.gevolgen terecht")

	# Een minigame die een veld teruggeeft dat niet in GETALLEN staat mag het
	# spel niet stilletjes beinvloeden.
	Gevolgen.boek(&"mg_user_story", MinigameResult.make(&"mg_user_story",
		GameEnums.Outcome.SUCCESS, 0, {&"iets_nieuws": 99}))
	_ok(not Session.gevolgen.has(&"iets_nieuws"),
		"een onbekend payload-veld belandt toch in de gevolgen")

	# --- de finale begint met de opgetelde dag ----------------------------
	var slecht := Gevolgen.finale_start()
	for k: StringName in [&"bugs", &"vertrouwen", &"getest", &"scope"]:
		_ok(slecht.has(k), "finale_start() levert geen '%s'" % k)
	_ok(int(slecht[&"bugs"]) >= 1 and int(slecht[&"bugs"]) <= 6,
		"bugs (%s) valt buiten zijn clamp" % slecht[&"bugs"])

	QuestEngine.start_run(&"daan")
	Gevolgen.boek(&"mg_user_story", MinigameResult.make(&"mg_user_story",
		GameEnums.Outcome.SUCCESS, 0,
		{&"meegenomen": ["vergelijker", "bestellen", "paard"], &"punten": 9, &"blij": 9}))
	Gevolgen.boek(&"mg_frontend_fix", MinigameResult.make(&"mg_frontend_fix",
		GameEnums.Outcome.SUCCESS, 0, {&"perfect": true, &"afwijking_totaal": 0}))
	Gevolgen.boek(&"mg_cro", MinigameResult.make(&"mg_cro",
		GameEnums.Outcome.SUCCESS, 0, {&"boven_doel": true, &"conversie": 3.4}))
	var goed := Gevolgen.finale_start()
	# Dit is de hele belofte van de spanningsboog: een zorgvuldige dag begint
	# de oplevering meetbaar makkelijker dan een slordige. Valt dit gelijk, dan
	# hebben de keuzes geen gevolgen meer en is de finale weer een los spelletje.
	_ok(int(goed[&"bugs"]) < int(slecht[&"bugs"]),
		"een zorgvuldige dag levert niet minder bugs op dan een slordige")
	_ok(int(goed[&"vertrouwen"]) > int(slecht[&"vertrouwen"]),
		"een zorgvuldige dag levert niet meer vertrouwen op dan een slordige")

	# --- alleen de finale krijgt de dag mee -------------------------------
	for id: StringName in GameData.ticket_ids():
		var extra := Gevolgen.minigame_config(id)
		var is_finale: bool = GameData.ticket(id).minigame_id == &"mg_deploy"
		_ok(extra.has("start_override") == is_finale,
			"%s krijgt %s een start_override" % [id, "geen" if is_finale else "wel"])

	QuestEngine.start_run(&"daan")


## Alle `gevolg_*`-vlaggen die ergens in een geneste datastructuur in een
## `flags_all` of `flags_none` staan. Recursief, want condities zitten diep:
## boom -> node -> variants -> when, en bij keuzes nog een laag dieper.
func _gevolgvlaggen_in(v: Variant) -> Array[StringName]:
	var uit: Array[StringName] = []
	if v is Dictionary:
		var d := v as Dictionary
		for lijst: String in ["flags_all", "flags_none"]:
			for f: Variant in d.get(lijst, []):
				if String(f).begins_with("gevolg_"):
					uit.append(StringName(f))
		for k: Variant in d.keys():
			uit.append_array(_gevolgvlaggen_in(d[k]))
	elif v is Array:
		for e: Variant in (v as Array):
			uit.append_array(_gevolgvlaggen_in(e))
	return uit


func _test_data_laadt() -> void:
	_kop("data laadt")
	_ok(GameData.load_errors.is_empty(), "GameData meldt: %s" % ", ".join(GameData.load_errors))
	_ok(GameData.character_ids().size() == 7, "verwacht 7 personages, kreeg %d" % GameData.character_ids().size())
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
				# De vrije modus (de urenstaat) heeft bewust geen goed antwoord:
				# elk vak neemt elke kaart, en er zijn juist meer uren dan
				# regels. De eisen hieronder gelden daar dus niet.
				if bool(c.get("vrij", false)):
					_ok(int(c.get("capaciteit", 1)) > 1,
						"%s: vrije modus zonder capaciteit; dan past er een uur per regel" % mid)
					_ok(int(c.get("blok_min", 0)) > 0,
						"%s: vrije modus zonder blok_min; een uurblok is dan nul minuten waard" % mid)
					var uren := (c.get("cards", []) as Array).size() * int(c.get("blok_min", 0))
					_ok(uren == Urenstaat.BUDGET_MIN,
						"%s: de blokken tellen op tot %d minuten, en het budget is %d" % [
							mid, uren, Urenstaat.BUDGET_MIN])
					continue
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
			"oplevering":
				# Deze tak heette "deploy" toen de finale nog de DeployConsole was.
				# Het contentblok kreeg type "oplevering" en de tak niet, waardoor
				# elke controle hieronder stilletjes oversloeg: geen foutmelding,
				# geen bewaking, en per personage geen garantie meer dat zijn
				# finale bestaat. Een test die niet loopt is erger dan geen test.
				var varianten := c.get("varianten", {}) as Dictionary
				for cid: StringName in GameData.character_ids():
					_ok(varianten.has(String(cid)), "mg_deploy: geen variant voor '%s'" % cid)
				for k: Variant in varianten.keys():
					var v := varianten[k] as Dictionary
					_ok(String(v.get("foutcode", "")) != "", "mg_deploy/%s: geen foutcode" % k)
					_ok(not (v.get("config", {}) as Dictionary).is_empty(),
						"mg_deploy/%s: lege config" % k)

				# De toestand waar de finale op rekent. `Gevolgen.finale_start()`
				# levert exact deze vier sleutels; loopt dat uit elkaar, dan begint
				# de oplevering stil met de standaardwaarden en heeft je hele dag
				# geen gevolgen meer.
				var start := c.get("start", {}) as Dictionary
				for k2: String in ["bugs", "vertrouwen", "getest", "scope"]:
					_ok(start.has(k2), "mg_deploy: start mist '%s'" % k2)
					_ok(Gevolgen.finale_start().has(StringName(k2)),
						"Gevolgen.finale_start() mist '%s', dat de data wel verwacht" % k2)
				_ok(int(c.get("acties", 0)) > 0, "mg_deploy: geen handelingen")

				var keuzes := c.get("keuzes", []) as Array
				_ok(keuzes.size() >= 4, "mg_deploy: te weinig keuzes voor acht handelingen")
				var goedkoopste := 99
				for raw: Variant in keuzes:
					var kz := raw as Dictionary
					_ok(String(kz.get("id", "")) != "", "mg_deploy: keuze zonder id")
					_ok(String(kz.get("label", "")) != "", "mg_deploy: keuze zonder label")
					_ok(String(kz.get("regel", "")) != "",
						"mg_deploy/%s: geen regel, dus een handeling zonder reactie" % kz.get("id", ""))
					goedkoopste = mini(goedkoopste, int(kz.get("kost", 0)))
					for ek: Variant in (kz.get("effect", {}) as Dictionary):
						_ok(String(ek) in ["bugs", "vertrouwen", "getest", "scope"],
							"mg_deploy/%s: effect op onbekende waarde '%s'" % [kz.get("id", ""), ek])
				_ok(goedkoopste <= int(c.get("acties", 0)),
					"mg_deploy: zelfs de goedkoopste keuze past niet in het budget")

				# Er moet altijd een uitkomst zijn, ook bij de slechtst denkbare
				# stand. Zonder een drempel op 0 valt de finale door zonder tekst.
				var laagste := 999
				for raw2: Variant in (c.get("uitkomsten", []) as Array):
					var u := raw2 as Dictionary
					_ok(String(u.get("titel", "")) != "", "mg_deploy: uitkomst zonder titel")
					_ok(String(u.get("tekst", "")) != "", "mg_deploy: uitkomst zonder tekst")
					# Geen game over: elke uitkomst is een oplevering.
					_ok(String(u.get("titel", "")) == "OPGELEVERD",
						"mg_deploy: uitkomst '%s' heet niet OPGELEVERD" % u.get("titel", ""))
					laagste = mini(laagste, int(u.get("min", 0)))
				_ok(laagste == 0, "mg_deploy: geen uitkomst met min 0; een slechte dag valt door")

				for raw3: Variant in (c.get("gebeurtenissen", []) as Array):
					var g := raw3 as Dictionary
					_ok(String(g.get("tekst", "")) != "", "mg_deploy: gebeurtenis zonder tekst")
					_ok(int(g.get("na", -1)) >= 0 and int(g.get("na", 0)) < int(c.get("acties", 0)),
						"mg_deploy: gebeurtenis op handeling %s valt buiten het budget" % g.get("na", "?"))
			"scope":
				var wensen := c.get("wensen", []) as Array
				_ok(wensen.size() >= 5, "%s: te weinig wensen om te kiezen" % mid)
				var punten_totaal := 0
				var blij_totaal := 0
				for raw: Variant in wensen:
					var w := raw as Dictionary
					_ok(String(w.get("id", "")) != "", "%s: wens zonder id" % mid)
					_ok(String(w.get("tekst", "")) != "", "%s: wens zonder tekst" % mid)
					punten_totaal += int(w.get("punten", 0))
					blij_totaal += int(w.get("blij", 0))
				# Alles meenemen moet te duur zijn, anders is er geen keuze te maken.
				_ok(punten_totaal > int(c.get("capaciteit", 0)),
					"%s: alle wensen passen samen in de sprint, dus er valt niets te kiezen" % mid)
				_ok(blij_totaal >= int(c.get("tevreden_min", 0)),
					"%s: zelfs alle wensen halen tevreden_min niet" % mid)
				# En er moet minstens één combinatie zijn die binnen de capaciteit
				# genoeg blij oplevert. Volledige zoektocht: negen wensen is 512.
				var haalbaar := false
				for masker: int in (1 << wensen.size()):
					var pt := 0
					var bl := 0
					for i: int in wensen.size():
						if masker & (1 << i) != 0:
							pt += int((wensen[i] as Dictionary).get("punten", 0))
							bl += int((wensen[i] as Dictionary).get("blij", 0))
					if pt <= int(c.get("capaciteit", 0)) and bl >= int(c.get("tevreden_min", 0)):
						haalbaar = true
						break
				_ok(haalbaar, "%s: geen enkele combinatie haalt de drempel binnen de capaciteit" % mid)
			"standup":
				var sprekers := c.get("sprekers", []) as Array
				_ok(sprekers.size() >= 4, "%s: te weinig sprekers" % mid)
				var spreektijd := 0.0
				var belangrijk := 0
				for raw: Variant in sprekers:
					var sp := raw as Dictionary
					_ok(String(sp.get("naam", "")) != "", "%s: spreker zonder naam" % mid)
					_ok(not (sp.get("regels", []) as Array).is_empty(),
						"%s: %s zegt niets" % [mid, sp.get("naam", "?")])
					spreektijd += float(sp.get("duur", 0.0))
					if bool(sp.get("belangrijk", false)):
						belangrijk += 1
				# De grap staat of valt hiermee: wie niets doet moet verliezen.
				#
				# Met een marge en niet met `>=`. Dit stond op gelijk (42 tegen 42)
				# en dat is geen "verliezen" maar een muntworp: de klok raakt nul
				# in hetzelfde frame waarin de laatste spreker klaar is, en welke
				# van die twee checks eerst draait bepaalt de uitslag. De uitkomst
				# van de niets-doen-route hoort niet van een float-vergelijking af
				# te hangen.
				var marge := spreektijd - float(c.get("tijd", 0.0))
				_ok(marge >= 2.0,
					"%s: de spreektijd (%.0fs) loopt maar %.1fs over het budget (%.0fs) heen; niets doen moet met marge verliezen" % [
						mid, spreektijd, marge, c.get("tijd", 0.0)])
				_ok(belangrijk >= 1,
					"%s: geen enkele spreker is belangrijk, dus afkappen heeft geen gevolgen" % mid)
				_ok(int(c.get("ingrepen", 0)) > 0 and int(c.get("ingrepen", 0)) < sprekers.size(),
					"%s: met %s ingrepen op %d sprekers valt er niets af te wegen" % [
						mid, c.get("ingrepen", 0), sprekers.size()])
			"uitlijnen":
				var elementen := c.get("elementen", []) as Array
				_ok(elementen.size() >= 3, "%s: te weinig elementen" % mid)
				for raw: Variant in elementen:
					var el := raw as Dictionary
					_ok(String(el.get("label", "")) != "", "%s: element zonder label" % mid)
					var afw := el.get("afwijking", []) as Array
					_ok(afw.size() == 2, "%s/%s: afwijking is geen paar" % [mid, el.get("id", "?")])
					_ok(int(afw[0]) != 0 or int(afw[1]) != 0,
						"%s/%s: staat al goed, dus er is niets te doen" % [mid, el.get("id", "?")])
				_ok(int(c.get("tolerantie", 0)) > 0, "%s: tolerantie 0 is met een raster onhaalbaar" % mid)
				_ok(int(c.get("raster", 0)) > int(c.get("tolerantie", 0)),
					"%s: raster kleiner dan de tolerantie maakt de puzzel triviaal" % mid)
			"abtest":
				var rondes := c.get("rondes", []) as Array
				_ok(rondes.size() >= 2, "%s: te weinig rondes voor een feedbacklus" % mid)
				var beste := 0.0
				for raw: Variant in rondes:
					var r := raw as Dictionary
					_ok(String(r.get("vraag", "")) != "", "%s: ronde zonder vraag" % mid)
					var varianten2 := r.get("varianten", []) as Array
					_ok(varianten2.size() >= 2, "%s: ronde met minder dan twee varianten" % mid)
					var top := -99.0
					var slecht := false
					for raw2: Variant in varianten2:
						var vr := raw2 as Dictionary
						_ok(String(vr.get("label", "")) != "", "%s: variant zonder label" % mid)
						_ok(String(vr.get("regel", "")) != "",
							"%s: variant zonder regel, dus een meting zonder uitleg" % mid)
						top = maxf(top, float(vr.get("effect", 0.0)))
						if float(vr.get("effect", 0.0)) < 0.0:
							slecht = true
					beste += top
					# Zonder een slechte optie per ronde is elke keuze goed en
					# heeft de feedbacklus niets te melden.
					_ok(slecht, "%s: ronde zonder enige negatieve variant" % mid)
				_ok(float(c.get("basis", 0.0)) + beste >= float(c.get("doel", 0.0)),
					"%s: het doel is onhaalbaar (basis %.1f + best %.1f < doel %.1f)" % [
						mid, c.get("basis", 0.0), beste, c.get("doel", 0.0)])
			"pijplijn":
				var stages := c.get("stages", []) as Array
				_ok(stages.size() >= 3, "%s: te weinig stages" % mid)
				for raw: Variant in stages:
					var st := raw as Dictionary
					_ok(String(st.get("label", "")) != "", "%s: stage zonder label" % mid)
					_ok(int(st.get("capaciteit", 0)) > 0, "%s/%s: capaciteit 0" % [mid, st.get("id", "?")])
				_ok((c.get("job_labels", []) as Array).size() >= int(c.get("jobs", 0)),
					"%s: minder labels dan clips, dus een clip zonder naam" % mid)
				_ok(int(c.get("doel", 0)) > 0 and int(c.get("doel", 0)) <= int(c.get("jobs", 0)),
					"%s: doel van %s is niet te halen met %s clips" % [
						mid, c.get("doel", 0), c.get("jobs", 0)])
				_ok(int(c.get("credits", 0)) > 0, "%s: geen credits, dus geen druk" % mid)

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
	# Dirk is nooit boos. Zijn hele register zit in deze wendingen: een exact
	# getal, en dan bedankt hij je voor iets wat je nog niet gedaan hebt.
	"dirk":      ["even een klein seintje", "als er nog wat mist", "alvast bedankt", "mijn collega dennis", "geen probleem hoor"],
}


## Alleen Danny en Bastiaan schrijven in kleine letters; zo staat het in de
## stembijbel (docs/dialogue-content.md). Bij de rest is een kleine letter aan
## het begin drift en geen stem.
const KLEINE_LETTER_STEMMEN: Array[String] = ["danny", "bastiaan"]

## Regels die wél met een kleine letter mogen beginnen: de tic zelf.
const KLEINE_OPENERS := {
	"victor": ["manmanman", "godver", "hahaha"],
	"koen":   ["piepelienies", "vgm", "lekker ouwe", "psst"],
	"dennis": ["oke", "thanks is gedaan"],
}

## Tics die maar bij één personage horen. Staat er een bij iemand anders, dan is
## die regel van een ander overgenomen — precies wat er bij t08 en t09 gebeurde.
## O-M-Z staat hier bewust niet in: dat is gedeeld bezit van vier personages.
const EXCLUSIEVE_TICS := {
	"jonathan": ["naartoe kijken", "ben benieuwd"],
	"danny":    ["joejoe", "psies", "biem", "olijfolie"],
	"victor":   ["manmanman", "godver", "hahaha"],
	"willem":   ["absoluta", "looff", "heeeel"],
	"koen":     ["lekker ouwe", "piepelienies", "pareltje", "vgm"],
	"daan":     ["puur uit interesse"],
	"bastiaan": ["hiya", ",,"],
	"dennis":   ["-_-", "thanks is gedaan"],
	"dirk":     ["even een klein seintje", "als er nog wat mist", "alvast bedankt"],
}

## Zoveel eigen reacties heeft elk personage minstens. De vijf oorspronkelijke
## zaten al tussen de 12 en 18; Koen en Bastiaan op 0 was het gat.
const SPELERSVARIANTEN_MIN := 12


## Kleine letter aan het begin is drift, tenzij het personage zo schrijft of de
## regel op zijn eigen tic opent. Begint een regel niet met een letter (Dennis
## opent op "-_-"), dan valt hij er vanzelf buiten.
static func _zinsbegin_klopt(wie: String, tekst: String) -> bool:
	if wie in KLEINE_LETTER_STEMMEN or tekst == "":
		return true
	var eerste := tekst[0]
	if eerste.to_lower() == eerste.to_upper():
		return true   # geen letter
	if eerste == eerste.to_upper():
		return true
	for o: Variant in (KLEINE_OPENERS.get(wie, []) as Array):
		if tekst.to_lower().begins_with(String(o)):
			return true
	return false


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

	# --- De spelerspool, die hierboven onzichtbaar is -----------------------
	#
	# _verzamel() bucket op `speaker`, en elke spelersvariant heeft speaker
	# "speler". Alle regels die je hoort als je *als* dat personage speelt
	# vielen daardoor buiten elke controle. _alle_regels() rekent een variant
	# met when.character toe aan dat personage, ongeacht wie hem uitspreekt.
	var per_personage: Dictionary = {}
	for r: Dictionary in _alle_regels():
		var wie := String(r["wie"])
		if wie == "" or wie == "speler":
			continue
		if not per_personage.has(wie):
			per_personage[wie] = [] as Array[Dictionary]
		(per_personage[wie] as Array).append(r)

	for wie: Variant in per_personage.keys():
		var naam := String(wie)
		for r: Variant in (per_personage[naam] as Array):
			var tekst := String((r as Dictionary)["tekst"])
			var bron := String((r as Dictionary)["bron"])
			_ok(_zinsbegin_klopt(naam, tekst),
				"%s — %s: begint met een kleine letter; dat is Danny's register, niet dat van %s"
					% [naam, bron, naam])
			for ander: Variant in EXCLUSIEVE_TICS.keys():
				if String(ander) == naam:
					continue
				for tic: Variant in (EXCLUSIEVE_TICS[ander] as Array):
					_ok(not (String(tic) in tekst.to_lower()),
						"%s — %s: gebruikt \"%s\", en dat is de tic van %s"
							% [naam, bron, tic, ander])

	# Speel je als iemand, dan hoor je jezelf. Bij Koen en Bastiaan was die pool
	# leeg: hun twee tickets waren nog op Victor en Jonathan gegate, dus wie hen
	# koos hoorde de hele dag iemand anders.
	for cid: StringName in GameData.character_ids():
		var eigen := 0
		for r: Variant in (per_personage.get(String(cid), []) as Array):
			if bool((r as Dictionary)["gegate"]):
				eigen += 1
		_ok(eigen >= SPELERSVARIANTEN_MIN,
			"%s heeft %d spelersvarianten, verwacht minstens %d; speel je als hem dan hoor je iemand anders"
				% [cid, eigen, SPELERSVARIANTEN_MIN])

	# Bastiaans dubbele komma is mechanisch te testen: geen enkele losse komma.
	# Ook in zijn spelersvarianten: die staan op speaker "speler" en vielen
	# daardoor buiten de bak hieronder, terwijl hij ze wel zelf uitspreekt.
	for r: Variant in (per_personage.get("bastiaan", []) as Array):
		var d := r as Dictionary
		if String(d["bron"]).begins_with("bureau_"):
			continue   # omschrijving, geen tekst uit zijn mond
		_ok(_losse_kommas(String(d["tekst"])) == 0,
			"bastiaan — %s: losse komma; bij hem zijn het er altijd twee" % d["bron"])

	var bas := String(per_spreker.get("bastiaan", ""))
	if bas != "":
		var los := _losse_kommas(bas)
		_ok(los == 0, "Bastiaan gebruikt %d losse komma('s); bij hem zijn het er altijd twee" % los)


static func _losse_kommas(tekst: String) -> int:
	var los := 0
	for i: int in tekst.length():
		if tekst[i] != ",":
			continue
		var vorige := i > 0 and tekst[i - 1] == ","
		var volgende := i + 1 < tekst.length() and tekst[i + 1] == ","
		if not vorige and not volgende:
			los += 1
	return los


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


## Traits moeten iets doen, en nooit iets slechts. Zonder deze test kan een
## voordeel stilletjes een nadeel worden bij de volgende contentwijziging.
func _test_traits() -> void:
	_kop("traits als voordeel")
	var gezien := 0
	for cid: Variant in GameData.character_ids():
		QuestEngine.start_run(StringName(cid))
		for tid: StringName in GameData.ticket_ids():
			var t: TicketDef = GameData.ticket(tid)
			if t.minigame_id == &"":
				continue
			# De opgave zoals de minigame hem zonder trait zou lezen. Niet
			# `t.minigame_config`: dat veld is overal leeg en juist daardoor
			# vergeleek deze test jarenlang twee lege dictionaries met elkaar.
			var basis: Dictionary = MinigameContent.get_config(t.minigame_id)
			var na: Dictionary = TraitModifier.pas_toe(t)
			if not QuestEngine.is_own_expertise(tid):
				_ok(na.is_empty(),
					"%s/%s: buiten je vakgebied mag de opgave niet veranderen" % [cid, t.code])
				continue
			gezien += 1
			var soort := String(basis.get("type", ""))

			# Dekking. Dit is de test die de halve migratie had moeten vangen:
			# zes minigames kregen nieuwe `type`-namen en de trait-tabel kende
			# ze niet, dus in vijf van de tien tickets deed je vakgebied niets.
			# Een nieuw type moet nu óf een voordeel hebben óf expliciet in
			# GEEN_VOORDEEL staan met de reden erbij.
			_ok(TraitModifier.VOORDEEL.has(soort) or TraitModifier.GEEN_VOORDEEL.has(soort),
				"%s/%s: mechaniek '%s' staat niet in TraitModifier.VOORDEEL en niet in GEEN_VOORDEEL" % [
					cid, t.code, soort])

			# En het voordeel moet echt iets doen. Een sleutel zetten die de
			# minigame nooit uitleest is niet te zien aan de config, maar een
			# config die identiek terugkomt is dat wel.
			if TraitModifier.VOORDEEL.has(soort):
				_ok(not na.is_empty() and na.hash() != basis.hash(),
					"%s/%s: '%s' belooft een voordeel maar levert dezelfde opgave" % [
						cid, t.code, soort])
			else:
				_ok(na.is_empty(),
					"%s/%s: '%s' hoort geen voordeel te geven maar verandert de opgave" % [
						cid, t.code, soort])
				continue

			# nooit strenger: minder kaarten, meer fouten toegestaan, meer tijd
			_ok(int(na.get("max_fouten", 99)) >= int(basis.get("max_fouten", 0)),
				"%s/%s: max_fouten mag niet omlaag" % [cid, t.code])
			_ok((na.get("cards", []) as Array).size() <= (basis.get("cards", []) as Array).size(),
				"%s/%s: er mogen geen kaarten bijkomen" % [cid, t.code])
			_ok(float(na.get("duur", 0.0)) >= float(basis.get("duur", 0.0)),
				"%s/%s: de tijd mag niet korter worden" % [cid, t.code])
			_ok(int(na.get("drempel", 0)) <= int(basis.get("drempel", 99)),
				"%s/%s: de drempel mag niet omhoog" % [cid, t.code])
			# het slotboard moet oplosbaar blijven: elk vak houdt een kaart
			if String(na.get("type", "")) == "slotboard":
				var ids := {}
				for raw: Variant in (na.get("cards", []) as Array):
					ids[String((raw as Dictionary).get("id", ""))] = true
				for raw2: Variant in (na.get("slots", []) as Array):
					var kan := false
					for a: Variant in ((raw2 as Dictionary).get("accepts", []) as Array):
						if ids.has(String(a)):
							kan = true
					_ok(kan, "%s/%s: een vak heeft geen passende kaart meer" % [cid, t.code])
			# Vijf mechanieken kregen hun voordeel in eigen getallen; die mogen
			# geen kant op die de opgave strenger maakt.
			_ok(int(na.get("capaciteit", 0)) >= int(basis.get("capaciteit", 0)),
				"%s/%s: de sprintruimte mag niet krimpen" % [cid, t.code])
			_ok(int(na.get("ingrepen", 0)) >= int(basis.get("ingrepen", 0)),
				"%s/%s: er mogen geen ingrepen af" % [cid, t.code])
			_ok(int(na.get("tolerantie", 0)) >= int(basis.get("tolerantie", 0)),
				"%s/%s: de speling mag niet kleiner worden" % [cid, t.code])
			_ok(int(na.get("credits", 0)) >= int(basis.get("credits", 0)),
				"%s/%s: er mogen geen credits af" % [cid, t.code])
			_ok(float(na.get("tijd", 0.0)) >= float(basis.get("tijd", 0.0)),
				"%s/%s: het tijdsbudget mag niet korter worden" % [cid, t.code])

			if TraitModifier.VOORDEEL.has(soort):
				_ok(TraitModifier.voordeel_tekst(t) != "",
					"%s/%s: voordeel zonder uitleg aan de speler" % [cid, t.code])
	_ok(gezien > 0, "geen enkel personage had een eigen minigame")


func _test_urenstaat() -> void:
	_kop("de urenstaat")

	# --- tijdstippen -----------------------------------------------------
	# 9:12 is geen willekeurige starttijd: zo staat het in de intro-dialoog.
	_ok(Urenstaat.formatteer(Urenstaat.START_MIN) == "09:12",
		"de dag begint niet op 09:12, terwijl de intro dat wel zegt")
	_ok(Urenstaat.formatteer(Urenstaat.START_MIN + Urenstaat.BUDGET_MIN) == "17:12",
		"acht uur na 09:12 is niet 17:12")
	_ok(Urenstaat.formatteer(1050) == "17:30", "1050 minuten is niet 17:30")
	# Bewust dóórlopen in plaats van terugvallen: 25:00 leest als een
	# nachtdienst, 01:00 als een nieuwe dag.
	_ok(Urenstaat.formatteer(25 * 60) == "25:00",
		"na middernacht valt de klok terug in plaats van door te lopen")

	# --- duren in Dirks notatie ------------------------------------------
	_ok(Urenstaat.formatteer_duur(45) == "45 min", "45 minuten schrijft hij niet uit")
	# Dirk zegt "er staat 0u geboekt", niet "0 min".
	_ok(Urenstaat.formatteer_duur(0) == "0u", "nul uur leest als minuten")
	_ok(Urenstaat.formatteer_duur(480) == "8u", "een heel aantal uren krijgt minuten mee")
	_ok(Urenstaat.formatteer_duur(570) == "9u30", "9u30 wordt verkeerd geschreven")

	# --- het grootboek ---------------------------------------------------
	_ok(Urenstaat.kosten_voor_ticket(true) < Urenstaat.kosten_voor_ticket(false),
		"je eigen vakgebied moet goedkoper zijn dan een ticket met een collega erbij")

	# --- de invariant: er is altijd meer werk dan uren -------------------
	# Dit is de grap zelf. Als een personage zijn dag binnen de acht uur kan
	# afmaken, klok je om precies 17:00 uit en is er niets meer om over te
	# overwerken.
	for cid: Variant in GameData.character_ids():
		QuestEngine.start_run(StringName(cid))
		var c: CharacterDef = GameData.character(StringName(cid))
		var eigen := 0
		var goedkoopst := 0
		for tid: StringName in GameData.ticket_ids():
			if QuestEngine.is_own_expertise(tid):
				eigen += 1
				goedkoopst += Urenstaat.kosten_voor_ticket(true)
			else:
				# buiten je vakgebied betaal je ook de zoektijd
				goedkoopst += Urenstaat.kosten_voor_ticket(false) + Urenstaat.OPHALEN_MIN
		var marge := goedkoopst - Urenstaat.BUDGET_MIN
		_ok(marge > 0,
			("%s kan zijn dag in %s afmaken, binnen het budget van %s. " +
			"De urenstaat hoort altijd over te lopen — zie de invariant in " +
			"docs/GAME_DESIGN.md.") % [
				c.name, Urenstaat.formatteer_duur(goedkoopst),
				Urenstaat.formatteer_duur(Urenstaat.BUDGET_MIN)])
		# De marge is dun: een eigen ticket erbij is ~30 minuten. Zakt hij onder
		# een half uur, dan is de volgende herbalancering van ticket-eigendom
		# genoeg om de grap stil te slopen.
		_ok(marge >= Urenstaat.EIGEN_MIN,
			("%s houdt maar %s marge op de acht uur. Onder %s is een enkele " +
			"verschuiving van ticket-eigendom genoeg om de overwerkgrap te " +
			"laten verdwijnen.") % [
				c.name, Urenstaat.formatteer_duur(maxi(0, marge)),
				Urenstaat.formatteer_duur(Urenstaat.EIGEN_MIN)])
		print("   %-9s goedkoopste dag %s, %d eigen, marge %s" % [
			c.name, Urenstaat.formatteer_duur(goedkoopst), eigen,
			Urenstaat.formatteer_duur(maxi(0, marge))])

	# --- de harde regel: tijd maakt het spel nooit onwinbaar -------------
	QuestEngine.start_run(&"daan")
	Session.book_time(10000, &"test")
	_ok(Urenstaat.is_overwerk(), "10000 minuten is geen overwerk?")
	for tid: StringName in GameData.ticket_ids():
		var t: TicketDef = GameData.ticket(tid)
		QuestEngine.unlock(tid)
		QuestEngine.mark_helper_present(tid)
		for raw: Variant in (t.requirements.get("has_item", []) as Array):
			Session.add_item(StringName(raw))
		_ok(QuestEngine.requirements_met(tid),
			"%s is niet meer op te lossen na 10000 geboekte minuten; tijd mag nooit blokkeren" % t.code)

	# --- state: resetten en bewaren --------------------------------------
	QuestEngine.start_run(&"daan")
	_ok(Session.worked_minutes == 0, "een nieuwe speelbeurt begint niet op nul minuten")
	Session.book_time(95, &"test")
	_ok(Session.worked_minutes == 95, "book_time telt niet op")
	Session.book_time(0, &"test")
	_ok(Session.worked_minutes == 95, "een boeking van nul minuten verandert het totaal")
	var heen := Session.to_dict()
	QuestEngine.start_run(&"daan")
	Session.from_dict(heen)
	_ok(Session.worked_minutes == 95, "de geboekte minuten overleven een save/load niet")
	_ok(int(Session.to_dict().get("worked_minutes", -1)) == 95,
		"worked_minutes staat niet in de save")

	# --- de conditiesleutel ----------------------------------------------
	_ok(Conditions.unknown_keys({"overwerk": true}).is_empty(),
		"'overwerk' is geen bekende conditiesleutel")
	QuestEngine.start_run(&"daan")
	_ok(Conditions.check({}), "een lege conditie moet binnen je budget waar zijn")
	_ok(not Conditions.check({"overwerk": true}), "overwerk is waar terwijl je nog uren hebt")
	_ok(Conditions.check({"overwerk": false}), "overwerk:false is onwaar terwijl je nog uren hebt")
	Session.book_time(Urenstaat.BUDGET_MIN, &"test")
	# De belangrijkste van de vier: een lege conditie mag NIET stilletjes
	# "het is geen overwerk" gaan beweren, want dan klapt na 17:00 elke
	# fallbackvariant in de game om.
	_ok(Conditions.check({}), "een lege conditie wordt onwaar in overwerk")
	_ok(Conditions.check({"overwerk": true}), "overwerk is onwaar terwijl je budget op is")
	_ok(not Conditions.check({"overwerk": false}), "overwerk:false is waar terwijl je budget op is")


func _test_questketen_alle_personages() -> void:
	_kop("questketen voor alle personages")
	for cid: StringName in GameData.character_ids():
		var naam := GameData.character(cid).name
		QuestEngine.start_run(cid)

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


## Alles staat tegelijk open, dus de belofte is: elk ticket kan het eerste zijn
## dat je doet. Dat is niet af te leiden uit "de keten loopt door" — een fout in
## available_when zou daar niet uit blijken maar hier wel.
func _test_vrije_volgorde() -> void:
	_kop("vrije volgorde")

	QuestEngine.start_run(&"daan")
	_ok(QuestEngine.open_tickets().size() == 9,
		"bij de start staan er %d open, verwacht 9" % QuestEngine.open_tickets().size())
	_ok(Session.ticket_state(&"t10") == GameEnums.TicketState.LOCKED,
		"t10 hoort dicht te zitten tot 9/10")
	_ok(Session.discovered.is_empty(), "een verse sessie heeft al tickets gevonden")

	# Elk van de negen als allereerste ticket van de dag.
	for eerste: StringName in GameData.ticket_ids():
		if eerste == &"t10":
			continue
		QuestEngine.start_run(&"daan")
		var t: TicketDef = GameData.ticket(eerste)

		_ok(Session.is_available(eerste), "%s kan niet als eerste" % t.code)
		QuestEngine.activate(eerste)
		if not QuestEngine.is_own_expertise(eerste):
			QuestEngine.mark_helper_present(eerste)
		for item: Variant in (t.requirements.get("has_item", []) as Array):
			Session.add_item(StringName(item))
		_ok(QuestEngine.requirements_met(eerste),
			"%s is als eerste niet oplosbaar" % t.code)
		QuestEngine.complete(eerste, MinigameResult.make(t.minigame_id, GameEnums.Outcome.SUCCESS))
		_ok(Session.is_done(eerste), "%s werd niet afgerond als eerste" % t.code)
		_ok(Session.done_count() == 1,
			"%s als eerste zette %d tickets klaar" % [t.code, Session.done_count()])

	# De finale blijft de finale.
	QuestEngine.start_run(&"daan")
	Session.add_item(&"deploysleutel")
	_ok(not Session.is_available(&"t10"), "t10 is meteen te doen; dan is 10/10 geen finale")
	for id: StringName in GameData.ticket_ids():
		if id == &"t10":
			continue
		var t2: TicketDef = GameData.ticket(id)
		QuestEngine.complete(id, MinigameResult.make(t2.minigame_id, GameEnums.Outcome.SUCCESS))
	_ok(Session.is_available(&"t10"), "t10 gaat niet open bij 9/10")


## Het scrumbord in de gang draagt er twee. Zonder een resolver die dat ziet is
## het tweede ticket onbereikbaar zodra beide openstaan.
func _test_gedeelde_ankers() -> void:
	_kop("gedeelde ankers")
	QuestEngine.start_run(&"daan")

	var ankers: Dictionary = {}
	for id: StringName in GameData.ticket_ids():
		var t: TicketDef = GameData.ticket(id)
		if t == null:
			continue
		ankers[t.anchor] = int(ankers.get(t.anchor, 0)) + 1

	var gedeeld := 0
	for anker: Variant in ankers.keys():
		var wid := StringName(anker)
		var hier := QuestEngine.tickets_at_anchor(wid)
		if int(ankers[anker]) <= 1:
			continue
		gedeeld += 1
		_ok(hier.size() >= 2,
			"anker '%s' draagt %d tickets maar levert er %d op" % [wid, ankers[anker], hier.size()])
		# een pin bepaalt welke van de twee je krijgt
		for t: TicketDef in hier:
			Session.pin(t.id)
			var gekozen := QuestEngine.preferred_at_anchor(wid)
			_ok(gekozen != null and gekozen.id == t.id,
				"pin op %s wint niet op anker '%s'" % [t.code, wid])
		Session.unpin()
	_ok(gedeeld >= 1, "geen enkel anker draagt meer dan één ticket — test is zinloos geworden")


## Verkennen moet werk opleveren, en elk ticket moet in precies één ruimte
## gevonden kunnen worden. Anders is er een ticket dat je nooit tegenkomt.
func _test_vinden() -> void:
	_kop("tickets vinden")
	QuestEngine.start_run(&"daan")

	var zones: Array[StringName] = []
	for id: StringName in GameData.ticket_ids():
		var z: StringName = GameData.ticket(id).zone
		if z != &"" and not (z in zones):
			zones.append(z)

	for z: StringName in zones:
		var nieuw := QuestEngine.discover_in_zone(z)
		for t: TicketDef in nieuw:
			_ok(t.zone == z, "%s werd gevonden in de verkeerde ruimte" % t.code)
		# tweede keer binnenlopen levert niets nieuws op
		_ok(QuestEngine.discover_in_zone(z).is_empty(),
			"ruimte '%s' levert bij herhaling opnieuw tickets op" % z)

	_ok(QuestEngine.undiscovered_count() == 0,
		"%d ticket(s) liggen in geen enkele ruimte" % QuestEngine.undiscovered_count())
	_ok(QuestEngine.inventory_tickets().size() == 9,
		"na alle ruimtes zitten er %d in je inventaris, verwacht 9"
			% QuestEngine.inventory_tickets().size())

	# de doelregel volgt je keuze
	Session.pin(&"t07")
	var doel := QuestEngine.next_hint_ticket()
	_ok(doel != null and doel.id == &"t07", "de doelregel volgt de gekozen ticket niet")
	QuestEngine.complete(&"t07", MinigameResult.make(&"mg_muziek", GameEnums.Outcome.SUCCESS))
	_ok(Session.pinned_ticket == &"", "de keuze blijft hangen op een opgelost ticket")


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


## Elke startroute moet de tickets openzetten. Deze test bestaat omdat de
## karakterselectie ooit alleen `Session.start_new()` deed: dan bleef elk ticket
## LOCKED, zei elk object "hier is nu niets te doen", startte er nooit een
## minigame en meldde de hint dat alles al opgelost was. De logica-tests
## hierboven merkten daar niets van, want die riepen het paar zelf netjes aan.
##
## Vandaar dat dit de bronbestanden leest: de fout zat niet in een functie maar
## in een aanroep die ontbrak.
func _test_startroutes() -> void:
	_kop("startroutes")

	QuestEngine.start_run(&"daan")
	_ok(QuestEngine.open_tickets().size() == 9,
		"start_run laat %d tickets open, verwacht 9" % QuestEngine.open_tickets().size())

	for pad: String in _gd_bestanden("res://scripts") + _gd_bestanden("res://autoload"):
		if pad.ends_with("/quest_engine.gd") or pad.ends_with("/session.gd") \
				or pad.ends_with("/test_runner.gd"):
			continue
		var src := FileAccess.get_file_as_string(pad)
		_ok(not ("Session.start_new(" in src),
			"%s roept Session.start_new() rechtstreeks aan; gebruik QuestEngine.start_run()" % pad)


func _gd_bestanden(map: String) -> Array[String]:
	var uit: Array[String] = []
	for naam: String in DirAccess.get_directories_at(map):
		uit.append_array(_gd_bestanden("%s/%s" % [map, naam]))
	for naam: String in DirAccess.get_files_at(map):
		if naam.ends_with(".gd"):
			uit.append("%s/%s" % [map, naam])
	return uit


func _objects_by_id() -> Dictionary:
	var out := {}
	for d: Dictionary in _objects():
		out[StringName(d.get("world_id", ""))] = d
	return out


## Het anker is het enige contactpunt met een ticket. Hangt er een visible_when
## op die naar een ander ticket wijst, dan bestaat het object er niet voor de
## speler: de probe slaat het over, E doet niets, er komt geen prompt en geen
## geluid, en de doelwijzer plant zich op een dood object.
##
## Dat was precies de stand van de wachtbank (BBD-203) — het eerste ticket dat
## een nieuwe speler tegenkomt, want het ligt in de spawnzone. Een overblijfsel
## van de oude ketenopzet. Negen van de tien tickets staan nu open vanaf minuut
## één, dus een anker dat op een ander ticket wacht is per definitie fout.
##
## De QA-speelbeurt liep hier nooit tegenaan omdat die de tickets op id-volgorde
## afwerkt: daar is t02 altijd al klaar als t03 aan de beurt is.
func _test_ankers_bereikbaar() -> void:
	_kop("ankers zijn vanaf de start aanspreekbaar")
	var per_id := _objects_by_id()

	for id: StringName in GameData.ticket_ids():
		var t: TicketDef = GameData.ticket(id)
		var obj := per_id.get(t.anchor, {}) as Dictionary
		_ok(not obj.is_empty(), "%s: anker '%s' staat niet in objects.json" % [t.code, t.anchor])
		if obj.is_empty():
			continue
		var vw := obj.get("visible_when", {}) as Dictionary
		_ok(Conditions.unknown_keys(vw).is_empty(),
			"%s: anker '%s' heeft onbekende visible_when-key %s"
				% [t.code, t.anchor, Conditions.unknown_keys(vw)])

	# De echte assert: wat er ook in visible_when staat, elk ticket dat bij de
	# start openstaat moet een object hebben dat je op dat moment kunt
	# aanspreken. Per personage, want een character- of trait-gate zou het voor
	# één personage stukmaken en voor de rest niet.
	for cid: StringName in GameData.character_ids():
		QuestEngine.start_run(cid)
		for t: TicketDef in QuestEngine.open_tickets():
			var vw2 := (per_id.get(t.anchor, {}) as Dictionary).get("visible_when", {}) as Dictionary
			_ok(Conditions.check(vw2),
				"%s/%s: het anker '%s' is bij de start niet aanspreekbaar"
					% [cid, t.code, t.anchor])

	# En het allereerste doel in het bijzonder: daar plant de wijzer zich op.
	QuestEngine.start_run(&"daan")
	var eerste: TicketDef = QuestEngine.next_hint_ticket()
	_ok(eerste != null, "next_hint_ticket() geeft bij de start niets")
	if eerste != null:
		var vw3 := (per_id.get(eerste.anchor, {}) as Dictionary).get("visible_when", {}) as Dictionary
		_ok(Conditions.check(vw3),
			"de eerste doelwijzer staat op '%s', en dat object is niet aanspreekbaar"
				% eerste.anchor)

	# De vier standen van de collega, scene-loos na te lopen.
	QuestEngine.start_run(&"daan")
	_ok(QuestEngine.helper_stand(&"t03") == GameEnums.HelperStand.NODIG,
		"t03 vraagt bij de start niet om Willem")
	_ok(QuestEngine.helper_stand(&"t01") == GameEnums.HelperStand.EIGEN,
		"t01 is Daans eigen vakgebied en zou niemand moeten vragen")
	Session.add_follower(&"npc_willem")
	_ok(QuestEngine.helper_stand(&"t03") == GameEnums.HelperStand.MEE,
		"een meelopende Willem wordt niet gezien")
	Session.remove_follower(&"npc_willem")
	QuestEngine.mark_helper_present(&"t03")
	_ok(QuestEngine.helper_stand(&"t03") == GameEnums.HelperStand.GEWEEST,
		"de vlag bij het object wordt niet gezien")

	# De teksten zelf, want dit was de klacht: de doelregel bleef "Haal Willem"
	# zeggen terwijl Willem achter je aan liep. Hud._wie() en het scrumbord zijn
	# statisch en scene-loos, dus hier na te lopen zonder de wereld te starten.
	var t03: TicketDef = GameData.ticket(&"t03")
	QuestEngine.start_run(&"daan")
	_ok(Hud._wie(t03).begins_with("Haal Willem"),
		"doelregel bij de start: kreeg \"%s\"" % Hud._wie(t03))
	_ok(Hud._eigenaar_suffix(t03.anchor) == " (Willem)",
		"prompt bij de start: kreeg \"%s\"" % Hud._eigenaar_suffix(t03.anchor))

	Session.add_follower(&"npc_willem")
	_ok(Hud._wie(t03) == "Willem loopt mee",
		"doelregel met Willem erbij: kreeg \"%s\"" % Hud._wie(t03))
	_ok(Hud._eigenaar_suffix(t03.anchor) == " (met Willem)",
		"prompt met Willem erbij: kreeg \"%s\"" % Hud._eigenaar_suffix(t03.anchor))
	_ok(Scrumbord._korte_eigenaar(t03) == "loopt mee",
		"briefje met Willem erbij: kreeg \"%s\"" % Scrumbord._korte_eigenaar(t03))
	_ok(Scrumbord._volledige_eigenaar(t03) == "Willem loopt met je mee",
		"detailregel met Willem erbij: kreeg \"%s\"" % Scrumbord._volledige_eigenaar(t03))
	Session.remove_follower(&"npc_willem")

	# En het eigen vakgebied blijft ongemoeid.
	QuestEngine.start_run(&"willem")
	_ok(Hud._wie(t03) == "Jij kunt dit zelf",
		"eigen vakgebied: kreeg \"%s\"" % Hud._wie(t03))
	_ok(Hud._eigenaar_suffix(t03.anchor) == "",
		"eigen vakgebied hoort geen naam achter de prompt te zetten")


## Commit 9da2cf2 maakte Bastiaan en Koen speelbaar en verschoof het
## eigenaarschap van t08 en t09 — de dialoog verhuisde niet mee. De naam en het
## portret in de dialoogbox komen uit het speaker-veld, dus je liep naar
## Bastiaan en kreeg Jonathan te zien.
func _test_ticket_eigenaarschap() -> void:
	_kop("ticket-eigenaarschap")
	var speelbaar := GameData.character_ids()

	for id: StringName in GameData.ticket_ids():
		var t: TicketDef = GameData.ticket(id)
		if t.owner_character == &"":
			continue   # de finale heeft bewust een variant voor iedereen
		for sleutel: Variant in t.dialogue_ids.keys():
			var did := StringName(t.dialogue_ids[sleutel])
			var def: DialogueDef = GameData.dialogue(did)
			if def == null:
				continue
			for nid: Variant in def.nodes.keys():
				var n := def.node(StringName(nid))
				var basis := String(n.get("speaker", ""))
				var regels: Array = [[basis, String(n.get("text", "")), n.get("when", {})]]
				for raw: Variant in n.get("variants", []):
					var v := raw as Dictionary
					regels.append([String(v.get("speaker", basis)),
						String(v.get("text", "")), v.get("when", {})])

				for r: Variant in regels:
					var sp := StringName(String(r[0]))
					var tekst := String(r[1])
					# Niet-speelbare sprekers (klant, dennis, bezorger) mogen
					# overal meedoen; die zijn NpcDefs, geen CharacterDefs.
					_ok(sp == &"" or sp == t.owner_character or not (sp in speelbaar),
						"%s (%s) — %s/%s: '%s' spreekt in het ticket van iemand anders"
							% [t.code, t.owner_character, did, nid, sp])
					for c: Variant in ((r[2] as Dictionary).get("character", []) as Array):
						_ok(StringName(String(c)) == t.owner_character,
							"%s — %s/%s: variant gegate op '%s', maar de eigenaar is '%s'"
								% [t.code, did, nid, c, t.owner_character])
					# De naam in de tekst: dit vangt de fetch-regels die de twee
					# asserts hierboven structureel niet kunnen zien.
					for cid: StringName in speelbaar:
						if cid == t.owner_character:
							continue
						var naam: String = GameData.character(cid).name
						_ok(not (naam in tekst),
							"%s — %s/%s: tekst noemt %s, maar het ticket is van %s"
								% [t.code, did, nid, naam, t.owner_character])


## Twee inside jokes die alleen werken als ze consequent zijn.
##
## O-M-Z: Willem, Danny, Daan en Victor willen omzet verdienen, maar noemen het
## nooit zo. Koen en Bastiaan doen niet mee en mogen het gewoon zeggen.
##
## Absoluta: dat is geen bevestiging maar de verkeerde klantnaam. Willem
## corrigeert zichzelf naar een tweede verkeerde naam en komt er nooit uit. De
## grap is de correctie, dus zonder "Looff" is het weer een bevestiging.
const OMZ_CLUB: Array[String] = ["willem", "danny", "daan", "victor"]


func _test_omz_en_absoluta() -> void:
	_kop("O-M-Z en Absoluta")

	for r: Dictionary in _alle_regels():
		var wie := String(r["wie"])
		var tekst := String(r["tekst"])
		if wie in OMZ_CLUB:
			_ok(not _bevat_woord(tekst.to_lower(), "omzet"),
				"%s — %s: zegt \"omzet\"; die vier noemen het alleen O-M-Z"
					% [wie, String(r["bron"])])
		if wie == "willem" and "absoluta" in tekst.to_lower():
			_ok("looff" in tekst.to_lower(),
				"willem — %s: \"Absoluta\" zonder de correctie is weer een bevestiging"
					% String(r["bron"]))


## Woordgrens, geen substring: "omzetten" is een gewoon werkwoord en mag.
static func _bevat_woord(tekst: String, woord: String) -> bool:
	var i := tekst.find(woord)
	while i >= 0:
		var voor := i == 0 or not _is_letter(tekst[i - 1])
		var na_i := i + woord.length()
		var na := na_i >= tekst.length() or not _is_letter(tekst[na_i])
		if voor and na:
			return true
		i = tekst.find(woord, i + 1)
	return false


static func _is_letter(c: String) -> bool:
	return c.to_lower() != c.to_upper() or c == "\u00eb" or c == "\u00e9"


## Elke dialoogregel met de spreker erbij, en met de spelersvarianten
## toegerekend aan het personage waar ze op gegate zijn. Dat laatste is het gat
## waardoor de stemtest de hele spelerspool niet zag: die regels hebben
## speaker "speler" en vielen dus buiten elke personagebak.
func _alle_regels() -> Array[Dictionary]:
	var uit: Array[Dictionary] = []
	for key: Variant in GameData.dialogues.keys():
		var did := StringName(key)
		var def: DialogueDef = GameData.dialogue(did)
		for nid: Variant in def.nodes.keys():
			var n := def.node(StringName(nid))
			var basis := String(n.get("speaker", ""))
			var bron := "%s/%s" % [did, nid]
			if String(n.get("text", "")) != "":
				uit.append({"wie": _normaliseer(basis), "tekst": String(n.get("text", "")),
					"bron": bron, "gegate": false})
			for raw: Variant in n.get("variants", []):
				var v := raw as Dictionary
				var tekst := String(v.get("text", ""))
				if tekst == "":
					continue
				var sp := _normaliseer(String(v.get("speaker", basis)))
				var gates := ((v.get("when", {}) as Dictionary).get("character", []) as Array)
				if gates.is_empty():
					uit.append({"wie": sp, "tekst": tekst, "bron": bron, "gegate": false})
					continue
				# Een variant op when.character is dat personage als hoofdpersoon,
				# ongeacht of er speaker "speler" boven staat.
				for c: Variant in gates:
					uit.append({"wie": String(c), "tekst": tekst, "bron": bron, "gegate": true})
	return uit


## De collega-NPC's heten npc_<naam>, de losse NPC's gewoon <naam>.
static func _normaliseer(spreker: String) -> String:
	return spreker.trim_prefix("npc_")


## De knoppenbalk rekent zijn hoogte uit een gemeten knophoogte, en de HUD hangt
## zijn onderste regels daar weer boven. Als die maat stil verschuift — een
## ander font, een andere stijlmarge — dan eet de balk zijn eigen ondermarge op
## en zakt de HUD mee, en dat is precies het soort fout dat je op een
## screenshot niet ziet maar op een telefoon wel voelt.
##
## Vandaar een test op het getal zelf: bouw één knop zoals de balk hem bouwt en
## vraag wat hij nodig heeft.
func _test_balkmaat() -> void:
	_kop("maat van de knoppenbalk")

	var houder := Control.new()
	add_child(houder)
	var b := UiKit.button("Onderzoeken", UiKit.FS_BODY)
	b.custom_minimum_size = Vector2(0, UiKit.KNOP_MIN_H)
	houder.add_child(b)
	var nodig := b.get_combined_minimum_size()

	_ok(nodig.y == Besturing.KNOP_HOOGTE,
		"knop in de balk is %d hoog, Besturing.KNOP_HOOGTE zegt %d" % [
			nodig.y, Besturing.KNOP_HOOGTE])
	_ok(nodig.y >= UiKit.KNOP_MIN_H,
		"knop (%d) haalt de duimmaat UiKit.KNOP_MIN_H (%d) niet" % [
			nodig.y, UiKit.KNOP_MIN_H])
	# De balk moet in de onderste 10% van het canvas passen; daarboven begint de
	# wereld waar je nog iets van wil zien.
	_ok(Besturing.BALK_RUIMTE <= 48,
		"de balk vraagt %d px onderaan een canvas van 416" % Besturing.BALK_RUIMTE)
	_ok(Hud.DUIMZONE == Besturing.BALK_RUIMTE,
		"de HUD reserveert %d px en de balk vraagt %d" % [
			Hud.DUIMZONE, Besturing.BALK_RUIMTE])

	houder.queue_free()


## De uitleg staat sinds kort op een eigen scherm vóór character select
## (IntroUitleg.LESSEN, scripts/ui/intro_uitleg.gd) in plaats van als dialoog
## bij het spawnen. Verlies daarvan geeft geen foutmelding: een woord dat
## wegvalt bij een volgende herschrijving is geen parse-fout, het is gewoon
## weer een speler die het niet snapt. Zie ook de 09:12-check in
## _test_urenstaat().
func _test_intro() -> void:
	_kop("introductie")

	var eigen := "\n".join(IntroUitleg.LESSEN)
	for les: String in [
			"Tien tickets", "naar buiten", "verspreid", "ticketbord", "collega"]:
		_ok(eigen.contains(les), "IntroUitleg.LESSEN noemt niet meer: '%s'" % les)

	# De knoppenbalk (Besturing) staat er op elk apparaat; een toetsnaam
	# beschrijft dan iets dat niet overal bestaat.
	for toets: String in ["druk op E", " TAB", " Q "]:
		_ok(not eigen.contains(toets),
			"IntroUitleg.LESSEN noemt een toets ('%s')" % toets)

	# Dezelfde regel gold voor de introductie toen die nog gesproken tekst was,
	# en blijft daarna nuttig als project-brede bewaking op elke andere
	# dialoogboom.
	for gid: Variant in GameData.dialogues.keys():
		var gdef: DialogueDef = GameData.dialogue(StringName(gid))
		var tekst := _alle_tekst(gdef)
		for toets: String in ["druk op E", " TAB", " Q "]:
			_ok(not tekst.contains(toets),
				"dialoog '%s' noemt een toets ('%s')" % [gid, toets])


## Een halve dag heen en terug door de save.
##
## `Session.load_from_disk()` had nul aanroepers terwijl `save_to_disk()` bij elk
## opgelost ticket en bij het naar de achtergrond gaan draait. De save stond dus
## op schijf en niemand las hem: een half uur spelen was op een telefoon
## onherstelbaar weg terwijl het bestand er gewoon lag. Nu het titelscherm hem
## met "Doorgaan" wél leest is die round-trip een contract, en dan hoort er een
## test op te staan die breekt vóór een speler zijn dag kwijt is.
##
## De echte valkuil zit niet in het schrijven maar in wat er stil verdwijnt: een
## sleutel die niet meegaat komt terug als de standaardwaarde, en dat leest als
## "die had ik nog niet gedaan" in plaats van als een fout.
func _test_save_ronde() -> void:
	_kop("save en laden")

	# Deze test schrijft naar het echte savepad. Wat er stond gaat er straks weer
	# terug: een testrun hoort geen speelbeurt van iemand over te schrijven.
	var had_save := FileAccess.file_exists(Session.SAVE_PATH)
	var oude_save := FileAccess.get_file_as_string(Session.SAVE_PATH) if had_save else ""

	# --- een halve run opbouwen -------------------------------------------
	QuestEngine.start_run(&"daan")
	var gedaan: Array[StringName] = []
	for tid: StringName in GameData.ticket_ids():
		if gedaan.size() >= 5:
			break
		var t: TicketDef = GameData.ticket(tid)
		QuestEngine.activate(tid)
		if not QuestEngine.is_own_expertise(tid):
			QuestEngine.mark_helper_present(tid)
		for item: Variant in (t.requirements.get("has_item", []) as Array):
			Session.add_item(StringName(item))
		QuestEngine.complete(tid, MinigameResult.make(t.minigame_id, GameEnums.Outcome.SUCCESS))
		gedaan.append(tid)
	_ok(gedaan.size() == 5, "de halve run haalt maar %d tickets" % gedaan.size())

	# En de rest van wat een speelbeurt achterlaat: losse vlaggen, spullen,
	# tellers, een keuze, geboekte uren en de getallen uit Gevolgen.
	Session.set_flag(&"save_test_vlag", true)
	Session.add_item(&"koffie", 3)
	Session.add_counter(&"save_test_teller", 2)
	Session.pin(&"t07")
	Session.book_hours(240)
	Gevolgen.boek(&"mg_user_story", MinigameResult.make(&"mg_user_story",
		GameEnums.Outcome.SUCCESS, 0, {&"punten": 17, &"blij": 13}))
	# Bewust runtime-only; zie de assert verderop.
	Session.add_follower(&"npc_willem")

	var verwacht_min := Session.worked_minutes
	var verwacht_gevonden := Session.discovered.size()
	_ok(verwacht_min > 0, "een halve run boekt geen enkele minuut")

	# --- het formaat: standen als naam, niet als getal ---------------------
	var heen := Session.to_dict()
	var rauwe_standen := heen.get("ticket_states", {}) as Dictionary
	_ok(String(rauwe_standen.get(String(gedaan[0]), "")) == "DONE",
		"een opgelost ticket staat niet als \"DONE\" in de save, maar als %s"
			% rauwe_standen.get(String(gedaan[0]), "<niets>"))
	_ok(String(rauwe_standen.get("t10", "")) == "LOCKED",
		"t10 staat niet als \"LOCKED\" in de save")

	# --- round-trip in het geheugen ---------------------------------------
	QuestEngine.start_run(&"victor")   # alles leeg, en expres een ánder personage
	Session.from_dict(heen)
	_controleer_halve_run("from_dict", gedaan, verwacht_min, verwacht_gevonden)

	# --- round-trip over de schijf ----------------------------------------
	Session.save_to_disk()
	QuestEngine.start_run(&"victor")
	_ok(Session.has_saved_run(), "has_saved_run() ziet de zojuist bewaarde run niet")
	_ok(Session.load_from_disk(), "load_from_disk() kon de save niet lezen")
	_controleer_halve_run("load_from_disk", gedaan, verwacht_min, verwacht_gevonden)

	# --- de collega's blijven bewust thuis ---------------------------------
	# Niet vergeten maar weggelaten: na het laden staat iedereen weer op zijn
	# post, dus een bewaarde lijst zou beweren dat Willem achter je aan loopt
	# terwijl hij aan zijn bureau zit. De vlag `helper_bij_<ticket>` overleeft
	# wél, zodat werk waar je hem al voor had opgehaald oplosbaar blijft.
	_ok(Session.followers.is_empty(),
		"followers komt terug uit de save; die hoort runtime-only te zijn")
	_ok(Session.get_flag(QuestEngine.helper_flag(gedaan[0]))
			or QuestEngine.is_own_expertise(gedaan[0]),
		"de helper-vlag van %s overleeft het laden niet" % gedaan[0])

	# --- migratiepad: een save met rauwe ints -----------------------------
	# Zo staan alle bestaande saves op schijf. Die horen door te spelen, niet
	# stil terug te vallen op een lege dag.
	QuestEngine.start_run(&"daan")
	Session.from_dict({
		"character_id": "daan",
		"ticket_states": {
			"t01": int(GameEnums.TicketState.DONE),
			"t02": int(GameEnums.TicketState.AVAILABLE),
		},
	})
	_ok(Session.ticket_state(&"t01") == GameEnums.TicketState.DONE,
		"een oude save met een rauwe int leest t01 niet meer als opgelost")
	_ok(Session.ticket_state(&"t02") == GameEnums.TicketState.AVAILABLE,
		"een oude save met een rauwe int leest t02 niet meer als open")

	# --- een lege sessie is geen run ---------------------------------------
	# Wegdrukken op het titelscherm mag geen knop "Doorgaan" opleveren die je in
	# een wereld zonder personage zet.
	var f := FileAccess.open(Session.SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"character_id": ""}))
		f.close()
	_ok(not Session.has_saved_run(),
		"een save zonder personage telt toch als een run om naar terug te keren")

	# --- de schijf weer terugzetten zoals hij was --------------------------
	if had_save:
		var g := FileAccess.open(Session.SAVE_PATH, FileAccess.WRITE)
		if g != null:
			g.store_string(oude_save)
			g.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Session.SAVE_PATH))

	QuestEngine.start_run(&"daan")


## Wat er na een round-trip terug hoort te staan. Twee keer aangeroepen — via
## `from_dict()` en via de schijf — omdat JSON een eigen laag fouten toevoegt:
## daar worden ints floats en StringNames strings, en een sleutel die dat niet
## overleeft valt stil terug op zijn standaardwaarde.
func _controleer_halve_run(via: String, gedaan: Array[StringName],
		minuten: int, gevonden: int) -> void:
	_ok(Session.character_id == &"daan", "%s: het personage is %s geworden" % [
		via, Session.character_id])
	_ok(Session.get_flag(&"save_test_vlag"), "%s: een losse vlag overleeft het niet" % via)
	_ok(Session.item_count(&"koffie") == 3,
		"%s: 3 koffie komt terug als %d" % [via, Session.item_count(&"koffie")])
	_ok(Session.get_counter(&"save_test_teller") == 2,
		"%s: de teller komt terug als %d" % [via, Session.get_counter(&"save_test_teller")])
	_ok(Session.worked_minutes == minuten,
		"%s: %d gewerkte minuten komen terug als %d" % [via, minuten, Session.worked_minutes])
	_ok(Session.booked_minutes == 240,
		"%s: de geboekte uren komen terug als %d" % [via, Session.booked_minutes])
	_ok(Session.pinned_ticket == &"t07",
		"%s: de gekozen ticket komt terug als '%s'" % [via, Session.pinned_ticket])
	_ok(int(Gevolgen.getal(&"scope_punten", -1)) == 17,
		"%s: de gevolgen komen terug als %s" % [via, Gevolgen.getal(&"scope_punten", -1)])
	_ok(Session.discovered.size() == gevonden,
		"%s: %d gevonden tickets komen terug als %d" % [via, gevonden, Session.discovered.size()])
	_ok(Session.done_order.size() == gedaan.size(),
		"%s: done_order telt %d in plaats van %d" % [
			via, Session.done_order.size(), gedaan.size()])
	for tid: StringName in gedaan:
		_ok(Session.is_done(tid), "%s: %s staat niet meer op opgelost" % [via, tid])
		_ok(tid in Session.done_order, "%s: %s ontbreekt in done_order" % [via, tid])
	_ok(Session.ticket_state(&"t10") == GameEnums.TicketState.LOCKED,
		"%s: t10 komt niet meer als geblokkeerd terug" % via)
	_ok(Session.done_count() == gedaan.size(),
		"%s: de teller staat op %d/10" % [via, Session.done_count()])

	# En de wereld moet hierna weer verder kunnen: de promotie die de laadroute
	# draait mag geen enkel ticket verliezen.
	QuestEngine.refresh_availability()
	_ok(QuestEngine.open_tickets().size() == GameData.ticket_ids().size() - gedaan.size() - 1,
		"%s: na het laden staan er %d tickets open" % [via, QuestEngine.open_tickets().size()])


## Alle tekst van een dialoogboom op een rij, varianten inbegrepen, om op te
## grepen zonder de boom zelf te hoeven doorlopen.
func _alle_tekst(def: DialogueDef) -> String:
	var out := ""
	for nid: Variant in def.nodes.keys():
		var node := def.node(StringName(nid))
		out += String(node.get("text", "")) + "\n"
		for v: Variant in node.get("variants", []):
			out += String((v as Dictionary).get("text", "")) + "\n"
	return out


## De briefing van de eigenaar: bestaat hij, klopt hij, en staat er niets in dat
## de speler niet had mogen zien.
##
## De belangrijkste van de vier controles is de laatste. De feiten in een
## briefing staan als plaatshouder in `data/minigame_content.json` en worden
## door `Briefing` gevuld uit de config van diezelfde minigame. Blijft er een
## accolade over, dan verzon iemand een plaatshouder die de mechaniek niet kent,
## en dan staat er letterlijk "{knelpunt}" in het gezicht van de speler. Dat is
## niets wat crasht en dus niets wat iemand meldt.
func _test_briefings() -> void:
	_kop("de briefing van de eigenaar")

	var gezien := 0
	for tid: StringName in GameData.ticket_ids():
		var t: TicketDef = GameData.ticket(tid)
		if t == null or t.owner_character == &"":
			continue    # de finale heeft geen eigenaar
		gezien += 1

		var tekst := Briefing.regel(t)
		if "--print-briefings" in OS.get_cmdline_user_args():
			print("   %s %s: %s" % [t.code, t.owner_character, tekst])
		_ok(tekst != "", "%s: geen briefing voor een ticket met een eigenaar (%s)" % [
			t.code, t.owner_character])
		_ok(not tekst.contains("{") and not tekst.contains("}"),
			"%s: onopgeloste plaatshouder in de briefing: %s" % [t.code, tekst])
		# Een briefing is een regel dialoog, geen handleiding.
		_ok(tekst.length() <= 220,
			"%s: briefing van %d tekens is te lang voor het dialoogvenster" % [
				t.code, tekst.length()])

		# De eigenaar moet ook echt bestaan als NPC, anders zwijgt hij.
		var d: NpcDef = GameData.npc(StringName("npc_%s" % t.owner_character))
		_ok(d != null, "%s: eigenaar '%s' staat niet in npcs.json" % [
			t.code, t.owner_character])

		# En zijn rol komt uit het personage, niet uit het ticket.
		var c: CharacterDef = GameData.character(t.owner_character)
		_ok(c != null and c.role != "",
			"%s: eigenaar '%s' heeft geen rol in characters.json" % [
				t.code, t.owner_character])
		if c != null:
			_ok(t.owner_role == c.role,
				"%s: owner_role '%s' wijkt af van de rol van %s ('%s')" % [
					t.code, t.owner_role, c.id, c.role])

	_ok(gezien == 9, "verwacht 9 tickets met een eigenaar, gevonden %d" % gezien)

	# Eén functietitel per collega. `characters.json` is de bron voor de briefing
	# en het selectiescherm, `npcs.json` voor het bordje boven zijn hoofd op de
	# vloer. Wijken die af, dan heeft dezelfde man twee banen: de speler kiest
	# "Client Lead" en spreekt daarna "Account management" aan. Dat is geen crash
	# en dus niets wat vanzelf opvalt — vandaar deze regel.
	for cid: StringName in GameData.character_ids():
		var pc: CharacterDef = GameData.character(cid)
		var np: NpcDef = GameData.npc(StringName("npc_%s" % cid))
		if pc == null or np == null:
			continue    # het ontbreken van de NPC wordt hierboven al gemeld
		_ok(np.role == pc.role,
			"%s heeft twee functietitels: '%s' in npcs.json, '%s' in characters.json" % [
				cid, np.role, pc.role])

	# De stand-up noemt bij naam wie iets te melden heeft. Die naam moet een
	# spreker zijn die in de data ook echt `belangrijk` staat, anders stuurt de
	# briefing je een verkeerde kant op — erger dan geen briefing.
	var st: Dictionary = MinigameContent.get_config(&"mg_planning")
	var brief_st := Briefing.regel(GameData.ticket(&"t02"))
	var genoemd := ""
	for raw: Variant in (st.get("sprekers", []) as Array):
		var sp := raw as Dictionary
		var naam := String(sp.get("naam", ""))
		if naam != "" and brief_st.contains(naam):
			genoemd = naam
			_ok(bool(sp.get("belangrijk", false)),
				"de stand-up-briefing noemt %s, maar die staat niet als belangrijk" % naam)
	_ok(genoemd != "", "de stand-up-briefing noemt geen enkele spreker bij naam")

	# En de scope-briefing noemt hoeveel van haar wensen eigenlijk projecten
	# zijn. Dat getal komt uit `Gevolgen.ZWARE_WENSEN` en moet kloppen: het
	# bepaalt straks of je scope te groot was, dus Daan mag er niet naast zitten.
	var sc: Dictionary = MinigameContent.get_config(&"mg_user_story")
	var zwaar := 0
	for raw: Variant in (sc.get("wensen", []) as Array):
		if String((raw as Dictionary).get("id", "")) in Gevolgen.ZWARE_WENSEN:
			zwaar += 1
	_ok(zwaar > 0, "geen enkele wens in BBD-201 is een zware wens")
	_ok(Briefing.regel(GameData.ticket(&"t01")).contains("er %d geen wens" % zwaar),
		"de scope-briefing noemt niet het werkelijke aantal zware wensen (%d)" % zwaar)

	# Hetzelfde voor het knelpunt in de renderpijplijn: de genoemde stap moet de
	# stap met de kleinste capaciteit zijn.
	var pj: Dictionary = MinigameContent.get_config(&"mg_video")
	var brief_pj := Briefing.regel(GameData.ticket(&"t08"))
	var kleinste := 99
	for raw: Variant in (pj.get("stages", []) as Array):
		kleinste = mini(kleinste, int((raw as Dictionary).get("capaciteit", 99)))
	for raw: Variant in (pj.get("stages", []) as Array):
		var stg := raw as Dictionary
		var label := String(stg.get("label", ""))
		if label != "" and brief_pj.contains(label):
			_ok(int(stg.get("capaciteit", 99)) == kleinste,
				"de pijplijn-briefing noemt '%s' als knelpunt, maar die heeft niet de kleinste capaciteit" % label)
