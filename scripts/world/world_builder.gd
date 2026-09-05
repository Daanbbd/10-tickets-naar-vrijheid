class_name WorldBuilder
extends RefCounted
## Bouwt de kantoorvloer uit data/floor.json. De TileSet wordt in code
## samengesteld uit de gegenereerde atlas, zodat een nieuwe plattegrond
## alleen een datawijziging is en geen editorwerk.

## Wandrijen buiten de vloer, boven en onder; zie `populate()`. Drie is genoeg
## voor elk bestaand portrettoestel: 9:22 geeft 469 px = 3,3 tegels extra,
## verdeeld over boven en onder.
const RAND_RIJEN := 3

const ATLAS_PNG := "res://assets/tilesets/office_atlas.png"
const ATLAS_JSON := "res://assets/tilesets/office_atlas.json"
const PHYSICS_LAYER := 0

## De korte as van de verdieping is 12 meter breed. Dat is de ankermaat uit
## docs/LEVEL.md, opgemeten op de ontruimingsplattegrond, en dezelfde waarde
## waar `tools/generators/gen_floor.py` zijn `M_PER_TILE` uit rekent.
##
## Alleen die ene maat staat hier; de rest volgt. Zo overleeft een afstand in
## meters een herontworpen vloer: wordt de plattegrond hoger of lager getekend,
## dan verandert de tegelmaat mee en de kamer niet.
const KORTE_AS_M := 12.0

## De lange as van de verdieping is 60 meter. Die staat hier apart omdat de
## plattegrond sinds de inkorting niet meer op schaal is in de lengte: het echte
## pand is 5,06:1, deze vloer is 80x26 en dus 3,08:1. Dat is een bewuste keuze --
## de ruimtes zijn zo groot als wat er in staat, en de lege gang ertussen is
## eruit -- maar hij mag niet doorlekken naar wat de speler leest.
##
## Zonder deze constante zou de doelwijzer "Birdhouse 22 m" tonen waar het in
## werkelijkheid 36 m is, want die rekent met meters per tegel en de vloer werd
## korter terwijl de tegel gelijk bleef. De korte as blijft het anker voor alles
## wat dwars staat; deze is het anker voor alles wat in de lengte meet.
const LANGE_AS_M := 60.0

var tile_size: int = 16
var grid: PackedStringArray = []
var legend: Dictionary = {}
var zones: Array = []
## Samengestelde meubels: footprint in tegels, beeld als losse sprite.
var props: Array = []
var size: Vector2i = Vector2i.ZERO
var spawn_tile: Vector2i = Vector2i.ZERO

var _coords: Dictionary = {}      ## char -> Vector2i atlas-coord
var _tileset: TileSet = null


func load_floor() -> bool:
	var f: Dictionary = GameData.floor_data
	if f.is_empty():
		push_error("WorldBuilder: data/floor.json ontbreekt of is leeg")
		return false

	tile_size = int(f.get("tile_size", 16))
	size = Vector2i(int(f["size"][0]), int(f["size"][1]))
	spawn_tile = Vector2i(int(f["spawn"][0]), int(f["spawn"][1]))
	legend = f.get("legend", {}) as Dictionary
	zones = f.get("zones", []) as Array
	props = f.get("props", []) as Array
	grid = PackedStringArray()
	for row: Variant in f.get("grid", []):
		grid.append(String(row))

	if grid.size() != size.y:
		push_error("WorldBuilder: grid heeft %d regels, verwacht %d" % [grid.size(), size.y])
		return false
	return true


func build_tileset() -> TileSet:
	if _tileset != null:
		return _tileset

	var meta := _read_atlas_json()
	_coords = meta.get("coords", {}) as Dictionary

	var ts := TileSet.new()
	ts.tile_size = Vector2i(tile_size, tile_size)
	ts.add_physics_layer(-1)
	ts.set_physics_layer_collision_layer(PHYSICS_LAYER, 1)

	var src := TileSetAtlasSource.new()
	src.texture = load(ATLAS_PNG)
	src.texture_region_size = Vector2i(tile_size, tile_size)
	# De source moet aan de TileSet hangen voordat er TileData bestaat,
	# anders kent hij de physics layers nog niet.
	ts.add_source(src, 0)

	var half := tile_size / 2.0
	for ch: Variant in _coords.keys():
		var coord := Vector2i(int(_coords[ch][0]), int(_coords[ch][1]))
		src.create_tile(coord)
		var td := src.get_tile_data(coord, 0)
		var info := legend.get(ch, {}) as Dictionary
		if bool(info.get("solid", false)):
			td.add_collision_polygon(PHYSICS_LAYER)
			td.set_collision_polygon_points(PHYSICS_LAYER, 0, PackedVector2Array([
				Vector2(-half, -half), Vector2(half, -half),
				Vector2(half, half), Vector2(-half, half),
			]))
		# Meubels sorteren op hun voet zodat de speler er netjes achter loopt.
		if String(info.get("kind", "")) == "prop":
			td.y_sort_origin = int(half)

	_tileset = ts
	return ts


