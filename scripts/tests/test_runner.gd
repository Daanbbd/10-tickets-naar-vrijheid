extends Node
## Headless testsuite. Draaien met:
##   Godot --headless --path . --scene res://tests/test_runner.tscn
##
## Draait als scene (niet als --script) omdat autoloads anders niet bestaan.

var _fails: Array[String] = []
var _checks: int = 0

## De telefoon van De Klant mag maar een subset van QuestEngine.EFFECT_OPS
## gebruiken — bewust kleiner, want een bericht dat gemist wordt (de bekende
## `_wachtrij`-race) mag nooit iets breken dat verder gaat dan tekst, een
## vlag, een teller in tijd, een item of een ontgrendeling.
const KLANT_EFFECT_OPS: Array[String] = [
	"unlock_ticket", "set_flag", "toast", "kost_tijd", "add_item",
]


func _ready() -> void:
	print("\n=== 10 TICKETS NAAR VRIJHEID — testsuite ===\n")
	_test_data_laadt()
	_test_verwijzingen()
	_test_look_lagen_bestaan()
	_test_dialoog()
	_test_geen_dode_data()
	_test_minigame_inhoud()
	_test_nederlands()
	_test_wereld()
	_test_karakterstemmen()
	_test_traits()
	_test_abtest_spreiding()
	_test_urenstaat()
	_test_klok()
	# Beide draaien een echte minigame via Shell.run_minigame() en wachten op
	# zijn `finished`-signaal — zonder `await` hier loopt hun staart pas ná
	# _rapport()/quit(), en dan tellen die controles nooit mee (zie de
	# soortgelijke, niet-awaited `_test_urenstaat_scherm()` onderaan: dat is
	# een bestaande tekortkoming die hier niet herhaald wordt).
	await _test_storingen()
	await _test_minigame_pauze()
	await _test_minigame_intro_scherm()
	_test_gevolgen()
	_test_questketen_alle_personages()
	_test_vrije_volgorde()
	_test_geen_dood_punt()
	_test_gedeelde_ankers()
	_test_vinden()
	_test_startroutes()
	_test_ankers_bereikbaar()
	_test_zonevolgorde()
	_test_item_vindplaats()
	_test_ticket_eigenaarschap()
	_test_omz_en_absoluta()
	_test_balkmaat()
	_test_hudband()
	_test_leesbaarheid()
	_test_minigame_chrome()
	_test_navigatie()
	_test_briefings()
	_test_intro()
	_test_save_ronde()
	_test_save_verwijderen()
	_test_uitlijnen_perfect()
	_test_wereldhandelingen()
	_test_urenstaat_scherm()
	_test_werving_begint_met_de_vraag()
	_test_klant_is_een_persoon()
	await _test_dialoogvenster_past()
	await _test_schermen_passen()
	await _test_wereldchrome_past()
	await _test_wijzer_wijkt_voor_tikkaartje()
	await _test_klant_melding_voor_bericht()
	_test_dialoog_speelt_niet_zijn_eigen_id()
	_test_teller_daalt_niet_binnen_complete()
	_test_tweede_oplevering_betaalt_niet_opnieuw()
	_test_keten_is_bereikbaar_en_afgeleid()
	_test_duimzone_rechts()
	await _test_weggevallen_regel_telt()
	_test_hokjedak_dekt_de_zone()
	_test_wijzer_kiest_het_dichtste()
	_test_aanduidingen_kloppen()
	_rapport()


# --- kleine assert-laag ---------------------------------------------------

func _ok(cond: bool, wat: String) -> void:
	_checks += 1
	if not cond:
		_fails.append(wat)


func _kop(t: String) -> void:
	print("-- %s" % t)


## Vindt de eerste Button onder `root` waarvan de tekst met `voorvoegsel`
## begint. Voor tests die een echte, in code opgebouwde UI controleren zonder
## op een structureel kindpad te leunen dat bij de eerstvolgende herschikking
## toch weer verandert.
func _vind_knop(root: Node, voorvoegsel: String) -> Button:
	if root == null:
		return null
	if root is Button and (root as Button).text.begins_with(voorvoegsel):
		return root as Button
	for kind: Node in root.get_children():
		var gevonden := _vind_knop(kind, voorvoegsel)
		if gevonden != null:
			return gevonden
	return null


## De tegenhanger van `_vind_knop()` voor gewone tekst: staat `stuk` ergens in
## een Label of RichTextLabel onder `root`? Om te controleren dat een naam of
## regel echt op het scherm terechtkomt, en niet alleen in de data staat.
func _vind_label(root: Node, stuk: String) -> Node:
	if root == null:
		return null
	if root is Label and (root as Label).text.contains(stuk):
		return root
	if root is RichTextLabel and (root as RichTextLabel).text.contains(stuk):
		return root
	for kind: Node in root.get_children():
		var gevonden := _vind_label(kind, stuk)
		if gevonden != null:
			return gevonden
	return null


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

			# Effects draaien pas ná de melding op het scherm (telefoon.gd::_toon).
			# De telefoon krijgt bewust een kleinere whitelist dan de volle
			# EFFECT_OPS: een gemiste zin mag nooit een teller of een item stuk
			# maken dat niemand hier verwacht.
			var effects := d.get("effects", []) as Array
			for e: Variant in effects:
				var ed := e as Dictionary
				if ed == null:
					continue
				var op := String(ed.get("op", ""))
				_ok(op in KLANT_EFFECT_OPS,
					"%s: effect-op '%s' staat niet op de whitelist voor de telefoon" % [bid, op])
				if op == "unlock_ticket":
					var doel := StringName(ed.get("ticket", ""))
					_ok(doel in GameData.ticket_ids(),
						"%s: unlock_ticket noemt '%s', en dat ticket bestaat niet" % [bid, doel])

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

	# --- F4-b: de vier wereldhandelingen boeken ook een gevolg -------------
	# Elk paar test eerst de goede kant, dan de slechte — en eindigt dus op de
	# slechte kant. Dat is met opzet: de vier vlaggen moeten blijven staan voor
	# de "slechte dag"-berekening van finale_start() verderop.
	Gevolgen.boek(&"mg_klantfeedback", MinigameResult.make(&"mg_klantfeedback",
		GameEnums.Outcome.SUCCESS, 5, {&"score": 5, &"drempel": 3}))
	_ok(not Session.get_flag(&"gevolg_klant_ontevreden"),
		"een score boven de drempel zet gevolg_klant_ontevreden toch")
	Gevolgen.boek(&"mg_klantfeedback", MinigameResult.make(&"mg_klantfeedback",
		GameEnums.Outcome.SUCCESS, 1, {&"score": 1, &"drempel": 3}))
	_ok(Session.get_flag(&"gevolg_klant_ontevreden"),
		"een score onder de drempel zet gevolg_klant_ontevreden niet")
	_ok(int(Gevolgen.getal(&"klant_score", -1)) == 1, "klant_score komt niet in de gevolgen terecht")
	_ok(int(Gevolgen.getal(&"klant_drempel", -1)) == 3, "klant_drempel komt niet in de gevolgen terecht")

	Gevolgen.boek(&"mg_backend_fix", MinigameResult.make(&"mg_backend_fix",
		GameEnums.Outcome.SUCCESS, 1, {&"juist": true}))
	_ok(not Session.get_flag(&"gevolg_backend_fout_gekozen"),
		"de juiste kabel kiezen zet gevolg_backend_fout_gekozen toch")
	Gevolgen.boek(&"mg_backend_fix", MinigameResult.make(&"mg_backend_fix",
		GameEnums.Outcome.SUCCESS, 0, {&"juist": false}))
	_ok(Session.get_flag(&"gevolg_backend_fout_gekozen"),
		"de verkeerde kabel kiezen zet gevolg_backend_fout_gekozen niet")
	_ok(not bool(Gevolgen.getal(&"backend_juist", true)), "backend_juist komt niet in de gevolgen terecht")

	Gevolgen.boek(&"mg_muziek", MinigameResult.make(&"mg_muziek",
		GameEnums.Outcome.SUCCESS, 1, {&"goed": true, &"titel": "Rustig Kantoor"}))
	_ok(not Session.get_flag(&"gevolg_verkeerde_merksound"),
		"de goede tags kiezen zet gevolg_verkeerde_merksound toch")
	Gevolgen.boek(&"mg_muziek", MinigameResult.make(&"mg_muziek",
		GameEnums.Outcome.SUCCESS, 0, {&"goed": false, &"titel": "Hardstyle Intro"}))
	_ok(Session.get_flag(&"gevolg_verkeerde_merksound"),
		"de verkeerde tags kiezen zet gevolg_verkeerde_merksound niet")
	_ok(String(Gevolgen.getal(&"muziek_titel", "")) == "Hardstyle Intro",
		"muziek_titel komt niet in de gevolgen terecht")

	Gevolgen.boek(&"mg_paarden", MinigameResult.make(&"mg_paarden",
		GameEnums.Outcome.SUCCESS, 1, {&"paard": true, &"zelf_gevonden": true}))
	_ok(not Session.get_flag(&"gevolg_paard_gemist"),
		"het paard zelf vinden zet gevolg_paard_gemist toch")
	# P1-6: dit is de enige route waarlangs gevolg_paard_gemist ooit true wordt
	# (Bastiaans vakgebiedvoordeel, via _wh_paarden()'s geen_zoektocht — zonder
	# de trait blokkeert die functie de route via het bord juist). Een trait
	# geeft alleen voordeel, nooit een straf (TraitModifier), dus getest mag
	# door deze vlag niet zakken. `clampi(getest, 0, 3)` in finale_start() zou
	# een straf op een toch al lege getest-teller onzichtbaar maken, dus eerst
	# gevolg_cro_gehaald erbij zodat de meting niet op de bodemklem struikelt.
	Gevolgen.boek(&"mg_cro", MinigameResult.make(&"mg_cro",
		GameEnums.Outcome.SUCCESS, 0, {&"boven_doel": true, &"conversie": 3.4}))
	var getest_voor := int(Gevolgen.finale_start()[&"getest"])
	_ok(getest_voor > 0, "P1-6: testopzet deugt niet, getest_voor zit al op de bodemklem")
	Gevolgen.boek(&"mg_paarden", MinigameResult.make(&"mg_paarden",
		GameEnums.Outcome.SUCCESS, 1, {&"paard": true, &"zelf_gevonden": false}))
	_ok(Session.get_flag(&"gevolg_paard_gemist"),
		"het paard niet zelf vinden zet gevolg_paard_gemist niet")
	_ok(not bool(Gevolgen.getal(&"paard_zelf_gevonden", true)),
		"paard_zelf_gevonden komt niet in de gevolgen terecht")
	_ok(int(Gevolgen.finale_start()[&"getest"]) == getest_voor,
		"P1-6: gevolg_paard_gemist kost getest — Bastiaans voordeel is weer een straf")

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


## Elke look-waarde in de data moet een laag-sheet op schijf hebben.
##
## Dit is de enige controle op het uiterlijk van de cast, en hij bestaat omdat
## de gevolgen van een fout hier onzichtbaar zijn. `CharacterSprites._laag()`
## doet bij een variant die niet bestaat niets meer dan een `push_warning` en
## onthoudt `null`; `_composiet()` slaat die laag daarna over. Een typfout in
## `characters.json` levert dus geen foutmelding op maar een collega zonder
## haar, zonder bril of zonder shirt -- en in een headless run leest niemand
## die waarschuwing.
##
## De cast is lang tegen niets gevalideerd en dat was te zien: Koen droeg een
## bril die hij niet heeft en Victor een koptelefoon die hij nooit draagt.
## Dit vangt de typfouten; of de waarde ook klopt met de foto in
## `assets/personen/` blijft mensenwerk.
func _test_look_lagen_bestaan() -> void:
	_kop("look-lagen bestaan")
	var iedereen: Dictionary = {}       # naam -> look
	for cid: StringName in GameData.character_ids():
		var c: CharacterDef = GameData.character(cid)
		iedereen[c.name] = c.look
	for nid: StringName in GameData.npcs:
		var n: NpcDef = GameData.npcs[nid]
		iedereen["NPC %s" % nid] = n.look

	for naam: String in iedereen:
		var look: Dictionary = iedereen[naam]
		for slot: StringName in CharacterSprites.VOLGORDE:
			# hair_back is geen eigen veld: hij volgt het kapsel, en alleen de
			# kapsels met een achterkant hebben er een sheet voor.
			var sleutel := &"hair" if slot == &"hair_back" else slot
			var variant := StringName(look.get(sleutel, &""))
			if variant == &"":
				continue
			if slot == &"hair_back" and not (variant in CharacterSprites.MET_ACHTERHAAR):
				continue
			var pad: String = CharacterSprites.LAAG_PAD % [slot, variant]
			_ok(ResourceLoader.exists(pad),
				"%s: look.%s = '%s' bestaat niet (%s)" % [naam, sleutel, variant, pad])


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


## Data die niets doet is erger dan ontbrekende data: hij liegt.
##
## Een item in `items.json` dat door geen enkel `add_item`-effect wordt
## uitgedeeld maakt van elke `has_item`-conditie een tak die nooit valt — de
## toegangspas hing er zo jarenlang bij, compleet met een regel dialoog die
## niemand ooit las. En een vlag die een keuze zet maar die niemand leest belooft
## een gevolg dat er niet is: de speler weegt af, en het weegt niets.
##
## Vandaar dat dit de bronbestanden leest en niet de geparste modellen. De fout
## zit niet in een functie maar in het ontbreken van een tweede plek waar iets
## genoemd wordt.
func _test_geen_dode_data() -> void:
	_kop("geen dode data")

	var vondst := {"items": {}, "keuzevlaggen": {}, "gelezen": {}}
	for pad: String in _databestanden():
		_oogst(JSON.parse_string(FileAccess.get_file_as_string(pad)), false, pad, vondst)

	var uitgedeeld: Dictionary = vondst["items"]
	var keuzevlaggen: Dictionary = vondst["keuzevlaggen"]
	var gelezen: Dictionary = vondst["gelezen"]

	# Vangnet: een test die per ongeluk niets vindt keurt alles goed.
	_ok(not uitgedeeld.is_empty(), "geen enkel add_item-effect gevonden; leest deze test de data wel?")
	_ok(not keuzevlaggen.is_empty(), "geen enkele keuzevlag gevonden; leest deze test de dialogen wel?")
	_ok(not gelezen.is_empty(), "geen enkele vlagconditie gevonden; leest deze test de dialogen wel?")

	for id: Variant in GameData.items.keys():
		_ok(uitgedeeld.has(String(id)),
			"item '%s' staat in items.json maar wordt door geen enkel add_item-effect uitgedeeld" % id)

	# En andersom: een effect dat een niet-bestaand item uitdeelt vult stilletjes
	# de inventaris met een id zonder naam en zonder omschrijving.
	for id: Variant in uitgedeeld.keys():
		_ok(GameData.item(StringName(id)) != null,
			"%s deelt item '%s' uit, en dat staat niet in items.json" % [uitgedeeld[id], id])

	for f: Variant in keuzevlaggen.keys():
		_ok(gelezen.has(String(f)) or StringName(f) in Gevolgen.VLAGGEN,
			"vlag '%s' wordt door een keuze gezet (%s) maar door geen enkele conditie of Gevolgen-regel gelezen" % [
				f, keuzevlaggen[f]])


## Alle gedragsdata. `floor.json` blijft erbuiten: dat is een plattegrond zonder
## effecten of condities, en hij wordt nooit met de hand aangeraakt.
func _databestanden() -> Array[String]:
	var out: Array[String] = []
	for dir_path: String in ["res://data", "res://data/dialogue", "res://data/tickets"]:
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		for f: String in dir.get_files():
			# Godot hernoemt geïmporteerde bestanden in exports naar .remap
			var clean := f.trim_suffix(".remap")
			if clean.ends_with(".json") and clean != "floor.json":
				out.append("%s/%s" % [dir_path, clean])
	out.sort()
	return out


## Loopt één JSON-boom af en noteert wie wat uitdeelt, zet en leest. `in_keuze`
## erft naar beneden door: een `set_flag` diep in een `choices`-tak is nog steeds
## een gevolg van een keuze van de speler.
func _oogst(v: Variant, in_keuze: bool, pad: String, uit: Dictionary) -> void:
	if v is Array:
		for e: Variant in (v as Array):
			_oogst(e, in_keuze, pad, uit)
		return
	if not (v is Dictionary):
		return
	var d := v as Dictionary

	match String(d.get("op", "")):
		"add_item":
			(uit["items"] as Dictionary)[String(d.get("item", ""))] = pad
		"set_flag":
			if in_keuze:
				(uit["keuzevlaggen"] as Dictionary)[String(d.get("flag", ""))] = pad

	# Zelfde soepelheid als Conditions._names(): een enkele naam mag ook zonder
	# lijst, en die telt hier net zo goed als lezer.
	for sleutel: String in ["flags_all", "flags_none"]:
		var rv: Variant = d.get(sleutel, [])
		if rv is Array:
			for f: Variant in (rv as Array):
				(uit["gelezen"] as Dictionary)[String(f)] = pad
		elif rv != null and String(rv) != "":
			(uit["gelezen"] as Dictionary)[String(rv)] = pad

	for k: Variant in d.keys():
		_oogst(d[k], in_keuze or String(k) == "choices", pad, uit)


