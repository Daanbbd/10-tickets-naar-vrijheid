extends Control
## Karakterselectie. Je kiest één collega en speelt de hele dag als hem.

var _cards: Array[PanelContainer] = []
var _ids: Array[StringName] = []
var _detail: VBoxContainer
var _index: int = 0


func _ready() -> void:
	UiKit.full_rect(self)
	var bg := ColorRect.new()
	bg.color = Color("#141824")
	UiKit.full_rect(bg)
	add_child(bg)

	var root := VBoxContainer.new()
	UiKit.full_rect(root)
	root.offset_left = 12; root.offset_right = -12
	root.offset_top = 8; root.offset_bottom = -8
	root.add_theme_constant_override("separation", 4)
	add_child(root)

	var head := UiKit.label("WIE BEN JIJ VANDAAG?", UiKit.FS_HEAD, UiKit.BLUEBIRD_BRIGHT)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(head)

	var sub := UiKit.label("Je kunt tijdens de dag niet wisselen. Zo werkt dat hier niet.",
		UiKit.FS_SMALL, UiKit.GRIJS)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(sub)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	root.add_child(row)

	for id: StringName in GameData.character_ids():
		var c: CharacterDef = GameData.character(id)
		_ids.append(id)
		row.add_child(_make_card(c))

	var detail_panel := PanelContainer.new()
	detail_panel.add_theme_stylebox_override("panel", UiKit.panel(UiKit.PANEL, UiKit.LINE))
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(detail_panel)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 1)
	detail_panel.add_child(_detail)

	var go := UiKit.button("Aan het werk", UiKit.FS_BODY)
	go.pressed.connect(_start)
	root.add_child(go)

	_select(0)

	# QA: `--scherm=select --autostart` doorloopt de normale startroute.
	if "--autostart" in OS.get_cmdline_user_args():
		await get_tree().create_timer(0.3).timeout
		_start()


func _make_card(c: CharacterDef) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.panel(UiKit.PANEL, UiKit.LINE))
	p.custom_minimum_size = Vector2(84, 76)
	_cards.append(p)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	p.add_child(v)

	var portrait := TextureRect.new()
	portrait.texture = _portrait_for(c)
	portrait.custom_minimum_size = Vector2(48, 52)
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	v.add_child(portrait)

	var n := UiKit.label(c.name, UiKit.FS_BODY, UiKit.INK)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(n)

	var r := UiKit.label(c.role, UiKit.FS_SMALL, UiKit.GRIJS)
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(r)

	var btn := Button.new()
	btn.flat = true
	UiKit.full_rect(btn)
	btn.pressed.connect(_on_card.bind(_cards.size() - 1))
	p.add_child(btn)
	return p


## Voorkeur voor het pixel-portret dat uit de echte teamfoto is afgeleid;
## anders de sprite zelf.
func _portrait_for(c: CharacterDef) -> Texture2D:
	if c.portrait != "" and ResourceLoader.exists(c.portrait):
		return load(c.portrait)
	var sf := CharacterSprites.frames_for(c.look, c.color, c.skin, c.hair, c.pants, c.accent)
	return sf.get_frame_texture(&"idle_down", 0)


func _on_card(i: int) -> void:
	AudioDirector.play_ui(&"klik")
	_select(i)


func _select(i: int) -> void:
	_index = i
	for j: int in _cards.size():
		var chosen := j == i
		_cards[j].add_theme_stylebox_override("panel",
			UiKit.panel(UiKit.BLUEBIRD_TINT if chosen else UiKit.PANEL,
				UiKit.BLUEBIRD_INK if chosen else UiKit.LINE, 2 if chosen else 1))

	for ch: Node in _detail.get_children():
		ch.queue_free()
		_detail.remove_child(ch)

	var c: CharacterDef = GameData.character(_ids[i])
	_detail.add_child(UiKit.label("%s / %s" % [c.name, c.role], UiKit.FS_BODY, UiKit.INK))
	var tag := UiKit.label(c.tagline, UiKit.FS_SMALL, UiKit.BLUEBIRD_INK)
	_detail.add_child(tag)
	var desc := UiKit.label(c.description, UiKit.FS_SMALL, UiKit.INK)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(desc)
	_detail.add_child(UiKit.label("Sterk in: " + ", ".join(c.specialisms), UiKit.FS_SMALL, UiKit.GRIJS))

	# Twee ticketcodes zonder referent zeggen niets. De kernregel wel: dit is het
	# enige moment waarop de speler echt zit te lezen.
	var eigen: int = 0
	for t: StringName in c.owned_tickets:
		if GameData.ticket(t) != null:
			eigen += 1
	var regel := UiKit.label(
		"Jij lost %d van de %d tickets zelf op. Voor de rest haal je een collega." % [
			eigen, GameData.ticket_ids().size()],
		UiKit.FS_SMALL, UiKit.GROEN)
	regel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(regel)


func _start() -> void:
	AudioDirector.play_ui(&"klik")
	Session.start_new(_ids[_index])
	QuestEngine.initialise_tickets()
	Shell.goto_game()
