class_name Besturing
extends CanvasLayer
## Hoe je dit spel bestuurt: een knoppenbalk onderaan, en een joystick die
## opkomt waar je duim landt.
##
## **Eén besturing, op elk apparaat.** Dit heette hiervoor `TouchControls` en
## bestond alleen op een telefoon; de desktop kreeg in plaats daarvan een
## tekstkaart met toetsnamen, en de HUD, het ticketbord, de dialoogbox en elke
## minigame hadden allemaal hun eigen `if Invoer.touch()`. Dat waren twee
## spellen met dezelfde inhoud, en van die twee werd de mobiele helft nooit
## gespeeld maar alleen bekeken — alle QA-shots stonden op `--touch` terwijl er
## met een toetsenbord getest werd. Nu is de balk er altijd en zijn toetsen
## sneltoetsen: WASD, E, Tab en Q doen precies wat de stick, de knoppen en een
## tik op een interactable doen.
##
## **Geen actieknop meer.** Die volgde alleen passief welk object het
## dichtstbij was en bleef, leeg en uitgegrijsd, altijd ruimte in de balk
## innemen. Tikken op het object zelf is directer én scheelt de plek: zie
## `_probeer_tik()`.
##
## Deze laag maakt geen eigen invoerbegrip. Hij drukt de bestaande acties in
## (`move_*`, `sprint`, `interact`, `ticketboard`, `hint`), zodat player.gd en
## main.gd niets van de balk hoeven te weten en de headless tests op de
## toetsenbordroute blijven werken.

## Een vaste stick zou op 192 px breed een kwart van het kantoor afdekken en
## dwingt je duim naar één plek. Deze verschijnt onder je duim en verdwijnt
## weer, dus hij kost alleen ruimte terwijl je loopt.
const STRAAL := 20.0        ## uitslag van de stick in canvaspixels
const KNOP_STRAAL := 6.0
const SPRINT_DREMPEL := 0.82  ## verder uitduwen dan dit is rennen

const MARGE := 4

## De drie hulpknoppen dragen een glyph en hoeven niet mee te groeien; de balk
## krimpt tot precies hun breedte plus de tussenruimte — er is geen actieknop
## meer die de rest opeist.
const HULP_BREEDTE := 26

## Wat een knop hier werkelijk hoog is.
##
## Twee getallen strijden hier: `UiKit.KNOP_MIN_H` is de duimondergrens, en een
## Button meldt daarnaast zijn eigen regelhoogte plus de marges van zijn stijl.
## De hoogste wint.
##
## Stond op 26, en dat was de gemeten kant die won: FS_BODY was 10, dus
## 14 + 2 x 6 = 26 tegen een ondergrens van 24. Sinds FS_BODY 12 is en
## KNOP_MIN_H 30, wint de ondergrens — precies zoals bedoeld, want een
## duimmaat die altijd verliest stuurt niets aan.
##
## Gemeten in een echt frame en niet uit de bron gerekend: de eerste versie
## hiervan rekende met 24, waardoor de balk twee pixels van zijn ondermarge
## opat en de HUD twee pixels te laag hing. `_test_balkmaat()` in de testsuite
## controleert dit getal, zodat een ander font of een andere stijlmarge het
## breekt in plaats van het stil te verschuiven.
const KNOP_HOOGTE := 30

## De balk is precies één knop hoog plus de krappe panelmarge (2 px boven en
## onder).
const BALK_HOOGTE := KNOP_HOOGTE + 4

## Hoeveel ruimte de balk onderaan het scherm inneemt, inclusief zijn marge en
## twee pixels lucht. De HUD hangt zijn onderste regels hierboven; dat is de
## enige lezer buiten deze klasse.
const BALK_RUIMTE := MARGE + BALK_HOOGTE + 2

## De stick mag alleen in de linkerhelft van de onderste tweederde opkomen.
## Daarboven zit de doelregel en de ticketteller: daar wil je kunnen tikken
## zonder dat er een stick onder je duim ontstaat. De balk zelf is apart
## uitgesloten — zie `_in_zone()`.
const ZONE_BREEDTE := 0.5
const ZONE_TOP := 0.38

## Voorbij dit punt (canvaspixels) is een druk-en-loslaat een sleep, geen tik.
## Ook wat de joystick zelf mag uitwijken voordat loslaten niet meer als tik
## telt — zie `_input()`.
const TIK_DREMPEL := 8.0

