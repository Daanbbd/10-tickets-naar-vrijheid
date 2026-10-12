class_name RushPixel
extends RefCounted
## Het formaat van een pixelportret: 32x40 pixels uit een vast palet van 32
## kleuren, en een code van 1280 tekens die precies dat beschrijft.
##
## Dat formaat is een privacykeuze. Wat het spel opslaat of (als het online
## scorebord aanstaat) verstuurt is altijd deze code: één teken per pixel,
## `0`-`9` en `a`-`v`. Daarin past geen foto, geen metadata en geen ander
## bestand, en een server kan met één regel controleren of hij klopt.

const B := 32
const H := 40
const TEKENS := "0123456789abcdefghijklmnopqrstuv"

## Index 0 is doorzichtig. Daarna donker naar licht, met genoeg huid- en
## haartinten voor een gezicht, en de kleuren van het spel voor de rest.
const PALET: Array[Color] = [
	Color(0, 0, 0, 0),
	Color("#141824"), Color("#2a2d38"), Color("#484e60"), Color("#6b7390"),
	Color("#9aa3b8"), Color("#cfd5e2"), Color("#f4f5f7"),
	Color("#3b2418"), Color("#5a3a26"), Color("#7a5236"), Color("#9c6b45"),
	Color("#c08552"), Color("#d9a477"), Color("#ecc59c"), Color("#f7dcc0"),
	Color("#2b1d14"), Color("#c9a86a"), Color("#e8d08a"), Color("#a0522d"),
	Color("#243cec"), Color("#3a86ff"), Color("#8fb3ff"), Color("#1d7a52"),
	Color("#3fd27f"), Color("#e5484d"), Color("#ff9f43"), Color("#ffd23f"),
	Color("#a463f2"), Color("#e56fa8"), Color("#2fb67c"), Color("#7a5a3a"),
]


## Brengt een plaatje terug naar het palet (dichtstbijzijnde kleur), op 32x40.
static func naar_palet(img: Image) -> Image:
	var uit := img.duplicate() as Image
	uit.convert(Image.FORMAT_RGBA8)
	if uit.get_size() != Vector2i(B, H):
		uit.resize(B, H, Image.INTERPOLATE_BILINEAR)
	for y: int in H:
		for x: int in B:
			uit.set_pixel(x, y, PALET[dichtstbij(uit.get_pixel(x, y))])
	return uit


static func dichtstbij(c: Color) -> int:
	if c.a < 0.5:
		return 0
	var beste := 1
	var afstand := INF
	for i: int in range(1, PALET.size()):
		var p := PALET[i]
		# Gewogen naar hoe een oog verschil ziet: groen telt het zwaarst.
		var d := 0.3 * pow(c.r - p.r, 2) + 0.59 * pow(c.g - p.g, 2) + 0.11 * pow(c.b - p.b, 2)
		if d < afstand:
			afstand = d
			beste = i
	return beste


## 32x40 naar 1280 tekens. Het plaatje wordt eerst naar het palet gebracht.
static func naar_code(img: Image) -> String:
	if img == null or img.is_empty():
		return ""
	var p := naar_palet(img)
	var s := ""
	for y: int in H:
		for x: int in B:
			s += TEKENS[dichtstbij(p.get_pixel(x, y))]
	return s


## Terug naar een plaatje, of null als de code niet klopt.
static func van_code(s: String) -> Image:
	if not geldig(s):
		return null
	var img := Image.create_empty(B, H, false, Image.FORMAT_RGBA8)
	for i: int in s.length():
		img.set_pixel(i % B, i / B, PALET[TEKENS.find(s[i])])
	return img


static func geldig(s: String) -> bool:
	if s.length() != B * H:
		return false
	for i: int in s.length():
		if TEKENS.find(s[i]) < 0:
			return false
	return true
