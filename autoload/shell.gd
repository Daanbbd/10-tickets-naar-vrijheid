extends Node
## Scene-router, fade-transities en host van de minigame-overlay.
## De enige plek in het project die get_tree().paused aanraakt.

const SCENE_TITLE := "res://scenes/boot/title.tscn"
const SCENE_INTRO_UITLEG := "res://scenes/boot/intro_uitleg.tscn"
const SCENE_SELECT := "res://scenes/boot/character_select.tscn"
const SCENE_BESTURING := "res://scenes/boot/besturing_uitleg.tscn"
const SCENE_GAME := "res://scenes/world/main.tscn"
const SCENE_END := "res://scenes/boot/ending.tscn"

const FADE_TIME := 0.35

@onready var _minigame_layer: CanvasLayer = $MinigameLayer
@onready var _fade: ColorRect = $TransitionLayer/Fade

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
## daarmee een openstaand pauzemenu ontpauzeren terwijl het er nog staat.
## Vandaar dat het hier staat en dat de vorige stand bewaard wordt in plaats
## van hersteld naar false.
##
## F5-a: een lopende minigame is sinds deze stap geen reden meer voor deze
## variabele om `true` te zijn — een minigame pauzeert de tree niet meer, dus
## backgrounden tijdens een normale minigame legt hier gewoon `false` vast
## (de tree stond immers niet gepauzeerd) en `_naar_voorgrond()` herstelt
## terecht naar `false`. De tree bevriest daarbij wél, onvoorwaardelijk, via
## regel 67 hieronder — dat is verificatiepunt F5-a-3: backgrounden bevriest
## altijd alles, ook een minigame, ongeacht wie de tree daarvóór al hield.
## `_active`/`Session._sloten` overleven het backgrounden ongemoeid (dit raakt
## alleen `get_tree().paused`), dus de minigame en zijn invoerslot staan er bij
## terugkomst nog precies zo bij als toen de app naar de achtergrond ging.
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
			#
			# Hier blijft het `OS.has_feature("mobile")` — dus native
			# Android/iOS — en wordt het NIET `Invoer.is_telefoon()`. Op een
			# app is focus-uit/-in een symmetrisch OS-signaal (Activity
			# pauzeert, Activity hervat). In een mobiele BROWSER is
			# window-focus veel wispelturiger: een permissiedialoog (zoals
			# de trilling die `Haptiek.tril()` nu ook op Web aanvraagt), het
			# toetsenbord, of simpelweg een tik op de adresbalk kan een
			# focus-uit sturen zonder de gegarandeerde focus-in erna. Zet je
			# dat hier ook aan, dan pauzeert de tree op een telefoon-browser
			# soms wél en komt er nooit meer een `_naar_voorgrond()` — precies
			# het "na het intro-gesprek reageert niets meer" dat dit
			# veroorzaakte. Echt naar de achtergrond gaan op mobiel web (de
			# tab verlaten) loopt toch al via `NOTIFICATION_APPLICATION_PAUSED`
			# hieronder, dat geen featurecheck heeft.
			if OS.has_feature("mobile"):
				_naar_achtergrond()
		NOTIFICATION_WM_WINDOW_FOCUS_IN:
			if OS.has_feature("mobile"):
				_naar_voorgrond()
		NOTIFICATION_WM_CLOSE_REQUEST:
			# Het kruisje op de desktop. Zonder dit gaat alles verloren sinds het
			# laatst opgeloste ticket: `QuestEngine.complete()` is de enige plek
			# die zelf opslaat, dus je vondsten, je gekozen ticket, de collega's
			# die je al had opgehaald (`helper_bij_*`), je gewerkte minuten en de
			# storingen die al gevuurd waren stonden nergens. `discover()` is de
			# enige mutatie van de collectielus zonder eigen save-pad, en juist
			# rondlopen en vinden is wat je tussen twee tickets doet.
			_bewaar_lopende_dag()


func _naar_achtergrond() -> void:
	if _in_achtergrond:
		return
	_in_achtergrond = true

	# Eerst opslaan, dan pas pauzeren: Android mag dit proces hierna zonder
	# waarschuwing killen. `WM_CLOSE_REQUEST` komt daar niet, dus dit is het
	# enige moment waarop de sessie nog veilig weggeschreven kan worden.
	_bewaar_lopende_dag()

	_pauze_voor_achtergrond = get_tree().paused
	get_tree().paused = true
	Engine.max_fps = 1
	AudioServer.set_bus_mute(0, true)


