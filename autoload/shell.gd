extends Node
## Scene-router, fade-transities en host van de minigame-overlay.
## De enige plek in het project die get_tree().paused aanraakt.

const SCENE_TITLE := "res://scenes/boot/title.tscn"
const SCENE_SELECT := "res://scenes/boot/character_select.tscn"
const SCENE_GAME := "res://scenes/world/main.tscn"
const SCENE_END := "res://scenes/boot/ending.tscn"

const FADE_TIME := 0.35

@onready var _minigame_layer: CanvasLayer = $MinigameLayer
@onready var _fade: ColorRect = $TransitionLayer/Fade
@onready var _debug_layer: CanvasLayer = $DebugLayer

var _active: MinigameBase = null
var _busy: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade.color.a = 0.0
	_fade.visible = false
	_qa_shot()


# --- App-lifecycle --------------------------------------------------------

## Wie de pauze bezit, bezit ook het naar de achtergrond gaan. Zou een losse
## autoload dit doen, dan zou die bij het terugkomen `paused = false` zetten en
## daarmee een lopende minigame ontpauzeren. Vandaar dat het hier staat en dat
## de vorige stand bewaard wordt in plaats van hersteld naar false.
var _pauze_voor_achtergrond: bool = false
var _in_achtergrond: bool = false


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			_naar_achtergrond()
		NOTIFICATION_APPLICATION_RESUMED:
			_naar_voorgrond()
		NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			# Op de desktop is focusverlies geen achtergrond: daar zou dit de
			# QA-shots en het spelen naast een editor stukmaken.
			if OS.has_feature("mobile"):
				_naar_achtergrond()
		NOTIFICATION_WM_WINDOW_FOCUS_IN:
			if OS.has_feature("mobile"):
				_naar_voorgrond()


func _naar_achtergrond() -> void:
	if _in_achtergrond:
		return
	_in_achtergrond = true

	# Eerst opslaan, dan pas pauzeren: Android mag dit proces hierna zonder
	# waarschuwing killen. `WM_CLOSE_REQUEST` komt daar niet, dus dit is het
	# enige moment waarop de sessie nog veilig weggeschreven kan worden.
	# Alleen als er een speelbeurt loopt: wegdrukken op het titelscherm zou
	# anders een lege sessie over een bestaande save heen schrijven.
	if Session.character_id != &"":
		Session.save_to_disk()

	_pauze_voor_achtergrond = get_tree().paused
	get_tree().paused = true
	Engine.max_fps = 1
	AudioServer.set_bus_mute(0, true)


func _naar_voorgrond() -> void:
	if not _in_achtergrond:
		return
	_in_achtergrond = false
	get_tree().paused = _pauze_voor_achtergrond
	Engine.max_fps = 0
	AudioServer.set_bus_mute(0, false)


## QA: `-- --shot=/pad/uit.png [--shot-na=3.0]` schrijft een frame weg en stopt.
## Zit hier en niet in de wereldscene, zodat ook het titelscherm, de
## personagekeuze en het eindscherm te controleren zijn.
func _qa_shot() -> void:
	var pad := ""
	var na := 2.5
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			pad = a.trim_prefix("--shot=")
		elif a.begins_with("--shot-na="):
			na = float(a.trim_prefix("--shot-na="))
	if pad == "":
		return
	# process_always: tijdens een minigame staat de tree op pause en zou een
	# gewone timer nooit aflopen.
	await get_tree().create_timer(na, true, false, true).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img.save_png(pad) == OK:
		print("[SHOT] %s (%dx%d)" % [pad, img.get_width(), img.get_height()])
	else:
		printerr("[SHOT] kon %s niet schrijven" % pad)
	get_tree().quit()


# --- Routing --------------------------------------------------------------

func goto_title() -> void:
	await _change_scene(SCENE_TITLE)

func goto_character_select() -> void:
	await _change_scene(SCENE_SELECT)

func goto_game() -> void:
	await _change_scene(SCENE_GAME)

func goto_ending() -> void:
	await _change_scene(SCENE_END)


func _change_scene(path: String) -> void:
	if _busy:
		return
	_busy = true
	await fade_out()
	get_tree().paused = false
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("Shell: kon scene '%s' niet laden (%d)" % [path, err])
	await get_tree().process_frame
	await get_tree().process_frame
	await fade_in()
	_busy = false


# --- Fades ----------------------------------------------------------------

func fade_out(duration: float = FADE_TIME) -> void:
	_fade.visible = true
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, duration)
	await tw.finished


func fade_in(duration: float = FADE_TIME) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, duration)
	await tw.finished
	_fade.visible = false


## Zwart scherm met tekst, voor de eindsequentie.
func hold_black(seconds: float) -> void:
	await get_tree().create_timer(seconds, true).timeout


# --- Minigames ------------------------------------------------------------

## Draait een minigame als overlay en geeft het resultaat terug.
## De wereld wordt gepauzeerd; de minigame-root draait op PROCESS_MODE_ALWAYS.
func run_minigame(minigame_id: StringName, config: Dictionary) -> MinigameResult:
	if _active != null:
		push_error("Shell: minigame '%s' gevraagd terwijl '%s' actief is" % [minigame_id, _active.minigame_id])
		return MinigameResult.aborted(minigame_id)

	var path := GameData.minigame_scene_path(minigame_id)
	if path == "" or not ResourceLoader.exists(path):
		push_error("Shell: geen scene voor minigame '%s' (pad '%s')" % [minigame_id, path])
		return MinigameResult.aborted(minigame_id)

	var packed: PackedScene = load(path)
	var mg := packed.instantiate() as MinigameBase
	if mg == null:
		push_error("Shell: scene '%s' erft niet van MinigameBase" % path)
		return MinigameResult.aborted(minigame_id)

	_active = mg
	mg.minigame_id = minigame_id
	mg.process_mode = Node.PROCESS_MODE_ALWAYS
	_minigame_layer.add_child(mg)

	get_tree().paused = true
	Bus.minigame_started.emit(minigame_id)

	# Slik de toetsaanslag waarmee de minigame gestart werd, anders vangt de
	# eerste ronde hem meteen op.
	await get_tree().process_frame
	mg.setup(config)

	var result: MinigameResult = await mg.finished

	_active = null
	mg.queue_free()
	await get_tree().process_frame
	get_tree().paused = false
	Bus.minigame_finished.emit(minigame_id, result)
	return result


func minigame_active() -> bool:
	return _active != null


# --- Debug ----------------------------------------------------------------

func debug_layer() -> CanvasLayer:
	return _debug_layer