func _test_minigame_inhoud() -> void:
	_kop("minigame-inhoud")
	for id: Variant in GameData.minigames.keys():
		var mid := StringName(id)
		var c := MinigameContent.get_config(mid)
		_ok(not c.is_empty(), "minigame '%s' heeft geen inhoud" % mid)
		if c.is_empty():
			continue

		# Het wat/waarom-scherm van MinigameIntro leest "intro" en "waarom" bij
		# alle elf minigames, niet alleen de negen met een eigenaar-briefing
		# (die controleert _test_briefings() al) — dus die twee velden gelden
		# hier voor de volledige lijst.
		var wat := Briefing.vul(String(c.get("intro", "")), c)
		_ok(wat != "", "%s: geen 'intro' (het 'Wat' op het instructiescherm)" % mid)
		_ok(not wat.contains("{") and not wat.contains("}"),
			"%s: onopgeloste plaatshouder in 'intro': %s" % [mid, wat])
		_ok(wat.length() <= 220, "%s: 'intro' van %d tekens is te lang voor het instructiescherm" % [
			mid, wat.length()])

		var waarom := Briefing.vul(String(c.get("waarom", "")), c)
		_ok(waarom != "", "%s: geen 'waarom' (het instructiescherm heeft er geen)" % mid)
		_ok(not waarom.contains("{") and not waarom.contains("}"),
			"%s: onopgeloste plaatshouder in 'waarom': %s" % [mid, waarom])
		_ok(waarom.length() <= 160, "%s: 'waarom' van %d tekens is te lang voor het instructiescherm" % [
			mid, waarom.length()])

		var t := String(c.get("type", ""))
		match t:
			"slotboard":
				# F4-a: het slotboard draagt nog maar een minigame — de urenstaat —
				# en die heeft bewust geen goed antwoord: drie kant-en-klare
				# tijdverdelingen, niet meer 22 sleepbare uurblokjes.
				var opties := c.get("opties", []) as Array
				_ok(opties.size() == 3,
					"%s: geen drie voorgestelde verdelingen (%d gevonden)" % [mid, opties.size()])
				var ids := {}
				for raw: Variant in opties:
					var o := raw as Dictionary
					var oid := String(o.get("id", ""))
					_ok(oid != "", "%s: optie zonder id" % mid)
					_ok(not ids.has(oid), "%s: id '%s' komt dubbel voor" % [mid, oid])
					ids[oid] = true
					_ok(String(o.get("tekst", "")) != "", "%s/%s: optie zonder tekst" % [mid, oid])
					_ok(String(o.get("reactie", "")) != "", "%s/%s: optie zonder reactie" % [mid, oid])
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
				var titels := {}
				for raw2: Variant in (c.get("uitkomsten", []) as Array):
					var u := raw2 as Dictionary
					var titel := String(u.get("titel", ""))
					_ok(titel != "", "mg_deploy: uitkomst zonder titel")
					_ok(String(u.get("tekst", "")) != "", "mg_deploy: uitkomst zonder tekst")
					# Geen game over: elke uitkomst is een oplevering. De titel mag
					# wel meebewegen met de score (BBD-210) — "OPGELEVERD" moet het
					# kernwoord blijven, maar hoeft niet meer letterlijk alles te zijn.
					_ok(titel.begins_with("OPGELEVERD"),
						"mg_deploy: uitkomst '%s' begint niet met OPGELEVERD" % titel)
					titels[titel] = true
					laagste = mini(laagste, int(u.get("min", 0)))
				_ok(laagste == 0, "mg_deploy: geen uitkomst met min 0; een slechte dag valt door")
				_ok(titels.size() == (c.get("uitkomsten", []) as Array).size(),
					"mg_deploy: twee uitkomsten delen dezelfde titel — de score moet zichtbaar meebewegen")

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
				var langste_duur := 0.0
				for raw: Variant in sprekers:
					var sp := raw as Dictionary
					_ok(String(sp.get("naam", "")) != "", "%s: spreker zonder naam" % mid)
					_ok(not (sp.get("regels", []) as Array).is_empty(),
						"%s: %s zegt niets" % [mid, sp.get("naam", "?")])
					var duur := float(sp.get("duur", 0.0))
					spreektijd += duur
					langste_duur = maxf(langste_duur, duur)
					if bool(sp.get("belangrijk", false)):
						belangrijk += 1
						# De naam zelf hoort niet in de data-aanwijzing te lekken: die
						# staat in de briefing als categorie, niet als naam (zie
						# `_test_briefings()`), maar de aanwijzing zelf moet er wel zijn.
						_ok(String(sp.get("aanwijzing", "")) != "" or sp.get("id", "") == "danny",
							"%s: belangrijke spreker %s heeft geen aanwijzing en is niet Danny" % [
								mid, sp.get("naam", "?")])
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
				# BBD-202/F4-a: één afkapping mag het nooit meer redden. Zelfs de
				# langste spreker alleen eraf halen moet de rest nog steeds over het
				# budget laten lopen, anders is "kap één keer de juiste af" weer de
				# hele opgave.
				_ok(marge > langste_duur,
					"%s: de marge (%.1fs) is niet groter dan de langste spreker (%.1fs); één afkapping volstaat dan al" % [
						mid, marge, langste_duur])
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

	# Elk samengesteld meubel moet zijn PNG hebben, en de maat in de naam moet
	# kloppen met de footprint: main.gd schaalt niets, dus een sprite die niet
	# past staat scheef op zijn eigen blok. Een ontbrekende sprite is vandaag
	# alleen een push_error in een draaiende wereld — dus onzichtbaar voor wie
	# de generator draait en de suite kijkt.
	for raw: Variant in (f.get("props", []) as Array):
		var p := raw as Dictionary
		var naam := String(p.get("prop", ""))
		var pad := "res://assets/sprites/props/%s.png" % naam
		_ok(ResourceLoader.exists(pad), "prop '%s' heeft geen sprite (%s)" % [naam, pad])
		var r: Array = p.get("rect", [0, 0, 0, 0])
		var maat := naam.get_slice("_", naam.get_slice_count("_") - 1)
		_ok(maat == "%dx%d" % [int(r[2]) - int(r[0]) + 1, int(r[3]) - int(r[1]) + 1],
			"prop '%s' heeft een naam die niet bij zijn footprint %s past" % [naam, str(r)])
		# Een hangend bordje mag de vloer niet dichtzetten: je loopt eronderdoor.
		if bool(p.get("hangend", false)):
			for x: int in range(int(r[0]), int(r[2]) + 1):
				for y: int in range(int(r[1]), int(r[3]) + 1):
					_ok(not _solide(grid, legend, x, y),
						"hangend bordje '%s' hangt boven een solide tegel %d,%d" % [naam, x, y])

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


## BBD-206/F4-a: "HOUDEN, TRAIT OMDRAAIEN." Danny's vakgebiedvoordeel gaf eerst
## `toon_effect: true`, en dat verwijderde zijn eigen minigame — de CRO'er was
## de enige speler die niet hoefde te meten, want elke knop toonde meteen zijn
## exacte effectgetal. `_test_traits()` hierboven bewijst alleen dat de opgave
## verandert; dit bewijst dat de vervanging (een bandbreedte) niet dezelfde
## fout in een ander jasje is: geen exact getal meer op de knop, én smal genoeg
## dat een duidelijke winnaar nog te herkennen is, maar breed genoeg dat twee
## dicht bij elkaar liggende varianten nog steeds gemeten moeten worden.
func _test_abtest_spreiding() -> void:
	_kop("BBD-206: Danny's CRO-voordeel meet nog steeds")

	var config: Dictionary = MinigameContent.get_config(&"mg_cro").duplicate(true)
	TraitModifier._abtest(config)
	_ok(not config.has("toon_effect"),
		"TraitModifier._abtest() zet nog 'toon_effect' — het exacte effectgetal is niet weg")
	_ok(bool(config.get("toon_spreiding", false)),
		"TraitModifier._abtest() zet 'toon_spreiding' niet aan")

	# Instantieer de node los van de scèneboom: `_variant_label()` en
	# `_spreiding_bereik()` zijn pure stringmethodes die geen `_ready()` nodig
	# hebben, dus dit hoeft geen scherm te openen om Danny's label te toetsen.
	var mg: Node = load("res://scripts/minigames/mg_abtest.gd").new()
	mg.set("_toon_spreiding", true)
	mg.set("_eenheid", "%")

	var label: String = mg.call("_variant_label", {"label": "Test", "effect": 0.5})
	_ok(not label.contains("+0,5"),
		"Danny's variant-label toont nog steeds het exacte effectgetal: %s" % label)
	_ok(label.contains("tot"),
		"Danny's variant-label toont geen bandbreedte: %s" % label)

	# Twee varianten die dicht bij elkaar liggen (net als in de echte data,
	# waar +0,1 en -0,1 in dezelfde ronde voorkomen) moeten overlappende
	# bandbreedtes krijgen: dat is het bewijs dat het label ze niet uit elkaar
	# trekt en de speler dus alsnog moet meten om de betere te vinden.
	var bereik_a: Vector2 = mg.call("_spreiding_bereik", 0.1)
	var bereik_b: Vector2 = mg.call("_spreiding_bereik", -0.1)
	_ok(bereik_a.x <= bereik_b.y and bereik_b.x <= bereik_a.y,
		"de bandbreedte trekt twee dicht bij elkaar liggende varianten (+0,1 en -0,1) toch al uit elkaar zonder te meten")

	# Een duidelijke winnaar (+0,5 tegenover +0,1) moet wel als winnaar blijven
	# lezen: anders is de bandbreedte zo breed dat het voordeel niets meer
	# zegt.
	var bereik_groot: Vector2 = mg.call("_spreiding_bereik", 0.5)
	var bereik_klein: Vector2 = mg.call("_spreiding_bereik", 0.1)
	_ok(bereik_groot.x > bereik_klein.y,
		"de bandbreedte is zo breed dat een duidelijk betere variant (+0,5) niet meer als beter leest dan +0,1")

	mg.free()


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


## Vier tickets staan meteen open (t02/t03/t04/t05 — west-cluster, vier
## verschillende eigenaren); de andere vijf ontgrendelen tijdens de dag. De
## oude belofte "elk ticket kan het eerste zijn" klopt dus niet meer. Wat
## overeind blijft, in een nieuwe vorm:
##
##  1. de startstand zelf (precies deze vier, en alleen deze vier);
##  2. elk van de vier startende tickets is zelfstandig oplosbaar als eerste;
##  3. de haalbare eigendoms-garantie: het eigen ticket van elk personage zit
##     in de eerste vier óf in de eerste ontsluitingsgolf, zodat niemand een
##     hele dag begint met vier boodschappen van anderen;
##  4. de finale blijft op slot tot 9/10.
##
## De echte vangrail — nooit een moment zonder open werk — staat niet hier maar
## in `_test_geen_dood_punt()`, want die eist een andere aanpak (elke
## bereikbare deelverzameling, niet elk eerste ticket).
func _test_vrije_volgorde() -> void:
	_kop("vrije volgorde")

	const EERSTE_VIER: Array[StringName] = [&"t02", &"t03", &"t04", &"t05"]

	QuestEngine.start_run(&"daan")
	var open_bij_start := QuestEngine.open_tickets()
	_ok(open_bij_start.size() == 4,
		"bij de start staan er %d open, verwacht 4" % open_bij_start.size())
	for t: TicketDef in open_bij_start:
		_ok(t.id in EERSTE_VIER, "%s staat onverwacht open bij de start" % t.code)
	_ok(Session.ticket_state(&"t10") == GameEnums.TicketState.LOCKED,
		"t10 hoort dicht te zitten tot 9/10")
	_ok(Session.discovered.is_empty(), "een verse sessie heeft al tickets gevonden")

	# Elk van de vier starttickets, los, als allereerste van de dag.
	for eerste: StringName in EERSTE_VIER:
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

	# De haalbare eigendoms-garantie. "Eerste ontsluitingsgolf" is hier
	# concreet: ten hoogste één andere voltooiing verwijderd van de start,
	# ongeacht welke van de vier de speler als eerste kiest.
	#
	# Leest de keten uit `available_when.tickets_done` op het kind en niet meer
	# uit `unlocks` op de ouder. Die rand is omgedraaid zodat beschikbaarheid
	# afgeleide state werd (`refresh_availability()` herstelt hem dan gratis na
	# het laden); `unlocks` bleef bestaan als effect-op maar staat niet meer in
	# de ticketdata, dus de oude lezing leverde een lege golf op en deze test
	# viel om op drie personages. `unlocks` blijft meegenomen voor het geval een
	# ticket ooit weer langs die route opengaat.
	var eerste_golf: Array[StringName] = []
	for id: StringName in EERSTE_VIER:
		for u: StringName in GameData.ticket(id).unlocks:
			if not (u in eerste_golf):
				eerste_golf.append(u)
	for id: StringName in GameData.ticket_ids():
		var wacht_op: Array = GameData.ticket(id).available_when.get("tickets_done", [])
		if wacht_op.size() != 1:
			continue
		if StringName(wacht_op[0]) in EERSTE_VIER and not (id in eerste_golf):
			eerste_golf.append(id)
	for cid: StringName in GameData.character_ids():
		var eigen: Array[StringName] = []
		for id: StringName in GameData.ticket_ids():
			if GameData.ticket(id).owner_character == cid:
				eigen.append(id)
		_ok(not eigen.is_empty(), "%s heeft geen eigen ticket" % cid)
		var bereikt := false
		for id: StringName in eigen:
			if (id in EERSTE_VIER) or (id in eerste_golf):
				bereikt = true
		_ok(bereikt,
			"%s: geen enkel eigen ticket zit in de eerste vier of de eerste ontsluitingsgolf (eigen: %s, golf: %s)"
				% [cid, eigen, eerste_golf])

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


## De echte vangrail achter de nieuwe ontsluiting: nooit een moment zonder
## open werk zolang er nog tickets liggen. Niet getest met een steekproef van
## volgordes, maar exact: elke deelverzameling voltooide tickets die via een
## geldige speelvolgorde bereikbaar is, wordt bezocht en gecontroleerd.
##
## Dat kan hier goedkoop, want de resulterende staat (welke tickets
## LOCKED/AVAILABLE staan) hangt alleen af van wélke tickets al af zijn, niet
## van de volgorde: elk reward_effect en elke unlock is onvoorwaardelijk en
## draait precies een keer. Dus is een zoektocht over deelverzamelingen een
## exacte dekking van élke speelvolgorde — inclusief de zeldzame die een
## steekproef van 10! volgordes zou kunnen missen — in plaats van een
## kansberekening.
func _test_geen_dood_punt() -> void:
	_kop("geen dood punt")

	var bezocht: Dictionary = {}
	var wachtrij: Array = [[]]
	var tien_bereikt := false
	var totaal := GameData.ticket_ids().size()

	while not wachtrij.is_empty():
		var pad: Array = wachtrij.pop_back()

		var sleuteldelen: Array = pad.duplicate()
		sleuteldelen.sort()
		var sleutel := ""
		for id: Variant in sleuteldelen:
			sleutel += String(id) + ","
		if bezocht.has(sleutel):
			continue
		bezocht[sleutel] = true

		QuestEngine.start_run(&"daan")
		for id: Variant in pad:
			var t: TicketDef = GameData.ticket(StringName(id))
			QuestEngine.complete(StringName(id), MinigameResult.make(t.minigame_id, GameEnums.Outcome.SUCCESS))
		_ok(Session.done_count() == pad.size(),
			"opbouw van pad %s klopt niet: %d/%d klaar" % [pad, Session.done_count(), pad.size()])

		var open := QuestEngine.open_tickets()
		if pad.size() < totaal:
			_ok(not open.is_empty(), "dood punt na %d/%d tickets — pad: %s" % [pad.size(), totaal, pad])
		else:
			tien_bereikt = true

		for t: TicketDef in open:
			if not (t.id in pad):
				var vervolg: Array = pad.duplicate()
				vervolg.append(t.id)
				wachtrij.append(vervolg)

	_ok(tien_bereikt, "geen enkele bereikbare volgorde haalt %d/%d tickets" % [totaal, totaal])
	# Vangnet: een test die per ongeluk niets doorzoekt keurt alles goed.
	_ok(bezocht.size() > totaal,
		"de zoektocht bezocht maar %d toestand(en); leest deze test de ontsluitingsketen wel?"
			% bezocht.size())