## Schrijft de lopende speelbeurt weg, als er één is.
##
## Alleen met een personage: wegdrukken of afsluiten op het titelscherm zou
## anders een lege sessie over een bestaande save heen schrijven, en dan biedt
## "Doorgaan" een dag aan zonder personage.
func _bewaar_lopende_dag() -> void:
	if Session.character_id != &"":
		Session.save_to_disk()


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
	# process_always: dit was nodig omdat de tree tijdens een minigame op pauze
	# stond (F5-a heft dat op: een gewone minigame gebruikt nu
	# `Session.lock_input()`, dus `--minigame=... --shot=...` zou een gewone
	# timer ook zonder deze vlag laten aflopen). De vlag blijft niettemin
	# staan: het pauzemenu en de achtergrondgang hieronder pauzeren de tree nog
	# wél, en zijn de enige twee plekken die dat na deze stap nog doen. Mocht
	# een toekomstige QA-vlag ooit een shot tijdens één van die twee vragen,
	# dan moet deze timer nog steeds aflopen — en zonder deze vlag zou hij dat
	# niet doen. Geen downside om hem te laten staan; wel een stille aanname
	# als hij verdwijnt.
	await get_tree().create_timer(na, true, false, true).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img.save_png(pad) == OK:
		print("[SHOT] %s (%dx%d)" % [pad, img.get_width(), img.get_height()])
	else:
		printerr("[SHOT] kon %s niet schrijven" % pad)
	get_tree().quit()


# --- Pauze ----------------------------------------------------------------

## Staat het pauzemenu open? Hier en niet in het menu zelf, want dit is dezelfde
## vraag als "wie bezit de pauze".
var _menu_pauze: bool = false


## Het pauzemenu vraagt hier of de wereld stil moet staan.
##
## Shell is de enige eigenaar van `get_tree().paused`, en dat is geen stijlregel:
## de achtergrondgang hierboven bewaart de vorige stand, en zou het menu zelf
## `paused = false` schrijven bij het sluiten, dan ontpauzeert het het
## achtergrondslot van een app die net terug in beeld komt.
##
## `_active != null` (een lopende minigame) hoort sinds F5-a niet meer in dit
## rijtje thuis op dezelfde grond als `_in_achtergrond`: een minigame houdt de
## tree niet meer zelf gepauzeerd, dus er valt voor déze functie niets meer te
## "overschrijven". De guard blijft niettemin staan, met een nieuwe reden: het
## pauzemenu (laag 40) hoort NOOIT boven een lopende minigame (laag 50) te
## verschijnen — dat is een bewuste keuze, zie `Pauzemenu`'s klassecommentaar
## — en `main.gd::_unhandled_input()` bewaakt dat al zelf door `cancel` niet
## naar `_pauzemenu.open()` door te laten zolang `Shell.minigame_active()` waar
## is. Deze regel opent dus in de praktijk nooit tijdens een minigame; hij
## blijft staan als achtervang voor elke aanroeper die `pauzeer_voor_menu()`
## ooit rechtstreeks aanroept zonder via dat invoerpad te gaan (bijvoorbeeld de
## testsuite). `_test_minigame_pauze()` bewaakt die achtervang.
func pauzeer_voor_menu(aan: bool) -> void:
	if _menu_pauze == aan:
		return
	_menu_pauze = aan
	if _active != null or _in_achtergrond:
		return
	get_tree().paused = aan


func menu_pauze_actief() -> bool:
	return _menu_pauze


# --- Routing --------------------------------------------------------------

func goto_title() -> void:
	await _change_scene(SCENE_TITLE)

func goto_intro_uitleg() -> void:
	await _change_scene(SCENE_INTRO_UITLEG)

func goto_character_select() -> void:
	await _change_scene(SCENE_SELECT)

## Het besturingsscherm zit tussen de personagekeuze en het spel. Alleen die
## route komt er langs: `--speler=` en "Doorgaan" gaan rechtstreeks naar
## `goto_game()`, en wie hervat weet al hoe hij loopt.
func goto_besturing() -> void:
	await _change_scene(SCENE_BESTURING)

func goto_game() -> void:
	await _change_scene(SCENE_GAME)

func goto_ending() -> void:
	await _change_scene(SCENE_END)


