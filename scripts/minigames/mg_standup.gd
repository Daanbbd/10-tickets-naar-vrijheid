extends MinigameBase
## BBD-202 — De stand-up. Zeven collega's praten na elkaar, samen langer dan het
## tijdsbudget, en je mag drie keer iemand afkappen.
##
## De klok loopt terwijl je luistert, dus de vraag is niet "wie kap ik af" maar
## "hoe lang durf ik te wachten voordat ik het weet". Twee sprekers melden iets
## wat later nog terugkomt; wie dat zijn staat nergens en moet uit hun regels
## blijken. Afkappen kost je die informatie, maar nooit de opdracht: het verlies
## belandt in de payload en niet in de uitslag.

# Kort genoeg om als tik te voelen, lang genoeg om te zien dat er iemand
# wegvalt. Twee keer FADE gaat van de klok af, dus dit is ook een prijs.
const FADE := 0.14

# QA wacht met afkappen tot het echt niet meer past. Deze marge is de speling
# die overblijft: te klein en een enkel haperend frame laat de doorloop falen,
# te groot en de autopilot kapt af terwijl het nog niet nodig is.
const QA_MARGE := 4.0

# Drie namen vooruit, de rest als "+4" achter de kop. Zeven rijen passen niet:
# een rij is een regel pixelfont hoog en Jonathan vult met zijn drie lange
# regels de kaart al bijna. Bij vier rijen kwam er tijdens Jonathan een
# schuifbalk in de kaart en verdween de laatste naam uit beeld — precies bij de
# spreker waar de afweging over gaat.
const RIJ_MAX := 3
const NAAM_BREED := 46

var _sprekers: Array[Dictionary] = []
var _idx: int = -1
var _spreker_t: float = 0.0

var _tijd: float = 42.0
var _tijd_max: float = 42.0
var _ingrepen: int = 3

var _afgekapt: Array[String] = []
var _gemist: Array[String] = []
var _gemist_gemeld: bool = false

# Tijdens de wisseltween staat de spreker stil maar loopt de stand-up door.
var _wissel: bool = false
var _qa: bool = false
# 0 = nog bezig, 1 = gehaald, -1 = tijd om. De uitslag kan op drie plekken
# vallen — de klok, een tik, een tweencallback — maar de banner wacht bijna twee
# seconden, en dat afwachten hoort in _process en niet halverwege een tween.
var _uitslag: int = 0
var _afgerond: bool = false

var _langste: float = 1.0

var _balk_vak: Control = null
var _balk: ColorRect = null
var _kaart: PanelContainer = null
var _naam: Label = null
var _regels: Array[Label] = []
var _flits: Label = null
var _knop: Button = null

var _rest: Label = null
var _meer: Label = null
var _kop: HBoxContainer = null
var _lijst: VBoxContainer = null
var _rij_naam: Array[Label] = []
var _rij_vul: Array[ColorRect] = []

var _kaart_tween: Tween = null
var _flits_tween: Tween = null


func _on_setup() -> void:
	var c := content()
	if c.is_empty():
		fail()
		return

	_tijd_max = float(c.get("tijd", 42.0))
	_tijd = _tijd_max
	_ingrepen = int(c.get("ingrepen", 3))
	for s: Variant in c.get("sprekers", []) as Array:
		_sprekers.append(s as Dictionary)
	if _sprekers.is_empty():
		fail()
		return
	for s: Dictionary in _sprekers:
		_langste = maxf(_langste, float(s.get("duur", 5.0)))

	var body := build_chrome(default_title(), String(c.get("intro", "")))
	_bouw_vast(body)
	_bouw_kaart(body)

	_volgende()
	_werk_balk_bij()
	_werk_status_bij()
	_werk_rest_bij()


## De tijdbalk en de afkapknop horen niet in de scroll: dit zijn de twee dingen
## die je op elk moment nodig hebt. De tijdbalk boven de inhoud, de knop eronder.
func _bouw_vast(_body: VBoxContainer) -> void:
	_balk_vak = Control.new()
	_balk_vak.custom_minimum_size = Vector2(0, 7)
	_balk_vak.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_balk_vak.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var achter := ColorRect.new()
	achter.color = UiKit.NEUTRAAL_TINT
	achter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.full_rect(achter)
	_balk_vak.add_child(achter)
	# De vulling krimpt via zijn rechteranker, niet via size: een Control krijgt
	# zijn formaat van de ouder, dus een size die je zelf zet is het volgende
	# frame weer weg.
	_balk = ColorRect.new()
	_balk.color = UiKit.GROEN
	_balk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_balk.anchor_left = 0.0
	_balk.anchor_top = 0.0
	_balk.anchor_right = 1.0
	_balk.anchor_bottom = 1.0
	_balk_vak.add_child(_balk)
	chrome_header().add_child(_balk_vak)

	_knop = UiKit.knop_primair("Afkappen", UiKit.FS_BODY)
	# Dit is de enige actie in de hele minigame en hij moet onder je duim liggen,
	# dus hij mag ruimer zijn dan de 24 px die UiKit als bodem aanhoudt.
	_knop.custom_minimum_size = Vector2(0, 32)
	_knop.focus_mode = Control.FOCUS_NONE
	_knop.disabled = _ingrepen <= 0
	_knop.pressed.connect(_op_afkappen)
	chrome_footer().add_child(_knop)


