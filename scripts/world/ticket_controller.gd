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
var _busy_sinds_ms: int = 0

## Hoe lang `_busy` mag aanstaan terwijl er zichtbaar niets loopt. Ruim boven
## het langste stille venster in een normale stroom — het briefje dat naar het
## bord vliegt is ~1,6 s en de urenrol ~0,75 s — en ruim onder wat een speler
## uitzit voordat hij denkt dat het spel stuk is.
const SLOT_RESPIJT_MS := 5000


## Loopt er nu een ticketstroom — oppakken, werven, minigame, afronden?
##
## Voor de QA-harnas. `Session.is_done()` valt vóór de urenrol en de
## afrondingsdialoog, dus daarop wachten betekent dat de doorloop het volgende
## ticket in racet terwijl dit nog loopt — en dan weigert `handle_npc_talk()`
## stil op zijn `_busy`-guard en loopt er dertig seconden later een collega
## "niet mee" zonder oorzaak. Zie `_qa_playthrough()` in main.gd.
func bezig() -> bool:
	return _busy


## Weigert deze interactie omdat er echt nog iets loopt?
##
## Het vangnet naast de fix in `Hud.toon_urenrol()`. `_busy` staat aan over een
## hele `await`-keten en GDScript kent geen `finally`: hangt één van die awaits,
## dan blijft het slot dicht en weigert elke volgende interactie stil — geen
## prompt die verdwijnt, geen regel in de console, alleen een tik die niets
## doet. Dat is playtest 2026-09-06 #37/#38, en het kostte Daan zijn speelbeurt.
##
## Draait er nog een dialoog, een minigame of een invoerslot, dan is dit gewoon
## geduld en weigeren we terecht. Is het scherm leeg en staat het slot langer
## dan `SLOT_RESPIJT_MS` dicht, dan lekt het en geven we de speler zijn spel
## terug. Een lek hoort een `push_error()` te zijn en geen stilte: het is een
## bug in deze klasse, geen speelbare toestand.
## Het slot dichtzetten en onthouden wanneer. Zie `_slot_houdt()`.
func _neem_slot() -> void:
	_busy = true
	_busy_sinds_ms = Time.get_ticks_msec()


func _slot_houdt(wat: String) -> bool:
	if not _busy:
		return false
	if Shell.minigame_active() or (_dialogue != null and _dialogue.is_active()) \
			or Session.input_locked:
		return true
	var stil_ms := Time.get_ticks_msec() - _busy_sinds_ms
	if stil_ms < SLOT_RESPIJT_MS:
		return true
	push_error(("TicketController: het slot stond %d ms dicht zonder dat er iets liep " +
		"— vastgelopen await. Losgelaten bij '%s'.") % [stil_ms, wat])
	_busy = false
	return false


func setup(registry: WorldRegistry, npcs: NpcLayer, builder: WorldBuilder) -> void:
	_registry = registry
	_npcs = npcs
	_builder = builder
	_dialogue = get_parent().get_node("DialogueController") as DialogueController
	_hud = get_parent().get_node("HUD") as Hud


# --- Ticketobject aanspreken ---------------------------------------------

func handle(ticket_id: StringName, source: Interactable) -> void:
	if _slot_houdt("ticket %s" % ticket_id):
		return
	# Een object kan meerdere tickets dragen (het scrumbord is er zowel voor de
	# planning als voor de paardenbugs), dus kies op basis van de stand van
	# zaken en niet op een vast id. Het slot gaat vóór het kiezen dicht: die
	# keuze kan een dialoogvenster openen, en dan mag er geen tweede E-druk
	# tussendoor komen.
	_neem_slot()
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
## Draagt dit object er meer dan één die openstaat, dan kiest de speler.
## `scrumbord_gang` droeg ooit twee tickets (t02 en t09), maar t09 was gated op
## `tickets_done: [t02]` — t02 was dus altijd al dicht tegen de tijd dat t09
## openging, en `open.size() > 1` hieronder viel daardoor nooit voor. Sinds
## P1-10 (t09 verhuisde naar het paardenkostuum) is er in de data geen enkel
## gedeeld anker meer. Deze tak is dus dode code, geen actieve
## "welke bedoel je?"-vraag — maar hij blijft staan als vangnet voor een
## toekomstig anker met wél twee gelijktijdig open tickets. Zie
## `_test_gedeelde_ankers()` in `test_runner.gd`, die dat leent in plaats van
## het in de data te zoeken. Verwijder deze tak niet zonder dat na te gaan.
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


