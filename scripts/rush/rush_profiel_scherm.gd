class_name RushProfielScherm
extends Control
## Jezelf maken: bijnaam, rol, portret en uiterlijk.
##
## Eén scrollbaar scherm in plaats van stappen. Bovenaan staat steeds wat je
## aan het maken bent (portret en loopfiguurtje); daaronder scroll je met je
## duim door de keuzes, en Opslaan en Annuleren staan altijd onderin. Met
## stappen zou je na elke keuze moeten terugbladeren om te zien wat het deed.
##
## Alles gebeurt op een kopie. Pas bij Opslaan gaat het naar `RushProfiel`;
## Annuleren laat het bestaande profiel ongemoeid. Bewaren op schijf doet het
## menu zelf, na `klaar(true)`.

signal klaar(opgeslagen: bool)

const VOLGORDE: Array[StringName] = [&"hair", &"facial", &"outfit", &"accessory", &"body"]
const SLOTNAAM := {
	&"hair": "Kapsel", &"facial": "Gezichtshaar", &"outfit": "Kleding",
	&"accessory": "Extra", &"body": "Postuur",
}
## Alleen wat er in `assets/sprites/characters/` staat. De lege variant is
## "geen"; een kapsel en een postuur heb je altijd.
const OPTIES := {
	&"hair": [&"kort", &"fade", &"kuif", &"zijscheiding", &"stekels", &"krullen",
		&"dunnend", &"kaal", &"lang", &"staart", &"knot"],
	&"facial": [&"", &"stoppels", &"snor", &"sik", &"baard"],
	&"outfit": [&"tshirt", &"polo", &"overhemd", &"blouse", &"trui", &"hoodie", &"vest", &"blazer"],
	&"accessory": [&"", &"bril", &"koptelefoon", &"pet", &"lanyard", &"speldje", &"tas", &"doos"],
	&"body": [&"gemiddeld", &"slank", &"stevig"],
}
const VARIANTNAAM := {&"": "geen", &"tshirt": "T-shirt", &"zijscheiding": "scheiding"}

const SHIRT: Array[Color] = [
	Color("#3a86ff"), Color("#243cec"), Color("#3fd27f"), Color("#1d7a52"),
	Color("#e5484d"), Color("#ff9f43"), Color("#ffd23f"), Color("#a463f2"),
	Color("#e56fa8"), Color("#2a2d38"), Color("#f4f5f7"), Color("#6b7390"),
]
const HUID: Array[Color] = [
	Color("#f7dcc0"), Color("#ecc59c"), Color("#e0b491"),
	Color("#c08552"), Color("#8d5a3b"), Color("#5a3a26"),
]
## De eerste negen zijn echte haarkleuren; alleen daaruit kiest een selfie.
## Lichtbruin en donkerblond staan er zodat rossig en middenbruin niet op rood
## of op blond vallen.
const HAAR: Array[Color] = [
	Color("#1f1a17"), Color("#3b2418"), Color("#6b4b36"), Color("#8f6a48"),
	Color("#b8925a"), Color("#e0c48a"), Color("#a0522d"), Color("#9aa3b8"),
	Color("#f4f5f7"), Color("#e56fa8"), Color("#3a86ff"), Color("#3fd27f"),
]
const HAAR_ECHT := 9
## Dezelfde standaard als `RushProfiel.frames()`.
const STANDAARD_KLEUREN := {
	&"shirt": Color("#3a86ff"), &"skin": Color("#e0b491"), &"hair": Color("#6b4b36"),
	&"pants": Color("#34384e"), &"accent": Color("#f4a259"),
}
## Achter het poppetje als je portret geen foto is: de muur van het kantoor.
const ACHTERGROND := Color("#484e60")
const PRIVACY := "Je foto blijft op je telefoon. Alleen het pixelplaatje wordt bewaard."
const LOOP_RICHTINGEN: Array[StringName] = [&"walk_down", &"walk_right", &"walk_up", &"walk_left"]

# De kopie waar je op werkt.
## Alleen bijnaam en foto: wie je bent, los van welk personage je speelt.
## Dat vraagt het spel aan iedereen, ook wie een vaste collega speelt, zodat
## het scorebord jouw gezicht laat zien. Zet dit vóór `add_child`.
var alleen_wie := false

var _naam := ""
var _rol: RushProfiel.Rol = RushProfiel.Rol.DEVELOPER
var _look: Dictionary = {}
var _kleuren: Dictionary = {}
var _portret: Image = null
## Of het portret een foto is. Zo niet, dan volgt het je poppetje.
var _uit_foto := false

