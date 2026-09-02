extends MinigameBase
## BBD-208 — De renderpijplijn. Koen wil alles in piepelienies gieten zodat het
## automatisch gaat; jij mag het eerst een minuut met de hand doen.
##
## Drie stages onder elkaar, zes clips, en één plek waar het pijn doet: een clip
## die rijp is en in Render blijft staan verbrandt credits per seconde. Dat is
## ook waarom `kost` alleen op een *rijpe* clip drukt en niet op de hele
## renderduur — vijf clips maal vijf seconden maal zes credits is anderhalf keer
## het budget, en dan valt er niets te spelen. De druk hoort te zitten in laten
## staan, niet in renderen.
##
## Was vier stages (Prompt → Render → Review → Publish); Review kostte nooit
## credits en voegde alleen een derde tik per clip toe zonder een nieuwe
## afweging. Weg ermee: Render blijft de enige stap die pijn doet, en dat is nu
## ook de enige rij waar je goed moet opletten. De statusregel bovenaan blijft
## het enige tellertje — de losse "X/Y"-chip naast Publish is geschrapt, want
## die herhaalde precies wat daar al stond.
##
## Al het rijpen, alle kosten en de hele klok lopen in één `_process` op deze
## node. Clips verdwijnen en verhuizen, dus een `_process` of een tween per
## blokje is hier vragen om een verwijzing naar een node die er niet meer is.

## Minimumformaat van een blokje. De echte hoogte komt van de stagerij, die de
## ruimte opeet die op dit canvas over is; het cliplabel breekt af over hoogstens
## _REGELS regels.
const _BLOK := Vector2(50, 34)
const _CHIP := Vector2(12, 22)
const _NAAM_BREED := 48.0
const _REGELS := 3

## Tempo waarmee Prompt zich vanzelf vult. Een lege eerste stage is dodelijk in
## een doorstroomspel: dan wacht de speler op de pijplijn in plaats van
## andersom. De knop is er voor wie sneller wil.
const _INTAKE := 1.2


## Eén zichtbaar blokje, met de clip waar het bij hoort erin. De dictionary is
## een verwijzing naar dezelfde clip in `_jobs`, dus opzoeken hoeft nooit.
class Blok extends RefCounted:
	var job: Dictionary
	var paneel: PanelContainer = null
	var naam: Label = null
	var balk: ProgressBar = null
	var staat: int = -1


var _stages: Array[Dictionary] = []
var _jobs: Array[Dictionary] = []
var _blokken: Array[Blok] = []
var _vakken: Array[HBoxContainer] = []

var _labels: Array[String] = []
var _tijd: float = 60.0
var _credits: float = 100.0
var _doel: int = 5
var _totaal: int = 6
var _volgende: int = 0
var _gepubliceerd: int = 0
var _intake_t: float = _INTAKE
var _puls: float = 0.0
var _running: bool = false
var _qa: bool = false

var _knop: Button = null
var _caption: Label = null


func _on_setup() -> void:
	var c := content()
	if c.is_empty():
		fail()
		return

	_tijd = float(c.get("tijd", 60.0))
	_credits = float(c.get("credits", 100))
	_doel = int(c.get("doel", 5))
	for raw: Variant in c.get("job_labels", []):
		_labels.append(String(raw))
	_totaal = mini(int(c.get("jobs", _labels.size())), _labels.size())
	for raw: Variant in c.get("stages", []):
		var s := raw as Dictionary
		_stages.append({
			&"label": String(s.get("label", "?")),
			&"cap": maxi(1, int(s.get("capaciteit", 2))),
			&"duur": float(s.get("duur", 0.0)),
			&"kost": float(s.get("kost", 0)),
		})
	if _stages.size() < 2 or _totaal <= 0:
		push_error("mg_pijplijn: onbruikbare config voor '%s'" % minigame_id)
		fail()
		return

	var body := build_chrome(default_title(), String(c.get("intro", "")))

	for i: int in _stages.size():
		body.add_child(_bouw_rij(i))

	# De volle clipnaam past nergens in een blokje van 50 px. Hier onder staat
	# welke clip je net verzette — dat is ook de plek waar de grap zit.
	_caption = UiKit.label("", UiKit.FS_SMALL, UiKit.GRIJS_OP_DONKER)
	_caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	_caption.clip_text = true
	_caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_caption.custom_minimum_size = Vector2(0, 14)
	body.add_child(_caption)

	_knop = UiKit.knop_primair("Nieuwe clip", UiKit.FS_SMALL)
	_knop.custom_minimum_size = Vector2(0, 26)
	_knop.focus_mode = Control.FOCUS_NONE
	_knop.pressed.connect(_haal_clip)
	body.add_child(_knop)

	_haal_clip()
	_herbouw()
	_running = true
	_update_status()


