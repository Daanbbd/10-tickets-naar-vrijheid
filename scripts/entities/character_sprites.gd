class_name CharacterSprites
extends RefCounted
## Stelt personage-SpriteFrames samen uit losse laag-sheets en herkleurt ze.
##
## Zes lagen (body, hair_back, outfit, hair, facial, accessory) worden over
## elkaar geplakt en daarna in een keer herkleurd. Zo krijgt elke collega een
## eigen silhouet zonder dat er per persoon een spritesheet bestaat.
##
## De cache staat op de look-combinatie, niet op het personage-id: `daan` en
## `npc_daan` zijn dezelfde persoon en delen dus een textuur.

const LAAG_PAD := "res://assets/sprites/characters/%s_%s.png"
const FW := 18          # 16 px personage + 1 px marge rondom, voor de outline
const FH := 34
const COLS := 12
const DIRS: Array[String] = ["down", "up", "left", "right"]

## Tekenvolgorde. hair_back moet voor body, anders valt lang haar over het
## gezicht in plaats van erachter.
const VOLGORDE: Array[StringName] = [
	&"hair_back", &"body", &"outfit", &"hair", &"facial", &"accessory",
	&"bezigheid",
]
## Alleen deze haarstijlen hebben een achterkant.
const MET_ACHTERHAAR: Array[StringName] = [&"lang", &"staart", &"knot"]

const STANDAARD_LOOK := {
	&"body": &"gemiddeld", &"outfit": &"tshirt", &"hair": &"kort",
	&"facial": &"", &"accessory": &"", &"bezigheid": &"",
}

## Oud `sheet`-veld -> look, zodat data die nog niet gemigreerd is blijft werken.
const LEGACY_LOOKS := {
	&"plain":   {&"body": &"gemiddeld", &"outfit": &"tshirt",   &"hair": &"kort"},
	&"beard":   {&"body": &"gemiddeld", &"outfit": &"overhemd", &"hair": &"kort", &"facial": &"baard"},
	&"glasses": {&"body": &"stevig",    &"outfit": &"trui",     &"hair": &"kort", &"accessory": &"bril"},
	&"curly":   {&"body": &"gemiddeld", &"outfit": &"tshirt",   &"hair": &"krullen", &"facial": &"baard"},
	&"long":    {&"body": &"stevig",    &"outfit": &"blouse",   &"hair": &"lang"},
	&"hoodie":  {&"body": &"slank",     &"outfit": &"hoodie",   &"hair": &"stekels"},
	&"buttons": {&"body": &"gemiddeld", &"outfit": &"blazer",   &"hair": &"zijscheiding"},
}

# sleutelkleuren in de laag-sheets, als 0xRRGGBB
const K_SKIN     := 0xff0000
const K_SKIN_S   := 0xaa0000
const K_HAIR     := 0x00ff00
const K_HAIR_S   := 0x00aa00
const K_SHIRT    := 0x0000ff
const K_SHIRT_S  := 0x0000aa
const K_PANTS    := 0xff00ff
const K_PANTS_S  := 0xaa00aa
const K_ACCENT   := 0x00ffff
const K_ACCENT_S := 0x00aaaa

static var _cache: Dictionary = {}      ## look-sleutel -> SpriteFrames
static var _lagen: Dictionary = {}      ## pad -> Image
static var _static_cache: Dictionary = {}   ## pad -> SpriteFrames


## Vult ontbrekende sleutels aan en accepteert nog het oude `sheet`-veld.
static func normaliseer_look(look: Dictionary, sheet: StringName = &"") -> Dictionary:
	var uit := STANDAARD_LOOK.duplicate()
	if look.is_empty() and sheet != &"" and LEGACY_LOOKS.has(sheet):
		for k: StringName in LEGACY_LOOKS[sheet]:
			uit[k] = LEGACY_LOOKS[sheet][k]
	for k: Variant in look:
		var sleutel := StringName(k)
		if uit.has(sleutel):
			uit[sleutel] = StringName(look[k])
	return uit


## Voor een "collega" zonder personagelagen: één los sprite-bestand
## (`res://assets/sprites/props/paard_bug.png` en dergelijke) in plaats van het
## gelaagde silhouet. Geen richting, geen loop-animatie — een paard in dit
## spel deint, het rent niet — dus elke animatienaam die `npc.gd` opvraagt
## krijgt hetzelfde ene beeld. Dat is precies genoeg: `_animate()` wisselt van
## animatie op basis van richting en beweging, en ziet hier telkens hetzelfde.
static func static_frames(path: String) -> SpriteFrames:
	if _static_cache.has(path):
		return _static_cache[path] as SpriteFrames

	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	var sf := SpriteFrames.new()
	sf.remove_animation(&"default")
	for dir: String in DIRS:
		for voorvoegsel: String in ["idle_", "walk_", "talk_"]:
			var anim := StringName(voorvoegsel + dir)
			sf.add_animation(anim)
			sf.set_animation_loop(anim, true)
			if tex != null:
				sf.add_frame(anim, tex)
	sf.add_animation(&"bezig_down")
	sf.set_animation_loop(&"bezig_down", false)
	if tex != null:
		sf.add_frame(&"bezig_down", tex)

	_static_cache[path] = sf
	return sf


