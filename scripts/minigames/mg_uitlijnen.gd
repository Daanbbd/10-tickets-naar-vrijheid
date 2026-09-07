extends MinigameBase
## Uitlijnen — BBD-204, de frontendfix van Victor.
##
## De enige minigame die over positie gaat in plaats van over een keuze. Zeven
## blokken van een productpagina staan een paar pixels naast hun plek en het
## raster eronder is de waarheid waar je naartoe werkt. Vervang alle blokken
## door grijze vlakken en je ziet nog steeds dat dit iets anders is dan de rest.
##
## Slepen is de enige route: een vinger op een blok van zestien pixels is groter
## dan de fout die je herstelt, dus vrij pixel-voor-pixel schuiven zou nooit
## precies uitkomen. `_op_sleep()` rondt daarom bij elke beweging af op de
## dichtstbijzijnde rasterstap — de precisie zit in het slepen zelf, niet in
## een aparte "vastklik"-actie erna.
##
## De stapgrootte (4, `raster` in de data) en elke `afwijking` moeten dezelfde
## rest delen — in de praktijk: elke afwijking is een veelvoud van het raster —
## anders komt geen enkel blok via hele stappen exact op nul uit en valt
## `perfect` in de payload nooit, wat Victors enige gevolg onbereikbaar maakt.
## Dat was precies de databug (elke `afwijking` in `data/minigame_content.json`
## deelde géén rest met het raster); de data is gerepareerd, niet de rekenwijze.
## De tolerantie van twee pixels blijft daarnaast bestaan, en betekent nu wat
## hij belooft: de marge waarbinnen een blok al "vast" oogt terwijl je nog
## sleept, niet de enige reden dat de puzzel oplosbaar is.


## Vaste plek en maat van elk blok op het vel, in canvaspixels en op het raster.
## Absolute posities, want dit ís de puzzel: een Container die zijn kinderen
## netjes onder elkaar zet, poetst de fout weg die de speler moet herstellen.
##
## De maten zijn zo gekozen dat elk blok met zijn grootste afwijking nog binnen
## het vel valt. Anders begint de puzzel met een blok dat half buiten de pagina
## hangt, en daar is geen rasterlijn meer om tegen te vergelijken.
const VORM: Dictionary = {
	&"logo":       Rect2(12, 12, 40, 20),
	&"nav":        Rect2(60, 12, 92, 20),
	&"hero":       Rect2(12, 44, 140, 76),
	&"prijs":      Rect2(12, 132, 60, 24),
	&"knop":       Rect2(80, 132, 72, 24),
	&"reviews":    Rect2(12, 168, 140, 24),
	&"aanbevolen": Rect2(12, 204, 140, 24),
}

## Zo groot als er in portret overblijft naast kop, statusregel, Klaar en
## Stoppen — groter dan dit en de eindbanner duwt het vel de scroll in.
const VEL_MAAT: Vector2 = Vector2(164, 240)