# --- Opbouw --------------------------------------------------------------

## Eén stagerij: naam links, de plekken rechts. Portrait is hoog en smal, dus de
## stages stapelen en de clips liggen naast elkaar.
func _bouw_rij(i: int) -> PanelContainer:
	var rij := PanelContainer.new()
	rij.add_theme_stylebox_override("panel", UiKit.panel_krap(UiKit.PANEL, UiKit.LINE))
	# De drie werkende stages verdelen de hoogte die overblijft. Een kwart leeg
	# canvas onderaan is zonde, en een hogere rij is meteen een groter tikdoel
	# en ruimte voor het echte cliplabel. In Publish rijpt niets, dus die rij
	# blijft zo laag als zijn chips.
	if i != _laatste():
		rij.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Grof tikdoel dat werkt boven een precies doel dat je met een duim mist:
	# een tik náást de blokjes pakt de meest rijpe clip van deze rij.
	rij.mouse_filter = Control.MOUSE_FILTER_STOP
	rij.gui_input.connect(_op_rij_input.bind(i))

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 2)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rij.add_child(h)

	var naam := UiKit.label(String(_stages[i][&"label"]), UiKit.FS_SMALL, UiKit.INK)
	naam.autowrap_mode = TextServer.AUTOWRAP_OFF
	naam.clip_text = true
	naam.custom_minimum_size = Vector2(_NAAM_BREED,
		_CHIP.y if i == _laatste() else _BLOK.y)
	naam.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	naam.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(naam)

	var vak := HBoxContainer.new()
	vak.add_theme_constant_override("separation", 2)
	vak.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vak.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(vak)
	_vakken.append(vak)

	return rij


func _bouw_blok(job: Dictionary) -> Blok:
	var b := Blok.new()
	b.job = job
	b.paneel = PanelContainer.new()
	b.paneel.custom_minimum_size = _BLOK
	# De blokjes verdelen de breedte die na de stagenaam overblijft; met twee
	# plekken is dat ruim een halve regel tekst extra per blokje.
	b.paneel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.paneel.mouse_filter = Control.MOUSE_FILTER_STOP
	b.paneel.gui_input.connect(_op_blok_input.bind(job))

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.paneel.add_child(col)

	# Het cliplabel *is* de grap, dus dat hoort op het blokje en niet alleen in
	# de regel eronder. Afbreken en dan afkappen met een ellipsis: een halve
	# grap leest beter dan "clip 3". Een Label met autowrap plus afkappen meldt
	# 1x1 als minimum, dus geen enkel label kan de rij uit elkaar duwen.
	b.naam = UiKit.label(_clip_label(job), UiKit.FS_SMALL, UiKit.INK)
	b.naam.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.naam.max_lines_visible = _REGELS
	b.naam.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.naam.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	b.naam.size_flags_vertical = Control.SIZE_EXPAND_FILL
	b.naam.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(b.naam)

	b.balk = ProgressBar.new()
	b.balk.show_percentage = false
	b.balk.min_value = 0.0
	b.balk.max_value = 1.0
	b.balk.custom_minimum_size = Vector2(0, 5)
	b.balk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(b.balk)

	return b


func _bouw_leeg() -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = _BLOK
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel",
		UiKit.panel_krap(UiKit.NEUTRAAL_TINT, UiKit.GRIJS, 2))
	return p


func _bouw_chip() -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = _CHIP
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel",
		UiKit.panel_krap(UiKit.GROEN_TINT, UiKit.GROEN, 2))
	return p


## Alleen aanroepen als de samenstelling verandert. Rijpen en kleuren gaan per
## frame via _verf(), zonder nodes weg te gooien.
func _herbouw() -> void:
	_blokken.clear()
	for i: int in _stages.size():
		var vak := _vakken[i]
		for kind: Node in vak.get_children():
			vak.remove_child(kind)
			kind.queue_free()
		var hier := _in_stage(i)
		if i == _laatste():
			for _j: Dictionary in hier:
				vak.add_child(_bouw_chip())
			continue
		for job: Dictionary in hier:
			var b := _bouw_blok(job)
			_blokken.append(b)
			vak.add_child(b.paneel)
		# Lege plekken tekenen de capaciteit: je ziet dat Render vol staat
		# voordat je erop tikt.
		for _k: int in maxi(0, int(_stages[i][&"cap"]) - hier.size()):
			vak.add_child(_bouw_leeg())
	_verf()


