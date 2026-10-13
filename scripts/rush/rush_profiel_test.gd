extends RefCounted
## Headless test van de profielmaker: van teamfoto via de GDScript-pijplijn
## naar portret, door de RushPixel-code heen, en het profiel heen en terug door
## `naar_dict()`/`van_dict()`. De browserkant kan headless niet draaien; die
## levert hetzelfde 32x40-plaatje aan als `RushSelfie.verklein()`.
##
## Draaien:
##   Godot --headless --path . scenes/rush/rush_profiel.tscn -- --test [--blad=/pad/blad.png]
## `--blad` schrijft een contactblad (uitsnede, portret, voorgestelde kleuren)
## om met het oog te beoordelen.

const FOTOS := "res://assets/personen"

var _fout := 0


func draai(scherm: RushProfielScherm) -> int:
	var oud := RushProfiel.naar_dict()
	_uitsnede()
	_naam_filter()
	var portretten := _fotos()
	_figuur(scherm)
	_rondreis(portretten)
	_opslaan_en_annuleren(scherm)
	RushProfiel.van_dict(oud)
	print("rush_profiel_test: %s (%d fout)" % ["OK" if _fout == 0 else "MIS", _fout])
	return 0 if _fout == 0 else 1


func _ok(cond: bool, wat: String) -> void:
	if not cond:
		_fout += 1
		print("  MIS: " + wat)


func _uitsnede() -> void:
	for maat: Vector2i in [Vector2i(3024, 4032), Vector2i(4032, 3024), Vector2i(550, 538),
			Vector2i(1080, 1920), Vector2i(31, 39), Vector2i(1, 1)]:
		var r := RushSelfie.uitsnede(maat)
		_ok(Rect2i(Vector2i.ZERO, maat).encloses(r), "uitsnede %s valt buiten de foto: %s" % [maat, r])
		if maat.x > 100:
			var verhouding := float(r.size.x) / r.size.y
			_ok(absf(verhouding - 0.8) < 0.01, "uitsnede %s is geen 4:5 maar %.3f" % [maat, verhouding])


func _naam_filter() -> void:
	var gevallen := {
		"  Daan  ": "Daan", "Jan-Piet_2": "Jan-Piet_2", "<script>": "script",
		"Zoë": "Zoë", "a  b": "a b", "😀Kim": "Kim", "heel lange bijnaam hier": "heel lange b",
		"ab/cd;ef": "abcdef", "日本": "",
	}
	for invoer: String in gevallen:
		var uit := RushProfielScherm.schoon(invoer, true)
		_ok(uit == gevallen[invoer], "schoon(%s) gaf '%s', verwacht '%s'" % [invoer, uit, gevallen[invoer]])


## Elke teamfoto door de pijplijn. Geeft de portretten terug voor de rondreis.
func _fotos() -> Array[Image]:
	var uit: Array[Image] = []
	var blad_pad := ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--blad="):
			blad_pad = a.get_slice("=", 1)
	var namen := Array(DirAccess.get_files_at(FOTOS)).filter(
		func(f: String) -> bool: return f.ends_with(".png"))
	_ok(namen.size() > 0, "geen foto's in %s" % FOTOS)
	var blad := Image.create_empty(464, maxi(1, namen.size()) * 168 + 4, false, Image.FORMAT_RGBA8)
	blad.fill(Color("#141824"))
	for i: int in namen.size():
		var pad := ProjectSettings.globalize_path("%s/%s" % [FOTOS, namen[i]])
		var klein := RushSelfie.van_bestand(pad)
		_ok(klein != null and klein.get_size() == Vector2i(32, 40), "%s: geen 32x40" % namen[i])
		if klein == null:
			continue
		# Wat de browser zou sturen: precies 5120 bytes RGBA.
		var terug := RushSelfie.van_rgba(klein.get_data())
		_ok(terug != null and terug.get_data() == klein.get_data(), "%s: van_rgba verliest iets" % namen[i])
		var p := RushSelfie.naar_portret(klein)
		_ok(_in_palet(p), "%s: portret niet in het palet" % namen[i])
		var code := RushPixel.naar_code(p)
		_ok(RushPixel.geldig(code), "%s: code ongeldig" % namen[i])
		var weer := RushPixel.van_code(code)
		_ok(weer != null and weer.get_data() == p.get_data(), "%s: code reist niet heen en terug" % namen[i])
		uit.append(p)
		_op_blad(blad, i, namen[i], klein, p)
	if blad_pad != "":
		blad.save_png(blad_pad)
		print("  contactblad: " + blad_pad)
	_ok(RushSelfie.van_rgba(PackedByteArray([1, 2, 3])) == null, "van_rgba slikt een verkeerde lengte")
	return uit


