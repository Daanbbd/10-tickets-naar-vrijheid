class_name RushDeelkaart
extends RefCounted
## De scorekaart die je zelf in Slack zet: één plaatje met je portret, je tijd
## en een grap over hoe het ging. Er gaat niets naar een server; op een telefoon
## opent het deelmenu van het toestel, anders wordt het een download of een
## bestand in je eigen map.
##
## Alles wordt met `Image`-bewerkingen getekend, ook de tekst: de letters komen
## rechtstreeks uit de glyph-atlas van het pixelfont. Zo werkt het overal
## hetzelfde, ook headless en in de webexport, zonder SubViewport die een frame
## moet wachten (en headless niets tekent).

const B := 240
const H := 135
## Een 240x135-kaart is op een scherm een postzegel. 4x pixelscherp is 960x540:
## groot genoeg voor Slack, en elke pixel blijft een blokje.
const SCHAAL := 4

const ACHTER := Color("#141824")
const BAND := Color("#0b0e16")
const BLAUW := Color("#3a86ff")
const LICHTBLAUW := Color("#8fb3ff")
const GOUD := Color("#ffd23f")
const ZILVER := Color("#c0c8d8")
const BRONS := Color("#cd7f32")
const GRIJS := Color("#8a93a8")
const ORANJE := Color("#ff9f43")
const GRAP := Color("#f4a259")
const DONKER := Color("#2a3042")

## Een JS-callback moet ergens blijven bestaan zolang de browser hem kan
## aanroepen; een lokale variabele wordt opgeruimd en dan roept JS in het niets.
static var _js_mislukt: JavaScriptObject = null
static var _web_png := PackedByteArray()
static var _web_naam := ""


static func maak(regel: Dictionary) -> Image:
	var img := Image.create_empty(B, H, false, Image.FORMAT_RGBA8)
	img.fill(ACHTER)
	var dag := clampi(int(regel.get("dag", 0)), 0, RushData.DAGEN.size() - 1)
	var minuut := float(regel.get("minuut", RushData.EIND_MIN))
	var sterren := clampi(int(regel.get("sterren", RushData.sterren_voor(minuut))), 0, 3)
	var ontsnap := float(regel.get("ontsnap", -1.0))

	# Kopband met het logo, zoals op de kast zelf.
	img.fill_rect(Rect2i(0, 0, B, 22), BAND)
	img.fill_rect(Rect2i(0, 22, B, 1), BLAUW)
	# Het kleine woord op dezelfde basislijn als het grote, met een spatie ertussen.
	var x := 6 + _tekst(img, "10 TICKETS", Vector2i(6, 3), 16, BLAUW) + 5
	var zak := int(UiKit.font_voor(16).get_ascent(16) - UiKit.font_voor(10).get_ascent(10))
	_tekst(img, "NAAR VRIJHEID", Vector2i(x, 3 + zak), 10, LICHTBLAUW)
	var dagnaam := String(RushData.DAGEN[dag]["naam"]).to_upper()
	_tekst(img, dagnaam, Vector2i(B - 6 - _breedte(dagnaam, 10), 8), 10, GOUD)

	# Het portret, 2x, in een lijst in de kleur van de sterren.
	var lijst: Color = [DONKER, BRONS, ZILVER, GOUD][sterren]
	var p := Rect2i(8, 30, 68, 84)
	img.fill_rect(p, lijst)
	img.fill_rect(p.grow(-2), Color("#1f2433"))
	var portret := _portret(regel)
	if portret != null:
		var groot := portret.duplicate() as Image
		groot.resize(RushPixel.B * 2, RushPixel.H * 2, Image.INTERPOLATE_NEAREST)
		img.blend_rect(groot, Rect2i(Vector2i.ZERO, groot.get_size()), p.position + Vector2i(2, 2))
	else:
		_tekst(img, "?", p.position + Vector2i(28, 30), 20, GRIJS)

	# Wie, en hoe laat naar huis.
	var kx := 86
	var naam := _kort(String(regel.get("naam", "?")), 16, B - kx - 6)
	_tekst(img, naam, Vector2i(kx, 28), 16, Color.WHITE)
	var rol := _kort(String(regel.get("rol", "")), 10, B - kx - 6)
	_tekst(img, rol, Vector2i(kx, 46), 10, GRIJS)
	_tekst(img, "Naar huis om", Vector2i(kx, 62), 10, GRIJS)
	_tekst(img, RushData.klok(minuut), Vector2i(kx, 72), 20, Color.WHITE)
	var plek := _plek(regel)
	if plek > 0:
		var t := "#%d" % plek
		_tekst(img, "plek", Vector2i(B - 6 - _breedte("plek", 10), 62), 10, GRIJS)
		_tekst(img, t, Vector2i(B - 6 - _breedte(t, 20), 72), 20, GOUD if plek == 1 else LICHTBLAUW)

	# Sterren, en de ontsnapping als die er is.
	for i: int in 3:
		var m := Vector2(kx + 7 + i * 16, 104)
		_ster(img, m, 7.0, GOUD if i < sterren else DONKER)
	if ontsnap >= 0.0:
		_tekst(img, "ontsnapt in %.1f s" % ontsnap, Vector2i(kx + 50, 98), 10, ORANJE)

	# Onderaan de grap van de dag.
	img.fill_rect(Rect2i(0, H - 17, B, 1), DONKER)
	var grap := grap_voor(regel)
	_tekst(img, grap, Vector2i((B - _breedte(grap, 10)) / 2, H - 14), 10, GRAP)

	# Een rand van één pixel, zodat de kaart in Slack niet in het grijs verdwijnt.
	img.fill_rect(Rect2i(0, 0, B, 1), BLAUW)
	img.fill_rect(Rect2i(0, H - 1, B, 1), BLAUW)
	img.fill_rect(Rect2i(0, 0, 1, H), BLAUW)
	img.fill_rect(Rect2i(B - 1, 0, 1, H), BLAUW)
	return img


