class_name RushOntsnapBallon
extends Node2D
## Tekst in de ontsnapping: een tekstballon boven iemands hoofd, of een getal
## dat opstijgt en vervaagt (-1 s, Koffie!).
##
## Waarom niet `RushPop`: die klemt zijn tekst binnen de 192 px van de
## rush-vloer, en deze vloer is 1280 px lang. Hier hangt de ballon aan het
## hoofd van wie praat, dus hij loopt mee en hoeft nergens binnen te blijven.

var tekst := ""
var kleur := Color.WHITE
var ballon := true
var duur := 1.4
var stijg := 3.0
var _t := 0.0


## Een ballon die aan `wie` hangt, net boven het hoofd. Een nieuwe ballon
## vervangt de vorige: twee zinnen tegelijk boven één hoofd leest niemand.
static func zeg(wie: Node2D, t: String, d: float = 1.4) -> RushOntsnapBallon:
	for k: Node in wie.get_children():
		if k is RushOntsnapBallon and (k as RushOntsnapBallon).ballon:
			k.queue_free()
	var b := RushOntsnapBallon.new()
	b.tekst = t
	b.duur = d
	b.position = Vector2(0, -36)
	b.z_index = 60
	wie.add_child(b)
	return b


## Een getal dat opstijgt, op een vaste plek in de wereld.
static func getal(ouder: Node2D, p: Vector2, t: String, k: Color) -> RushOntsnapBallon:
	var b := RushOntsnapBallon.new()
	b.tekst = t
	b.kleur = k
	b.ballon = false
	b.duur = 0.9
	b.stijg = 16.0
	b.position = p
	b.z_index = 70
	ouder.add_child(b)
	return b


func _process(delta: float) -> void:
	_t += delta
	if _t >= duur:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var f := _t / duur
	var y := -stijg * (1.0 - pow(1.0 - minf(f * 2.0, 1.0), 2.0))
	var alpha := 1.0 if f < 0.75 else (1.0 - f) / 0.25
	var font := UiKit.FONT_10
	var maat := font.get_string_size(tekst, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
	var x := -roundf(maat.x / 2.0)
	if not ballon:
		var k := kleur
		k.a = alpha
		draw_string_outline(font, Vector2(x, y), tekst, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 3,
			Color(0.08, 0.09, 0.13, alpha))
		draw_string(font, Vector2(x, y), tekst, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, k)
		return
	# Een klein sprongetje bij binnenkomst, net als bij `RushPop`.
	y -= sin(minf(_t * 7.0, 1.0) * PI) * 3.0
	alpha *= minf(_t * 12.0, 1.0)
	var r := Rect2(x - 3, y - 11, maat.x + 6, 12)
	draw_rect(Rect2(r.position + Vector2(1, 1), r.size), Color(0, 0, 0, 0.3 * alpha))
	draw_rect(r, Color(1, 1, 1, alpha))
	draw_rect(r, Color(0.14, 0.15, 0.2, alpha), false, 1.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-2, y + 1), Vector2(2, y + 1), Vector2(0, y + 4)]), Color(1, 1, 1, alpha))
	draw_string(font, Vector2(x, y - 2), tekst, HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
		Color(0.14, 0.15, 0.2, alpha))