## Eén blok van de pagina. Kent zijn eigen nulpunt en de stappen die de speler
## erop gezet heeft; het rekenwerk zit in de minigame, zodat de teller in de
## statusregel en de payload uit dezelfde bron komen.
##
## Een `Panel` en geen `PanelContainer`: een Container rekent zijn eigen
## minimum uit het label erin, en een label dat afbreekt meldt in de eerste
## meetronde nog geen breedte — het vraagt dan hoogte voor één letter per regel.
## Een blok van zestien pixels groeide daardoor naar negentig, en dat is precies
## de maat waar deze minigame over gaat. Het label hangt hier aan de ankers, dus
## het volgt het blok zonder er iets over te zeggen.
class Blok extends Panel:
	const SNAP_TIJD := 0.12

	var elem_id: StringName = &""
	var naam: String = ""
	var thuis: Vector2 = Vector2.ZERO
	var maat: Vector2 = Vector2.ZERO
	var start: Vector2 = Vector2.ZERO      ## de afwijking waarmee de data begint
	var stappen: Vector2i = Vector2i.ZERO  ## hele rasterstappen van de speler
	var vast: bool = false

	var _tint: Color = UiKit.PANEL
	var _tween: Tween = null

	func _init(id: StringName, tekst: String, vorm: Rect2, afwijking: Vector2, tint: Color) -> void:
		elem_id = id
		naam = tekst
		thuis = vorm.position
		maat = vorm.size
		start = afwijking
		_tint = tint
		# Het vel vangt alle tikken zelf op. Dan loopt een sleep door als de
		# vinger het blok verlaat, en staat de hittest op één plek in plaats van
		# in zeven losse controls.
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = maat
		size = maat
		var l := UiKit.label(tekst, UiKit.FS_SMALL, UiKit.INK)
		# Niet afbreken maar afkappen: een blok heeft de maat die de opmaak
		# voorschrijft, en tekst mag die maat niet komen bijstellen.
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.clip_text = true
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UiKit.full_rect(l)
		add_child(l)
		toon_rand(false)

	## De resterende afwijking in pixels. Blijft staan als het blok visueel al
	## vastgeklikt is: binnen de tolerantie is niet hetzelfde als op nul, en de
	## payload moet dat verschil kunnen melden.
	func rest(raster: int) -> Vector2:
		return start + Vector2(stappen) * float(raster)

	func op_raster(raster: int, tolerantie: float) -> bool:
		var r := rest(raster)
		return absf(r.x) <= tolerantie and absf(r.y) <= tolerantie

	## De rand vertelt de staat, de vulling vertelt welk blok het is. Groen
	## betekent hier "deze staat op zijn plek" en niet "goed geantwoord", dus de
	## vulling gaat er niet in mee: die zou dan twee dingen tegelijk zeggen.
	func toon_rand(geselecteerd: bool) -> void:
		var kleur := UiKit.LINE
		if vast:
			kleur = UiKit.GROEN
		elif geselecteerd:
			kleur = UiKit.BLUEBIRD_INK
		add_theme_stylebox_override("panel",
			UiKit.panel_krap(_tint, kleur, 2 if (vast or geselecteerd) else 1))

	## Twee pixels verschuiving zie je nauwelijks bewegen, dus het vastklikken
	## zit vooral in het lichtje eromheen. Zonder dat leest een snap als niets.
	func schuif_naar(doel: Vector2, snappend: bool) -> void:
		_dood_tween()
		if not snappend:
			position = doel
			return
		_tween = create_tween().set_parallel(true)
		_tween.tween_property(self, "position", doel, SNAP_TIJD).set_ease(Tween.EASE_OUT)
		modulate = Color(1.4, 1.4, 1.4)
		_tween.tween_property(self, "modulate", Color.WHITE, SNAP_TIJD * 2.0)

	func _dood_tween() -> void:
		if _tween != null and _tween.is_valid():
			_tween.kill()
		_tween = null
		# Een gedode tween laat zijn doel staan waar het was; het blok zou dus
		# opgelicht blijven liggen.
		modulate = Color.WHITE

	## De minigame is een overlay die halverwege een animatie afgebroken kan
	## worden, en een tween overleeft zijn node niet vanzelf.
	func _exit_tree() -> void:
		_dood_tween()


## Het vel waar de pagina op staat: tekent het raster en vangt elke tik en
## sleepbeweging op.
class Vel extends Control:
	signal aangeraakt(punt: Vector2)
	signal gesleept(punt: Vector2)
	signal losgelaten()

	var raster: int = 4

	func _init(maat: Vector2, stap: int) -> void:
		raster = maxi(1, stap)
		custom_minimum_size = maat
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_STOP

	## Het raster moet te zien zijn zonder de pagina te overschreeuwen, want het
	## is de maatstaf en niet de inhoud. Elke vierde lijn iets donkerder: anders
	## is fijn ruitpapier op deze schaal één egale grijze waas en kun je een
	## klein blok niet meer tegen een groot blok uitlijnen.
	func _draw() -> void:
		var grof := UiKit.NEUTRAAL_TINT.darkened(0.14)
		var x := 0
		while x <= int(size.x):
			draw_line(Vector2(x, 0), Vector2(x, size.y),
				grof if x % (raster * 4) == 0 else UiKit.NEUTRAAL_TINT, 1.0)
			x += raster
		var y := 0
		while y <= int(size.y):
			draw_line(Vector2(0, y), Vector2(size.x, y),
				grof if y % (raster * 4) == 0 else UiKit.NEUTRAAL_TINT, 1.0)
			y += raster

	## Beide gebeurtenisfamilies: op een telefoon komen ScreenTouch en
	## ScreenDrag binnen, op de desktop de muisvarianten. Een sleep geeft de
	## absolute plek van de vinger door en niet `relative`, want met
	## muisemulatie aan komt dezelfde beweging twee keer langs — en dan zou één
	## veeg het blok twee keer zo ver schuiven.
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventScreenTouch:
			var t := event as InputEventScreenTouch
			if t.pressed:
				aangeraakt.emit(t.position)
			else:
				losgelaten.emit()
			accept_event()
		elif event is InputEventScreenDrag:
			gesleept.emit((event as InputEventScreenDrag).position)
			accept_event()
		elif event is InputEventMouseButton:
			var m := event as InputEventMouseButton
			if m.button_index != MOUSE_BUTTON_LEFT:
				return
			if m.pressed:
				aangeraakt.emit(m.position)
			else:
				losgelaten.emit()
			accept_event()
		elif event is InputEventMouseMotion:
			gesleept.emit((event as InputEventMouseMotion).position)