## Het scrumbord in de gang draagt er twee. Zonder een resolver die dat ziet is
## het tweede ticket onbereikbaar zodra beide openstaan.
func _test_gedeelde_ankers() -> void:
	_kop("gedeelde ankers")
	QuestEngine.start_run(&"daan")
	# Dit gaat over de resolver, niet over de startstand (F3-a): ontgrendel
	# alles zodat gedeelde ankers ook echt met twee open tickets getest worden.
	for id: StringName in GameData.ticket_ids():
		QuestEngine.unlock(id)

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
	# Dit gaat over de zone-plattegrond, niet over de startstand (F3-a):
	# ontgrendel alles behalve de finale zodat elk ticket vindbaar getest wordt.
	for id: StringName in GameData.ticket_ids():
		if id != &"t10":
			QuestEngine.unlock(id)

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
	_ok(QuestEngine.open_tickets().size() == 4,
		"start_run laat %d tickets open, verwacht 4" % QuestEngine.open_tickets().size())

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
	_ok(Hud.eigenaar_suffix(t03.anchor) == " (Willem)",
		"bijschrift op de tikmarker bij de start: kreeg \"%s\"" % Hud.eigenaar_suffix(t03.anchor))

	Session.add_follower(&"npc_willem")
	_ok(Hud._wie(t03) == "Willem loopt mee",
		"doelregel met Willem erbij: kreeg \"%s\"" % Hud._wie(t03))
	_ok(Hud.eigenaar_suffix(t03.anchor) == " (met Willem)",
		"bijschrift met Willem erbij: kreeg \"%s\"" % Hud.eigenaar_suffix(t03.anchor))
	_ok(Scrumbord._korte_eigenaar(t03) == "loopt mee",
		"briefje met Willem erbij: kreeg \"%s\"" % Scrumbord._korte_eigenaar(t03))
	_ok(Scrumbord._volledige_eigenaar(t03) == "Willem loopt met je mee",
		"detailregel met Willem erbij: kreeg \"%s\"" % Scrumbord._volledige_eigenaar(t03))
	Session.remove_follower(&"npc_willem")

	# En het eigen vakgebied blijft ongemoeid.
	QuestEngine.start_run(&"willem")
	_ok(Hud._wie(t03) == "Jij kunt dit zelf",
		"eigen vakgebied: kreeg \"%s\"" % Hud._wie(t03))
	_ok(Hud.eigenaar_suffix(t03.anchor) == "",
		"eigen vakgebied hoort geen naam achter het bijschrift te zetten")


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
						var gate := StringName(String(c))
						if String(sleutel) == "recruit":
							# De werving is de enige boom die de eigenaar per
							# definitie nooit speelt: je haalt hem juist op omdat
							# het níét jouw vakgebied is (`required_helper()`
							# geeft leeg terug bij eigen werk). Een gate op de
							# eigenaar is hier dus een dode variant, en een gate
							# op ieder ander is precies de bedoeling — daar zegt
							# de speler in zijn eigen stem waarvoor hij vastloopt.
							_ok(gate != t.owner_character,
								"%s — %s/%s: variant gegate op eigenaar '%s', maar die haalt zichzelf nooit op"
									% [t.code, did, nid, gate])
							_ok(gate in speelbaar,
								"%s — %s/%s: variant gegate op '%s', dat is geen speelbaar personage"
									% [t.code, did, nid, gate])
						else:
							_ok(gate == t.owner_character,
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


## Wat de HUD bovenin permanent afdekt, en wat daaronder ligt.
##
## De verdieping is 26 tegels en de viewport precies even hoog, dus de camera
## klemt Y volledig vast: chrome bovenin staat over de vergaderkamers. Rij 0 is
## muur — daar mag het staan. Rij 1 is spel: `deploycomputer` op (1,1),
## `sprintbord_vloer` op (25,1). `GameCamera.zak_onder_hud()` schuift de wereld
## daarom een stukje omlaag, en de som van die twee getallen moet kloppen.
##
## Dit is het soort getal dat stil verschuift: één regel extra in de bovenbalk,
## of een groter font, en de vergaderkamers zitten er weer achter zonder dat er
## iets faalt. Vandaar gemeten en niet geteld — `bovenband_hoogte()` telt zijn
## eigen chips op, deze test legt de uitkomst vast.
func _test_hudband() -> void:
	_kop("de band die de HUD bovenin afdekt")

	var tegel := int(GameData.floor_data.get("tile_size", 16))
	var hoog := int(ProjectSettings.get_setting("display/window/size/viewport_height", 416))

	var hud := Hud.new()
	add_child(hud)
	hud.setup()
	var band := hud.bovenband_hoogte()
	var verschuiving := minf(band, GameCamera.MAX_VERSCHUIVING)

	_ok(band > 0.0, "bovenband_hoogte() geeft 0; meet de bovenbalk niets?")
	# De eerste rij spel begint na de verschuiving op `tegel + verschuiving`.
	# Daar moet de chrome ophouden, anders staat hij over de vergaderkamers.
	_ok(band <= float(tegel) + verschuiving,
		"de vaste HUD-balk is %.0f px hoog en dekt daarmee rij 1 af (die begint op %.0f)" % [
			band, float(tegel) + verschuiving])

	var tiles := _object_tiles()
	var hoogste := 99
	var laagste := 0
	for wid: StringName in tiles:
		var y: int = (tiles[wid] as Vector2i).y
		hoogste = mini(hoogste, y)
		laagste = maxi(laagste, y)

	# Rij 0 is muur en draagt geen enkel object. Komt daar ooit iets te staan,
	# dan is de hele afweging hierboven ongeldig en moet dit meebewegen.
	_ok(hoogste >= 1,
		"er staat een object op tegelrij %d, en die rij ligt achter de HUD-chips" % hoogste)
	# En wat er onderaan af gaat, mag niet van het scherm vallen: rij 24 draagt
	# het fysieke ticketbord.
	_ok(float((laagste + 1) * tegel) + GameCamera.MAX_VERSCHUIVING <= float(hoog),
		"het laagste object staat op rij %d en valt met %.0f px verschuiving onder het scherm" % [
			laagste, GameCamera.MAX_VERSCHUIVING])

	# `free()` en niet `queue_free()`: alle tests draaien synchroon in `_ready()`,
	# dus een uitgestelde vrijgave laat deze HUD de hele rest van de suite in de
	# boom staan. Hij is op vijftien Bus-signalen aangesloten en zou dus meelopen
	# met elke latere test die er een uitstuurt — toasts bouwen, tweens starten,
	# de doelregel verversen. Meten en meteen opruimen.
	remove_child(hud)
	hud.free()


## De secundaire tekst haalt WCAG AA, en blijft dat halen.
##
## `UiKit.GRIJS` (#8a8a8a) stond jarenlang op elke uitleg-, status- en
## bijschriftregel in het spel: 3,1:1 op een licht paneel, 3,9:1 op een donker
## paneel, 2,7:1 op papier. Alle drie onder de 4,5:1 die AA vraagt, en dat is
## geen formaliteit — dit is een spel dat op een telefoon gespeeld wordt, vaak
## niet binnen, en elke minigame legt zichzelf uit in precies die kleur.
##
## Twee dingen worden hier bewaakt. Ten eerste dat het vervangende paar de norm
## haalt op élke ondergrond waar het op staat — het paar bestaat juist omdat één
## grijs dat niet kan. Ten tweede, en dat is de belangrijkere: dat niemand per
## ongeluk terugvalt op `GRIJS`. Een label in de verkeerde grijstint is geen
## parse-fout en geen zichtbare bug in de editor; het is gewoon weer een regel
## die buiten wegvalt, en dat merk je pas op een terras.
func _test_leesbaarheid() -> void:
	_kop("leesbaarheid van de secundaire tekst")

	const AA := 4.5
	var op_licht := {
		"PANEL": UiKit.PANEL,
		"WIT": UiKit.WIT,
		"PAPIER": UiKit.PAPIER,
		"POSTIT_LEEG": UiKit.POSTIT_LEEG,
		"NEUTRAAL_TINT": UiKit.NEUTRAAL_TINT,
	}
	for naam: String in op_licht:
		var v := _contrast(UiKit.GRIJS_OP_LICHT, op_licht[naam] as Color)
		_ok(v >= AA, "GRIJS_OP_LICHT haalt op %s maar %.2f:1, AA vraagt %.1f" % [naam, v, AA])

	# `INK.lightened(0.14)` is de opgelichte rij van de karakterselectie: het
	# lichtste donkere vlak in het spel en dus de krapste van de twee kanten.
	var op_donker := {
		"PANEL_DARK": UiKit.PANEL_DARK,
		"INK": UiKit.INK,
		"SCHERM_NACHT": UiKit.SCHERM_NACHT,
		"SCHERM_DIEP": UiKit.SCHERM_DIEP,
		"selectierij": UiKit.INK.lightened(0.14),
	}
	for naam: String in op_donker:
		var v := _contrast(UiKit.GRIJS_OP_DONKER, op_donker[naam] as Color)
		_ok(v >= AA, "GRIJS_OP_DONKER haalt op %s maar %.2f:1, AA vraagt %.1f" % [naam, v, AA])

	for pad: String in _gd_bestanden("res://scripts"):
		var nr := 0
		for regel: String in FileAccess.get_file_as_string(pad).split("\n"):
			nr += 1
			var kaal := regel.replace("UiKit.GRIJS_OP_LICHT", "") \
				.replace("UiKit.GRIJS_OP_DONKER", "")
			if not kaal.contains("UiKit.GRIJS"):
				continue
			# Randen, balkvullingen en uitgeschakelde knoppen mogen GRIJS wel:
			# een uitgeschakeld element valt buiten WCAG 1.4.3, en een streep is
			# geen tekst. Alleen wat een letterkleur wordt is hier fout.
			_ok(not (kaal.contains("UiKit.label(") or kaal.contains("\"font_color\"")),
				"%s:%d zet UiKit.GRIJS als tekstkleur — gebruik GRIJS_OP_LICHT of GRIJS_OP_DONKER"
					% [pad, nr])


## Eén blauwe knop per minigamescherm, en een chrome die donker blijft.
##
## `UiKit.knop_primair()` werkt alleen zolang hij zeldzaam is: twee gevulde
## knoppen naast elkaar wijzen allebei nergens heen, en dan is de vorm terug bij
## waar hij vandaan kwam — een scherm waarop elke knop er hetzelfde uitziet.
## Twee minigames hebben er bewust nul (`mg_whack` is arcade, `mg_choicescene`
## is een keuzelijst waarin de keuze zelf de handeling is); de rest heeft er
## precies één. Dit telt dus een bovengrens en geen exact aantal.
##
## De tweede helft bewaakt het donkere oppervlak. `build_chrome()` bouwde een
## crème paneel terwijl de hele shell eromheen donker is; valt dat terug op de
## standaard van `UiKit.panel()`, dan is elke minigame weer het enige lichte
## scherm van het spel — en staan de secundaire regels van tien minigames in een
## grijstint die daar de norm niet haalt.
func _test_minigame_chrome() -> void:
	_kop("de chrome van de minigames")

	for pad: String in _gd_bestanden("res://scripts/minigames"):
		var n := 0
		for regel: String in FileAccess.get_file_as_string(pad).split("\n"):
			# Commentaar telt niet mee: `mg_oplevering.gd` legt in proza uit dat
			# zijn DEPLOYEN-knop deze stijl draagt.
			if regel.strip_edges().begins_with("#"):
				continue
			if regel.contains("UiKit.knop_primair("):
				n += 1
		_ok(n <= 1, "%s heeft %d primaire knoppen; er hoort er hoogstens één per scherm te zijn"
			% [pad, n])

	var bron := FileAccess.get_file_as_string("res://scripts/minigames/minigame_base.gd")
	_ok(bron.contains("UiKit.panel(UiKit.SCHERM_NACHT"),
		"build_chrome() bouwt geen donker oppervlak meer — de minigames vallen terug op crème")
	_ok(not bron.contains("UiKit.GRIJS_OP_LICHT"),
		"minigame_base.gd zet nog GRIJS_OP_LICHT op een donkere ondergrond")


## Relatieve luminantie volgens WCAG 2.x. Godot's `Color` bewaart sRGB-waarden,
## dus de gammastap hoort er hier bij; `srgb_to_linear()` zou hem overslaan.
static func _luminantie(c: Color) -> float:
	var kanaal := func(v: float) -> float:
		return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * float(kanaal.call(c.r)) \
		+ 0.7152 * float(kanaal.call(c.g)) \
		+ 0.0722 * float(kanaal.call(c.b))


static func _contrast(a: Color, b: Color) -> float:
	var la := _luminantie(a)
	var lb := _luminantie(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


## De navigatie: de kompasstrip leest de vloer uit, en de doelregel zegt de
## ruimte één keer.
##
## De strip tekent één pixel per tegel, dus zijn breedte ís de plattegrond. Komt
## dat getal ooit uit een constante in de HUD in plaats van uit `floor.json`,
## dan wijst hij na de eerstvolgende herindeling van de vloer stelselmatig naar
## de verkeerde kant — zonder fout, want een strip die te breed rekent tekent
## nog steeds een keurig streepje.
func _test_navigatie() -> void:
	_kop("navigatie: kompasstrip en doelregel")

	var maat: Variant = GameData.floor_data.get("size", null)
	_ok(maat is Array and (maat as Array).size() == 2, "floor.json heeft geen bruikbare `size`")
	if maat is Array and (maat as Array).size() == 2:
		var breed := int((maat as Array)[0])
		_ok(Hud.Kompas.vloerbreedte() == breed,
			"de kompasstrip rekent met %d tegels, floor.json zegt %d" % [
				Hud.Kompas.vloerbreedte(), breed])
		for z: Variant in (GameData.floor_data.get("zones", []) as Array):
			var d := z as Dictionary
			var r: Array = d.get("rect", [])
			_ok(r.size() == 4 and int(r[2]) < breed,
				"zone '%s' loopt voorbij de vloerbreedte en valt buiten de kompasstrip"
					% d.get("id", "?"))

	# De doelregel noemt de ruimte niet twee keer. Dit was
	# "Nu: BBD-204 · De Vloer · Haal Victor uit De Vloer" — twee keer dezelfde
	# plek in een regel van 184 px breed, die daardoor over twee regels viel.
	QuestEngine.start_run(&"daan")
	for tid: StringName in GameData.ticket_ids():
		var t: TicketDef = GameData.ticket(tid)
		if t.zone_name == "":
			continue
		var regel := "Nu:  %s%s" % [t.code, Hud._waarheen(t)]
		_ok(regel.count(t.zone_name) <= 1,
			"de doelregel van %s noemt '%s' meer dan eens: %s" % [
				t.code, t.zone_name, regel])


## De uitleg staat sinds kort op een eigen scherm vóór character select
## (IntroUitleg.LESSEN, scripts/ui/intro_uitleg.gd) in plaats van als dialoog
## bij het spawnen. Verlies daarvan geeft geen foutmelding: een woord dat
## wegvalt bij een volgende herschrijving is geen parse-fout, het is gewoon
## weer een speler die het niet snapt. Zie ook de 09:12-check in
## _test_urenstaat().
func _test_intro() -> void:
	_kop("introductie")

	var eigen := "\n".join(IntroUitleg.lessen())
	for les: String in [
			"Tien tickets", "naar buiten", "verspreid", "ticketbord", "collega"]:
		_ok(eigen.contains(les), "IntroUitleg.lessen() noemt niet meer: '%s'" % les)

	# Het getal in regel 3 moet de ticketdata volgen. Hier stond "Negen staan
	# meteen open" hard in de tekst terwijl F3-a er vier van had gemaakt: het
	# eerste en enige wat een speler over het keuzemechaniek te horen krijgt,
	# en het was onwaar. Deze test bindt het woord aan de data, zodat een
	# volgende herbalancering van `available_when` de tekst meesleept in plaats
	# van hem stil te laten liegen.
	var open_nu := IntroUitleg.open_bij_start()
	_ok(open_nu > 0 and open_nu < GameData.ticket_ids().size(),
		"open_bij_start() geeft %d van %d; klopt de available_when-keten nog?" % [
			open_nu, GameData.ticket_ids().size()])
	_ok(eigen.contains("%s staan meteen open" % IntroUitleg.TELWOORDEN[open_nu]),
		"de uitleg noemt niet '%s staan meteen open' terwijl er %d openstaan" % [
			IntroUitleg.TELWOORDEN[open_nu], open_nu])

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


## "Opnieuw beginnen" op het titelscherm is de enige destructieve knop in het
## spel: `Session.delete_saved_run()` gooit de bewaarde dag weg, zonder eigen
## bevestiging (die hoort bij de aanroeper, `title_screen.gd::_toon_bevestiging()`).
## Deze test bewaakt de functie zelf: hij moet echt verwijderen, en stil niets
## doen als er toch al niets lag.
func _test_save_verwijderen() -> void:
	_kop("een dag wissen (opnieuw beginnen)")

	var had_save := FileAccess.file_exists(Session.SAVE_PATH)
	var oude_save := FileAccess.get_file_as_string(Session.SAVE_PATH) if had_save else ""

	var f := FileAccess.open(Session.SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"character_id": "daan"}))
		f.close()
	_ok(Session.has_saved_run(), "kon geen testsave neerzetten om te verwijderen")

	Session.delete_saved_run()
	_ok(not FileAccess.file_exists(Session.SAVE_PATH),
		"delete_saved_run() liet het savebestand staan")
	_ok(not Session.has_saved_run(),
		"delete_saved_run() wiste het bestand, maar has_saved_run() zegt nog steeds ja")

	# Stil, geen foutmelding: een tweede keer wissen (of een race met een
	# andere opslag) mag niet klagen over een bestand dat al weg is.
	Session.delete_saved_run()

	# --- de echte titelscherm-overlay: opbouwen, annuleren, en de knop-
	# bedrading van "Ja" -----------------------------------------------------
	# `_op_wis_en_begin()` zelf wordt hier niet aangeroepen: die eindigt in
	# `Shell.goto_intro_uitleg()`, en een echte scenewissel middenin de
	# testsuite zou de testrunner-scene onder zichzelf vandaan trekken. De
	# bedrading (welke functie de knop aanroept) is wél te controleren zonder
	# hem uit te voeren.
	var f2 := FileAccess.open(Session.SAVE_PATH, FileAccess.WRITE)
	if f2 != null:
		f2.store_string(JSON.stringify({"character_id": "daan"}))
		f2.close()

	var scherm: Control = (load("res://scenes/boot/title.tscn") as PackedScene).instantiate()
	add_child(scherm)

	scherm.call("_toon_bevestiging")
	var overlay: Control = scherm.get("_bevestiging")
	_ok(overlay != null, "_toon_bevestiging() bouwt geen overlay op")

	scherm.call("_sluit_bevestiging")
	_ok(scherm.get("_bevestiging") == null,
		"_sluit_bevestiging() sluit de overlay niet")
	_ok(Session.has_saved_run(),
		"annuleren wiste de save alsnog — dat mag nooit")

	scherm.call("_toon_bevestiging")
	var wis_knop := _vind_knop(scherm.get("_bevestiging") as Control, "Ja, dag wissen")
	_ok(wis_knop != null, "geen wisknop gevonden in de bevestigingsoverlay")
	if wis_knop != null:
		var verbonden := false
		for c: Dictionary in wis_knop.pressed.get_connections():
			if (c["callable"] as Callable).get_method() == "_op_wis_en_begin":
				verbonden = true
		_ok(verbonden, "de wisknop roept niet _op_wis_en_begin() aan")
	scherm.call("_sluit_bevestiging")

	scherm.queue_free()

	if had_save:
		var g := FileAccess.open(Session.SAVE_PATH, FileAccess.WRITE)
		if g != null:
			g.store_string(oude_save)
			g.close()


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

	# De stand-up geeft een categorie-aanwijzing over wie iets te melden heeft
	# ("de collega die..."), nooit een naam — dat zou de afweging voor de
	# speler oplossen. Danny, de tweede belangrijke spreker, krijgt bewust
	# geen aanwijzing: hij moet ongemarkeerd blijven, dat is de enige verborgen
	# informatie in het spel.
	var st: Dictionary = MinigameContent.get_config(&"mg_planning")
	var brief_st := Briefing.regel(GameData.ticket(&"t02"))
	var eerste_belangrijke := {}
	for raw: Variant in (st.get("sprekers", []) as Array):
		var sp := raw as Dictionary
		var naam := String(sp.get("naam", ""))
		_ok(naam == "" or not brief_st.contains(naam),
			"de stand-up-briefing noemt %s bij naam, en verraadt zo wie je moet sparen" % naam)
		if eerste_belangrijke.is_empty() and bool(sp.get("belangrijk", false)):
			eerste_belangrijke = sp
	_ok(not eerste_belangrijke.is_empty(),
		"mg_planning heeft geen enkele belangrijke spreker")
	if not eerste_belangrijke.is_empty():
		var aanwijzing := String(eerste_belangrijke.get("aanwijzing", ""))
		_ok(aanwijzing != "",
			"de eerste belangrijke spreker (%s) heeft geen aanwijzing" % eerste_belangrijke.get("naam", "?"))
		_ok(aanwijzing != "" and brief_st.contains(aanwijzing),
			"de stand-up-briefing bevat niet de aanwijzing van de belangrijke spreker")

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