var _selfie: RushSelfie
var _scroll: ScrollContainer
var _portret_rect: TextureRect
var _figuur: AnimatedSprite2D
var _wie: Label
var _naam_knop: Button
var _naam_veld: LineEdit
var _rol_knoppen: Array[Button] = []
var _voordeel: Label
var _status: Label
var _blader_waarde: Dictionary = {}   ## slot -> Label
var _stalen: Dictionary = {}          ## kleursleutel -> {Color: Button}
var _loop_tijd := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_neem_over()
	_selfie = RushSelfie.new()
	add_child(_selfie)
	_selfie.foto.connect(_op_foto)
	_selfie.geen_foto.connect(func() -> void: _zeg("Geen foto gekozen."))
	_bouw()
	_ververs()
	_qa_vlaggen()


func _process(delta: float) -> void:
	_loop_tijd += delta
	var anim := LOOP_RICHTINGEN[int(_loop_tijd / 1.6) % LOOP_RICHTINGEN.size()]
	if _figuur.animation != anim:
		_figuur.play(anim)


# --- De kopie -------------------------------------------------------------------

## Begin bij wat er al is, zodat dit scherm ook "aanpassen" is.
func _neem_over() -> void:
	_naam = RushProfiel.naam
	if _naam == "" and OS.has_feature("web"):
		# Sommige ingebouwde browsers (Slack, Teams) blokkeren `prompt()`. Met
		# een voorgestelde naam kun je dan toch opslaan; wie wel kan typen,
		# overschrijft hem.
		_naam = "Collega %d" % randi_range(10, 99)
	_rol = RushProfiel.rol
	_look = CharacterSprites.normaliseer_look(RushProfiel.look)
	_kleuren = STANDAARD_KLEUREN.duplicate()
	for k: Variant in RushProfiel.kleuren:
		_kleuren[StringName(k)] = RushProfiel.kleuren[k]
	var oud := RushProfiel.portret
	if oud == null or oud.is_empty():
		_uit_foto = false
		_portret = _figuurportret()
	else:
		_portret = oud.duplicate() as Image
		# Was het oude portret je poppetje, dan blijft het dat volgen.
		_uit_foto = RushProfiel.uit_foto


func _frames() -> SpriteFrames:
	return CharacterSprites.frames_for(_look, _kleuren[&"shirt"], _kleuren[&"skin"],
		_kleuren[&"hair"], _kleuren[&"pants"], _kleuren[&"accent"])


func _figuurportret() -> Image:
	return RushSelfie.van_figuur(_frames(), ACHTERGROND)


## Alles wat van de kopie afhangt opnieuw tonen. Goedkoop genoeg om na elke
## tik te doen: het portret is 1280 pixels, en de sprites zitten in een cache.
func _ververs() -> void:
	if not _uit_foto:
		_portret = _figuurportret()
	_portret_rect.texture = ImageTexture.create_from_image(_portret)
	var anim := _figuur.animation
	_figuur.sprite_frames = _frames()
	_figuur.play(anim if _figuur.sprite_frames.has_animation(anim) else &"walk_down")
	var n := schoon(_naam, true)
	_wie.text = (n if n != "" else "Nog naamloos") if alleen_wie else \
		"%s · %s" % [n if n != "" else "Nog naamloos", RushProfiel.ROL_NAAM[_rol]]
	if _naam_knop != null:
		_naam_knop.text = n if n != "" else "Tik voor je bijnaam"
		_naam_knop.add_theme_color_override(&"font_color", Color.WHITE if n != "" else Color("#8a93a8"))
	# Alleen als het echt anders is: tijdens het typen zou dit de cursor verzetten.
	if _naam_veld != null and _naam_veld.text != _naam:
		_naam_veld.text = _naam
	for i: int in _rol_knoppen.size():
		_stijl_keuze(_rol_knoppen[i], i == int(_rol))
	if _voordeel != null:
		_voordeel.text = RushProfiel.ROL_VOORDEEL[_rol]
	for slot: StringName in VOLGORDE:
		if _blader_waarde.has(slot):
			(_blader_waarde[slot] as Label).text = _variantnaam(_look.get(slot, &""))
	for sleutel: StringName in _stalen:
		var knoppen: Dictionary = _stalen[sleutel]
		for c: Color in knoppen:
			_stijl_staal(knoppen[c], c, c.is_equal_approx(_kleuren[sleutel]))


# --- Opbouw ---------------------------------------------------------------------