# --- Spelverloop ---------------------------------------------------------

func _process(delta: float) -> void:
	if not _running:
		return

	_puls = fmod(_puls + delta * 7.0, TAU)
	_tijd -= delta

	for job: Dictionary in _jobs:
		var s := _stages[int(job[&"stage"])]
		var duur := float(s[&"duur"])
		if float(job[&"t"]) < duur:
			job[&"t"] = minf(duur, float(job[&"t"]) + delta)
		elif float(s[&"kost"]) > 0.0:
			# Rijp en nog in Render: dit is de rekening die oploopt terwijl je
			# nadenkt over welke rij je eerst leegtrekt.
			_credits -= float(s[&"kost"]) * delta

	if _qa:
		_qa_stap()
	else:
		_intake_t -= delta
		if _intake_t <= 0.0 and _haal_clip():
			_intake_t = _INTAKE

	_verf()
	_update_status()

	# Doorschuiven kan de partij al beslist hebben; dan hoort de klok niet ook
	# nog een tweede uitslag te melden.
	if not _running:
		return

	if _credits <= 0.0:
		_credits = 0.0
		_running = false
		await finish_with_banner(false, String(content().get("credits_op", "Credits op.")),
			_score(), _payload())
		return

	if _tijd <= 0.0:
		_tijd = 0.0
		_running = false
		await finish_with_banner(false, String(content().get("failure", "De tijd is om.")),
			_score(), _payload())


## Volgende clip de pijplijn in. Geeft terug of dat gelukt is, zodat de
## automatische toevoer het opnieuw probeert zodra er plek is.
func _haal_clip() -> bool:
	if not _plek(0) or _volgende >= _totaal:
		return false
	var job := {&"nr": _volgende, &"stage": 0, &"t": 0.0}
	_jobs.append(job)
	_volgende += 1
	_zet_caption(job)
	_herbouw()
	_update_status()
	AudioDirector.play_ui(&"pak")
	return true


## Eén clip een stage op. De enige route naar Publish — ook voor QA.
func _schuif(job: Dictionary, geluid: bool = true) -> void:
	if not _running or not _rijp(job):
		return
	var naar := int(job[&"stage"]) + 1
	if naar > _laatste():
		return
	if not _plek(naar):
		# Vol. Hij blijft staan, en in Render tikt de teller gewoon door.
		if geluid:
			AudioDirector.play_ui(&"fout")
		return

	job[&"stage"] = naar
	job[&"t"] = 0.0
	_zet_caption(job)
	if naar == _laatste():
		_gepubliceerd += 1
		if geluid:
			AudioDirector.play_ui(&"raak")
	elif geluid:
		AudioDirector.play_ui(&"klik")
	_herbouw()
	_update_status()

	if _gepubliceerd >= _doel:
		_running = false
		await finish_with_banner(true, String(content().get("success", "Alles gepubliceerd.")),
			_score(), _payload())


func _op_blok_input(event: InputEvent, job: Dictionary) -> void:
	if _tik(event):
		_schuif(job)


## Een tik naast de blokjes: pak de clip die het verst is. Bij een volle Render
## is dat precies degene die geld kost.
func _op_rij_input(event: InputEvent, stage: int) -> void:
	if not _tik(event):
		return
	var job := _meest_rijp(stage)
	if not job.is_empty():
		_schuif(job)