## `via_npc` is alleen van belang voor BBD-209: dat ticket lost pas op als je
## een dwalende paardenbug aanspreekt, niet als je alleen het scrumbord
## aanklikt. Zie `_wh_paarden()`.
func _handle_inner(t: TicketDef, via_npc: bool = false) -> void:
	# `_play_or_line` en niet `_line(_dlg(...))`. Dat tweede stond hier, en
	# `_dlg()` geeft een dialoog-*id* terug zodra de sleutel bestaat — wat bij
	# `done` voor alle tien de tickets zo is. `_line()` zet zijn argument
	# rechtstreeks in de dialoogbox, dus een opgelost ticket aanspreken zei
	# letterlijk "t01_done", en de tien geschreven afsluitdialogen speelden
	# nooit. Twee regels lager, bij `fetch` en `blocked`, stond het goede
	# patroon al: id als id, tekst als fallback.
	if Session.is_done(t.id):
		# Als terzijde boven het object als de regel dat toelaat (één node,
		# geen keuze of effect — alle tien de done-regels zijn zo): de wereld
		# loopt door en je hoeft niet te tikken. Anders gewoon in de box.
		var anker := _registry.get_by_id(t.anchor)
		if anker == null or not _dialogue.speel_of_bark(_dlg(t, &"done", &""), anker):
			await _play_or_line(_dlg(t, &"done", &""),
				"Dit is opgelost. Even niet aan zitten.")
		return

	if Session.ticket_state(t.id) == GameEnums.TicketState.LOCKED:
		await _play_or_line(_dlg(t, &"locked", &""), _locked_hint(t))
		return

	# Was dit ticket al aangenomen? Dan is dit een tweede aanloop en hoort de
	# aanname-ceremonie niet nog een keer. Dat gebeurt bij BBD-209: je neemt hem
	# aan bij het paardenkostuum en maakt hem af bij een paard, en zonder deze
	# vlag kreeg je bij dat paard opnieuw het briefje én opnieuw Bastiaans
	# briefing te zien.
	var al_aangenomen := Session.ticket_state(t.id) == GameEnums.TicketState.ACTIVE
	QuestEngine.activate(t.id)
	# Het briefje zien binnenkomen en naar het ticketbord zien gaan, vóór de
	# dialoog. Dit is het moment waarop een ticket iets wordt in plaats van een
	# regel in een lijst.
	#
	# Hier stond `toon_nieuw_briefje()`, en dat zette het volledige bord over het
	# scherm — elf keer per speelbeurt, zonder dat er stond waarom. Zie
	# `Hud.toon_ticket_melding()`.
	if _hud != null and not al_aangenomen:
		await _hud.toon_ticket_melding(t, t.zone_name)

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
	if not al_aangenomen:
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

	# F4-b: vier tickets lossen op dóór in de wereld te handelen — een gesprek,
	# een keuze bij een object, een collega aanspreken — in plaats van door een
	# afgesloten minigame-overlay. `Shell.run_minigame()` bouwt precies zo'n
	# schermvullende, muis-blokkerende chrome (`MinigameLayer`); dat is precies
	# wat hier niet mag gebeuren, want een wereldhandeling moet de speler juist
	# in de zichtbare wereld laten blijven klikken en lopen. (Vóór F5-a
	# pauzeerde `run_minigame()` ook `get_tree()`, en was dát de reden dit pad
	# apart te houden; sinds F5-a doet het dat niet meer, maar de overlay zelf
	# blijft even ongeschikt voor dit soort tickets.)
	var result: MinigameResult
	if t.wereldhandeling:
		result = await _resolve_wereldhandeling(t, mg_config.get("inhoud", {}) as Dictionary, via_npc)
	else:
		result = await Shell.run_minigame(t.minigame_id, mg_config)

	match result.outcome:
		GameEnums.Outcome.SUCCESS:
			# complete() boekt de uren zelf, vóór zijn eigen save. De HUD is al
			# aan het rollen op dat signaal; hier wachten we hem alleen uit,
			# zodat je je dag ziet weglopen vóór je personage reageert.
			QuestEngine.complete(t.id, result)
			_vier(t)
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
			# En dan de keuze die er tot nu toe niet was. Een mislukte poging
			# was een gratis herkansing: kwartier kwijt, ticket open, nog eens.
			# Nu mag je het ook zó de deur uit doen — en dat komt terug bij de
			# oplevering. Ná `play()`/`_line()`, want die zetten hun eigen
			# `_active` weer op false; anders weigert `ask_choice()` stil.
			if await _wil_gebrekkig_shippen(t):
				await _ship_gebrekkig(t, result)
		_:
			pass   # afgebroken: ticket blijft ACTIVE, opnieuw proberen mag


