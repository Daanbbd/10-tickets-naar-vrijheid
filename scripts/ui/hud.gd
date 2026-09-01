class_name Hud
extends CanvasLayer
## Ticketteller, doelregel, interactieprompt, zonenaam, toasts, besturingskaart
## en ticketbord. De inventaris zit in het bord, niet permanent op het scherm.

## Portretcanvas van 192 px breed: alles hangt aan de randen in plaats van
## aan vaste pixelposities uit de oude 480x270-indeling.
const MARGE := 4

## Hoe lang een nieuw briefje in beeld blijft. Dit gebeurt tien keer per
## speelbeurt, dus het mag nooit in de weg gaan zitten.
const BRIEFJE_ZICHTBAAR := 1.4

const NUDGE_NA := 45.0          ## seconden zonder voortgang voor een gratis hint
const KAART_ZICHTBAAR := 9.0

var _prompt: PanelContainer
var _prompt_label: Label
var _counter: Label
var _objective: PanelContainer
var _objective_label: Label
var _zone: Label
var _zone_tween: Tween = null
var _toasts: VBoxContainer
var _board: Control
var _bord: Scrumbord
var _card: PanelContainer
var _card_tween: Tween = null
var _nudge: Timer


func setup() -> void:
	layer = 10
	var root := UiKit.full_rect(Control.new())
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# --- ticketteller linksboven ---
	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", UiKit.panel(UiKit.PANEL_DARK, UiKit.INK))
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = MARGE
	top.offset_right = -MARGE
	top.offset_top = MARGE
	root.add_child(top)
	_counter = UiKit.label("", UiKit.FS_BODY, UiKit.WIT)
	top.add_child(_counter)

	# --- doelregel, direct onder de teller, permanent zichtbaar ---
	# Dit is het antwoord op "ik weet niet waar ik moet beginnen": er staat
	# altijd precies een doel op het scherm, ook als de DAG er twee openzet.
	_objective = PanelContainer.new()
	#half-doorzichtig: het paneel staat linksboven en dekte daar anders de
	# bovenrand van de wereld af.
	_objective.add_theme_stylebox_override("panel",
		UiKit.panel(Color(UiKit.PANEL_DARK, 0.80), UiKit.ORANJE))
	_objective.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_objective.offset_left = MARGE
	_objective.offset_right = -MARGE
	_objective.offset_top = MARGE + 18
	root.add_child(_objective)
	_objective_label = UiKit.label("", UiKit.FS_SMALL, UiKit.WIT)
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective.add_child(_objective_label)

	# --- zonenaam onderaan ---
	_zone = UiKit.label("", UiKit.FS_BODY, UiKit.WIT)
	_zone.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_zone.anchor_left = 0.5
	_zone.anchor_right = 0.5
	_zone.anchor_top = 1.0
	_zone.anchor_bottom = 1.0
	_zone.offset_top = -30
	_zone.offset_bottom = -16
	_zone.offset_left = -90
	_zone.offset_right = 90
	_zone.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zone.modulate.a = 0.0
	root.add_child(_zone)

	# --- interactieprompt ---
	_prompt = PanelContainer.new()
	_prompt.add_theme_stylebox_override("panel", UiKit.panel(UiKit.PANEL, UiKit.INK))
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.anchor_left = 0.5
	_prompt.anchor_right = 0.5
	_prompt.anchor_top = 1.0
	_prompt.anchor_bottom = 1.0
	_prompt.offset_top = -50
	_prompt.offset_bottom = -32
	_prompt.offset_left = -90
	_prompt.offset_right = 90
	_prompt.visible = false
	root.add_child(_prompt)
	_prompt_label = UiKit.label("", UiKit.FS_SMALL)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_child(_prompt_label)

	# --- toasts rechtsboven ---
	_toasts = VBoxContainer.new()
	_toasts.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_toasts.anchor_left = 1.0
	_toasts.anchor_right = 1.0
	_toasts.offset_left = -(192 - MARGE * 2)
	_toasts.offset_right = -MARGE
	_toasts.offset_top = 46
	_toasts.alignment = BoxContainer.ALIGNMENT_END
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_toasts)

	_build_card(root)
	_build_board(root)

	_nudge = Timer.new()
	_nudge.one_shot = true
	_nudge.wait_time = NUDGE_NA
	_nudge.timeout.connect(_on_nudge)
	add_child(_nudge)
	_nudge.start()

	Bus.interaction_prompt_changed.connect(_on_prompt)
	Bus.ticket_state_changed.connect(func(_a: StringName, _b: GameEnums.TicketState) -> void: _refresh())
	Bus.ticket_completed.connect(func(_a: StringName, _b: MinigameResult) -> void: _refresh())
	Bus.item_added.connect(func(_a: StringName, _b: int) -> void: _refresh())
	Bus.item_removed.connect(func(_a: StringName, _b: int) -> void: _refresh())
	Bus.toast_requested.connect(_on_toast)
	Bus.zone_entered.connect(_on_zone)
	Bus.hint_requested.connect(_on_hint)
	Bus.input_lock_changed.connect(_on_input_lock)

	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_panel"):
		get_viewport().set_input_as_handled()
		toggle_controls_card()


