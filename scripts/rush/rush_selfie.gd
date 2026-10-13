class_name RushSelfie
extends Node
## Van foto naar pixelportret, zonder dat de foto ergens blijft.
##
## Op web gebeurt het zware werk in de browser: een `<input type="file">` leest
## de foto, een canvas snijdt het gezicht eruit en verkleint het naar 32x40, en
## alleen die 1280 pixels (5120 bytes RGBA) komen Godot binnen. De foto zelf
## komt nooit in het geheugen van het spel, gaat niet het netwerk op en wordt
## niet bewaard: de object-URL wordt meteen ingetrokken en de canvassen worden
## leeggemaakt. Op desktop doet een bestandskiezer hetzelfde, met de verkleining
## in GDScript; die verkleining is ook wat de headless test gebruikt.
##
## Wat er daarna gebeurt is voor beide gelijk: `naar_portret()` brengt het
## plaatje naar het palet van `RushPixel`, en dat is het enige dat bewaard wordt.

## Een 32x40-plaatje, nog in echte kleuren. Nog geen portret: eerst door
## `naar_portret()`.
signal foto(klein: Image)
## De speler annuleerde, of de foto was niet te lezen.
signal geen_foto

const B := RushPixel.B
const H := RushPixel.H
## Dezelfde uitsnede als `tools/generators/gen_portraits.py`, zodat een selfie
## naast de portretten van het team niet uit de toon valt: 86% van de korte
## kant breed, vanaf 2% van boven, in de verhouding 4:5.
const UITSNEDE_BREED := 0.86
const UITSNEDE_BOVEN := 0.02
## Wat meer kleur en contrast, anders wordt een gezicht op 32x40 grauw.
## gen_portraits.py doet 1.25 verzadiging, maar kiest daarna zelf 24 kleuren;
## dit vaste palet heeft minder huidtinten, en te verzadigde huid valt dan
## eerder op een spelkleur dan op de huidtint ernaast.
const VERZADIGING := 1.1
const CONTRAST := 1.15
## Hoe zwaar kleur telt tegen helderheid bij het kiezen van een paletkleur.
const KLEUR_GEWICHT := 4.0
## De paletkleuren waaruit een foto wordt opgebouwd: grijzen, huid, haar,
## blauw en donkergroen. Feloranje, geel, roze, paars, rood en de felle groenen
## zijn er voor het spel, en in een gezicht worden het sproeten.
const FOTO_PALET: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
	16, 17, 18, 19, 20, 21, 22, 23, 31]

## De callback die de browser aanroept als de foto verwerkt is. Een veld en
## geen lokale variabele: `create_callback()` geeft een object dat opgeruimd
## wordt zodra niemand het vasthoudt, en dan komt het antwoord nooit aan.
var _js_terug: JavaScriptObject = null
var _dialoog: FileDialog = null
## Welke knoppen een browserknopje boven zich hebben: id -> {knop, camera, knip}.
var _dekken: Dictionary = {}


# --- Kiezen ---------------------------------------------------------------------

## Kan de browser een foto aanleveren?
static func op_web() -> bool:
	return OS.has_feature("web")


## Legt een onzichtbaar, echt bestandsknopje van de browser precies over
## `knop`, zodat één tik meteen de camera of de fotokiezer opent.
##
## Een browser opent een bestandskiezer alleen vanuit een echte aanraking, en
## Godot verwerkt een tik pas in zijn volgende beeld, als die aanraking al
## voorbij is. Eerder "wapende" het indrukken de browser en opende het loslaten
## de kiezer; maar dat loslaten was vaak al gebeurd voordat Godot het
## indrukken zag, en dan moest je twee keer tikken. Met een echt
## `<input type=file>` boven op de knop raakt je vinger de browser zelf.
## `knip` is de scrollbak waar de knop in zit: buiten die rand doet het
## knopje niets.
func dek(knop: Control, camera: bool, knip: Control = null) -> void:
	if not op_web() or not _installeer_js():
		return
	if _js_terug == null:
		_js_terug = JavaScriptBridge.create_callback(_op_js_foto)
	_dekken["camera" if camera else "kies"] = {"knop": knop, "camera": camera, "knip": knip}


