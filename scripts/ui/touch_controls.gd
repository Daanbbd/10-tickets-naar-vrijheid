class_name TouchControls
extends CanvasLayer
## Duimbesturing voor de wereldscene: een joystick die verschijnt waar je hem
## neerzet, een actieknop die het werkwoord draagt van waar je voor staat, en
## twee hulpknoppen voor het ticketbord en de hint.
##
## Deze laag maakt geen eigen invoerbegrip. Hij drukt de bestaande acties in
## (`move_*`, `sprint`, `interact`, `ticketboard`, `hint`), zodat player.gd en
## main.gd niets van touch hoeven te weten en de toetsenbordroute intact blijft
## voor de headless tests en de desktopbuild.

## Een vaste stick zou op 192 px breed een kwart van het kantoor afdekken en
## dwingt je duim naar één plek. Deze verschijnt onder je duim en verdwijnt
## weer, dus hij kost alleen ruimte terwijl je loopt.
const STRAAL := 20.0        ## uitslag van de stick in canvaspixels
const KNOP_STRAAL := 6.0
const SPRINT_DREMPEL := 0.82  ## verder uitduwen dan dit is rennen

## Android vraagt 48 dp. Op een 1080-brede telefoon schaalt dit canvas 5x, dus
## één logische px is ~0,34 mm en 48 dp (~9 mm) is 26 px. Zie de rekensom in
## agent_docs/.handoffs/2026-09-01-2035-character-select/HANDOFF.md.
const KNOP_GROOT := 34
const KNOP_KLEIN := 26
const MARGE := 4

## De stick mag alleen in de linkerhelft van de onderste tweederde opkomen.
## Daarboven zit de doelregel en de ticketteller: daar wil je kunnen tikken
## zonder dat er een stick onder je duim ontstaat.
const ZONE_BREEDTE := 0.5
const ZONE_TOP := 0.38

var _stick: Control
var _knoppen: Control
var _actieknop: Button = null
var _vinger: int = -1
var _midden: Vector2 = Vector2.ZERO
var _uitslag: Vector2 = Vector2.ZERO
var _ingedrukt: Array[StringName] = []


func setup() -> void:
	# Onder de HUD (laag 10): het ticketbord is een schermvullende overlay en
	# moet de duimbesturing afdekken in plaats van andersom.
	layer = 9
	process_mode = Node.PROCESS_MODE_PAUSABLE

	var root := UiKit.full_rect(Control.new())
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_stick = UiKit.full_rect(Control.new())
	_stick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stick.visible = false
	_stick.draw.connect(_teken_stick)
	root.add_child(_stick)

	_knoppen = UiKit.veilige_laag(root)
	_bouw_knoppen()

	Bus.input_lock_changed.connect(_on_input_lock)
	Bus.interaction_prompt_changed.connect(_on_prompt)


# --- Knoppen --------------------------------------------------------------

func _bouw_knoppen() -> void:
	# De actieknop draagt het werkwoord van waar je voor staat — "Openen",
	# "Praten" — in plaats van een toetsnaam. Een knop die "E" heet verwijst
	# naar een toetsenbord dat er niet is; een knop die "Openen" heet vertelt
	# je wat er gebeurt als je hem indrukt, en maakt de losse prompt half
	# overbodig. Hij groeit mee met het woord en verdwijnt als er niets is.
	_actieknop = _knop("", KNOP_GROOT, &"interact",
		Vector2(-MARGE, -MARGE - KNOP_GROOT), Vector2(-MARGE, -MARGE))
	_actieknop.visible = false

	# Twee hulpknoppen op een rij erboven, buiten de plek waar de actieknop
	# breed kan worden.
	var y := -MARGE - KNOP_GROOT - 4
	_knop("▤", KNOP_KLEIN, &"ticketboard",
		Vector2(-MARGE - KNOP_KLEIN, y - KNOP_KLEIN), Vector2(-MARGE, y))
	_knop("?", KNOP_KLEIN, &"hint",
		Vector2(-MARGE - KNOP_KLEIN * 2 - 4, y - KNOP_KLEIN),
		Vector2(-MARGE - KNOP_KLEIN - 4, y))


