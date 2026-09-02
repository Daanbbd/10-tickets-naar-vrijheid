extends Node2D
## Orkestreert de kantoorwereld. De boot-volgorde is expliciet en hangt niet af
## van de _ready-volgorde van siblings.

const PLAYER_SCENE := "res://scenes/entities/player.tscn"
const OBJECTS_JSON := "res://data/objects.json"

## De zeven light-moods uit floor.json waren geschreven en werden door niets
## gelezen. Dit maakt van 60% identiek grijs acht ruimtes die anders voelen.
## Subtiel houden: dit is een tint, geen kleurfilter. Bij een sterkere waarde
## wordt de grijze betonvloer zichtbaar bruin of blauw, en dan klopt het beeld
## niet meer met de referentiefoto's.
const LICHT: Dictionary = {
	"warm": Color(1.02, 1.00, 0.96),
	"neutraal": Color(1.0, 1.0, 1.0),
	"koel": Color(0.98, 1.00, 1.03),
	"koud": Color(0.95, 0.98, 1.04),
	"klinisch": Color(1.01, 1.02, 1.02),
	"donker": Color(0.88, 0.87, 0.86),
	"dim": Color(0.92, 0.94, 0.93),
	"jungle": Color(0.97, 1.02, 0.97),
}

var _licht_tween: Tween = null

@onready var ground: TileMapLayer = $World/Ground
@onready var solid: TileMapLayer = $World/Solid
@onready var objects_layer: Node2D = $World/Objects
@onready var npc_layer: NpcLayer = $World/Entities/Npcs
@onready var entities: Node2D = $World/Entities
@onready var camera: GameCamera = $GameCamera
@onready var registry: WorldRegistry = $WorldRegistry
@onready var mutator: WorldMutator = $WorldMutator
@onready var tickets: TicketController = $TicketController
@onready var dialogue: DialogueController = $DialogueController
@onready var hud: Hud = $HUD
@onready var licht: CanvasModulate = $Licht
@onready var storingen: Storingen = $Storingen

var builder: WorldBuilder = WorldBuilder.new()
var player: Player = null
var _pauzemenu: Pauzemenu = null

var _zone_id: StringName = &""
## Waar de doelwijzer nu aan hangt. Ook de bron van de kompasstrip, zodat die
## twee nooit uit elkaar kunnen lopen.
var _doelwit: Node2D = null
## Alleen voor de speelbeurt-harnas: hoeveel meldingen van De Klant er gevallen zijn.
var _klant_meldingen: int = 0

## Zolang de intro loopt houdt de vloer zijn tickets vast. Zonder dit vuurt
## _report_tile() op physics-frame 1 al een toast af over BBD-203: boven de
## infade, voordat het spel het woord "ticket" heeft gezegd, en zonder dat de
## speler een stap heeft gezet. Precies de omgekeerde les.
var _intro_loopt: bool = false
var _uitgestelde_zone: StringName = &""