func _process(_delta: float) -> void:
	if _dekken.is_empty():
		return
	var rs := JavaScriptBridge.get_interface("rushSelfie")
	if rs == null:
		return
	var vp := get_viewport().get_visible_rect().size
	for id: String in _dekken:
		var d: Dictionary = _dekken[id]
		var knop: Control = d["knop"]
		if not is_instance_valid(knop) or not knop.is_visible_in_tree():
			rs.call("weg", id)
			continue
		var r := knop.get_global_rect()
		var knip: Control = d["knip"]
		if knip != null and is_instance_valid(knip):
			r = r.intersection(knip.get_global_rect())
		if r.size.x < 4.0 or r.size.y < 4.0:
			rs.call("weg", id)
			continue
		rs.call("dek", id, r.position.x, r.position.y, r.size.x, r.size.y, vp.x, vp.y,
			bool(d["camera"]), _js_terug)


## Desktop: een gewone bestandskiezer. De foto wordt hier verkleind en meteen
## losgelaten; alleen het 32x40-plaatje gaat verder.
func kies_bestand() -> void:
	if op_web():
		return
	if _dialoog == null:
		_dialoog = FileDialog.new()
		_dialoog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_dialoog.access = FileDialog.ACCESS_FILESYSTEM
		_dialoog.use_native_dialog = true
		_dialoog.title = "Kies een foto"
		_dialoog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Foto's"])
		_dialoog.file_selected.connect(_op_bestand)
		_dialoog.canceled.connect(geen_foto.emit)
		add_child(_dialoog)
	_dialoog.popup_centered_ratio(0.9)


func _op_bestand(pad: String) -> void:
	var klein := van_bestand(pad)
	if klein == null:
		geen_foto.emit()
	else:
		foto.emit(klein)


func _op_js_foto(args: Array) -> void:
	var b64 := String(args[0]) if args.size() > 0 and args[0] != null else ""
	var klein := van_rgba(Marshalls.base64_to_raw(b64)) if b64 != "" else null
	if klein == null:
		geen_foto.emit()
	else:
		foto.emit(klein)


func _exit_tree() -> void:
	# Een kiezer die nog openstaat mag na dit scherm niemand meer terugroepen.
	if op_web() and JavaScriptBridge.get_interface("rushSelfie") != null:
		JavaScriptBridge.get_interface("rushSelfie").call("ruim")
	_js_terug = null


# --- De pijplijn ----------------------------------------------------------------

## Het 32x40-plaatje dat de browser stuurde, of null als het niet klopt.
static func van_rgba(bytes: PackedByteArray) -> Image:
	if bytes.size() != B * H * 4:
		return null
	return Image.create_from_data(B, H, false, Image.FORMAT_RGBA8, bytes)


## Desktop en test: een fotobestand naar 32x40. De volle foto leeft alleen in
## deze functie.
static func van_bestand(pad: String) -> Image:
	var img := Image.load_from_file(pad)
	if img == null or img.is_empty():
		return null
	return verklein(img)


## Welk stuk van een foto het portret wordt. Gespiegeld in de JavaScript
## hieronder; verander je het hier, verander het daar ook.
static func uitsnede(maat: Vector2i) -> Rect2i:
	var w := float(maat.x)
	var h := float(maat.y)
	var boven := floorf(h * UITSNEDE_BOVEN)
	var breed := minf(w, h) * UITSNEDE_BREED
	# Past 4:5 er niet in (een liggende of vierkante foto), dan smaller in
	# plaats van platgedrukt: een gerekt gezicht herken je niet.
	breed = minf(breed, (h - boven) * B / H)
	var hoog := breed * H / B
	return Rect2i(int((w - breed) / 2.0), int(boven), maxi(1, int(breed)), maxi(1, int(hoog)))


## Uitsnijden en in stappen halveren tot 32x40. Eén grote sprong laat pixels
## vallen in plaats van ze te middelen, en dan knippert het portret van ruis.
static func verklein(img: Image) -> Image:
	var uit := img.get_region(uitsnede(img.get_size()))
	uit.convert(Image.FORMAT_RGBA8)
	while uit.get_width() >= B * 4:
		uit.resize(uit.get_width() / 2, uit.get_height() / 2, Image.INTERPOLATE_BILINEAR)
	uit.resize(B, H, Image.INTERPOLATE_LANCZOS)
	return uit


## Van verkleinde foto naar het portret dat bewaard mag worden.
static func naar_portret(klein: Image) -> Image:
	return RushPixel.naar_palet(kwantiseer(verfraai(klein)))


