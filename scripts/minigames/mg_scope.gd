extends MinigameBase
## Scope-schuif — BBD-201, de user story van de Klant.
##
## Negen wensen, dertien punten, en een klant die "MVP" zei zonder te weten wat
## dat kost. Je verdeelt haar lijst over twee kolommen en botst daarbij tegen
## twee grenzen tegelijk: boven de capaciteit past het niet in de sprint, onder
## de tevredenheidsdrempel wordt zij er niet blij van. Eén tik verplaatst een
## wens naar de andere lijst; dat is de hele besturing.
##
## Er is bewust niet één goed antwoord. Het paard kost één punt en maakt haar
## het blijst van alles, dus je kunt slagen met het paard en Comic Sans terwijl
## de webshop blijft liggen. Dat is de grap van dit ticket, en de mechaniek mag
## hem dus niet afstraffen: elke verdeling die binnen de capaciteit past en de
## drempel haalt, slaagt. Welke combinaties dat zijn staat nergens op het
## scherm — dat uitzoeken is het spel.


## Een van de twee grenzen, als balkje. Een PanelContainer met een eigen
## `_draw()`: de vulling loopt onder de tekst door, zodat je de grens al ziet
## naderen voordat de kleur omslaat. Alleen de kleur zou pas iets zeggen op het
## moment dat het al te laat is.
class Meter extends PanelContainer:
	const BALK_H := 3.0

	var _tekst: Label = null
	var _balk: Color = UiKit.GRIJS

	## Wordt getweend in plaats van meteen gezet: een balk die verspringt leest
	## als een andere meter, een balk die loopt leest als dezelfde meter met een
	## nieuwe stand.
	var vulling: float = 0.0:
		set(v):
			vulling = v
			queue_redraw()

	func _init() -> void:
		custom_minimum_size = Vector2(0, 17)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tekst = UiKit.label("", UiKit.FS_SMALL, UiKit.INK)
		_tekst.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_tekst.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_tekst.autowrap_mode = TextServer.AUTOWRAP_OFF
		add_child(_tekst)
		zet("", UiKit.NEUTRAAL_TINT, UiKit.LINE, UiKit.INK, UiKit.GRIJS)

	func zet(tekst: String, bg: Color, rand: Color, ink: Color, balk: Color) -> void:
		_tekst.text = tekst
		_tekst.add_theme_color_override("font_color", ink)
		add_theme_stylebox_override("panel", UiKit.panel_krap(bg, rand))
		_balk = balk
		queue_redraw()

	func _draw() -> void:
		var w := size.x * clampf(vulling, 0.0, 1.0)
		if w > 0.0:
			draw_rect(Rect2(0.0, size.y - BALK_H, w, BALK_H), _balk)


## Eén wens uit de lijst. Geen `UiKit.button()` maar een PanelContainer met een
## HBox erin: de punten en de blijheid moeten rechts onder elkaar uitlijnen over
## alle regels heen, en een Button kent maar één tekst. Een PanelContainer vangt
## de tik zelf op (`mouse_filter` staat daar standaard op STOP) en groeit met de
## afgebroken tekst mee, dus het mikpunt blijft even groot als de regel.
class WensRij extends PanelContainer:
	signal getikt(wens_id: StringName)

	var wens_id: StringName = &""
	var punten: int = 0
	var blij: int = 0

	func _init(wens: Dictionary) -> void:
		wens_id = StringName(String(wens.get("id", "")))
		punten = int(wens.get("punten", 0))
		blij = int(wens.get("blij", 0))
		# 24 canvaspixels is op een telefoon ~10 mm; daaronder wordt een regel
		# een mikpunt in plaats van een knop.
		custom_minimum_size = Vector2(0, 24)
		var rij := HBoxContainer.new()
		rij.add_theme_constant_override("separation", 2)
		add_child(rij)
		var t := UiKit.label(String(wens.get("tekst", "")), UiKit.FS_SMALL, UiKit.INK)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rij.add_child(t)
		rij.add_child(_cijfer(punten, "pt"))
		rij.add_child(_cijfer(blij, "bl"))
		zet_sprint(false)

	## Elk cijfer draagt nu zijn eigen eenheid ("5pt", "3bl") in plaats van kaal
	## op het briefje te staan. Die eenheid stond eerder alleen als legenda
	## boven de lijst (de oude `_bouw_kop()`), en dat is precies het stukje
	## tekst dat de scrollbar afkapte zodra de lijst niet meer paste — en zelfs
	## zonder dat defect moest je terugscrollen naar de kop om te weten wat je
	## las. Negen kaarten met twee onbenoemde getallen was het echte probleem;
	## een kop erboven hoefde dat niet op te lossen.
	static func _cijfer(n: int, eenheid: String) -> Label:
		var l := UiKit.label("%d%s" % [n, eenheid], UiKit.FS_SMALL, UiKit.INK)
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(20, 0)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		return l

	## Geel papier zit in de sprint, verschoten papier ligt ernaast. De kleur
	## zegt bij welke lijst een briefje hoort, ook als de kop erboven al
	## weggescrold is.
	func zet_sprint(ja: bool) -> void:
		add_theme_stylebox_override("panel", UiKit.postit(
			UiKit.POSTIT if ja else UiKit.POSTIT_LEEG,
			UiKit.POSTIT_RAND if ja else UiKit.POSTIT_LEEG_RAND))

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed \
				and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			getikt.emit(wens_id)