func _bouw_kaart(body: VBoxContainer) -> void:
	# Eén kaart die van spreker wisselt, geen kaart per spreker: op deze kaart
	# loopt de wegvaltween, en tweenen op een node die je daarna weggooit is
	# precies de crash die je in een real-time minigame niet wil.
	_kaart = PanelContainer.new()
	# Zes pixels marge boven en onder, zoals UiKit.panel() ze zet, is op een
	# kaart die de hele resthoogte vult net te veel: Jonathans drie regels plus
	# de wachtrij schoten er een handvol pixels over en dat leverde een
	# schuifbalk op. Links en rechts blijft het zes, want daar staat de tekst
	# tegen de rand aan.
	var sb := UiKit.panel(UiKit.PANEL, UiKit.LINE)
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	_kaart.add_theme_stylebox_override("panel", sb)
	# De kaart vult de hoogte die overblijft. Anders staat er tussen de spreker
	# en de knop een gat van driehonderd pixels, en verspringt de tekst bij
	# elke spreker met een andere hoeveelheid regels.
	_kaart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_kaart)

	var kol := VBoxContainer.new()
	# 1 px tussen de onderdelen, niet 2: de regels van een spreker zijn samen
	# één alinea, en de zeven tussenruimtes die dat scheelt zijn precies wat
	# Jonathans kaart nodig heeft om zonder schuifbalk te passen.
	kol.add_theme_constant_override("separation", 1)
	_kaart.add_child(kol)

	_naam = UiKit.label("", UiKit.FS_HEAD, UiKit.INK)
	kol.add_child(_naam)

	var meeste := 0
	for s: Dictionary in _sprekers:
		meeste = maxi(meeste, (s.get("regels", []) as Array).size())
	for i: int in meeste:
		var l := UiKit.label("", UiKit.FS_SMALL, UiKit.INK)
		l.visible = false
		kol.add_child(l)
		_regels.append(l)

	_bouw_wachtrij(kol)


## Wie er nog aankomt, onderaan dezelfde kaart. Zonder deze rij is "moet ik
## deze afkappen" geen afweging maar een schrikreactie op de klok: je ziet niet
## dat er na hem nog vier man staat.
##
## De rij noemt alleen naam en lengte. Geen enkele markering verraadt wie iets
## te melden heeft — dat het loont om Jonathan te laten praten moet uit zijn
## eigen regels blijken, en zijn balkje maakt hem juist het aantrekkelijkste
## slachtoffer.
func _bouw_wachtrij(kol: VBoxContainer) -> void:
	# Rekt de ruimte tussen de laatste regel en de wachtrij op, zodat de rij aan
	# de onderrand van de kaart blijft plakken in plaats van mee te schuiven met
	# het aantal regels dat de spreker al gezegd heeft.
	var rek := Control.new()
	rek.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rek.size_flags_vertical = Control.SIZE_EXPAND_FILL
	kol.add_child(rek)

	var streep := ColorRect.new()
	streep.color = UiKit.LINE
	streep.custom_minimum_size = Vector2(0, 1)
	streep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kol.add_child(streep)

	_kop = HBoxContainer.new()
	_kop.add_theme_constant_override("separation", 4)
	kol.add_child(_kop)
	# De optelsom die de speler zelf zou moeten maken: dit getal naast de klok
	# rechtsboven is de hele beslissing.
	_rest = UiKit.label("", UiKit.FS_SMALL, UiKit.GRIJS)
	_rest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_kop.add_child(_rest)
	# Zonder afbreken uit valt "+2" in een HBox naast een uitrekkend label uiteen
	# in een "+" en een "2" op de regel eronder, en dan is de kop dubbel hoog.
	_meer = UiKit.label("", UiKit.FS_SMALL, UiKit.GRIJS)
	_meer.autowrap_mode = TextServer.AUTOWRAP_OFF
	_meer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_kop.add_child(_meer)

	_lijst = VBoxContainer.new()
	_lijst.add_theme_constant_override("separation", 1)
	kol.add_child(_lijst)
	# Altijd RIJ_MAX rijen in de boom, ook als de rij korter wordt: een rij die
	# verdwijnt maakt de kaart lager en dan kruipt de knop weg onder je duim.
	for i: int in RIJ_MAX:
		var rij := HBoxContainer.new()
		rij.add_theme_constant_override("separation", 4)
		_lijst.add_child(rij)

		# Afbreken uit en clippen aan: een naam die op twee regels valt maakt
		# deze rij hoger dan de andere drie.
		var nm := UiKit.label("", UiKit.FS_SMALL, UiKit.GRIJS)
		nm.autowrap_mode = TextServer.AUTOWRAP_OFF
		nm.clip_text = true
		nm.custom_minimum_size = Vector2(NAAM_BREED, 0)
		rij.add_child(nm)
		_rij_naam.append(nm)

		var vak := Control.new()
		vak.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vak.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vak.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		vak.custom_minimum_size = Vector2(0, 5)
		rij.add_child(vak)
		var spoor := ColorRect.new()
		spoor.color = UiKit.NEUTRAAL_TINT
		spoor.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UiKit.full_rect(spoor)
		vak.add_child(spoor)
		var vul := ColorRect.new()
		vul.color = UiKit.GRIJS
		vul.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vul.anchor_left = 0.0
		vul.anchor_top = 0.0
		vul.anchor_right = 1.0
		vul.anchor_bottom = 1.0
		vak.add_child(vul)
		_rij_vul.append(vul)

	# De meldingsregel deelt deze plek met de wachtrij in plaats van er eigen
	# hoogte bij te vragen. Twee redenen: op 416 px is er niets over — Jonathans
	# drie regels vullen de kaart tot de rand — en de melding gaat juist over de
	# rij die eronder verspringt. Hij is korter dan de rij, dus hij kan de kaart
	# nooit over de rand duwen, en de knop staat buiten de scroll en beweegt niet.
	_flits = UiKit.label("", UiKit.FS_SMALL, UiKit.GRIJS)
	_flits.visible = false
	kol.add_child(_flits)


