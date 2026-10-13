extends Control
## Test voor RushVeeg: slepen over een knop scrolt en tikt hem niet aan,
## gewoon tikken werkt nog, en na een snelle veeg glijdt de lijst uit.
##
## Met een echt venster (headless levert Godot geen GUI-invoer af):
##     Godot --path . --position -4000,-4000 tests/rush_veeg_test.tscn

var _getikt := 0
var _fouten := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(0, 0)
	scroll.size = Vector2(192, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	RushVeeg.koppel(scroll)
	var kol := VBoxContainer.new()
	kol.custom_minimum_size = Vector2(192, 0)
	scroll.add_child(kol)
	for i: int in 30:
		var b := Button.new()
		b.text = "knop %d" % i
		b.custom_minimum_size = Vector2(0, 40)
		b.mouse_filter = Control.MOUSE_FILTER_PASS
		b.pressed.connect(func() -> void: _getikt += 1)
		kol.add_child(b)
	# Wachten tot de lijst opgemeten is: anders valt er nog niets te scrollen.
	for i: int in 60:
		await get_tree().process_frame
		var balk := scroll.get_v_scroll_bar()
		if balk.max_value - balk.page > 100.0:
			break

	# 1. Gewoon tikken.
	await _druk(Vector2(96, 20), true)
	await _druk(Vector2(96, 20), false)
	_check(_getikt == 1, "een tik zonder slepen tikt de knop aan (%d)" % _getikt)

	# 2. Slepen over een knop: scrollt, en tikt niet.
	await _druk(Vector2(96, 200), true)
	for i: int in 8:
		await _beweeg(Vector2(96, 200 - (i + 1) * 10))
	await get_tree().create_timer(0.2).timeout
	await _druk(Vector2(96, 120), false)
	_check(_getikt == 1, "slepen tikt geen knop aan (%d)" % _getikt)
	_check(scroll.scroll_vertical >= 70, "slepen scrolt mee (%d)" % scroll.scroll_vertical)

	# 3. Snel vegen en loslaten: hij glijdt door.
	var voor := scroll.scroll_vertical
	await _druk(Vector2(96, 250), true)
	for i: int in 4:
		await _beweeg(Vector2(96, 250 - (i + 1) * 25))
	await _druk(Vector2(96, 150), false)
	var bij_los := scroll.scroll_vertical
	await get_tree().create_timer(0.5).timeout
	_check(scroll.scroll_vertical > bij_los + 20, "na een veeg glijdt hij uit (%d -> %d)" % [bij_los, scroll.scroll_vertical])
	_check(bij_los > voor, "de veeg zelf scrolt (%d -> %d)" % [voor, bij_los])

	print("rush_veeg_test: %s (%d fout)" % ["OK" if _fouten == 0 else "FOUT", _fouten])
	get_tree().quit(0 if _fouten == 0 else 1)


func _druk(p: Vector2, in_: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = in_
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if in_ else 0
	e.position = p
	e.global_position = p
	get_viewport().push_input(e, true)
	await get_tree().process_frame


func _beweeg(p: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	e.position = p
	e.global_position = p
	get_viewport().push_input(e, true)
	await get_tree().process_frame


func _check(ok: bool, wat: String) -> void:
	if not ok:
		_fouten += 1
		print("FOUT: ", wat)
