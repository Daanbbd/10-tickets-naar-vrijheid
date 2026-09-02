extends MinigameBase
## Uitlijnen — BBD-204, de frontendfix van Victor.
##
## De enige minigame die over positie gaat in plaats van over een keuze. Vijf
## blokken van een productpagina staan een paar pixels naast hun plek en het
## raster eronder is de waarheid waar je naartoe werkt. Vervang alle blokken
## door grijze vlakken en je ziet nog steeds dat dit iets anders is dan de rest.
##
## De besturing zijn vier richtingsknoppen. Slepen mag ook, maar het is de
## bijroute: de fout die je herstelt is kleiner dan de vinger waarmee je hem
## aanwijst, dus een knop die precies één rasterstap doet komt verder dan een
## duim op een blok van zestien pixels.
##
## De stapgrootte (4) en de afwijkingen uit de data delen nooit een rest: geen
## enkel blok komt via hele stappen exact op nul uit. De tolerantie van twee
## pixels is dus geen vriendelijkheid maar de reden dat het oplosbaar is — en
## precies waarom `perfect` in de payload vrijwel altijd false blijft. Victor
## zou zeggen dat het nog wat meer uitgelijnd kan.


## Vaste plek en maat van elk blok op het vel, in canvaspixels en op het raster.
## Absolute posities, want dit ís de puzzel: een Container die zijn kinderen
## netjes onder elkaar zet, poetst de fout weg die de speler moet herstellen.
##
## De maten zijn zo gekozen dat elk blok met zijn grootste afwijking nog binnen
## het vel valt. Anders begint de puzzel met een blok dat half buiten de pagina
## hangt, en daar is geen rasterlijn meer om tegen te vergelijken.
const VORM: Dictionary = {
	&"logo": Rect2(12, 12, 40, 20),
	&"nav": Rect2(60, 12, 92, 20),
	&"hero": Rect2(12, 44, 140, 76),
	&"prijs": Rect2(12, 140, 60, 24),
	&"knop": Rect2(80, 140, 72, 24),
}

## Zo groot als er in portret overblijft naast de kop, de intro en de
## richtingsknoppen. Groter kan niet, kleiner hoeft niet: hoe meer rasterlijnen
## er naast een blok staan, hoe beter je ziet dat het scheef hangt.
const VEL_MAAT: Vector2 = Vector2(164, 180)

## Duimmaat, geen designkeuze: 34x30 canvaspixels is op een telefoon ruim een
## centimeter, en daaronder wordt een richtingsknop een mikpunt.
const PIJL_MAAT: Vector2 = Vector2(34, 30)


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
		# in vijf losse controls.
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
var _pijlen: Array[Button] = []
var _klaar: Button = null

var _sleept: bool = false
var _greep: Vector2 = Vector2.ZERO
var _qa_bezig: bool = false


func _on_setup() -> void:
	var c := content()
	if c.is_empty():
		fail()
		return

	_raster = maxi(1, int(c.get("raster", 4)))
	_tolerantie = maxf(0.0, float(c.get("tolerantie", 2)))

	var body := build_chrome(default_title(), String(c.get("intro", "")))

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
	# elementen hergebruiken. De vijf van BBD-204 hebben een eigen vorm, want
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


static func _afwijking(e: Dictionary) -> Vector2:
	var paar: Array = e.get("afwijking", [])
	if paar.size() < 2:
		return Vector2.ZERO
	return Vector2(float(paar[0]), float(paar[1]))


## Papierkleur per element, zodat de pagina als een pagina leest en niet als
## vijf identieke vakken. GROEN_TINT staat er bewust niet tussen: groen is hier
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
	return UiKit.PANEL


## De vier richtingsknoppen en Klaar horen buiten de scroll. Dit is de
## besturing, en besturing die wegscrolt op het moment dat je hem nodig hebt is
## geen besturing. Het vel erboven past er in portret naast.
func _bouw_voet(body: VBoxContainer) -> void:
	var voet := VBoxContainer.new()
	voet.add_theme_constant_override("separation", 2)

	# Als een kruis en niet als een rijtje: bij een puzzel over richting hoort
	# een knop op de kant waar hij het blok heen duwt.
	var pad := GridContainer.new()
	pad.columns = 3
	pad.add_theme_constant_override("h_separation", 2)
	pad.add_theme_constant_override("v_separation", 2)
	pad.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	voet.add_child(pad)
	pad.add_child(_gat())
	pad.add_child(_pijl("▲", Vector2i(0, -1)))
	pad.add_child(_gat())
	pad.add_child(_pijl("◀", Vector2i(-1, 0)))
	pad.add_child(_pijl("▼", Vector2i(0, 1)))
	pad.add_child(_pijl("▶", Vector2i(1, 0)))

	_klaar = UiKit.knop_primair("Klaar", UiKit.FS_BODY)
	_klaar.pressed.connect(_afronden)
	voet.add_child(_klaar)

	chrome_footer().add_child(voet)


func _pijl(teken: String, richting: Vector2i) -> Button:
	var b := UiKit.button(teken, UiKit.FS_BODY)
	b.custom_minimum_size = PIJL_MAAT
	# Zonder selectie doen deze knoppen niets, en dat moet je aan de knop zien.
	# De uitgeschakelde staat komt uit UiKit.button(), dus hier staat hij niet.
	# Een focusrand van 2 px vreet een knop van 34 px op, en tikken hoeft geen focus.
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(_verschuif.bind(richting))
	_pijlen.append(b)
	return b


static func _gat() -> Control:
	var c := Control.new()
	c.custom_minimum_size = PIJL_MAAT
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


# --- Verschuiven ----------------------------------------------------------

func _gekozen() -> Blok:
	return _blokken.get(_keuze, null) as Blok


## Eén tik is één rasterstap op het geselecteerde blok.
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
	# Naast een blok laat de selectie staan. Een misser midden in een reeks
	# tikken zou anders de knoppen onder je duim uitschakelen.
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
	for b: Button in _pijlen:
		b.disabled = blok == null
	set_status("%s  ·  %d/%d op raster" % [
		blok.naam if blok != null else "Kies een blok",
		_op_raster_aantal(), _volgorde.size()])


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