func _process(delta: float) -> void:
	if _afgerond:
		return

	if _uitslag != 0:
		_afgerond = true
		var c := content()
		var ok := _uitslag > 0
		await finish_with_banner(ok,
			String(c.get("success" if ok else "failure", "")),
			maxi(0, roundi(_tijd)), _payload())
		return

	_tijd -= delta
	_werk_balk_bij()
	_werk_status_bij()
	_werk_rest_bij()
	if _tijd <= 0.0:
		_uitslag = -1
		return

	# De autopilot beslist hier en niet in qa_solve: die wordt één keer
	# aangeroepen, en een stand-up van veertig seconden speel je niet uit in
	# één frame.
	if _qa:
		_qa_overweeg()

	if _wissel:
		return

	_spreker_t += delta
	_werk_regels_bij()
	if _spreker_t >= _duur():
		_volgende()


## De volgende spreker aan het woord. Buiten bereik betekent: de stand-up is
## rond, en dat is de enige winroute.
func _volgende() -> void:
	# De tween die hierheen leidt loopt nog als de klok er tussendoor op nul
	# komt. Zonder deze rem overschrijft de laatste wissel dan een verloren
	# stand-up met een gehaalde.
	if _uitslag != 0:
		return
	_wissel = false
	_idx += 1
	_spreker_t = 0.0
	if _idx >= _sprekers.size():
		_uitslag = 1
		return

	var sp := _huidig()
	_naam.text = String(sp.get("naam", "?"))
	var regels := sp.get("regels", []) as Array
	for i: int in _regels.size():
		_regels[i].text = String(regels[i]) if i < regels.size() else ""
		_regels[i].visible = false
	_werk_regels_bij()
	_werk_wachtrij_bij()


func _op_afkappen() -> void:
	if _uitslag != 0 or _wissel or _ingrepen <= 0:
		return
	var sp := _huidig()
	if sp.is_empty():
		return

	_ingrepen -= 1
	_knop.disabled = _ingrepen <= 0
	var id := String(sp.get("id", ""))
	_afgekapt.append(id)

	var melding := String(content().get("kap_regel", ""))
	var kleur := UiKit.GRIJS
	if bool(sp.get("belangrijk", false)):
		# Geen straf, geen tijdverlies: wat je kwijt bent is wat hij nog ging
		# zeggen. Dat merk je later, dus hier hoort niet meer dan een hint.
		_gemist.append(id)
		if not _gemist_gemeld:
			_gemist_gemeld = true
			melding = String(content().get("gemist", melding))
			kleur = UiKit.ORANJE
	_flits_tonen(melding, kleur)
	AudioDirector.play_ui(&"klik")

	_wissel = true
	if _kaart_tween != null and _kaart_tween.is_running():
		_kaart_tween.kill()
	_kaart_tween = create_tween()
	_kaart_tween.tween_property(_kaart, "modulate:a", 0.0, FADE)
	_kaart_tween.tween_callback(_volgende)
	_kaart_tween.tween_property(_kaart, "modulate:a", 1.0, FADE)