func _ready() -> void:
	registry.add_to_group(&"world_registry")

	if not builder.load_floor():
		push_error("Main: kon de vloer niet laden")
		return

	builder.populate(ground, solid)
	_spawn_props()
	_spawn_objects()

	npc_layer.setup(builder)
	registry.build()
	mutator.setup(registry, npc_layer)
	dialogue.setup()
	tickets.setup(registry, npc_layer, builder)
	hud.setup()

	# De Klant hangt naast de HUD in plaats van erin: zij is geen schermbeeld
	# van jouw voortgang maar iemand die zich meldt. Eigen CanvasLayer, boven
	# de dialoog en onder de minigame.
	var telefoon := Telefoon.new()
	telefoon.name = "Telefoon"
	add_child(telefoon)
	telefoon.setup()

	# De besturing hangt naast de HUD in plaats van erin: de knoppenbalk drukt
	# alleen de gewone acties in, dus hij hoort niet bij het schermbeeld.
	# Onvoorwaardelijk — er is één besturing, ook met een toetsenbord erbij.
	var besturing := Besturing.new()
	besturing.name = "Besturing"
	add_child(besturing)
	besturing.setup()

	# Het pauzemenu draait op PROCESS_MODE_ALWAYS en is dus het enige dat nog
	# leeft zodra de wereld stilstaat. Eigen CanvasLayer (40): boven de telefoon,
	# onder de minigame.
	_pauzemenu = Pauzemenu.new()
	_pauzemenu.name = "Pauzemenu"
	add_child(_pauzemenu)
	_pauzemenu.setup()

	# De wereld is een pure functie van Session: speel alles opnieuw af.
	mutator.replay_all()

	_spawn_player()
	npc_layer.spawn_initial()
	camera.setup(player, builder.world_rect())
	# Generaliseert Dirk: welke collega's langskomen, wat er stukgaat, staat in
	# data/storingen.json in plaats van in een naam-check. Na de speler en de
	# NPC's, want de node moet ze allebei kunnen aanspreken.
	storingen.setup(npc_layer, mutator, player)

	Bus.ticket_completed.connect(_on_ticket_completed)
	Bus.ticket_state_changed.connect(func(_a: StringName, _b: GameEnums.TicketState) -> void: _refresh_marker())
	Bus.ticket_completed.connect(func(_a: StringName, _b: MinigameResult) -> void: _refresh_marker())
	Bus.follower_joined.connect(func(_a: StringName) -> void: _refresh_marker())
	Bus.follower_released.connect(func(_a: StringName) -> void: _refresh_marker())
	Bus.flag_changed.connect(func(_a: StringName, _b: bool) -> void: _refresh_marker())
	_refresh_marker()
	Bus.game_started.emit()
	AudioDirector.set_base(&"kantoor")
	_qa_bord()
	_qa_kaart()
	_qa_hint()
	_qa_briefing()

	if Autopilot.gevraagd():
		add_child(Autopilot.new())
	if "--playthrough" in OS.get_cmdline_user_args():
		# De spanningsboog is het enige systeem dat niet uit een minigame of een
		# ticketstand blijkt: als De Klant zich nooit meldt, ziet een speelbeurt
		# er precies hetzelfde uit en valt de hele escalatie stil zonder fout.
		# Daarom logt de harnas haar meldingen, en controleert hij aan het eind
		# of alle vier de drempels gevallen zijn.
		Bus.klant_bericht.connect(func(bid: StringName) -> void:
			_klant_meldingen += 1
			print("[SPEELBEURT] De Klant meldt zich: %s  (bij %d/10)" % [
				bid, Session.done_count()]))
		_qa_playthrough()
	else:
		_qa_kijk()
		_qa_auto()
		_intro_beat()




## Zet het wijzertje op het huidige doel: eerst de collega die nog opgehaald moet
## worden, daarna het object. Er leeft er altijd maximaal één.
func _refresh_marker() -> void:
	for m: Node in get_tree().get_nodes_in_group(&"objective_marker"):
		m.queue_free()
	_doelwit = null

	var t: TicketDef = QuestEngine.next_hint_ticket()
	if t == null:
		_mark_object(&"voordeur")
		_kompas_bijwerken()
		return

	if not QuestEngine.is_own_expertise(t.id) and not Session.get_flag(QuestEngine.helper_flag(t.id)):
		var helper := npc_layer.find_npc(QuestEngine.required_helper(t.id))
		if helper != null and not helper.is_following():
			_mark_node(helper)
			_kompas_bijwerken()
			return
	_mark_object(t.anchor)
	_kompas_bijwerken()


func _mark_object(world_id: StringName) -> void:
	var wo := registry.get_by_id(world_id)
	if wo != null:
		_mark_node(wo)


func _mark_node(n: Node2D) -> void:
	var m := ObjectiveMarker.new()
	# De wijzer meet zijn afstand vanaf de speler en zegt in welke ruimte het
	# doel staat. Beide weet hij zelf niet: hij hangt aan het doel en kent alleen
	# zijn ouder. Dus krijgt hij ze hier mee, van de enige plek die de speler,
	# de vloer en het doel tegelijk in handen heeft.
	m.speler = player
	m.plek = String(builder.zone_at(builder.world_to_tile(n.global_position)).get("name", ""))
	m.meter_per_px = builder.meters_per_pixel()
	n.add_child(m)
	_doelwit = n


## De kompasstrip in de HUD: waar sta jij, waar staat je doel, op ware schaal.
##
## Het doel komt uit dezelfde `_refresh_marker()` die de wijzer plaatst, dus de
## strip en het driehoekje kunnen elkaar niet tegenspreken. `QuestEngine`
## bepaalt wélk ticket dat is; hier wordt alleen een positie doorgegeven.
func _kompas_bijwerken() -> void:
	if hud == null or player == null:
		return
	var doel := -1
	if is_instance_valid(_doelwit):
		doel = builder.world_to_tile(_doelwit.global_position).x
	hud.zet_kompas(builder.world_to_tile(player.global_position).x, doel)