## F3-c: Dirk is gegeneraliseerd naar data/storingen.json. Deze test bewaakt
## de data-integriteit op dezelfde manier als _test_verwijzingen() dat voor
## tickets doet, en daarna de harde regel uit het faalbeleid: een storing kost
## tijd en informatie, nooit voortgang.
func _test_storingen() -> void:
	_kop("storingen")
	var defs := Storingen.laad()
	_ok(not defs.is_empty(), "data/storingen.json bevat geen enkele storing")

	var gezien_ids: Array[String] = []
	var soorten_gezien: Array[String] = []
	for d: Dictionary in defs:
		var id := String(d.get("id", ""))
		_ok(id != "", "storing zonder id")
		_ok(not (id in gezien_ids), "storing-id '%s' komt dubbel voor" % id)
		gezien_ids.append(id)

		var soort := String(d.get("soort", ""))
		_ok(not Storingen.unknown_soort(soort), "storing '%s': onbekende soort '%s'" % [id, soort])
		if not (soort in soorten_gezien):
			soorten_gezien.append(soort)

		var trig := d.get("trigger", {}) as Dictionary
		var bad_trig := Storingen.unknown_trigger_keys(trig)
		_ok(bad_trig.is_empty(), "storing '%s': onbekende trigger-key %s" % [id, bad_trig])

		var when := d.get("when", {}) as Dictionary
		var bad_when := Conditions.unknown_keys(when)
		_ok(bad_when.is_empty(), "storing '%s': onbekende conditie-key %s in 'when'" % [id, bad_when])

		var effects := d.get("effects", []) as Array
		var bad_fx := QuestEngine.unknown_effect_ops(effects)
		_ok(bad_fx.is_empty(), "storing '%s': onbekende effect-op %s" % [id, bad_fx])

		var wc := d.get("world_changes", []) as Array
		var bad_wc := WorldMutator.unknown_ops(wc)
		_ok(bad_wc.is_empty(), "storing '%s': onbekende world_change-op %s" % [id, bad_wc])
		for raw: Variant in wc:
			var c := raw as Dictionary
			var target := StringName(c.get("target", ""))
			if target != &"":
				_ok(GameData.has_world_id(target),
					"storing '%s': world_change wijst naar onbekende id '%s'" % [id, target])

		if soort == "npc_komt_langs":
			var npc_id := StringName(d.get("npc", ""))
			_ok(npc_id != &"", "storing '%s': npc_komt_langs zonder 'npc'-veld" % id)
			_ok(GameData.npc(npc_id) != null,
				"storing '%s': npc '%s' staat niet in npcs.json" % [id, npc_id])

		# reopen_ticket en unlock_ticket zijn de enige toegestane
		# state-mutaties op een ticket vanuit een storing, en allebei wijzen
		# ze altijd vooruit (naar AVAILABLE) — nooit terug naar LOCKED.
		for raw: Variant in effects:
			var e := raw as Dictionary
			var op := String(e.get("op", ""))
			if op == "reopen_ticket" or op == "unlock_ticket":
				var tid := StringName(e.get("ticket", ""))
				_ok(GameData.ticket(tid) != null,
					"storing '%s': %s wijst naar onbekend ticket '%s'" % [id, op, tid])

	_ok(gezien_ids.size() >= 3,
		"minder dan drie storingen: het plan vraagt om meerdere soorten (%d gevonden)" % gezien_ids.size())
	_ok("npc_komt_langs" in soorten_gezien, "geen enkele storing van het type 'npc_komt_langs'")
	_ok("iets_gaat_stuk" in soorten_gezien, "geen enkele storing van het type 'iets_gaat_stuk'")

	# --- de harde regel, uitgevoerd: elke storing die vuurt mag het geheel-
	# bereikbaar-blijven-invariant niet breken --------------------------------
	# Elk ticket staat al open, opgehaald en van zijn items voorzien; alles
	# staat daarna hard op DONE. Zo raakt reopen_ticket altijd een ticket dat
	# ook echt weer op te lossen is, in plaats van toevallig een ticket dat
	# nog LOCKED stond — en zo test dit precies de eigen state-mutatie van de
	# storing, los van of `trigger`/`when` hem ooit echt zouden laten afgaan.
	for d: Dictionary in defs:
		var id := String(d.get("id", ""))
		QuestEngine.start_run(&"daan")
		for tid: StringName in GameData.ticket_ids():
			QuestEngine.unlock(tid)
			QuestEngine.mark_helper_present(tid)
			var t: TicketDef = GameData.ticket(tid)
			for raw: Variant in (t.requirements.get("has_item", []) as Array):
				Session.add_item(StringName(raw))
		for tid: StringName in GameData.ticket_ids():
			Session.ticket_states[tid] = GameEnums.TicketState.DONE
			if not (tid in Session.done_order):
				Session.done_order.append(tid)

		QuestEngine.run_effects(d.get("effects", []) as Array)

		for tid: StringName in GameData.ticket_ids():
			var st := Session.ticket_state(tid)
			_ok(st != GameEnums.TicketState.LOCKED,
				"storing '%s' zet %s naar LOCKED — storingen mogen nooit voortgang blokkeren" % [id, tid])
			if st == GameEnums.TicketState.AVAILABLE or st == GameEnums.TicketState.ACTIVE:
				_ok(QuestEngine.requirements_met(tid),
					"storing '%s': %s staat open maar is niet op te lossen na de storing" % [id, tid])
		_ok(Session.is_done(&"t10") or QuestEngine.requirements_met(&"t10"),
			"storing '%s': de finale (t10) is niet meer haalbaar na de storing" % id)

	# --- F5-b: storingen tijdens een minigame -------------------------------
	# Frequentie is een ontwerpknop die als een echte constraint gebouwd moet
	# zijn (max één onderbreking per minigame, nooit in de eerste vijf
	# seconden) — dit test de zuivere gatingfunctie met een injecteerbare klok,
	# zodat er geen vijf reële seconden gewacht hoeft te worden.
	var storingen := Storingen.new()
	add_child(storingen)

	_ok(not storingen.mag_onderbreken_minigame(0.0),
		"mag_onderbreken_minigame(): staat 'ja' toe terwijl er geen minigame draait")

	# Dit test F5-b, niet MinigameIntro: het wat/waarom-scherm zou hier anders
	# ongezien blijven staan te wachten op een druk op "Starten" die in deze
	# synchrone test nooit komt.
	Session.set_flag(MinigameIntro.gezien_vlag(&"mg_paarden"), true)
	var lopend: Variant = Shell.call(&"run_minigame", &"mg_paarden", {})
	await get_tree().process_frame
	await get_tree().process_frame

	_ok(Shell.minigame_active(), "run_minigame(): minigame_active() bleef false — kan F5-b niet testen")
	var gestart := Time.get_ticks_msec() / 1000.0
	storingen._op_minigame_gestart(&"mg_paarden")  # zelfde pad als Bus.minigame_started

	_ok(not storingen.mag_onderbreken_minigame(gestart),
		"mag_onderbreken_minigame(): staat 'ja' toe op t=0 — de eerste vijf seconden horen met rust gelaten")
	_ok(not storingen.mag_onderbreken_minigame(gestart + Storingen.MIN_WACHT_MINIGAME_SEC - 0.01),
		"mag_onderbreken_minigame(): staat 'ja' toe vlak vóór de vijf seconden")
	_ok(storingen.mag_onderbreken_minigame(gestart + Storingen.MIN_WACHT_MINIGAME_SEC),
		"mag_onderbreken_minigame(): staat 'nee' terwijl er wél vijf seconden om zijn en er niets anders in de weg staat")

	# --- de echte routing: _vuur_eenmalig() moet storing() aanroepen op de
	# actieve minigame zodra het mag, en zijn eigen mutatie moet gewoon
	# doorgaan — nul nieuwe grammatica, storing() is de enige nieuwe oppervlakte.
	#
	# `_vuur_eenmalig()` roept `mag_onderbreken_minigame()` zelf zonder `nu` aan,
	# dus die kijkt op de ECHTE klok. `_mg_gestart_op` een heel eind terugzetten
	# (ver voorbij nul, niet zomaar "5 seconden vóór nu" — de suite draait in de
	# praktijk sneller dan 5 seconden real time, dus "nu min 5" kan zelf negatief
	# uitkomen) laat die aanroep ook zonder echt te wachten "ja" zeggen.
	# `_mg_actief` blijft intact (los veld, geen sentinel op het getal), dus dit
	# leest niet per ongeluk als "geen minigame gestart".
	storingen._mg_gestart_op = -1000.0
	var actief := Shell.active_minigame()
	_ok(actief != null, "active_minigame(): geeft niets terug terwijl mg_paarden loopt")
	var nep_storing := {
		"id": "test_storing_f5b",
		"soort": "afleiding",
		"dialogue": "Test: het weekend maakt weer lawaai.",
		"effects": [{"op": "kost_tijd", "minuten": 5, "reden": "afleiding"}],
	}
	var voor_minuten := Session.worked_minutes
	storingen._vuur_eenmalig(nep_storing)
	_ok(Session.worked_minutes == voor_minuten + 5,
		"_vuur_eenmalig(): de normale state-mutatie (kost_tijd) bleef uit toen er ook naar storing() geroute werd")
	if actief != null:
		var strook := actief.chrome_header()
		var gevonden := false
		for kind: Node in strook.find_children("*", "Label", true, false):
			if (kind as Label).text == "Test: het weekend maakt weer lawaai.":
				gevonden = true
		_ok(gevonden,
			"_vuur_eenmalig(): storing() landde niet zichtbaar in chrome_header() van de actieve minigame")
	_ok(not storingen.mag_onderbreken_minigame(gestart + 100.0),
		"mag_onderbreken_minigame(): staat een tweede onderbreking toe in dezelfde minigame-sessie")

	# Opruimen: de echte minigame afronden zoals qa_solve() dat ook zou doen.
	if actief != null:
		actief.succeed(100, {"qa": true})
	await lopend
	storingen.queue_free()
	_ok(not Shell.minigame_active(), "na afloop van de teststoring: minigame_active() moet weer false zijn")


## F5-a: het invoerslot en niet `get_tree().paused` eigent "de speler kan niet
## lopen". Vóór en na een minigame moeten `Session.input_locked` en
## `Shell.minigame_active()` allebei op false staan (geen lek van het slot), en
## `get_tree().paused` moet FALSE blijven terwijl de minigame loopt — dat is
## letterlijk het verschil dat F5-a maakt.
func _test_minigame_pauze() -> void:
	_kop("een minigame pauzeert het invoerslot, niet de wereld (F5-a)")

	_ok(not Session.input_locked, "input_locked stond al aan vóór de test — vervuilde staat")
	_ok(not Shell.minigame_active(), "er draaide al een minigame vóór de test — vervuilde staat")
	_ok(not get_tree().paused, "de tree stond al gepauzeerd vóór de test — vervuilde staat")

	# Zelfde reden als in _test_storingen(): dit test F5-a, niet MinigameIntro.
	Session.set_flag(MinigameIntro.gezien_vlag(&"mg_paarden"), true)
	var lopend: Variant = Shell.call(&"run_minigame", &"mg_paarden", {})

	_ok(Shell.minigame_active(), "run_minigame(): minigame_active() bleef false")
	_ok(Session.input_locked,
		"run_minigame(): input_locked bleef false — de speler kan dan gewoon wegwandelen")
	_ok(not get_tree().paused,
		"run_minigame(): de tree staat gepauzeerd — F5-a ontkoppelt dit juist van de minigame")

	# `run_minigame()` slikt zelf één process_frame vóór `mg.setup()` (om de
	# toetsaanslag te slikken waarmee de minigame gestart werd) en luistert pas
	# ná die frame naar `mg.finished`. Zonder deze wacht hier vuurt `succeed()`
	# hieronder `finished` af vóórdat `run_minigame()` daar zelf naar luistert
	# — een gemist signaal waar niemand ooit meer op wacht, en de `await lopend`
	# verderop hangt dan voor altijd.
	await get_tree().process_frame
	await get_tree().process_frame
	_ok(not get_tree().paused, "run_minigame(): na setup() staat de tree alsnog gepauzeerd")

	var actief := Shell.active_minigame()
	_ok(actief != null, "active_minigame(): geeft niets terug terwijl er een minigame loopt")

	# F5's kernbelofte: "geen klok kon tikken" was de klacht over het oude
	# pauzemodel, dus de wandklok moet nu wél doortikken terwijl deze minigame
	# open staat — ook al staat `Session.input_locked` aan (zie klok.gd).
	# `done_order` even leegmaken: eerdere tests (_test_storingen() hierboven)
	# laten alle tickets op DONE staan, en Klok._process() stopt terecht zodra
	# `Session.all_done()` — dat zou hier verkeerd als "klok tikt niet" lezen.
	var bewaarde_done_order := Session.done_order.duplicate()
	Session.done_order.clear()
	var klok := Klok.new()
	add_child(klok)
	var voor_klok := Session.worked_minutes
	klok._process(Klok.TICK_SEC)
	_ok(Session.worked_minutes == voor_klok + 1,
		"Klok._process(): tikt niet door terwijl een minigame open staat — F5's klok-belofte is gebroken")
	klok.queue_free()
	Session.done_order = bewaarde_done_order

	if actief != null:
		actief.succeed(100, {"qa": true})

	var result: MinigameResult = await lopend
	_ok(result != null and result.outcome == GameEnums.Outcome.SUCCESS,
		"run_minigame(): succeed() op de minigame leverde geen geslaagd MinigameResult op")
	_ok(not Shell.minigame_active(), "na afloop: minigame_active() moet weer false zijn")
	_ok(not Session.input_locked, "na afloop: input_locked moet weer false zijn — anders lekt het slot")
	_ok(Shell.active_minigame() == null, "na afloop: active_minigame() moet weer null zijn")

	# Achtervang uit Shell.pauzeer_voor_menu(): main.gd/Besturing voorkomen al
	# dat het pauzemenu tijdens een minigame opengaat, maar mocht iets die
	# functie ooit rechtstreeks aanroepen terwijl er een minigame loopt, dan
	# mag dat de tree niet aanraken (de menu-laag hoort sowieso nooit boven een
	# minigame te verschijnen — zie Pauzemenu's klassecommentaar).
	var lopend2: Variant = Shell.call(&"run_minigame", &"mg_paarden", {})
	await get_tree().process_frame
	await get_tree().process_frame
	Shell.pauzeer_voor_menu(true)
	_ok(not get_tree().paused,
		"pauzeer_voor_menu(true) tijdens een minigame pauzeerde de tree alsnog — de achtervang faalt")
	Shell.pauzeer_voor_menu(false)
	var actief2 := Shell.active_minigame()
	if actief2 != null:
		actief2.succeed(100, {"qa": true})
	await lopend2
	_ok(not Shell.minigame_active(), "opruimen van de tweede testminigame is niet gelukt")


