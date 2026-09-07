extends MinigameBase
## BBD-202 — De stand-up. Zeven collega's praten na elkaar en je mag drie keer
## iemand afkappen. Twee van hen — nooit bij naam genoemd, dat moet uit hun
## regels blijken — melden iets bruikbaars; de rest praat gewoon. De opgave is
## letterlijk zichtbaar: een balk "Gehoord" die vult zodra zo'n regel valt. Sta
## hij vol als de stand-up afloopt, dan is dat een geslaagde speelbeurt. Kap je
## iemand af vóórdat zijn bruikbare regel viel, dan stopt de ronde meteen: de
## kaart blijft op die spreker staan en de banner noemt hem bij naam. Ook dat
## is gewoon een retry, geen game-over — net als overal elders in dit spel.
##
## De briefing wijst er één aan op rol, nooit op naam — Danny, de tweede,
## krijgt geen aanwijzing en dat is bewust de enige verborgen informatie in het
## spel. Wie iemand afkapt nadat zijn regel al gevallen is verliest niets: dat
## segment staat al groen en blijft dat.

# Kort genoeg om als tik te voelen, lang genoeg om te zien dat er iemand
# wegvalt. Twee keer FADE gaat van de klok af, dus dit is ook een prijs.
const FADE := 0.14

## Wat een verkeerde notitie van de klok kost. Genoeg om alles-opschrijven
## onhaalbaar te maken, te weinig om één misser fataal te laten zijn — dit is
## een comedy adventure en geen uitdaging (zie `docs/GAME_DESIGN.md`).
const FOUT_SEC := 3.0

# P3: de klokbalk zelf (vak, vulling, kleurcurve, knipperpuls) komt nu uit
# `minigame_base.gd`'s `bouw_klokbalk()`/`zet_klokbalk()` — dezelfde balk als
# `mg_scope.gd` en `mg_abgevecht.gd` gebruiken, in plaats van een vijfde kopie.

var _sprekers: Array[Dictionary] = []
var _idx: int = -1
var _spreker_t: float = 0.0

var _tijd: float = 42.0
var _tijd_max: float = 42.0
var _ingrepen: int = 3

var _afgekapt: Array[String] = []
var _gemist: Array[String] = []
# Wie er afgekapt werd vóórdat zijn bruikbare regel viel — leeg zolang dat nog
# niemand is. Zodra dit gevuld raakt eindigt de ronde meteen (zie
# `_op_afkappen()`), en `_process()` gebruikt de naam voor de bannertekst.
var _gemist_naam: String = ""

# Of de nuttige regel van de huidige spreker al gemarkeerd is. Per spreker
# eenmalig: zonder deze vlag zou _werk_regels_bij() 'm elk frame opnieuw
# markeren zolang hij zichtbaar blijft.
var _nuttig_regel_getoond: bool = false

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

var _kaart: PanelContainer = null
var _naam: Label = null
var _teller: Label = null
var _regels: Array[Label] = []
var _flits: Label = null
var _knop: Button = null
var _noteer_knop: Button = null

## Wat de speler al genoteerd heeft, als "sprekerid:regelindex". Eén notitie per
## regel: twee keer op dezelfde regel tikken kost niet twee keer de klok, want
## dat is geen tweede afweging maar een dubbele tik.
var _genoteerd: Dictionary = {}

## De hoogste regelindex die nu op de kaart staat. `_werk_regels_bij()` houdt
## hem bij, `_op_opschrijven()` beoordeelt hem.
var _regel_nu: int = -1

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

	# P1: de intro verschijnt niet hier expliciet — de chrome bouwt hem zelf als
	# overlay ín het veld, uit `content().get("intro")`, gevuld met dezelfde
	# `_ingrepen` via `Briefing.vul()`. Deze lege string blijft staan zodat de
	# aanroep ongewijzigd is (zie het contract van `build_chrome_veld()`).
	#
	# De veldvorm en niet de lijstvorm: dit is een real-time spel, geen
	# formulier, en de kop op FS_HEAD at twee regels die hier niets deden.
	var body := build_chrome_veld(default_title(), "")
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
	# P3: de klokbalk zelf komt nu uit `minigame_base.gd`, zodat er één balk is
	# en niet vier — zie `bouw_klokbalk()`/`zet_klokbalk()`.
	chrome_header().add_child(bouw_klokbalk())

	_bouw_info_balk()

	# Twee acties naast elkaar, want er zijn er nu twee.
	#
	# Hiervóór was "Afkappen" de enige knop in de hele minigame, en de nuttige
	# regel ving zichzelf op het moment dat hij verscheen — inclusief een groene
	# markering die verklapte dát dit hem was. De speler keek dus veertig
	# seconden naar regels die zichzelf afhandelden en mocht drie keer iemand
	# wegsturen. Daans oordeel (#20): *"Ik kan maar een paar keer afkappen, de
	# rest van de mini game zit ik passief te wachten en te hopen dat ik het
	# haal. Wat een kutgame."*
	#
	# Nu is opschrijven de opgave. Elke regel is een afweging: is dit het ding
	# dat je moet melden, of praat er iemand. Een verkeerde notitie kost
	# `FOUT_SEC` van de klok, dus alles maar opschrijven werkt niet — achttien
	# regels tegen drie seconden per misser is meer dan de klok lang is.
	var rij := HBoxContainer.new()
	rij.add_theme_constant_override("separation", 3)

	_noteer_knop = UiKit.knop_primair("Opschrijven", UiKit.FS_SMALL)
	_noteer_knop.custom_minimum_size = Vector2(0, 32)
	_noteer_knop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_noteer_knop.focus_mode = Control.FOCUS_NONE
	_noteer_knop.pressed.connect(_op_opschrijven)
	rij.add_child(_noteer_knop)

	_knop = UiKit.button(_kap_label(), UiKit.FS_SMALL)
	_knop.custom_minimum_size = Vector2(0, 32)
	_knop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_knop.focus_mode = Control.FOCUS_NONE
	_knop.disabled = _ingrepen <= 0
	_knop.pressed.connect(_op_afkappen)
	rij.add_child(_knop)

	chrome_footer().add_child(rij)


