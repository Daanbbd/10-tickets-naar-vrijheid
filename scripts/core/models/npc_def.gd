class_name NpcDef
extends Resource
## Niet-speelbaar personage. Uit data/npcs.json.
## Dialoog verwijst naar id's, nooit naar namen: de namenlijst is inwisselbaar.

@export var id: StringName = &""
@export var name: String = ""
@export var role: String = ""
@export var home_tile: Vector2i = Vector2i.ZERO
@export var zone: StringName = &""
## Aan welk bureau-eiland uit `floor.json` deze collega zit, of leeg.
##
## Expliciet en niet uit afstand afgeleid. Dat laatste heeft hier gestaan en gaf
## twee van de drie fout: Victor kwam op Team Helio uit omdat zijn standplaats
## daar dichter bij lag, en Dennis viel terug op "bij de bureaus". Waar iemand
## zit is een gegeven van het kantoor, geen functie van zijn looppunt.
@export var plek: StringName = &""
@export var dialogue_id: StringName = &""
@export var route: Array[Vector2i] = []
@export var route_pause: float = 2.0
@export var can_follow: bool = false
@export var is_playable_colleague: bool = false
@export var color: Color = Color.WHITE
@export var skin: Color = Color(0.86, 0.70, 0.56)
@export var hair: Color = Color(0.25, 0.18, 0.13)
@export var sheet: StringName = &"plain"   ## verouderd, valt terug via LEGACY_LOOKS
## Silhouet in lagen: body, outfit, hair, facial, accessory.
@export var look: Dictionary = {}
@export var pants: Color = Color("#34384e")
@export var accent: Color = Color("#f4a259")
@export var portrait: String = ""
@export var spawn_when: Dictionary = {}
## Leeg = het gewone gelaagde personagesilhouet. Gezet = een los sprite-bestand
## (bijv. de paardenbugs) in plaats van het body/hair/outfit-silhouet — voor
## een "collega" die geen mens is en dus geen personagelagen heeft.
@export var static_sprite: String = ""
