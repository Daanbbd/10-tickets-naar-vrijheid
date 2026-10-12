class_name RushPop
extends Node2D
## Tekst in de wereld: een tekstballon boven iemands hoofd, of een getal dat
## opstijgt en vervaagt (+1, +20 min).

var tekst := ""
var kleur := Color.WHITE
var ballon := false
## Ballon onder het punt in plaats van erboven, met het staartje omhoog.
var onder := false
var duur := 1.6
var stijg := 10.0
var _t := 0.0


static func ballon_op(ouder: Node, p: Vector2, t: String, d: float = 1.7) -> RushPop:
	var b := RushPop.new()
	# Bovenin hangt het bord; een ballon daaroverheen verstopt de tickets.
	if p.y < 60.0:
		b.onder = true
		p.y += 70.0
	b.tekst = t
	b.ballon = true
	b.duur = d
	b.stijg = 3.0
	b.position = p
	b.z_index = 50
	ouder.add_child(b)
	return b


static func getal_op(ouder: Node, p: Vector2, t: String, k: Color) -> RushPop:
	var b := RushPop.new()
	b.tekst = t
	b.kleur = k
	b.duur = 1.0
	b.stijg = 16.0
	b.position = p
	b.z_index = 60
	ouder.add_child(b)
	return b


## Snippers in de kleuren van het bord, op een plek in de vloer (lokaal).
static func confetti(ouder: Node2D, p: Vector2, aantal: int = 18) -> void:
	var c := CPUParticles2D.new()
	c.one_shot = true
	c.explosiveness = 0.95
	c.amount = aantal
	c.lifetime = 0.9
	c.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	c.emission_sphere_radius = 3.0
	c.direction = Vector2(0.0, -1.0)
	c.spread = 70.0
	c.initial_velocity_min = 40.0
	c.initial_velocity_max = 85.0
	c.gravity = Vector2(0.0, 150.0)
	c.scale_amount_min = 2.0
	c.scale_amount_max = 3.0
	c.color_initial_ramp = Juice._postit_ramp()
	c.color_ramp = Juice._uitdoof_ramp()
	c.position = p
	c.z_index = 55
	ouder.add_child(c)
	c.emitting = true
	c.finished.connect(c.queue_free)


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
	# Binnen de vloer blijven (192 breed); de ouder is altijd de vloer zelf.
	var x := clampf(-maat.x / 2.0, 4.0 - position.x, 188.0 - maat.x - position.x)
	if ballon:
		# Een klein sprongetje bij binnenkomst in plaats van uitrekken.
		y -= sin(minf(_t * 7.0, 1.0) * PI) * 3.0
		alpha *= minf(_t * 12.0, 1.0)
		var r := Rect2(x - 3, y - 11, maat.x + 6, 12)
		draw_rect(Rect2(r.position + Vector2(1, 1), r.size), Color(0, 0, 0, 0.3 * alpha))
		draw_rect(r, Color(1, 1, 1, alpha))
		draw_rect(r, Color(0.14, 0.15, 0.2, alpha), false, 1.0)
		if onder:
			draw_colored_polygon(PackedVector2Array([
				Vector2(-2, y - 12), Vector2(2, y - 12), Vector2(0, y - 15)]), Color(1, 1, 1, alpha))
		else:
			draw_colored_polygon(PackedVector2Array([
				Vector2(-2, y + 1), Vector2(2, y + 1), Vector2(0, y + 4)]), Color(1, 1, 1, alpha))
		draw_string(font, Vector2(x, y - 2), tekst, HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
			Color(0.14, 0.15, 0.2, alpha))
	else:
		var k := kleur
		k.a = alpha
		draw_string_outline(font, Vector2(x, y), tekst, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 3,
			Color(0.08, 0.09, 0.13, alpha))
		draw_string(font, Vector2(x, y), tekst, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, k)
