extends MinigameBase
## Verbind knooppunten met kabels. Draagt BBD-205 (datastroom herstellen), en
## verder niets: de finale is een eigen mechaniek geworden (`mg_oplevering`).
##
## Klik een knooppunt, klik een tweede: er loopt een kabel. Nog eens klikken
## op een bestaande kabel haalt hem weg.

class NodeBtn extends PanelContainer:
	var node_id: String = ""
	var board: Node = null
	signal picked(id: String)

	func _init(id: String, label: String, b: Node) -> void:
		node_id = id
		board = b
		custom_minimum_size = Vector2(96, 22)
		add_theme_stylebox_override("panel", UiKit.panel(UiKit.PANEL, UiKit.LINE))
		var l := UiKit.label(label, UiKit.FS_SMALL, UiKit.INK)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(l)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed \
				and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			picked.emit(node_id)

	func highlight(on: bool) -> void:
		add_theme_stylebox_override("panel",
			UiKit.panel(UiKit.WIT if on else UiKit.PANEL, UiKit.BLUEBIRD_INK if on else UiKit.LINE, 2 if on else 1))


class CableLines extends Control:
	var board: Node = null

	func _draw() -> void:
		for pair: Array in board.get("_cables"):
			var a: Control = board.call(&"node_ctrl", pair[0])
			var b: Control = board.call(&"node_ctrl", pair[1])
			if a == null or b == null:
				continue
			var pa := a.get_global_rect().get_center() - global_position
			var pb := b.get_global_rect().get_center() - global_position
			# De kabel loopt over het donkere oppervlak van de chrome; bb-blue is
			# daar nauwelijks van de ondergrond te onderscheiden. De stippen aan de
			# uiteinden liggen wél op een licht knooppunt en blijven dus INK.
			draw_line(pa, pb, UiKit.BLUEBIRD_BRIGHT, 2.0, true)
			draw_circle(pa, 2.5, UiKit.INK)
			draw_circle(pb, 2.5, UiKit.INK)


var _nodes: Dictionary = {}       ## id -> NodeBtn
var _cables: Array = []           ## [[id_a, id_b], ...]
var _selected: String = ""
var _lines: CableLines = null
var _fouten: int = 0


func _on_setup() -> void:
	var c := content()
	if c.is_empty():
		fail()
		return

	var body := build_chrome(String(c.get("titel", default_title())), String(c.get("intro", "")))

	var stack := Control.new()
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(stack)

	var cols := HBoxContainer.new()
	UiKit.full_rect(cols)
	cols.add_theme_constant_override("separation", 4)
	stack.add_child(cols)

	var by_col := {}
	for raw: Variant in c.get("nodes", []):
		var n := raw as Dictionary
		var k := int(n.get("kolom", 0))
		if not by_col.has(k):
			by_col[k] = []
		(by_col[k] as Array).append(n)

	var keys := by_col.keys()
	keys.sort()
	for k: Variant in keys:
		var v := VBoxContainer.new()
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_theme_constant_override("separation", 4)
		v.size_flags_vertical = Control.SIZE_EXPAND_FILL
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cols.add_child(v)
		for raw: Variant in by_col[k]:
			var n := raw as Dictionary
			var id := String(n.get("id", ""))
			var btn := NodeBtn.new(id, String(n.get("label", id)), self)
			btn.picked.connect(_on_pick)
			v.add_child(btn)
			_nodes[id] = btn

	_lines = CableLines.new()
	_lines.board = self
	UiKit.full_rect(_lines)
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(_lines)

	var check := UiKit.knop_primair("Verbinding testen", UiKit.FS_BODY)
	check.pressed.connect(_check)
	body.add_child(check)

	set_status("Tik twee knooppunten aan om ze te verbinden.")


func node_ctrl(id: String) -> Control:
	return _nodes.get(id, null) as Control


func _on_pick(id: String) -> void:
	AudioDirector.play_ui(&"klik")
	if _selected == "":
		_selected = id
		(_nodes[id] as NodeBtn).highlight(true)
		return
	if _selected == id:
		(_nodes[id] as NodeBtn).highlight(false)
		_selected = ""
		return

	var pair := [_selected, id]
	var existing := _find_cable(_selected, id)
	if existing >= 0:
		_cables.remove_at(existing)
	else:
		_cables.append(pair)

	(_nodes[_selected] as NodeBtn).highlight(false)
	_selected = ""
	_lines.queue_redraw()
	set_status("%d verbinding(en)" % _cables.size())


func _find_cable(a: String, b: String) -> int:
	for i: int in _cables.size():
		var p: Array = _cables[i]
		if (p[0] == a and p[1] == b) or (p[0] == b and p[1] == a):
			return i
	return -1


func _check() -> void:
	var c := content()
	var required: Array = c.get("verbindingen", [])
	var ok := true

	for raw: Variant in required:
		var p := raw as Array
		if _find_cable(String(p[0]), String(p[1])) < 0:
			ok = false
			break

	if ok and _cables.size() != required.size():
		ok = false   # extra kabels tellen als fout

	if ok:
		await finish_with_banner(true, String(c.get("success", "Er stroomt weer data.")), 100)
		return

	_fouten += 1
	AudioDirector.play_ui(&"fout")
	if _fouten >= int(c.get("max_fouten", 3)):
		await finish_with_banner(false, String(c.get("failure", "Nog steeds undefined.")))
	else:
		set_status("Nog niet goed. Controleer de volgorde van de lagen.")


## QA: legt precies de gevraagde verbindingen en test ze.
func qa_solve() -> void:
	_cables.clear()
	for raw: Variant in content().get("verbindingen", []):
		var pr := raw as Array
		_cables.append([String(pr[0]), String(pr[1])])
	_lines.queue_redraw()
	_check()