# --- Besturingskaart -----------------------------------------------------

func _build_card(root: Control) -> void:
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", UiKit.panel(UiKit.PANEL_DARK, UiKit.INK))
	_card.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_card.anchor_left = 1.0
	_card.anchor_top = 1.0
	_card.anchor_right = 1.0
	_card.anchor_bottom = 1.0
	_card.offset_left = -(192 - MARGE * 2)
	_card.offset_top = -78
	_card.offset_right = -MARGE
	_card.offset_bottom = -MARGE
	_card.modulate.a = 0.0
	_card.visible = false
	root.add_child(_card)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	_card.add_child(v)
	for regel: String in [
		"WASD  lopen        Shift  rennen",
		"E     praten / bekijken",
		"TAB   ticketbord   Q  hint",
		"F1    deze kaart",
	]:
		v.add_child(UiKit.label(regel, UiKit.FS_SMALL, UiKit.WIT))


## Laat de kaart even zien en fade hem daarna weg. F1 haalt hem terug.
func show_controls_card(duur: float = KAART_ZICHTBAAR) -> void:
	if _card_tween != null and _card_tween.is_running():
		_card_tween.kill()
	_card.visible = true
	_card_tween = create_tween()
	_card_tween.tween_property(_card, "modulate:a", 1.0, 0.25)
	_card_tween.tween_interval(duur)
	_card_tween.tween_property(_card, "modulate:a", 0.0, 0.6)
	_card_tween.tween_callback(func() -> void: _card.visible = false)


func toggle_controls_card() -> void:
	if _card.visible and _card.modulate.a > 0.5:
		if _card_tween != null and _card_tween.is_running():
			_card_tween.kill()
		_card_tween = create_tween()
		_card_tween.tween_property(_card, "modulate:a", 0.0, 0.2)
		_card_tween.tween_callback(func() -> void: _card.visible = false)
	else:
		show_controls_card(20.0)
	AudioDirector.play_ui(&"klik")


# --- Ticketbord -----------------------------------------------------------

func _build_board(root: Control) -> void:
	_board = UiKit.full_rect(Control.new())
	_board.visible = false
	_board.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_board)
	_board.add_child(UiKit.dimmer(0.78))

	_bord = Scrumbord.new()
	UiKit.full_rect(_bord)
	_bord.bouw(false)
	_board.add_child(_bord)

	_bord.toon_sluitregel("TAB  sluiten")


func toggle_board(close_up: bool = false) -> void:
	_board.visible = not _board.visible
	AudioDirector.play_ui(&"klik")
	if _board.visible:
		_bord.zet_close_up(close_up)
		_fill_board()


## Het bord openen en een net gevonden briefje zien landen. Dit is wat een
## ticket vinden tot een moment maakt in plaats van een regel in een lijst.
func toon_nieuw_briefje(t: TicketDef) -> void:
	# Tijdens een geautomatiseerde speelbeurt niets tonen: die drukt geen toets
	# in om weg te klikken en zou hier blijven hangen.
	if t == null or _board.visible or Autopilot.gevraagd():
		return
	_board.visible = true
	_bord.zet_close_up(true)
	_fill_board()
	_bord.laat_briefje_landen(t)
	await get_tree().create_timer(BRIEFJE_ZICHTBAAR, true, false, true).timeout
	_board.visible = false


func _fill_board() -> void:
	if _bord != null:
		_bord.vul()


## "Jij kunt dit zelf" of de naam van de collega die je moet ophalen — met de
## ruimte waar hij staat, want de werkelijke kosten van ophalen zijn zoektijd.
static func _wie(t: TicketDef) -> String:
	if QuestEngine.is_own_expertise(t.id):
		return "Jij kunt dit zelf"
	var d: NpcDef = GameData.npc(QuestEngine.required_helper(t.id))
	if d == null:
		return "Vraag: %s" % t.owner_role
	var waar := _zone_naam(d.zone)
	return "Haal %s%s" % [d.name, "" if waar == "" else " uit %s" % waar]