## De uitleg (aantal, spreiding, bord, collega ophalen) staat sinds kort vóór
## character select op een eigen scherm (`IntroUitleg`); hier blijft alleen het
## mechanische deel over: de eerste vondst niet als toast tijdens de infade,
## maar als bordbeat zodra de speler kan kijken.
func _intro_beat() -> void:
	if Session.done_count() > 0:
		return
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--auto=") or a.begins_with("--kijk=") \
				or a == "--autoplay" or a == "--playthrough":
			return

	_intro_loopt = true
	await get_tree().create_timer(0.4).timeout

	# De vondst is nu het gevolg van de infade in plaats van een toast die eraan
	# voorafgaat. Er ligt werk in de entree waar je al staat: dit is de eerste
	# keer dat "een ruimte binnenlopen levert een ticket op" iets doet in plaats
	# van iets beweert.
	_intro_loopt = false
	Session.lock_input()
	var nieuw := _vind_werk(_uitgestelde_zone)
	if not nieuw.is_empty():
		await hud.toon_nieuw_briefje(nieuw[0], 2.6)
	Session.unlock_input()

	hud.show_controls_card()


## QA: `-- --speler=x --kijk=<x>,<y>` zet de speler op die tegel en kijkt verder
## nergens naar. `--auto=` kan dit niet vervangen: die triggert de interactie en
## zet dus een dialoogvenster over de onderste derde van het beeld — precies waar
## de slagschaduwen en de raamband staan die je met een `--shot` wilt zien. En
## niet elke plek waar de vloer gecontroleerd moet worden heeft een object.
func _qa_kijk() -> void:
	var arg := ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--kijk="):
			arg = a.trim_prefix("--kijk=")
	if arg == "":
		return
	var d := arg.split(",")
	if d.size() != 2:
		push_error("QA: --kijk verwacht <x>,<y>, kreeg '%s'" % arg)
		return
	var t := Vector2i(int(d[0]), int(d[1]))
	player.global_position = builder.tile_to_world(builder.nearest_walkable(t))
	camera.global_position = player.global_position
	camera.reset_smoothing()


## QA: `-- --speler=x --auto=<world_id>` zet de speler bij een object en
## triggert de interactie meteen. Alleen bedoeld om te testen.
func _qa_auto() -> void:
	var target := ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--auto="):
			target = a.trim_prefix("--auto=")
	if target == "":
		return

	var wo := registry.get_by_id(StringName(target))
	if wo == null:
		push_error("QA: onbekend object '%s'" % target)
		return

	var tile := builder.world_to_tile(wo.global_position)
	player.global_position = builder.tile_to_world(builder.nearest_walkable(tile))
	camera.global_position = player.global_position
	camera.reset_smoothing()

	await get_tree().create_timer(0.4).timeout
	var it := wo.get_node_or_null("Interactable") as Interactable
	if it != null:
		_interact_with(it)