## Hoe dicht een tik bij de schermprojectie van het huidige interactable moet
## vallen om te gelden. Dezelfde, al gevalideerde duimmaat als de knoppen —
## zie `KNOP_HOOGTE` hierboven voor waar dat getal vandaan komt.
const TIK_STRAAL := UiKit.KNOP_MIN_H

var _stick: Control
var _balk: PanelContainer
var _vinger: int = -1
var _midden: Vector2 = Vector2.ZERO
var _uitslag: Vector2 = Vector2.ZERO
var _ingedrukt: Array[StringName] = []

## Vingerindex van een kandidaat-tik, los van de joystick-vinger. Blijft -99
## zolang er geen kandidaat is; een echte vingerindex is nooit negatief.
var _tik_index: int = -99
var _tik_start: Vector2 = Vector2.ZERO

## Voor `_probeer_tik()`: main.gd zet dit ná het spawnen van de speler, want
## `setup()` hieronder draait daarvóór.
var _speler: Player = null


func setup() -> void:
	# Onder de HUD (laag 10): het ticketbord is een schermvullende overlay en
	# moet de besturing afdekken in plaats van andersom.
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

	_bouw_balk(UiKit.veilige_laag(root))

	Bus.input_lock_changed.connect(_on_input_lock)


## Main.gd roept dit aan ná het spawnen van de speler — die bestaat nog niet
## als `setup()` hierboven draait.
func set_speler(p: Player) -> void:
	_speler = p


# --- De balk --------------------------------------------------------------

## Eén paneel dat om zijn drie knoppen sluit, tegen de linkerkant. Stond
## eerder over de volle breedte omdat de actieknop de rest opeiste; zonder
## die knop is een balk die toch de volle breedte blijft claimen alleen nog
## een lege plak achtergrond — dode ruimte in plaats van chrome.
func _bouw_balk(ouder: Control) -> void:
	_balk = PanelContainer.new()
	_balk.add_theme_stylebox_override("panel",
		UiKit.panel_krap(UiKit.PANEL_DARK, UiKit.INK))
	_balk.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_balk.offset_left = MARGE
	_balk.offset_bottom = -MARGE
	# Als de inhoud ooit toch meer nodig heeft, groeit hij omhoog de wereld in.
	# Standaard groeit een Control naar END, en dat is hier de onderrand van het
	# scherm — precies de kant waar niets meer is.
	_balk.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ouder.add_child(_balk)

	var rij := HBoxContainer.new()
	rij.add_theme_constant_override("separation", 2)
	_balk.add_child(rij)

	_knop(rij, "▤", &"ticketboard", HULP_BREEDTE)
	_knop(rij, "?", &"hint", HULP_BREEDTE)
	# Pauze. Op een telefoon bestaat ESC niet, en het pauzemenu is de enige plek
	# waar je het volume kunt zetten en de run kunt verlaten — dat mag geen
	# functie zijn die alleen met een toetsenbord bereikbaar is. Sluiten gebeurt
	# in het menu zelf: dan staat deze balk op pauze.
	_knop(rij, "≡", &"cancel", HULP_BREEDTE)

	# Horizontaal anchor_left == anchor_right (BOTTOM_LEFT), dus de breedte komt
	# uitsluitend uit deze size-toewijzing; get_combined_minimum_size() is een
	# zuivere optelling over de zojuist toegevoegde knoppen, geen deferred
	# layout-pas nodig.
	_balk.size = _balk.get_combined_minimum_size()


func _knop(rij: HBoxContainer, tekst: String, actie: StringName, breedte: int) -> Button:
	var b := UiKit.button(tekst, UiKit.FS_BODY)
	b.custom_minimum_size = Vector2(breedte, UiKit.KNOP_MIN_H)
	b.focus_mode = Control.FOCUS_NONE  # geen focusrand op een aanraakscherm
	# button_down/-up in plaats van pressed: main.gd luistert op de neergaande
	# flank, en de actie moet daarna weer los zodat is_action_pressed klopt.
	b.button_down.connect(func() -> void: _actie(actie, true))
	b.button_up.connect(func() -> void: _actie(actie, false))
	rij.add_child(b)
	return b


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