## Het doel van de minigame, letterlijk zichtbaar: één segment per belangrijke
## spreker, dat vult zodra zijn regel valt. Vervangt de wachtrij — die toonde
## spreekduur zonder ooit te zeggen wat daarmee te doen was, en dit vertelt
## precies waar de speelbeurt om draait zonder ooit te verraden wíe belangrijk
## is. Staat vast in `chrome_header()`, naast de tijdbalk: dit mag nooit
## wegscrollen, net zomin als de klok.
func _bouw_info_balk() -> void:
	var rij := HBoxContainer.new()
	rij.add_theme_constant_override("separation", 4)
	_info_kop = UiKit.label("Gehoord", UiKit.FS_SMALL, UiKit.WIT)
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
	_info_teller.text = "%d van %d" % [gevangen, _belangrijke_ids.size()]


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

	# Naam en sprekerteller op één regel: de naam mag het meeste van de breedte
	# hebben, de teller staat rechts en blijft op de basislijn van de naam
	# staan (SIZE_SHRINK_END) in plaats van in het midden van de rij te centreren.
	var naam_rij := HBoxContainer.new()
	naam_rij.add_theme_constant_override("separation", 4)
	kol.add_child(naam_rij)

	_naam = UiKit.label("", UiKit.FS_HEAD, UiKit.INK)
	_naam.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	naam_rij.add_child(_naam)

	# GRIJS_OP_LICHT, niet GRIJS: de kaart staat op UiKit.PANEL (licht), zie de
	# toelichting bij `_markeer_nuttige_regel()` verderop over dezelfde keuze.
	_teller = UiKit.label("", UiKit.FS_SMALL, UiKit.GRIJS_OP_LICHT)
	_teller.autowrap_mode = TextServer.AUTOWRAP_OFF
	_teller.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_teller.size_flags_vertical = Control.SIZE_SHRINK_END
	naam_rij.add_child(_teller)

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
		# Vol is geslaagd, leeg (of half) is niet — ongeacht welke van de drie
		# manieren de stand-up eindigde: de klok op nul, alle sprekers gehad,
		# of een belangrijke spreker afgekapt vóór zijn regel viel. Vroeger
		# betekende `_uitslag > 0` ("alle sprekers gehad") altijd winst en de
		# klok op nul altijd verlies; nu telt alleen of de infobalk vol staat
		# op het moment dat een van deze drie gebeurt.
		var c := content()
		var ok := _balk_vol()
		if _gemist_naam != "":
			# De speler moet het rode segment en de flits van `_op_afkappen()`
			# nog even kunnen zien voordat de banner erover valt. `create_timer`
			# met process_always (true, false, true), zoals docs/MINIGAMES.md
			# voorschrijft voor een timer die ook tijdens een gepauzeerde tree
			# door moet lopen.
			await get_tree().create_timer(1.2, true, false, true).timeout
		var tekst := ""
		if ok:
			tekst = String(c.get("success", ""))
		elif _gemist_naam != "":
			tekst = String(c.get("failure_gemist", c.get("failure", ""))) \
				.format({"naam": _gemist_naam})
		else:
			tekst = String(c.get("failure", ""))
		await finish_with_banner(ok, tekst, maxi(0, roundi(_tijd)), _payload())
		return

	_tijd -= delta
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
	_teller.text = "%d van %d" % [_idx + 1, _sprekers.size()]
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
	_knop.text = _kap_label()
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
	var mist_belangrijke_melding := bool(sp.get("belangrijk", false)) and not _nuttig_regel_getoond
	if mist_belangrijke_melding:
		_segment_status[id] = "gemist"
		_gemist.append(id)
		_werk_info_balk_bij()
		melding = String(content().get("gemist", melding))
		kleur = UiKit.ORANJE
	_flits_tonen(melding, kleur)
	AudioDirector.play_ui(&"klik")

	if mist_belangrijke_melding:
		# Winnen kan vanaf hier niet meer: één van de twee bruikbare meldingen
		# is nu definitief gemist, en de balk kan deze ronde niet meer vol
		# komen (zie `_balk_vol()`). Doorspelen zou de speler alleen nog een
		# kansloze stand-up laten uitzitten tot de klok om is. Geen wisseltween
		# dus: de kaart blijft op deze spreker staan, zodat het rode segment en
		# de flits hierboven zichtbaar blijven tot de banner verschijnt.
		_gemist_naam = String(sp.get("naam", ""))
		_uitslag = -1
		return

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
	_regel_nu = tot - 1

	# De nuttige regel markeert zich hier NIET meer, en vangt zich hier ook
	# niet meer. Dat deed hij wel: hij werd groen en zijn segment vulde op het
	# moment dat hij verscheen, dus de opgave loste zich vanzelf op en de speler
	# keek toe. Wat overblijft is bijhouden *dat* hij gevallen is, want
	# `_op_afkappen()` moet nog weten of afkappen een melding kost.
	if not _nuttig_regel_getoond and sp.has("nuttige_regel"):
		if int(sp["nuttige_regel"]) < tot:
			_nuttig_regel_getoond = true


