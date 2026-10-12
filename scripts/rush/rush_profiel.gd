class_name RushProfiel
extends RefCounted
## Een zelfgemaakt personage: bijnaam, rol, uiterlijk en een pixelportret.
##
## Leeft alleen op dit apparaat, in `RushSave`. Het portret is al 32x40 en
## teruggebracht tot het palet van het spel als het hier aankomt: een echte
## foto komt nooit in dit object, en dus ook nooit in een opslagbestand.

const ID := &"eigen"
const NAAM_MAX := 12
const PORTRET := Vector2i(32, 40)

enum Rol { DEVELOPER, DESIGN, SALES, SUPPORT, OPERATIONS, CONSULTANT }

const ROL_NAAM := {
	Rol.DEVELOPER: "Developer",
	Rol.DESIGN: "Design",
	Rol.SALES: "Sales",
	Rol.SUPPORT: "Support",
	Rol.OPERATIONS: "Operations",
	Rol.CONSULTANT: "Consultant",
}

## De vakken die je aan je eigen bureau zelf doet.
const ROL_VAKKEN := {
	Rol.DEVELOPER: [RushData.Vak.FE, RushData.Vak.BE],
	Rol.DESIGN: [RushData.Vak.FE],
	Rol.SALES: [RushData.Vak.KLANT],
	Rol.SUPPORT: [RushData.Vak.KLANT],
	Rol.OPERATIONS: [RushData.Vak.BE],
	Rol.CONSULTANT: [RushData.Vak.SCOPE],
}

## Eén regel: wat je rol je in het spel oplevert. Het spel leest de rol zelf;
## dit is alleen de uitleg op het scherm.
const ROL_VOORDEEL := {
	Rol.DEVELOPER: "Frontend én backend doe je zelf.",
	Rol.DESIGN: "Frontend doe je zelf, en collega's maken het sneller af.",
	Rol.SALES: "Als ze belt, kost het je maar 10 minuten.",
	Rol.SUPPORT: "Tickets blijven langer geduldig op het bord.",
	Rol.OPERATIONS: "Brand blus je in een tel, en dubbel deployen levert meer op.",
	Rol.CONSULTANT: "Je kapt Jonathan af zonder erheen te lopen.",
}

static var naam := ""
static var rol: Rol = Rol.DEVELOPER
## Een `CharacterSprites`-look: body, hair, facial, outfit, accessory.
static var look: Dictionary = {}
## Kleuren als Color: skin, hair, shirt, pants, accent.
static var kleuren: Dictionary = {}
## 32x40, RGBA8, al in het palet. Leeg als je nog geen portret hebt.
static var portret: Image = null


static func bestaat() -> bool:
	return naam.strip_edges() != ""


static func vakken() -> Array:
	return ROL_VAKKEN[rol]


static func frames() -> SpriteFrames:
	return CharacterSprites.frames_for(look, _kleur(&"shirt", "#3a86ff"), _kleur(&"skin", "#e0b491"),
		_kleur(&"hair", "#6b4b36"), _kleur(&"pants", "#34384e"), _kleur(&"accent", "#f4a259"))


static func portret_textuur() -> Texture2D:
	if portret == null or portret.is_empty():
		return null
	return ImageTexture.create_from_image(portret)


static func naar_dict() -> Dictionary:
	var k := {}
	for sleutel: Variant in kleuren:
		k[String(sleutel)] = (kleuren[sleutel] as Color).to_html(false)
	var l := {}
	for sleutel: Variant in look:
		l[String(sleutel)] = String(look[sleutel])
	var p := ""
	if portret != null and not portret.is_empty():
		p = Marshalls.raw_to_base64(portret.save_png_to_buffer())
	return {"naam": naam, "rol": int(rol), "look": l, "kleuren": k, "portret": p}


static func van_dict(d: Dictionary) -> void:
	naam = String(d.get("naam", "")).left(NAAM_MAX)
	rol = clampi(int(d.get("rol", 0)), 0, Rol.size() - 1) as Rol
	look = {}
	var l: Variant = d.get("look", {})
	if l is Dictionary:
		for sleutel: Variant in l:
			look[StringName(String(sleutel))] = StringName(String(l[sleutel]))
	kleuren = {}
	var k: Variant = d.get("kleuren", {})
	if k is Dictionary:
		for sleutel: Variant in k:
			kleuren[StringName(String(sleutel))] = Color.from_string(String(k[sleutel]), Color.WHITE)
	portret = null
	var p := String(d.get("portret", ""))
	if p != "":
		var img := Image.new()
		if img.load_png_from_buffer(Marshalls.base64_to_raw(p)) == OK \
				and img.get_size() == PORTRET:
			img.convert(Image.FORMAT_RGBA8)
			portret = img


static func _kleur(sleutel: StringName, standaard: String) -> Color:
	return kleuren.get(sleutel, Color(standaard))