## Het wat/waarom-scherm: de eerste keer verschijnt en blokkeert het tot er
## op "Starten" gedrukt wordt, een tweede keer voor hetzelfde id slaat het
## over, en "Terug" breekt af zonder de vlag te zetten (dus verschijnt het bij
## een volgende poging weer). `Autopilot.gevraagd()` leest de commandoregel
## rechtstreeks en is hier niet om te zetten — dat pad hoort bij de
## `--autoplay`-doorloop, niet bij deze suite.
func _test_minigame_intro_scherm() -> void:
	_kop("het wat/waarom-scherm vóór een minigame")

	QuestEngine.start_run(&"daan")   # wist Session.flags: mg_paarden telt als ongezien
	var vlag := MinigameIntro.gezien_vlag(&"mg_paarden")
	_ok(not Session.get_flag(vlag), "vervuilde staat: mg_paarden gold al als gezien")

	# --- eerste keer: het scherm verschijnt en blokkeert -----------------
	var lopend: Variant = Shell.call(&"run_minigame", &"mg_paarden", {})
	await get_tree().process_frame
	await get_tree().process_frame
	_ok(not Shell.minigame_active(),
		"run_minigame(): de minigame draait al vóór het wat/waarom-scherm bevestigd is")
	var poort: MinigameIntro = get_tree().get_first_node_in_group(&"minigame_intro")
	_ok(poort != null, "run_minigame(): geen MinigameIntro-node gevonden bij een ongezien id")

	if poort != null:
		poort.besloten.emit(true)
		await get_tree().process_frame
		await get_tree().process_frame
		_ok(Shell.minigame_active(),
			"MinigameIntro.besloten(true): de minigame startte niet na 'Starten'")
		_ok(Session.get_flag(vlag), "MinigameIntro.besloten(true): de gezien-vlag staat niet")
		var actief := Shell.active_minigame()
		if actief != null:
			actief.succeed(100, {"qa": true})
		await lopend

	# --- tweede keer: hetzelfde id slaat het scherm over ------------------
	var lopend2: Variant = Shell.call(&"run_minigame", &"mg_paarden", {})
	await get_tree().process_frame
	await get_tree().process_frame
	_ok(Shell.minigame_active(),
		"run_minigame(): een gezien id toont het wat/waarom-scherm alsnog")
	_ok(get_tree().get_first_node_in_group(&"minigame_intro") == null,
		"run_minigame(): een gezien id maakt toch een MinigameIntro-node aan")
	var actief2 := Shell.active_minigame()
	if actief2 != null:
		actief2.succeed(100, {"qa": true})
	await lopend2

	# --- "Terug": afbreken zonder de vlag te zetten ------------------------
	QuestEngine.start_run(&"daan")   # opnieuw ongezien
	Shell.call(&"run_minigame", &"mg_paarden", {})
	await get_tree().process_frame
	await get_tree().process_frame
	var poort2: MinigameIntro = get_tree().get_first_node_in_group(&"minigame_intro")
	_ok(poort2 != null, "run_minigame(): geen MinigameIntro-node gevonden voor de 'Terug'-poging")
	if poort2 == null:
		return
	poort2.besloten.emit(false)

	# Niet `await` op het teruggegeven MinigameResult van deze derde
	# Shell.call() in dezelfde functie: dat bleek in de praktijk niet
	# betrouwbaar op te lossen voor dit afbreekpad (`run_minigame()` rondt
	# zijn eigen cleanup en `return` intern gegarandeerd af — bevestigd met
	# print-debugging — maar de aanroeper hier ving die voltooiing soms niet
	# op). We wachten daarom een begrensd aantal frames op het zichtbare
	# resultaat in plaats van op de retourwaarde zelf, zodat deze test nooit
	# voor altijd kan blijven hangen.
	var pogingen := 0
	while Session.input_locked and pogingen < 30:
		await get_tree().process_frame
		pogingen += 1
	_ok(pogingen < 30, "MinigameIntro.besloten(false): input_locked bleef aanstaan na 30 frames")
	_ok(not Session.get_flag(vlag),
		"MinigameIntro.besloten(false): de gezien-vlag staat alsnog — 'Terug' mag geen 'gezien' zijn")
	_ok(not Shell.minigame_active(), "na 'Terug': minigame_active() moet false blijven")
	_ok(not Session.input_locked, "na 'Terug': input_locked moet weer false zijn")


## F3-d: de klok tikt door met de speeltijd. Bewaakt dat dit (a) het spel niet
## onwinbaar kan maken, ongeacht hoe lang iemand blijft rondlopen, en (b) de
## `overwerk`-conditie daadwerkelijk bereikbaar maakt binnen een sessie van de
## bedoelde lengte, in plaats van alleen in theorie te bestaan.
func _test_klok() -> void:
	_kop("de klok")

	# --- de harde regel: een volle dag klok-tikken mag het spel niet
	# onwinbaar maken, net als de 10000-minuten-boeking in _test_urenstaat()
	# hierboven, maar dan via precies het pad waarlangs de klok zelf tikt. ---
	QuestEngine.start_run(&"daan")
	for tid: StringName in GameData.ticket_ids():
		QuestEngine.unlock(tid)
		QuestEngine.mark_helper_present(tid)
		var t: TicketDef = GameData.ticket(tid)
		for raw: Variant in (t.requirements.get("has_item", []) as Array):
			Session.add_item(StringName(raw))
	for _i in range(1440):
		Session.book_time(1, &"verloop")
	_ok(Session.worked_minutes >= 1440, "1440 klok-tikken van 1 minuut leveren geen 1440 minuten op")
	_ok(Urenstaat.is_overwerk(), "een dag van 24 uur klok-tikken is geen overwerk")
	for tid: StringName in GameData.ticket_ids():
		_ok(QuestEngine.requirements_met(tid),
			("%s is niet meer op te lossen na een volle dag klok-tikken; de klok mag het spel " +
			"nooit onwinbaar maken") % GameData.ticket(tid).code)
	_ok(Session.is_available(&"t10") or Session.is_done(&"t10"),
		"de finale (t10) is niet meer bereikbaar na een volle dag klok-tikken")

	# --- de klok maakt overwerk ook echt bereikbaar binnen een sessie van de
	# bedoelde lengte, niet pas na freewheelen. Bij 1 in-game minuut per
	# Klok.TICK_SEC seconden duurt het BUDGET_MIN minuten om voorbij de acht
	# uur te komen; dat hoort ruim binnen de ~25 minuten reëel uit het plan te
	# vallen (en de eerste tickets boeken zelf ook al mee, dus in de praktijk
	# eerder). ------------------------------------------------------------
	var sec_tot_overwerk: float = float(Urenstaat.BUDGET_MIN) * Klok.TICK_SEC
	_ok(sec_tot_overwerk <= 25.0 * 60.0,
		("overwerk duurt %.0f reële seconden pure klok-tikken om te bereiken — dat past niet " +
		"meer binnen een speelsessie van orde-grootte 25 minuten") % sec_tot_overwerk)

	# --- en de vier dialoogvarianten die op 'overwerk' letten, zijn dan ook
	# geen dode data (zie _test_geen_dode_data() voor het bredere principe):
	# als de klok nooit voorbij BUDGET_MIN komt zonder dat de speler zelf
	# blijft freewheelen, valt geen van deze varianten ooit. -----------------
	var overwerk_varianten := 0
	for key: Variant in GameData.dialogues.keys():
		var def: DialogueDef = GameData.dialogue(StringName(key))
		for nid: Variant in def.nodes.keys():
			var node := def.node(StringName(nid))
			for raw: Variant in (node.get("variants", []) as Array):
				var v := raw as Dictionary
				if bool((v.get("when", {}) as Dictionary).get("overwerk", false)):
					overwerk_varianten += 1
	_ok(overwerk_varianten >= 4,
		"verwacht minstens vier dialoogvarianten die op 'overwerk' letten, gevonden %d" % overwerk_varianten)


## BBD-204 · `mg_uitlijnen`: bewijst de datafix, niet alleen dat de suite
## toevallig doorloopt. De bug zat hierin: de stapgrootte (`raster`) en de
## `afwijking` van elk blok deelden geen rest, dus geen enkel blok kon via
## hele rasterstappen exact op nul uitkomen en `perfect` viel nooit — Victors
## enige gevolg was dood. Dit draait de echte minigame, sleept elk blok met de
## eigen `_op_aanraking()`/`_op_sleep()`/`_op_los()`-handlers (dezelfde route
## als een speler met een vinger) precies naar zijn rasterpunt, en toetst dan
## `rest()` zelf — de exacte functie waarmee `_afronden()` `perfect` bepaalt —
## in plaats van er alleen op te vertrouwen dat de puzzel "voelt" als opgelost.
func _test_uitlijnen_perfect() -> void:
	_kop("uitlijnen: een exacte sleep maakt perfect haalbaar")

	var packed: PackedScene = load("res://scenes/minigames/mg_uitlijnen.tscn")
	var mg: MinigameBase = packed.instantiate() as MinigameBase
	mg.minigame_id = &"mg_frontend_fix"
	add_child(mg)
	mg.setup({})

	var raster: int = int(mg.get("_raster"))
	var volgorde: Array = mg.get("_volgorde")
	var blokken: Dictionary = mg.get("_blokken")
	_ok(not volgorde.is_empty(), "mg_frontend_fix: geen elementen geladen voor de testronde")

	for id: Variant in volgorde:
		var blok: Object = blokken[id]
		var thuis: Vector2 = blok.get("thuis")
		var vooraf: Vector2 = blok.call("rest", raster)
		_ok(not vooraf.is_zero_approx(),
			"%s: begint al op nul, dus deze ronde bewijst niets over de datafix" % id)

		# Eén doorlopende aanraking, precies zoals een vinger op het scherm: neer
		# op het midden van het blok (de blokken staan nog op hun scheve
		# beginplek en overlappen elkaar daar deels, dus een hoekpunt kan
		# per ongeluk het verkeerde blok raken), dan naar zijn rasterpunt
		# (`thuis`) met dezelfde grip en los. Met een consistente grip valt
		# `_greep` weg uit de som, dus het slepunt bepaalt de uitkomst direct.
		var midden: Vector2 = blok.get("maat") / 2.0
		var vanaf: Vector2 = (blok.get("position") as Vector2) + midden
		mg.call("_op_aanraking", vanaf)
		mg.call("_op_sleep", thuis + midden)
		mg.call("_op_los")

		var na: Vector2 = blok.call("rest", raster)
		_ok(na.is_zero_approx(),
			"%s: een exacte sleep laat %s over in plaats van (0, 0) — perfect valt nog steeds nooit" % [
				id, na])
		_ok(bool(blok.get("vast")),
			"%s: staat na een exacte sleep niet 'vast', terwijl de rest al op nul staat" % id)

	mg.queue_free()


## F4-b: BBD-203, BBD-205, BBD-207 en BBD-209 lossen op dóór in de wereld te
## handelen, niet meer via een afgesloten minigame-overlay. Zonder
## deze test kan een vijfde `wereldhandeling`-ticket stil op de
## `push_error`-tak van `TicketController._resolve_wereldhandeling()` belanden
## — onzichtbaar tot een echte speelbeurt erop stuit — of kan het paarden-drietal
## uit `data/npcs.json` uit elkaar groeien met wat BBD-209 verwacht.
func _test_wereldhandelingen() -> void:
	_kop("wereldhandelingen (F4-b)")

	# Elke minigame_id die TicketController._resolve_wereldhandeling() echt
	# herkent. Twee kanten op bewaakt: een ticket dat wereldhandeling:true
	# draagt zonder hier te staan, én andersom.
	const BEKEND: Array[StringName] = [
		&"mg_klantfeedback", &"mg_backend_fix", &"mg_muziek", &"mg_paarden",
	]
	for id: StringName in GameData.ticket_ids():
		var t: TicketDef = GameData.ticket(id)
		if t.wereldhandeling:
			_ok(t.minigame_id in BEKEND,
				"%s: wereldhandeling:true maar '%s' heeft geen resolver" % [t.code, t.minigame_id])
		else:
			_ok(not (t.minigame_id in BEKEND),
				"%s: '%s' heeft een wereldhandeling-resolver, maar wereldhandeling staat niet aan" % [
					t.code, t.minigame_id])

	# De vier bekende eigenaren: een wereldhandeling is geen degradatie, het is
	# nog steeds een werkwoord uit de mond van de eigenaar.
	var verwacht_eigenaar := {
		&"t03": &"willem", &"t05": &"jonathan", &"t07": &"danny", &"t09": &"bastiaan",
	}
	for id: StringName in verwacht_eigenaar.keys():
		var t: TicketDef = GameData.ticket(id)
		_ok(t.wereldhandeling, "%s hoort een wereldhandeling te zijn" % t.code)
		_ok(t.owner_character == verwacht_eigenaar[id],
			"%s: eigenaar is '%s', verwacht '%s'" % [t.code, t.owner_character, verwacht_eigenaar[id]])

	# De paarden zelf: ze bestaan, en t09 ruimt ze op als hij afrond — anders
	# blijven ze na "opgelost" nog over de vloer dwalen.
	var paarden: Array[StringName] = [&"paard_bug_1", &"paard_bug_2", &"paard_klant_decoy"]
	for nid: StringName in paarden:
		_ok(GameData.npc(nid) != null, "npc '%s' ontbreekt uit data/npcs.json" % nid)

	var despawnd: Array[String] = []
	for raw: Variant in GameData.ticket(&"t09").world_changes:
		var c := raw as Dictionary
		if String(c.get("op", "")) == "despawn_npc":
			despawnd.append(String(c.get("npc", "")))
	for nid: StringName in paarden:
		_ok(String(nid) in despawnd, "t09 despawnt '%s' niet in zijn world_changes" % nid)


## F4-a: `mg_slotboard.gd` (de urenstaat, `mg_urenstaat`) werd een dialoogkeuze
## met drie kant-en-klare tijdverdelingen in plaats van een sleepspel met 22
## elementen. `ticket_controller.gd::_urenstaat()` en `_dirk_oordeel()` lezen
## drie sleutels uit de payload — `geboekt_min`, `op_rest`, `lege_tickets` —
## en dat contract mag een presentatiewijziging niet stilletjes breken.
func _test_urenstaat_scherm() -> void:
	_kop("de urenstaat als dialoogkeuze (F4-a)")

	QuestEngine.start_run(&"daan")
	Session.done_order.clear()
	for i: int in 4:
		Session.done_order.append(GameData.ticket_ids()[i])

	var packed: PackedScene = load("res://scenes/minigames/mg_slotboard.tscn")
	var mg: MinigameBase = packed.instantiate() as MinigameBase
	mg.minigame_id = &"mg_urenstaat"
	add_child(mg)
	mg.setup({})

	var opties: Array = mg.content().get("opties", [])
	_ok(opties.size() == 3, "mg_urenstaat: geen drie voorgestelde verdelingen")

	# Elke voorgestelde verdeling rekent zelf uit tegen de vier tickets die
	# hierboven als "vandaag afgerond" zijn opgezet, en moet daarbij de drie
	# sleutels leveren die Dirk leest, met waarden die bij de naam van de
	# optie passen.
	for id: String in ["tickets", "eerlijk", "overig"]:
		var v: Dictionary = mg.call("_verdeling", id)
		for sleutel: String in ["geboekt_min", "op_rest", "lege_tickets"]:
			_ok(v.has(sleutel), "urenstaat/%s: payload mist '%s'" % [id, sleutel])
		_ok(int(v.get("geboekt_min", -1)) == Urenstaat.BUDGET_MIN,
			"urenstaat/%s: geboekt_min is %s, en een dag is altijd %d minuten" % [
				id, v.get("geboekt_min"), Urenstaat.BUDGET_MIN])
		_ok(int(v.get("lege_tickets", -1)) >= 0, "urenstaat/%s: lege_tickets is negatief" % id)

		match id:
			"tickets":
				_ok(int(v.get("op_rest", -1)) == 0,
					"urenstaat/tickets: 'vooral op de tickets zelf' laat nog %s minuten op overig staan" %
						v.get("op_rest"))
			"eerlijk":
				_ok(int(v.get("op_rest", -1)) > 0 and int(v.get("op_rest", 0)) < 4 * 60,
					"urenstaat/eerlijk: 'een eerlijke spreiding' hoort niet op 0 en niet op Dirks " +
						"vraagteken-drempel uit te komen (%s min)" % v.get("op_rest"))
			"overig":
				_ok(int(v.get("op_rest", 0)) >= 4 * 60,
					"urenstaat/overig: 'veel op overig' haalt Dirks vraagteken-drempel niet (%s van de %d min)" % [
						v.get("op_rest"), 4 * 60])

		# Dirk accepteert per code toch alles, maar zijn regel mag op geen van
		# de drie combinaties leeg blijven of crashen.
		var oordeel := TicketController._dirk_oordeel(v)
		_ok(oordeel != "", "urenstaat/%s: Dirk heeft niets te zeggen" % id)
		# En hij moet er ook als Dirk klinken. Deze vier regels stonden als
		# string in ticket_controller.gd en waren daarmee de enige tekst in het
		# spel die _test_karakterstemmen() niet las -- drie van de vier droegen
		# geen enkele van zijn tics. Nu komen ze uit `dirk_urenstaat`, en deze
		# controle houdt ze daar.
		var klinkt_als_dirk := false
		for t: Variant in (TICS["dirk"] as Array):
			if String(t) in oordeel.to_lower():
				klinkt_als_dirk = true
				break
		_ok(klinkt_als_dirk,
			"urenstaat/%s: Dirks slotregel draagt geen enkele van zijn tics: \"%s\"" % [id, oordeel])
		# {naam} blijft hier bewust staan: die vult DialogueController.vul_in()
		# vlak voor het renderen. Deze twee komen uit de payload en horen hier
		# al weg te zijn.
		_ok(not oordeel.contains("{rest}") and not oordeel.contains("{aantal}"),
			"urenstaat/%s: onvervangen payload-token in Dirks slotregel: \"%s\"" % [id, oordeel])

	# En de echte weg: een tik op een keuze moet via de echte MinigameResult
	# dezelfde drie sleutels opleveren, niet alleen de rekenfunctie op zich.
	mg.call("_kies", opties[0] as Dictionary)
	var result: MinigameResult = await mg.finished
	_ok(result.outcome == GameEnums.Outcome.SUCCESS,
		"urenstaat: een dialoogkeuze levert geen geslaagde MinigameResult op")
	for sleutel2: String in ["geboekt_min", "op_rest", "lege_tickets"]:
		_ok(result.payload.has(sleutel2), "urenstaat: MinigameResult.payload mist '%s'" % sleutel2)
	_ok(int(result.payload.get("geboekt_min", 0)) == Urenstaat.BUDGET_MIN,
		"urenstaat: de echte flow boekt geen volle dag")

	mg.queue_free()