var _raster: int = 4
var _tolerantie: float = 2.0

var _volgorde: Array[StringName] = []
var _blokken: Dictionary = {}        ## StringName -> Blok
var _keuze: StringName = &""

var _vel: Vel = null
var _klaar: Button = null

var _sleept: bool = false
var _greep: Vector2 = Vector2.ZERO
var _qa_bezig: bool = false

# P3/M3: "Victor kijkt mee" — geen harde klok (dit spel gaat over positie, niet
# over tijd), wel een zachte teller die elke `_drift_sec` seconden één blok
# dat nog niet vast staat een pixel verder van zijn plek af laat schuiven.
# `_drift_actief` is dezelfde bewaakvlag als elders (zie `mg_standup.gd`'s
# `_running`): pas aan het eind van `_on_setup()` op true.
const DRIFT_MAX_PER_AS := 6.0
const DRIFT_SCHUD_PX := 2.0
const DRIFT_SCHUD_TIJD := 0.15

var _drift_sec: float = 8.0
var _drift_t: float = 0.0
var _drift_actief: bool = false
var _drift_toegevoegd: Dictionary = {}   ## StringName -> Vector2, drift tot nu toe per as
var _drift_label: Label = null
var _schud_tween: Tween = null
var _puls_tween: Tween = null


func _on_setup() -> void:
	var c := content()
	if c.is_empty():
		fail()
		return

	_raster = maxi(1, int(c.get("raster", 4)))
	_tolerantie = maxf(0.0, float(c.get("tolerantie", 2)))
	_drift_sec = maxf(1.0, float(c.get("drift_sec", 8.0)))

	var body := build_chrome(default_title(), String(c.get("intro", "")))

	_drift_label = UiKit.label("", UiKit.FS_SMALL, UiKit.WIT)
	chrome_header().add_child(_drift_label)

	var kader := PanelContainer.new()
	kader.add_theme_stylebox_override("panel", UiKit.panel_krap(UiKit.WIT, UiKit.LINE))
	# Op zijn eigen maat gehouden en gecentreerd: gestrekt zou het vel breder
	# worden dan de posities waarop de pagina is uitgetekend, en dan staat de
	# hele opmaak scheef in zijn eigen kader.
	kader.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(kader)

	_vel = Vel.new(VEL_MAAT, _raster)
	_vel.aangeraakt.connect(_op_aanraking)
	_vel.gesleept.connect(_op_sleep)
	_vel.losgelaten.connect(_op_los)
	kader.add_child(_vel)

	# Onbekende id's onder elkaar: de finale mag deze mechaniek met andere
	# elementen hergebruiken. De zeven van BBD-204 hebben een eigen vorm, want
	# die moeten samen als een productpagina lezen.
	var vrije_y := 12.0
	for raw: Variant in c.get("elementen", []):
		var e := raw as Dictionary
		var id := StringName(String(e.get("id", "")))
		if id == &"" or _blokken.has(id):
			continue
		var vorm: Rect2 = VORM.get(id, Rect2(12.0, vrije_y, 84.0, 16.0))
		if not VORM.has(id):
			vrije_y += 20.0
		var blok := Blok.new(id, String(e.get("label", String(id))),
			vorm, _afwijking(e), _tint(id))
		_vel.add_child(blok)
		_blokken[id] = blok
		_volgorde.append(id)
		_plaats(blok, false)

	if _volgorde.is_empty():
		fail()
		return

	_bouw_voet(body)
	_werk_bij()

	# De eerste 0,6 s: een pulserende rand rond het meest scheve blok, zodat
	# slepen zich aandient zonder daar een woord tekst voor nodig te hebben.
	var meest_scheef := _meest_scheef_blok()
	if meest_scheef != null:
		_puls_tween = puls_rand(meest_scheef, 2)

	_drift_actief = true