## Na een mislukte poging: nog eens, of is dit zo goed genoeg?
##
## "Nog een keer" staat bewust bovenaan. De autopilot
## (`scripts/tests/autopilot.gd`) drukt altijd de knop met focus, en
## `DialogueBox.show_choices()` geeft die aan de eerste — dus de geautomatiseerde
## speelbeurt blijft herkansen zoals hij altijd deed, en shipt nooit stil iets
## gebrekkigs. Een geweigerde of lege vraag komt als -1 terug en valt dezelfde
## kant op: herkansen is de veilige keuze, shippen moet je echt kiezen.
func _wil_gebrekkig_shippen(t: TicketDef) -> bool:
	# De oplevering is de shipknop zelf: een mislukte deploy is een rollback en
	# geen half werk dat je alsnog live kunt zetten. Daar geldt alleen "nog een
	# keer" — en de tweede keer slaagt altijd (zie mg_oplevering.gd).
	if t.id == &"t10":
		return false
	var opties: Array[String] = ["Nog een keer.", "Goed genoeg. Shippen."]
	var keuze := await _dialogue.ask_choice("Nog een keer, of is dit goed genoeg?", opties)
	return keuze == 1


## "Goed genoeg. Shippen." Het ticket gaat alsnog dicht, en het spel doet daar
## niet moeilijk over: `result.outcome` is FAIL, maar `QuestEngine.complete()`
## kijkt daar niet naar en `Gevolgen.boek()` leest alleen de payload. Wat wél
## verandert is de boekhouding: de teller en de vlag hieronder zijn wat
## `Gevolgen.finale_start()` straks als bugs doorrekent.
##
## Dit is de grappigste en meest thematische inzet van het spel. De wereld
## zegt straks "200 OK" boven iets dat stuk is, en pas bij de oplevering blijkt
## dat niet falen je iets kostte, maar doen alsof je niet faalde. Wel de
## klokrol: dít is een oplevering, hoe krom ook, en `complete()` boekt er de
## gewone ticketuren voor — bovenop het kwartier dat het mislukken al kostte.
func _ship_gebrekkig(t: TicketDef, result: MinigameResult) -> void:
	Session.add_counter(Gevolgen.GEBREKKIG_TELLER)
	Session.set_flag(Gevolgen.gebrekkig_vlag(t.id), true)
	QuestEngine.complete(t.id, result)
	AudioDirector.play_sfx(&"pak")
	Bus.toast_requested.emit("%s geshipt. Ongetest." % t.code, &"tijd")
	if _hud != null:
		await _hud.toon_urenrol()


## Klein impactframe bij een opgelost ticket: een tik op de camera en wat
## confetti boven het object waar je het oploste. Klein, want dit gebeurt tien
## keer per beurt — de tiende keer moet het nog steeds een ticket zijn en geen
## vuurwerkshow. `get_parent()` is Main (Node2D), dus de confetti leeft in de
## wereld en niet in een UI-laag.
func _vier(t: TicketDef) -> void:
	Juice.schok(2.0, 0.22)
	var wo := _registry.get_by_id(t.anchor)
	if wo != null:
		Juice.confetti(get_parent(), wo.global_position + Vector2(0, -8))


## Waar je met deze collega naartoe gaat: de ruimte, of het object als je daar
## al staat.
##
## Dit noemde altijd `zone_name`, en dat gaat mis zodra de collega in dezelfde
## ruimte zit als zijn eigen ticket. Daan zit in Summit en BBD-201 ligt op de
## vergadertafel in Summit: je haalde hem daar op en kreeg "Daan loopt mee naar
## Summit" terwijl je er middenin stond. Dat leest als een aanwijzing die je
## nergens heen stuurt.
##
## Dezelfde regel als `Main._wijzer_plek()`: de ruimtenaam beantwoordt "welke
## kant op", en sta je er al, dan is de vraag "wat zoek ik" en is het object het
## betere antwoord.
static func _bestemming(d: NpcDef, t: TicketDef) -> String:
	if d != null and d.zone == t.zone:
		var label := GameData.object_label(t.anchor)
		if label != "":
			return label
	return t.zone_name


