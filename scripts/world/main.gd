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

var builder: WorldBuilder = WorldBuilder.new()
var player: Player = null

var _zone_id: StringName = &""


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

	# De wereld is een pure functie van Session: speel alles opnieuw af.
	mutator.replay_all()

	_spawn_player()
	npc_layer.spawn_initial()
	camera.setup(player, builder.world_rect())

	Bus.ticket_completed.connect(_on_ticket_completed)
	Bus.ticket_state_changed.connect(func(_a: StringName, _b: GameEnums.TicketState) -> void: _refresh_marker())
	Bus.ticket_completed.connect(func(_a: StringName, _b: MinigameResult) -> void: _refresh_marker())
	Bus.follower_joined.connect(func(_a: StringName) -> void: _refresh_marker())
	Bus.follower_released.connect(func(_a: StringName) -> void: _refresh_marker())
	Bus.flag_changed.connect(func(_a: StringName, _b: bool) -> void: _refresh_marker())
	_refresh_marker()
	Bus.game_started.emit()
	AudioDirector.play_music(&"kantoor")
	_qa_bord()

	if Autopilot.gevraagd():
		add_child(Autopilot.new())
	if "--playthrough" in OS.get_cmdline_user_args():
		_qa_playthrough()
	else:
		_qa_auto()
		_intro_beat()




## Zet het wijzertje op het huidige doel: eerst de collega die nog opgehaald moet
## worden, daarna het object. Er leeft er altijd maximaal één.
func _refresh_marker() -> void:
	for m: Node in get_tree().get_nodes_in_group(&"objective_marker"):
		m.queue_free()

	var t: TicketDef = QuestEngine.next_hint_ticket()
	if t == null:
		_mark_object(&"voordeur")
		return

	if not QuestEngine.is_own_expertise(t.id) and not Session.get_flag(QuestEngine.helper_flag(t.id)):
		var helper := npc_layer.find_npc(QuestEngine.required_helper(t.id))
		if helper != null and not helper.is_following():
			_mark_node(helper)
			return
	_mark_object(t.anchor)


func _mark_object(world_id: StringName) -> void:
	var wo := registry.get_by_id(world_id)
	if wo != null:
		_mark_node(wo)


func _mark_node(n: Node2D) -> void:
	n.add_child(ObjectiveMarker.new())


## De eerste minuut: premisse, wincondititie, het werkwoord en het eerste doel.
## Zes nodes, niet meer: elke node is een E-druk en een lap Nederlands.
func _intro_beat() -> void:
	if Session.done_count() > 0:
		return
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--auto=") or a == "--autoplay" or a == "--playthrough":
			return

	await get_tree().create_timer(0.4).timeout
	if GameData.dialogue(&"intro") != null:
		await dialogue.play(&"intro")

	# Even laten zien waar het eerste ticket ligt: op deze vloer is de
	# vergaderruimte niet vanuit de entree te zien.
	var t: TicketDef = QuestEngine.next_hint_ticket()
	if t != null:
		Bus.camera_focus_requested.emit(t.anchor, 2.0)
		await get_tree().create_timer(2.4).timeout
	hud.show_controls_card()


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


## QA: loopt alle tien de tickets in volgorde af in de echte runtime, inclusief
## dialogen, minigames en wereldveranderingen. Bewijst dat de hele dag speelbaar
## is zonder dat iemand de toetsen aanraakt.
func _qa_playthrough() -> void:
	await get_tree().create_timer(0.5).timeout
	var start := Time.get_ticks_msec()

	for tid: StringName in GameData.ticket_ids():
		var t: TicketDef = GameData.ticket(tid)
		if not await _qa_wacht_tot(func() -> bool: return Session.is_available(tid), 20.0):
			printerr("[SPEELBEURT] %s werd nooit beschikbaar" % t.code)
			break

		# de collega ophalen simuleren
		if not QuestEngine.is_own_expertise(tid):
			QuestEngine.mark_helper_present(tid)
		# benodigde items simuleren (de deploysleutel uit het magazijn)
		for item: Variant in (t.requirements.get("has_item", []) as Array):
			if not Session.has_item(StringName(item)):
				Session.add_item(StringName(item))

		var wo := registry.get_by_id(t.anchor)
		if wo == null:
			printerr("[SPEELBEURT] %s: anker '%s' ontbreekt" % [t.code, t.anchor])
			break
		player.global_position = builder.tile_to_world(
			builder.nearest_walkable(builder.world_to_tile(wo.global_position)))
		camera.global_position = player.global_position
		camera.reset_smoothing()
		await get_tree().create_timer(0.3).timeout

		var it := wo.get_node_or_null("Interactable") as Interactable
		_interact_with(it)

		if await _qa_wacht_tot(func() -> bool: return Session.is_done(tid), 90.0):
			print("[SPEELBEURT] %s opgelost  (%d/10)" % [t.code, Session.done_count()])
		else:
			printerr("[SPEELBEURT] %s liep vast" % t.code)
			break

	if Session.all_done():
		print("[SPEELBEURT] 10/10 — naar de voordeur")
		var deur := registry.get_by_id(&"voordeur")
		player.global_position = builder.tile_to_world(
			builder.nearest_walkable(builder.world_to_tile(deur.global_position)))
		await get_tree().create_timer(0.5).timeout
		_verlaat_kantoor()
	else:
		printerr("[SPEELBEURT] MISLUKT op %d/10" % Session.done_count())

	print("[SPEELBEURT] duur: %.1fs" % ((Time.get_ticks_msec() - start) / 1000.0))
	if "--quit-when-done" in OS.get_cmdline_user_args():
		await get_tree().create_timer(1.0).timeout
		get_tree().quit(0 if Session.all_done() else 1)


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
		# blok, op beloopbare vloer. Daarom centreren op de footprint in plaats
		# van uitlijnen op de linkerbovenhoek.
		var half := Vector2(builder.tile_size, builder.tile_size) * 0.5
		var lb := builder.tile_to_world(Vector2i(int(r[0]), int(r[1]))) - half
		var voetprint := Vector2(
			float(int(r[2]) - int(r[0]) + 1), float(int(r[3]) - int(r[1]) + 1)) * builder.tile_size
		s.position = lb + (voetprint - s.texture.get_size()) * 0.5
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


func _on_player_tile(t: Vector2i) -> void:
	var z := builder.zone_at(t)
	var zid := StringName(z.get("id", ""))
	if zid != _zone_id and zid != &"":
		_zone_id = zid
		_tint_zone(String(z.get("light", "neutraal")))
		Bus.zone_entered.emit(zid, String(z.get("name", "")))
	if zid == &"z10_weekend":
		_weekend_duwt_terug()


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


func _on_ticket_completed(_id: StringName, _r: MinigameResult) -> void:
	npc_layer.refresh_conditional()
	npc_layer.release_all()


## Tien van de tien: de deur klikt open en de dag zit erop.
func _verlaat_kantoor() -> void:
	Session.input_locked = true
	AudioDirector.play_sfx(&"deur")
	Bus.toast_requested.emit("KLIK", &"deur")
	await get_tree().create_timer(1.2).timeout
	Bus.game_finished.emit(true)
	Shell.goto_ending()


func _process(delta: float) -> void:
	if _weekend_t > 0.0:
		_weekend_t = maxf(0.0, _weekend_t - delta)
