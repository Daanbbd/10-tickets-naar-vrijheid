class_name InteractionProbe
extends Area2D
## Vindt het dichtstbijzijnde interactieve object voor de speler.
##
## Evalueert de overlap elke frame opnieuw in plaats van enter/exit bij te
## houden: Area2D-monitoring staat stil tijdens pause, waardoor exit-events na
## een minigame een frame te laat komen en de prompt blijft hangen.

var _current: Interactable = null


func _ready() -> void:
	monitoring = true
	monitorable = false


## Hoe hard dit object aandacht verdient als er meer dan één binnen bereik ligt.
##
## Puur op afstand kiezen ging mis waar twee dingen naast elkaar staan: het
## serverrack met BBD-205 erop en het rack ernaast dat alleen een grapje is,
## liggen één tegel uit elkaar. Je kreeg dan "Onderzoeken Serverrack" terwijl
## het ticket op de buurman lag — twee bijna identieke prompts op dezelfde plek,
## en de verkeerde won zodra je een halve tegel opschoof.
##
## Werk wint dus van sfeer, en pas daarbinnen telt afstand.


## Wie met je meeloopt telt het lichtst.
##
## Een volger houdt `Npc.FOLLOW_DISTANCE` (26 px) aan, en deze probe reikt 31 px
## ver: hij ligt dus permanent binnen bereik, waar je ook staat. Met het gewicht
## van een gewoon kernobject (1) wint hij daarmee op afstand van alles waar je
## naartoe gelópen bent zodra dat net iets verder weg ligt — het scrumbord, een
## deur, een collega die je wél wilde spreken. Dat is precies het "ik kan niets
## meer aanspreken" dat `storing_dennis` opleverde, want die laat Dennis zes
## tickets lang met je meelopen.
##
## Onder sfeer en niet uitgeschakeld: staat er verder niets in de buurt, dan is
## hij nog steeds het antwoord. Je moet hem kunnen aanspreken — bij Dennis is
## dat zelfs de enige manier om hem weer kwijt te raken.
const VOLGER := -1

## Waar `_gewicht()` nooit onder komt, zodat ook een volger gekozen kan worden.
const GEEN := -99


static func _gewicht(it: Interactable) -> int:
	if it.kind == Interactable.Kind.TICKET and it.ticket_here() != null:
		return 2   # hier ligt een ticket dat nu open staat
	# Duck typing en geen `as Npc`: `Npc` verwijst naar `Player` en `Player`
	# naar deze klasse, en GDScript struikelt over wederzijdse
	# `class_name`-verwijzingen (zie docs/ARCHITECTURE.md).
	var ouder := it.get_parent()
	if ouder != null and ouder.has_method(&"is_following") \
			and bool(ouder.call(&"is_following")):
		return VOLGER
	if it.is_core_kind():
		return 1   # collega, deur, bord: doet iets, maar geen openstaand werk
	return 0       # posters, de blauwe tijger, alles wat je alleen leest


func _physics_process(_delta: float) -> void:
	var best: Interactable = null
	var best_d := INF
	var best_w := GEEN
	for a: Area2D in get_overlapping_areas():
		var it := a as Interactable
		if it == null or not it.is_available():
			continue
		var w := _gewicht(it)
		var d := global_position.distance_squared_to(it.global_position)
		if w > best_w or (w == best_w and d < best_d):
			best_w = w
			best_d = d
			best = it

	if best != _current:
		_current = best
		Bus.interaction_prompt_changed.emit(
			_current.prompt_text() if _current != null else "", _current != null,
			_current.world_id if _current != null else &"",
			_current.verb() if _current != null else "")


func current() -> Interactable:
	return _current


## Na een dialoog of minigame: prompt geforceerd verversen.
func refresh() -> void:
	_current = null