static func _afwijking(e: Dictionary) -> Vector2:
	var paar: Array = e.get("afwijking", [])
	if paar.size() < 2:
		return Vector2.ZERO
	return Vector2(float(paar[0]), float(paar[1]))


## Papierkleur per element, zodat de pagina als een pagina leest en niet als
## zeven identieke vakken. GROEN_TINT staat er bewust niet tussen: groen is hier
## de kleur van "staat op zijn plek".
static func _tint(id: StringName) -> Color:
	match id:
		&"logo", &"hero":
			return UiKit.BLUEBIRD_TINT
		&"nav":
			return UiKit.NEUTRAAL_TINT
		&"prijs":
			return UiKit.POSTIT
		&"knop":
			return UiKit.ORANJE_TINT
		&"reviews":
			return UiKit.ROZE_TINT
		&"aanbevolen":
			return UiKit.PAPIER
	return UiKit.PANEL


## Klaar hoort buiten de scroll: besturing die wegscrolt op het moment dat je
## hem nodig hebt is geen besturing. Het vel erboven past er in portret naast.
func _bouw_voet(body: VBoxContainer) -> void:
	_klaar = UiKit.knop_primair("Klaar", UiKit.FS_BODY)
	_klaar.pressed.connect(_afronden)
	chrome_footer().add_child(_klaar)


# --- Verschuiven ----------------------------------------------------------

func _gekozen() -> Blok:
	return _blokken.get(_keuze, null) as Blok


## Eén tik is één rasterstap op het geselecteerde blok. Sinds deze taak is dit
## alleen nog de route van `qa_solve()` — de UI-knoppen die dit aanriepen zijn
## weg, maar de methode zelf moet blijven bestaan en werken.
func _verschuif(richting: Vector2i) -> void:
	var blok := _gekozen()
	if blok != null:
		_zet_stappen(blok, blok.stappen + richting)


## Zet de stappen en houdt het blok binnen het vel. Buiten het vel is er geen
## rasterlijn meer om tegen te vergelijken, en een blok dat half onder het kader
## verdwijnt is niet meer aan te tikken.
func _zet_stappen(blok: Blok, nieuw: Vector2i) -> void:
	var geklemd := Vector2i(
		_klem(nieuw.x, blok.thuis.x + blok.start.x, VEL_MAAT.x - blok.maat.x),
		_klem(nieuw.y, blok.thuis.y + blok.start.y, VEL_MAAT.y - blok.maat.y))
	if geklemd == blok.stappen:
		return   # tegen de rand of geen beweging: geen tik, geen geluid

	var was_vast := blok.vast
	blok.stappen = geklemd
	blok.vast = blok.op_raster(_raster, _tolerantie)
	AudioDirector.play_ui(&"pak" if (blok.vast and not was_vast) else &"klik")
	_plaats(blok, blok.vast)
	blok.toon_rand(blok.elem_id == _keuze)
	_werk_bij()


## Hoeveel hele stappen er nog in het vel passen, per as.
func _klem(stappen: int, basis: float, ruimte: float) -> int:
	var laag := ceili(-basis / float(_raster))
	var hoog := floori((ruimte - basis) / float(_raster))
	return clampi(stappen, laag, maxi(laag, hoog))


## Binnen de tolerantie klikt het blok visueel op zijn nulpunt vast; de
## resterende afwijking blijft in de administratie staan. Dat is bewust: de
## speler moet kunnen zien dat het klopt, en de payload moet "binnen de
## tolerantie" van "exact op nul" kunnen onderscheiden.
func _plaats(blok: Blok, snappend: bool) -> void:
	blok.schuif_naar(blok.thuis if blok.vast else blok.thuis + blok.rest(_raster), snappend)


# --- Kiezen en slepen -----------------------------------------------------

