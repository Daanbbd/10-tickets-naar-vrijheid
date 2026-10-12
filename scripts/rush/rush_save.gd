class_name RushSave
extends RefCounted
## Wie je bent en hoeveel sterren je per dag haalde. Meer onthoudt de rush niet.

const PAD := "user://rush.json"

static var karakter: StringName = &""
static var sterren: Array[int] = [0, 0, 0, 0, 0]
## Snelste ontsnapping per dag in seconden; 0 is nog nooit.
static var ontsnapping: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
## De dag die nu gespeeld wordt; gezet door het menu, gelezen door het spel.
static var dag: int = 0
static var _geladen := false


static func laad() -> void:
	if _geladen:
		return
	_geladen = true
	if not FileAccess.file_exists(PAD):
		return
	var f := FileAccess.open(PAD, FileAccess.READ)
	if f == null:
		return
	var d: Variant = JSON.parse_string(f.get_as_text())
	if not d is Dictionary:
		return
	karakter = StringName(String(d.get("karakter", "")))
	var s: Variant = d.get("sterren", [])
	if s is Array:
		for i: int in mini(s.size(), sterren.size()):
			sterren[i] = clampi(int(s[i]), 0, 3)
	var o: Variant = d.get("ontsnapping", [])
	if o is Array:
		for i: int in mini(o.size(), ontsnapping.size()):
			ontsnapping[i] = maxf(0.0, float(o[i]))


static func bewaar() -> void:
	var f := FileAccess.open(PAD, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"karakter": String(karakter), "sterren": sterren,
		"ontsnapping": ontsnapping}))


## Eerste dag zonder sterren; daarna is de week klaar en blijft vrijdag open.
static func open_dag() -> int:
	for i: int in sterren.size():
		if sterren[i] == 0:
			return i
	return sterren.size() - 1


static func is_open(i: int) -> bool:
	return i == 0 or sterren[i - 1] > 0


static func noteer(i: int, s: int) -> void:
	sterren[i] = maxi(sterren[i], s)
	bewaar()


## Geeft true als dit een nieuw record is.
static func noteer_ontsnapping(i: int, sec: float) -> bool:
	var record := ontsnapping[i] <= 0.0 or sec < ontsnapping[i]
	if record:
		ontsnapping[i] = sec
		bewaar()
	return record


static func totaal() -> int:
	var t := 0
	for s: int in sterren:
		t += s
	return t