static func _tik(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		return mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	return false


# --- Vormgeving per frame ------------------------------------------------

func _verf() -> void:
	# Rijp moet je in één oogopslag zien; dat is de belangrijkste leesbaarheids-
	# eis hier. De puls loopt mee in _process in plaats van in een tween, want
	# een blokje kan elk moment verhuizen en verdwijnen.
	var puls := 0.5 + 0.5 * sin(_puls)
	for b: Blok in _blokken:
		var s := _stages[int(b.job[&"stage"])]
		var duur := float(s[&"duur"])
		b.balk.value = 1.0 if duur <= 0.0 else clampf(float(b.job[&"t"]) / duur, 0.0, 1.0)

		var staat := 0
		if _rijp(b.job):
			staat = 2 if float(s[&"kost"]) > 0.0 else 1
		if staat != b.staat:
			b.staat = staat
			_zet_stijl(b, staat)
		b.paneel.modulate = (Color.WHITE if staat == 0
			else Color.WHITE.lerp(Color(1.4, 1.4, 1.4), puls))


func _zet_stijl(b: Blok, staat: int) -> void:
	match staat:
		1:
			b.paneel.add_theme_stylebox_override("panel",
				UiKit.panel_krap(UiKit.GROEN_TINT, UiKit.GROEN, 2))
			b.naam.add_theme_color_override("font_color", UiKit.INK)
			_zet_balk(b.balk, UiKit.GROEN_TINT, UiKit.GROEN)
		2:
			# Verbrandt credits. Dit hoort pijn te doen om te zien.
			b.paneel.add_theme_stylebox_override("panel",
				UiKit.panel_krap(UiKit.ROOD, UiKit.INK, 2))
			b.naam.add_theme_color_override("font_color", UiKit.WIT)
			_zet_balk(b.balk, UiKit.INK, UiKit.WIT)
		_:
			b.paneel.add_theme_stylebox_override("panel",
				UiKit.panel_krap(UiKit.PANEL, UiKit.LINE, 2))
			b.naam.add_theme_color_override("font_color", UiKit.INK)
			_zet_balk(b.balk, UiKit.NEUTRAAL_TINT, UiKit.BLUEBIRD_INK)


## De themastijl van een ProgressBar houdt binnenmarge over; op een balkje van
## 5 px blijft er dan niets van de vulling zichtbaar.
static func _zet_balk(balk: ProgressBar, achter: Color, vulling: Color) -> void:
	balk.add_theme_stylebox_override("background", _plat(achter))
	balk.add_theme_stylebox_override("fill", _plat(vulling))


static func _plat(kleur: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = kleur
	sb.set_content_margin_all(0)
	return sb


func _update_status() -> void:
	set_status("%d cr  ·  %d s  ·  %d/%d" % [
		maxi(0, ceili(_credits)), maxi(0, ceili(_tijd)), _gepubliceerd, _doel])
	if _knop != null:
		var over := _totaal - _volgende
		_knop.disabled = over <= 0 or not _plek(0)
		if over > 0:
			_knop.text = "Nieuwe clip  ·  %d over" % over
		else:
			_knop.text = "Alle clips binnen"


func _zet_caption(job: Dictionary) -> void:
	if _caption != null:
		_caption.text = "clip %d  ·  %s" % [int(job[&"nr"]) + 1, _clip_label(job)]


## Het blokje kapt lange labels af; hier onder staat de hele naam.
func _clip_label(job: Dictionary) -> String:
	var nr := int(job[&"nr"])
	return _labels[nr] if nr < _labels.size() else "clip %d" % (nr + 1)


# --- Kleine hulpjes ------------------------------------------------------

func _laatste() -> int:
	return _stages.size() - 1


func _in_stage(i: int) -> Array[Dictionary]:
	var uit: Array[Dictionary] = []
	for job: Dictionary in _jobs:
		if int(job[&"stage"]) == i:
			uit.append(job)
	return uit


func _plek(i: int) -> bool:
	return _in_stage(i).size() < int(_stages[i][&"cap"])


func _rijp(job: Dictionary) -> bool:
	return float(job[&"t"]) >= float(_stages[int(job[&"stage"])][&"duur"])


func _meest_rijp(stage: int) -> Dictionary:
	var beste: Dictionary = {}
	var top := -1.0
	var duur := float(_stages[stage][&"duur"])
	for job: Dictionary in _in_stage(stage):
		var f := 1.0 if duur <= 0.0 else float(job[&"t"]) / duur
		if f > top:
			top = f
			beste = job
	return beste


func _score() -> int:
	return _gepubliceerd * 20


func _payload() -> Dictionary:
	return {
		&"gepubliceerd": _gepubliceerd,
		&"credits_over": maxi(0, floori(_credits)),
		&"tijd_over": maxf(0.0, _tijd),
	}


## QA: trekt de pijplijn echt leeg langs de gewone doorschuiflogica. Van achter
## naar voren, zodat er stroomafwaarts eerst plek vrijkomt; per frame schuift
## elke clip zo hoogstens één stage op.
func qa_solve() -> void:
	_qa = true


func _qa_stap() -> void:
	for i: int in range(_laatste() - 1, -1, -1):
		for job: Dictionary in _in_stage(i):
			if _rijp(job) and _plek(i + 1):
				_schuif(job, false)
	_haal_clip()
