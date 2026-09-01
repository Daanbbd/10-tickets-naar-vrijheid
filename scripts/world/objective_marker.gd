class_name ObjectiveMarker
extends Node2D
## Wijst het huidige doel aan in de wereld: eerst de collega die je moet ophalen,
## daarna het object zelf. Zonder dit moet de speler op gevoel zoeken naar een
## A4 die alleen in de dialoog bestaat.
##
## Geen art-asset: een driehoekje dat zichzelf tekent, dus geen atlas-tile en
## geen import-stap. Er leeft er altijd maximaal één.

const HOOGTE := 20.0
const AMPLITUDE := 2.5
const SNELHEID := 3.2

var _t: float = 0.0
var _basis: float = 0.0


func _ready() -> void:
	add_to_group(&"objective_marker")
	z_index = 60
	_basis = -HOOGTE
	position = Vector2(0.0, _basis)


func _process(delta: float) -> void:
	_t += delta
	# Alleen de positie beweegt; de vorm blijft gelijk, dus geen queue_redraw.
	position.y = _basis + sin(_t * SNELHEID) * AMPLITUDE


func _draw() -> void:
	var punten := PackedVector2Array([Vector2(-4.0, -5.0), Vector2(4.0, -5.0), Vector2(0.0, 2.0)])
	draw_colored_polygon(punten, UiKit.ORANJE)
	var rand := PackedVector2Array([
		Vector2(-4.0, -5.0), Vector2(4.0, -5.0), Vector2(0.0, 2.0), Vector2(-4.0, -5.0)])
	draw_polyline(rand, UiKit.INK, 1.0)