## Drie korrelvarianten van dezelfde betonvloer. Ze staan bewust niet in het
## grid: het is geen plattegrondinformatie maar textuur, en drie extra tekens
## door 2400 gridtegels strooien maakt `floor.json` onleesbaar voor de enige
## lezer die telt — een mens die de plattegrond nakijkt. De keuze is
## deterministisch per tegel, dus twee runs geven dezelfde vloer.
const VLOER_VARIANTEN: PackedStringArray = [".", ",", ";"]


func _vloer_variant(x: int, y: int) -> Vector2i:
	var h: int = absi((x * 73856093) ^ (y * 19349663))
	return _coord_for(VLOER_VARIANTEN[h % VLOER_VARIANTEN.size()])


## Vult de twee lagen. Ground draagt alles wat vloer is; Solid draagt muren,
## glas en meubels.
##
## Vloer hoort op Ground en niet op Solid, ook als het een accent- of
## raamlichttegel is. `Solid` heeft `y_sort_enabled`, dus een vloertegel dáár
## sorteert tegen de propsprites en kan een schaduw of een meubelrand afdekken
## zodra hij een hogere y heeft. Op Ground (z_index -10) kan dat per definitie
## niet.
func populate(ground: TileMapLayer, solid: TileMapLayer) -> void:
	var ts := build_tileset()
	ground.tile_set = ts
	solid.tile_set = ts
	ground.clear()
	solid.clear()

	for y: int in size.y:
		var row := grid[y]
		for x: int in size.x:
			var ch := row[x]
			var info := legend.get(ch, {}) as Dictionary
			var kind := String(info.get("kind", "floor"))
			var cell := Vector2i(x, y)

			if kind == "wall" or kind == "exit":
				solid.set_cell(cell, 0, _coord_for(ch))
				continue

			if kind == "floor":
				ground.set_cell(cell, 0,
					_vloer_variant(x, y) if ch == "." else _coord_for(ch))
				continue

			ground.set_cell(cell, 0, _vloer_variant(x, y))
			solid.set_cell(cell, 0, _coord_for(ch))

	# Wandrijen buiten de vloer, boven en onder. De vloer is 26 tegels hoog en
	# het canvas minstens 416 px, maar sinds `window/stretch/aspect = "expand"`
	# groeit het canvas op een hoger toestel mee: een 9:21-telefoon ziet 448 px,
	# dus twee tegels méér dan de vloer. Zonder deze rijen kijkt die speler
	# boven en onder de verdieping in het niets; met deze rijen kijkt hij tegen
	# de muur, wat een kantoor hoort te doen. `GameCamera` laat hem precies zo
	# ver kijken als het canvas hoger is (`rand_voor()`), nooit verder dan dit.
	for y: int in range(-RAND_RIJEN, 0):
		for x: int in size.x:
			solid.set_cell(Vector2i(x, y), 0, _coord_for("#"))
	for y: int in range(size.y, size.y + RAND_RIJEN):
		for x: int in size.x:
			solid.set_cell(Vector2i(x, y), 0, _coord_for("#"))


## De vloer zelf, zonder de wandrand. Alles wat in meters of tegels rekent
## (`meters_per_tegel()`, de wijzer, de kompasstrip) gaat hiervan uit.
func world_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(size) * float(tile_size))


## De vloer plus de getekende wandrand boven en onder — het uiterste dat de
## camera mag tonen op een toestel dat hoger is dan de vloer.
func world_rect_met_rand() -> Rect2:
	var r := float(RAND_RIJEN * tile_size)
	return world_rect().grow_individual(0.0, r, 0.0, r)


## Meters per tegel, afgeleid uit `KORTE_AS_M`. Zie daar.
func meters_per_tegel() -> float:
	return KORTE_AS_M / float(maxi(1, size.y))


## Meters per tegel in de lengterichting, afgeleid uit `LANGE_AS_M`. Wijkt af
## van `meters_per_tegel()` omdat de vloer in de lengte samengeperst is; zie daar.
func meters_per_tegel_lang() -> float:
	return LANGE_AS_M / float(maxi(1, size.x))


## Meters per wereldpixel in de lengterichting. Voor alles wat een afstand in
## het beeld toont -- en dat is in dit spel altijd een horizontale afstand: de
## camera klemt verticaal vast, dus `objective_marker` meet alleen over x.
func meters_per_pixel() -> float:
	return meters_per_tegel_lang() / float(maxi(1, tile_size))


func tile_to_world(t: Vector2i) -> Vector2:
	return Vector2(t) * float(tile_size) + Vector2(tile_size, tile_size) * 0.5


func world_to_tile(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / tile_size), floori(p.y / tile_size))


func char_at(t: Vector2i) -> String:
	if t.y < 0 or t.y >= size.y or t.x < 0 or t.x >= size.x:
		return "#"
	return grid[t.y][t.x]


