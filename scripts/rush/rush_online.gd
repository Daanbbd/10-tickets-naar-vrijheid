class_name RushOnline
extends RefCounted
## Het online scorebord. Staat uit zolang `ADRES` leeg is; dan doet het spel
## niets online en blijft alles op het apparaat.
##
## Wat de server doet, en wat hij bewaart en niet bewaart, staat in
## `server/README.md`. Hier de spelkant, met drie regels:
##   - Alleen jouw bijnaam, rol, eindtijd, ontsnaptijd, pixelportret en de
##     willekeurige sleutel van dit apparaat gaan weg. Niets anders.
##   - Alles is optioneel: geen netwerk, een trage of kapotte server, of een
##     weggegooid scherm geeft een leeg antwoord, nooit een crash.
##   - Er is geen account. De sleutel (`RushSave.geef_sleutel()`) is het enige
##     bewijs dat een regel van jou is, en daarmee kun je ze ook wissen.
##
## De drie functies wachten op het antwoord (`await`), met een tijdelijke
## `HTTPRequest` als kind van `ouder` (roep ze dus niet aan in `_ready` van
## die ouder, maar daarna). Op het web gebruikt Godot daar `fetch` voor; de
## server staat CORS toe voor de speelsite.

## Het adres van de Worker, zonder slash aan het eind: bijvoorbeeld
## "https://tickets-scorebord.jouwnaam.workers.dev". Leeg is uit.
const ADRES := ""

## Seconden voordat we opgeven. Het scorebord mag het spel nooit ophouden.
const TIJD_MAX := 6.0

## Wat er van een regel uit de eregalerij mee gaat. Nooit `wie`, `gebeld`
## of `sterren`: de server rekent de sterren zelf uit.
const VERSTUURD := ["dag", "naam", "rol", "minuut", "ontsnap", "portret"]


static func actief() -> bool:
	return ADRES != ""


## De top 20 van deze dag, op eindtijd. Elke regel is
## {naam, rol, minuut, sterren, ontsnap, portret}. Leeg bij een fout.
static func haal(ouder: Node, dag: int) -> Array:
	var antw: Dictionary = await _vraag(ouder, HTTPClient.METHOD_GET, "/scores?dag=%d" % dag)
	var uit: Array = []
	if antw["status"] != 200 or not antw["data"] is Dictionary:
		return uit
	var lijst: Variant = (antw["data"] as Dictionary).get("scores", [])
	if not lijst is Array:
		return uit
	for r: Variant in lijst:
		if r is Dictionary:
			uit.append(_schoon(r))
	return uit


## Zet een regel online en geeft de plek terug (1 is de beste), of 0 als hij
## de top 20 niet haalt of er iets misging. `regel` is een gewone regel uit
## `RushSave`; er gaat alleen mee wat in `VERSTUURD` staat.
static func stuur(ouder: Node, regel: Dictionary) -> int:
	for veld: String in VERSTUURD:
		if not regel.has(veld):
			return 0
	var portret := _tekst(regel["portret"])
	if portret != "" and not RushPixel.geldig(portret):
		portret = ""
	var body := {
		"dag": int(_getal(regel["dag"], 0.0)),
		"naam": _tekst(regel["naam"]),
		"rol": _tekst(regel["rol"]),
		"minuut": _getal(regel["minuut"], 0.0),
		"ontsnap": _getal(regel["ontsnap"], -1.0),
		"portret": portret,
		"sleutel": RushSave.geef_sleutel(),
	}
	var antw: Dictionary = await _vraag(ouder, HTTPClient.METHOD_POST, "/scores", body)
	if antw["status"] != 200 or not antw["data"] is Dictionary:
		return 0
	return maxi(0, int(_getal((antw["data"] as Dictionary).get("plek"), 0.0)))


## Wist al jouw regels van de server, op alle dagen. True als dat gelukt is.
## (De lokale eregalerij blijft; die wis je los in `RushSave`.)
static func wis(ouder: Node) -> bool:
	var antw: Dictionary = await _vraag(ouder, HTTPClient.METHOD_DELETE, "/scores",
		{"sleutel": RushSave.geef_sleutel()})
	return antw["status"] == 200


## Eén verzoek. Geeft altijd {status, data}; status 0 is "geen antwoord".
static func _vraag(ouder: Node, methode: HTTPClient.Method, pad: String, body: Variant = null) -> Dictionary:
	var geen := {"status": 0, "data": null}
	if not actief() or not is_instance_valid(ouder) or not ouder.is_inside_tree():
		return geen
	var req := HTTPRequest.new()
	req.timeout = TIJD_MAX
	ouder.add_child(req)
	var koppen := PackedStringArray(["Accept: application/json"])
	var tekst := ""
	if body != null:
		koppen.append("Content-Type: application/json")
		tekst = JSON.stringify(body)
	if req.request(ADRES.trim_suffix("/") + pad, koppen, methode, tekst) != OK:
		req.queue_free()
		return geen
	var uit: Array = await req.request_completed
	req.queue_free()
	if int(uit[0]) != HTTPRequest.RESULT_SUCCESS:
		return geen
	var data: Variant = JSON.parse_string((uit[3] as PackedByteArray).get_string_from_utf8())
	return {"status": int(uit[1]), "data": data}


## Wat de server stuurt is data, geen code: we nemen alleen de bekende velden
## over, in het juiste type, en een portret alleen als het een geldige code is.
static func _schoon(r: Dictionary) -> Dictionary:
	var portret := _tekst(r.get("portret"))
	return {
		"naam": _tekst(r.get("naam")),
		"rol": _tekst(r.get("rol")),
		"minuut": _getal(r.get("minuut"), 0.0),
		"sterren": clampi(int(_getal(r.get("sterren"), 1.0)), 1, 3),
		"ontsnap": _getal(r.get("ontsnap"), -1.0),
		"portret": portret if RushPixel.geldig(portret) else "",
	}


static func _tekst(v: Variant) -> String:
	return v if v is String else ""


static func _getal(v: Variant, standaard: float) -> float:
	return float(v) if v is int or v is float else standaard