## Opschrijven wat er nú op de kaart staat. Dit is de opgave: beoordelen of de
## regel die je net leest het ding is dat gemeld moet worden.
##
## Er staat opzettelijk geen enkele hint in beeld welke regel dat is. De
## briefing wijst één belangrijke spreker aan op rol ("degene die een technisch
## probleem meldt") en Danny krijgt er geen — dat blijft de enige verborgen
## informatie in het spel, en dat was altijd al de bedoeling. Alleen was die
## kennis nergens voor nodig zolang de regel zichzelf ving.
func _op_opschrijven() -> void:
	if _uitslag != 0 or _wissel or _afgerond:
		return
	var sp := _huidig()
	if sp.is_empty() or _regel_nu < 0:
		return

	var id := String(sp.get("id", ""))
	var sleutel := "%s:%d" % [id, _regel_nu]
	if _genoteerd.has(sleutel):
		return
	_genoteerd[sleutel] = true

	var is_de_melding := bool(sp.get("belangrijk", false)) \
		and sp.has("nuttige_regel") \
		and int(sp["nuttige_regel"]) == _regel_nu \
		and String(_segment_status.get(id, "")) == "open"

	if is_de_melding:
		_segment_status[id] = "gevangen"
		_werk_info_balk_bij()
		if _regel_nu < _regels.size():
			_markeer_nuttige_regel(_regels[_regel_nu])
		var gevangen := 0
		for status: Variant in _segment_status.values():
			if String(status) == "gevangen":
				gevangen += 1
		_flits_tonen("%s %d van %d." % [
			String(content().get("nuttig", "")), gevangen, _belangrijke_ids.size()
		], UiKit.GROEN_OP_LICHT)
		if _balk_vol():
			_uitslag = 1
		return

	# Mis. De prijs is tijd en niet voortgang, zoals overal in dit spel.
	_tijd = maxf(0.0, _tijd - FOUT_SEC)
	_werk_balk_bij()
	_flits_tonen("%s  -%d sec" % [
		String(content().get("fout_notitie", "Opgeschreven. Dat was niets.")),
		roundi(FOUT_SEC),
	], UiKit.ROOD_OP_LICHT)
	AudioDirector.play_ui(&"fout")
	Juice.schok(0.8, 0.12)


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


## P3: de balk zelf (kleur, knipperpuls) komt nu uit `minigame_base.gd`'s
## `zet_klokbalk()` — hetzelfde gedrag, maar niet meer vier keer overgetypt.
func _werk_balk_bij() -> void:
	zet_klokbalk(_tijd / maxf(0.001, _tijd_max))


## Alleen de klok in de status. Het aantal ingrepen stond er ook, en samen was
## dat "30 sec · nog 3x afkappen" — breed genoeg om de titel in de kopregel tot
## "De" af te kappen. Dat getal hoort bovendien op de knop die het beperkt.
func _kap_label() -> String:
	return "Afkappen (%d)" % maxi(0, _ingrepen)


func _werk_status_bij() -> void:
	set_status("%d sec" % maxi(0, ceili(_tijd)))


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
	if _wissel:
		return
	var sp := _huidig()
	if sp.is_empty():
		return

	# Eerst opschrijven, dan pas afkappen: sinds opschrijven de opgave is, wint
	# een harnas dat alleen afkapt nooit meer. Dit tikt zodra de nuttige regel
	# op de kaart staat, precies zoals een oplettende speler zou doen.
	var id := String(sp.get("id", ""))
	if bool(sp.get("belangrijk", false)) and sp.has("nuttige_regel") \
			and int(sp["nuttige_regel"]) == _regel_nu \
			and String(_segment_status.get(id, "")) == "open":
		_op_opschrijven()
		return

	if _ingrepen > 0 and id in _qa_afkap_ids:
		_op_afkappen()


func qa_solve() -> void:
	_qa = true