const SCHUIF_TIJD := 0.15

## Boven dit aantal wensen wordt de volledige zoektocht van qa_solve() te duur
## en valt hij terug op hebzucht. Negen wensen is 512 combinaties; de finale zou
## via content_override een langere lijst kunnen meegeven.
const QA_MAX_EXACT := 18

var _capaciteit: int = 13
var _tevreden_min: int = 10
var _eenheid: String = "punten"

var _volgorde: Array[StringName] = []
var _rijen: Dictionary = {}          ## StringName -> WensRij

var _sprint: VBoxContainer = null
var _rest: VBoxContainer = null
var _sprint_kop: Label = null
var _rest_kop: Label = null
var _sprint_leeg: Label = null

var _meter_punten: Meter = null
var _meter_blij: Meter = null
var _hint: Label = null
var _vastleg: Button = null

var _schuif: Tween = null
var _schuivende_rij: WensRij = null
var _qa_bezig: bool = false


func _on_setup() -> void:
	var c := content()
	if c.is_empty():
		fail()
		return

	_capaciteit = int(c.get("capaciteit", 13))
	_tevreden_min = int(c.get("tevreden_min", 10))
	_eenheid = String(c.get("eenheid", "punten"))

	var body := build_chrome(default_title(), String(c.get("intro", "")))

	_bouw_meters(body)
	_sprint_kop = _bouw_kop(body, "IN DE SPRINT")
	_sprint = _bouw_lijst(body)
	_sprint_leeg = UiKit.label("Nog niets. Zij wacht.", UiKit.FS_SMALL, UiKit.GRIJS_OP_DONKER)
	body.add_child(_sprint_leeg)
	_rest_kop = _bouw_kop(body, "NIET DEZE SPRINT")
	_rest = _bouw_lijst(body)
	_bouw_voet(body)

	# Alles begint erbuiten: de speler kiest wat erin komt, niet wat eruit moet.
	# Dat is dezelfde beweging als het gesprek dat hij daarna met haar heeft.
	for raw: Variant in c.get("wensen", []):
		var w := raw as Dictionary
		var rij := WensRij.new(w)
		if rij.wens_id == &"" or _rijen.has(rij.wens_id):
			continue
		rij.getikt.connect(_op_tik)
		_rest.add_child(rij)
		_rijen[rij.wens_id] = rij
		_volgorde.append(rij.wens_id)

	_werk_bij(false)


## De twee meters horen boven de scroll. Zitten ze erin, dan scrollen ze weg
## precies op het moment dat de speler onderin een regel aantikt en wil zien wat
## dat met zijn twee grenzen doet.
func _bouw_meters(_body: VBoxContainer) -> void:
	var rij := HBoxContainer.new()
	rij.add_theme_constant_override("separation", 3)
	_meter_punten = Meter.new()
	_meter_blij = Meter.new()
	rij.add_child(_meter_punten)
	rij.add_child(_meter_blij)

	chrome_header().add_child(rij)


## De hint en de knop horen om dezelfde reden buiten de scroll: "dit past niet
## in de sprint" is een antwoord op de tik die je net gaf, en dat lees je niet
## als het zes regels lager staat.
func _bouw_voet(_body: VBoxContainer) -> void:
	var voet := VBoxContainer.new()
	voet.add_theme_constant_override("separation", 2)
	_hint = UiKit.label("", UiKit.FS_SMALL, UiKit.ROOD)
	# Vaste hoogte: een hint die verschijnt en verdwijnt zou de hele lijst onder
	# de vinger van de speler op en neer laten springen.
	_hint.custom_minimum_size = Vector2(0, 12)
	voet.add_child(_hint)
	_vastleg = UiKit.knop_primair("Vastleggen", UiKit.FS_BODY)
	_vastleg.pressed.connect(_vastleggen)
	voet.add_child(_vastleg)

	chrome_footer().add_child(voet)