## Eén waar feit over dit ticket, in de stem van degene van wie het is.
##
## De feiten komen uit dezelfde config die de minigame straks draait, dus deze
## regel kan niet verouderen; zie `Briefing`.
func briefing(t: TicketDef) -> void:
	await _briefing(t)


func _briefing(t: TicketDef) -> void:
	# Een ticket van iemand (owner_character gezet) brieft via de eigenaar: die
	# heb je net opgehaald, en dít is waarvoor. Speel je hem zelf, dan is het
	# jouw vakgebied en ken je je eigen ticket al.
	if t.owner_character != &"":
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
		return

	# Een ticket van iedereen (BBD-202, BBD-207) heeft geen eigenaar om op te
	# halen, maar kan wel een `briefer` hebben: iemand die vóór de minigame één
	# feit vertelt zonder dat je hem ophaalt. Speel je de briefer zelf, dan
	# zwijgt hij — je kent je eigen feit al, net als een eigenaar bij zijn eigen
	# ticket.
	if t.briefer == &"" or t.briefer == Session.character_id:
		return
	var tekst2 := Briefing.regel(t)
	if tekst2 == "":
		return
	var d2: NpcDef = GameData.npc(StringName("npc_%s" % t.briefer))
	if d2 == null:
		return
	await _dialogue.say(d2.name, tekst2, t.briefer)


# --- Wereldhandelingen (F4-b) ----------------------------------------------
#
# Drie tickets kregen geen afgesloten minigame-overlay meer, maar
# lossen op dóór in de wereld te handelen: een gesprek, een keuze bij een
# object, een collega aanspreken. BBD-207 hoorde hier ooit ook bij
# (`mg_muziek`/`_wh_muziek()`), tot het een echte minigame-overlay terugkreeg
# in de vorm van een gevecht (`mg_abgevecht.gd`) — zie de Deel 3-notitie bij
# `data/tickets/t07.json`. `content` is hier altijd al de config zoals
# de oude minigame hem zou hebben gekregen — inclusief het TraitModifier-
# voordeel van je eigen vakgebied — dus deze functies hoeven zelf niets van
# traits te weten. Ze hergebruiken uitsluitend bestaande grammatica:
# `DialogueController.ask_choice()` / `.say()`, en de gewone `MinigameResult`.
#
# Geen van de vier kan hier nog mislukken: dat is een bewuste keuze en geen
# oude bug die is blijven staan. Een wereldhandeling is een gewone interactie
# en geen toets — de kwaliteit van je keuze landt in het `payload`-dict voor
# een latere stap (F4-d), niet in een pass/fail-scherm. Alleen BBD-209 kan nog
# "niet af" zijn: die wacht op het aanspreken van een paard, niet op een
# score.

func _resolve_wereldhandeling(t: TicketDef, inhoud: Dictionary, via_npc: bool) -> MinigameResult:
	var content: Dictionary = inhoud if not inhoud.is_empty() else MinigameContent.get_config(t.minigame_id)
	match t.minigame_id:
		&"mg_klantfeedback":
			return await _wh_klantfeedback(content)
		&"mg_backend_fix":
			return await _wh_backend(content)
		&"mg_paarden":
			return await _wh_paarden(t, content, via_npc)
		_:
			push_error("TicketController: geen wereldhandeling-resolver voor '%s'" % t.minigame_id)
			return MinigameResult.aborted(t.minigame_id)


