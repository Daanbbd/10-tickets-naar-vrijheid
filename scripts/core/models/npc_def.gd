class_name NpcDef
extends Resource
## Niet-speelbaar personage. Uit data/npcs.json.
## Dialoog verwijst naar id's, nooit naar namen: de namenlijst is inwisselbaar.

@export var id: StringName = &""
@export var name: String = ""
@export var role: String = ""
@export var home_tile: Vector2i = Vector2i.ZERO
@export var zone: StringName = &""
@export var dialogue_id: StringName = &""
@export var route: Array[Vector2i] = []
@export var route_pause: float = 2.0
@export var can_follow: bool = false
@export var is_playable_colleague: bool = false
@export var color: Color = Color.WHITE
@export var skin: Color = Color(0.86, 0.70, 0.56)
@export var hair: Color = Color(0.25, 0.18, 0.13)
@export var sheet: StringName = &"plain"
@export var portrait: String = ""
@export var spawn_when: Dictionary = {}