## Kop boven een van de twee lijsten. Droeg vroeger ook de legenda "pnt blij"
## voor de twee kolommen cijfers rechts in elke regel, rechts uitgelijnd tot
## tegen de rand van de ScrollContainer — precies waar Godots scrollbar zich
## overheen tekent zodra de lijst niet meer past. De cijfers noemen hun
## eenheid nu zelf, in de kaart (zie WensRij._cijfer()), dus de kop hoeft
## alleen nog de naam van de lijst te dragen en heeft niets meer dat kan
## afkappen.
func _bouw_kop(body: VBoxContainer, tekst: String) -> Label:
	# De kop staat op de chrome en niet op een briefje, dus op het donkere
	# oppervlak.
	var l := UiKit.label(tekst, UiKit.FS_SMALL, UiKit.WIT)
	body.add_child(l)
	return l


func _bouw_lijst(body: VBoxContainer) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(v)
	return v


# --- Verdelen -------------------------------------------------------------

func _op_tik(wens_id: StringName) -> void:
	var rij: WensRij = _rijen.get(wens_id, null)
	if rij == null:
		return
	var naar_sprint := rij.get_parent() != _sprint
	AudioDirector.play_ui(&"pak" if naar_sprint else &"klik")
	_verplaats(rij, _sprint if naar_sprint else _rest)
	_schuivende_rij = rij
	_werk_bij(true)


func _verplaats(rij: WensRij, doel: VBoxContainer) -> void:
	var oud := rij.get_parent()
	if oud == doel:
		return
	if oud != null:
		oud.remove_child(rij)
	doel.add_child(rij)
	rij.zet_sprint(doel == _sprint)
	# De datavolgorde vasthouden. Zonder dit landt een regel die je terugzet
	# onderaan de stapel en verlies je hem uit het oog, terwijl je hem net nog
	# in je hand had.
	var plek := 0
	for id: StringName in _volgorde:
		if id == rij.wens_id:
			break
		var r: WensRij = _rijen[id]
		if r.get_parent() == doel:
			plek += 1
	doel.move_child(rij, plek)


func _in_sprint() -> Array[StringName]:
	var uit: Array[StringName] = []
	for id: StringName in _volgorde:
		if (_rijen[id] as WensRij).get_parent() == _sprint:
			uit.append(id)
	return uit


func _som(ids: Array[StringName], veld: StringName) -> int:
	var n := 0
	for id: StringName in ids:
		n += int((_rijen[id] as WensRij).get(veld))
	return n


func _werk_bij(geanimeerd: bool) -> void:
	var mee := _in_sprint()
	var punten := _som(mee, &"punten")
	var blij := _som(mee, &"blij")
	var te_vol := punten > _capaciteit
	var genoeg := blij >= _tevreden_min

	_meter_punten.zet("%d/%d %s" % [punten, _capaciteit, _eenheid],
		UiKit.ROOD if te_vol else UiKit.NEUTRAAL_TINT,
		UiKit.INK if te_vol else UiKit.LINE,
		UiKit.WIT if te_vol else UiKit.INK,
		UiKit.ROOD if te_vol else UiKit.GRIJS)
	_meter_blij.zet("blij %d/%d" % [blij, _tevreden_min],
		UiKit.GROEN if genoeg else UiKit.NEUTRAAL_TINT,
		UiKit.INK if genoeg else UiKit.LINE,
		UiKit.WIT if genoeg else UiKit.INK,
		UiKit.GROEN if genoeg else UiKit.GRIJS)

	var vul_punten := float(punten) / float(maxi(1, _capaciteit))
	var vul_blij := float(blij) / float(maxi(1, _tevreden_min))
	if geanimeerd:
		_anim(vul_punten, vul_blij)
	else:
		_meter_punten.vulling = vul_punten
		_meter_blij.vulling = vul_blij

	_sprint_kop.text = "IN DE SPRINT (%d)" % mee.size()
	_rest_kop.text = "NIET DEZE SPRINT (%d)" % (_volgorde.size() - mee.size())
	_sprint_leeg.visible = mee.is_empty()

	# Boven de capaciteit is de knop dicht: dat is geen keuze die de speler mag
	# maken, en Dennis zou hem alsnog voor honderdtwintig procent inplannen.
	_hint.text = String(content().get("te_vol", "")) if te_vol else ""
	_vastleg.disabled = te_vol
	set_status("%d van %d wensen" % [mee.size(), _volgorde.size()])