## BBD-203, De klant heeft feedback. Willem (of jij, in zijn vakgebied) vertaalt
## haar drie tegenstrijdige rondes rechtstreeks in het lopende gesprek — een
## echte keuze per ronde in plaats van een quiz waarvan knop 1 altijd goed was.
##
## P4: zij wacht niet. Elke ronde krijgt `ronde_sec` seconden op de balk boven
## de knoppen (`DialogueController.ask_choice()`); loopt die leeg, dan levert
## die ronde nul punten op en typt zij door. Dat is de enige manier waarop je
## hier punten kunt laten liggen zonder een verkeerd antwoord te geven, en het
## is precies wat een gesprek met een ongeduldige klant duur maakt. Willems
## vakgebiedvoordeel verlaagt niet alleen de drempel maar verlengt ook die
## klok (`TraitModifier._choicescene()`): hij weet wat hij moet vragen én hij
## krijgt de ruimte om het te vragen.
func _wh_klantfeedback(content: Dictionary) -> MinigameResult:
	var intro := String(content.get("intro", ""))
	if intro != "":
		await _line(intro)

	var score := 0
	for raw: Variant in (content.get("rondes", []) as Array):
		var ronde := raw as Dictionary
		var opties: Array[Dictionary] = []
		for o_raw: Variant in (ronde.get("opties", []) as Array):
			var o := o_raw as Dictionary
			if Conditions.check(o.get("when", {}) as Dictionary):
				opties.append(o)
		if opties.is_empty():
			continue

		var labels: Array[String] = []
		for o: Dictionary in opties:
			labels.append(String(o.get("tekst", "...")))
		var i := await _dialogue.ask_choice(String(ronde.get("prompt", "")), labels,
			float(content.get("ronde_sec", 8.0)))
		if i == DialogueController.KEUZE_VERLOPEN:
			# Nul punten voor deze ronde, en zij merkt het op. Geen tweede kans:
			# een klok die je opnieuw mag proberen is geen klok.
			var stilte := String(content.get("timeout_reactie", ""))
			if stilte != "":
				await _line(stilte)
			continue
		if i < 0 or i >= opties.size():
			continue

		var gekozen := opties[i]
		score += int(gekozen.get("punten", 0))
		var reactie := String(gekozen.get("reactie", ""))
		if reactie != "":
			await _line(reactie)

	var drempel := int(content.get("drempel", 0))
	var eindtekst := String(content.get("success", "")) if score >= drempel else String(content.get("failure", ""))
	if eindtekst != "":
		await _line(eindtekst)
	return MinigameResult.make(&"mg_klantfeedback", GameEnums.Outcome.SUCCESS, score,
		{"score": score, "drempel": drempel})


## BBD-205, De backend is stuk. Jonathans briefing gaf de aanwijzing; de
## dialoogkeuze bij het serverrack is de handeling zelf. `set_modulate` (via
## WorldMutator, op `reward_effects`/`world_changes` van t05) is het zichtbare
## gevolg zodra `QuestEngine.complete()` draait — niets nieuws nodig hier.
##
## P4: één keuze zonder prijs is geen keuze. Een verkeerde kabel geeft nu een
## schok, een rode flits, een kwartier op de urenstaat en een regel, en daarna
## kies je opnieuw uit wat er nog ligt. De juiste kabel blijft altijd staan
## (`kabels_na_fout()`), dus het ticket loopt gegarandeerd af: de prijs is tijd
## en de bug van morgen, nooit voortgang. `juist` in de payload betekent
## sindsdien "in één keer goed" — dat is wat `Gevolgen.boek()` uitleest voor
## `gevolg_backend_fout_gekozen`, en één foute kabel is genoeg voor die bug.
func _wh_backend(content: Dictionary) -> MinigameResult:
	var intro := String(content.get("intro", ""))
	if intro != "":
		await _line(intro)

	var labels_van_id := {}
	for raw: Variant in (content.get("nodes", []) as Array):
		var n := raw as Dictionary
		labels_van_id[String(n.get("id", ""))] = String(n.get("label", n.get("id", "")))

	var opties := kabelopties(content)
	if opties.is_empty():
		return MinigameResult.make(&"mg_backend_fix", GameEnums.Outcome.SUCCESS, 1,
			{"juist": true, "pogingen": 0})

	# Volgorde husselen, niet de opties zelf: `opties[0]` blijft "de juiste" voor
	# de payload, `over` bepaalt alleen waar die op het scherm komt en welke
	# kabels er na een foute keuze nog liggen.
	var over: Array = range(opties.size())
	over.shuffle()

	var pogingen := 0
	var juist := false
	while not over.is_empty():
		var labels: Array[String] = []
		for idx: int in over:
			labels.append(_kabelregel(opties[idx] as Array, labels_van_id))
		var gekozen := await _dialogue.ask_choice("Welke kabel leg je?", labels)
		if gekozen < 0 or gekozen >= over.size():
			# `ask_choice()` weigerde (er liep al een gesprek) en heeft dat zelf
			# geteld. Nog een ronde opendraaien maakt daar een lus van die
			# niemand ziet en die nooit stopt.
			break
		pogingen += 1
		if int(over[gekozen]) == 0:
			juist = pogingen == 1
			break
		_kabel_kost()
		var fout_regel := String(content.get("fout_reactie", ""))
		if fout_regel != "":
			await _line(fout_regel)
		over = kabels_na_fout(over, gekozen)

	var eindtekst := String(content.get("success", "")) if juist else String(content.get("failure", ""))
	if eindtekst != "":
		await _line(eindtekst)
	return MinigameResult.make(&"mg_backend_fix", GameEnums.Outcome.SUCCESS, 1 if juist else 0,
		{"juist": juist, "pogingen": pogingen})


