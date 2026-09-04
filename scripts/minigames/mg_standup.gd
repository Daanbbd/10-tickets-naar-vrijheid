extends MinigameBase
## BBD-202 — De stand-up. Zeven collega's praten na elkaar en je mag drie keer
## iemand afkappen. Twee van hen — nooit bij naam genoemd, dat moet uit hun
## regels blijken — melden iets bruikbaars; de rest praat gewoon. De opgave is
## letterlijk zichtbaar: een balk "Nuttige info" die vult zodra zo'n regel
## valt. Sta hij vol als de stand-up afloopt, dan is dat een geslaagde
## speelbeurt; sta hij niet vol (een van de twee is afgekapt vóór zijn regel),
## dan faal je — net als overal elders in dit spel gewoon een retry, geen
## game-over.
##
## De briefing wijst er één aan op rol, nooit op naam — Danny, de tweede,
## krijgt geen aanwijzing en dat is bewust de enige verborgen informatie in het
## spel. Wie iemand afkapt nadat zijn regel al gevallen is verliest niets: dat
## segment staat al groen en blijft dat.

# Kort genoeg om als tik te voelen, lang genoeg om te zien dat er iemand
# wegvalt. Twee keer FADE gaat van de klok af, dus dit is ook een prijs.
const FADE := 0.14

var _sprekers: Array[Dictionary] = []
var _idx: int = -1
var _spreker_t: float = 0.0

var _tijd: float = 42.0
var _tijd_max: float = 42.0
var _ingrepen: int = 3

var _afgekapt: Array[String] = []
var _gemist: Array[String] = []

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
# Zie de toelichting bij `_running = true` onderaan `_on_setup()`.
var _running: bool = false

# Elke belangrijke spreker krijgt precies één segment op de infobalk, in
# sprekervolgorde. "open" = nog onbeslist, "gevangen" = zijn regel is gehoord,
# "gemist" = afgekapt vóórdat die viel — en blijft dat de rest van de ronde.
var _belangrijke_ids: Array[String] = []
var _segment_status: Dictionary = {}

# QA-strategie, eenmalig bepaald bij setup (zie _bepaal_qa_afkap()): nooit een
# belangrijke spreker, wel de langste niet-belangrijke sprekers tot de
# interventies op zijn.
var _qa_afkap_ids: Array[String] = []

var _balk_vak: Control = null
var _balk: ColorRect = null
var _kaart: PanelContainer = null
var _naam: Label = null
var _regels: Array[Label] = []
var _flits: Label = null
var _knop: Button = null

var _info_kop: Label = null
var _info_teller: Label = null
var _info_segmenten: Array[ColorRect] = []

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
		if bool(s.get("belangrijk", false)):
			var id := String(s.get("id", ""))
			_belangrijke_ids.append(id)
			_segment_status[id] = "open"
	_qa_afkap_ids = _bepaal_qa_afkap()

	# De intro zelf verschijnt niet meer hier — dat doet `MinigameIntro`, vóór
	# dit scherm opent, gevuld met dezelfde `_ingrepen` via `Briefing.vul()`.
	var body := build_chrome(default_title(), "")
	_bouw_vast(body)
	_bouw_kaart(body)

	_volgende()
	_werk_balk_bij()
	_werk_status_bij()
	_werk_info_balk_bij()
	# Pas nu, aan het eind: `Shell.run_minigame()` voegt deze node toe en wacht
	# daarna een frame (`await get_tree().process_frame`) vóórdat hij
	# `setup()`/`_on_setup()` aanroept, en `_process()` draait al zodra de node
	# in de tree hangt. Zonder deze vlag greep `_werk_balk_bij()` in dat ene
	# frame naar `_balk` terwijl die nog null was — hetzelfde patroon als
	# `_running` in `mg_whack.gd` en `mg_pijplijn.gd`.
	_running = true


## QA kapt nooit een belangrijke spreker af, en kiest onder de rest de langste
## eerst — zoveel als er interventies zijn. Eenmalig bepaald, niet meer een
## levende "past het nog?"-vraag: met de infobalk als uitslag is de opgave
## "beide belangrijke regels horen", en de kortste weg daarheen is gewoon
## zoveel mogelijk lawaai wegknippen, niet live bijhouden wat er nog past.
func _bepaal_qa_afkap() -> Array[String]:
	var kandidaten: Array[Dictionary] = []
	for s: Dictionary in _sprekers:
		if not bool(s.get("belangrijk", false)):
			kandidaten.append(s)
	kandidaten.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("duur", 0.0)) > float(b.get("duur", 0.0)))
	var ids: Array[String] = []
	for i: int in mini(_ingrepen, kandidaten.size()):
		ids.append(String(kandidaten[i].get("id", "")))
	return ids


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

	_bouw_info_balk()

	_knop = UiKit.knop_primair("Afkappen", UiKit.FS_BODY)
	# Dit is de enige actie in de hele minigame en hij moet onder je duim liggen,
	# dus hij mag ruimer zijn dan de 24 px die UiKit als bodem aanhoudt.
	_knop.custom_minimum_size = Vector2(0, 32)
	_knop.focus_mode = Control.FOCUS_NONE
	_knop.disabled = _ingrepen <= 0
	_knop.pressed.connect(_op_afkappen)
	chrome_footer().add_child(_knop)