static func _zone_naam(zone_id: StringName) -> String:
	if zone_id == &"":
		return ""
	for z: Variant in (GameData.floor_data.get("zones", []) as Array):
		var d := z as Dictionary
		if StringName(d.get("id", "")) == zone_id:
			return String(d.get("name", ""))
	return ""


# --- Reacties -------------------------------------------------------------

func _refresh() -> void:
	_counter.text = "Tickets  %d/%d" % [Session.done_count(), Session.total_tickets()]
	_refresh_objective()
	_refresh_items()
	if _board.visible:
		_fill_board()
	if _nudge != null:
		_nudge.start()


## Altijd precies een doel, ook als de DAG er twee openzet.
func _refresh_objective() -> void:
	var t: TicketDef = QuestEngine.next_hint_ticket()
	if t == null:
		_objective_label.text = "Nu:  alles is opgelost — ga naar de voordeur"
		return
	_objective_label.text = "Nu:  %s  ·  %s  ·  %s" % [t.code, t.zone_name, _wie(t)]


func _refresh_items() -> void:
	var namen: Array[String] = []
	for id: StringName in Session.items_owned():
		var it: ItemDef = GameData.item(id)
		if it != null:
			namen.append(it.name)
	if _bord != null:
		_bord.toon_inventaris("Bij je: %s" % ", ".join(namen) if not namen.is_empty() else "")


## Wie dit ticket bezit hoort zichtbaar te zijn vóór de interactie, niet pas
## nadat de speler er vergeefs op E heeft gedrukt.
func _on_prompt(text: String, shown: bool, world_id: StringName) -> void:
	_prompt.visible = shown and not Session.input_locked
	_prompt_label.text = "E   %s%s" % [text, _eigenaar_suffix(world_id)]


static func _eigenaar_suffix(world_id: StringName) -> String:
	if world_id == &"":
		return ""
	for id: StringName in GameData.ticket_ids():
		var t: TicketDef = GameData.ticket(id)
		if t == null or t.anchor != world_id or not Session.is_available(id):
			continue
		if QuestEngine.is_own_expertise(id):
			return ""
		var d: NpcDef = GameData.npc(QuestEngine.required_helper(id))
		return " (%s)" % (d.name if d != null else t.owner_role)
	return ""


## De dialoogbox (layer 20) dekt de prompt en de zonenaam (layer 10) af. Verberg
## ze dus zolang de input op slot staat, in plaats van ze eronder te laten staan.
func _on_input_lock(locked: bool) -> void:
	if locked:
		_prompt.visible = false
		_zone.modulate.a = 0.0


func _on_toast(text: String, _icon: StringName) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.panel(UiKit.PANEL_DARK, UiKit.INK))
	var l := UiKit.label(text, UiKit.FS_SMALL, UiKit.WIT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.add_child(l)
	_toasts.add_child(p)
	var tw := create_tween()
	tw.tween_interval(2.6)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)


## Kill-before-recreate: langs een deuropening lopen hertriggert zone_entered op
## elke tile-overgang, en stapelende tweens vechten om dezelfde alpha.
func _on_zone(_id: StringName, zone_name: String) -> void:
	_zone.text = zone_name
	if _zone_tween != null and _zone_tween.is_running():
		_zone_tween.kill()
	_zone_tween = create_tween()
	_zone_tween.tween_property(_zone, "modulate:a", 1.0, 0.25)
	_zone_tween.tween_interval(1.6)
	_zone_tween.tween_property(_zone, "modulate:a", 0.0, 0.6)


func _on_hint() -> void:
	if _nudge != null:
		_nudge.start()
	var t: TicketDef = QuestEngine.next_hint_ticket()
	if t == null:
		Bus.toast_requested.emit("Alles is opgelost. Ga naar de voordeur.", &"hint")
		return
	# De hint zelf hoort erbij: die stond alleen op het TAB-bord.
	Bus.toast_requested.emit("%s — %s. %s %s" % [t.code, t.zone_name, _wie(t) + ".", t.hint], &"hint")


## Niemand hoort langer dan 45 seconden vast te zitten. Dit leert bovendien
## wat Q doet, door het een keer voor te doen.
func _on_nudge() -> void:
	if Session.input_locked or Shell.minigame_active():
		_nudge.start()
		return
	Bus.hint_requested.emit()