## De kabels waaruit je kiest: de juiste op index 0, daarna de afleiders die er
## na Jonathans vakgebiedvoordeel nog bij liggen. Niet in die volgorde getoond
## — de briefing heeft de juiste net voorgezegd, dus knop 1 zou altijd goed
## zijn zonder dat de speler ook maar hoefde te lezen.
##
## Jonathans vakgebiedvoordeel (`TraitModifier._cableboard()`) knipt de
## afleiderslijst in, maar zonder deze `bonus` bleef hier altijd `mini(2, …)`
## staan — twee foute kabels, getrimd of niet. Vergelijk met het ongetrimde
## bestand en trek het verschil van het aantal getoonde afleiders af, zodat
## "Minder losse draden." ook echt minder losse draden op het scherm zet.
##
## Die aftrek zakte hier ooit tot 0 getoonde afleiders: `MINDER_AFLEIDERS` is 2,
## en met `bonus` ook 2 werd `mini(2, afleiders.size()) - bonus` exact 0 zodra
## de ingekorte lijst nog minstens twee afleiders had (wat bij BBD-205 het geval
## is — zes basisafleiders min twee is nog altijd vier). Dan bleef er precies
## één optie over — de juiste, zonder keuze en zonder "verkeerde kabel"-prijs.
## De regel is: altijd minstens twee opties zolang de data een afleider kent.
## Vandaar geclampt op minimaal 1 getoonde afleider in plaats van rechtstreeks
## op `mini(2, …) - bonus`.
##
## Static, zodat de suite de opgave zonder wereld kan narekenen.
static func kabelopties(content: Dictionary) -> Array:
	var verbindingen: Array = content.get("verbindingen", [])
	if verbindingen.is_empty():
		return []
	var afleiders: Array = content.get("afleiders", [])
	if afleiders.is_empty():
		return [verbindingen[0]]
	var basis_afleiders: int = (MinigameContent.get_config(&"mg_backend_fix").get(
		"afleiders", []) as Array).size()
	var bonus := maxi(0, basis_afleiders - afleiders.size())
	var aantal_getoond := maxi(1, mini(2, afleiders.size()) - bonus)
	var opties: Array = [verbindingen[0]]
	for i: int in range(aantal_getoond):
		opties.append(afleiders[i])
	return opties


## Wat er na een foute keuze nog op het scherm ligt: de gekozen kabel gaat
## eruit, de rest houdt zijn volgorde. De juiste (index 0) kan er nooit uit,
## dus is de laatste overgebleven optie hoe dan ook de juiste — daar eindigt de
## handeling mee, ook als je alle afleiders eerst probeert.
##
## Static en zonder scherm, zodat de suite de hele reeks foute keuzes kan
## narekenen zonder een dialoogbox te openen.
static func kabels_na_fout(over: Array, gekozen: int) -> Array:
	if gekozen < 0 or gekozen >= over.size() or int(over[gekozen]) == 0:
		return over.duplicate()
	var uit: Array = over.duplicate()
	uit.remove_at(gekozen)
	return uit


static func _kabelregel(paar: Array, labels_van_id: Dictionary) -> String:
	var a := String(labels_van_id.get(String(paar[0]), paar[0]))
	var b := String(labels_van_id.get(String(paar[1]), paar[1]))
	return "Verbind %s met %s." % [a, b]


## Wat een verkeerde kabel kost: een vonk die je voelt, een die je ziet, en een
## kwartier dat op de urenstaat blijft staan. Geen toast erbij — de HUD-klok
## rolt zelf, en een tweede melding boven een regel tekst is ruis.
func _kabel_kost() -> void:
	Juice.schok()
	Juice.flits(UiKit.ROOD)
	AudioDirector.play_sfx(&"fout")
	Session.book_time(Urenstaat.FOUT_MIN, &"fout")