func _knop(tekst: String, maat: int, actie: StringName,
		links_boven: Vector2, rechts_onder: Vector2) -> Button:
	var b := UiKit.button(tekst, UiKit.FS_BODY)
	b.custom_minimum_size = Vector2(maat, maat)
	b.focus_mode = Control.FOCUS_NONE  # geen focusrand op een aanraakscherm
	b.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	b.offset_left = links_boven.x
	b.offset_top = links_boven.y
	b.offset_right = rechts_onder.x
	b.offset_bottom = rechts_onder.y
	# De knop mag naar links uitgroeien voor een lang werkwoord als
	# "Onderzoeken", maar blijft rechtsonder verankerd.
	b.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	b.modulate.a = 0.82  # je moet het kantoor eronder blijven zien
	# button_down/-up in plaats van pressed: main.gd luistert op de neergaande
	# flank, en de actie moet daarna weer los zodat is_action_pressed klopt.
	b.button_down.connect(func() -> void: _actie(actie, true))
	b.button_up.connect(func() -> void: _actie(actie, false))
	_knoppen.add_child(b)
	return b


## De actieknop volgt exact dezelfde melding als de prompt in de HUD, zodat er
## nooit een knop staat voor iets wat niet in bereik is.
func _on_prompt(_text: String, shown: bool, _world_id: StringName, verb: String) -> void:
	if _actieknop == null:
		return
	_actieknop.visible = shown and not Session.input_locked
	_actieknop.text = verb


## Een echte InputEventAction, geen Input.action_press: main.gd leest deze
## acties in _unhandled_input, en dat ziet alleen gebeurtenissen die door de
## invoerpijplijn komen.
func _actie(actie: StringName, ingedrukt: bool) -> void:
	if ingedrukt:
		Haptiek.tril(Haptiek.Sterkte.TIK)
	var ev := InputEventAction.new()
	ev.action = actie
	ev.pressed = ingedrukt
	Input.parse_input_event(ev)


# --- Joystick -------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if Session.input_locked or Shell.minigame_active():
		_los()
		return

	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			if _vinger == -1 and _in_zone(t.position):
				_vinger = t.index
				_midden = t.position
				_stuur(Vector2.ZERO)
				_stick.visible = true
				_stick.queue_redraw()
		elif t.index == _vinger:
			_los()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _vinger:
			_uitslag = (d.position - _midden).limit_length(STRAAL)
			_stuur(_uitslag / STRAAL)
			_stick.queue_redraw()


func _in_zone(p: Vector2) -> bool:
	var r := _stick.get_viewport_rect().size
	return p.x < r.x * ZONE_BREEDTE and p.y > r.y * ZONE_TOP


func _los() -> void:
	if _vinger == -1:
		return
	_vinger = -1
	_uitslag = Vector2.ZERO
	_stick.visible = false
	_stuur(Vector2.ZERO)


## De stick vertaalt naar dezelfde vier acties als WASD, met kracht, zodat
## Input.get_vector in player.gd analoog blijft werken.
func _stuur(richting: Vector2) -> void:
	_zet(&"move_left", maxf(-richting.x, 0.0))
	_zet(&"move_right", maxf(richting.x, 0.0))
	_zet(&"move_up", maxf(-richting.y, 0.0))
	_zet(&"move_down", maxf(richting.y, 0.0))
	# Rennen is geen aparte knop: ver uitduwen is rennen. Dat scheelt een
	# knop in de duimzone en het is het gebaar dat mensen toch al maken.
	_zet(&"sprint", 1.0 if richting.length() > SPRINT_DREMPEL else 0.0)


func _zet(actie: StringName, kracht: float) -> void:
	if kracht > 0.0:
		Input.action_press(actie, kracht)
		if not actie in _ingedrukt:
			_ingedrukt.append(actie)
	elif actie in _ingedrukt:
		Input.action_release(actie)
		_ingedrukt.erase(actie)


func _on_input_lock(locked: bool) -> void:
	if locked:
		_los()


## Bij een scenewissel of afsluiten mogen er geen acties blijven hangen: die
## overleven deze node en laten de speler in het volgende scherm doorlopen.
func _exit_tree() -> void:
	for actie: StringName in _ingedrukt.duplicate():
		Input.action_release(actie)
	_ingedrukt.clear()


# --- Tekenen --------------------------------------------------------------

## Met de hand getekend in plaats van sprites: op deze schaal is de stick vier
## vormen, en zo hoeft er geen atlas voor mee de build in.
func _teken_stick() -> void:
	var kleur := Color(UiKit.WIT, 0.55)
	_stick.draw_arc(_midden, STRAAL, 0.0, TAU, 24, Color(UiKit.INK, 0.5), 3.0)
	_stick.draw_arc(_midden, STRAAL, 0.0, TAU, 24, kleur, 1.0)
	var knop := _midden + _uitslag
	_stick.draw_circle(knop, KNOP_STRAAL + 1.0, Color(UiKit.INK, 0.5))
	_stick.draw_circle(knop, KNOP_STRAAL,
		UiKit.BLUEBIRD_BRIGHT if _uitslag.length() > STRAAL * SPRINT_DREMPEL else kleur)
