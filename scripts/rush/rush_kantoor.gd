class_name RushKantoor
extends Node2D
## De vloer: één scherm Bluebird Day, 12 bij 22 tegels. Tekent de vaste
## inrichting en weet waar alles staat; het spel zet er de mensen op.

const T := 16
const KOLOMMEN := 12
const RIJEN := 22
const BREED := KOLOMMEN * T
const HOOG := RIJEN * T
## Eerste en laatste looprij.
const VLOER_BOVEN := 3
const VLOER_ONDER := 20

const ATLAS := preload("res://assets/tilesets/office_atlas.png")
const SERVER := preload("res://assets/sprites/props/serverrack_2x4.png")
const PLANT_TEGEL := 20

## Bureaus: middelpunt x en de voorkant y. Drie, drie, één.
const BUREAUS: Array[Vector2] = [
	Vector2(32, 96), Vector2(96, 96), Vector2(160, 96),
	Vector2(32, 160), Vector2(96, 160), Vector2(160, 160),
	Vector2(32, 224),
]

const BORD_RECT := Rect2(20, 5, 152, 40)
const BORD_SLOTS := 6
const KOFFIE_RECT := Rect2(146, 192, 28, 30)
const SERVER_RECT := Rect2(144, 248, 32, 72)
const DEUR_RECT := Rect2(16, 336, 32, 16)
const PLANT_RECT := Rect2(80, 196, 32, 26)

var brand := false
var koffie_klaar := true
var deur_open := false
var _tijd := 0.0
var _server_flits := 0.0


func slot_positie(i: int) -> Vector2:
	return Vector2(BORD_RECT.position.x + 18 + i * 23, BORD_RECT.position.y + 22)


func slot_benader(i: int) -> Vector2:
	return Vector2(slot_positie(i).x, VLOER_BOVEN * T + 10)


func koffie_benader() -> Vector2:
	return Vector2(KOFFIE_RECT.get_center().x, 232)


func server_benader() -> Vector2:
	return Vector2(SERVER_RECT.get_center().x, 330)


func deur_punt() -> Vector2:
	return Vector2(DEUR_RECT.get_center().x, 330)


func flits_server() -> void:
	_server_flits = 1.0


## Welke tegels niet te belopen zijn.
func blokkades() -> Array[Rect2i]:
	var uit: Array[Rect2i] = []
	for b: Vector2 in BUREAUS:
		var c := int(b.x / T) - 1
		var r := int(b.y / T) - 2
		uit.append(Rect2i(c, r, 2, 2))
	uit.append(Rect2i(9, 12, 2, 2))   # koffie
	uit.append(Rect2i(5, 12, 2, 2))   # plant
	uit.append(Rect2i(9, 16, 2, 4))   # server
	uit.append(Rect2i(0, 16, 3, 2))   # bank
	return uit


func _process(delta: float) -> void:
	_tijd += delta
	_server_flits = maxf(0.0, _server_flits - delta * 2.0)
	queue_redraw()


func _draw() -> void:
	_vloer()
	_muren()
	_bord()
	_koffie()
	_plant()
	_server()


func _tegel(idx: int, p: Vector2) -> void:
	draw_texture_rect_region(ATLAS, Rect2(p, Vector2(T, T)), Rect2(idx * T, 0, T, T))


func _vloer() -> void:
	for y: int in range(VLOER_BOVEN, VLOER_ONDER + 1):
		for x: int in KOLOMMEN:
			var v := absi((x * 73856093) ^ (y * 19349663)) % 3
			_tegel([0, 47, 48][v], Vector2(x * T, y * T))
	# Het blauwe kleed van Bluebird Day, met de vogel erop.
	var kleed := Rect2(54, 252, 80, 64)
	draw_rect(kleed, Color("#2f4fd6", 0.22))
	draw_rect(kleed.grow(-3), Color("#2f4fd6", 0.12))
	draw_rect(kleed, Color("#243cec", 0.35), false, 1.0)
	_vogel(kleed.get_center() + Vector2(0, -6), Color("#243cec", 0.35))
	_kleine_tekst("BLUEBIRD DAY", kleed.get_center() + Vector2(-27, 18), Color("#243cec", 0.4))
	# Lounge linksonder: bank en een plant, waar niemand ooit zit.
	draw_rect(Rect2(6, 262, 34, 6), Color("#3a4a6a"))
	draw_rect(Rect2(6, 268, 34, 10), Color("#4c6190"))
	draw_rect(Rect2(4, 264, 4, 14), Color("#3a4a6a"))
	draw_rect(Rect2(38, 264, 4, 14), Color("#3a4a6a"))
	draw_rect(Rect2(6, 278, 36, 2), Color(0, 0, 0, 0.2))
	_tegel(PLANT_TEGEL, Vector2(2, 296))
	_tegel(PLANT_TEGEL, Vector2(174, 52))