## Het dialoogvenster blijft binnen het scherm, hoe lang de regel ook is.
##
## `DialogueBox` zet het paneel vast aan de ONDERrand (anchor 1.0, onderkant op
## MARGE_ONDER) en rekent de bovenrand terug uit de gemeten inhoud. Twee dingen
## konden dat onderuithalen, en samen deden ze dat ook:
##
##   1. `grow_vertical` stond op de standaard END. Een Control kan niet kleiner
##      dan zijn `get_combined_minimum_size()`; wordt hij opgerekt, dan gebeurt
##      dat in de groeirichting. Naar beneden, vanaf 8px boven de bodem.
##   2. `fit_content` bleef aan, ook boven HOOGTE_MAX. Het label meldde zijn
##      volledige teksthoogte als minimum, dus de clamp op HOOGTE_MAX klemde
##      niets: het paneel werd zo hoog als de tekst en schoof het beeld uit.
##
## Dit is een zichtbare bug zonder foutmelding -- de regel is er gewoon niet
## meer -- en hij treft juist de langste teksten, die het spel bewust heeft
## (Dirks urenstaatregels, de briefing van de eigenaar). Vandaar een meting op
## de echte node in plaats van een constante-vergelijking.
func _test_dialoogvenster_past() -> void:
	_kop("het dialoogvenster past op het scherm")

	var box := DialogueBox.new()
	add_child(box)
	await get_tree().process_frame

	var vp: float = get_viewport().get_visible_rect().size.y
	var paneel := box.get_child(0) as Control

	# Van kort tot absurd. De laatste twee kunnen in het echte spel niet
	# voorkomen; ze staan er zodat de rand van het gedrag gemeten wordt en niet
	# alleen het geval dat toevallig nu past.
	var gevallen := {
		"korte regel": "Ik ben iets te vroeg. Dat doe ik altijd.",
		"Dirk, volledig": "Hoi Daan, even een klein seintje. Er staat vandaag tot nu " +
			"toe 0u geboekt, terwijl de verwachting rond de 4u ligt. Zou je je uren " +
			"aanvullen als er nog wat mist? Alvast bedankt!",
		"twee keer Dirk": ("Er staat vandaag tot nu toe 0u geboekt, terwijl de " +
			"verwachting rond de 4u ligt. ").repeat(2),
		"absurd lang": "Het logo mag groter, maar niet te groot. ".repeat(12),
	}

	for naam: String in gevallen:
		var tekst := String(gevallen[naam])
		box.show_line("Mevrouw P. Aardenmens", tekst, null)
		# Twee frames: `_pas_hoogte_aan()` meet zelf pas ná een layout-pass.
		await get_tree().process_frame
		await get_tree().process_frame
		var top: float = paneel.global_position.y
		var onder: float = top + paneel.size.y
		_ok(onder <= vp + 0.5,
			"dialoogvenster (%s, %d tekens) loopt %.0f px onder het scherm door" % [
				naam, tekst.length(), onder - vp])
		_ok(top >= -0.5,
			"dialoogvenster (%s) begint %.0f px boven het scherm" % [naam, -top])
		_ok(paneel.size.y <= DialogueBox.HOOGTE_MAX + 0.5,
			"dialoogvenster (%s) is %.0f px hoog, HOOGTE_MAX zegt %.0f" % [
				naam, paneel.size.y, DialogueBox.HOOGTE_MAX])

	# En met keuzeknoppen erbij, want die groeien onder de tekst aan en lopen
	# via dezelfde meting.
	box.show_line("", String(gevallen["Dirk, volledig"]), null)
	await get_tree().process_frame
	box.show_choices(["Ik vul ze aan.", "Ik doe het morgen.", "Ik boek nu."] as Array[String])
	await get_tree().process_frame
	await get_tree().process_frame
	var onder_keuzes: float = paneel.global_position.y + paneel.size.y
	_ok(onder_keuzes <= vp + 0.5,
		"dialoogvenster met drie keuzes loopt %.0f px onder het scherm door" % (onder_keuzes - vp))

	# De hoogte moet ook weer terug kunnen: een lange regel mag het venster niet
	# permanent opgeblazen achterlaten voor de korte regel erna.
	box.show_line("", "Done.", null)
	await get_tree().process_frame
	await get_tree().process_frame
	_ok(paneel.size.y <= DialogueBox.HOOGTE_MIN + 0.5,
		"na een lange regel blijft het venster %.0f px hoog voor 'Done.', HOOGTE_MIN is %.0f" % [
			paneel.size.y, DialogueBox.HOOGTE_MIN])

	box.queue_free()


## Een wervingsgesprek begint met de hulpvraag, en met het ticketnummer erin.
##
## Alle negen bomen openden op een wedervraag van de collega — "Welke pagina?",
## "Wat staat er?", "hoeveel,," — alsof hij al wist waarvoor je kwam. De speler
## zei nooit waar hij voor vastliep, en het ticket werd niet genoemd. Dat is de
## meest herhaalde scène van het spel (voor bijna elk ticket haal je iemand op)
## en juist daar ontbrak het waarom.
##
## Twee eisen. De openingsnode is van de speler en noemt de ticketcode, en elk
## personage dat deze werving kán spelen heeft er zijn eigen regel — een
## gedeelde fallback op de meest herhaalde scène is precies de vlakheid die
## hier weg moest.
func _test_werving_begint_met_de_vraag() -> void:
	_kop("een werving begint met de hulpvraag")
	var speelbaar := GameData.character_ids()

	for id: StringName in GameData.ticket_ids():
		var t: TicketDef = GameData.ticket(id)
		if t.owner_character == &"" or not t.dialogue_ids.has(&"recruit"):
			continue
		var did := StringName(t.dialogue_ids[&"recruit"])
		var def: DialogueDef = GameData.dialogue(did)
		if def == null:
			continue

		var open_node := def.node(def.start_node)
		_ok(String(open_node.get("speaker", "")) == "speler",
			"%s — %s opent op '%s' en niet op de speler; dan vraagt niemand om hulp"
				% [t.code, did, open_node.get("speaker", "")])

		var varianten := open_node.get("variants", []) as Array
		_ok(not varianten.is_empty(), "%s — %s: openingsnode zonder varianten" % [t.code, did])

		var gedekt: Array[StringName] = []
		for raw: Variant in varianten:
			var v := raw as Dictionary
			var tekst := String(v.get("text", ""))
			_ok(tekst.contains(t.code),
				"%s — %s: openingsregel noemt het ticket niet: \"%s\"" % [t.code, did, tekst])
			for c: Variant in ((v.get("when", {}) as Dictionary).get("character", []) as Array):
				gedekt.append(StringName(String(c)))

		# Iedereen behalve de eigenaar; die haalt zichzelf nooit op.
		for cid: StringName in speelbaar:
			if cid == t.owner_character:
				continue
			_ok(cid in gedekt,
				"%s — %s: %s heeft geen eigen hulpvraag en valt terug op de algemene regel"
					% [t.code, did, cid])


## De Klant is één persoon, over twee kanalen.
##
## Haar pushberichten (`klant_berichten.json`) volgden de character bible al —
## de schoonzus die heeft meegekeken, de neef die zei dat het in een weekend
## kan — maar de vrouw die in de entree zit had een kleinzoon en een echtgenoot
## met een hoveniersbedrijf. Dat zijn twee verschillende mensen die toevallig
## dezelfde manege bezitten, en het lopende geintje (twee UX-reviewers met
## onbeperkt gezag en nul verantwoordelijkheid) valt daarmee uit elkaar.
func _test_klant_is_een_persoon() -> void:
	_kop("de klant is één persoon")

	const VERBODEN: Array[String] = ["kleinzoon", "hovenier", "mijn man", "haar man", "echtgenoot"]
	var gesproken := ""
	for key: Variant in GameData.dialogues.keys():
		var def: DialogueDef = GameData.dialogue(StringName(key))
		for nid: Variant in def.nodes.keys():
			var n := def.node(StringName(nid))
			var basis := String(n.get("speaker", ""))
			var regels: Array[String] = []
			if basis == "klant":
				regels.append(String(n.get("text", "")))
			for raw: Variant in n.get("variants", []):
				var v := raw as Dictionary
				if String(v.get("speaker", basis)) == "klant":
					regels.append(String(v.get("text", "")))
			for regel: String in regels:
				gesproken += " " + regel
				for woord: String in VERBODEN:
					_ok(not regel.to_lower().contains(woord),
						"%s/%s: de klant noemt '%s'; haar reviewers zijn de schoonzus en de neef"
							% [key, nid, woord])

	# En ze noemt ze ook echt, in beide kanalen.
	var telefoon := FileAccess.get_file_as_string("res://data/klant_berichten.json").to_lower()
	for wie: String in ["schoonzus", "neef"]:
		_ok(gesproken.to_lower().contains(wie),
			"de klant noemt haar %s nergens in de entree" % wie)
		_ok(telefoon.contains(wie),
			"de klant noemt haar %s nergens op de telefoon" % wie)


# --- Ticketstroom-audit: vier controles op de gaten die groen bleven ------
#
# De suite stond groen terwijl een opgelost ticket letterlijk "t01_done" in de
# dialoogbox zette en elke doorloop elf oplossingen kostte voor tien tickets.
# Deze vier dekken die gaten.


## Elke dialoog-id die de speler kan raken hoort een dialoog te *spelen* en niet
## als tekst geprint te worden.
##
## `_test_dialoog()` controleert al dat elke gerefereerde id bestáát. Dat was
## precies het gat: `TicketController._dlg()` geeft een id terug zodra de sleutel
## bestaat, en `_line()` zette dat rechtstreeks in de box. Alle tien de
## `done`-sleutels bestaan, dus alle tien de tickets printten hun eigen id.
func _test_dialoog_speelt_niet_zijn_eigen_id() -> void:
	_kop("dialoog-ids worden gespeeld, niet geprint")

	# Commentaarregels eruit, anders vindt deze controle de uitleg erboven —
	# waarin het foute patroon met opzet geciteerd staat — en faalt hij op zijn
	# eigen documentatie.
	var code := ""
	for regel: String in FileAccess.get_file_as_string(
			"res://scripts/world/ticket_controller.gd").split("\n"):
		if not regel.strip_edges().begins_with("#"):
			code += regel + "\n"

	# `_play_or_line(_dlg(` eerst wegstrepen: die naam eindigt op `_line(_dlg(`,
	# dus een kale substring-zoektocht vindt juist de góede aanroep.
	code = code.replace("_play_or_line(_dlg(", "OK(")

	_ok(not code.contains("_line(_dlg("),
		"ticket_controller.gd geeft een _dlg()-id aan _line(); dat print de id als tekst — gebruik _play_or_line()")
	for sleutel: String in ["done", "locked", "fetch", "blocked"]:
		_ok(not code.contains('_line(_dlg(t, &"%s"' % sleutel),
			"de '%s'-regel gaat nog via _line() en print dus zijn dialoog-id" % sleutel)


## `done_count()` mag binnen één `complete()` nooit dalen.
##
## Dat gebeurde wel: een storing hangt aan `Bus.flag_changed`, `time_booked` en
## `ticket_completed`, en die vuren alle drie *binnen* `complete()`. De storing
## riep dan `reopen()` aan met zijn `done_order.erase()` terwijl `complete()` nog
## halverwege was. In een echte doorloop stond de teller na BBD-207 nog op 5, en
## werd BBD-205 later een tweede keer opgelost.
func _test_teller_daalt_niet_binnen_complete() -> void:
	_kop("de teller daalt niet tijdens een oplevering")

	# Meet niet op `ticket_state_changed` — dat signaal valt in `complete()`
	# vóór de `done_order.append()`, dus op dat moment staat de teller
	# legitiem nog op de oude waarde. Wat de bug wél kenmerkt is dat een ánder
	# ticket zijn DONE verliest tijdens de oplevering, en dat de teller met
	# meer of minder dan precies één opschuift.
	QuestEngine.start_run(&"daan")

	for id: StringName in GameData.ticket_ids():
		if not Session.is_available(id):
			continue
		var voor := Session.done_count()
		var was_done: Array[StringName] = Session.done_order.duplicate()

		QuestEngine.complete(id, MinigameResult.make(
			GameData.ticket(id).minigame_id, GameEnums.Outcome.SUCCESS))

		_ok(Session.done_count() == voor + 1,
			"%s: teller ging van %d naar %d in plaats van naar %d — er is tijdens de oplevering iets heropend"
				% [GameData.ticket(id).code, voor, Session.done_count(), voor + 1])
		for eerder: StringName in was_done:
			_ok(Session.is_done(eerder),
				"%s: het opleveren van %s zette %s terug naar open"
					% [GameData.ticket(id).code, GameData.ticket(id).code,
						GameData.ticket(eerder).code])


## Een tweede oplevering van hetzelfde ticket deelt de beloning niet opnieuw uit.
##
## `complete()` bewaakt met `is_done()`, en die staat na een `reopen()` weer op
## false — dus `run_effects()` draaide een tweede keer en elke doorloop eindigde
## met `productdata` op aantal 2. `kost_tijd` en de presentatie-ops horen juist
## wél opnieuw te draaien.
func _test_tweede_oplevering_betaalt_niet_opnieuw() -> void:
	_kop("heropleveren betaalt niet twee keer")

	QuestEngine.start_run(&"daan")
	var t: TicketDef = GameData.ticket(&"t05")
	var resultaat := MinigameResult.make(t.minigame_id, GameEnums.Outcome.SUCCESS)

	QuestEngine.complete(&"t05", resultaat)
	var na_eerste := Session.item_count(&"productdata")
	_ok(na_eerste == 1,
		"eerste oplevering van BBD-205 gaf %d productdata in plaats van 1" % na_eerste)
	_ok(&"t05" in Session.beloond, "BBD-205 staat na oplevering niet in Session.beloond")

	QuestEngine.reopen(&"t05")
	_ok(not Session.is_done(&"t05"), "reopen() zette BBD-205 niet terug naar open")
	_ok(&"t05" in Session.beloond, "reopen() wiste de beloningsregistratie van BBD-205")

	var uren_voor := Session.worked_minutes
	QuestEngine.complete(&"t05", resultaat)
	_ok(Session.item_count(&"productdata") == na_eerste,
		"tweede oplevering van BBD-205 deelde productdata opnieuw uit (%d)"
			% Session.item_count(&"productdata"))
	_ok(Session.worked_minutes > uren_voor,
		"tweede oplevering van BBD-205 kostte geen tijd; opnieuw werken hoort opnieuw tijd te kosten")


## De ticketketen is bereikbaar en volledig afgeleid uit `available_when`.
##
## `unlocks` was een gebeurtenis: hij draaide één keer bij het opleveren en werd
## na het laden nooit herspeeld, terwijl `world_changes` dat wél worden. Een
## ticket achter een al-opgeleverd ticket stond na het laden dus permanent op
## LOCKED en `all_done()` was onhaalbaar — zonder crash of waarschuwing.
func _test_keten_is_bereikbaar_en_afgeleid() -> void:
	_kop("de ticketketen is bereikbaar en afgeleid")

	for id: StringName in GameData.ticket_ids():
		var aw: Dictionary = GameData.ticket(id).available_when
		for f: Variant in (aw.get("flags_all", []) as Array):
			_ok(not String(f).begins_with("_"),
				"%s hangt op de sentinelvlag '%s' in plaats van op een echte conditie"
					% [GameData.ticket(id).code, f])
		for nodig: Variant in (aw.get("tickets_done", []) as Array):
			var n := StringName(nodig)
			_ok(GameData.ticket(n) != null,
				"%s wacht op onbekend ticket '%s'" % [GameData.ticket(id).code, n])
			_ok(n != id, "%s wacht op zichzelf" % GameData.ticket(id).code)

	QuestEngine.start_run(&"daan")
	var ronde := 0
	while not Session.all_done() and ronde < GameData.ticket_ids().size() * 2:
		ronde += 1
		for id: StringName in GameData.ticket_ids():
			if Session.is_done(id) or not Session.is_available(id):
				continue
			if id == &"t10":
				Session.add_item(&"deploysleutel")
			QuestEngine.complete(id, MinigameResult.make(
				GameData.ticket(id).minigame_id, GameEnums.Outcome.SUCCESS))
	_ok(Session.all_done(),
		"de keten liep vast op %d/%d" % [Session.done_count(), Session.total_tickets()])

	# En nu de kern: de hele keten herbouwen uit niets dan `done_order`. Dat is
	# wat er na het laden van een save gebeurt.
	var bewaard := Session.done_order.duplicate()
	QuestEngine.start_run(&"daan")
	for id: StringName in bewaard:
		if id == &"t10":
			continue
		Session.ticket_states[id] = GameEnums.TicketState.DONE
		if not (id in Session.done_order):
			Session.done_order.append(id)
	QuestEngine.refresh_availability()
	_ok(Session.is_available(&"t10"),
		"na het herbouwen uit done_order is de finale niet beschikbaar")
	for id: StringName in GameData.ticket_ids():
		_ok(Session.is_done(id) or Session.is_available(id),
			"%s bleef LOCKED na het herbouwen uit done_order — de keten is niet afgeleid"
				% GameData.ticket(id).code)


