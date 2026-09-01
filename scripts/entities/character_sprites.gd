class_name CharacterSprites
extends RefCounted
## Bouwt SpriteFrames uit het herkleurbare personage-template.
## Eén sheet, per personage een palette swap. Resultaten worden gecachet.

const SHEET_DIR := "res://assets/sprites/characters/person_%s.png"
const FW := 16
const FH := 24
const COLS := 5
const DIRS: Array[String] = ["down", "up", "left", "right"]

# sleutelkleuren in het template
const KEY_SKIN   := Color8(255, 0, 0)
const KEY_SKIN_S := Color8(170, 0, 0)
const KEY_HAIR   := Color8(0, 255, 0)
const KEY_HAIR_S := Color8(0, 170, 0)
const KEY_SHIRT  := Color8(0, 0, 255)
const KEY_SHIRT_S:= Color8(0, 0, 170)

static var _cache: Dictionary = {}
static var _templates: Dictionary = {}


static func frames_for(id: StringName, shirt: Color, skin: Color, hair: Color,
		sheet: StringName = &"plain") -> SpriteFrames:
	if _cache.has(id):
		return _cache[id] as SpriteFrames

	var tex := _recolored_texture(shirt, skin, hair, sheet)
	var sf := SpriteFrames.new()
	sf.remove_animation("default")

	for row: int in DIRS.size():
		var dir := DIRS[row]

		sf.add_animation(StringName("idle_" + dir))
		sf.set_animation_loop(StringName("idle_" + dir), true)
		sf.set_animation_speed(StringName("idle_" + dir), 1.0)
		sf.add_frame(StringName("idle_" + dir), _region(tex, 0, row))

		sf.add_animation(StringName("walk_" + dir))
		sf.set_animation_loop(StringName("walk_" + dir), true)
		sf.set_animation_speed(StringName("walk_" + dir), 9.0)
		for col: int in range(1, COLS):
			sf.add_frame(StringName("walk_" + dir), _region(tex, col, row))

	_cache[id] = sf
	return sf


static func _region(tex: Texture2D, col: int, row: int) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(col * FW, row * FH, FW, FH)
	return at


static func _recolored_texture(shirt: Color, skin: Color, hair: Color, sheet: StringName) -> ImageTexture:
	var img := _load_template(sheet).duplicate() as Image
	var mapping := {
		KEY_SKIN:    skin,
		KEY_SKIN_S:  skin.darkened(0.28),
		KEY_HAIR:    hair,
		KEY_HAIR_S:  hair.darkened(0.25),
		KEY_SHIRT:   shirt,
		KEY_SHIRT_S: shirt.darkened(0.3),
	}
	for y: int in img.get_height():
		for x: int in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a < 0.5:
				continue
			for key: Color in mapping.keys():
				if _same(c, key):
					img.set_pixel(x, y, Color(mapping[key], c.a))
					break
	return ImageTexture.create_from_image(img)


static func _same(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.02 and absf(a.g - b.g) < 0.02 and absf(a.b - b.b) < 0.02


static func _load_template(sheet: StringName) -> Image:
	if not _templates.has(sheet):
		var path := SHEET_DIR % sheet
		if not ResourceLoader.exists(path):
			push_warning("CharacterSprites: sheet '%s' bestaat niet, val terug op plain" % sheet)
			path = SHEET_DIR % "plain"
		var t: Texture2D = load(path)
		var img := t.get_image()
		img.convert(Image.FORMAT_RGBA8)
		_templates[sheet] = img
	return _templates[sheet] as Image