## QA: loopt alle tien de tickets af in de echte runtime, inclusief dialogen,
## minigames en wereldveranderingen. Bewijst dat de hele dag speelbaar is
## zonder dat iemand de toetsen aanraakt.
##
## Geen vaste eenmalige doorloop van t01..t10 meer: sinds F3-c mag een storing
## een opgelost ticket terugzetten naar TO DO ("iets gaat stuk"), en dan hoort
## de harnas het net als een speler gewoon nog een keer op te pakken in plaats
## van vast te lopen op 9/10 omdat zijn beurt al voorbij was. Vandaar de
## buitenste while: die blijft ronden draaien tot alles klaar is, vastloopt,
## of geen enkel ticket in een hele ronde meer vooruit kwam.
func _qa_playthrough() -> void:
	await get_tree().create_timer(0.5).timeout
	var start := Time.get_ticks_msec()

	var vastgelopen := false
	var max_rondes := GameData.ticket_ids().size() * 3
	var ronde := 0
	while not Session.all_done() and ronde < max_rondes and not vastgelopen:
		ronde += 1
		var vooruitgang_deze_ronde := false
		for tid: StringName in GameData.ticket_ids():
			# Synchrone check, geen wachttijd: refresh_availability() draait
			# al binnen QuestEngine.complete(), dus een ticket dat deze ronde
			# nog niet beschikbaar is, wordt dat niet door hier op te wachten.
			# Een LOCKED ticket dat nooit losraakt levert straks een lege
			# ronde op, en dát is de foutmelding.
			if Session.is_done(tid) or not Session.is_available(tid):
				continue
			vooruitgang_deze_ronde = true
			if not await _qa_doe_ticket(tid):
				vastgelopen = true
				break
		if not vooruitgang_deze_ronde and not Session.all_done():
			var vast: Array[String] = []
			for tid2: StringName in GameData.ticket_ids():
				if not Session.is_done(tid2):
					vast.append(GameData.ticket(tid2).code)
			printerr("[SPEELBEURT] vastgelopen: %s werd(en) nooit beschikbaar" % ", ".join(vast))
			break

	if Session.all_done():
		print("[SPEELBEURT] 10/10 — naar de voordeur")
		var gemist := Gevolgen.DREMPELS.size() - _klant_meldingen
		if gemist > 0:
			printerr("[SPEELBEURT] %d van de %d klantmeldingen zijn nooit gevallen" % [
				gemist, Gevolgen.DREMPELS.size()])
		var deur := registry.get_by_id(&"voordeur")
		player.global_position = builder.tile_to_world(
			builder.nearest_walkable(builder.world_to_tile(deur.global_position)))
		await get_tree().create_timer(0.5).timeout
		_verlaat_kantoor()
	else:
		printerr("[SPEELBEURT] MISLUKT op %d/10" % Session.done_count())

	print("[SPEELBEURT] duur: %.1fs" % ((Time.get_ticks_msec() - start) / 1000.0))
	# De urenstaat hoort altijd over de acht uur te gaan; dit is de plek waar een
	# geautomatiseerde doorloop dat laat zien.
	print("[SPEELBEURT] gewerkt: %s, uit om %s (budget %s)" % [
		Urenstaat.formatteer_duur(Session.worked_minutes),
		Urenstaat.formatteer(Urenstaat.nu()),
		Urenstaat.formatteer_duur(Urenstaat.BUDGET_MIN)])
	if "--quit-when-done" in OS.get_cmdline_user_args():
		await get_tree().create_timer(1.0).timeout
		get_tree().quit(0 if Session.all_done() else 1)