## De zone-rects in floor.json overlappen: z1_entree ligt volledig binnen
## z9_vloer, en z4/z5/z6/z7/z8 liggen binnen z11_gang. `WorldBuilder.zone_at()`
## geeft de EERSTE rect die past, dus in welke ruimte je staat hangt af van de
## volgorde waarin ze in het bestand staan. Die volgorde was nergens vastgelegd
## en niets testte hem.
##
## Wat er stukgaat als iemand `zones` herordent: `discover_in_zone()` vergelijkt
## op zone-id, dus een ticket waarvan het anker ineens "De Gang" oplevert wordt
## nooit meer gevonden door er binnen te lopen. Geen crash, geen melding — je
## loopt langs werk dat niet in je inventaris komt.
func _test_zonevolgorde() -> void:
	_kop("zonevolgorde")
	var b := WorldBuilder.new()
	b.zones = GameData.floor_data.get("zones", []) as Array
	_ok(not b.zones.is_empty(), "floor.json bevat geen zones; leest deze test de plattegrond wel?")

	# Vangnet: zonder overlappende rects bewijst deze test niets.
	var overlap := 0
	for i: int in range(b.zones.size()):
		for j: int in range(i + 1, b.zones.size()):
			var r1: Array = (b.zones[i] as Dictionary).get("rect", [])
			var r2: Array = (b.zones[j] as Dictionary).get("rect", [])
			if r1.size() == 4 and r2.size() == 4 \
					and int(r1[0]) <= int(r2[2]) and int(r2[0]) <= int(r1[2]) \
					and int(r1[1]) <= int(r2[3]) and int(r2[1]) <= int(r1[3]):
				overlap += 1
	_ok(overlap > 0,
		"geen enkele zone-rect overlapt nog; dan is de volgorde niet meer betekenisvol en kan deze test weg")

	var tegels := _object_tiles()
	for id: StringName in GameData.ticket_ids():
		var t: TicketDef = GameData.ticket(id)
		if t == null or t.anchor == &"":
			continue
		_ok(tegels.has(t.anchor),
			"%s hangt aan '%s' en dat object staat niet in objects.json" % [t.code, t.anchor])
		if not tegels.has(t.anchor):
			continue
		var gevonden := StringName(b.zone_at(tegels[t.anchor] as Vector2i).get("id", ""))
		_ok(gevonden == t.zone,
			"%s zegt zone '%s', maar zijn anker '%s' ligt volgens zone_at() in '%s' — is de volgorde van `zones` in floor.json veranderd?" % [
				t.code, t.zone, t.anchor, gevonden])


## Een item met een `vindplaats` is wat de wijzer aanwijst zolang je het nog niet
## hebt (zie `QuestEngine.ontbrekend_item()` en `Main._doel_node()`). Dat zijn
## twee velden die uit elkaar kunnen lopen: het object waar het ligt, en de
## ruimte die de doelregel noemt. `GameData` leest `objects.json` niet in, dus
## niets anders bewaakt dat die twee bij elkaar horen — en een verkeerde `zone`
## stuurt de speler met een kloppende pijl naar de verkeerde ruimtenaam.
func _test_item_vindplaats() -> void:
	_kop("item-vindplaats")
	var b := WorldBuilder.new()
	b.zones = GameData.floor_data.get("zones", []) as Array
	var tegels := _object_tiles()

	var met_vindplaats := 0
	for k: Variant in GameData.items.keys():
		var it: ItemDef = GameData.item(StringName(k))
		if it == null or it.vindplaats == &"":
			continue
		met_vindplaats += 1

		_ok(GameData.has_world_id(it.vindplaats),
			"item '%s' ligt bij '%s' en dat staat niet in world_ids.json" % [it.id, it.vindplaats])
		_ok(tegels.has(it.vindplaats),
			"item '%s' ligt bij '%s' en dat object staat niet in objects.json" % [it.id, it.vindplaats])
		if tegels.has(it.vindplaats):
			var zid := StringName(b.zone_at(tegels[it.vindplaats] as Vector2i).get("id", ""))
			_ok(zid == it.zone,
				"item '%s' zegt zone '%s', maar '%s' staat in '%s'" % [it.id, it.zone, it.vindplaats, zid])

		# Een vindplaats zonder vrager wijst nooit iets aan.
		var gevraagd := false
		for tid: StringName in GameData.ticket_ids():
			var t: TicketDef = GameData.ticket(tid)
			if t != null and StringName(it.id) in Conditions.namen(t.requirements.get("has_item", [])):
				gevraagd = true
		_ok(gevraagd,
			"item '%s' heeft een vindplaats maar geen enkel ticket vraagt erom" % it.id)

	_ok(met_vindplaats > 0,
		"geen enkel item heeft een vindplaats; dan kan de wijzer nooit naar ontbrekend spul wijzen")


## world_id -> tegel, uit objects.json.
func _object_tiles() -> Dictionary:
	var out := {}
	for d: Dictionary in _objects():
		var wid := StringName(d.get("world_id", ""))
		var tile: Array = d.get("tile", [])
		if wid != &"" and tile.size() == 2:
			out[wid] = Vector2i(int(tile[0]), int(tile[1]))
	return out


## De melding vóór het bericht van De Klant.
##
## Twee dingen worden hier gemeten die geen van beide uit een losse constructie
## van het scherm blijken. Ten eerste: er gebeurt niets in de wereld zolang je
## niet geopend hebt. Het effect van k1 is `unlock_ticket t07`, en t07 staat op
## `available_when: {tickets_done: [t04]}` — dus op slot bij een verse run. Dat
## is de meetlat: een bericht dat de speler nog niet gelezen heeft mag de wereld
## niet al veranderd hebben.
##
## Ten tweede: er is precies één uitweg. Haar berichten dragen effects, dus een
## tweede knop of een ESC die de melding wegtikt zou een ticket kunnen
## ontgrendelen dat de speler nooit heeft zien langskomen.
func _test_klant_melding_voor_bericht() -> void:
	_kop("de melding vóór het bericht van De Klant")

	QuestEngine.start_run(&"daan")
	_ok(not Session.is_available(&"t07"),
		"vervuilde staat: t07 stond al open vóór deze test")

	var tel := Telefoon.new()
	tel.name = "TelefoonTest"
	add_child(tel)
	tel.setup()
	await get_tree().process_frame

	# --- stap 1: de melding, en verder niets ------------------------------
	tel.call(&"_toon", &"k1")
	await get_tree().process_frame
	_ok(tel.is_open(), "_toon(k1): de telefoon staat niet open")
	_ok(not bool(tel.get(&"_bericht_zichtbaar")),
		"_toon(k1): het bericht staat er meteen, de melding is overgeslagen")

	var melding := tel.get(&"_meldingvak") as CanvasItem
	var bericht := tel.get(&"_berichtvak") as CanvasItem
	_ok(melding != null and melding.visible, "_toon(k1): het meldingsvak staat niet aan")
	_ok(bericht != null and not bericht.visible, "_toon(k1): het berichtvak staat al aan")

	# Haar naam, uit de data. Niet "De Klant" en niet de naam van de manege:
	# dit is het moment waarop de speler wil weten wie er belt.
	var klant := GameData.npc(&"klant")
	_ok(klant != null, "npc 'klant' ontbreekt, dus de melding kan geen naam tonen")
	if klant != null:
		_ok(_vind_label(melding, klant.name) != null,
			"de melding noemt '%s' niet" % klant.name)

	# Eén uitweg, en niet twee.
	_ok(_vind_knop(melding, "Openen") != null, "de melding heeft geen Openen-knop")
	for verboden: String in ["Sluiten", "Later", "Weg", "Terug", "Negeren"]:
		_ok(_vind_knop(melding, verboden) == null,
			"de melding heeft een tweede uitweg ('%s') en hoort er maar één te hebben"
				% verboden)

	_ok(not Session.is_available(&"t07"),
		"k1: t07 ging al open terwijl het bericht nog niet gelezen was")

	# ESC hoort de melding niet weg te tikken. Dit is de guard in `_input()`:
	# die kijkt naar `_bericht_zichtbaar` en niet naar `_open`.
	var esc := InputEventAction.new()
	esc.action = &"cancel"
	esc.pressed = true
	tel.call(&"_input", esc)
	await get_tree().process_frame
	_ok(tel.is_open() and not bool(tel.get(&"_bericht_zichtbaar")),
		"ESC op de melding legde de telefoon weg: het bericht en zijn effects werden overgeslagen")
	_ok(not Session.is_available(&"t07"),
		"ESC op de melding: t07 ging alsnog open")

	# --- stap 2: openen ---------------------------------------------------
	var openen := _vind_knop(melding, "Openen")
	if openen != null:
		openen.pressed.emit()
		await get_tree().process_frame
	_ok(bool(tel.get(&"_bericht_zichtbaar")), "Openen: het bericht kwam niet op het scherm")
	_ok(melding != null and not melding.visible, "Openen: de melding bleef staan")
	_ok(bericht != null and bericht.visible, "Openen: het berichtvak kwam niet aan")
	var tekst := tel.get(&"_tekst") as RichTextLabel
	_ok(tekst != null and tekst.text != "", "Openen: er staat geen berichttekst op het scherm")
	_ok(Session.is_available(&"t07"), "Openen: het effect van k1 draaide niet")

	# --- wegleggen mag nu wél ---------------------------------------------
	tel.call(&"_weg")
	await get_tree().process_frame
	_ok(not tel.is_open(), "_weg(): de telefoon bleef open")
	_ok(not Session.input_locked, "_weg(): het invoerslot bleef dicht")

	tel.queue_free()
	await get_tree().process_frame


func _test_duimzone_rechts() -> void:
	_kop("de duimzone ligt rechtsonder, weg van de knoppenbalk")

	var b := Besturing.new()
	add_child(b)
	b.setup()
	var r := b.get_viewport().get_visible_rect().size

	# Ruim onder ZONE_TOP en ruim boven de balk: dit meet de zijkant, niet de
	# hoogte en niet de chrome-uitzondering.
	var y := r.y * 0.6
	var rechts := Vector2(r.x * 0.8, y)
	var links := Vector2(r.x * 0.2, y)
	var rechtsboven := Vector2(r.x * 0.8, r.y * 0.1)

	# Rechtsonder is waar de duim ligt; linksonder staat de knoppenbalk (▤ ? ≡)
	# en die mag niet met de stick om dezelfde pixels vechten. Deze test staat
	# er omdat het een ergonomische keuze is die je bij het lezen van
	# `_in_zone()` per ongeluk omdraait: één `<` in plaats van `>`.
	_ok(b._in_zone(rechts),
		"rechtsonder (%.0f,%.0f) maakt geen stick; ligt de duimzone weer links?" % [
			rechts.x, rechts.y])
	_ok(not b._in_zone(links),
		"linksonder (%.0f,%.0f) maakt een stick, boven op de knoppenbalk" % [
			links.x, links.y])
	_ok(not b._in_zone(rechtsboven),
		"rechtsbóven (%.0f,%.0f) maakt een stick; daar zit de doelregel" % [
			rechtsboven.x, rechtsboven.y])

	# Zelfde reden als in `_test_hudband()`: synchrone suite, dus meteen vrijgeven.
	remove_child(b)
	b.free()


## Een geweigerde dialoogregel moet geteld worden, want `push_error()` raakt de
## exitcode niet.
##
## Dit is de bewaking onder de speelbeurt-poort: op het BBD-203-pad vielen
## Willems briefing, de openingsregel en alle drie keuzerondes weg omdat het
## harnas interacties afvuurde terwijl het wervingsgesprek nog liep -- en de
## doorloop meldde dat als "10/10, exit 0". Het harnas wacht nu
## (`Main._qa_dialoog_vrij()`), maar een teller die niet meetelt is geen poort,
## dus dit test de teller zelf in plaats van de doorloop van drie minuten.
func _test_weggevallen_regel_telt() -> void:
	_kop("een weggevallen dialoogregel wordt geteld")
	# Deze test lokt de weigeringen zélf uit, dus de ERROR-regels die hierna in
	# de uitvoer staan horen erbij. Zonder deze regel leest een groene suite met
	# drie ERROR's erin als een suite die je mag negeren -- en dat is precies de
	# gewoonte die P0-2 veroorzaakte.
	print("   (de ERROR-regels hieronder zijn opzettelijk: dit test de weigering)")

	var dc := DialogueController.new()
	add_child(dc)
	dc.setup()
	_ok(dc.geweigerd() == 0, "een verse DialogueController begint niet op nul")

	# `_active` direct zetten in plaats van een echt gesprek starten: `say()`
	# wacht anders op invoer die in een headless suite nooit komt. Dit is precies
	# de toestand die het harnas veroorzaakte.
	dc._active = true

	await dc.say("Willem", "Deze regel valt weg.")
	_ok(dc.geweigerd() == 1, "een geweigerde say() werd niet geteld")

	var keuze: int = await dc.ask_choice("Welke bedoel je?", ["A", "B"] as Array[String])
	_ok(keuze == -1, "ask_choice() gaf %d in plaats van -1 tijdens een lopend gesprek" % keuze)
	_ok(dc.geweigerd() == 2, "een geweigerde ask_choice() werd niet geteld")

	# En een lege labellijst is een aanroepfout van de opgave, geen platgedrukte
	# regel: die mag de teller niet laten oplopen.
	dc._active = false
	var leeg: int = await dc.ask_choice("Niets te kiezen", [] as Array[String])
	_ok(leeg == -1, "een lege ask_choice() gaf %d in plaats van -1" % leeg)
	_ok(dc.geweigerd() == 2, "een lege labellijst liet de weigeringsteller oplopen")

	remove_child(dc)
	dc.free()


## Het dak op het vergaderhokje moet de zone precies dekken.
##
## Het dak is geen regel in `floor.json` maar een eigen node, dus `_test_wereld()`
## — dat elke prop uit de vloerdata tegen zijn PNG legt — ziet hem niet. En de
## vloer is al een keer van 130 naar 80 tegels gegaan: verschuift `z8_hokje`
## nog eens, dan hangt er zonder deze test een dak naast een kamer, en dat merk
## je alleen door er toevallig naar te kijken.
func _test_hokjedak_dekt_de_zone() -> void:
	_kop("het dak past op het vergaderhokje")

	var rect: Array = []
	for z: Variant in GameData.floor_data.get("zones", []) as Array:
		var d := z as Dictionary
		if StringName(d.get("id", "")) == HokjeDak.ZONE:
			rect = d.get("rect", []) as Array
			break
	_ok(rect.size() == 4, "zone '%s' heeft geen rect in floor.json" % HokjeDak.ZONE)
	if rect.size() != 4:
		return

	var tegel := int(GameData.floor_data.get("tile_size", 16))
	var verwacht := Vector2(
		float(int(rect[2]) - int(rect[0]) + 1), float(int(rect[3]) - int(rect[1]) + 1)) * tegel

	_ok(ResourceLoader.exists(HokjeDak.SPRITE),
		"%s bestaat niet (of mist zijn .import)" % HokjeDak.SPRITE)
	if not ResourceLoader.exists(HokjeDak.SPRITE):
		return
	var tex: Texture2D = load(HokjeDak.SPRITE)
	_ok(tex.get_size() == verwacht,
		"%s is %v, maar zone %s vraagt %v" % [
			HokjeDak.SPRITE, tex.get_size(), HokjeDak.ZONE, verwacht])

	# En hij moet boven de speler liggen, anders loop je ervoor langs in plaats
	# van eronder — dat is het hele punt van een dak.
	_ok(HokjeDak.Z_DAK > 0, "Z_DAK is %d en ligt daarmee niet boven de wereld" % HokjeDak.Z_DAK)