func _bouw() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#141824")
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var marge := MarginContainer.new()
	add_child(marge)
	marge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for k: String in ["left", "right"]:
		marge.add_theme_constant_override("margin_" + k, 10)
	marge.add_theme_constant_override(&"margin_top", 10)
	marge.add_theme_constant_override(&"margin_bottom", 10)
	var kol := VBoxContainer.new()
	kol.add_theme_constant_override(&"separation", 4)
	marge.add_child(kol)

	kol.add_child(_lbl("WIE BEN JIJ?" if alleen_wie else "JEZELF MAKEN", 16, Color("#3a86ff"), true))
	if alleen_wie:
		kol.add_child(_lbl("Je naam en gezicht op het scorebord.", 10, Color("#b0b4c2"), true))
	kol.add_child(_voorbeeld())
	_wie = _lbl("", 10, Color("#ffd23f"), true)
	kol.add_child(_wie)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.scroll_deadzone = 6
	RushVeeg.koppel(_scroll)
	_dunne_balk(_scroll.get_v_scroll_bar())
	kol.add_child(_scroll)
	var inhoud := VBoxContainer.new()
	inhoud.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inhoud.add_theme_constant_override(&"separation", 4)
	_scroll.add_child(inhoud)
	_bouw_naam(inhoud)
	if alleen_wie:
		_bouw_foto(inhoud)
	else:
		_bouw_rol(inhoud)
		_bouw_foto(inhoud)
		_bouw_uiterlijk(inhoud)
		_bouw_kleuren(inhoud)
	inhoud.add_child(UiKit.spacer(4))

	var balk := HBoxContainer.new()
	balk.add_theme_constant_override(&"separation", 6)
	kol.add_child(balk)
	var annuleer := _knop("Annuleren", false)
	annuleer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	annuleer.pressed.connect(func() -> void: klaar.emit(false))
	balk.add_child(annuleer)
	var bewaar := _knop("Opslaan", true)
	bewaar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bewaar.pressed.connect(_opslaan)
	balk.add_child(bewaar)


## Portret op 2x naast het loopfiguurtje op 2x: wat je kiest, zie je meteen.
func _voorbeeld() -> Control:
	var rij := HBoxContainer.new()
	rij.alignment = BoxContainer.ALIGNMENT_CENTER
	rij.add_theme_constant_override(&"separation", 14)
	var lijst := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#1f2433")
	sb.border_color = Color("#4a5677")
	sb.set_border_width_all(1)
	sb.set_content_margin_all(2)
	lijst.add_theme_stylebox_override(&"panel", sb)
	_portret_rect = TextureRect.new()
	_portret_rect.custom_minimum_size = Vector2(RushPixel.B * 2, RushPixel.H * 2)
	_portret_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portret_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_portret_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	lijst.add_child(_portret_rect)
	rij.add_child(lijst)

	var podium := Control.new()
	podium.custom_minimum_size = Vector2(44, 84)
	podium.draw.connect(func() -> void:
		podium.draw_rect(Rect2(6, 76, 32, 4), Color(0, 0, 0, 0.35)))
	_figuur = AnimatedSprite2D.new()
	_figuur.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_figuur.scale = Vector2(2, 2)
	_figuur.position = Vector2(22, 44)
	_figuur.sprite_frames = _frames()
	_figuur.play(&"walk_down")
	podium.add_child(_figuur)
	rij.add_child(podium)
	# Wie alleen zichzelf invult, speelt misschien een vaste collega: dan zegt
	# een poppetje niets.
	podium.visible = not alleen_wie
	return rij


func _bouw_naam(kol: VBoxContainer) -> void:
	kol.add_child(_kop("BIJNAAM"))
	# Op web geen LineEdit maar een knop die `prompt()` opent. Het virtuele
	# toetsenbord van Godot is een experimentele exportoptie die hier uit staat,
	# dus een LineEdit op een telefoon laat zich wel aantikken maar niet
	# beschrijven. Een eigen HTML-invoerveld over het canvas kan wel, maar moet
	# meeschalen met de canvasschaal, de notch en het toetsenbord dat het beeld
	# opschuift. `prompt()` geeft in één regel het toetsenbord van de telefoon
	# zelf, met autocorrectie en zonder lay-outwerk; voor één veld van twaalf
	# tekens is dat de betere ruil dan een mooier maar breekbaarder veld.
	if RushSelfie.op_web():
		_naam_knop = _knop("", false)
		_naam_knop.pressed.connect(_vraag_naam)
		_in_scroll(_naam_knop)
		kol.add_child(_naam_knop)
		return
	_naam_veld = LineEdit.new()
	_naam_veld.text = _naam
	_naam_veld.max_length = RushProfiel.NAAM_MAX
	_naam_veld.placeholder_text = "Je bijnaam"
	_naam_veld.custom_minimum_size = Vector2(0, 30)
	_naam_veld.add_theme_font_override(&"font", UiKit.font_voor(12))
	_naam_veld.add_theme_font_size_override(&"font_size", 12)
	_naam_veld.text_changed.connect(func(t: String) -> void:
		var s := schoon(t, false)
		if s != t:
			_naam_veld.text = s
			_naam_veld.caret_column = s.length()
		_naam = s
		_ververs())
	_in_scroll(_naam_veld)
	kol.add_child(_naam_veld)


