extends Node
## Test tegen het echte online scorebord: versturen, ophalen, koplopers, en
## daarna alles weer wissen, zodat het bord schoon blijft. Gebruikt een eigen
## testsleutel, niet die van dit apparaat.
##
##     Godot --headless --path . tests/rush_online_test.tscn

var _fouten := 0


func _ready() -> void:
	if not RushOnline.actief():
		print("rush_online_test: overgeslagen (geen ADRES)")
		get_tree().quit()
		return
	RushSave._geladen = true
	RushSave.sleutel = Crypto.new().generate_random_bytes(16).hex_encode()
	var regel := {"dag": 4, "naam": "Testbot", "rol": "Developer", "minuut": 990.0,
		"ontsnap": 22.5, "punten": 1300, "portret": RushPixel.naar_code(
			(load("res://assets/sprites/portraits/victor.png") as Texture2D).get_image())}
	var plek: int = await RushOnline.stuur(self, regel)
	_check(plek >= 1, "stuur geeft een plek (%d)" % plek)
	var lijst: Array = await RushOnline.haal(self, 4)
	var gevonden := false
	for r: Dictionary in lijst:
		if r["naam"] == "Testbot" and r["punten"] == 1300 and r["sterren"] == 3:
			gevonden = true
	_check(gevonden, "haal vindt de regel terug, met sterren van de server")
	var kop: Array = await RushOnline.koplopers(self)
	_check(kop.size() == 5 and kop[4] is Dictionary, "koplopers heeft vrijdag")
	var te_veel := regel.duplicate()
	te_veel["punten"] = 99999
	_check(await RushOnline.stuur(self, te_veel) == 0, "onzin-punten worden geweigerd")
	_check(await RushOnline.wis(self), "wis lukt")
	lijst = await RushOnline.haal(self, 4)
	for r: Dictionary in lijst:
		if r["naam"] == "Testbot":
			_check(false, "na wissen is de testregel weg")
	print("rush_online_test: %s (%d fout)" % ["OK" if _fouten == 0 else "FOUT", _fouten])
	get_tree().quit(0 if _fouten == 0 else 1)


func _check(ok: bool, wat: String) -> void:
	if not ok:
		_fouten += 1
		print("FOUT: ", wat)
