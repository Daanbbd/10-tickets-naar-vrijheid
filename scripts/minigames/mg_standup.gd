extends MinigameBase
## BBD-202 — De stand-up. Zeven collega's praten na elkaar, samen ruim langer
## dan het tijdsbudget, en je mag drie keer iemand afkappen — één afkapping
## redt je nooit: zelfs de langste spreker alleen eraf halen is niet genoeg.
##
## De klok loopt terwijl je luistert, dus de vraag is niet "wie kap ik af" maar
## "hoe lang durf ik te wachten voordat ik het weet", en dat meerdere keren op
## rij. Twee sprekers melden iets wat later nog terugkomt; wie dat zijn staat
## nergens en moet uit hun regels blijken. De briefing wijst er één aan op rol,
## nooit op naam — Danny, de tweede, krijgt geen aanwijzing en dat is bewust de
## enige verborgen informatie in het spel. Afkappen kost je die informatie,
## maar nooit de opdracht: het verlies belandt in de payload en niet in de
## uitslag.

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

# Of de nuttige regel van de huidige spreker al gemarkeerd is. Per spreker
# eenmalig: zonder deze vlag zou _werk_regels_bij() 'm elk frame opnieuw
# markeren zolang hij zichtbaar blijft.
var _nuttig_regel_getoond: bool = false
# Voor de dreigingspuls op de tijdbalk in de laatste seconden.
var _puls_t: float = 0.0

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

	# De intro zelf verschijnt niet meer hier — dat doet `MinigameIntro`, vóór
	# dit scherm opent, gevuld met dezelfde `_ingrepen` via `Briefing.vul()`.
	var body := build_chrome(default_title(), "")
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
	_rest = UiKit.label("", UiKit.FS_SMALL, UiKit.GRIJS_OP_LICHT)
	_rest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_kop.add_child(_rest)
	# Zonder afbreken uit valt "+2" in een HBox naast een uitrekkend label uiteen
	# in een "+" en een "2" op de regel eronder, en dan is de kop dubbel hoog.
	_meer = UiKit.label("", UiKit.FS_SMALL, UiKit.GRIJS_OP_LICHT)
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
		var nm := UiKit.label("", UiKit.FS_SMALL, UiKit.GRIJS_OP_LICHT)
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
	_flits = UiKit.label("", UiKit.FS_SMALL, UiKit.GRIJS_OP_LICHT)
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
	_puls_t += delta
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
	# Wie er net klaar is, vóór de kaart omslaat naar de volgende: alleen op
	# dit moment weten we of hij belangrijk was én is uitgesproken in plaats
	# van afgekapt. Bij setup (_idx == -1) is dit leeg, dus geen valse start.
	var vorige := _huidig()
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
		# De markering van een vorige spreker mag niet blijven hangen op het
		# regelnummer van de volgende — anders licht bij Willem toevallig
		# dezelfde regel op als bij Jonathan, zonder dat het iets betekent.
		_regels[i].remove_theme_color_override("font_color")
	_nuttig_regel_getoond = false
	_werk_regels_bij()
	_werk_wachtrij_bij()

	# De positieve tegenhanger van de "gemist"-melding in _op_afkappen(): wie
	# uitgesproken raakt in plaats van afgekapt te worden, bevestigt dat
	# luisteren loonde. Zonder deze melding is "iets nuttigs horen" een gebeurtenis
	# zonder feedback, en alleen het missen ervan (bij afkappen) was zichtbaar.
	if not vorige.is_empty() and bool(vorige.get("belangrijk", false)) \
			and not (String(vorige.get("id", "")) in _afgekapt):
		_flits_tonen(String(content().get("nuttig", "")), UiKit.GROEN)


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
	var kleur := UiKit.GRIJS_OP_LICHT
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

	# De regel die er inhoudelijk toe doet licht op zodra hij zichtbaar wordt —
	# niet vooraf, niet per persoon. Wie hem niet hoort (afgekapt vóór hij
	# valt) heeft 'm gewoon nooit gezien; geen vooruitblik, geen oneerlijke gok.
	if not _nuttig_regel_getoond and sp.has("nuttige_regel"):
		var idx := int(sp["nuttige_regel"])
		if idx < tot and idx < _regels.size():
			_nuttig_regel_getoond = true
			_markeer_nuttige_regel(_regels[idx])


## Kleurt de regel groen en geeft 'm een korte pop, op het moment dat hij
## verschijnt — hetzelfde moment waarop een luisterende speler 'm zou lezen.
## Geen aankondiging vooraf, geen los label erbij: de tekst zelf is de tell.
func _markeer_nuttige_regel(l: Label) -> void:
	# GROEN_OP_LICHT, niet GROEN: de kaart staat op UiKit.PANEL (licht), en
	# GROEN zelf is een derivaat voor een donkere ondergrond (P3).
	l.add_theme_color_override("font_color", UiKit.GROEN_OP_LICHT)
	l.pivot_offset = Vector2(0, l.size.y * 0.5)
	var tw := create_tween()
	tw.tween_property(l, "scale", Vector2(1.06, 1.06), 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	AudioDirector.play_ui(&"pak")


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


# Onder welk aandeel resterende tijd de balk begint te knipperen — hetzelfde
# punt waar hij vroeger in één sprong hard rood werd, nu ook voelbaar in
# plaats van alleen zichtbaar.
const _PULS_DREMPEL := 0.2
const _PULS_SNELHEID := 9.0


func _werk_balk_bij() -> void:
	var deel := clampf(_tijd / maxf(0.001, _tijd_max), 0.0, 1.0)
	_balk.anchor_right = deel
	_balk.color = _tijdkleur(deel)
	# Een knipperende balk in de laatste seconden: "steeds roder" moet je
	# voelen aankomen, niet pas zien als de kleur al omgeslagen is.
	if deel <= _PULS_DREMPEL:
		_balk.modulate.a = lerpf(0.55, 1.0, (sin(_puls_t * _PULS_SNELHEID) + 1.0) * 0.5)
	else:
		_balk.modulate.a = 1.0


## Vloeiend van groen via oranje naar rood, in plaats van drie harde banden:
## de urgentie loopt continu op in plaats van in twee sprongen te springen.
static func _tijdkleur(deel: float) -> Color:
	if deel >= 0.5:
		return UiKit.GROEN.lerp(UiKit.ORANJE, (1.0 - deel) / 0.5)
	return UiKit.ORANJE.lerp(UiKit.ROOD, (0.5 - deel) / 0.5)


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
