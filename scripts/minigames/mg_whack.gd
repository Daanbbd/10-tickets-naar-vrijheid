extends MinigameBase
## BBD-209 — Paardenbugs opruimen. Arcade-piek van de game.
##
## Bug-paarden raken telt. Klantpaarden raken kost je een strafseconde en een
## vernederende regel. Er is bewust geen game over: alleen tijd.

const HOLES := 8
const BUG := "res://assets/sprites/props/paard_bug.png"
const KLANT := "res://assets/sprites/props/paard_klant.png"
const GAT := "res://assets/sprites/props/gat.png"


class Hole extends Control:
	signal hit(hole: Hole)
	var horse: TextureRect = null
	var gat: TextureRect = null
	var is_bug: bool = false
	var active: bool = false
	var _t: float = 0.0
	var _life: float = 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(34, 46)
		mouse_filter = Control.MOUSE_FILTER_STOP
		gat = TextureRect.new()
		gat.texture = load("res://assets/sprites/props/gat.png")
		gat.position = Vector2(0, 34)
		gat.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(gat)
		horse = TextureRect.new()
		horse.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		horse.visible = false
		add_child(horse)

	func pop(bug: bool, life: float) -> void:
		is_bug = bug
		active = true
		_t = 0.0
		_life = life
		horse.texture = load("res://assets/sprites/props/paard_bug.png" if bug
			else "res://assets/sprites/props/paard_klant.png")
		horse.visible = true
		horse.position = Vector2(1, 40)

	func clear() -> void:
		active = false
		horse.visible = false

	func _process(delta: float) -> void:
		if not active:
			return
		_t += delta
		# opkomen, blijven staan, weer wegzakken
		var up := clampf(_t / 0.18, 0.0, 1.0)
		var down := clampf((_t - (_life - 0.18)) / 0.18, 0.0, 1.0)
		horse.position.y = 40.0 - 34.0 * up + 34.0 * down
		if _t >= _life:
			clear()

	func _gui_input(event: InputEvent) -> void:
		if not active:
			return
		var tik := (event is InputEventMouseButton and (event as InputEventMouseButton).pressed
				and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) \
			or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
		if tik:
			hit.emit(self)


var _holes: Array[Hole] = []
var _gevangen: int = 0
var _doel: int = 10
var _tijd_over: float = 60.0
var _spawn_t: float = 1.0
var _interval: float = 1.3
var _interval_min: float = 0.55
var _zichtbaar: float = 1.5
var _bug_kans: float = 0.65
var _running: bool = false
var _melding: Label = null


func _on_setup() -> void:
	var c := content()
	if c.is_empty():
		fail()
		return

	_doel = int(c.get("doel", 10))
	_tijd_over = float(c.get("duur", 60))
	_interval = float(c.get("spawn_start", 1.3))
	_interval_min = float(c.get("spawn_min", 0.55))
	_zichtbaar = float(c.get("zichtbaar", 1.5))
	_bug_kans = float(c.get("bug_kans", 0.65))

	var body := build_chrome(String(c.get("titel", default_title())), String(c.get("intro", "")))

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 34)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(grid)

	for i: int in HOLES:
		var h := Hole.new()
		h.hit.connect(_on_hit)
		grid.add_child(h)
		_holes.append(h)

	_melding = UiKit.label("", UiKit.FS_SMALL, UiKit.ROOD)
	_melding.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_melding)

	_running = true
	_update_status()


func _process(delta: float) -> void:
	if not _running:
		return

	_tijd_over -= delta
	_spawn_t -= delta
	_update_status()

	if _spawn_t <= 0.0:
		_spawn_t = _interval
		_spawn()

	if _tijd_over <= 0.0:
		_running = false
		var c := content()
		await finish_with_banner(false, String(c.get("failure", "De tijd is om.")), _gevangen)


func _spawn() -> void:
	var vrij: Array[Hole] = []
	var actief := 0
	for h: Hole in _holes:
		if h.active:
			actief += 1
		else:
			vrij.append(h)
	if vrij.is_empty() or actief >= 2:
		return
	var h: Hole = vrij[randi() % vrij.size()]
	h.pop(randf() < _bug_kans, _zichtbaar)
	AudioDirector.play_ui(&"hinnik")


func _on_hit(h: Hole) -> void:
	if not _running or not h.active:
		return
	var c := content()

	if h.is_bug:
		_gevangen += 1
		_interval = maxf(_interval_min, _interval * 0.92)
		_melding.text = ""
		AudioDirector.play_ui(&"raak")
		h.clear()
		if _gevangen >= _doel:
			_running = false
			await finish_with_banner(true, String(c.get("success", "Alle bugs opgeruimd.")), _gevangen)
		else:
			_update_status()
	else:
		_tijd_over = maxf(1.0, _tijd_over - 3.0)
		_melding.text = String(c.get("straf_tekst", "JE HEBT EEN KLANTPAARD GESLAGEN"))
		AudioDirector.play_ui(&"fout")
		h.clear()


func _update_status() -> void:
	set_status("bugs %d/%d   ·   %02d sec" % [_gevangen, _doel, maxi(0, ceili(_tijd_over))])


## QA: slaat via de echte trefroutine bugpaarden tot het doel gehaald is.
func qa_solve() -> void:
	if not _running:
		return
	var h: Hole = _holes[0]
	h.pop(true, _zichtbaar)
	_on_hit(h)