## Eén tween voor de hele verplaatsing: de regel licht op in zijn nieuwe lijst
## en de twee balkjes lopen naar hun nieuwe stand. Zonder dat zie je alleen dat
## er iets anders staat, niet dat er iets verschoof.
func _anim(vul_punten: float, vul_blij: float) -> void:
	if _schuif != null and _schuif.is_valid():
		_schuif.kill()
	# Een gedode tween laat zijn doel staan waar het was. Wie snel tikt zou dus
	# een spoor van halfdoorzichtige regels achterlaten, vandaar dat alle regels
	# eerst weer op vol worden gezet.
	for id: StringName in _volgorde:
		(_rijen[id] as WensRij).modulate = Color.WHITE

	_schuif = create_tween().set_parallel(true)
	_schuif.tween_property(_meter_punten, "vulling", vul_punten, SCHUIF_TIJD)
	_schuif.tween_property(_meter_blij, "vulling", vul_blij, SCHUIF_TIJD)
	if _schuivende_rij != null and is_instance_valid(_schuivende_rij):
		_schuivende_rij.modulate = Color(1.0, 1.0, 1.0, 0.2)
		_schuif.tween_property(_schuivende_rij, "modulate", Color.WHITE, SCHUIF_TIJD) \
			.set_ease(Tween.EASE_OUT)


## Tweens overleven hun node niet vanzelf als die node al wegvalt; de minigame
## is een overlay die halverwege een animatie afgebroken kan worden.
func _exit_tree() -> void:
	if _schuif != null and _schuif.is_valid():
		_schuif.kill()
	_schuif = null


# --- Vastleggen -----------------------------------------------------------

func _vastleggen() -> void:
	var c := content()
	var mee := _in_sprint()
	var punten := _som(mee, &"punten")
	var blij := _som(mee, &"blij")

	var weg: Array[String] = []
	for id: StringName in _volgorde:
		if not (id in mee):
			weg.append(String(id))
	var meegenomen: Array[String] = []
	for id: StringName in mee:
		meegenomen.append(String(id))

	var payload := {
		&"meegenomen": meegenomen,
		&"weggelaten": weg,
		&"punten": punten,
		&"blij": blij,
	}

	if punten > _capaciteit:
		# Via de knop onbereikbaar; blijft staan voor het geval de scope ooit
		# ergens anders vandaan wordt vastgelegd.
		await finish_with_banner(false, String(c.get("failure", "Dit past niet.")), blij, payload)
		return
	if blij < _tevreden_min:
		await finish_with_banner(false, String(c.get("te_weinig", "Zij wordt hier niet blij van.")),
			blij, payload)
		return
	await finish_with_banner(true, String(c.get("success", "Je hebt een scope.")), blij, payload)


# --- QA -------------------------------------------------------------------

## Lost op langs de echte winroute: dezelfde tikken, dezelfde knop.
##
## De combinatie wordt uit de data gerekend en niet ingebakken, want er zijn er
## meerdere goed en de finale mag deze mechaniek met een andere lijst
## hergebruiken. De autopilot tikt elke 0,45 s opnieuw, vandaar de vlag: een
## tweede ronde zou de wensen er weer uit halen.
func qa_solve() -> void:
	if _qa_bezig or _vastleg == null:
		return
	_qa_bezig = true

	var keuze := _qa_keuze()
	for id: StringName in _volgorde:
		_verplaats(_rijen[id] as WensRij, _sprint if id in keuze else _rest)
	_werk_bij(false)
	_vastleggen()


## Kleinste verdeling die binnen de capaciteit past en de drempel haalt.
## Volledig zoeken over de deelverzamelingen: negen wensen zijn 512
## combinaties, en hebzucht op blij-per-punt is niet gegarandeerd.
func _qa_keuze() -> Array[StringName]:
	var n := _volgorde.size()
	if n > QA_MAX_EXACT:
		return _qa_hebzucht()
	var best: Array[StringName] = []
	var best_punten := _capaciteit + 1
	for masker: int in 1 << n:
		var punten := 0
		var blij := 0
		for i: int in n:
			if masker & (1 << i) != 0:
				var r: WensRij = _rijen[_volgorde[i]]
				punten += r.punten
				blij += r.blij
		if punten > _capaciteit or blij < _tevreden_min or punten >= best_punten:
			continue
		best_punten = punten
		best = []
		for i: int in n:
			if masker & (1 << i) != 0:
				best.append(_volgorde[i])
	return best if not best.is_empty() else _qa_hebzucht()


## Terugvaloptie: de meeste blijheid per punt eerst, tot de capaciteit vol is.
func _qa_hebzucht() -> Array[StringName]:
	var ids := _volgorde.duplicate()
	ids.sort_custom(_meer_blij_per_punt)
	var uit: Array[StringName] = []
	var punten := 0
	for id: StringName in ids:
		var r: WensRij = _rijen[id]
		if punten + r.punten > _capaciteit:
			continue
		punten += r.punten
		uit.append(id)
	return uit


func _meer_blij_per_punt(a: StringName, b: StringName) -> bool:
	var ra: WensRij = _rijen[a]
	var rb: WensRij = _rijen[b]
	return float(ra.blij) / float(maxi(1, ra.punten)) > float(rb.blij) / float(maxi(1, rb.punten))