## BBD-207, We hebben muziek nodig. Drie tags in plaats van twaalf, één
## dialoogkeuze bij de speaker in plaats van een kapot gerenderd tag-scherm.
## De grap (hardstyle, panfluit, ...) blijft gewoon in de content staan.
## BBD-209, Paardenbugs. Via het scrumbord (`via_npc == false`) kom je hier
## zonder ooit een paard te hebben aangesproken: dan is er niets te doen, en
## blijft het ticket ACTIVE (net als "Stoppen" in een oude minigame). Via een
## bugpaard (`handle_npc_talk()`) IS het aanspreken zelf de handeling.
##
## Bastiaans vakgebiedvoordeel (`TraitModifier._whack()`) zet `paard_komt`.
## Dat was `geen_zoektocht`: het ticket loste zichzelf op vanaf het bord, en
## daarmee nam zijn eigen vakgebied de enige handeling van zijn eigen ticket
## weg. Nu pint en zoekt iedereen, en loopt het dichtstbijzijnde bugpaard naar
## hem toe terwijl hij loopt. Aanspreken doet hij zelf.
## De opdracht wordt hier ook echt een opdracht, en niet alleen een zin.
##
## Hier stond alleen die ene vertellerregel, gevolgd door `aborted()`. Daarna
## veranderde er niets: het ticket stond niet gepind, en de doelwijzer bleef naar
## het paardenkostuum wijzen — het object dat je net dezelfde regel gaf. Wie
## erop terugliep kreeg hem opnieuw. Dat is de lus waarin dit ticket leest als
## "hij legt wat uit en er triggert niks".
##
## `Session.pin()` zet het bovenaan het bord en op de doelregel;
## `Main._doel_node()` stuurt de wijzer daarna naar een paard in plaats van naar
## het kostuum.
func _wh_paarden(t: TicketDef, content: Dictionary, via_npc: bool) -> MinigameResult:
	if not via_npc:
		Session.pin(t.id)
		var komt := bool(content.get("paard_komt", false)) and _stuur_paard_naar_speler()
		var intro := String(content.get("intro", ""))
		if intro == "":
			intro = "Ze lopen ergens rond: in de gang, op het toilet, zelfs in Weekend. Spreek er een aan."
		if komt:
			intro += " Eén draait zich om en komt jouw kant op."
		await _line(intro)
		Bus.toast_requested.emit("Spreek een paardenbug aan", &"volgen")
		return MinigameResult.aborted(t.minigame_id)
	return MinigameResult.make(t.minigame_id, GameEnums.Outcome.SUCCESS, 1,
		{"paard": true, "zelf_gevonden": via_npc})


## Het dichtstbijzijnde bugpaard naar de speler laten lopen; true als er ook
## echt eentje op weg is gegaan.
##
## `loop_naar()` en niet `start_following()`: volgen meldt de NPC aan als
## collega (`Session.add_follower()`, `Bus.follower_joined`, de HUD-rij met
## wie er met je meeloopt), en een bug in een paardenkostuum is geen collega
## die je hebt opgehaald. Eén gerichte wandeling over de vloer is precies wat
## het voordeel belooft: hij komt naar je toe, en aanspreken doe je zelf.
func _stuur_paard_naar_speler() -> bool:
	var main := get_parent()
	var speler := main.get("player") as Node2D
	var laag := main.get("npc_layer") as NpcLayer
	if speler == null or laag == null:
		return false
	var paard := laag.dichtstbijzijnde_met_prefix("paard_bug", speler.global_position)
	if paard == null:
		return false
	paard.loop_naar(speler.global_position)
	return true


# --- Collega aanspreken ---------------------------------------------------

func handle_npc_talk(source: Interactable) -> void:
	if _slot_houdt("collega aanspreken"):
		return
	var npc := source.get_parent() as Npc
	if npc == null:
		return

	# BBD-209: de paarden lopen als wereldobjecten door het kantoor, en het
	# aanspreken van een bugpaard IS de handeling die het ticket oplost — geen
	# apart scherm, geen minigame. `_handle_inner()` doet verder precies
	# hetzelfde als bij elk ander ticket (activeren, briefje, eigen-vakgebied,
	# briefing); alleen de resolutiestap verschilt via `via_npc`.
	if String(npc.npc_id).begins_with("paard_bug"):
		_neem_slot()
		await _handle_inner(GameData.ticket(&"t09"), true)
		_busy = false
		return
	# Het klantpaard-dat-op-een-bug-lijkt blijft de grap uit de oude
	# `mg_whack`: hem aanspreken lost niets op, want hij is geen bug.
	if npc.npc_id == &"paard_klant_decoy":
		_neem_slot()
		await _line("Gewoon een paard van de klant. Geen bug — hij hoort hier niet, maar hij hoort ook nergens.")
		_busy = false
		return

	_neem_slot()
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
			# Vangnet voor een ticket zonder wervingsboom. Ook hier eerst de
			# hulpvraag: waarom je iemand ophaalt hoort in de eerste regel te
			# staan, niet in de aanname dat de collega het al weet.
			await _line("Je legt %s uit. %s: \"Kom, ik loop even mee.\"" % [
				wanted.code, npc.def.name])
		npc.start_following(get_parent().get("player") as Node2D)
		# De bestemming erbij: de toast is vluchtig, dus hij moet iets zeggen wat
		# nergens anders staat. Wie er meeloopt staat vanaf nu permanent op de
		# doelregel en op het bord.
		Bus.toast_requested.emit(
			"%s loopt mee naar %s" % [npc.def.name, _bestemming(npc.def, wanted)], &"volgen")
		# Het briefje ná het gesprek: bij een object is het briefje de vondst,
		# hier is het gesprek de werving en het briefje het gevolg. En hier heeft
		# de melding een echte afzender — dit ticket komt van deze collega.
		if _hud != null:
			await _hud.toon_ticket_melding(wanted, npc.def.name)
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
	# Als spreker en niet als verteltekst: zo krijgt hij zijn naamregel, zijn
	# portret zodra dat bestaat, en beweegt zijn mond mee (npc.gd luistert op
	# `dialogue_started` en vergelijkt op id).
	await _dialogue.say(npc.def.name, _dirk_oordeel(p), npc.npc_id)


