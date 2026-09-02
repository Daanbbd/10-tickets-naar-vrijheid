extends MinigameBase
## Dialoogkeuzes met punten. Draagt BBD-203 (klantfeedback), en verder niets:
## de finale is een eigen mechaniek geworden (`mg_oplevering`).

var _ronde: int = 0
var _score: int = 0
var _drempel: int = 6
var _prompt: Label = null
var _reactie: Label = null
var _opties: VBoxContainer = null


func _on_setup() -> void:
	var c := content()
	if c.is_empty():
		fail()
		return
	_drempel = int(c.get("drempel", 6))

	var body := build_chrome(String(c.get("titel", default_title())), String(c.get("intro", "")))

	var pp := PanelContainer.new()
	pp.add_theme_stylebox_override("panel", UiKit.panel(UiKit.PAPIER, UiKit.LINE))
	body.add_child(pp)
	_prompt = UiKit.label("", UiKit.FS_BODY, UiKit.INK)
	_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pp.add_child(_prompt)

	_opties = VBoxContainer.new()
	_opties.add_theme_constant_override("separation", 2)
	_opties.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_opties)

	_reactie = UiKit.label("", UiKit.FS_SMALL, UiKit.BLUEBIRD_INK)
	_reactie.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_reactie)

	_show_ronde()


func _show_ronde() -> void:
	var c := content()
	var rondes: Array = c.get("rondes", [])
	if _ronde >= rondes.size():
		_afronden()
		return

	var r := rondes[_ronde] as Dictionary
	_prompt.text = String(r.get("prompt", ""))
	set_status("Vraag %d/%d   ·   score %d" % [_ronde + 1, rondes.size(), _score])

	for ch: Node in _opties.get_children():
		ch.queue_free()
		_opties.remove_child(ch)

	for raw: Variant in r.get("opties", []):
		var o := raw as Dictionary
		if not Conditions.check(o.get("when", {}) as Dictionary):
			continue
		var b := UiKit.keuzeknop(String(o.get("tekst", "...")), UiKit.FS_SMALL)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(_pick.bind(o))
		_opties.add_child(b)

	if _opties.get_child_count() > 0:
		(_opties.get_child(0) as Button).grab_focus()


func _pick(o: Dictionary) -> void:
	_score += int(o.get("punten", 0))
	_reactie.text = String(o.get("reactie", ""))
	AudioDirector.play_ui(&"klik")
	_ronde += 1
	await get_tree().create_timer(0.9, true).timeout
	_show_ronde()


func _afronden() -> void:
	var c := content()
	if _score >= _drempel:
		await finish_with_banner(true, String(c.get("success", "Goed afgehandeld.")), _score)
	else:
		await finish_with_banner(false, String(c.get("failure", "Dat ging niet lekker.")), _score)


## QA: kiest per ronde de optie met de meeste punten.
func qa_solve() -> void:
	var rondes: Array = content().get("rondes", [])
	if _ronde >= rondes.size():
		return
	var beste: Dictionary = {}
	var beste_pt := -1
	for raw: Variant in (rondes[_ronde] as Dictionary).get("opties", []):
		var o := raw as Dictionary
		if not Conditions.check(o.get("when", {}) as Dictionary):
			continue
		if int(o.get("punten", 0)) > beste_pt:
			beste_pt = int(o.get("punten", 0))
			beste = o
	if not beste.is_empty():
		_pick(beste)
