class_name WorldBuilder
extends RefCounted
## Bouwt de kantoorvloer uit data/floor.json. De TileSet wordt in code
## samengesteld uit de gegenereerde atlas, zodat een nieuwe plattegrond
## alleen een datawijziging is en geen editorwerk.

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


## Vult de twee lagen. Ground ligt overal onder; Solid draagt muren, glas en meubels.
func populate(ground: TileMapLayer, solid: TileMapLayer) -> void:
	var ts := build_tileset()
	ground.tile_set = ts
	solid.tile_set = ts
	ground.clear()
	solid.clear()

	var floor_coord := _coord_for(".")
	for y: int in size.y:
		var row := grid[y]
		for x: int in size.x:
			var ch := row[x]
			var info := legend.get(ch, {}) as Dictionary
			var kind := String(info.get("kind", "floor"))
			var cell := Vector2i(x, y)

			if kind != "wall" and kind != "exit":
				ground.set_cell(cell, 0, floor_coord)

			if ch != ".":
				solid.set_cell(cell, 0, _coord_for(ch))


func world_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(size) * float(tile_size))


## Meters per tegel, afgeleid uit `KORTE_AS_M`. Zie daar.
func meters_per_tegel() -> float:
	return KORTE_AS_M / float(maxi(1, size.y))


## Meters per wereldpixel. Voor alles wat een afstand in het beeld toont.
func meters_per_pixel() -> float:
	return meters_per_tegel() / float(maxi(1, tile_size))


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