func _vraag_naam() -> void:
	var vraag := "Je bijnaam (max %d tekens)" % RushProfiel.NAAM_MAX
	var antwoord: Variant = JavaScriptBridge.eval(
		"prompt(%s, %s)" % [JSON.stringify(vraag), JSON.stringify(_naam)], true)
	if antwoord == null:
		return
	_naam = schoon(String(antwoord), true)
	_ververs()


func _bouw_rol(kol: VBoxContainer) -> void:
	kol.add_child(_kop("ROL"))
	# Twee kolommen: "Operations" en "Consultant" passen niet met drie naast
	# elkaar op 192 pixels.
	var raster := GridContainer.new()
	raster.columns = 2
	raster.add_theme_constant_override(&"h_separation", 4)
	raster.add_theme_constant_override(&"v_separation", 4)
	kol.add_child(raster)
	for r: int in RushProfiel.Rol.size():
		var b := _knop(RushProfiel.ROL_NAAM[r], false)
		b.custom_minimum_size = Vector2(0, 28)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void:
			Haptiek.tril(Haptiek.Sterkte.TIK)
			_rol = r as RushProfiel.Rol
			_ververs())
		_in_scroll(b)
		raster.add_child(b)
		_rol_knoppen.append(b)
	_voordeel = _lbl("", 10, Color("#f4a259"), true)
	# Twee regels vast, zodat de rest niet verspringt bij een kortere uitleg.
	_voordeel.custom_minimum_size = Vector2(0, 26)
	kol.add_child(_voordeel)


func _bouw_foto(kol: VBoxContainer) -> void:
	kol.add_child(_kop("PORTRET"))
	# Altijd je eigen gezicht: geen "zonder foto". Het scorebord is leuker met
	# echte koppen, ook als je een vaste collega speelt.
	if RushSelfie.op_web() and Invoer.is_telefoon():
		var selfie := _knop("Maak een selfie", true)
		_selfie.dek(selfie, true, _scroll)
		_in_scroll(selfie)
		kol.add_child(selfie)
	var kies := _knop("Kies foto", not (RushSelfie.op_web() and Invoer.is_telefoon()))
	if RushSelfie.op_web():
		_selfie.dek(kies, false, _scroll)
	else:
		kies.pressed.connect(_selfie.kies_bestand)
	_in_scroll(kies)
	kol.add_child(kies)
	kol.add_child(_lbl(PRIVACY, 10, Color("#b0b4c2"), true))
	_status = _lbl("", 10, Color("#3fd27f"), true)
	kol.add_child(_status)


func _bouw_uiterlijk(kol: VBoxContainer) -> void:
	kol.add_child(_kop("UITERLIJK"))
	for slot: StringName in VOLGORDE:
		kol.add_child(_bladerrij(slot))


func _bladerrij(slot: StringName) -> Control:
	var rij := HBoxContainer.new()
	rij.add_theme_constant_override(&"separation", 4)
	var terug := _pijl("◀", slot, -1)
	rij.add_child(terug)
	var midden := VBoxContainer.new()
	midden.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	midden.alignment = BoxContainer.ALIGNMENT_CENTER
	midden.add_theme_constant_override(&"separation", 0)
	midden.add_child(_lbl(SLOTNAAM[slot], 10, Color("#8a93a8"), true))
	var waarde := _lbl("", 12, Color.WHITE, true)
	waarde.autowrap_mode = TextServer.AUTOWRAP_OFF
	midden.add_child(waarde)
	_blader_waarde[slot] = waarde
	rij.add_child(midden)
	rij.add_child(_pijl("▶", slot, 1))
	return rij