## Eén ticket van _qa_playthrough(): kiezen, ophalen, oplossen. Eigen functie
## en geen inline blok in de ronde-lus hierboven, want dit stuk verandert niet
## door de F3-c-herbalancering — alleen hóé vaak en in welke volgorde het
## aangeroepen wordt, veranderde.
func _qa_doe_ticket(tid: StringName) -> bool:
	var t: TicketDef = GameData.ticket(tid)

	# Kiezen wat we gaan doen. Zonder dit vraagt het scrumbord in de gang
	# welk van de twee tickets we bedoelen, en dan blijft de speelbeurt op
	# een dialoogvenster wachten dat niemand wegklikt.
	if "--geen-pin" not in OS.get_cmdline_user_args():
		Session.pin(tid)

	# De collega echt ophalen, niet de vlag zetten. Dit is de route die een
	# speler neemt, en juist daar zat de bug: werven veranderde niets
	# zichtbaars. Alleen als de NPC onvindbaar is valt de speelbeurt terug
	# op de vlag, zodat een spawn-probleem niet als questfout leest.
	#
	# Was die vlag al gezet (een storing zette dit ticket terug naar TO DO
	# ná de eerste keer ophalen), dan verwacht `_ticket_waiting_for()` in
	# ticket_controller.gd geen tweede keer — precies zoals een speler ook
	# niet nog eens naar Jonathan hoeft te lopen om hem te herinneren aan
	# hulp die hij al gaf.
	if not QuestEngine.is_own_expertise(tid) and not Session.get_flag(QuestEngine.helper_flag(tid)):
		var helper_id := QuestEngine.required_helper(tid)
		var helper := npc_layer.find_npc(helper_id)
		if helper == null:
			printerr("[SPEELBEURT] %s: collega '%s' staat niet op de vloer" % [t.code, helper_id])
			QuestEngine.mark_helper_present(tid)
		else:
			player.global_position = builder.tile_to_world(
				builder.nearest_walkable(builder.world_to_tile(helper.global_position)))
			camera.global_position = player.global_position
			camera.reset_smoothing()
			await get_tree().create_timer(0.3).timeout
			tickets.handle_npc_talk(helper.interactable)
			if not await _qa_wacht_tot(func() -> bool: return helper.is_following(), 30.0):
				printerr("[SPEELBEURT] %s: %s liep niet mee" % [t.code, helper_id])
				return false
			print("[SPEELBEURT] %s: %s opgehaald, doel staat op %s" % [
				t.code, helper.def.name, Session.pinned_ticket])
	# benodigde items simuleren (de deploysleutel uit het magazijn)
	for item: Variant in (t.requirements.get("has_item", []) as Array):
		if not Session.has_item(StringName(item)):
			Session.add_item(StringName(item))

	# BBD-209 (F4-b) lost niet meer op via zijn anker: het scrumbord vertelt je
	# alleen dat er ergens een paard loopt. De echte handeling is een dwalende
	# paardenbug aanspreken, dus de speelbeurt doet hier hetzelfde als een
	# speler zou doen — op een paard af lopen in plaats van op het bord.
	if t.minigame_id == &"mg_paarden":
		var paard := npc_layer.find_npc(&"paard_bug_1")
		if paard == null:
			paard = npc_layer.find_npc(&"paard_bug_2")
		if paard == null:
			printerr("[SPEELBEURT] %s: geen paardenbug op de vloer" % t.code)
			return false
		player.global_position = builder.tile_to_world(
			builder.nearest_walkable(builder.world_to_tile(paard.global_position)))
		camera.global_position = player.global_position
		camera.reset_smoothing()
		await get_tree().create_timer(0.3).timeout
		_interact_with(paard.interactable)
	else:
		var wo := registry.get_by_id(t.anchor)
		if wo == null:
			printerr("[SPEELBEURT] %s: anker '%s' ontbreekt" % [t.code, t.anchor])
			return false
		player.global_position = builder.tile_to_world(
			builder.nearest_walkable(builder.world_to_tile(wo.global_position)))
		camera.global_position = player.global_position
		camera.reset_smoothing()
		await get_tree().create_timer(0.3).timeout

		var it := wo.get_node_or_null("Interactable") as Interactable
		_interact_with(it)

	if not await _qa_wacht_tot(func() -> bool: return Session.is_done(tid), 90.0):
		printerr("[SPEELBEURT] %s liep vast" % t.code)
		return false

	print("[SPEELBEURT] %s opgelost  (%d/10)" % [t.code, Session.done_count()])
	# `is_done` valt vóór de urenrol en de afrondingsdialoog, dus de stroom
	# loopt op dit punt nog. Zonder deze wacht racet de harnas het volgende
	# ticket in, en dan weigert `handle_npc_talk()` stil op zijn `_busy`-guard:
	# de collega loopt niet mee en dertig seconden later meldt de speelbeurt
	# "liep niet mee" zonder oorzaak. Dat was geen spelbug — een speler kan
	# zijn eigen dialoog niet inhalen — maar de harnas kan dat wel, en dan
	# test hij iets wat niet bestaat.
	if not await _qa_wacht_tot(func() -> bool: return not tickets.bezig(), 30.0):
		printerr("[SPEELBEURT] %s: de ticketstroom kwam niet tot rust" % t.code)
		return false
	return true


func _qa_wacht_tot(voorwaarde: Callable, timeout: float) -> bool:
	var t := 0.0
	while t < timeout:
		if bool(voorwaarde.call()):
			return true
		await get_tree().process_frame
		t += get_process_delta_time()
	return false


func _unhandled_input(event: InputEvent) -> void:
	if Session.input_locked or Shell.minigame_active():
		return

	# Sluiten doet het menu zelf: zodra het openstaat ligt deze node op pauze en
	# ziet hij geen invoer meer.
	if event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		_pauzemenu.open()
		return

	if event.is_action_pressed("interact"):
		var it := player.probe.current()
		if it != null:
			get_viewport().set_input_as_handled()
			_interact_with(it)
	elif event.is_action_pressed("ticketboard"):
		get_viewport().set_input_as_handled()
		hud.toggle_board()
	elif event.is_action_pressed("hint"):
		get_viewport().set_input_as_handled()
		Bus.hint_requested.emit()


func _interact_with(it: Interactable) -> void:
	if it.world_id == &"voordeur" and Session.all_done():
		_verlaat_kantoor()
		return

	AudioDirector.play_sfx(&"interactie")
	# Een interactie die aankomt voelt anders dan een knop die je indrukt: de
	# knopbalk geeft een TIK zodra je hem raakt, dit is de bevestiging dat er
	# aan de andere kant ook echt iets stond.
	Haptiek.tril(Haptiek.Sterkte.STOOT)
	match it.kind:
		Interactable.Kind.TICKET:
			tickets.handle(it.ticket_id, it)
		Interactable.Kind.TALK:
			tickets.handle_npc_talk(it)
		_:
			_examine(it)