## Eén regel over hoe het ging. Vast per prestatie, niet willekeurig: dezelfde
## dag geeft dezelfde kaart, en dan kun je hem met een collega vergelijken.
static func grap_voor(regel: Dictionary) -> String:
	var minuut := float(regel.get("minuut", RushData.EIND_MIN))
	var sterren := int(regel.get("sterren", RushData.sterren_voor(minuut)))
	var gebeld := int(regel.get("gebeld", 0))
	var ontsnap := float(regel.get("ontsnap", -1.0))
	var dag := int(regel.get("dag", 0))
	if gebeld == 0:
		return "Ze heeft niet gebeld. Verdacht."
	if minuut <= 15 * 60:
		return "Om %s thuis. Dirk wil je uren zien." % RushData.klok(minuut)
	if gebeld >= 5:
		return "Ze belde %d keer. Haar paard ook." % gebeld
	if sterren <= 1:
		return "Het paard sliep al toen je thuiskwam."
	if ontsnap >= 0.0 and ontsnap < 12.0:
		return "Sneller buiten dan het brandalarm."
	if dag == RushData.DAGEN.size() - 1:
		return "Vrijdag live. Wat kan er misgaan?"
	if sterren == 3:
		return "Voor vijven thuis. Zo hoort het."
	return "Net na vijven. Niemand heeft het gezien."


## Maakt de kaart en geeft hem weg: op een telefoon via het deelmenu, in een
## browser zonder deelmenu als download, op een computer in je eigen map.
static func deel(regel: Dictionary) -> void:
	if regel.is_empty():
		return
	var groot := maak(regel)
	groot.resize(B * SCHAAL, H * SCHAAL, Image.INTERPOLATE_NEAREST)
	var png := groot.save_png_to_buffer()
	var dag := clampi(int(regel.get("dag", 0)), 0, RushData.DAGEN.size() - 1)
	var naam := "10-tickets-%s-%s.png" % [String(RushData.DAGEN[dag]["kort"]).to_lower(),
		RushData.klok(float(regel.get("minuut", 0.0))).replace(":", "")]
	if OS.has_feature("web"):
		_deel_web(png, naam, _deeltekst(regel))
	else:
		_bewaar_lokaal(png, naam)


static func _deeltekst(regel: Dictionary) -> String:
	var dag := clampi(int(regel.get("dag", 0)), 0, RushData.DAGEN.size() - 1)
	return "%s om %s naar huis. 10 Tickets naar Vrijheid." % [
		String(RushData.DAGEN[dag]["naam"]), RushData.klok(float(regel.get("minuut", 0.0)))]


## `navigator.share` met een bestand werkt op iOS en Android (en in sommige
## desktopbrowsers). Kan dat niet, of weigert de browser, dan een download. Wie
## het deelmenu zelf wegtikt (AbortError) krijgt géén download achteraf.
static func _deel_web(png: PackedByteArray, naam: String, tekst: String) -> void:
	var kan: Variant = JavaScriptBridge.eval("""(function () {
		try {
			return !!(navigator.canShare && navigator.share && navigator.canShare({files: [
				new File([new Uint8Array(1)], 'x.png', {type: 'image/png'})]}));
		} catch (e) { return false; }
	})()""", true)
	if not kan:
		JavaScriptBridge.download_buffer(png, naam, "image/png")
		return
	_web_png = png
	_web_naam = naam
	if _js_mislukt == null:
		_js_mislukt = JavaScriptBridge.create_callback(_web_mislukt)
	var venster := JavaScriptBridge.get_interface("window")
	venster.set("godotDeelkaartMislukt", _js_mislukt)
	JavaScriptBridge.eval("""(function (b64, naam, tekst) {
		var bin = atob(b64);
		var bytes = new Uint8Array(bin.length);
		for (var i = 0; i < bin.length; i++) { bytes[i] = bin.charCodeAt(i); }
		var file = new File([bytes], naam, {type: 'image/png'});
		navigator.share({files: [file], title: '10 Tickets naar Vrijheid', text: tekst})
			.catch(function (e) {
				if (!e || e.name !== 'AbortError') { window.godotDeelkaartMislukt(String(e && e.name)); }
			});
	})(%s, %s, %s)""" % [JSON.stringify(Marshalls.raw_to_base64(png)), JSON.stringify(naam),
		JSON.stringify(tekst)], true)