## Elke pixel naar de paletkleur die er voor het oog het dichtst bij ligt.
##
## `RushPixel.naar_palet()` meet in RGB met groen zwaar gewogen. Voor de
## kleuren van het spel is dat prima, maar een huidtint ligt daar soms dichter
## bij feloranje dan bij de huidtint ernaast, en dan krijgt een gezicht
## sproeten van oranje. In OKLab is afstand wat je ziet. Het resultaat bestaat
## al uit paletkleuren, dus `naar_palet()` laat het daarna zoals het is.
static func kwantiseer(img: Image) -> Image:
	var lab: Array[Vector3] = []
	for i: int in FOTO_PALET:
		lab.append(_oklab(RushPixel.PALET[i]))
	var uit := img.duplicate() as Image
	for y: int in uit.get_height():
		for x: int in uit.get_width():
			var c := uit.get_pixel(x, y)
			if c.a < 0.5:
				continue
			var l := _oklab(c)
			var beste := 0
			var afstand := INF
			for i: int in lab.size():
				# Kleur telt dubbel: anders kiest een grijze muur of een zwart
				# shirt een bruin dat even licht is, en krijgt het vlekken.
				var v := l - lab[i]
				var d := v.x * v.x + KLEUR_GEWICHT * (v.y * v.y + v.z * v.z)
				if d < afstand:
					afstand = d
					beste = i
			uit.set_pixel(x, y, RushPixel.PALET[FOTO_PALET[beste]])
	return uit


## sRGB naar OKLab (Björn Ottosson, 2020).
static func _oklab(c: Color) -> Vector3:
	var r := _lineair(c.r)
	var g := _lineair(c.g)
	var b := _lineair(c.b)
	var l := pow(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b, 1.0 / 3.0)
	var m := pow(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b, 1.0 / 3.0)
	var s := pow(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b, 1.0 / 3.0)
	return Vector3(
		0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
		1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
		0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)


static func _lineair(v: float) -> float:
	return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)


## Verzadiging en contrast zoals `ImageEnhance` in gen_portraits.py. Ook ondoorzichtig
## maken: een PNG met een gat zou anders een gat in je gezicht worden.
static func verfraai(klein: Image) -> Image:
	var data := klein.get_data()
	var n := data.size() / 4
	var gem := 0.0
	for i: int in n:
		gem += _luma(data, i * 4)
	gem /= maxf(1.0, n)
	for i: int in n:
		var p := i * 4
		var l := _luma(data, p)
		for c: int in 3:
			var v := float(data[p + c])
			v = l + (v - l) * VERZADIGING
			v = gem + (v - gem) * CONTRAST
			data[p + c] = clampi(roundi(v), 0, 255)
		data[p + 3] = 255
	return Image.create_from_data(B, H, false, Image.FORMAT_RGBA8, data)


static func _luma(data: PackedByteArray, p: int) -> float:
	return 0.299 * data[p] + 0.587 * data[p + 1] + 0.114 * data[p + 2]


# --- Kleuren uit de selfie ------------------------------------------------------

## De huid: het middenvlak van het gezicht, maar alleen de lichtere helft
## zonder de felste pixels. Zo vallen baard, wenkbrauwen, ogen en schaduw
## eruit, en glimlicht en tanden ook.
static func huidkleur(klein: Image) -> Color:
	var px: Array[Color] = []
	for y: int in range(12, 27):
		for x: int in range(9, 23):
			px.append(klein.get_pixel(x, y))
	px.sort_custom(func(a: Color, b: Color) -> bool: return a.get_luminance() < b.get_luminance())
	return _mediaan(px.slice(px.size() / 2, px.size() * 9 / 10))


## Het haar: vanaf het gezicht omhoog tot de huid ophoudt; de paar pixels
## daarboven zijn haar. Van bovenaf zoeken gaat mis op een donker plafond of
## een lamp in beeld. Wat op de achtergrond van dezelfde rij lijkt telt niet,
## dus een kaal hoofd tegen een muur geeft te weinig, en dan is er geen
## voorstel (null).
static func haarkleur(klein: Image) -> Variant:
	var huid := huidkleur(klein)
	var midden := _gezichtsmidden(klein, huid)
	var px: Array[Color] = []
	for x: int in range(midden - 4, midden + 4):
		var top := -1
		for y: int in range(24, -1, -1):
			if _is_huid(klein.get_pixel(x, y), huid):
				top = y
			elif top >= 0 and y < top - 3:
				break
		for dy: int in range(1, 4):
			var y := top - dy
			if top < 0 or y < 0:
				break
			var c := klein.get_pixel(x, y)
			if not _is_huid(c, huid) and kleurafstand(c, _rand(klein, y)) > 0.06:
				px.append(c)
	if px.size() < 6:
		return null
	return _mediaan(px)