## Samengestelde meubels: de tegel eronder doet de collision en de footprint,
## deze sprite doet het beeld. Zo leest een bureau-eiland als één ontworpen ding
## in plaats van als zestien keer dezelfde tegel.
const PROPS_DIR := "res://assets/sprites/props/"

## Boven de y-sortering uit: een bordje hangt aan het plafond, dus het hoort
## altijd vóór de speler. Ruim boven de vloerlagen (Ground staat op -10) en
## onder alles wat op een CanvasLayer leeft.
const Z_HANGEND := 20


func _spawn_props() -> void:
	for raw: Variant in builder.props:
		var p := raw as Dictionary
		var naam := String(p.get("prop", ""))
		var pad := "%s%s.png" % [PROPS_DIR, naam]
		if not ResourceLoader.exists(pad):
			push_error("Main: propsprite ontbreekt: %s" % pad)
			continue
		var r: Array = p.get("rect", [0, 0, 0, 0])
		var s := Sprite2D.new()
		s.name = "Prop_%s_%d_%d" % [naam, int(r[0]), int(r[1])]
		s.texture = load(pad)
		s.centered = false
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# De sprite mag groter zijn dan de footprint — stoelen horen buiten het
		# blok, op beloopbare vloer, en de slagschaduw valt eronder uit. Daarom
		# centreren op de footprint in plaats van uitlijnen op de linkerbovenhoek.
		var half := Vector2(builder.tile_size, builder.tile_size) * 0.5
		var lb := builder.tile_to_world(Vector2i(int(r[0]), int(r[1]))) - half
		var voetprint := Vector2(
			float(int(r[2]) - int(r[0]) + 1), float(int(r[3]) - int(r[1]) + 1)) * builder.tile_size
		var tex := s.texture.get_size()

		# --- y-sortering op de voet, niet op de bovenrand ---------------------
		# `objects_layer` is y-gesorteerd en Node2D heeft geen `y_sort_origin`
		# zoals TileData: de sorteersleutel is gewoon `position.y`. Met
		# `centered = false` was dat de bovenrand van de sprite, en die ligt bij
		# een eiland van acht tegels 128 px boven zijn voet. Een speler die er
		# noordelijk langs liep sorteerde daardoor vóór het hele blok, en een
		# speler die er zuidelijk van stond kon erachter verdwijnen.
		#
		# De node staat nu op de onderrand van de footprint — dezelfde
		# conventie als `TileData.y_sort_origin = half` in world_builder, en
		# dezelfde als de speler, die zijn oorsprong in zijn voeten heeft. De
		# `offset` zet het beeld daarna terug op zijn plek, dus er verschuift
		# niets zichtbaars: alleen de sleutel klopt.
		if bool(p.get("hangend", false)):
			# Een hangend bordje raakt de vloer nooit: die doet niet mee aan de
			# sortering maar hangt er met een expliciete z_index bovenop.
			s.position = lb + (voetprint - tex) * 0.5
			s.z_index = Z_HANGEND
		else:
			s.position = Vector2(lb.x + (voetprint.x - tex.x) * 0.5, lb.y + voetprint.y)
			s.offset = Vector2(0.0, -(voetprint.y + tex.y) * 0.5)
		objects_layer.add_child(s)


## Een object bekijken: eerst de flavourregel, daarna een eventuele extra actie.
## Zo leert de speler TAB doordat het fysieke ticketbord het echte bord opent.
func _examine(it: Interactable) -> void:
	if it.dialogue_id != &"":
		await dialogue.play(it.dialogue_id, it.label)
	if it.action == &"board":
		# Aan het echte bord sta je ernaast: dat is de close-up. TAB blijft de
		# snelle blik van overal.
		hud.toggle_board(true)


# --- Opbouw ---------------------------------------------------------------