func _pijl(t: String, slot: StringName, stap: int) -> Button:
	var b := _knop(t, false)
	b.custom_minimum_size = Vector2(32, 30)
	b.pressed.connect(func() -> void: _blader(slot, stap))
	_in_scroll(b)
	return b


func _blader(slot: StringName, stap: int) -> void:
	var lijst: Array = OPTIES[slot]
	var i := lijst.find(_look.get(slot, &""))
	_look[slot] = lijst[posmod(i + stap, lijst.size())]
	_ververs()


func _bouw_kleuren(kol: VBoxContainer) -> void:
	kol.add_child(_kop("KLEUREN"))
	_staalrij(kol, "Shirt", &"shirt", SHIRT)
	_staalrij(kol, "Huid", &"skin", HUID)
	_staalrij(kol, "Haar", &"hair", HAAR)


func _staalrij(kol: VBoxContainer, titel: String, sleutel: StringName, kleuren: Array[Color]) -> void:
	kol.add_child(_lbl(titel, 10, Color("#8a93a8")))
	var raster := GridContainer.new()
	raster.columns = 6
	raster.add_theme_constant_override(&"h_separation", 4)
	raster.add_theme_constant_override(&"v_separation", 4)
	kol.add_child(raster)
	var knoppen := {}
	for c: Color in kleuren:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(24, 24)
		b.pressed.connect(func() -> void:
			RushKlank.ui(&"rush_knop")
			_kleuren[sleutel] = c
			_ververs())
		_in_scroll(b)
		raster.add_child(b)
		knoppen[c] = b
	_stalen[sleutel] = knoppen


# --- Foto -----------------------------------------------------------------------

## Het 32x40-plaatje is binnen. Het wordt hier een portret, en de huid- en
## haarkleur worden een voorstel: de stalen tonen meteen wat er gekozen is, en
## één tik zet het anders.
func _op_foto(klein: Image) -> void:
	_portret = RushSelfie.naar_portret(klein)
	_uit_foto = true
	_kleuren[&"skin"] = dichtstbij(RushSelfie.huidkleur(klein), HUID)
	var haar: Variant = RushSelfie.haarkleur(klein)
	if haar is Color:
		_kleuren[&"hair"] = dichtstbij(haar, HAAR.slice(0, HAAR_ECHT))
		_zeg("Huid- en haarkleur komen uit je foto. Pas ze gerust aan.")
	else:
		_zeg("Huidkleur komt uit je foto. Pas hem gerust aan.")
	_ververs()


static func dichtstbij(c: Color, uit: Array) -> Color:
	var beste: Color = uit[0]
	var afstand := INF
	for k: Color in uit:
		var d := RushSelfie.kleurafstand(c, k)
		if d < afstand:
			afstand = d
			beste = k
	return beste


func _zeg(t: String) -> void:
	_status.text = t
	_status.add_theme_color_override(&"font_color", Color("#3fd27f"))


# --- Opslaan --------------------------------------------------------------------

func _opslaan() -> void:
	var n := schoon(_naam, true)
	if n == "":
		_scroll.scroll_vertical = 0
		if _naam_veld != null:
			_naam_veld.grab_focus()
		else:
			_vraag_naam()
		if schoon(_naam, true) == "":
			_wie.text = "Kies eerst een bijnaam"
			return
		n = schoon(_naam, true)
	if not _uit_foto:
		_zeg("Eerst een foto: die komt op het scorebord.")
		_status.add_theme_color_override(&"font_color", Color("#ff8a95"))
		_scroll.scroll_vertical = 0
		return
	RushProfiel.naam = n
	RushProfiel.portret = _portret.duplicate() as Image
	RushProfiel.uit_foto = true
	if not alleen_wie:
		RushProfiel.rol = _rol
		RushProfiel.look = _look.duplicate()
		RushProfiel.kleuren = _kleuren.duplicate()
	klaar.emit(true)


## Letters (Latijns schrift, want dat heeft het pixelfont), cijfers, spatie,
## streepje en liggend streepje. `af` haalt ook spaties aan de randen weg; tijdens
## het typen nog niet, anders kun je geen tweede woord beginnen.
static func schoon(t: String, af: bool) -> String:
	var uit := ""
	for c: String in t:
		var u := c.unicode_at(0)
		var letter := c.to_upper() != c.to_lower() and u < 0x250
		if letter or c in "0123456789-_ ":
			uit += c
	while "  " in uit:
		uit = uit.replace("  ", " ")
	uit = uit.lstrip(" ")
	if af:
		uit = uit.strip_edges()
	return uit.left(RushProfiel.NAAM_MAX)