## Het doel van de minigame, letterlijk zichtbaar: één segment per belangrijke
## spreker, dat vult zodra zijn regel valt. Vervangt de wachtrij — die toonde
## spreekduur zonder ooit te zeggen wat daarmee te doen was, en dit vertelt
## precies waar de speelbeurt om draait zonder ooit te verraden wíe belangrijk
## is. Staat vast in `chrome_header()`, naast de tijdbalk: dit mag nooit
## wegscrollen, net zomin als de klok.
func _bouw_info_balk() -> void:
	var rij := HBoxContainer.new()
	rij.add_theme_constant_override("separation", 4)
	_info_kop = UiKit.label("Nuttige info", UiKit.FS_SMALL, UiKit.WIT)
	_info_kop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rij.add_child(_info_kop)
	_info_teller = UiKit.label("", UiKit.FS_SMALL, UiKit.WIT)
	_info_teller.autowrap_mode = TextServer.AUTOWRAP_OFF
	_info_teller.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rij.add_child(_info_teller)
	chrome_header().add_child(rij)

	var balk := HBoxContainer.new()
	balk.add_theme_constant_override("separation", 2)
	balk.custom_minimum_size = Vector2(0, 6)
	for id: String in _belangrijke_ids:
		var seg := ColorRect.new()
		seg.color = UiKit.NEUTRAAL_TINT
		seg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		balk.add_child(seg)
		_info_segmenten.append(seg)
	chrome_header().add_child(balk)


## Kleurt elk segment naar zijn status en telt de teller mee. Geroepen op
## setup en telkens een segment van status wisselt — niet elke frame, want
## niets hier verandert tussen twee statuswissels in.
func _werk_info_balk_bij() -> void:
	var gevangen := 0
	for i: int in _belangrijke_ids.size():
		var status := String(_segment_status.get(_belangrijke_ids[i], "open"))
		var kleur := UiKit.NEUTRAAL_TINT
		if status == "gevangen":
			kleur = UiKit.GROEN
			gevangen += 1
		elif status == "gemist":
			kleur = UiKit.ROOD
		if i < _info_segmenten.size():
			_info_segmenten[i].color = kleur
	_info_teller.text = "%d/%d" % [gevangen, _belangrijke_ids.size()]


## Vol is vol: elk segment moet "gevangen" zijn, niet alleen "niet meer open".
## Een "gemist" segment kan deze ronde niet meer groen worden, dus dat telt
## als niet-gehaald totdat de speelbeurt opnieuw begint.
func _balk_vol() -> bool:
	for id: String in _belangrijke_ids:
		if String(_segment_status.get(id, "open")) != "gevangen":
			return false
	return true


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

	_bouw_flits(kol)


## De meldingsregel onderaan de kaart: afkap-feedback en de "dit komt nog
## terug"-flash bij een gevangen segment. Stond hier ooit naast de wachtrij en
## wisselde daarmee van plek; nu heeft hij de onderkant van de kaart voor
## zichzelf.
func _bouw_flits(kol: VBoxContainer) -> void:
	var rek := Control.new()
	rek.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rek.size_flags_vertical = Control.SIZE_EXPAND_FILL
	kol.add_child(rek)

	var streep := ColorRect.new()
	streep.color = UiKit.LINE
	streep.custom_minimum_size = Vector2(0, 1)
	streep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kol.add_child(streep)

	_flits = UiKit.label("", UiKit.FS_SMALL, UiKit.GRIJS_OP_LICHT)
	_flits.visible = false
	kol.add_child(_flits)