static func _web_mislukt(_args: Array) -> void:
	if not _web_png.is_empty():
		JavaScriptBridge.download_buffer(_web_png, _web_naam, "image/png")


## Op een computer: in een eigen map naast de save, en die map openen.
static func _bewaar_lokaal(png: PackedByteArray, naam: String) -> void:
	var map := "user://deelkaarten"
	DirAccess.make_dir_recursive_absolute(map)
	var pad := map.path_join(naam)
	var f := FileAccess.open(pad, FileAccess.WRITE)
	if f == null:
		push_warning("Deelkaart: kan %s niet schrijven" % pad)
		return
	f.store_buffer(png)
	f.close()
	print("Deelkaart: %s" % ProjectSettings.globalize_path(pad))
	if DisplayServer.get_name() != "headless":
		OS.shell_open(ProjectSettings.globalize_path(map))


# --- Bouwstenen -----------------------------------------------------------------

static func _portret(regel: Dictionary) -> Image:
	var img := RushPixel.van_code(String(regel.get("portret", "")))
	if img != null:
		return img
	# Zonder code (een oude regel) het portret van de collega zelf, als dat er is.
	var def: CharacterDef = GameData.character(StringName(String(regel.get("wie", ""))))
	if def != null and def.portrait != "" and ResourceLoader.exists(def.portrait):
		return RushPixel.naar_palet((load(def.portrait) as Texture2D).get_image())
	return null


## De plek op dit apparaat, of 0 als de regel er (nog) niet in staat.
static func _plek(regel: Dictionary) -> int:
	var lijst := RushSave.scores_van(int(regel.get("dag", 0)))
	for i: int in lijst.size():
		if lijst[i] == regel:
			return i + 1
	return 0


## Tekent `t` met de linkerbovenhoek op `pos`. Geeft de breedte terug.
static func _tekst(img: Image, t: String, pos: Vector2i, maat: int, kleur: Color) -> int:
	var font := UiKit.font_voor(maat)
	var sz := Vector2i(maat, 0)
	var basis := pos.y + int(font.get_ascent(maat))
	var pen := pos.x
	var atlassen := {}
	for i: int in t.length():
		var g := font.get_glyph_index(maat, t.unicode_at(i), 0)
		if g == 0:
			pen += maat / 2
			continue
		font.render_glyph(0, sz, g)
		var uv := Rect2i(font.get_glyph_uv_rect(0, sz, g))
		if uv.size.x > 0 and uv.size.y > 0:
			var ti := font.get_glyph_texture_idx(0, sz, g)
			if not atlassen.has(ti):
				atlassen[ti] = font.get_texture_image(0, sz, ti)
			var atlas: Image = atlassen[ti]
			var plek := Vector2i(pen, basis) + Vector2i(font.get_glyph_offset(0, sz, g))
			if atlas != null:
				for v: int in uv.size.y:
					for u: int in uv.size.x:
						if atlas.get_pixel(uv.position.x + u, uv.position.y + v).a < 0.5:
							continue
						var q := plek + Vector2i(u, v)
						if q.x >= 0 and q.y >= 0 and q.x < img.get_width() and q.y < img.get_height():
							img.set_pixelv(q, kleur)
		pen += int(font.get_glyph_advance(0, maat, g).x)
	return pen - pos.x


static func _breedte(t: String, maat: int) -> int:
	var font := UiKit.font_voor(maat)
	var w := 0
	for i: int in t.length():
		var g := font.get_glyph_index(maat, t.unicode_at(i), 0)
		w += maat / 2 if g == 0 else int(font.get_glyph_advance(0, maat, g).x)
	return w


## Kort `t` in tot hij in `max_b` past, met een puntje erachter.
static func _kort(t: String, maat: int, max_b: int) -> String:
	if _breedte(t, maat) <= max_b:
		return t
	while t.length() > 1 and _breedte(t + ".", maat) > max_b:
		t = t.substr(0, t.length() - 1)
	return t.strip_edges() + "."


static func _ster(img: Image, m: Vector2, r: float, k: Color) -> void:
	var pts := PackedVector2Array()
	for i: int in 10:
		var a := -PI / 2.0 + i * PI / 5.0
		pts.append(m + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
	for y: int in range(int(m.y - r) - 1, int(m.y + r) + 2):
		for x: int in range(int(m.x - r) - 1, int(m.x + r) + 2):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), pts) \
					and x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
				img.set_pixel(x, y, k)