func _op_aanraking(punt: Vector2) -> void:
	var blok := _raak(punt)
	# Naast een blok laat de selectie staan: de statusregel moet het gekozen
	# blok blijven noemen, en een misser midden in het slepen mag de keuze
	# niet wissen.
	if blok == null:
		return
	_kies(blok.elem_id)
	_sleept = true
	_greep = punt - blok.position


func _op_sleep(punt: Vector2) -> void:
	if not _sleept:
		return
	var blok := _gekozen()
	if blok == null:
		return
	var doel := punt - _greep - blok.thuis - blok.start
	_zet_stappen(blok, Vector2i(
		roundi(doel.x / float(_raster)), roundi(doel.y / float(_raster))))


func _op_los() -> void:
	_sleept = false


## Van boven naar onder zoeken: het blok dat je ziet liggen is het blok dat je
## aantikt.
func _raak(punt: Vector2) -> Blok:
	for i: int in range(_vel.get_child_count() - 1, -1, -1):
		var blok := _vel.get_child(i) as Blok
		if blok != null and blok.get_rect().has_point(punt):
			return blok
	return null


## De minigame is een overlay die halverwege een animatie afgebroken kan
## worden; de drift-schudtween en de openingspuls overleven hun node niet
## vanzelf.
func _exit_tree() -> void:
	if _schud_tween != null and _schud_tween.is_valid():
		_schud_tween.kill()
	if _puls_tween != null and _puls_tween.is_valid():
		_puls_tween.kill()


func _kies(id: StringName) -> void:
	if _keuze == id:
		return
	AudioDirector.play_ui(&"klik")
	var vorige := _gekozen()
	if vorige != null:
		vorige.toon_rand(false)
	_keuze = id
	var blok := _gekozen()
	if blok != null:
		blok.toon_rand(true)
		# Het gekozen blok naar voren: een klein blok dat over de hero schuift
		# zou er anders achter verdwijnen terwijl je het aan het verplaatsen bent.
		_vel.move_child(blok, -1)
	_werk_bij()


# --- Stand van zaken ------------------------------------------------------

func _op_raster_aantal() -> int:
	var n := 0
	for id: StringName in _volgorde:
		if (_blokken[id] as Blok).vast:
			n += 1
	return n


func _werk_bij() -> void:
	var blok := _gekozen()
	set_status("%s  ·  %d/%d op raster" % [
		blok.naam if blok != null else "Kies een blok",
		_op_raster_aantal(), _volgorde.size()])
	_werk_drift_teller_bij()


## Het blok met de grootste resterende afwijking — bepaalt waar de openings-
## puls op valt.
func _meest_scheef_blok() -> Blok:
	var beste: Blok = null
	var beste_afwijking := -1.0
	for id: StringName in _volgorde:
		var kandidaat := _blokken[id] as Blok
		var r := kandidaat.rest(_raster)
		var afwijking := absf(r.x) + absf(r.y)
		if afwijking > beste_afwijking:
			beste_afwijking = afwijking
			beste = kandidaat
	return beste


func _werk_drift_teller_bij() -> void:
	if _drift_label == null:
		return
	var scheef := _volgorde.size() - _op_raster_aantal()
	_drift_label.text = "Victor kijkt mee  ·  %d scheef" % scheef


# --- Victor kijkt mee: de build drift --------------------------------------

## Elke `_drift_sec` seconden krijgt één blok dat nog niet vast staat een
## pixel extra afwijking. Geen fail door tijd: wie niets doet, ziet de puzzel
## alleen langzaam erger worden.
func _process(delta: float) -> void:
	if not _drift_actief:
		return
	_drift_t += delta
	if _drift_t >= _drift_sec:
		_drift_t -= _drift_sec
		_val_drift()


