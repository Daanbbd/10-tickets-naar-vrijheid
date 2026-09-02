class_name TapMarker
extends Node2D
## Wijst aan dat het object waarop hij hangt nu, voor het eerst, aan te tikken
## is — de vervanging van de vaste actieknop. `main.gd` bouwt en breekt er
## hooguit één tegelijk, gehangen aan `Interactable.global_position`.
##
## Geen art-asset: een pulserende ring die zichzelf tekent, net als
## `ObjectiveMarker`. Andere kleur dan die driehoek (`UiKit.ORANJE`, expliciet
## gereserveerd voor "doel"): dit betekent iets anders — niet "ga hierheen"
## maar "hier kun je nu iets doen" — en verdient dus zijn eigen kleur.

const STRAAL := 9.0
const AMPLITUDE := 1.5
const SNELHEID := 4.0

var _t: float = 0.0


func _ready() -> void:
	z_index = 60
	# Iets boven het object, zodat de ring niet over de tegelkunst zelf ligt.
	position = Vector2(0.0, -6.0)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var straal := STRAAL + sin(_t * SNELHEID) * AMPLITUDE
	draw_arc(Vector2.ZERO, straal, 0.0, TAU, 20, Color(UiKit.INK, 0.5), 3.0)
	draw_arc(Vector2.ZERO, straal, 0.0, TAU, 20, UiKit.BLUEBIRD_BRIGHT, 1.5)