## De wijzer kiest het dichtste beschikbare ticket, niet het laagste nummer.
##
## `next_hint_ticket()` liep `ticket_ids()` af, en die lijst staat op `order`.
## De gidslaag stuurde je daarmee in ticketnummervolgorde over de verdieping:
## nagerekend op de ankers uit objects.json 338 tegels waar 156 genoeg is.
## Deze test staat er omdat de oude versie er onschuldig uitzag — "geef het
## eerste beschikbare terug" is een redelijke regel, tot je ziet welke volgorde
## die lijst heeft.
func _test_wijzer_kiest_het_dichtste() -> void:
	_kop("de wijzer kiest het dichtste doel")

	var bewaar_tile := Session.player_tile
	QuestEngine.start_run(&"daan")

	# Twee tickets die bij de start allebei openstaan, met ankers ver uit
	# elkaar. Uit de data gehaald, niet gehardcodeerd: de vloer is al een keer
	# ingekort en dan moeten deze tegels meebewegen.
	var open_ids: Array[StringName] = []
	for id: StringName in GameData.ticket_ids():
		if Session.is_available(id) and GameData.object_tile(GameData.ticket(id).anchor).x >= 0:
			open_ids.append(id)
	_ok(open_ids.size() >= 2, "minder dan twee open tickets met een anker; test kan niets meten")
	if open_ids.size() < 2:
		Session.player_tile = bewaar_tile
		return

	# De twee die het verst van elkaar liggen, zodat de meting niet op een
	# gelijkspel uitkomt.
	var a: StringName = open_ids[0]
	var b: StringName = open_ids[1]
	var verst := -1
	for i: int in open_ids.size():
		for j: int in range(i + 1, open_ids.size()):
			var ta := GameData.object_tile(GameData.ticket(open_ids[i]).anchor)
			var tb := GameData.object_tile(GameData.ticket(open_ids[j]).anchor)
			var d := absi(ta.x - tb.x) + absi(ta.y - tb.y)
			if d > verst:
				verst = d
				a = open_ids[i]
				b = open_ids[j]
	_ok(verst > 0, "de twee ankers liggen op dezelfde tegel")

	Session.discover(a)
	Session.discover(b)
	Session.unpin()

	# Naast a gaan staan moet a opleveren, ook als b een lager ticketnummer heeft.
	Session.player_tile = GameData.object_tile(GameData.ticket(a).anchor)
	var bij_a: TicketDef = QuestEngine.next_hint_ticket()
	_ok(bij_a != null and bij_a.id == a,
		"naast %s wijst de wijzer naar %s" % [a, bij_a.id if bij_a != null else &"niets"])

	Session.player_tile = GameData.object_tile(GameData.ticket(b).anchor)
	var bij_b: TicketDef = QuestEngine.next_hint_ticket()
	_ok(bij_b != null and bij_b.id == b,
		"naast %s wijst de wijzer naar %s" % [b, bij_b.id if bij_b != null else &"niets"])

	# En zonder speler valt hij terug op ticketvolgorde, want dan zijn alle
	# afstanden 0. Daar leunt elke test op die zonder wereld draait.
	# Alleen a en b zijn gevonden, en gevonden gaat voor: verwacht dus de eerste
	# van die twee in order, niet het eerste open ticket.
	var eerst_gevonden: StringName = a
	for id: StringName in GameData.ticket_ids():
		if id == a or id == b:
			eerst_gevonden = id
			break
	Session.player_tile = Vector2i(-1, -1)
	var zonder: TicketDef = QuestEngine.next_hint_ticket()
	_ok(zonder != null and zonder.id == eerst_gevonden,
		"zonder speler geeft de wijzer %s in plaats van %s (de eerste in order)" % [
			zonder.id if zonder != null else &"niets", eerst_gevonden])

	Session.player_tile = bewaar_tile


## Elk paneel en elke knop op de boot-schermen past binnen het canvas.
##
## Dit is het gat waardoor drie afgekapte schermen konden shippen. De suite
## controleerde hier gedrag en geen geometrie: `_test_save_verwijderen()` bouwt
## de échte bevestigingsoverlay op en kijkt alleen of de wisknop de goede
## functie aanroept. Of je die knop kón lezen was geen test.
##
## Wat er stond: het titelscherm zette zijn kolom op 280 px breed (canvas is
## 192), de eindeschermen-ping op 260, en de knop "Ja, dag wissen en opnieuw
## beginnen" was een `UiKit.button()` zonder autowrap — die meldt zijn volle
## tekstbreedte als minimum en duwde het paneel daarmee buiten het canvas.
##
## Meet horizontaal én verticaal, en niet alleen het paneel: een Control groeit
## standaard naar `GROW_DIRECTION_END`, en onderaan het scherm is dat de kant
## waar niets meer is. Twee frames per scherm, want een Container legt zijn
## kinderen pas in de layout-pass neer — zelfde reden als bij
## `_test_dialoogvenster_past()`.
func _test_schermen_passen() -> void:
	_kop("de boot-schermen passen op het canvas")

	for pad: String in ["res://scenes/boot/title.tscn",
			"res://scenes/boot/ending.tscn",
			"res://scenes/boot/intro_uitleg.tscn",
			"res://scenes/boot/character_select.tscn"]:
		var scherm: Control = (load(pad) as PackedScene).instantiate()
		add_child(scherm)
		await get_tree().process_frame
		await get_tree().process_frame
		_meet_schermvulling(scherm, pad.get_file())

		# De bevestigingsoverlay bestaat alleen na een aanroep, en juist daar zat
		# de afgekapte knop. Hij hangt onder hetzelfde scherm, dus dezelfde meting.
		if scherm.has_method("_toon_bevestiging"):
			scherm.call("_toon_bevestiging")
			await get_tree().process_frame
			await get_tree().process_frame
			_meet_schermvulling(scherm.get("_bevestiging") as Control,
				"%s + bevestiging" % pad.get_file())
			scherm.call("_sluit_bevestiging")

		scherm.queue_free()
		await get_tree().process_frame


## Loopt de boom af en klaagt over elk paneel of elke knop die buiten het canvas
## uitsteekt. `PanelContainer` en `Button` en niet elke Control: een Label mag
## breder meten dan hij tekent, en een `full_rect`-ColorRect hoort juist precies
## de rand te halen.
func _meet_schermvulling(root: Control, naam: String) -> void:
	if root == null:
		_ok(false, "%s: geen scherm om te meten" % naam)
		return
	var vp := get_viewport().get_visible_rect()
	for c: Control in _controls(root):
		if not (c is PanelContainer or c is Button):
			continue
		if not c.is_visible_in_tree() or c.size == Vector2.ZERO:
			continue
		# Wat in een klemmende ouder hangt mag buiten beeld uitsteken: de
		# personagerijen staan in een `ScrollContainer` en de onderste hoort
		# er 24 px onderuit te lopen — dat is waar scrollen voor is.
		if _wordt_geklemd(c, root):
			continue
		var r := Rect2(c.global_position, c.size)
		var wat := "%s in %s" % [c.get_class(), naam]
		if c is Button:
			wat = "knop \"%s\" in %s" % [(c as Button).text.replace("\n", " "), naam]
		_ok(r.position.x >= vp.position.x - 0.5,
			"%s begint %.0f px links buiten het canvas" % [wat, vp.position.x - r.position.x])
		_ok(r.end.x <= vp.end.x + 0.5,
			"%s loopt %.0f px rechts buiten het canvas" % [wat, r.end.x - vp.end.x])
		_ok(r.position.y >= vp.position.y - 0.5,
			"%s begint %.0f px boven het canvas" % [wat, vp.position.y - r.position.y])
		_ok(r.end.y <= vp.end.y + 0.5,
			"%s loopt %.0f px onder het canvas door" % [wat, r.end.y - vp.end.y])


## Hangt `c` in een ouder die zijn kinderen afklemt? `ScrollContainer` zet
## `clip_contents` in zijn constructor, en `character_select.gd` zet hem zelf op
## het podium — één vraag dekt dus beide.
func _wordt_geklemd(c: Control, root: Control) -> bool:
	var n := c.get_parent()
	while n != null:
		if n is Control and (n as Control).clip_contents:
			return true
		if n == root:
			return false
		n = n.get_parent()
	return false


func _controls(root: Node) -> Array[Control]:
	var uit: Array[Control] = []
	if root is Control:
		uit.append(root as Control)
	for kind: Node in root.get_children():
		uit.append_array(_controls(kind))
	return uit


## De chrome in de wereld past op het canvas — de knoppenbalk vooral.
##
## Dit is de test die er niet was toen het misging. `_test_balkmaat()` legt de
## hóógte van de balk vast en `_test_hudband()` wat hij bovenin afdekt, maar
## niemand vroeg wáár de balk landde. Hij landde op y408 in een viewport van
## 416: van elke knop van 30 px stonden er 24 onder het scherm, en op een
## telefoon zag je van ▤ ? ≡ nog net de bovenrand. Oorzaak was
## `_balk.size = get_combined_minimum_size()` in `Besturing._bouw_balk()` —
## `Control.set_size()` rekent alle vier de offsets opnieuw uit, dus die ene
## regel gooide de verankering aan de onderrand weg die er twee regels eerder
## was gezet.
##
## Op een screenshot van de viewport is dat wél te zien, in tegenstelling tot
## een afgekapt OS-venster — maar niemand kijkt naar de onderste acht pixels
## van een shot van 416 hoog. Vandaar een getal in plaats van een oog.
func _test_wereldchrome_past() -> void:
	_kop("de chrome in de wereld past op het canvas")

	var besturing := Besturing.new()
	add_child(besturing)
	besturing.setup()

	var hud := Hud.new()
	add_child(hud)
	hud.setup()
	# De besturingsuitleg is een modaal venster met een knop erin, en die knop
	# hoort net zo binnen het canvas te vallen als de balk.
	hud.show_controls_card()

	await get_tree().process_frame
	await get_tree().process_frame

	_meet_schermvulling(besturing.get_child(0) as Control, "de knoppenbalk")
	_meet_schermvulling(hud.get_child(0) as Control, "de HUD")

	# En de balk hoort de ruimte te pakken die de HUD voor hem vrijhoudt: één
	# getal, twee lezers. Loopt dat uit elkaar, dan hangen de onderste
	# HUD-regels over de knoppen of blijft er een strook dode ruimte tussen.
	var vp := get_viewport().get_visible_rect()
	var balk := _vind_balk(besturing)
	_ok(balk != null, "geen knoppenbalk gevonden in Besturing")
	if balk != null:
		var onder := vp.end.y - balk.get_global_rect().end.y
		_ok(is_equal_approx(onder, float(Besturing.MARGE)),
			"de balk staat %.0f px van de onderrand, MARGE zegt %d" % [
				onder, Besturing.MARGE])
		_ok(balk.get_global_rect().size.y <= float(Besturing.BALK_RUIMTE),
			"de balk is %.0f px hoog en past niet in BALK_RUIMTE (%d)" % [
				balk.get_global_rect().size.y, Besturing.BALK_RUIMTE])

	# `free()` en niet `queue_free()`, om dezelfde reden als in
	# `_test_hudband()`: beide nodes hangen aan de Bus en zouden anders met de
	# rest van de suite meelopen.
	remove_child(hud)
	hud.free()
	remove_child(besturing)
	besturing.free()


## De knoppenbalk is de PanelContainer met de drie knoppen erin. Op vorm
## gezocht en niet op kindpad, net als `_vind_knop()`.
func _vind_balk(root: Node) -> PanelContainer:
	if root is PanelContainer:
		var knoppen := 0
		for c: Control in _controls(root):
			if c is Button:
				knoppen += 1
		if knoppen >= 3:
			return root as PanelContainer
	for kind: Node in root.get_children():
		var g := _vind_balk(kind)
		if g != null:
			return g
	return null


## De doelwijzer gaat niet over het bijschrift van waar je voor staat.
##
## Twee kaartjes die niets van elkaar wisten, en de situatie waarin dat misgaat
## is de gewone: je staat voor een collega ("Praten Willem") terwijl je doel
## elders in het gebouw ligt, dus de pijl klemt zich tegen de schermrand op de
## hoogte van dat doel. De vloer is één lange strook, dus "dezelfde hoogte" is
## eerder regel dan uitzondering — en dan lag "Entree 23 m" over "Praten
## Willem" heen.
##
## Van die twee wijkt de wijzer; het tikkaartje hoort bij het ding waar je vlak
## voor staat en heeft de vaste plek. Zie
## `ObjectiveMarker._wijk_voor_tikkaartje()`.
func _test_wijzer_wijkt_voor_tikkaartje() -> void:
	_kop("de doelwijzer wijkt voor het tikkaartje")

	# De wijzer vraagt `Hud.vrije_band()` op; zonder HUD is er geen band en
	# meet deze test iets anders dan het spel doet.
	var hud := Hud.new()
	add_child(hud)
	hud.setup()

	var wereld := Node2D.new()
	add_child(wereld)

	# Het doel ligt rechts buiten het zichtbare stuk wereld, dus de pijl klemt
	# zich tegen de rechterrand — de enige stand waarin hij een kaartje draagt.
	var doel := Node2D.new()
	doel.position = Vector2(400.0, 200.0)
	wereld.add_child(doel)
	var wijzer := ObjectiveMarker.new()
	wijzer.plek = "Entree"
	wijzer.meter_per_px = 0.1
	doel.add_child(wijzer)

	# En het tikkaartje op diezelfde hoogte, tegen die rand aan.
	var anker := Node2D.new()
	anker.position = Vector2(150.0, 206.0)
	wereld.add_child(anker)
	var tik := TapMarker.new()
	anker.add_child(tik)
	tik.zet("Praten Willem", true)

	# Drie frames: `_wijk_voor_tikkaartje()` rekent met de maat die
	# `_zet_kaartje()` het frame ervoor heeft gezet, dus de uitwijking valt op
	# zijn vroegst in het tweede frame.
	for _i: int in 3:
		await get_tree().process_frame

	var a := tik.kaartje_rect()
	var b := _kaartje_rect_van(wijzer)
	_ok(a.size != Vector2.ZERO, "het tikkaartje heeft geen maat; meet deze test iets?")
	_ok(b.size != Vector2.ZERO, "het doelkaartje heeft geen maat; klemt de pijl wel?")

	# Zonder deze controle zou "geen overlap" ook waar zijn als de twee
	# kaartjes gewoon naast elkaar liggen, en dan bewijst de test niets.
	_ok(a.position.x < b.end.x and b.position.x < a.end.x,
		"de twee kaartjes overlappen horizontaal niet (%s en %s); dan is er geen conflict om te ontwijken" % [a, b])

	_ok(not a.intersects(b),
		"het doelkaartje %s ligt over het tikkaartje %s" % [b, a])

	remove_child(wereld)
	wereld.free()
	remove_child(hud)
	hud.free()


## Het bijschrift van een wereldmarker, in wereldcoördinaten. Op vorm gezocht en
## niet op kindpad; `ObjectiveMarker` houdt zijn kaartje privé.
func _kaartje_rect_van(n: Node2D) -> Rect2:
	for k: Node in n.get_children():
		if k is PanelContainer and (k as PanelContainer).visible:
			var p := k as PanelContainer
			return Rect2(n.global_position + p.position, p.size)
	return Rect2()


## Elke plek waar je iemand kunt ophalen moet een zinsstaart hebben, en elke
## `plek` op een NPC moet bestaan.
##
## "Haal Victor uit De Vloer" kwam ervan dat de HUD zelf " uit %s" om een
## zonenaam heen bouwde. Dat voorzetsel staat nu per zone en per bureau-eiland
## in floor.json — en dat bestand wordt gegenereerd, dus een `aanduiding` die
## bij een volgende vloerronde wegvalt levert stil "Haal Victor" op, zonder
## plek en zonder foutmelding.
func _test_aanduidingen_kloppen() -> void:
	_kop("iedereen is ergens op te halen")

	var plek_ids: Array[StringName] = []
	for raw: Variant in GameData.floor_data.get("plekken", []) as Array:
		var p := raw as Dictionary
		var pid := StringName(p.get("id", ""))
		plek_ids.append(pid)
		_ok(String(p.get("aanduiding", "")) != "",
			"bureau-eiland '%s' heeft geen aanduiding" % pid)
		_ok((p.get("rect", []) as Array).size() == 4,
			"bureau-eiland '%s' heeft geen rect van vier" % pid)
	_ok(plek_ids.size() == 5, "verwacht vijf bureau-eilanden, kreeg %d" % plek_ids.size())

	for raw: Variant in GameData.floor_data.get("zones", []) as Array:
		var z := raw as Dictionary
		_ok(String(z.get("aanduiding", "")) != "",
			"zone '%s' heeft geen aanduiding" % z.get("id", ""))

	# Elke collega die je kunt moeten ophalen levert een volledige zin op, en
	# een `plek` die niet bestaat is een typefout die je anders pas ziet als de
	# doelregel halverwege stopt.
	for id: StringName in GameData.ticket_ids():
		var t: TicketDef = GameData.ticket(id)
		if t == null:
			continue
		var helper: StringName = QuestEngine.required_helper(t.id)
		if helper == &"":
			continue
		var d: NpcDef = GameData.npc(helper)
		if d == null:
			continue
		if d.plek != &"":
			_ok(plek_ids.has(d.plek),
				"%s zit op plek '%s' en die staat niet in floor.json" % [d.name, d.plek])
		_ok(Hud._aanduiding(d.zone, d.plek) != "",
			"%s is nergens op te halen: zone '%s', plek '%s'" % [d.name, d.zone, d.plek])

	# En de plek wint van de zone, want dat is het hele punt: Bastiaan en Victor
	# zitten op De Vloer maar horen bij een eiland.
	var bas: NpcDef = GameData.npc(&"npc_bastiaan")
	if bas != null and bas.plek != &"":
		_ok(Hud._aanduiding(bas.zone, bas.plek).contains("Team"),
			"Bastiaan krijgt '%s' en niet zijn eiland" % Hud._aanduiding(bas.zone, bas.plek))