# --- Joystick + tikken ------------------------------------------------------

## De muis mag de joystick aandrijven zolang er geen aanraakscherm is; de
## afweging daarachter staat bij `Invoer.muis_als_vinger()`. Een eigen index,
## want een echte vingerindex is nooit negatief.
const MUIS_INDEX := -2


func _input(event: InputEvent) -> void:
	if Session.input_locked or Shell.minigame_active():
		_los()
		_tik_index = -99
		return

	# Beide soorten gebeurtenissen naar dezelfde drie waarden brengen, zodat de
	# joysticklogica er maar één keer staat.
	var index := -99
	var positie := Vector2.ZERO
	var neer := false
	var sleep := false

	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		index = t.index
		positie = t.position
		neer = t.pressed
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		index = d.index
		positie = d.position
		sleep = true
	elif Invoer.muis_als_vinger() and event is InputEventMouseButton \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var m := event as InputEventMouseButton
		index = MUIS_INDEX
		positie = m.position
		neer = m.pressed
	elif Invoer.muis_als_vinger() and event is InputEventMouseMotion and _vinger == MUIS_INDEX:
		index = MUIS_INDEX
		positie = (event as InputEventMouseMotion).position
		sleep = true
	else:
		return

	if sleep:
		if index == _vinger:
			_uitslag = (positie - _midden).limit_length(STRAAL)
			_stuur(_uitslag / STRAAL)
			_stick.queue_redraw()
		elif index == _tik_index and positie.distance_to(_tik_start) > TIK_DREMPEL:
			# Te ver gesleept om nog een tik te zijn — gewoon een vinger die
			# over lege wereld beweegt.
			_tik_index = -99
	elif neer:
		if _vinger == -1 and _in_zone(positie):
			_vinger = index
			_midden = positie
			_stuur(Vector2.ZERO)
			_stick.visible = true
			_stick.queue_redraw()
		elif _tik_index == -99 and not _op_balk(positie):
			_tik_index = index
			_tik_start = positie
	elif index == _vinger:
		# Nauwelijks uitgeweken: dit was eerder een tik dan een sleepgebaar,
		# ook al viel de neergaande druk toevallig in de joystickzone. Zo hoeft
		# een object daar niet apart behandeld te worden.
		var was_tik := _uitslag.length() <= TIK_DREMPEL
		_los()
		if was_tik:
			_probeer_tik(positie)
	elif index == _tik_index:
		_tik_index = -99
		_probeer_tik(positie)


## Bevestigt een tik: proximity (`InteractionProbe`) blijft de enige bron van
## waarheid voor óf een interactie kan, dit doet geen eigen raycast of
## Area2D-picking. De tik moet alleen ergens op de schermprojectie van het al
## toegestane interactable vallen. Buiten beeld of achter UI werkt vanzelf:
## de projectie valt dan simpelweg buiten TIK_STRAAL.
func _probeer_tik(scherm_positie: Vector2) -> void:
	if _speler == null:
		return
	var it := _speler.probe.current()
	if it == null:
		return
	var vp := get_viewport()
	if vp == null:
		return
	var canvas_pos: Vector2 = vp.get_canvas_transform() * it.global_position
	if canvas_pos.distance_to(scherm_positie) > TIK_STRAAL:
		return
	_actie(&"interact", true)
	_actie(&"interact", false)


## `_input` loopt vóór de GUI-verwerking, dus een tik op ▤ komt hier ook langs.
## Zonder deze uitzondering zou het ticketbord openen én een stick achterlaten
## in de linkerhoek van de balk. De balk uitrekenen in plaats van een marge
## raden: dan blijft dit kloppen als de balk van hoogte verandert.
func _op_balk(p: Vector2) -> bool:
	return _balk != null and _balk.get_global_rect().has_point(p)


func _in_zone(p: Vector2) -> bool:
	if _op_balk(p):
		return false
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


## Tijdens een dialoog gaat de balk helemaal weg in plaats van eronder te
## blijven staan. De dialoogbox (laag 20) dekt hem grotendeels af en er bleef
## een strookje knop onder de onderrand uitkijken; en er is dan ook niets te
## besturen — de enige actie is verder tikken.
func _on_input_lock(locked: bool) -> void:
	if locked:
		_los()
	if _balk != null:
		_balk.visible = not locked


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
