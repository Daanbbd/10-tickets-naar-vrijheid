extends MinigameBase
## Kies N tags, de combinatie bepaalt de uitkomst. Een Suno/AI-generator-parodie.
## Gedeeld door BBD-207 (merksound) en BBD-208 (AI-video).

var _picked: Array[String] = []
var _buttons: Dictionary = {}     ## tag_id -> Button
var _kies: int = 3
var _pogingen_over: int = 4
var _result_panel: PanelContainer = null
var _result_title: Label = null
var _result_text: Label = null
var _generate: Button = null


func _on_setup() -> void:
	var c := content()
	if c.is_empty():
		fail()
		return

	_kies = int(c.get("kies", 3))
	_pogingen_over = int(c.get("pogingen", 4))

	var body := build_chrome(String(c.get("titel", default_title())), String(c.get("intro", "")))

	if String(c.get("eis", "")) != "":
		var eis := UiKit.label("Briefing: %s" % c["eis"], UiKit.FS_SMALL, UiKit.BLUEBIRD_INK)
		eis.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(eis)

	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 3)
	flow.add_theme_constant_override("v_separation", 3)
	body.add_child(flow)

	for raw: Variant in c.get("tags", []):
		var t := raw as Dictionary
		var id := String(t.get("id", ""))
		var b := UiKit.keuzeknop(String(t.get("label", id)), UiKit.FS_SMALL)
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, 18)
		b.toggled.connect(_on_toggle.bind(id))
		flow.add_child(b)
		_buttons[id] = b

	_result_panel = PanelContainer.new()
	_result_panel.add_theme_stylebox_override("panel", UiKit.panel(Color("#e9e4d6"), UiKit.LINE))
	_result_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_result_panel.visible = false
	body.add_child(_result_panel)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 1)
	_result_panel.add_child(rv)
	_result_title = UiKit.label("", UiKit.FS_BODY, UiKit.INK)
	rv.add_child(_result_title)
	_result_text = UiKit.label("", UiKit.FS_SMALL, UiKit.GRIJS)
	_result_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rv.add_child(_result_text)

	_generate = UiKit.button("Genereren", UiKit.FS_BODY)
	_generate.pressed.connect(_generate_pressed)
	body.add_child(_generate)

	_update_status()


func _on_toggle(pressed: bool, id: String) -> void:
	if pressed:
		if _picked.size() >= _kies:
			(_buttons[id] as Button).set_pressed_no_signal(false)
			set_status("Je mag er maar %d kiezen." % _kies)
			return
		_picked.append(id)
	else:
		_picked.erase(id)
	AudioDirector.play_ui(&"klik")
	_update_status()


func _update_status() -> void:
	set_status("%d/%d gekozen   ·   pogingen over: %d" % [_picked.size(), _kies, _pogingen_over])
	if _generate != null:
		_generate.disabled = _picked.size() != _kies


func _generate_pressed() -> void:
	if _picked.size() != _kies:
		return
	var c := content()
	_generate.disabled = true
	set_status("Genereren...")
	AudioDirector.play_ui(&"genereren")
	await get_tree().create_timer(1.1, true).timeout

	var res := _match_result(c.get("resultaten", []) as Array)
	_result_panel.visible = true
	_result_title.text = String(res.get("titel", "Resultaat"))
	_result_text.text = String(res.get("tekst", ""))

	if bool(res.get("goed", false)):
		await finish_with_banner(true, String(c.get("success", "Bruikbaar.")), 100,
			{"tags": _picked.duplicate()})
		return

	_pogingen_over -= 1
	AudioDirector.play_ui(&"fout")
	if _pogingen_over <= 0:
		await finish_with_banner(false, String(c.get("failure", "Dit wordt hem niet.")))
		return

	_reset_picks()


func _reset_picks() -> void:
	for id: Variant in _buttons.keys():
		(_buttons[id] as Button).set_pressed_no_signal(false)
	_picked.clear()
	_update_status()


## Eerste resultaat waarvan when_any een van de gekozen tags bevat.
## Een resultaat zonder when_any is de fallback.
func _match_result(list: Array) -> Dictionary:
	var fallback := {}
	for raw: Variant in list:
		var r := raw as Dictionary
		var any: Array = r.get("when_any", [])
		if any.is_empty():
			if fallback.is_empty():
				fallback = r
			continue
		var need_all: Array = r.get("when_all", [])
		if not need_all.is_empty():
			var ok := true
			for t: Variant in need_all:
				if not (String(t) in _picked):
					ok = false
					break
			if not ok:
				continue
		for t: Variant in any:
			if String(t) in _picked:
				return r
	return fallback if not fallback.is_empty() else {"titel": "Onbruikbaar", "tekst": "Er komt niets uit.", "goed": false}


## QA: kiest uitsluitend tags die tot het goede resultaat leiden.
func qa_solve() -> void:
	if _generate == null or _generate.disabled and _picked.size() == _kies:
		return
	var veilig: Array[String] = []
	for raw: Variant in content().get("resultaten", []):
		var r := raw as Dictionary
		if bool(r.get("goed", false)):
			for t: Variant in r.get("when_any", []):
				veilig.append(String(t))
			break
	_reset_picks()
	for t: String in veilig:
		if _picked.size() >= _kies:
			break
		if _buttons.has(t):
			(_buttons[t] as Button).button_pressed = true
	if _picked.size() == _kies:
		_generate_pressed()
