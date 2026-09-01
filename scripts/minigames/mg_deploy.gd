extends MinigameBase
## BBD-210 — de finale. Alle checks staan op groen, en dan faalt de deployment
## precies op jouw vakgebied. Elk personage krijgt een eigen laatste probleem.

const MECHANIEK_SCENE := {
	"slotboard": "res://scenes/minigames/mg_slotboard.tscn",
	"choicescene": "res://scenes/minigames/mg_choicescene.tscn",
	"cableboard": "res://scenes/minigames/mg_cableboard.tscn",
}

var _console: VBoxContainer = null
var _deploy_btn: Button = null
var _variant: Dictionary = {}


func _on_setup() -> void:
	var c := content()
	if c.is_empty():
		fail()
		return

	var cid := String(Session.character_id)
	_variant = (c.get("varianten", {}) as Dictionary).get(cid, {}) as Dictionary
	if _variant.is_empty():
		push_error("mg_deploy: geen variant voor personage '%s'" % cid)
		fail()
		return

	var body := build_chrome("PRODUCTIEDEPLOYMENT", String(c.get("intro", "")))

	var term := PanelContainer.new()
	term.add_theme_stylebox_override("panel", UiKit.panel(Color("#14161f"), UiKit.INK))
	term.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(term)
	_console = VBoxContainer.new()
	_console.add_theme_constant_override("separation", 0)
	term.add_child(_console)

	_deploy_btn = UiKit.button("DEPLOY", UiKit.FS_BODY)
	_deploy_btn.pressed.connect(_run_deploy)
	body.add_child(_deploy_btn)

	set_status("klaar om te deployen")


func _line(text: String, col: Color) -> void:
	var l := UiKit.label(text, UiKit.FS_SMALL, col)
	_console.add_child(l)


func _run_deploy() -> void:
	_deploy_btn.disabled = true
	var c := content()
	for ch: Node in _console.get_children():
		ch.queue_free()
		_console.remove_child(ch)

	AudioDirector.play_ui(&"genereren")
	for raw: Variant in c.get("checks", []):
		_line("  %-22s OK" % String(raw), UiKit.GROEN)
		await get_tree().create_timer(0.28, true).timeout

	await get_tree().create_timer(0.5, true).timeout
	_line("", UiKit.WIT)
	_line("  DEPLOYMENT FAILED", UiKit.ROOD)
	_line("  %s" % String(_variant.get("foutcode", "UNKNOWN ERROR")), UiKit.ROOD)
	AudioDirector.play_ui(&"fout")
	await get_tree().create_timer(0.9, true).timeout

	var uitleg := UiKit.label(String(_variant.get("uitleg", "")), UiKit.FS_SMALL, UiKit.BLUEBIRD_BRIGHT)
	uitleg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_console.add_child(uitleg)
	await get_tree().create_timer(1.2, true).timeout

	var ok := await _run_variant()
	if not ok:
		_deploy_btn.disabled = false
		_deploy_btn.text = "OPNIEUW DEPLOYEN"
		set_status("deployment afgebroken")
		return

	_line("", UiKit.WIT)
	_line("  DEPLOYMENT SUCCESSFUL", UiKit.GROEN)
	await finish_with_banner(true, String(_variant.get("success", "DEPLOYMENT SUCCESSFUL")), 100)


## Draait de mechaniek van deze variant als losse overlay bovenop de console.
func _run_variant() -> bool:
	var mech := String(_variant.get("mechaniek", "choicescene"))
	var path := String(MECHANIEK_SCENE.get(mech, ""))
	if path == "" or not ResourceLoader.exists(path):
		push_error("mg_deploy: onbekende mechaniek '%s'" % mech)
		return false

	var sub := (load(path) as PackedScene).instantiate() as MinigameBase
	sub.minigame_id = StringName("mg_deploy_%s" % Session.character_id)
	sub.content_override = _variant.get("config", {}) as Dictionary
	sub.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(sub)
	sub.setup(sub.content_override)

	var res: MinigameResult = await sub.finished
	sub.queue_free()
	await get_tree().process_frame
	return res.outcome == GameEnums.Outcome.SUCCESS


## QA: start de deploy. De variant-minigame wordt daarna door de autopilot
## zelf opgelost, want die zit ook in de groep "minigame".
func qa_solve() -> void:
	if _deploy_btn != null and not _deploy_btn.disabled:
		_run_deploy()