func _spawn_objects() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(OBJECTS_JSON))
	if not (parsed is Array):
		push_error("Main: %s kon niet gelezen worden" % OBJECTS_JSON)
		return

	for raw: Variant in parsed:
		var d := raw as Dictionary
		var wo := WorldObject.new()
		wo.world_id = StringName(d.get("world_id", ""))
		wo.name = "Obj_%s" % wo.world_id
		var t: Array = d.get("tile", [0, 0])
		wo.position = builder.tile_to_world(Vector2i(int(t[0]), int(t[1])))
		objects_layer.add_child(wo)

		# Optioneel beeld op het object zelf. Vandaag zet geen enkel object dit,
		# dus dit is een no-op — maar zodra de vloer echte propsprites aan een
		# world_id hangt, is dit de plek waar ze binnenkomen, en werkt
		# `set_modulate` op dat object meteen mee.
		wo.set_sprite(String(d.get("sprite", "")))

		var area := Interactable.new()
		area.name = "Interactable"
		area.world_id = wo.world_id
		area.kind = _kind_from(String(d.get("kind", "examine")))
		area.label = String(d.get("label", ""))
		area.ticket_id = StringName(d.get("ticket", ""))
		area.dialogue_id = StringName(d.get("dialogue", ""))
		area.available_when = d.get("visible_when", {}) as Dictionary
		area.action = StringName(d.get("action", ""))

		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 13.0
		shape.shape = circle
		area.add_child(shape)
		wo.add_child(area)


static func _kind_from(s: String) -> Interactable.Kind:
	match s:
		"talk": return Interactable.Kind.TALK
		"use": return Interactable.Kind.USE
		"ticket": return Interactable.Kind.TICKET
		"door": return Interactable.Kind.DOOR
		_: return Interactable.Kind.EXAMINE


func _spawn_player() -> void:
	player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	entities.add_child(player)
	player.global_position = builder.tile_to_world(builder.nearest_walkable(builder.spawn_tile))
	player.setup(Session.character(), builder.tile_size)
	player.moved_to_tile.connect(_on_player_tile)


# --- Wereldreacties -------------------------------------------------------

## QA: `--bord` opent het sprintbord meteen, zodat het te controleren is.
func _qa_bord() -> void:
	if "--bord" not in OS.get_cmdline_user_args():
		return
	await get_tree().create_timer(0.5).timeout
	hud.toggle_board()


## QA: `--briefing=<ticket>` speelt de briefing van dat ticket meteen af.
##
## De briefing is de plek waar een collega een mens wordt in plaats van een
## sleutel, en dus de plek waar de tekst het meest telt. Zonder deze vlag is hij
## alleen te zien door een halve speelbeurt te spelen tot precies het juiste
## moment, en dan is prozacontrole een kwestie van frames jagen. Het langste
## exemplaar (BBD-208) is ruim tweehonderd tekens, dus of hij in het
## dialoogvenster past is een echte vraag.
func _qa_briefing() -> void:
	var doel := ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--briefing="):
			doel = a.trim_prefix("--briefing=")
	if doel == "":
		return
	var t: TicketDef = GameData.ticket(StringName(doel))
	if t == null:
		push_error("QA: onbekend ticket '%s'" % doel)
		return
	await get_tree().create_timer(0.5).timeout
	await tickets.briefing(t)


## QA: `--hint` vraagt meteen een hint aan, zodat het briefje in beeld staat.
##
## Zonder deze vlag is het alleen te zien door de hintknop in te drukken of door
## vijfenveertig seconden niets te doen, en geen van beide past in een `--shot`.
## Dat is precies het verkeerde ding om ongezien te laten: de hint blijft nu
## staan tot je hem wegtikt, dus als hij ergens overheen valt blijft dat ook
## staan. Het langste exemplaar (BBD-210) is 184 tekens.
func _qa_hint() -> void:
	if "--hint" not in OS.get_cmdline_user_args():
		return
	await get_tree().create_timer(0.6).timeout
	Bus.hint_requested.emit()


## QA: `--kaart` zet de besturingskaart in beeld en laat hem staan.
##
## Zonder deze vlag was de kaart alleen te zien door de intro uit te spelen of
## F1 in te drukken, en dus niet met een `--shot` te controleren. Dat is precies
## het scherm dat vertelt hoe het spel werkt, dus dat hoort in beeld te kunnen
## komen zonder een mens aan het toetsenbord.
func _qa_kaart() -> void:
	if "--kaart" not in OS.get_cmdline_user_args():
		return
	await get_tree().create_timer(0.5).timeout
	hud.show_controls_card(600.0)