func _muren() -> void:
	# Achterwand met plint.
	draw_rect(Rect2(0, 0, BREED, 3 * T), Color("#59617a"))
	draw_rect(Rect2(0, 0, BREED, 3), Color("#3d4356"))
	draw_rect(Rect2(0, 3 * T - 3, BREED, 3), Color("#2f3442"))
	# Ramen links en rechts van het bord.
	for x: float in [4.0, 176.0]:
		draw_rect(Rect2(x, 8, 12, 26), Color("#8fb7d9"))
		draw_rect(Rect2(x, 8, 12, 26), Color("#2f3442"), false, 1.0)
		draw_line(Vector2(x + 6, 8), Vector2(x + 6, 34), Color("#2f3442"))
	# Onderwand met de uitgang.
	draw_rect(Rect2(0, HOOG - T, BREED, T), Color("#3d4356"))
	draw_rect(Rect2(0, HOOG - T, BREED, 2), Color("#2f3442"))
	var d := DEUR_RECT
	if deur_open:
		draw_rect(d, Color("#bfe3a8"))
		draw_rect(Rect2(d.position, Vector2(d.size.x, 4)), Color("#ffffff", 0.6))
	else:
		draw_rect(d, Color("#7a5a3a"))
		draw_rect(Rect2(d.position + Vector2(d.size.x / 2.0 - 1, 0), Vector2(2, d.size.y)), Color("#5a3f28"))
	draw_rect(Rect2(d.position.x + 4, d.position.y + 5, 24, 6), Color("#1d7a52"))
	_kleine_tekst("UIT", Vector2(d.position.x + 9, d.position.y + 10), Color.WHITE)
	# Zijkanten.
	draw_rect(Rect2(0, 0, 1, HOOG), Color("#2f3442"))
	draw_rect(Rect2(BREED - 1, 0, 1, HOOG), Color("#2f3442"))


func _bord() -> void:
	var r := BORD_RECT
	draw_rect(Rect2(r.position + Vector2(1, 2), r.size), Color(0, 0, 0, 0.3))
	draw_rect(r, Color("#c9ccd4"))
	draw_rect(r.grow(-2), Color("#f4f5f7"))
	draw_rect(Rect2(r.position.x + 2, r.position.y + 2, r.size.x - 4, 8), Color("#243cec"))
	_kleine_tekst("SPRINT 14  ·  TO DO", Vector2(r.position.x + 6, r.position.y + 9), Color.WHITE)
	for i: int in BORD_SLOTS:
		var p := slot_positie(i)
		draw_rect(Rect2(p - Vector2(7, 8), Vector2(14, 16)), Color("#e3e5ea"))
	draw_rect(r, Color("#8a8f9c"), false, 1.0)


func _koffie() -> void:
	var r := KOFFIE_RECT
	draw_rect(Rect2(r.position + Vector2(-2, 22), Vector2(r.size.x + 4, 10)), Color("#6b5640"))
	draw_rect(Rect2(r.position + Vector2(-2, 22), Vector2(r.size.x + 4, 2)), Color("#8a7154"))
	draw_rect(Rect2(r.position + Vector2(4, 0), Vector2(20, 23)), Color("#2b2e36"))
	draw_rect(Rect2(r.position + Vector2(6, 3), Vector2(16, 6)), Color("#16181d"))
	var lamp := Color("#3fe07a") if koffie_klaar else Color("#e5484d")
	draw_rect(Rect2(r.position + Vector2(8, 5), Vector2(3, 2)), lamp)
	draw_rect(Rect2(r.position + Vector2(10, 13), Vector2(8, 3)), Color("#4a4f5c"))
	draw_rect(Rect2(r.position + Vector2(11, 17), Vector2(6, 5)), Color("#eeeeee"))
	if koffie_klaar:
		for i: int in 2:
			var f := fmod(_tijd * 0.8 + i * 0.5, 1.0)
			draw_circle(r.position + Vector2(13 + i * 2, 15 - f * 10.0), 1.2, Color(1, 1, 1, 0.5 * (1.0 - f)))


func _plant() -> void:
	var r := PLANT_RECT
	draw_rect(Rect2(r.position + Vector2(2, 14), Vector2(28, 12)), Color("#8a6a4a"))
	draw_rect(Rect2(r.position + Vector2(2, 14), Vector2(28, 2)), Color("#a8865f"))
	_tegel(PLANT_TEGEL, r.position + Vector2(0, 0))
	_tegel(PLANT_TEGEL, r.position + Vector2(16, 2))


func _server() -> void:
	var r := SERVER_RECT
	draw_rect(Rect2(r.position + Vector2(-2, r.size.y - 4), Vector2(r.size.x + 4, 6)), Color(0, 0, 0, 0.3))
	draw_texture(SERVER, r.position)
	if _server_flits > 0.0:
		draw_rect(r, Color(0.4, 1.0, 0.6, _server_flits * 0.45))
	# Bordje erboven: hier gaat het live.
	var bord := Rect2(r.position.x - 4, r.position.y - 12, r.size.x + 8, 9)
	draw_rect(bord, Color("#1d7a52") if not brand else Color("#e5484d"))
	_kleine_tekst("LIVE" if not brand else "BRAND", Vector2(bord.position.x + 8, bord.position.y + 7), Color.WHITE)
	if brand:
		for i: int in 7:
			var f := fmod(_tijd * 2.5 + i * 0.37, 1.0)
			var x := r.position.x + 3 + i * 4.3 + sin(_tijd * 9.0 + i) * 1.5
			var y := r.position.y + r.size.y - 8 - f * 50.0
			var k := Color("#ffd23f").lerp(Color("#e5484d"), f)
			k.a = 1.0 - f * 0.8
			draw_circle(Vector2(x, y), 3.5 * (1.0 - f * 0.6), k)


func _vogel(c: Vector2, k: Color) -> void:
	# Een vogeltje in een paar vlakken: lijf, vleugel, snavel.
	draw_circle(c, 6.0, k)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-2, -2), c + Vector2(-12, -8), c + Vector2(-4, 3)]), k)
	draw_colored_polygon(PackedVector2Array([c + Vector2(5, -2), c + Vector2(10, 0), c + Vector2(5, 2)]), k)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-5, 3), c + Vector2(-11, 7), c + Vector2(-3, 6)]), k)


func _kleine_tekst(t: String, p: Vector2, k: Color) -> void:
	draw_string(UiKit.FONT_10, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, k)
