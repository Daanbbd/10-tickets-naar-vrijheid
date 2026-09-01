class_name Interactable
extends Area2D
## Interactiepunt in de wereld. Zit op collision layer 4 zodat alleen de
## InteractionProbe van de speler hem ziet.

signal interacted(who: Node)

enum Kind { TALK, EXAMINE, USE, TICKET, DOOR }

const VERB := {
	Kind.TALK: "Praten",
	Kind.EXAMINE: "Onderzoeken",
	Kind.USE: "Gebruiken",
	Kind.TICKET: "Oppakken",
	Kind.DOOR: "Openen",
}

@export var world_id: StringName = &""
@export var kind: Kind = Kind.EXAMINE
@export var label: String = ""
@export var ticket_id: StringName = &""
@export var dialogue_id: StringName = &""
@export var available_when: Dictionary = {}
## Optionele extra actie na de dialoog, bv. "board" om het ticketbord te openen.
@export var action: StringName = &""

var _enabled: bool = true


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	monitoring = false
	monitorable = true
	add_to_group(&"interactable")


func is_available() -> bool:
	return _enabled and visible and Conditions.check(available_when)


func set_enabled(v: bool) -> void:
	_enabled = v


func prompt_text() -> String:
	return "%s  %s" % [verb(), label] if label != "" else verb()


## Het werkwoord los, zonder het label. Op een aanraakscherm staat dit op de
## actieknop zelf: de knop zegt dan wat hij doet in plaats van naar een toets
## te verwijzen die er niet is.
func verb() -> String:
	if kind == Kind.TICKET and ticket_here() == null:
		return "Bekijken"
	return String(VERB.get(kind, "Gebruiken"))


## Het openstaande ticket op dit object, of null. De HUD gebruikt dit om de
## eigenaar aan de prompt te hangen.
func ticket_here() -> TicketDef:
	for id: StringName in GameData.ticket_ids():
		var t: TicketDef = GameData.ticket(id)
		if t != null and t.anchor == world_id and Session.is_available(id):
			return t
	return null


func trigger(who: Node) -> void:
	interacted.emit(who)