func is_solid(t: Vector2i) -> bool:
	var info := legend.get(char_at(t), {}) as Dictionary
	return bool(info.get("solid", true))


## Dichtstbijzijnde begaanbare tegel, voor het veilig plaatsen van NPC's.
func nearest_walkable(t: Vector2i, max_radius: int = 6) -> Vector2i:
	if not is_solid(t):
		return t
	for r: int in range(1, max_radius + 1):
		for dy: int in range(-r, r + 1):
			for dx: int in range(-r, r + 1):
				if absi(dx) != r and absi(dy) != r:
					continue
				var c := t + Vector2i(dx, dy)
				if not is_solid(c):
					return c
	return t


## Een loopbare route van tegel naar tegel, als wereldposities.
##
## Er was geen enkele pathfinding in dit project: `Npc._move_towards()` gaat in
## een rechte lijn op zijn doel af en laat `move_and_slide()` de rest doen. Dat
## werkt zolang er niets tussen staat, en dat is op deze vloer bijna nergens
## waar. Tussen de startplek (2,17) en het scrumbord (12,24) staat een muur op
## x9; een collega die na een ticket naar huis loopt gaat dwars door de
## bureau-eilanden. In beide gevallen glijdt hij langs de geometrie tot hij in
## een hoek klem staat, en dan beweegt er niets meer zonder dat er iets misgaat
## dat je kunt zien.
##
## Breedte-eerst en geen A*: de vloer is 80x26, dus 2080 tegels in het ergste
## geval. Dat is goedkoper dan de prioriteitswachtrij die A* ervoor nodig heeft,
## en het levert bij gelijke stapkosten hetzelfde kortste pad op.
##
## Vier richtingen en niet acht: diagonaal langs een binnenhoek snijdt door de
## muur die die hoek maakt. De diagonalen komen er in de beweging vanzelf bij,
## want een NPC loopt naar het volgende punt en niet naar het volgende vakje.
##
## Leeg terug betekent: onbereikbaar. Een niet-loopbaar begin- of eindpunt wordt
## eerst naar de dichtstbijzijnde loopbare tegel getrokken, zodat een anker dat
## in een muur staat geen lege route oplevert.
func pad(van: Vector2i, naar: Vector2i) -> PackedVector2Array:
	var start := nearest_walkable(van)
	var doel := nearest_walkable(naar)
	if start == doel:
		return PackedVector2Array([tile_to_world(doel)])

	var vorige := {start: start}
	var wachtrij: Array[Vector2i] = [start]
	var gevonden := false
	while not wachtrij.is_empty():
		var c: Vector2i = wachtrij.pop_front()
		if c == doel:
			gevonden = true
			break
		for d: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var n := c + d
			if n.x < 0 or n.y < 0 or n.x >= size.x or n.y >= size.y:
				continue
			if vorige.has(n) or is_solid(n):
				continue
			vorige[n] = c
			wachtrij.append(n)
	if not gevonden:
		return PackedVector2Array()

	var tegels: Array[Vector2i] = []
	var t := doel
	while t != start:
		tegels.append(t)
		t = vorige[t]
	tegels.reverse()

	# Alleen de knikken bewaren. Een rechte gang van twintig tegels is één
	# beweging; twintig tussenpunten maken daar twintig micro-correcties van, en
	# dat is precies het schokkerige lopen dat een route hoort weg te nemen.
	var uit := PackedVector2Array()
	for i: int in tegels.size():
		var laatste := i == tegels.size() - 1
		if laatste or _knik(tegels, i):
			uit.append(tile_to_world(tegels[i]))
	return uit


## Verandert de looprichting op dit punt? Het eerste punt telt nooit als knik:
## daar komt de NPC al vandaan.
func _knik(tegels: Array[Vector2i], i: int) -> bool:
	if i == 0 or i + 1 >= tegels.size():
		return false
	return (tegels[i] - tegels[i - 1]) != (tegels[i + 1] - tegels[i])


func zone_at(t: Vector2i) -> Dictionary:
	for z: Variant in zones:
		var d := z as Dictionary
		var r: Array = d.get("rect", [])
		if r.size() == 4 and t.x >= int(r[0]) and t.x <= int(r[2]) and t.y >= int(r[1]) and t.y <= int(r[3]):
			return d
	return {}


func _coord_for(ch: String) -> Vector2i:
	if not _coords.has(ch):
		return Vector2i(0, 0)
	return Vector2i(int(_coords[ch][0]), int(_coords[ch][1]))


func _read_atlas_json() -> Dictionary:
	if not FileAccess.file_exists(ATLAS_JSON):
		push_error("WorldBuilder: %s ontbreekt. Draai tools/generators/gen_tiles.py" % ATLAS_JSON)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ATLAS_JSON))
	return parsed as Dictionary if parsed is Dictionary else {}
