class_name RushOntsnapPlafond
extends Node2D
## Vrijdag brandt alles, ook het plafond: brandende systeemplafondplaten die
## voor je voeten naar beneden komen.
##
## Elke plaat kondigt zich aan met een schaduw op de vloer die groeit en
## donkerder wordt. Na `AANLOOP` seconden valt hij, en sta je er dan onder,
## dan sta je even te knipperen. Daarna smeult hij nog wat na, maar je kunt
## erdoorheen: een stuk plafond mag je nooit de enige weg afsnijden.
##
## Waar en wanneer ze vallen, beslist de ontsnapping; deze node tekent ze en
## zegt wanneer er een neerkomt.

signal valt(p: Vector2)

## Van schaduw tot inslag.
const AANLOOP := 0.8
## Hoe lang de plaat nog nasmeult.
const NA := 1.1
## Een plaat is een tegel groot.
const MAAT := 14.0

## {p: Vector2, t: float}
var platen: Array[Dictionary] = []
var _vloer: Node2D
var _tijd := 0.0


func _ready() -> void:
	z_index = 26
	# De schaduw hoort op de vloer, onder iedereen; de vallende plaat erboven.
	_vloer = Node2D.new()
	_vloer.z_as_relative = false
	_vloer.z_index = -4
	_vloer.draw.connect(_teken_schaduw)
	add_child(_vloer)


func laat_vallen(p: Vector2) -> void:
	platen.append({"p": p, "t": 0.0})


## Nog niet neergekomen: voor de bot, die eromheen wil.
func dreigend() -> Array[Vector2]:
	var uit: Array[Vector2] = []
	for d: Dictionary in platen:
		if float(d["t"]) < AANLOOP:
			uit.append(d["p"])
	return uit


func _process(delta: float) -> void:
	_tijd += delta
	for i: int in range(platen.size() - 1, -1, -1):
		var d := platen[i]
		var oud := float(d["t"])
		d["t"] = oud + delta
		if oud < AANLOOP and float(d["t"]) >= AANLOOP:
			valt.emit(d["p"])
		if float(d["t"]) > AANLOOP + NA:
			platen.remove_at(i)
	queue_redraw()
	_vloer.queue_redraw()


func _teken_schaduw() -> void:
	for d: Dictionary in platen:
		var t := float(d["t"])
		if t >= AANLOOP:
			continue
		var f := t / AANLOOP
		var p: Vector2 = d["p"] + Vector2(0, 2)
		# Meteen een oranje kader op de plek waar hij valt, dat steeds sneller
		# knippert, en daarbinnen een schaduw die groeit en donkerder wordt.
		# Op een drukke pixelvloer moet je dit in één blik zien.
		var puls := 0.6 + 0.4 * sin(_tijd * lerpf(12.0, 36.0, f))
		var vol := Vector2(MAAT + 2.0, 12.0)
		var m := (vol * lerpf(0.45, 1.0, f)).round()
		_vloer.draw_rect(Rect2((p - m / 2.0).round(), m), Color(0.05, 0.0, 0.0, 0.35 + 0.35 * f))
		var r := Rect2((p - vol / 2.0).round(), vol)
		var k := Color(1.0, 0.42, 0.17, puls)
		_vloer.draw_rect(Rect2(r.position, Vector2(r.size.x, 2)), k)
		_vloer.draw_rect(Rect2(r.position + Vector2(0, r.size.y - 2), Vector2(r.size.x, 2)), k)
		_vloer.draw_rect(Rect2(r.position, Vector2(2, r.size.y)), k)
		_vloer.draw_rect(Rect2(r.position + Vector2(r.size.x - 2, 0), Vector2(2, r.size.y)), k)
		# En er dwarrelen al vonkjes uit het plafond naar beneden.
		for i: int in 3:
			var fk := fmod(t * 2.2 + i * 0.33, 1.0)
			var q := p + Vector2(-5.0 + i * 5.0, lerpf(-46.0, -2.0, fk)).round()
			_vloer.draw_rect(Rect2(q, Vector2(2, 2)), Color(1.0, 0.85, 0.35, 1.0 - fk * 0.4))


func _draw() -> void:
	for d: Dictionary in platen:
		var t := float(d["t"])
		var p: Vector2 = d["p"]
		if t < AANLOOP - 0.22:
			continue
		if t < AANLOOP:
			# Valt: een gloeiende plaat die van boven het beeld komt.
			var f := (t - (AANLOOP - 0.22)) / 0.22
			var y := lerpf(-90.0, 0.0, f * f)
			_plaat(p + Vector2(0, roundf(y)), 1.0)
			continue
		# Neergekomen: brokken met vlammetjes, die uitdoven.
		var na := (t - AANLOOP) / NA
		var a := 1.0 - na
		_plaat(p + Vector2(0, 1), a)
		var tq := floorf(_tijd * 12.0) / 12.0
		for k: int in 3:
			var x := p.x - 5.0 + k * 5.0
			var h := roundf((6.0 - k % 2 * 2.0) * (0.7 + 0.3 * sin(tq * 13.0 + k * 2.1)) * a)
			draw_rect(Rect2(x - 1.0, p.y - h - 2.0, 3.0, h), Color(1.0, 0.42, 0.12, a))
			draw_rect(Rect2(x, p.y - h * 0.5 - 2.0, 1.0, h * 0.5), Color(1.0, 0.85, 0.3, a))


func _plaat(p: Vector2, a: float) -> void:
	var r := Rect2(p - Vector2(MAAT / 2.0, 4.0), Vector2(MAAT, 6.0))
	draw_rect(Rect2(r.position + Vector2(0, 2), r.size), Color(0.1, 0.05, 0.04, 0.6 * a))
	draw_rect(r, Color(0.78, 0.74, 0.68, a))
	draw_rect(Rect2(r.position, Vector2(MAAT, 2.0)), Color(1.0, 0.5, 0.15, a))
	draw_rect(r, Color(0.35, 0.3, 0.28, a), false, 1.0)
