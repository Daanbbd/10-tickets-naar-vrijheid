class_name RushVeeg
extends Node
## Scrollen met een duim zoals een telefoon dat doet, voor een ScrollContainer.
##
## Godots eigen sleep-scrollen had twee dingen die op een telefoon niet goed
## voelen. Er zat geen vaart in: laat je los, dan staat de lijst meteen stil.
## En wie op een knop begon te slepen, nam die knop mee onder zijn vinger,
## zodat het loslaten alsnog als tik op die knop telde.
##
## Deze node neemt het slepen over: na een paar pixels beweging is het een
## veeg, de knop eronder wordt losgelaten buiten beeld (dus geen tik), de
## lijst volgt je vinger op de subpixel, en na het loslaten glijdt hij uit.

const DREMPEL := 5.0        ## canvaspixels voordat een aanraking een veeg is
const WRIJVING := 4.5       ## hoe snel het uitglijden afneemt (per seconde)
const MIN_VAART := 12.0     ## daaronder staat hij stil

var _scroll: ScrollContainer
var _ingedrukt := false
var _veegt := false
var _start := Vector2.ZERO
var _vorige := 0.0
var _positie := 0.0
var _vaart := 0.0
var _laatste_tijd := 0
## Waar zijn we zelf een gebeurtenis aan het insturen (zie `_laat_knop_los`).
var _nep := false


static func koppel(scroll: ScrollContainer) -> RushVeeg:
	var v := RushVeeg.new()
	v._scroll = scroll
	scroll.add_child(v)
	# Het eigen sleepgedrag uitzetten door het nooit te laten beginnen.
	scroll.scroll_deadzone = 100000
	return v


func _input(event: InputEvent) -> void:
	if _nep or not is_instance_valid(_scroll) or not _scroll.is_visible_in_tree():
		return
	# Aanraking komt ook als nagebootste muis binnen; die gebruiken we. De
	# echte touch-gebeurtenissen binnen de lijst slikken we, anders scrolt
	# ScrollContainer er zelf ook nog mee.
	if event is InputEventScreenDrag or event is InputEventScreenTouch:
		if _binnen((event as InputEventFromWindow).position) or _ingedrukt:
			if _veegt:
				get_viewport().set_input_as_handled()
		return

	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			if _binnen(mb.position):
				_ingedrukt = true
				_veegt = false
				_start = mb.position
				_vorige = mb.position.y
				_positie = float(_scroll.scroll_vertical)
				_vaart = 0.0
				_laatste_tijd = Time.get_ticks_msec()
		elif _ingedrukt:
			_ingedrukt = false
			if _veegt:
				get_viewport().set_input_as_handled()
				# Eerst stilgehouden en dan losgelaten: dan glijdt hij niet uit.
				if Time.get_ticks_msec() - _laatste_tijd > 90:
					_vaart = 0.0
			_veegt = false
		return

	var mm := event as InputEventMouseMotion
	if mm != null and _ingedrukt:
		var y := mm.position.y
		if not _veegt and absf(y - _start.y) * _schaal() > DREMPEL:
			_veegt = true
			_laat_knop_los()
		if _veegt:
			var nu := Time.get_ticks_msec()
			var dt := maxf(0.001, (nu - _laatste_tijd) / 1000.0)
			var dy := (y - _vorige) * _schaal()
			_positie -= dy
			_zet(_positie)
			# Vaart als glijdend gemiddelde, zodat één schokje niet telt.
			_vaart = lerpf(_vaart, -dy / dt, 0.4)
			_vorige = y
			_laatste_tijd = nu
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _ingedrukt or absf(_vaart) < MIN_VAART or not is_instance_valid(_scroll):
		if not _ingedrukt:
			_vaart = 0.0
		return
	_positie += _vaart * delta
	_vaart *= exp(-WRIJVING * delta)
	if not _zet(_positie):
		_vaart = 0.0


## Zet de scrollpositie; geeft false als hij tegen een rand liep.
func _zet(p: float) -> bool:
	var balk := _scroll.get_v_scroll_bar()
	var maxi_ := maxf(0.0, balk.max_value - balk.page)
	var geklemd := clampf(p, 0.0, maxi_)
	_positie = geklemd
	_scroll.scroll_vertical = roundi(geklemd)
	return is_equal_approx(geklemd, p)


## Wie op een knop begon, heeft die knop nu "vast". Een knop kijkt bij het
## loslaten niet waar je bent, maar of je bij de laatste beweging nog boven
## hem zat; en omdat de lijst met je vinger meeschuift, is dat zo. Dus eerst
## een beweging ver buiten beeld, dan het loslaten: geen tik.
func _laat_knop_los() -> void:
	var weg := Vector2(-10000, -10000)
	var beweeg := InputEventMouseMotion.new()
	beweeg.button_mask = MOUSE_BUTTON_MASK_LEFT
	beweeg.position = weg
	beweeg.global_position = weg
	var los := InputEventMouseButton.new()
	los.button_index = MOUSE_BUTTON_LEFT
	los.pressed = false
	los.position = weg
	los.global_position = weg
	_nep = true
	get_viewport().push_input(beweeg, true)
	get_viewport().push_input(los, true)
	_nep = false


func _binnen(p: Vector2) -> bool:
	return _scroll.get_global_rect().has_point(_naar_canvas(p))


## Gebeurtenissen in `_input` zijn al in viewportcoördinaten; de schaal is 1,
## maar staat hier apart voor het geval de lijst ooit in een geschaalde ouder
## hangt.
func _schaal() -> float:
	return 1.0


func _naar_canvas(p: Vector2) -> Vector2:
	return p
