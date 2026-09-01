class_name CharacterDef
extends Resource
## Speelbaar personage. Uit data/characters.json.

@export var id: StringName = &""
@export var name: String = ""
@export var role: String = ""
@export var tagline: String = ""
@export var description: String = ""
@export var traits: Array[StringName] = []
@export var specialisms: Array[String] = []
@export var owned_tickets: Array[StringName] = []
@export var finale_id: StringName = &""
@export var color: Color = Color.WHITE
@export var skin: Color = Color(0.86, 0.70, 0.56)
@export var hair: Color = Color(0.25, 0.18, 0.13)
@export var sheet: StringName = &"plain"   ## verouderd, valt terug via LEGACY_LOOKS
## Silhouet in lagen: body, outfit, hair, facial, accessory.
@export var look: Dictionary = {}
@export var pants: Color = Color("#34384e")
@export var portrait: String = ""
@export var accent: Color = Color("#3a86ff")
