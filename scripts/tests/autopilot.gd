class_name Autopilot
extends Node
## QA-hulpje: drukt vanzelf op de interactietoets zodat dialogen doorlopen en
## minigames zichzelf oplossen. Alleen actief met `-- --autoplay`.
##
## Hiermee kan de volledige lus dialoog -> minigame -> ticket klaar zonder
## menselijke handen worden nagelopen.

const INTERVAL := 0.45

var _t: float = 0.0
var _tikken: int = 0


static func gevraagd() -> bool:
	return "--autoplay" in OS.get_cmdline_user_args()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = INTERVAL
	_tikken += 1

	# minigames lossen zichzelf op via hun eigen debug-ingang
	var mg := _actieve_minigame()
	if mg != null:
		if mg.has_method(&"qa_solve"):
			mg.call(&"qa_solve")
		return

	# Staat er een keuze open, dan kiest de autopilot de bovenste. Een
	# InputEventAction voor "interact" is geen "ui_accept", dus een knop met
	# focus reageert daar niet op en zou de speelbeurt laten hangen.
	var knop := get_viewport().gui_get_focus_owner() as Button
	if knop != null and knop.is_visible_in_tree():
		knop.pressed.emit()
		return

	_druk("interact")


## Een echt InputEvent door de normale invoerketen sturen; Input.action_press()
## alleen is te vluchtig en mist de is_action_just_pressed-frame.
func _druk(actie: StringName) -> void:
	var ev := InputEventAction.new()
	ev.action = actie
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	await get_tree().process_frame
	var up := InputEventAction.new()
	up.action = actie
	up.pressed = false
	Input.parse_input_event(up)


## De laatst toegevoegde minigame is de actieve: de deployconsole opent een
## tweede minigame bovenop zichzelf.
func _actieve_minigame() -> MinigameBase:
	var lijst := get_tree().get_nodes_in_group(&"minigame")
	if lijst.is_empty():
		return null
	return lijst[lijst.size() - 1] as MinigameBase
