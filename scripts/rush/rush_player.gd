class_name RushPlayer
extends Node2D
## Jij. Loopt een pad af dat het spel uitrekent, en draagt maximaal twee
## tickets boven je hoofd.

signal aangekomen

const SNELHEID := 66.0
const HANDEN := 2

var sprite: AnimatedSprite2D
var handen: Array[RushTicket] = []
var pad: PackedVector2Array = PackedVector2Array()
var boost: float = 0.0
## Zolang dit loopt doe je iets anders dan lopen: werken, drinken, blussen,
## of naar Dirk luisteren.
var bezig: float = 0.0
var bezig_totaal: float = 1.0
var bezig_kleur: Color = Color.WHITE
var _richting := &"down"
var _tijd := 0.0
var _stof: float = 0.0


func setup(id: StringName) -> void:
	sprite = AnimatedSprite2D.new()
	sprite.offset = Vector2(0, -16)
	add_child(sprite)
	if id == RushProfiel.ID:
		sprite.sprite_frames = RushProfiel.frames()
		sprite.play(&"idle_down")
		return
	var def: CharacterDef = GameData.character(id)
	if def != null:
		sprite.sprite_frames = CharacterSprites.frames_for(
			def.look, def.color, def.skin, def.hair, def.pants, def.accent)
	sprite.play(&"idle_down")


func loopt() -> bool:
	return not pad.is_empty()


func vrije_hand() -> bool:
	return handen.size() < HANDEN


func start_bezig(duur: float, kleur: Color) -> void:
	bezig = duur
	bezig_totaal = duur
	bezig_kleur = kleur


func kijk(r: StringName) -> void:
	_richting = r


func tik(delta: float) -> void:
	_tijd += delta
	if boost > 0.0:
		boost = maxf(0.0, boost - delta)
	if bezig > 0.0:
		bezig = maxf(0.0, bezig - delta)
		_speel(&"idle")
		queue_redraw()
		return
	if pad.is_empty():
		_speel(&"idle")
		queue_redraw()
		return

	var snelheid := SNELHEID * (1.6 if boost > 0.0 else 1.0)
	var rest := snelheid * delta
	while rest > 0.0 and not pad.is_empty():
		var doel := pad[0]
		var naar := doel - position
		var afstand := naar.length()
		if afstand <= rest:
			position = doel
			rest -= afstand
			pad.remove_at(0)
		else:
			var stap := naar / afstand * rest
			position += stap
			rest = 0.0
			if absf(stap.x) > absf(stap.y) * 1.2:
				_richting = &"right" if stap.x > 0.0 else &"left"
			else:
				_richting = &"down" if stap.y > 0.0 else &"up"
	if boost > 0.0:
		_stof += delta
	if pad.is_empty():
		_speel(&"idle")
		aangekomen.emit()
	else:
		_speel(&"walk")
	sprite.speed_scale = 1.5 if boost > 0.0 else 1.0
	queue_redraw()


func _speel(soort: StringName) -> void:
	var anim := StringName("%s_%s" % [soort, _richting])
	if sprite.animation != anim:
		sprite.play(anim)


func _draw() -> void:
	# Schaduw.
	draw_rect(Rect2(-6, -1, 12, 3), Color(0, 0, 0, 0.25))
	if boost > 0.0:
		# Koffiestoom achter je aan.
		for i: int in 3:
			var f := fmod(_tijd * 2.0 + i * 0.33, 1.0)
			draw_circle(Vector2(-4 + i * 4, -36 - f * 8.0), 1.5, Color(1, 1, 1, 0.5 * (1.0 - f)))
	if bezig > 0.0:
		var c := Vector2(0, -46)
		var deel := 1.0 - bezig / bezig_totaal
		draw_circle(c, 6.0, Color(0, 0, 0, 0.5))
		draw_arc(c, 4.5, -PI / 2.0, -PI / 2.0 + TAU * deel, 20, bezig_kleur, 2.0)


## Waar het n-de ticket in je handen hangt, lokaal.
func hand_positie(i: int) -> Vector2:
	var bob := absf(sin(_tijd * 10.0)) * 1.0 if loopt() else 0.0
	return Vector2(-7 + i * 14 if handen.size() > 1 else 0, -42 - bob)


func hit(p: Vector2) -> bool:
	return Rect2(position + Vector2(-8, -34), Vector2(16, 36)).has_point(p)