static func frames_for(look: Dictionary, shirt: Color, skin: Color, hair: Color,
		pants: Color, accent: Color) -> SpriteFrames:
	var sleutel := "%s|%s|%s|%s|%s|%s" % [
		_looksleutel(look), shirt.to_html(false), skin.to_html(false),
		hair.to_html(false), pants.to_html(false), accent.to_html(false)]
	if _cache.has(sleutel):
		return _cache[sleutel] as SpriteFrames

	var tex := ImageTexture.create_from_image(
		_herkleur(_composiet(look), shirt, skin, hair, pants, accent))
	var sf := SpriteFrames.new()
	sf.remove_animation(&"default")

	for rij: int in DIRS.size():
		var dir := DIRS[rij]

		# Idle is geen stilstaand plaatje: ademen en knipperen maken het verschil
		# tussen een vloer vol mensen en een wassenbeeldenmuseum. Van achteren
		# zie je geen ogen, dus daar vervalt het knipperframe.
		var idle := StringName("idle_" + dir)
		sf.add_animation(idle)
		sf.set_animation_loop(idle, true)
		sf.set_animation_speed(idle, 2.0)
		sf.add_frame(idle, _regio(tex, 0, rij), 4.0)
		sf.add_frame(idle, _regio(tex, 1, rij), 2.0)
		sf.add_frame(idle, _regio(tex, 0, rij), 3.0)
		sf.add_frame(idle, _regio(tex, 2 if rij != 1 else 0, rij), 0.35)

		var loop := StringName("walk_" + dir)
		sf.add_animation(loop)
		sf.set_animation_loop(loop, true)
		sf.set_animation_speed(loop, 9.0)
		for col: int in range(3, 7):
			sf.add_frame(loop, _regio(tex, col, rij))

		# De bezigheid staat alleen in rij `down`: hij speelt op het
		# selectiescherm, waar het personage je aankijkt. In de andere rijen zijn
		# die kolommen leeg, dus daar heeft de animatie geen zin.
		if rij == 0:
			sf.add_animation(&"bezig_down")
			sf.set_animation_loop(&"bezig_down", false)
			sf.set_animation_speed(&"bezig_down", 6.0)
			for col: int in range(8, COLS):
				sf.add_frame(&"bezig_down", _regio(tex, col, rij))

		var praat := StringName("talk_" + dir)
		sf.add_animation(praat)
		sf.set_animation_loop(praat, true)
		sf.set_animation_speed(praat, 6.0)
		sf.add_frame(praat, _regio(tex, 7, rij))
		sf.add_frame(praat, _regio(tex, 0, rij))

	_cache[sleutel] = sf
	return sf


static func _looksleutel(look: Dictionary) -> String:
	var d := ""
	for slot: StringName in VOLGORDE:
		d += "%s," % look.get(slot, &"")
	return d


## Plakt de lagen op elkaar. blend_rect is native, dus dit kost geen GDScript-lus.
static func _composiet(look: Dictionary) -> Image:
	var uit := Image.create_empty(FW * COLS, FH * DIRS.size(), false, Image.FORMAT_RGBA8)
	var rect := Rect2i(0, 0, FW * COLS, FH * DIRS.size())
	for slot: StringName in VOLGORDE:
		var variant: StringName = look.get(
			&"hair" if slot == &"hair_back" else slot, &"")
		if slot == &"hair_back" and not (variant in MET_ACHTERHAAR):
			continue
		if variant == &"":
			continue
		var img := _laag(slot, variant)
		if img != null:
			uit.blend_rect(img, rect, Vector2i.ZERO)
	return uit


static func _laag(slot: StringName, variant: StringName) -> Image:
	var pad := LAAG_PAD % [slot, variant]
	if _lagen.has(pad):
		return _lagen[pad] as Image
	if not ResourceLoader.exists(pad):
		push_warning("CharacterSprites: laag '%s' bestaat niet" % pad)
		_lagen[pad] = null
		return null
	var img := (load(pad) as Texture2D).get_image()
	img.convert(Image.FORMAT_RGBA8)
	_lagen[pad] = img
	return img


## Vervangt de tien sleutelkleuren in een keer.
##
## Bewust op de rauwe PackedByteArray en niet met get_pixel/set_pixel: die
## hebben per aanroep zoveel overhead dat een sheet van 144x136 merkbaar hapert,
## en in de web-export is de CPU trager.
static func _herkleur(img: Image, shirt: Color, skin: Color, hair: Color,
		pants: Color, accent: Color) -> Image:
	var kaart := {
		K_SKIN: skin,     K_SKIN_S: skin.darkened(0.28),
		K_HAIR: hair,     K_HAIR_S: hair.darkened(0.25),
		K_SHIRT: shirt,   K_SHIRT_S: shirt.darkened(0.30),
		K_PANTS: pants,   K_PANTS_S: pants.darkened(0.30),
		K_ACCENT: accent, K_ACCENT_S: accent.darkened(0.30),
	}
	# vooraf naar bytes, zodat de lus zelf geen Color meer aanraakt
	var bytes := {}
	for k: int in kaart:
		var c: Color = kaart[k]
		bytes[k] = PackedByteArray([c.r8, c.g8, c.b8])

	var data := img.get_data()
	var n := data.size()
	var i := 0
	while i < n:
		if data[i + 3] != 0:
			var sleutel := (data[i] << 16) | (data[i + 1] << 8) | data[i + 2]
			if bytes.has(sleutel):
				var b: PackedByteArray = bytes[sleutel]
				data[i] = b[0]
				data[i + 1] = b[1]
				data[i + 2] = b[2]
		i += 4
	return Image.create_from_data(img.get_width(), img.get_height(), false,
		Image.FORMAT_RGBA8, data)


static func _regio(tex: Texture2D, col: int, rij: int) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(col * FW, rij * FH, FW, FH)
	return at
