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


## `--rommelig`: speel zoals een mens speelt. Elke minigame gaat de eerste keer
## mis, en op de vraag die daarna komt kiest de autopilot "Goed genoeg.
## Shippen." in plaats van te herkansen.
##
## Waarom die vlag bestaat: zonder hem kwam `TicketController._ship_gebrekkig()`
## in geen enkele geautomatiseerde speelbeurt voor. De autopilot drukt altijd de
## knop met focus, en `DialogueBox.show_choices()` geeft die aan de eerste — dus
## het harnas herkanste tien van de tien keer en shipte nooit iets gebrekkigs.
## Precies achter dat pad zat de vastloper van playtest 2026-09-06 #38: twee
## boekingen vlak achter elkaar (het kwartier voor de misser, daarna de
## ticketuren) met `Hud.toon_urenrol()` ertussen. Alle zeven personages haalden
## 10/10 en niemand kon het zien.
static func rommelig() -> bool:
	return gevraagd() and "--rommelig" in OS.get_cmdline_user_args()


## De oplevering is de shipknop zelf: een mislukte deploy is een rollback en
## geen half werk dat je alsnog live zet, dus `_wil_gebrekkig_shippen()` biedt
## daar geen keuze aan. Hem hier laten mislukken levert dan een ticket op dat
## op ACTIVE blijft staan en nooit meer aangeraakt wordt — een vastgelopen
## speelbeurt op een pad dat het spel niet kent.
const NIET_LATEN_MISLUKKEN := &"mg_deploy"

## De tweede knop op de vraag na een misser. Op de tekst en niet op de index:
## de autopilot mag niet blind de laatste knop drukken, want dan kiest hij ook
## "Stoppen" op een keuze die hier niets mee te maken heeft.
const SHIP_KNOP := "Goed genoeg. Shippen."

var _al_gefaald: Dictionary = {}


## F5-a-verificatie: dit stond al op ALWAYS om door te tikken tijdens de oude
## wereldpauze van een minigame. Nu de wereld tijdens een minigame doorloopt
## (`Shell.run_minigame()` gebruikt `Session.lock_input()`, niet meer
## `get_tree().paused`), draaien de wereld-`_process()`s (spelerbeweging,
## `Klok`, NPC's) voortaan óók tijdens een minigame — maar dat verandert niets
## aan hoe vaak DEZE node tikt: `_process()` hieronder werd al elke frame
## aangeroepen, gepauzeerd of niet (dat is precies wat ALWAYS betekent), en telt
## zelf zijn interval af (`_t -= delta`) onafhankelijk van wat er verder in de
## boom gebeurt. Eén tik per `INTERVAL`, ongewijzigd — geen dubbele aansturing.
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
		# Eén keer per mechaniek, niet elke keer: na het shippen moet de
		# speelbeurt door, en een minigame die altijd faalt komt nooit voorbij
		# een ticket dat je niet gebrekkig mag opleveren.
		if rommelig() and mg.minigame_id != NIET_LATEN_MISLUKKEN \
				and not _al_gefaald.has(mg.minigame_id):
			_al_gefaald[mg.minigame_id] = true
			mg.fail(0, {"qa": true, "rommelig": true})
			return
		if mg.has_method(&"qa_solve"):
			mg.call(&"qa_solve")
		return

	# Staat er een keuze open, dan kiest de autopilot de bovenste. Een
	# InputEventAction voor "interact" is geen "ui_accept", dus een knop met
	# focus reageert daar niet op en zou de speelbeurt laten hangen.
	var knop := get_viewport().gui_get_focus_owner() as Button
	if knop != null and knop.is_visible_in_tree():
		if rommelig():
			var ship := _broertje_met_tekst(knop, SHIP_KNOP)
			if ship != null:
				ship.pressed.emit()
				return
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


## De knop met deze tekst naast `bij`. De keuzeknoppen van `DialogueBox` staan
## als broertjes onder één container en alleen de eerste heeft focus, dus dit is
## de hele zoektocht.
static func _broertje_met_tekst(bij: Button, tekst: String) -> Button:
	var ouder := bij.get_parent()
	if ouder == null:
		return null
	for kind: Node in ouder.get_children():
		var b := kind as Button
		if b != null and b.is_visible_in_tree() and b.text == tekst:
			return b
	return null