## Zijn slotregel hangt af van waar je de uren hebt weggeschreven. Nooit een
## verwijt, altijd een observatie met een getal erin.
##
## De keuze staat hier, de tekst niet. Welke van de vier regels het wordt hangt
## af van de payload van de minigame (`op_rest`, `lege_tickets`) -- getallen die
## `Conditions` niet kent, dus dat kan geen dialoogvariant zijn. Wat hij zégt
## hoort wel in de data: stond het hier als string, dan is het de enige stem in
## het spel die `_test_karakterstemmen()` niet leest, en precies daar liep hij
## zijn eigen tics mis.
static func _dirk_oordeel(p: Dictionary) -> String:
	var rest := int(p.get("op_rest", 0))
	var leeg := int(p.get("lege_tickets", 0))

	var nid := &"rest"
	if rest >= 4 * 60:
		nid = &"veel_rest"
	elif leeg > 0:
		nid = &"lege_tickets"
	elif rest == 0:
		nid = &"alles_geboekt"

	var def: DialogueDef = GameData.dialogue(&"dirk_urenstaat")
	if def == null:
		push_error("TicketController: dialoogboom 'dirk_urenstaat' ontbreekt")
		return ""
	# {naam} en de klok vult DialogueController.vul_in() zelf in; deze twee
	# staan alleen in de payload van de minigame.
	return String(def.node(nid).get("text", "")) \
		.replace("{rest}", Urenstaat.formatteer_duur(rest)) \
		.replace("{aantal}", str(leeg))


## Het open ticket waarvoor deze NPC de eigenaar is. Danny bezit er twee en Daan
## ook, dus één collega kan voor meerdere dingen gevraagd worden zodra die
## tickets tegelijk open staan. Je pin wint; anders vraagt hij waar het over gaat.
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
	var basis := "Dit is niet jouw vakgebied. Je hebt %s nodig, %s." % [who, role]
	if d == null:
		return basis
	# Zelfde locatiestaart als de doelregel (Hud._aanduiding()), geen tweede
	# implementatie van "waar zit deze collega".
	var waar := Hud._aanduiding(d.zone, d.plek)
	if waar == "":
		return basis
	return "%s %s%s." % [basis, waar.substr(0, 1).to_upper(), waar.substr(1)]


## Waarom hier nog niets ligt. Hier stond "Hier is nu niets te doen." — één
## regel voor alle vijf de vergrendelde tickets, zonder één woord over wat het
## losmaakt. De keten bestond dus wel en was onzichtbaar.
func _locked_hint(t: TicketDef) -> String:
	var blok: TicketDef = QuestEngine.blokkerend_ticket(t.id)
	if blok != null:
		return "Dit werk bestaat nog niet. Het komt er zodra %s klaar is." % blok.code
	var nodig: int = QuestEngine.blokkerend_aantal(t.id)
	if nodig > 0:
		return "Dit is het laatste. Er moeten eerst nog %d tickets af." % nodig
	return "Hier is nu niets te doen."


func _line(text: String) -> void:
	await _dialogue.say("", text)


func _play_or_line(dialogue_id: StringName, fallback: String) -> void:
	if dialogue_id != &"":
		await _dialogue.play(dialogue_id)
	else:
		await _line(fallback)
