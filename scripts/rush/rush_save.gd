class_name RushSave
extends RefCounted
## Wie je bent, hoeveel sterren je per dag haalde, en de eregalerij van dit
## apparaat. Alles staat in één bestand op het apparaat zelf; niets hiervan gaat
## ergens heen, tenzij je een score zelf online zet (RushOnline).

const PAD := "user://rush.json"

static var karakter: StringName = &""
static var sterren: Array[int] = [0, 0, 0, 0, 0]
## Snelste ontsnapping per dag in seconden; 0 is nog nooit.
static var ontsnapping: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
## De eregalerij van dit apparaat, zoals op een arcadekast: per dag de beste
## tien, van iedereen die hier gespeeld heeft. Een regel is
## {dag, naam, wie, rol, minuut, sterren, gebeld, ontsnap, portret}; `portret`
## is een RushPixel-code (1280 tekens), of leeg.
static var scores: Array[Dictionary] = []
const SCORES_PER_DAG := 10
## Willekeurig, alleen op dit apparaat: bewijst bij een online scorebord dat
## een score van jou is, zodat je hem zelf kunt wissen. Geen account.
static var sleutel := ""
## Heeft deze speler "Zo werkt het" al gezien? Dan komt het niet meer vanzelf.
static var uitleg_gezien := false

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
	var p: Variant = d.get("profiel", {})
	if p is Dictionary:
		RushProfiel.van_dict(p)
	var sc: Variant = d.get("scores", [])
	if sc is Array:
		for r: Variant in sc:
			if r is Dictionary:
				scores.append(r)
	sleutel = String(d.get("sleutel", ""))
	uitleg_gezien = bool(d.get("uitleg_gezien", false))
	var o: Variant = d.get("ontsnapping", [])
	if o is Array:
		for i: int in mini(o.size(), ontsnapping.size()):
			ontsnapping[i] = maxf(0.0, float(o[i]))


static func bewaar() -> void:
	var f := FileAccess.open(PAD, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"karakter": String(karakter), "sterren": sterren,
		"ontsnapping": ontsnapping, "profiel": RushProfiel.naar_dict(), "scores": scores,
		"sleutel": sleutel, "uitleg_gezien": uitleg_gezien}))


## Zet een gespeelde dag in de eregalerij. Geeft de plek terug (1 is de
## beste), of 0 als hij de tien niet haalt.
static func noteer_score(regel: Dictionary) -> int:
	var dag := int(regel.get("dag", 0))
	var van_dag: Array[Dictionary] = []
	for r: Dictionary in scores:
		if int(r.get("dag", -1)) == dag:
			van_dag.append(r)
	van_dag.append(regel)
	van_dag.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("minuut", 9999.0)) < float(b.get("minuut", 9999.0)))
	van_dag = van_dag.slice(0, SCORES_PER_DAG)
	var plek := van_dag.find(regel) + 1
	var rest: Array[Dictionary] = []
	for r: Dictionary in scores:
		if int(r.get("dag", -1)) != dag:
			rest.append(r)
	rest.append_array(van_dag)
	scores = rest
	bewaar()
	return plek


static func scores_van(dag: int) -> Array[Dictionary]:
	var uit: Array[Dictionary] = []
	for r: Dictionary in scores:
		if int(r.get("dag", -1)) == dag:
			uit.append(r)
	uit.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("minuut", 9999.0)) < float(b.get("minuut", 9999.0)))
	return uit


static func geef_sleutel() -> String:
	if sleutel == "":
		var c := Crypto.new()
		sleutel = c.generate_random_bytes(16).hex_encode()
		bewaar()
	return sleutel


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