# --- Bouwstenen -----------------------------------------------------------------

## Knoppen in de scrollbak laten een sleep door, zodat je ook over een knop
## heen kunt scrollen met je duim.
func _in_scroll(c: Control) -> void:
	c.mouse_filter = Control.MOUSE_FILTER_PASS


func _dunne_balk(balk: VScrollBar) -> void:
	var spoor := StyleBoxEmpty.new()
	spoor.content_margin_left = 2
	spoor.content_margin_right = 1
	balk.add_theme_stylebox_override(&"scroll", spoor)
	for s: String in ["grabber", "grabber_highlight", "grabber_pressed"]:
		var g := StyleBoxFlat.new()
		g.bg_color = Color("#4a5677")
		balk.add_theme_stylebox_override(s, g)


func _kop(t: String) -> Control:
	var l := _lbl(t, 10, Color("#3a86ff"))
	l.custom_minimum_size = Vector2(0, 14)
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	return l


func _variantnaam(v: StringName) -> String:
	return VARIANTNAAM.get(v, String(v))


func _stijl_keuze(b: Button, gekozen: bool) -> void:
	for s: String in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("#22304f") if gekozen else Color("#1f2433")
		sb.border_color = Color("#3a86ff") if gekozen else Color("#2f3649")
		sb.set_border_width_all(2 if gekozen else 1)
		b.add_theme_stylebox_override(s, sb)
	b.add_theme_color_override(&"font_color", Color.WHITE if gekozen else Color("#b0b4c2"))


func _stijl_staal(b: Button, c: Color, gekozen: bool) -> void:
	for s: String in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = c
		sb.border_color = Color("#ffd23f") if gekozen else Color("#2f3649")
		sb.set_border_width_all(3 if gekozen else 1)
		b.add_theme_stylebox_override(s, sb)


func _lbl(t: String, maat: int, k: Color, midden: bool = false) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override(&"font", UiKit.font_voor(maat))
	l.add_theme_font_size_override(&"font_size", maat)
	l.add_theme_color_override(&"font_color", k)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if midden:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if maat <= 12:
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _knop(t: String, primair: bool) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 30)
	b.add_theme_font_override(&"font", UiKit.FONT_12)
	b.add_theme_font_size_override(&"font_size", 12)
	var kleur := Color("#3a86ff") if primair else Color("#2a3042")
	for s: String in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = kleur.lightened(0.1) if s == "hover" else (kleur.darkened(0.15) if s == "pressed" else kleur)
		sb.border_color = kleur.darkened(0.35)
		sb.set_border_width_all(1)
		b.add_theme_stylebox_override(s, sb)
	b.add_theme_color_override(&"font_color", Color.WHITE)
	b.add_theme_color_override(&"font_hover_color", Color.WHITE)
	b.add_theme_color_override(&"font_pressed_color", Color.WHITE)
	b.pressed.connect(func() -> void: RushKlank.ui(&"rush_knop"))
	return b


# --- QA -------------------------------------------------------------------------

## Alleen voor `scenes/rush/rush_profiel.tscn` vanaf de commandoregel:
## `-- --demo[=victor]` laadt een teamfoto als selfie (de GDScript-weg, want
## headless is er geen browser), `--scroll=N` scrolt voor een schermafdruk, en
## `--test` draait de pijplijntest en stopt met een exitcode.
func _qa_vlaggen() -> void:
	# Onder het menu, of als tweede scherm in de test, nooit.
	if get_parent() != get_tree().root:
		return
	klaar.connect(func(opgeslagen: bool) -> void:
		print("klaar(%s) %s" % [opgeslagen, JSON.stringify(RushProfiel.naar_dict()).left(160)]))
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--demo"):
			var wie := a.get_slice("=", 1) if "=" in a else "victor"
			_naam = wie.capitalize()
			var klein := RushSelfie.van_bestand(
				ProjectSettings.globalize_path("res://assets/personen/%s.png" % wie))
			if klein != null:
				_op_foto(klein)
			_ververs()
		elif a.begins_with("--scroll="):
			var y := int(a.get_slice("=", 1))
			# Pas na twee frames is de inhoud gemeten en kan de bak zover.
			await get_tree().process_frame
			await get_tree().process_frame
			_scroll.scroll_vertical = y
		elif a == "--test":
			var test: RefCounted = load("res://scripts/rush/rush_profiel_test.gd").new()
			get_tree().quit(test.call("draai", self))