func _on_player_tile(t: Vector2i) -> void:
	# Eén pixel per tegel, dus per tegel bijwerken is precies de resolutie van de
	# strip. Vaker zou niets veranderen en wel elke frame een redraw kosten.
	_kompas_bijwerken()
	var z := builder.zone_at(t)
	var zid := StringName(z.get("id", ""))
	if zid != _zone_id and zid != &"":
		_zone_id = zid
		_tint_zone(String(z.get("light", "neutraal")))
		Bus.zone_entered.emit(zid, String(z.get("name", "")))
		_vind_werk(zid)
	if zid == &"z10_weekend":
		_weekend_duwt_terug()


## Een ruimte binnenlopen levert het werk op dat daar ligt. Dat is de reden om
## te verkennen nu niets meer achter een ander ticket zit.
##
## Eén melding voor de hele ruimte, niet één per ticket: op De Vloer hangen er
## drie, en drie toasts achter elkaar leest als een foutmelding.
##
## Retourneert wat er gevonden is, zodat _intro_beat() de vondst die hij heeft
## uitgesteld zelf kan tonen in plaats van als toast.
func _vind_werk(zone_id: StringName) -> Array[TicketDef]:
	if _intro_loopt:
		_uitgestelde_zone = zone_id
		return []
	var nieuw := QuestEngine.discover_in_zone(zone_id)
	if nieuw.is_empty():
		return []
	if nieuw.size() == 1:
		Bus.toast_requested.emit("Nieuw ticket: %s" % nieuw[0].code, &"ticket")
	else:
		var codes: Array[String] = []
		for t: TicketDef in nieuw:
			codes.append(t.code)
		Bus.toast_requested.emit("%d tickets gevonden: %s" % [
			nieuw.size(), ", ".join(codes)], &"ticket")
	AudioDirector.play_ui(&"pak")
	_refresh_marker()
	return nieuw


## Weekend is van het designbureau waar we de vloer mee delen. Je mag er komen,
## maar niets houdt je er. Geen onzichtbare muur: een reeks opmerkingen die
## steeds ongeduldiger worden, zodat teruglopen jouw idee lijkt.
const WEEKEND_DUW := [
	"Er gebeuren hier rare dingen. Ga terug.",
	"Dit is te veel geluid. AAA.",
	"Iemand vraagt of je van de podcast bent. Je bent niet van de podcast.",
	"Er staat een plant die je aankijkt.",
	"Dit is hun vloer. Dat is duidelijk.",
]
const WEEKEND_PAUZE := 4.5

var _weekend_t: float = 0.0
var _weekend_i: int = 0


func _weekend_duwt_terug() -> void:
	if _weekend_t > 0.0:
		return
	_weekend_t = WEEKEND_PAUZE
	Bus.toast_requested.emit(WEEKEND_DUW[_weekend_i % WEEKEND_DUW.size()], &"weekend")
	_weekend_i += 1


func _tint_zone(mood: String) -> void:
	if licht == null:
		return
	var doel: Color = LICHT.get(mood, Color.WHITE)
	# Kill-before-recreate: langs een deuropening lopen hertriggert dit op elke
	# tile-overgang, en stapelende tweens vechten om dezelfde kleur.
	if _licht_tween != null and _licht_tween.is_running():
		_licht_tween.kill()
	_licht_tween = create_tween()
	_licht_tween.tween_property(licht, "color", doel, 0.4)


func _on_ticket_completed(id: StringName, _r: MinigameResult) -> void:
	npc_layer.refresh_conditional()
	# Alleen de collega van dít ticket gaat terug naar zijn post. _handle_inner
	# heeft hem meestal al losgelaten; dit is het vangnet. Iemand die je voor
	# een ánder ticket hebt opgehaald blijft lopen — hem stilletjes naar huis
	# sturen was de straf voor vooruitdenken.
	var helper := QuestEngine.required_helper(id)
	if helper != &"":
		var n := npc_layer.find_npc(helper)
		if n != null and n.is_following():
			n.stop_following(true)


## Tien van de tien: de deur klikt open en de dag zit erop.
func _verlaat_kantoor() -> void:
	Session.lock_input()
	AudioDirector.play_sfx(&"deur")
	Bus.toast_requested.emit("KLIK", &"deur")
	await get_tree().create_timer(1.2).timeout
	Bus.game_finished.emit(true)
	Shell.goto_ending()


func _process(delta: float) -> void:
	if _weekend_t > 0.0:
		_weekend_t = maxf(0.0, _weekend_t - delta)