## Waar het gezicht staat: het gemiddelde van de huidpixels, want niet elke
## selfie is netjes gecentreerd.
static func _gezichtsmidden(klein: Image, huid: Color) -> int:
	var som := 0
	var n := 0
	for y: int in range(10, 25):
		for x: int in range(4, B - 4):
			if _is_huid(klein.get_pixel(x, y), huid):
				som += x
				n += 1
	return clampi(som / n, 8, B - 9) if n > 0 else B / 2


static func _is_huid(c: Color, huid: Color) -> bool:
	return kleurafstand(c, huid) < 0.12


## De achtergrond op rij y: de buitenste pixels links en rechts.
static func _rand(klein: Image, y: int) -> Color:
	var px: Array[Color] = []
	for x: int in [0, 1, B - 2, B - 1]:
		px.append(klein.get_pixel(x, y))
	return _mediaan(px)


## Hoe verschillend twee kleuren eruitzien: afstand in OKLab.
static func kleurafstand(a: Color, b: Color) -> float:
	return _oklab(a).distance_to(_oklab(b))


## Per kanaal de mediaan: één glimlicht of schaduw trekt hem niet scheef.
static func _mediaan(px: Array[Color]) -> Color:
	if px.is_empty():
		return Color.GRAY
	var r: Array[float] = []
	var g: Array[float] = []
	var b: Array[float] = []
	for c: Color in px:
		r.append(c.r)
		g.append(c.g)
		b.append(c.b)
	r.sort()
	g.sort()
	b.sort()
	var m := px.size() / 2
	return Color(r[m], g[m], b[m])


# --- Zonder foto ----------------------------------------------------------------

## Een portret van je eigen poppetje: het hoofd en de schouders uit het eerste
## `idle_down`-frame, twee keer zo groot. Het poppetje is 16 breed en een
## portret 32, dus 2x past precies en blijft pixelscherp.
static func van_figuur(frames: SpriteFrames, achtergrond: Color) -> Image:
	var uit := Image.create_empty(B, H, false, Image.FORMAT_RGBA8)
	uit.fill(achtergrond)
	var at := frames.get_frame_texture(&"idle_down", 0) as AtlasTexture
	if at == null or at.atlas == null:
		return RushPixel.naar_palet(uit)
	var frame := at.atlas.get_image().get_region(Rect2i(at.region))
	frame.convert(Image.FORMAT_RGBA8)
	# Het frame heeft 1 px marge rondom; het hoofd begint op de bovenste rij.
	var hoofd := frame.get_region(Rect2i(1, 0, 16, 19))
	hoofd.resize(32, 38, Image.INTERPOLATE_NEAREST)
	uit.blend_rect(hoofd, Rect2i(0, 0, 32, 38), Vector2i(0, 3))
	return RushPixel.naar_palet(uit)


# --- De browserkant -------------------------------------------------------------

## Eén keer per pagina. Geeft false als er geen JavaScript is (een export
## zonder JavaScriptBridge).
static func _installeer_js() -> bool:
	var js := JS.replace("__B__", str(B)).replace("__H__", str(H)) \
		.replace("__BREED__", str(UITSNEDE_BREED)).replace("__BOVEN__", str(UITSNEDE_BOVEN))
	JavaScriptBridge.eval(js, true)
	return JavaScriptBridge.get_interface("rushSelfie") != null