## Regels komen één voor één, verdeeld over de spreektijd. Daarom kost wachten
## op wat iemand te melden heeft ook echt tijd.
func _werk_regels_bij() -> void:
	var sp := _huidig()
	var aantal := (sp.get("regels", []) as Array).size()
	if aantal <= 0:
		return
	var per := maxf(0.3, _duur() / float(aantal))
	var tot := clampi(int(_spreker_t / per) + 1, 1, aantal)
	for i: int in _regels.size():
		_regels[i].visible = i < tot


## Namen en balkjes wisselen alleen als de rij korter wordt, dus dit hoort bij
## een sprekerwissel en niet in _process.
func _werk_wachtrij_bij() -> void:
	var komend := _sprekers.size() - (_idx + 1)
	var toon := clampi(komend, 0, _rij_naam.size())
	for i: int in _rij_naam.size():
		if i >= toon:
			_rij_naam[i].text = ""
			_rij_vul[i].visible = false
			continue
		var sp := _sprekers[_idx + 1 + i]
		_rij_naam[i].text = String(sp.get("naam", ""))
		# Ondergrens van 0.06: Victor duurt drie seconden en zonder minimum is
		# zijn balkje een streepje dat je niet meer als balkje leest.
		_rij_vul[i].anchor_right = clampf(float(sp.get("duur", 5.0)) / _langste, 0.06, 1.0)
		_rij_vul[i].visible = true
	_meer.text = "+%d" % (komend - toon) if komend > toon else ""


func _werk_rest_bij() -> void:
	_rest.text = "nog %d sec praten" % maxi(0, ceili(_rest_spreektijd()))


func _werk_balk_bij() -> void:
	var deel := clampf(_tijd / maxf(0.001, _tijd_max), 0.0, 1.0)
	_balk.anchor_right = deel
	_balk.color = UiKit.GROEN if deel > 0.45 else (UiKit.ORANJE if deel > 0.2 else UiKit.ROOD)


func _werk_status_bij() -> void:
	set_status("%02d sec  ·  %dx afkappen" % [maxi(0, ceili(_tijd)), _ingrepen])


func _flits_tonen(tekst: String, kleur: Color) -> void:
	_flits.text = tekst
	_flits.add_theme_color_override("font_color", kleur)
	_flits.modulate.a = 1.0
	_onderkant(true)
	if _flits_tween != null and _flits_tween.is_running():
		_flits_tween.kill()
	_flits_tween = create_tween()
	_flits_tween.tween_interval(1.0)
	_flits_tween.tween_property(_flits, "modulate:a", 0.0, 0.5)
	_flits_tween.tween_callback(_onderkant.bind(false))


## Wisselt de onderkant van de kaart tussen de melding en de namen. De kop met
## "nog zoveel sec praten" blijft staan: dat getal is net veranderd door de
## ingreep en is precies waar je op dat moment naar kijkt. Melding plus kop is
## nog altijd lager dan kop plus drie namen, dus dit kan de kaart niet over de
## rand duwen.
func _onderkant(melding: bool) -> void:
	_flits.visible = melding
	_lijst.visible = not melding


func _huidig() -> Dictionary:
	if _idx < 0 or _idx >= _sprekers.size():
		return {}
	return _sprekers[_idx]


func _duur() -> float:
	return maxf(0.3, float(_huidig().get("duur", 5.0)))


## Wat er nog gesproken moet worden, inclusief de rest van wie nu aan het woord
## is. Zodra dit niet meer in de klok past moet er iemand af.
func _rest_spreektijd() -> float:
	var som := maxf(0.0, _duur() - _spreker_t)
	for i: int in range(_idx + 1, _sprekers.size()):
		som += maxf(0.0, float(_sprekers[i].get("duur", 5.0)))
	return som


func _payload() -> Dictionary:
	return {
		&"afgekapt": _afgekapt,
		&"gemist": _gemist,
		&"tijd_over": maxf(0.0, _tijd),
	}


func _exit_tree() -> void:
	if _kaart_tween != null:
		_kaart_tween.kill()
	if _flits_tween != null:
		_flits_tween.kill()


## QA: speelt de stand-up echt uit. Wachten tot het niet meer past en dan de
## huidige spreker afkappen, mits die niets belangrijks meldt — dezelfde route
## die een speler moet vinden, dus met een lege `gemist` aan het eind.
func _qa_overweeg() -> void:
	if _wissel or _ingrepen <= 0:
		return
	var sp := _huidig()
	if sp.is_empty() or bool(sp.get("belangrijk", false)):
		return
	if _rest_spreektijd() + QA_MARGE <= _tijd:
		return
	_op_afkappen()


func qa_solve() -> void:
	_qa = true