## Per foto een rij: het teamportret uit gen_portraits.py, dit portret, de
## verkleinde foto zelf, en de voorgestelde huid- en haarkleur.
func _op_blad(blad: Image, i: int, naam: String, klein: Image, p: Image) -> void:
	var y := i * 168 + 4
	var ref_pad := "res://assets/sprites/portraits/%s" % naam
	if ResourceLoader.exists(ref_pad):
		blad.blit_rect(_groot((load(ref_pad) as Texture2D).get_image()), Rect2i(0, 0, 128, 160), Vector2i(4, y))
	blad.blit_rect(_groot(p), Rect2i(0, 0, 128, 160), Vector2i(136, y))
	blad.blit_rect(_groot(klein), Rect2i(0, 0, 128, 160), Vector2i(268, y))
	var huid := RushProfielScherm.dichtstbij(RushSelfie.huidkleur(klein), RushProfielScherm.HUID)
	blad.fill_rect(Rect2i(400, y, 28, 28), huid)
	var haar: Variant = RushSelfie.haarkleur(klein)
	if haar is Color:
		blad.fill_rect(Rect2i(400, y + 32, 28, 28), haar)
		blad.fill_rect(Rect2i(432, y + 32, 28, 28), RushProfielScherm.dichtstbij(
			haar, RushProfielScherm.HAAR.slice(0, RushProfielScherm.HAAR_ECHT)))


func _groot(img: Image) -> Image:
	var g := img.duplicate() as Image
	g.convert(Image.FORMAT_RGBA8)
	g.resize(128, 160, Image.INTERPOLATE_NEAREST)
	return g


func _in_palet(img: Image) -> bool:
	for y: int in img.get_height():
		for x: int in img.get_width():
			if not RushPixel.PALET.has(img.get_pixel(x, y)):
				return false
	return true


func _figuur(scherm: RushProfielScherm) -> void:
	var p := RushSelfie.van_figuur(scherm._frames(), RushProfielScherm.ACHTERGROND)
	_ok(p.get_size() == Vector2i(32, 40) and _in_palet(p), "portret zonder foto is geen 32x40 in het palet")
	_ok(RushPixel.geldig(RushPixel.naar_code(p)), "portret zonder foto geeft geen geldige code")


func _rondreis(portretten: Array[Image]) -> void:
	RushProfiel.naam = "Test-Kim_1"
	RushProfiel.rol = RushProfiel.Rol.OPERATIONS
	RushProfiel.look = {&"body": &"slank", &"hair": &"krullen", &"facial": &"", &"outfit": &"hoodie", &"accessory": &"bril"}
	RushProfiel.kleuren = {&"shirt": Color("#e5484d"), &"skin": Color("#8d5a3b"), &"hair": Color("#1f1a17"),
		&"pants": Color("#34384e"), &"accent": Color("#f4a259")}
	RushProfiel.portret = portretten[0] if not portretten.is_empty() else null
	var d := RushProfiel.naar_dict()
	var tekst := JSON.stringify(d)
	RushProfiel.van_dict({})
	_ok(not RushProfiel.bestaat(), "van_dict({}) laat een profiel staan")
	RushProfiel.van_dict(JSON.parse_string(tekst))
	_ok(RushProfiel.naar_dict() == d, "naar_dict/van_dict verliest iets:\n%s\n%s" % [d, RushProfiel.naar_dict()])
	_ok(RushProfiel.rol == RushProfiel.Rol.OPERATIONS, "rol reist niet mee")
	_ok(RushProfiel.look.get(&"accessory") == &"bril", "look reist niet mee")
	if RushProfiel.portret != null and not portretten.is_empty():
		_ok(RushProfiel.portret.get_data() == portretten[0].get_data(), "portret reist niet mee")
	_ok(tekst.length() < 2000, "profiel is %d tekens; er past meer in dan een pixelportret" % tekst.length())


## Opslaan zet alles in RushProfiel; Annuleren raakt niets aan.
func _opslaan_en_annuleren(scherm: RushProfielScherm) -> void:
	var voor := RushProfiel.naar_dict()
	var s := RushProfielScherm.new()
	scherm.add_child(s)
	var uitkomst: Array[bool] = []
	s.klaar.connect(func(o: bool) -> void: uitkomst.append(o))
	s._naam = "Iets anders"
	s._rol = RushProfiel.Rol.SALES
	s._blader(&"hair", 1)
	s.klaar.emit(false)
	_ok(RushProfiel.naar_dict() == voor, "annuleren veranderde het profiel")
	s._naam = "Nieuw"
	s._uit_foto = false
	s._opslaan()
	_ok(uitkomst == [false], "opslaan zonder foto mag niet: %s" % [uitkomst])
	var klein := (load("res://assets/sprites/portraits/victor.png") as Texture2D).get_image()
	klein.convert(Image.FORMAT_RGBA8)
	s._op_foto(klein)
	s._opslaan()
	_ok(uitkomst == [false, true], "klaar kwam niet als verwacht: %s" % [uitkomst])
	_ok(RushProfiel.uit_foto and RushProfiel.heeft_identiteit(), "na een foto heb je een identiteit")
	# Een profiel zonder gekozen uiterlijk moet toch een zichtbaar poppetje geven.
	var bewaard := RushProfiel.look
	RushProfiel.look = {}
	var img := RushProfiel.frames().get_frame_texture(&"idle_down", 0).get_image()
	var zichtbaar := 0
	for y: int in img.get_height():
		for x: int in img.get_width():
			if img.get_pixel(x, y).a > 0.1:
				zichtbaar += 1
	_ok(zichtbaar > 50, "een leeg uiterlijk geeft een onzichtbaar poppetje (%d pixels)" % zichtbaar)
	RushProfiel.look = bewaard
	_ok(RushProfiel.naam == "Nieuw" and RushProfiel.rol == RushProfiel.Rol.SALES, "opslaan zette naam/rol niet")
	_ok(RushProfiel.portret != null and RushProfiel.portret.get_size() == Vector2i(32, 40), "opslaan zonder portret")
	s.queue_free()