func _val_drift() -> void:
	var kandidaten: Array[StringName] = []
	for id: StringName in _volgorde:
		if not (_blokken[id] as Blok).vast:
			kandidaten.append(id)
	if kandidaten.is_empty():
		return   # alles staat al op het raster: niets meer om scheef te maken

	var id := kandidaten[randi() % kandidaten.size()]
	var blok := _blokken[id] as Blok
	var toegevoegd: Vector2 = _drift_toegevoegd.get(id, Vector2.ZERO)
	var assen: Array[int] = []
	if toegevoegd.x < DRIFT_MAX_PER_AS:
		assen.append(0)
	if toegevoegd.y < DRIFT_MAX_PER_AS:
		assen.append(1)
	if assen.is_empty():
		return   # dit blok heeft zijn maximale drift al gehad op beide assen

	var gekozen_as := assen[randi() % assen.size()]
	var r := blok.rest(_raster)
	if gekozen_as == 0:
		var richting := 1.0 if r.x >= 0.0 else -1.0
		blok.start.x += richting
		toegevoegd.x += 1.0
	else:
		var richting := 1.0 if r.y >= 0.0 else -1.0
		blok.start.y += richting
		toegevoegd.y += 1.0
	_drift_toegevoegd[id] = toegevoegd
	blok.vast = blok.op_raster(_raster, _tolerantie)

	# Synchroon naar de nieuwe (net iets scheve) plek, en dáárna een kort
	# schudtweentje erbovenop — niet via `_plaats()`, die zijn eigen snap-tween
	# op `position` zou starten en zo met de schudtween om diezelfde
	# eigenschap vechten.
	var doel := blok.thuis + blok.rest(_raster)
	blok.position = doel
	_schud(blok, doel)

	_werk_drift_teller_bij()
	_toon_drift_melding()


func _schud(blok: Blok, doel: Vector2) -> void:
	if _schud_tween != null and _schud_tween.is_valid():
		_schud_tween.kill()
	_schud_tween = create_tween()
	_schud_tween.tween_property(blok, "position", doel + Vector2(DRIFT_SCHUD_PX, 0.0),
		DRIFT_SCHUD_TIJD * 0.5).set_trans(Tween.TRANS_SINE)
	_schud_tween.tween_property(blok, "position", doel, DRIFT_SCHUD_TIJD * 0.5) \
		.set_trans(Tween.TRANS_SINE)


## De statusregel toont "de build drift" 1 s, en valt dan terug op de gewone
## "<blok> · n/m op raster"-tekst.
func _toon_drift_melding() -> void:
	set_status("de build drift")
	await get_tree().create_timer(1.0, true).timeout
	if not is_inside_tree():
		return
	_werk_bij()


# --- Afronden -------------------------------------------------------------

func _afronden() -> void:
	var totaal := 0
	var perfect := true
	for id: StringName in _volgorde:
		var r := (_blokken[id] as Blok).rest(_raster)
		totaal += roundi(absf(r.x)) + roundi(absf(r.y))
		if not r.is_zero_approx():
			perfect = false

	var payload := {
		&"afwijking_totaal": totaal,
		&"perfect": perfect,
	}
	# De score is wat er nog scheef staat, niet hoe vaak je getikt hebt: dit
	# ticket gaat over het resultaat op het scherm.
	var score := maxi(0, 100 - totaal)
	var c := content()
	if _op_raster_aantal() == _volgorde.size():
		await finish_with_banner(true,
			String(c.get("success", "Alles staat op het raster.")), score, payload)
		return
	await finish_with_banner(false,
		String(c.get("failure", "Het staat scheef.")), score, payload)


# --- QA -------------------------------------------------------------------

## Lost op langs de echte winroute: dezelfde selectie, dezelfde richtingstikken,
## dezelfde knop. Een omweg naar succeed() zou juist de tolerantie ongetest
## laten, en daar staat of valt deze mechaniek op.
##
## De autopilot tikt elke 0,45 s opnieuw, vandaar de vlag: een tweede ronde zou
## de banner nog eens laten vallen terwijl de eerste nog loopt.
func qa_solve() -> void:
	if _qa_bezig or _klaar == null:
		return
	_qa_bezig = true

	for id: StringName in _volgorde:
		var blok := _blokken[id] as Blok
		_kies(id)
		# As voor as naar het nulpunt toe tikken. De rest van een afwijking
		# modulo het raster is altijd binnen twee stappen weg; de teller is er
		# alleen zodat onmogelijke data geen oneindige lus wordt.
		var tikken := 0
		while not blok.vast and tikken < 64:
			tikken += 1
			var r := blok.rest(_raster)
			var richting := Vector2i.ZERO
			if absf(r.x) > _tolerantie:
				richting.x = -1 if r.x > 0.0 else 1
			else:
				richting.y = -1 if r.y > 0.0 else 1
			var voor := blok.stappen
			_verschuif(richting)
			if blok.stappen == voor:
				break   # tegen de rand: verder tikken helpt niet
	_afronden()
