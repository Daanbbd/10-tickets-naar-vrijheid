class_name HokjeDak
extends Sprite2D
## Het dak op het vergaderhokje, en de enige prop die doorzichtig wordt.
##
## Het hokje is van boven dicht en heeft één deur, aan de noordzijde op de
## `D`-tegel. Een dak dat daar hoort te liggen dekt dus per definitie de speler
## af zodra die binnenstaat — en binnen ligt `hokje_ipad`, het anker van t08.
## Onzichtbaar met een ticket praten is geen optie, dus het dak tweent naar
## `ALPHA_BINNEN` zolang je in de zone staat en weer terug als je eruit loopt.
##
## Waarom een eigen node en geen gewone prop uit `floor.json`: `_spawn_props()`
## maakt kale Sprite2D's die in de y-sortering meedoen. Dit ding moet er juist
## bovenuit (anders loopt de speler er vóór langs in plaats van eronder) en het
## moet op zonewissels reageren. Dat is gedrag, en gedrag hoort niet in data.
##
## De maat komt uit de zone in `floor.json` en staat hier niet in cijfers: de
## vloer is één keer van 130 naar 80 tegels gegaan en dan moet dit meebewegen
## in plaats van stil ergens anders te hangen.

const ZONE := &"z8_hokje"
const SPRITE := "res://assets/sprites/props/hokjedak_7x4.png"

## Boven de speler, maar onder de hangende bordjes (`Main.Z_HANGEND`, 20): een
## plafondbordje hangt lager dan het dak erboven zou hangen, en die twee komen
## elkaar nergens tegen — dit is puur de bedoeling vastleggen.
const Z_DAK := 19

## Niet nul: je hoort te zien dát er een dak boven je zit. Wel laag genoeg om
## de speler, de tikring en het `hokje_ipad`-label eronder te kunnen lezen.
const ALPHA_BINNEN := 0.28
const FADE := 0.22

var _tween: Tween = null


## Aangeroepen na add_child, net als `NpcLayer.setup()`.
func setup(builder: WorldBuilder) -> void:
	var rect: Array = []
	for z: Variant in builder.zones:
		var d := z as Dictionary
		if StringName(d.get("id", "")) == ZONE:
			rect = d.get("rect", []) as Array
			break
	if rect.size() != 4:
		push_error("HokjeDak: zone '%s' heeft geen rect in floor.json" % ZONE)
		queue_free()
		return

	texture = load(SPRITE)
	centered = false
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = Z_DAK
	position = Vector2(float(int(rect[0])), float(int(rect[1]))) * float(builder.tile_size)

	# De sprite hoort de zone exact te dekken. Klopt dat niet, dan is de zone
	# verplaatst zonder dat het dak is bijgetekend, en dan hangt hier een dak
	# naast een kamer — precies het soort stille fout dat je op een render pas
	# ziet als je er expliciet naar zoekt.
	var tegels := Vector2i(int(rect[2]) - int(rect[0]) + 1, int(rect[3]) - int(rect[1]) + 1)
	var verwacht := Vector2(tegels) * float(builder.tile_size)
	if texture != null and texture.get_size() != verwacht:
		push_error("HokjeDak: %s is %v, de zone vraagt %v" % [
			SPRITE, texture.get_size(), verwacht])

	Bus.zone_entered.connect(_op_zone)


## Elke zonewissel komt hier langs; alleen deze zone maakt het dak doorzichtig.
## Er is geen `zone_exited` op de Bus, en die is er ook niet voor nodig: je
## staat altijd in precies één zone, dus een melding over een andere zone ís
## het vertrek uit deze.
func _op_zone(zone_id: StringName, _zone_name: String) -> void:
	_zet_alpha(ALPHA_BINNEN if zone_id == ZONE else 1.0)


func _zet_alpha(doel: float) -> void:
	if is_equal_approx(modulate.a, doel):
		return
	if _tween != null and _tween.is_running():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", doel, FADE)
