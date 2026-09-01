extends MinigameBase
## Sleep-kaartjes-naar-vakken. Gedeelde mechaniek voor BBD-201 (user story),
## BBD-202 (planning), BBD-204 (frontend) en BBD-206 (CRO-pagina).
##
## Er zijn altijd meer kaarten dan vakken: de afleiders zijn de grap.

const CARD_W := 84
const CARD_H := 20


class DragCard extends PanelContainer:
	var card_id: String = ""
	var text: String = ""
	var tint: Color = UiKit.PANEL
	var board: Node = null

	func _init(id: String, t: String, col: Color, b: Node) -> void:
		card_id = id
		text = t
		tint = col
		board = b
		custom_minimum_size = Vector2(84, 20)
		mouse_filter = Control.MOUSE_FILTER_STOP
		add_theme_stylebox_override("panel", UiKit.panel(tint, UiKit.LINE))
		var l := UiKit.label(t, UiKit.FS_SMALL, UiKit.INK)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(l)

	func _get_drag_data(_pos: Vector2) -> Variant:
		var ghost := PanelContainer.new()
		ghost.add_theme_stylebox_override("panel", UiKit.panel(tint, UiKit.BLUEBIRD_INK, 2))
		ghost.custom_minimum_size = Vector2(84, 20)
		var gl := UiKit.label(text, UiKit.FS_SMALL, UiKit.INK)
		gl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ghost.add_child(gl)
		set_drag_preview(ghost)
		AudioDirector.play_ui(&"pak")
		return {"card_id": card_id, "node": self}

	func _gui_input(event: InputEvent) -> void:
		# Klikken haalt een geplaatste kaart terug: sleuren is niet verplicht.
		if event is InputEventMouseButton and event.pressed \
				and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			board.call(&"return_card", self)


class DropSlot extends PanelContainer:
	var accepts: Array = []
	var slot_label: String = ""
	var holder: HBoxContainer = null
	var board: Node = null

	func _init(lbl: String, acc: Array, b: Node) -> void:
		slot_label = lbl
		accepts = acc
		board = b
		custom_minimum_size = Vector2(88, 46)
		add_theme_stylebox_override("panel", UiKit.panel(Color("#e6e1d4"), UiKit.LINE))
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 1)
		add_child(v)
		var l := UiKit.label(lbl, UiKit.FS_SMALL, UiKit.GRIJS)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(l)
		holder = HBoxContainer.new()
		holder.custom_minimum_size = Vector2(84, 20)
		holder.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_child(holder)

	func is_filled() -> bool:
		return holder.get_child_count() > 0

	func card() -> DragCard:
		return holder.get_child(0) as DragCard if is_filled() else null

	func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
		return data is Dictionary and (data as Dictionary).has("card_id") and not is_filled()

	func _drop_data(_pos: Vector2, data: Variant) -> void:
		board.call(&"place_card", (data as Dictionary)["node"], self)


var _slots: Array[DropSlot] = []
var _pool: HFlowContainer = null
var _fouten: int = 0
var _max_fouten: int = 2


func _on_setup() -> void:
	var c := content()
	if c.is_empty():
		fail()
		return

	_max_fouten = int(c.get("max_fouten", 2))
	var body := build_chrome(String(c.get("titel", default_title())), String(c.get("intro", "")))

	var slot_row := HBoxContainer.new()
	slot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	slot_row.add_theme_constant_override("separation", 3)
	body.add_child(slot_row)
	for raw: Variant in c.get("slots", []):
		var sd := raw as Dictionary
		var s := DropSlot.new(String(sd.get("label", "")), sd.get("accepts", []) as Array, self)
		slot_row.add_child(s)
		_slots.append(s)

	body.add_child(UiKit.label("Sleep de kaartjes naar het juiste vak. Klik een geplaatst kaartje om het terug te halen.",
		UiKit.FS_SMALL, UiKit.GRIJS))

	_pool = HFlowContainer.new()
	_pool.add_theme_constant_override("h_separation", 3)
	_pool.add_theme_constant_override("v_separation", 3)
	_pool.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_pool)

	for raw: Variant in c.get("cards", []):
		var cd := raw as Dictionary
		# Bewust ALLE kaarten neutraal: de tint uit de data zou het antwoord verklappen.
		_pool.add_child(DragCard.new(String(cd.get("id", "")), String(cd.get("text", "")),
			UiKit.PANEL, self))

	var check := UiKit.button("Controleren", UiKit.FS_BODY)
	check.pressed.connect(_check)
	body.add_child(check)

	_update_status()


# --- Sleepacties (aangeroepen door de inner classes) ----------------------

func place_card(card: DragCard, slot: DropSlot) -> void:
	if slot.is_filled():
		return
	card.get_parent().remove_child(card)
	slot.holder.add_child(card)
	AudioDirector.play_ui(&"klik")
	_update_status()


func return_card(card: DragCard) -> void:
	if card.get_parent() == _pool:
		return
	card.get_parent().remove_child(card)
	_pool.add_child(card)
	AudioDirector.play_ui(&"klik")
	_update_status()


func _update_status() -> void:
	var filled := 0
	for s: DropSlot in _slots:
		if s.is_filled():
			filled += 1
	set_status("%d/%d ingevuld   ·   fouten %d/%d" % [filled, _slots.size(), _fouten, _max_fouten])


# --- Nakijken -------------------------------------------------------------

func _check() -> void:
	var c := content()
	var missing := 0
	var wrong: Array[DropSlot] = []

	for s: DropSlot in _slots:
		if not s.is_filled():
			missing += 1
			continue
		if not (s.card().card_id in s.accepts):
			wrong.append(s)

	if missing > 0:
		set_status("Er zijn nog %d vakken leeg." % missing)
		AudioDirector.play_ui(&"fout")
		return

	if wrong.is_empty():
		await finish_with_banner(true, String(c.get("success", "Klaar.")), 100)
		return

	_fouten += 1
	for s: DropSlot in wrong:
		s.add_theme_stylebox_override("panel", UiKit.panel(Color("#f6e2e4"), UiKit.ROOD, 2))
		return_card(s.card())
	AudioDirector.play_ui(&"fout")

	if _fouten >= _max_fouten:
		await finish_with_banner(false, String(c.get("failure", "Dit klopt niet.")))
	else:
		set_status("%d kaartjes stonden verkeerd. Nog %d poging(en)." % [wrong.size(), _max_fouten - _fouten])


## QA: legt de juiste kaart in elk vak en drukt op controleren.
func qa_solve() -> void:
	for s: DropSlot in _slots:
		if s.is_filled():
			continue
		for n: Node in _pool.get_children():
			var c := n as DragCard
			if c != null and c.card_id in s.accepts:
				place_card(c, s)
				break
	_check()
