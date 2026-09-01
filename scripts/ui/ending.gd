extends Control
## Het einde. Je loopt naar buiten, en dan gaat je telefoon.

const REGELS: Array[String] = [
	"Je pakt je jas van de kapstok.",
	"Dezelfde jas als vanochtend. Het voelt langer geleden.",
	"De deur valt achter je dicht.",
	"17:31.",
]

var _tekst: Label
var _ping: VBoxContainer


func _ready() -> void:
	UiKit.full_rect(self)
	var bg := ColorRect.new()
	bg.color = Color("#0b0d14")
	UiKit.full_rect(bg)
	add_child(bg)

	_tekst = UiKit.label("", UiKit.FS_BODY, UiKit.WIT)
	_tekst.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tekst.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tekst.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tekst.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_tekst)

	_bouw_ping()
	_speel()


func _bouw_ping() -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.panel(UiKit.PANEL, UiKit.INK, 2))
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.anchor_left = 0.5; p.anchor_right = 0.5
	p.anchor_top = 0.5; p.anchor_bottom = 0.5
	p.offset_left = -130; p.offset_right = 130
	p.offset_top = -26; p.offset_bottom = 26
	p.modulate.a = 0.0
	add_child(p)

	_ping = VBoxContainer.new()
	_ping.add_theme_constant_override("separation", 2)
	p.add_child(_ping)
	_ping.add_child(UiKit.label("JIRA", UiKit.FS_SMALL, UiKit.BLUEBIRD_INK))
	var kop := UiKit.label("23 NIEUWE TICKETS AAN JOU TOEGEWEZEN", UiKit.FS_BODY, UiKit.INK)
	kop.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	kop.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ping.add_child(kop)
	_ping.set_meta("panel", p)


func _speel() -> void:
	AudioDirector.stop_music(0.6)
	await get_tree().create_timer(0.8).timeout

	for regel: String in REGELS:
		await _toon(regel)

	await get_tree().create_timer(1.0).timeout

	AudioDirector.play_ui(&"interactie")
	var p := _ping.get_meta("panel") as PanelContainer
	var tw := create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.2)
	await tw.finished

	await get_tree().create_timer(3.2).timeout

	var slot := UiKit.label("EINDE", UiKit.FS_HEAD, UiKit.BLUEBIRD_BRIGHT)
	slot.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	slot.anchor_left = 0.5; slot.anchor_right = 0.5
	slot.anchor_top = 1.0; slot.anchor_bottom = 1.0
	slot.offset_left = -60; slot.offset_right = 60
	slot.offset_top = -40; slot.offset_bottom = -22
	slot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(slot)

	var terug := UiKit.button("Terug naar het begin", UiKit.FS_SMALL)
	terug.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	terug.anchor_left = 0.5; terug.anchor_right = 0.5
	terug.anchor_top = 1.0; terug.anchor_bottom = 1.0
	terug.offset_left = -70; terug.offset_right = 70
	terug.offset_top = -20; terug.offset_bottom = -6
	terug.pressed.connect(func() -> void: Shell.goto_title())
	add_child(terug)
	terug.grab_focus()


func _toon(regel: String) -> void:
	_tekst.text = regel
	_tekst.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_tekst, "modulate:a", 1.0, 0.5)
	tw.tween_interval(1.5)
	tw.tween_property(_tekst, "modulate:a", 0.0, 0.5)
	await tw.finished