func _change_scene(path: String) -> void:
	if _busy:
		return
	_busy = true
	await fade_out()
	# Net als het invoerslot overleeft geen enkele pauze-eigenaar een scenewissel:
	# het pauzemenu dat hem zette bestaat straks niet meer.
	_menu_pauze = false
	get_tree().paused = false
	# Geen enkel invoerslot overleeft een scenewissel: de dialoog, de telefoon of
	# de vertrekscene die hem zette bestaat straks niet meer, dus niemand gooit
	# hem nog los. Zonder dit is de volgende scene onbestuurbaar.
	Session.reset_input_lock()
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
##
## F5-a: dit pauzeert de wereld niet meer. Hier stond `get_tree().paused =
## true/false`, en dat bevroor het hele kantoor zolang een minigame liep — geen
## storing kon landen, geen collega kon lopen, geen klok kon tikken. Nu grijpt
## dit alleen `Session.lock_input()`/`unlock_input()`: dezelfde getelde
## semafoor die de dialoogbox en de telefoon al gebruiken. `Besturing._input()`
## bailt daarnaast al expliciet op `Shell.minigame_active()`, dus de speler kan
## nog steeds niet lopen — alleen de wereld eromheen staat niet meer stil.
##
## Wat WEL blijft stilstaan: de dialoogbox. Lezen mag geen straf zijn, en
## `DialogueController` grijpt zijn eigen invoer al af via diezelfde
## `Session.lock_input()` — dat stond al los van `get_tree().paused` en hoeft
## door deze wijziging niet aan te passen. Een expliciete keuze, geen omissie.
##
## De minigame-root blijft op PROCESS_MODE_ALWAYS staan: dat was nodig om de
## oude wereldpauze te overleven en is nu nodig om door te blijven werken
## terwijl een pauzemenu- of achtergrondpauze — die WEL de tree pauzeren —
## actief is. Zie `pauzeer_voor_menu()` en `_naar_achtergrond()` hieronder.
func run_minigame(minigame_id: StringName, config: Dictionary) -> MinigameResult:
	if _active != null:
		push_error("Shell: minigame '%s' gevraagd terwijl '%s' actief is" % [minigame_id, _active.minigame_id])
		return MinigameResult.aborted(minigame_id)

	var path := GameData.minigame_scene_path(minigame_id)
	if path == "" or not ResourceLoader.exists(path):
		push_error("Shell: geen scene voor minigame '%s' (pad '%s')" % [minigame_id, path])
		return MinigameResult.aborted(minigame_id)

	# De eerste keer dat dit minigame-id in deze speelbeurt voorkomt: wat de
	# opgave is en waarom ze ertoe doet, los van de minigame zelf en los van
	# de briefing die de eigenaar er eventueel al over gaf. Vóór de instantiatie
	# van `mg`: bij "Terug" is er dan nooit een minigame-node om weer op te
	# ruimen. Eigen, volledig sequentiële lock/unlock-paar — `Session.lock_input()`
	# is een teller en componeert dus probleemloos met het paar hieronder.
	# `Bus.minigame_started` blijft na dit blok staan: dat hoort bij de echte
	# minigame, niet bij dit scherm.
	if MinigameIntro.moet_getoond(minigame_id):
		Session.lock_input()
		var poort := MinigameIntro.new()
		_minigame_layer.add_child(poort)
		poort.setup(minigame_id, config.get("inhoud", {}) as Dictionary)
		var doorgegaan: bool = await poort.besloten
		poort.queue_free()
		Session.unlock_input()
		if not doorgegaan:
			return MinigameResult.aborted(minigame_id)
		Session.set_flag(MinigameIntro.gezien_vlag(minigame_id), true)

	var packed: PackedScene = load(path)
	var mg := packed.instantiate() as MinigameBase
	if mg == null:
		push_error("Shell: scene '%s' erft niet van MinigameBase" % path)
		return MinigameResult.aborted(minigame_id)

	_active = mg
	mg.minigame_id = minigame_id
	mg.process_mode = Node.PROCESS_MODE_ALWAYS
	_minigame_layer.add_child(mg)

	Session.lock_input()
	Bus.minigame_started.emit(minigame_id)

	# Slik de toetsaanslag waarmee de minigame gestart werd, anders vangt de
	# eerste ronde hem meteen op.
	await get_tree().process_frame
	mg.setup(config)

	var result: MinigameResult = await mg.finished

	_active = null
	mg.queue_free()
	await get_tree().process_frame
	Session.unlock_input()
	Bus.minigame_finished.emit(minigame_id, result)
	return result


func minigame_active() -> bool:
	return _active != null


## De actieve minigame, of null als er geen loopt. Voor `Storingen` (F5-b): een
## storing die tijdens een minigame afgaat moet in dát scherm landen — de
## telefoon (laag 30) en de HUD-toast (laag 10) liggen allebei onder de
## minigame (laag 50) en zijn dus onzichtbaar zolang die openstaat.
func active_minigame() -> MinigameBase:
	return _active