## Alles in de browser. Bewust zonder `fetch`, `XMLHttpRequest` of iets dat een
## adres krijgt: de foto gaat van het bestand naar een object-URL (alleen in
## dit tabblad geldig), naar een canvas, en als 32x40 naar Godot. Daarna wordt
## alles losgelaten.
const JS := """
(function () {
	if (window.rushSelfie) { return; }
	var B = __B__, H = __H__, BREED = __BREED__, BOVEN = __BOVEN__;
	var st = { terug: null, knoppen: {} };

	function klaar(b64) {
		var t = st.terug;
		if (t) { t(b64); }
	}

	function leeg(c) { c.width = 0; c.height = 0; }

	// Gespiegeld van RushSelfie.uitsnede().
	function uitsnede(w, h) {
		var boven = Math.floor(h * BOVEN);
		var breed = Math.min(w, h) * BREED;
		breed = Math.min(breed, (h - boven) * B / H);
		return { x: Math.floor((w - breed) / 2), y: boven, w: Math.max(1, Math.floor(breed)), h: Math.max(1, Math.floor(breed * H / B)) };
	}

	function canvas(w, h) {
		var c = document.createElement('canvas');
		c.width = w; c.height = h;
		var ctx = c.getContext('2d');
		ctx.imageSmoothingEnabled = true;
		ctx.imageSmoothingQuality = 'high';
		return c;
	}

	// Eerst naar het grootste veelvoud van 32x40 dat in de uitsnede past (maximaal
	// 1024 breed, ruim onder de canvasgrens van iOS), daarna steeds halveren.
	function verklein(img) {
		var u = uitsnede(img.naturalWidth, img.naturalHeight);
		var w = B;
		while (w * 2 <= u.w && w * 2 <= 1024) { w *= 2; }
		var c = canvas(w, w * H / B);
		c.getContext('2d').drawImage(img, u.x, u.y, u.w, u.h, 0, 0, c.width, c.height);
		while (c.width > B) {
			var k = canvas(c.width / 2, c.height / 2);
			k.getContext('2d').drawImage(c, 0, 0, k.width, k.height);
			leeg(c);
			c = k;
		}
		var d = c.getContext('2d').getImageData(0, 0, B, H).data;
		leeg(c);
		var s = '';
		for (var n = 0; n < d.length; n++) { s += String.fromCharCode(d[n]); }
		return btoa(s);
	}

	function lees(bestand) {
		var url = URL.createObjectURL(bestand);
		var img = new Image();
		function af(b64) {
			URL.revokeObjectURL(url);
			img.onload = null;
			img.onerror = null;
			img.removeAttribute('src');
			klaar(b64);
		}
		img.onload = function () {
			var b64 = '';
			try { b64 = verklein(img); } catch (e) { b64 = ''; }
			af(b64);
		};
		img.onerror = function () { af(''); };
		img.src = url;
	}

	// Per knop een echt bestandsknopje, onzichtbaar boven op de plek van de
	// Godot-knop. Een tik erop is een echte aanraking, dus de kiezer opent meteen.
	function maak(camera) {
		var i = document.createElement('input');
		i.type = 'file';
		i.accept = 'image/*';
		if (camera) { i.setAttribute('capture', 'user'); }
		var s = i.style;
		s.position = 'fixed'; s.opacity = '0'; s.zIndex = '2147483000';
		s.margin = '0'; s.padding = '0'; s.border = '0'; s.cursor = 'pointer';
		s.fontSize = '16px'; s.display = 'none';
		i.onchange = function () {
			var f = i.files && i.files[0];
			if (f) { lees(f); } else { klaar(''); }
			// Leeg, zodat dezelfde foto nog eens kiezen ook een change geeft.
			try { i.value = ''; } catch (e) {}
		};
		document.body.appendChild(i);
		return i;
	}

	window.rushSelfie = {
		dek: function (id, x, y, w, h, vw, vh, camera, terug) {
			st.terug = terug;
			var i = st.knoppen[id];
			if (!i) { i = maak(camera); st.knoppen[id] = i; }
			var c = document.getElementById('canvas') || document.querySelector('canvas');
			if (!c) { return; }
			var r = c.getBoundingClientRect();
			var sx = r.width / vw, sy = r.height / vh;
			i.style.left = (r.left + x * sx) + 'px';
			i.style.top = (r.top + y * sy) + 'px';
			i.style.width = (w * sx) + 'px';
			i.style.height = (h * sy) + 'px';
			i.style.display = 'block';
		},
		weg: function (id) {
			var i = st.knoppen[id];
			if (i) { i.style.display = 'none'; }
		},
		ruim: function () {
			for (var id in st.knoppen) {
				var i = st.knoppen[id];
				i.onchange = null;
				if (i.parentNode) { i.parentNode.removeChild(i); }
			}
			st.knoppen = {};
			st.terug = null;
		}
	};
})();
"""