func _process(delta: float) -> void:
	if not _running or _afgerond:
		return

	if _uitslag != 0:
		_afgerond = true
		# Vol is geslaagd, leeg (of half) is niet — ongeacht welke van de twee
		# manieren de stand-up beëindigde. Vroeger betekende `_uitslag > 0`
		# ("alle sprekers gehad") altijd winst en de klok op nul altijd
		# verlies; nu telt alleen of de infobalk vol staat op het moment dat
		# een van beide gebeurt.
		var c := content()
		var ok := _balk_vol()
		await finish_with_banner(ok,
			String(c.get("success" if ok else "failure", "")),
			maxi(0, roundi(_tijd)), _payload())
		return

	_tijd -= delta
	_puls_t += delta
	_werk_balk_bij()
	_werk_status_bij()
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
		# De markering van een vorige spreker mag niet blijven hangen op het
		# regelnummer van de volgende — anders licht bij Willem toevallig
		# dezelfde regel op als bij Jonathan, zonder dat het iets betekent.
		#
		# Terugzetten op INK, niet `remove_theme_color_override()`. Dat laatste
		# stond hier en haalde de kleur weg die `UiKit.label()` zélf als
		# override zet — er is geen thema-kleur die eronder vandaan komt, dus
		# de Label viel terug op zijn ingebouwde wit. Op de lichte kaart
		# (PANEL, #f3f3f3) was daarmee elke sprekersregel onleesbaar, de hele
		# minigame lang: alleen de groen gemarkeerde regel was nog te lezen.
		_regels[i].add_theme_color_override("font_color", UiKit.INK)
	_nuttig_regel_getoond = false
	_werk_regels_bij()
	# Geen aparte "hij is uitgesproken"-melding meer aan het eind van zijn beurt:
	# `_werk_regels_bij()` markeert een belangrijke regel al op het moment dat
	# hij verschijnt, en tegen de tijd dat de volle spreekduur om is, was die
	# regel dus altijd al getoond. Een tweede melding hier zou hetzelfde moment
	# een tweede keer vieren.


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
	# Alleen "gemist" als zijn nuttige regel nog niet gevallen was. Hier stond
	# vroeger alleen `bool(sp.get("belangrijk", false))`, zonder te kijken of
	# je 'm al gehoord had — dus iemand afkappen nádat je zijn info al had werd
	# nog steeds als fout gemeld. Dat segment staat dan al groen; afkappen
	# verandert daar niets meer aan.
	if bool(sp.get("belangrijk", false)) and not _nuttig_regel_getoond:
		_segment_status[id] = "gemist"
		_gemist.append(id)
		_werk_info_balk_bij()
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
	# Dit is ook het moment waarop zijn segment op de infobalk vult: niet pas
	# aan het eind van zijn beurt, en niet als hij toch nog wordt afgekapt ná
	# deze regel — dan staat hij al groen.
	if not _nuttig_regel_getoond and sp.has("nuttige_regel"):
		var idx := int(sp["nuttige_regel"])
		if idx < tot and idx < _regels.size():
			_nuttig_regel_getoond = true
			_markeer_nuttige_regel(_regels[idx])
			var id := String(sp.get("id", ""))
			if id in _belangrijke_ids:
				_segment_status[id] = "gevangen"
				_werk_info_balk_bij()
				var gevangen := 0
				for status: Variant in _segment_status.values():
					if String(status) == "gevangen":
						gevangen += 1
				_flits_tonen("%s (%d/%d)" % [
					String(content().get("nuttig", "")), gevangen, _belangrijke_ids.size()
				], UiKit.GROEN_OP_LICHT)


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
	_flits.visible = true
	if _flits_tween != null and _flits_tween.is_running():
		_flits_tween.kill()
	_flits_tween = create_tween()
	_flits_tween.tween_interval(1.0)
	_flits_tween.tween_property(_flits, "modulate:a", 0.0, 0.5)
	_flits_tween.tween_callback(func() -> void: _flits.visible = false)


func _huidig() -> Dictionary:
	if _idx < 0 or _idx >= _sprekers.size():
		return {}
	return _sprekers[_idx]


func _duur() -> float:
	return maxf(0.3, float(_huidig().get("duur", 5.0)))


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


## QA: speelt de stand-up echt uit, volgens de strategie die `_bepaal_qa_afkap()`
## al bij setup bepaalde — nooit een belangrijke spreker, wel de langste
## niet-belangrijke sprekers, zoveel als er interventies zijn. Kapt direct bij
## het begin van zo iemands beurt af: er valt niets meer af te wegen, de keuze
## lag al vast.
func _qa_overweeg() -> void:
	if _wissel or _ingrepen <= 0:
		return
	var sp := _huidig()
	if sp.is_empty():
		return
	if String(sp.get("id", "")) in _qa_afkap_ids:
		_op_afkappen()


func qa_solve() -> void:
	_qa = true
