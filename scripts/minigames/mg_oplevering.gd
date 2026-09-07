extends MinigameBase
## BBD-210 — de oplevering. De finale. Elke geslaagde uitkomst is een
## oplevering: de titel begint met OPGELEVERD en beweegt mee met de score, en
## wat echt verschilt is wat je er achteraf over kunt zeggen.
##
## Sinds Fase 3b kan de eerste poging wél mislukken: onder de laagste
## geslaagde drempel op de eerste deploy volgt een ROLLBACK met de foutcode van
## je eigen personage, het ticket blijft open en je probeert het opnieuw. De
## tweede poging slaagt altijd ("OPGELEVERD, EINDELIJK") — een dag die zelfs met
## perfect spel niet boven de drempel komt bestaat en mag niemand vastzetten.
## Falen kost dus één keer tijd en gezicht, nooit voortgang. Zie `faalt_deploy()`.
##
## **P5 (Fase 5).** Het werkwoord was acht handelingen met een prijskaartje op
## één klok: het rustigste scherm van het spel op het moment dat het het
## luidste hoorde te zijn (`docs/AUDIT-2026-09-05.md` deel 2, M8). Nu schreeuwt
## alles tegelijk. Spoedjes komen binnen als kaartjes met een eigen aflopende
## balk, hoogstens drie tegelijk, en elk spoedje vraagt precies één van de zeven
## handelingen.
##
## **Sinds 7 september is het een race** (`docs/AUDIT-2026-09-07-MINIGAMES.md`).
## Bovenaan rijdt de deploy over de straat met het vuur erachter; de afstand
## ertussen is `voorsprong` in seconden, en dat getal ís de score. Blussen houdt
## je voor, een misser en een verlopen kaartje halen het vuur dichterbij, en op
## nul houdt het op. Dat repareerde drie dingen tegelijk: blind op de zeven
## knoppen rammen haalde dezelfde score als perfect spel, er stond nooit meer
## dan één kaartje tegelijk, en blussen was netto winst waardoor een rampdag een
## zorgvuldige dag kon verslaan. Een slechte dag stuurt nu geen extra spoedjes
## maar snellere vlammen.
##
## Wat de dag besloot komt hier binnen als brandhaarden en niet alleen als
## startgetallen: de fout gelegde kabel is het eerste kaartje, een ontevreden
## klant belt twee keer, en elk ticket dat om vijf uur nog open stond meldt zich
## alsnog. Zie `BrandjesModel._bouw_rij()`.
##
## De rekenkern staat bewust niet hier maar in `scripts/minigames/brandjes_model.gd`:
## die klasse raakt geen node en leest `Session` niet, zodat
## `_test_finale_brandjes()` de balans headless kan doorrekenen. Dit bestand is
## alleen nog weergave, invoer en de console-fase.

enum Fase { VOORBEREIDEN, DEPLOYEN, HERSTELLEN, KLAAR }

## De vier waarden van de dag. Ze staan sinds de race niet meer op het scherm
## (`_bouw_kop()`): ze bepalen nu hoeveel voorsprong je krijgt en hoe hard het
## vuur loopt. `METER_NAAM` blijft voor de payload en voor een eventuele
## terugkeer van een cijferweergave.
const METERS: Array[StringName] = [&"bugs", &"vertrouwen", &"getest", &"scope"]
const METER_NAAM := {
	&"bugs": "bugs", &"vertrouwen": "vertrouwen",
	&"getest": "getest", &"scope": "scope",
}

## Handelingen in fase 3: genoeg om te reageren, te weinig om het op te lossen.
const HERSTEL_ACTIES := 2
## Hoeveel keer er al gedeployd is deze dag; alleen de eerste keer kan misgaan.
const POGINGEN_TELLER := &"deploy_pogingen"

## Eén kaartje, en de ruimte voor drie. De zone houdt die hoogte ook als er
## niets ligt: kaartjes die de knoppen eronder verschuiven zijn niet te raken.
const KAART_H := 30.0
const KAART_SEP := 2.0
const BALK_H := 4.0
## Hoe lang een kaartje erover doet om weg te glijden.
const KAART_WEG := 0.25

## Hoe lang de knoppen op slot zitten na een handeling die nergens op sloeg.
## Dit slot was tot 7 september de énige prijs van een misser, en het was te
## goedkoop: blind cyclen haalde daarmee dezelfde score als perfect spel. De
## echte prijs zit nu in `_model.mis()`, die voorsprong afhaalt; dit slot is
## alleen nog de rem die voorkomt dat één tik er drie worden.
const BLOKKADE := 0.4
const MIS_FLITS := 0.2

## De hoogte van de antwoordregel: twee regels FS_SMALL, vast. Zie `_bouw()`.
const REGEL_H := 28.0
## De breedte die die regel op het smalste canvas (192 px) krijgt, gemeten aan
## de echte scroll: 192 min de vier px chrome-marge aan weerszijden, min de
## panelrand. `_test_finale_regels_passen()` rekent er de teksten mee na.
const REGEL_BREED := 172.0

## De pijplijn die op groen loopt voordat hij op jouw vakgebied omvalt. Drie
## regels, niet zeven: een nep-console met zeven controles voor een uitkomst
## die toch altijd slaagt, was het meest overgeëngineerde scherm van het spel.
## Deze namen zitten niet in de data omdat ze voor elk personage hetzelfde zijn:
## het verschil is de regel waarop hij faalt, niet de weg ernaartoe.
const CHECKS: Array[String] = ["build", "tests", "healthcheck"]
const CHECKS_LIVE: Array[String] = ["opnieuw bouwen", "uitrollen", "live"]

## Trager dan met zeven regels: met nog maar drie moet elke regel zijn gewicht
## dragen, anders is de console leeg voordat je hem gelezen hebt.
const TIK_CHECK := 0.55
const TIK_REGEL := 0.55
const TIK_GEBEURTENIS := 1.5

## Vanaf hier kleurt de klok rood: een laatste visuele waarschuwing voordat hij
## voor je beslist.
const KLOK_ALARM := 15.0


var _fase: Fase = Fase.VOORBEREIDEN
var _model: BrandjesModel = null
## Alleen fase 3 telt nog handelingen. In fase 1 is de klok de schaarste.
var _acties: int = 0
var _foutcode: String = ""
var _foutregel: String = ""
## Waar staat terwijl de console loopt; zonder dit kan een snelle tikker twee
## fases over elkaar heen zetten.
var _bezig: bool = false
var _blokkade: float = 0.0
var _qa_stap: int = 0

var _waarde: Dictionary = {}
var _tweens: Dictionary = {}
var _knoppen: Dictionary = {}
## nr van het brandje -> zijn kaartje. `nr` en niet `id`, want de ontevreden
## klant staat twee keer in de rij en kan dus twee keer tegelijk branden.
var _kaarten: Dictionary = {}
var _zone: Control = null
var _regel: Label = null
var _deploy: Button = null
var _foutbalk: PanelContainer = null
var _foutbalk_label: Label = null
var _console_paneel: PanelContainer = null
var _console: VBoxContainer = null
var _klok_label: Label = null
## De straat in de kopstrook. Toont waar de deploy staat en waar het vuur staat;
## de rekenkern zit in `BrandjesModel` en dit is puur de weergave.
var _straat: DeployStraat = null
## Alarm gaat aan als de vlammen dichterbij komen dan dit aantal seconden. Dan
## flikkert de strook, wiebelen de knoppen en wordt de statusregel rood.
const ALARM_SEC := 4.0
var _alarm_aan: bool = false
var _wiebel: Tween = null

## De ontwarring: Jonathans appje met drie gesprekken door elkaar. Staat op de
## plek van het knoppenraster en is er nooit tegelijk mee zichtbaar.
var _ontwarring: Ontwarring = null
var _grid: GridContainer = null
## Nr van het puzzelbrandje zolang de puzzel open staat, anders -1.
var _puzzel_nr: int = -1
var _puzzel_gedaan: bool = false
## De werk-fragmenten die de speler al gepakt heeft, op volgorde van `volgorde`.
var _puzzel_gepakt: Array[int] = []


func _on_setup() -> void:
	var c := content()
	if c.is_empty():
		fail()
		return

	# config wint van content: zo bepaalt de opgetelde dag van de speler de
	# begintoestand zonder dat deze minigame iets over de wereld hoeft te weten.
	var start: Dictionary = {}
	for k: Variant in (c.get("start", {}) as Dictionary):
		start[String(k)] = (c.get("start", {}) as Dictionary)[k]
	for k: Variant in (cfg("start_override", {}) as Dictionary):
		start[String(k)] = (cfg("start_override", {}) as Dictionary)[k]

	_model = BrandjesModel.new(c, start, _vlaggen(), _open_werk(), randi())

	_lees_variant(c)
	_bouw(c)
	_refresh()
	_refresh_klok()
	_status_regel()
	set_process(true)


## De `gevolg_*`-vlaggen die het model nodig heeft om de rij te zaaien. Ze gaan
## als gewone dictionary mee zodat `BrandjesModel` zelf geen Session kent.
func _vlaggen() -> Dictionary:
	var uit: Dictionary = {}
	for v: StringName in Gevolgen.VLAGGEN:
		uit[v] = Session.get_flag(v)
	return uit


## De codes van de tickets die om vijf uur nog open stonden. Elk daarvan meldt
## zich in de finale alsnog; het model topt af op `NIET_AF_MAX`.
func _open_werk() -> Array[String]:
	var uit: Array[String] = []
	for id: StringName in Session.niet_af():
		var t: TicketDef = GameData.ticket(id)
		if t != null and t.code != "":
			uit.append(t.code)
	return uit


## De foutcode hoort bij het vakgebied van de speler; dat is de hele pointe van
## de finale. Ontbreekt hij, dan valt de minigame terug in plaats van af te
## breken: een speler mag zijn dag niet kwijtraken aan een gat in de data.
func _lees_variant(c: Dictionary) -> void:
	var pc: CharacterDef = player_character()
	var cid := String(pc.id) if pc != null else ""
	var v := (c.get("varianten", {}) as Dictionary).get(cid, {}) as Dictionary
	if v.is_empty():
		push_error("mg_oplevering: geen variant voor personage '%s'" % cid)
		_foutcode = "DEPLOYMENT FAILED"
		_foutregel = "Er ging iets mis waar niemand een naam voor heeft."
		return
	_foutcode = String(v.get("foutcode", "DEPLOYMENT FAILED"))
	_foutregel = String((v.get("config", {}) as Dictionary).get("regel", ""))


# --- Opbouw ---------------------------------------------------------------

## Van boven naar beneden, en alles moet op 192x416 zonder scrollen passen:
## kop met klok en meters (in de niet-scrollende header), de kaartjeszone, de
## regel waarop de laatste handeling antwoordt, de zeven knoppen in twee
## kolommen, en in de voet de knop die de finale afsluit plus de banner uit P2.
func _bouw(c: Dictionary) -> void:
	var body := build_chrome(default_title(), String(c.get("intro", "")))

	_bouw_kop()
	_bouw_foutbalk()

	_zone = Control.new()
	_zone.custom_minimum_size = Vector2(0, KAART_H * 3.0 + KAART_SEP * 2.0)
	_zone.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# SHRINK_BEGIN en niet de standaard FILL: de hoogte van deze zone is precies
	# drie kaartjes, en overgebleven ruimte hoort naar beneden te vallen en niet
	# hier te blijven hangen. Kaartjes staan op vaste plekken binnen de zone
	# (`_plaats()`), dus een zone die meegroeit verschuift alleen de lege ruimte
	# eronder — en die hoort bij de knoppen, die zo hoog mogelijk moeten staan.
	_zone.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	# Een kaartje dat wegglijdt hoort de zone niet uit te lopen: de meting in
	# `_meet_horizontale_overloop()` rekent alles buiten deze klem als weg.
	_zone.clip_contents = true
	_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(_zone)

	# Twee regels reserveren, en er ook twee blijven: de reactie op een
	# handeling verschijnt hier, en een knoppenraster dat bij elke tik een paar
	# pixels opschuift is niet te raken.
	#
	# `clip_text` is de rem. Zonder dat meldt een Label met autowrap de hoogte
	# van zijn gewrapte tekst als minimum, en een gebeurtenis van drie regels
	# duwde de onderste rij knoppen onder de vouw — met scrollbalk, halverwege
	# de klok, in precies de minigame die om tempo vraagt. Dat de derde regel
	# dan wegvalt is de tweede helft van de afspraak: geen enkele tekst die hier
	# landt mag over twee regels heen gaan, en `_test_finale_regels_passen()`
	# rekent dat na op elk woord dat `_zeg()` kan krijgen.
	_regel = UiKit.label("Er komt zo iets binnen. Blus het met de juiste handeling.",
		UiKit.FS_SMALL, UiKit.GRIJS_OP_DONKER)
	_regel.custom_minimum_size = Vector2(0, REGEL_H)
	_regel.clip_text = true
	# Godots standaardthema zet `line_spacing` op 3, en dan meten twee regels
	# 31 px in plaats van de 28 die `get_multiline_string_size()` meldt: de
	# tweede regel viel onder de klem weg en Dirk zei alleen nog zijn halve zin.
	# Nul, zodat de meting in `_test_finale_regels_passen()` letterlijk is wat
	# dit label doet. De 10px-snit zit al in een regelhoogte van 14 en heeft die
	# extra drie niet nodig.
	_regel.add_theme_constant_override("line_spacing", 0)
	body.add_child(_regel)

	_bouw_knoppen(body)

	# De knop die de finale afsluit hoort buiten de scroll: hij mag nooit onder
	# de knoppen wegzakken, want dan is de finale niet af te maken. In fase 1
	# staat hij er niet: de klok ís de deploy, en een knop DEPLOYEN ernaast zou
	# beloven dat je eerder klaar kunt zijn.
	_deploy = UiKit.knop_primair(String(c.get("deploy_label", "LIVE ZETTEN")), UiKit.FS_BODY)
	_deploy.focus_mode = Control.FOCUS_NONE
	_deploy.visible = false
	_deploy.pressed.connect(_op_deploy)
	chrome_footer().add_child(_deploy)


## De kop is de straat: de deploy rijdt van links naar rechts en de brandende
## laag zit erachter. Eén strook, niets erbij.
##
## Hier stonden de vier meters (bugs, vertrouwen, getest, scope) met hun woord
## voluit. Die zijn weg, en dat moest ook: het scherm had nog negen pixels
## speling (`docs/AUDIT-2026-09-07-MINIGAMES.md`), en een strook van 28 px past
## daar alleen in als de meterstrook van 34 px hem plaatsmaakt. Het is geen
## verlies. De meters wáren de opgave niet, ze waren de boekhouding erover;
## sinds de race bepalen ze hoeveel voorsprong je begint met en hoe hard het
## vuur loopt (`BrandjesModel.start_voorsprong()`), en dát is nu te zien in
## plaats van af te lezen. De klok en de voorsprong staan als getal in de
## statusregel eronder, waar ze als bijschrift bij de strook lezen.
func _bouw_kop() -> void:
	var paneel := PanelContainer.new()
	paneel.add_theme_stylebox_override("panel", UiKit.panel_krap(UiKit.WIT, UiKit.LINE))
	paneel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	chrome_header().add_child(paneel)

	_straat = DeployStraat.new()
	paneel.add_child(_straat)


## Een label dat niet mag afbreken. UiKit.label() zet autowrap aan omdat een
## lange regel anders de indeling van een 192px-canvas opentrekt, maar in een
## HBox is het omgekeerde het probleem: een afbrekend label meldt een minimum
## van één letter, en dan zet de container de rij rechtop.
func _vast(tekst: String, maat: int, kleur: Color) -> Label:
	var l := UiKit.label(tekst, maat, kleur)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


## De foutcode blijft in fase 3 staan. Zonder dat reageer je op iets wat twee
## seconden geleden van je scherm verdwenen is.
func _bouw_foutbalk() -> void:
	_foutbalk = PanelContainer.new()
	_foutbalk.add_theme_stylebox_override("panel", UiKit.panel_krap(UiKit.PANEL, UiKit.ROOD, 2))
	_foutbalk.visible = false
	chrome_header().add_child(_foutbalk)
	# ROOD_OP_LICHT, niet ROOD: _foutbalk staat op UiKit.PANEL (licht), en ROOD
	# zelf is een derivaat voor een donkere ondergrond (P3).
	_foutbalk_label = UiKit.label("", UiKit.FS_SMALL, UiKit.ROOD_OP_LICHT)
	_foutbalk.add_child(_foutbalk_label)


## De zeven handelingen als zeven vaste knoppen, altijd zichtbaar, twee
## kolommen van vier en drie. Vast en niet herbouwd per beurt: een knop die van
## plek wisselt terwijl je erop mikt is de snelste manier om een spel dat om
## tempo vraagt onspeelbaar te maken.
func _bouw_knoppen(body: VBoxContainer) -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	body.add_child(grid)

	for raw: Variant in content().get("keuzes", []):
		var o := raw as Dictionary
		var id := StringName(o.get("id", ""))
		var b := UiKit.keuzeknop(String(o.get("label", "?")), UiKit.FS_SMALL)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_op_handeling.bind(id))
		grid.add_child(b)
		_knoppen[id] = b

	_grid = grid
	# De ontwarring komt op dezelfde plek en neemt het raster over zolang hij
	# open staat. Drie rijen van hoogstens 40 px tegen de vier rijen die het
	# knoppenraster inneemt, dus dit kan er nooit ruimte bij vragen.
	_ontwarring = Ontwarring.new()
	_ontwarring.visible = false
	_ontwarring.gekozen.connect(_op_fragment)
	body.add_child(_ontwarring)


func _keuze(id: StringName) -> Dictionary:
	for raw: Variant in content().get("keuzes", []):
		if StringName((raw as Dictionary).get("id", "")) == id:
			return raw as Dictionary
	return {}


# --- De brandjes ----------------------------------------------------------

## De tijdlijn loopt in `_process` en niet in een `create_timer`-lus: elk
## kaartje heeft een balk die per frame moet krimpen, en dan is een tik van een
## seconde geen klok maar een schok. Bijkomend: dit stopt vanzelf als de tree
## pauzeert (backgrounden), wat de oude lus met `process_always = true` niet
## deed — de klok liep door terwijl de speler in een andere app zat.
func _process(delta: float) -> void:
	if _fase != Fase.VOORBEREIDEN or _model == null:
		return

	if _blokkade > 0.0:
		_blokkade = maxf(0.0, _blokkade - delta)
		if _blokkade <= 0.0:
			_zet_knoppen(true)

	for e: Dictionary in _model.tik(delta):
		_verwerk(e)
	_werk_kaartjes_bij()
	_refresh_klok()
	_status_regel()
	_werk_straat_bij()

	var pz := content().get("puzzel", {}) as Dictionary
	if not _puzzel_gedaan and not pz.is_empty() and _model.verstreken >= float(pz.get("na", 30.0)):
		_open_puzzel()


## De strook volgt het model, elke frame. `voortgang()` is waar de deploy staat,
## `vuur_positie()` waar de voorkant van de vlammen staat; het verschil is de
## voorsprong, en dat is precies wat de speler moet zien.
func _werk_straat_bij() -> void:
	if _straat == null or _model == null:
		return
	var dichtbij: bool = _model.voorsprong <= ALARM_SEC
	_straat.zet(_model.voortgang(), _model.vuur_positie(), dichtbij)
	if dichtbij != _alarm_aan:
		_alarm_aan = dichtbij
		_zet_wiebel(dichtbij)


## Onder de alarmgrens wiebelen de zeven knoppen. Niet als versiering: het is de
## enige plek waar het scherm zelf zegt "nu gaat het mis", en de speler kijkt op
## dat moment naar de knoppen en niet naar de strook.
##
## `rotation` op een Button in een GridContainer mag: de container zet positie
## en maat, niet de rotatie. `pivot_offset` in het midden, anders draait hij om
## zijn linkerbovenhoek en schuift hij visueel weg van zijn tikdoel.
func _zet_wiebel(aan: bool) -> void:
	if _wiebel != null and _wiebel.is_valid():
		_wiebel.kill()
		_wiebel = null
	for id: Variant in _knoppen:
		var b := _knoppen[id] as Button
		b.rotation = 0.0
	if not aan or Autopilot.gevraagd():
		return
	_wiebel = create_tween().set_loops()
	for id: Variant in _knoppen:
		var b := _knoppen[id] as Button
		b.pivot_offset = b.size * 0.5
		_wiebel.parallel().tween_property(b, "rotation", 0.03, 0.09)
		_wiebel.parallel().tween_property(b, "rotation", -0.03, 0.09).set_delay(0.09)
		_wiebel.parallel().tween_property(b, "rotation", 0.0, 0.09).set_delay(0.18)


func _verwerk(e: Dictionary) -> void:
	match int(e.get(&"soort", -1)):
		BrandjesModel.Soort.SPAWN:
			# Geen eigen "toast"-sample: die bestaat niet in assets/audio/sfx,
			# en `play_ui()` slikt een onbekende cue stil door. `interactie` is
			# de korte tik die elders al "er meldt zich iets" betekent.
			AudioDirector.play_ui(&"interactie")
		BrandjesModel.Soort.VERLOPEN:
			var b := e[&"brandje"] as Dictionary
			_weg_kaart(int(b[&"nr"]), false)
			# Verliep het puzzelkaartje terwijl de ontwarring nog open stond,
			# dan sluit die en zegt Jonathan wat hij altijd zegt.
			if int(b[&"nr"]) == _puzzel_nr:
				_sluit_puzzel()
				var pz := content().get("puzzel", {}) as Dictionary
				_zeg(String(pz.get("verlopen", "")), UiKit.ROOD)
				AudioDirector.play_ui(&"fout")
				impact(2.0, 0.25, Haptiek.Sterkte.STOOT)
				if _straat != null:
					_straat.hobbel()
				_toon_veranderd(e[&"veranderd"] as Dictionary)
				return
			_zeg("%s. Te laat." % String(b[&"tekst"]), UiKit.ROOD)
			AudioDirector.play_ui(&"fout")
			# `impact()` en niet `Juice.schok()`: die laatste schudt de
			# wereldcamera, en die zit achter het dekkende paneel van deze
			# minigame — onzichtbaar. Zie `MinigameBase.impact()`.
			impact(2.0, 0.25, Haptiek.Sterkte.STOOT)
			if _straat != null:
				_straat.hobbel()
			_toon_veranderd(e[&"veranderd"] as Dictionary)
		BrandjesModel.Soort.INGEHAALD:
			_ingehaald()
		BrandjesModel.Soort.GEBEURTENIS:
			var g := e[&"gebeurtenis"] as Dictionary
			_toon_veranderd(e[&"veranderd"] as Dictionary)
			if bool(g.get("storing", false)):
				_storing(String(g.get("tekst", "")))
			else:
				_zeg(String(g.get("tekst", "")), UiKit.ORANJE)
		BrandjesModel.Soort.TIJD_OM:
			_tijd_is_om()


# --- De ontwarring: Jonathans appje --------------------------------------

## Jonathan stuurt halverwege een bericht waarin drie gesprekken door elkaar
## lopen: een bevinding over de prijzen-API, het rijstveld van zijn moeder, en
## dat hij stopt met een klant. Hij is niet onduidelijk — élk fragment is
## exact. Hij zat op Claude te wachten en las ondertussen zijn moeder.
##
## Dit is de "taak die onduidelijk wordt": er brandt een kaartje dat je niet kunt
## blussen tot je de drie werk-fragmenten eruit getikt hebt. Die vertellen samen
## dat de prijs op de productpagina indicatief is, dus dat het géén bug is en de
## klant geïnformeerd moet worden — en dat is een andere knop dan waar je bij
## "prijs klopt niet" intuïtief naar grijpt.
##
## De klok en de vlammen lopen door. De andere kaartjes staan stil en er spawnt
## niets, want het raster is bezet en blussen kan toch niet.
func _open_puzzel() -> void:
	var pz := content().get("puzzel", {}) as Dictionary
	if pz.is_empty() or _puzzel_gedaan or _model == null:
		return
	var b := (pz.get("brandje", {}) as Dictionary).duplicate(true)
	if b.is_empty():
		return
	_puzzel_gedaan = true
	_puzzel_gepakt.clear()

	_puzzel_nr = _model.zet_puzzelbrandje(b)
	if _puzzel_nr < 0:
		return
	_werk_kaartjes_bij()
	_zeg(String(pz.get("aankondiging", "")), UiKit.ORANJE)
	AudioDirector.play_ui(&"interactie")

	var frag: Array[Dictionary] = []
	for raw: Variant in pz.get("fragmenten", []):
		frag.append((raw as Dictionary).duplicate())
	frag.shuffle()
	if _grid != null:
		_grid.visible = false
	_ontwarring.visible = true
	_ontwarring.toon(frag)


## Een getikt fragment. Werk-fragmenten moeten op hun eigen volgorde gepakt
## worden; ruis kost voorsprong en blijft liggen, zodat een misser de puzzel
## nooit onoplosbaar maakt.
func _op_fragment(id: StringName) -> void:
	var pz := content().get("puzzel", {}) as Dictionary
	if _puzzel_nr < 0 or _model == null:
		return
	var gekozen := {}
	for raw: Variant in pz.get("fragmenten", []):
		var f := raw as Dictionary
		if StringName(f.get("id", "")) == id:
			gekozen = f
			break
	if gekozen.is_empty():
		return

	if not bool(gekozen.get("werk", false)):
		_ontwarring.markeer(id, false)
		_zeg(String(pz.get("mis", "")), UiKit.ORANJE)
		AudioDirector.play_ui(&"fout")
		_model.pas_vuur(-float(pz.get("mis_vuur", 1.0)))
		impact(1.5, 0.18, Haptiek.Sterkte.TIK)
		return

	_ontwarring.markeer(id, true)
	AudioDirector.play_ui(&"raak")
	Haptiek.tril(Haptiek.Sterkte.TIK)
	_puzzel_gepakt.append(int(gekozen.get("volgorde", 0)))
	var nodig := 0
	for raw: Variant in pz.get("fragmenten", []):
		if bool((raw as Dictionary).get("werk", false)):
			nodig += 1
	if _puzzel_gepakt.size() < nodig:
		return

	# Alle drie gepakt: de opdracht is helder, en nu moet je hem nog uitvoeren.
	# Dát is het moment waar dit voor bestaat — de instructie wordt duidelijk,
	# jij doet de handeling.
	_sluit_puzzel()
	_zeg(String(pz.get("opgelost", "")), UiKit.BLUEBIRD_BRIGHT)
	_model.verleng_puzzelbrandje(float(pz.get("duur_na", 8.0)))
	_werk_kaartjes_bij()
	var doel := StringName((pz.get("brandje", {}) as Dictionary).get("handeling", ""))
	var knop := _knoppen.get(doel) as Button
	if knop != null:
		puls_rand(knop, 3)


## Het eerstvolgende nog niet gepakte werk-fragment, voor de autopilot.
func _qa_fragment() -> void:
	var pz := content().get("puzzel", {}) as Dictionary
	var beste := {}
	for raw: Variant in pz.get("fragmenten", []):
		var f := raw as Dictionary
		if not bool(f.get("werk", false)):
			continue
		if int(f.get("volgorde", 0)) in _puzzel_gepakt:
			continue
		if beste.is_empty() or int(f.get("volgorde", 0)) < int(beste.get("volgorde", 0)):
			beste = f
	if not beste.is_empty():
		_op_fragment(StringName(beste.get("id", "")))


func _sluit_puzzel() -> void:
	_puzzel_nr = -1
	if _ontwarring != null:
		_ontwarring.sluit()
		_ontwarring.visible = false
	if _grid != null:
		_grid.visible = true


## De vlammen hebben de deploy ingehaald. Dit is de faalstaat die de finale tot
## 7 september niet had: je kon wel laag scoren, maar niet verliezen terwijl je
## speelde. Nu houdt het op, en het houdt zichtbaar op — de knoppen vallen om,
## want ze doen ook niets meer.
func _ingehaald() -> void:
	if _fase != Fase.VOORBEREIDEN:
		return
	_zeg("De vlammen halen je in. Je gaat live met wat er brandt.", UiKit.ROOD)
	AudioDirector.play_ui(&"fout")
	Juice.flits(UiKit.ROOD, 0.45, 0.2)
	impact(4.0, 0.5, Haptiek.Sterkte.SLAG)
	if _straat != null:
		_straat.toon_brandt()
	_zet_wiebel(false)
	_laat_knoppen_omvallen()
	_tijd_is_om()


## Zeven knoppen die uit hun raster kantelen en grijs worden. Ze zijn op dat
## moment toch al dood (`_zet_knoppen(false)` in `_tijd_is_om()`), en een dode
## knop die er nog uit ziet als een knop is een knop waar je op blijft tikken.
##
## `rotation` en `modulate` en niet `position`: de GridContainer bezit de
## positie en zou een verschuiving elke layout-pass terugzetten.
func _laat_knoppen_omvallen() -> void:
	if Autopilot.gevraagd():
		return
	var tw := create_tween().set_parallel(true)
	var i := 0
	for id: Variant in _knoppen:
		var b := _knoppen[id] as Button
		b.pivot_offset = Vector2(b.size.x * 0.5, b.size.y)
		var kant := 0.15 + 0.15 * float(i % 3) / 2.0
		tw.tween_property(b, "rotation", kant if i % 2 == 0 else -kant, 0.45)
		tw.tween_property(b, "modulate", UiKit.GRIJS, 0.45)
		i += 1


func _toon_veranderd(veranderd: Dictionary) -> void:
	_refresh()
	for m: Variant in veranderd:
		_flits(StringName(m), bool(veranderd[m]))


## Een tik op een handeling. Vraagt een zichtbaar brandje er precies om, dan
## dooft het brandje met de kortste balk. Zo niet, dan gebeurt er niets behalve
## een rode flits: loze handelingen mogen de meters niet opdrijven.
func _op_handeling(id: StringName) -> void:
	if _bezig or _fase == Fase.DEPLOYEN or _fase == Fase.KLAAR or _model == null:
		return
	if _fase == Fase.HERSTELLEN:
		_herstel_handeling(id)
		return
	if _blokkade > 0.0:
		return

	var r := _model.blus(id)
	if r.is_empty():
		_mis(id)
		return

	_weg_kaart(int((r[&"brandje"] as Dictionary)[&"nr"]), true)
	# `raak` en niet `klik`: geblust en misgetikt klonken tot nu toe allebei als
	# een knop, en dan moet je de tekstregel lezen om te weten wat er gebeurde.
	AudioDirector.play_ui(&"raak")
	Haptiek.tril(Haptiek.Sterkte.TIK)
	if _straat != null:
		_straat.hobbel(1.5)
	_zeg(String(r[&"regel"]), UiKit.BLUEBIRD_BRIGHT)
	# Onthullen voor het effect: zo zie je bij de eerste test het getal
	# verschijnen dat er de hele tijd al stond.
	var onthuld := StringName(r[&"onthuld"])
	if onthuld != &"":
		_refresh()
		_flits(onthuld, false)
	_toon_veranderd(r[&"veranderd"] as Dictionary)
	_werk_kaartjes_bij()


## Een tik waar niets voor brandt. Kostte tot 7 september alleen dit
## knoppenslot van 0,4 s, en dat was zo goedkoop dat blind door de zeven
## knoppen cyclen op elk zaad dezelfde score haalde als perfect spel
## (`docs/AUDIT-2026-09-07-MINIGAMES.md`). `_model.mis()` laat het nu echt
## voorsprong kosten, dus die route zakt onder de faaldrempel.
func _mis(id: StringName) -> void:
	AudioDirector.play_ui(&"fout")
	_zeg("Daar is nu geen spoed bij.", UiKit.ORANJE)
	_model.mis(id)
	impact(1.5, 0.18, Haptiek.Sterkte.TIK)
	if _straat != null:
		_straat.hobbel(2.0)
	_blokkade = BLOKKADE
	_zet_knoppen(false)
	var b := _knoppen.get(id) as Button
	if b == null:
		return
	b.modulate = UiKit.ROOD
	create_tween().tween_property(b, "modulate", Color.WHITE, MIS_FLITS)


func _zet_knoppen(aan: bool) -> void:
	if aan and (_fase == Fase.DEPLOYEN or _fase == Fase.KLAAR):
		return
	for id: Variant in _knoppen:
		(_knoppen[id] as Button).disabled = not aan


# --- De kaartjes ----------------------------------------------------------

func _werk_kaartjes_bij() -> void:
	if _zone == null or _model == null:
		return
	for i: int in _model.zichtbaar.size():
		var b := _model.zichtbaar[i]
		var nr := int(b[&"nr"])
		var kaart := _kaarten.get(nr) as Control
		if kaart == null:
			kaart = _maak_kaart(b)
			_kaarten[nr] = kaart
			_zone.add_child(kaart)
		_plaats(kaart, i)
		var deel := clampf(float(b[&"resterend"]) / maxf(0.01, float(b[&"duur"])), 0.0, 1.0)
		var balk := kaart.get_node(^"balk") as ColorRect
		balk.anchor_right = deel
		balk.color = UiKit.tijdkleur(deel)


func _maak_kaart(b: Dictionary) -> Control:
	var kaart := Control.new()
	kaart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kaart.clip_contents = true

	var paneel := PanelContainer.new()
	paneel.name = "paneel"
	paneel.add_theme_stylebox_override("panel", UiKit.panel_krap(UiKit.PANEL, UiKit.LINE))
	paneel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.full_rect(paneel)
	kaart.add_child(paneel)

	var l := UiKit.label(String(b[&"tekst"]), UiKit.FS_SMALL, UiKit.INK)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paneel.add_child(l)

	# De balk hangt onderaan het kaartje en krimpt via zijn rechteranker, zodat
	# hij geen enkele meting van de breedte nodig heeft. Kleur uit dezelfde
	# functie als de stand-up: groen via oranje naar rood, continu.
	var balk := ColorRect.new()
	balk.name = "balk"
	balk.anchor_left = 0.0
	balk.anchor_right = 1.0
	balk.anchor_top = 1.0
	balk.anchor_bottom = 1.0
	balk.offset_top = -BALK_H
	balk.offset_bottom = 0.0
	balk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kaart.add_child(balk)
	return kaart


func _plaats(kaart: Control, i: int) -> void:
	kaart.anchor_left = 0.0
	kaart.anchor_right = 1.0
	var doel := float(i) * (KAART_H + KAART_SEP)
	if int(kaart.get_meta(&"idx", -1)) == i:
		return
	kaart.set_meta(&"idx", i)
	if kaart.offset_bottom == 0.0 and kaart.offset_top == 0.0:
		kaart.offset_top = doel
		kaart.offset_bottom = doel + KAART_H
		return
	# Een kaartje dat opschuift omdat het kaartje erboven gedoofd is, springt
	# niet: dan zou de kaart onder je vinger wegschieten.
	var tw := create_tween().set_parallel(true)
	tw.tween_property(kaart, "offset_top", doel, 0.12)
	tw.tween_property(kaart, "offset_bottom", doel + KAART_H, 0.12)


## Groen en weg, of rood en weg. Het kaartje verlaat de map meteen zodat de
## volgende laag er niet meer op wacht; de node zelf glijdt nog even door.
func _weg_kaart(nr: int, gelukt: bool) -> void:
	var kaart := _kaarten.get(nr) as Control
	if kaart == null:
		return
	_kaarten.erase(nr)
	var paneel := kaart.get_node_or_null(^"paneel") as PanelContainer
	if paneel != null:
		paneel.add_theme_stylebox_override("panel", UiKit.panel_krap(
			UiKit.GROEN_TINT if gelukt else UiKit.ORANJE_TINT,
			UiKit.GROEN_OP_LICHT if gelukt else UiKit.ROOD_OP_LICHT, 2))
	var tw := create_tween().set_parallel(true)
	if gelukt:
		# Geblust: naar rechts het beeld uit, zoals het altijd deed. Dat leest
		# als "afgehandeld en weg".
		var breed := maxf(_zone.size.x, 1.0)
		tw.tween_property(kaart, "offset_left", breed, KAART_WEG)
		tw.tween_property(kaart, "offset_right", breed, KAART_WEG)
	else:
		# Verlopen: omvallen. Een kaartje dat je liet lopen hoort niet netjes
		# weg te schuiven alsof je iets afhandelde. De zone clipt en kaartjes
		# negeren de muis (`_maak_kaart`), dus er steekt niets uit en er is
		# geen tikdoel dat meekantelt.
		kaart.pivot_offset = Vector2(0.0, KAART_H)
		tw.tween_property(kaart, "rotation", 0.25, KAART_WEG + 0.05)
		tw.tween_property(kaart, "offset_top", kaart.offset_top + 18.0, KAART_WEG + 0.05)
	tw.tween_property(kaart, "modulate:a", 0.0, KAART_WEG)
	# `is_instance_valid` in de callback: `_wis_kaarten()` kan dit kaartje
	# ondertussen al hebben vrijgegeven (fasewissel tijdens de tween), en dan
	# hervat deze callback op een gefreede node.
	tw.chain().tween_callback(func() -> void:
		if is_instance_valid(kaart):
			kaart.queue_free())


# --- Fase 3: herstellen ---------------------------------------------------

## Na de ROLLBACK is er geen klok en zijn er geen brandjes meer, alleen twee
## handelingen. Dezelfde zeven knoppen, dezelfde effecten: wat je hier nog doet
## is wat je al de hele avond deed, maar dan met de foutcode in beeld.
func _herstel_handeling(id: StringName) -> void:
	if _acties <= 0:
		return
	var keuze := _keuze(id)
	if keuze.is_empty():
		return
	_acties -= 1
	_model.gedaan.append(String(id))

	var onthult := StringName(keuze.get("onthult", ""))
	if onthult != &"" and not bool(_model.bekend.get(onthult, false)):
		_model.bekend[onthult] = true
		_refresh()
		_flits(onthult, false)

	_toon_veranderd(_model.pas_effect(keuze.get("effect", {}) as Dictionary))
	_zeg(String(keuze.get("regel", "")), UiKit.BLUEBIRD_BRIGHT)
	AudioDirector.play_ui(&"klik")
	_status_regel()
	if _acties <= 0:
		_zet_knoppen(false)


## Neemt het scherm heel even helemaal over: een storing landt in je dag, niet
## in een regel onderaan. Zolang hij openstaat staan de balken van de brandjes
## stil — een storing die je kaartjes laat verlopen terwijl je er niet bij kunt
## is geen onderbreking maar een straf voor het lezen ervan.
func _storing(tekst: String) -> void:
	_model.gepauzeerd = true
	var overlay := PanelContainer.new()
	overlay.add_theme_stylebox_override("panel", UiKit.panel(UiKit.INK, UiKit.ROOD, 3))
	UiKit.full_rect(overlay)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.modulate = Color(1, 1, 1, 0)
	add_child(overlay)

	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 6)
	UiKit.full_rect(v)
	overlay.add_child(v)

	var kop := UiKit.label("OPGELET", UiKit.FS_HEAD, UiKit.ROOD)
	kop.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(kop)

	var regel := UiKit.label(tekst, UiKit.FS_SMALL, UiKit.WIT)
	regel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(regel)

	AudioDirector.play_ui(&"fout")
	impact(3.0, 0.4, Haptiek.Sterkte.STOOT)
	# Geen `await <tween>.finished` op deze twee: dat is de vastloper van dit
	# project zodra iets die tween killt. Een gewone pauze doet hetzelfde en
	# kan niet blijven hangen.
	var in_tw := create_tween()
	in_tw.tween_property(overlay, "modulate:a", 1.0, 0.1)
	await _pauze(0.1)
	await _pauze(TIK_GEBEURTENIS + 0.6)
	# Vroeger zat hier een `return` die `gepauzeerd` op true liet staan. Dan
	# loopt de klok nooit meer af en is de finale niet af te maken; elke route
	# hieruit moet het model weer laten lopen.
	if is_instance_valid(overlay):
		var uit_tw := create_tween()
		uit_tw.tween_property(overlay, "modulate:a", 0.0, 0.15)
		await _pauze(0.15)
		if is_instance_valid(overlay):
			overlay.queue_free()
	if _model != null:
		_model.gepauzeerd = false


## De klok ís de deploy. Op nul gaat het live met wat er ligt, en de brandjes
## die dan nog branden zijn de brandjes waarmee het live gaat.
func _tijd_is_om() -> void:
	_bezig = true
	_zeg("De tijd is om. Je gaat nu live met wat er ligt.", UiKit.ORANJE)
	AudioDirector.play_ui(&"fout")
	await _pauze(TIK_REGEL)
	if not is_inside_tree():
		return
	_bezig = false
	await _op_deploy()


func _op_deploy() -> void:
	if _bezig:
		return
	match _fase:
		Fase.VOORBEREIDEN:
			await _deployen()
		Fase.HERSTELLEN:
			await _live()
		_:
			pass


# --- Fase 2: de console ---------------------------------------------------

func _deployen() -> void:
	if _fase != Fase.VOORBEREIDEN:
		return
	_fase = Fase.DEPLOYEN
	_bezig = true
	set_process(false)
	# De klok hoort bij fase 1. Zodra je deployt is de deadline gehaald of
	# geforceerd, en een bevroren tijd op het scherm zou allebei ontkennen.
	if _klok_label != null:
		_klok_label.text = ""
	_zet_wiebel(false)
	_wis_kaarten()
	_zet_knoppen(false)
	set_status("deployen")
	_open_console()
	AudioDirector.play_ui(&"genereren")

	for naam: String in CHECKS:
		_check(naam)
		await _pauze(TIK_CHECK)
	await _pauze(0.7)

	# Alles op groen, en dan is het scherm ineens leeg op één regel na. Dit is
	# het enige moment in het spel dat mag schreeuwen.
	_wis_console()
	_console.alignment = BoxContainer.ALIGNMENT_CENTER
	_console_regel("DEPLOYMENT FAILED", UiKit.ROOD, UiKit.FS_BODY)
	AudioDirector.play_ui(&"fout")
	await _pauze(0.4)
	_console_regel(_foutcode, UiKit.ROOD, UiKit.FS_HEAD)
	await _pauze(1.0)
	_console_regel(_foutregel, UiKit.BLUEBIRD_BRIGHT, UiKit.FS_SMALL)
	await _pauze(1.5)

	# Alles klaarzetten voor fase 3 vóór de faseovergang zelf: het aantal
	# handelingen, de foutbalk, de knop. Daarna is HERSTELLEN waar.
	_acties = HERSTEL_ACTIES
	_foutbalk_label.text = _foutcode
	_foutbalk.visible = true
	_deploy.visible = true
	_sluit_console()
	_fase = Fase.HERSTELLEN
	_bezig = false

	_zeg("Twee handelingen. Daarna zet je hem live, wat je ook doet.", UiKit.WIT)
	_zet_knoppen(true)
	_refresh()
	_status_regel()


func _open_console() -> void:
	_console_paneel = PanelContainer.new()
	_console_paneel.add_theme_stylebox_override("panel", UiKit.panel(UiKit.INK, UiKit.LINE))
	UiKit.full_rect(_console_paneel)
	_console_paneel.offset_left = 4
	_console_paneel.offset_right = -4
	_console_paneel.offset_top = 4
	_console_paneel.offset_bottom = -4
	_console_paneel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_console_paneel)

	# Geen scroll: wat hier staat moet in beeld staan. Vandaar dat de checks er
	# straks af gaan voordat de foutcode komt — die krijgt het scherm alleen.
	_console = VBoxContainer.new()
	_console.add_theme_constant_override("separation", 1)
	_console_paneel.add_child(_console)


func _sluit_console() -> void:
	if _console_paneel == null:
		return
	_console_paneel.queue_free()
	_console_paneel = null
	_console = null


func _wis_console() -> void:
	if _console == null:
		return
	for ch: Node in _console.get_children():
		_console.remove_child(ch)
		ch.queue_free()


func _wis_kaarten() -> void:
	for nr: Variant in _kaarten:
		var kaart := _kaarten[nr] as Control
		if is_instance_valid(kaart):
			kaart.queue_free()
	_kaarten.clear()


func _check(naam: String) -> void:
	if _console == null:
		return
	var rij := HBoxContainer.new()
	rij.add_theme_constant_override("separation", 4)
	_console.add_child(rij)
	var l := _vast(naam, UiKit.FS_SMALL, UiKit.WIT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rij.add_child(l)
	rij.add_child(_vast("OK", UiKit.FS_SMALL, UiKit.GROEN))


func _console_regel(tekst: String, kleur: Color, maat: int) -> void:
	if _console == null:
		return
	_console.add_child(UiKit.spacer(4))
	_console.add_child(UiKit.label(tekst, maat, kleur))


# --- Van fase 3 naar live -------------------------------------------------

func _live() -> void:
	if _fase != Fase.HERSTELLEN:
		return
	_fase = Fase.KLAAR
	_bezig = true
	_foutbalk.visible = false
	_zet_knoppen(false)
	set_status("live")
	_open_console()
	AudioDirector.play_ui(&"genereren")
	for naam: String in CHECKS_LIVE:
		_check(naam)
		await _pauze(TIK_CHECK)

	# Wie nooit getest heeft ziet het hier, vóór de titel valt: blind deployen
	# kost iets, en die rekening moet in beeld staan op het moment dat hij
	# betaald wordt. Anders leest een lage score als pech in plaats van als de
	# prijs voor niet-kijken — en dan leert de speler er niets van.
	if not bool(_model.bekend.get(&"bugs", false)):
		_console_regel("ONGETEST. Elke bug telt dubbel.", UiKit.ROOD, UiKit.FS_SMALL)
		await _pauze(0.7)

	var score := _score()
	var uit := _uitkomst(score)
	var titel := String(uit.get("titel", "OPGELEVERD"))
	var tekst := String(uit.get("tekst", ""))

	# Eén keer mag het misgaan — en dan gaat het ook echt mis. Zie de kop.
	# De teller zelf wordt niet hier opgehoogd: een minigame mag Session lezen,
	# nooit schrijven (`minigame_base.gd` regel 6-7). `TicketController` telt
	# de mislukte poging op het moment dat de FAIL-uitkomst binnenkomt.
	if faalt_deploy(score, _faal_drempel(), Session.get_counter(POGINGEN_TELLER)):
		await _pauze(0.5)
		_wis_console()
		_console.alignment = BoxContainer.ALIGNMENT_CENTER
		_console_regel("ROLLBACK", UiKit.ROOD, UiKit.FS_HEAD)
		_console_regel(_foutcode, UiKit.ROOD, UiKit.FS_SMALL)
		_console_regel("Het staat niet live. Dat hoorde iedereen.", UiKit.WIT, UiKit.FS_SMALL)
		AudioDirector.play_ui(&"fout")
		impact(3.0, 0.4, Haptiek.Sterkte.SLAG)
		await _pauze(1.8)
		await finish_with_banner(false, "ROLLBACK", score, {
			&"score": score,
			&"titel": "ROLLBACK",
			&"tekst": "",
			&"eind": _model.toestand.duplicate(),
			&"gebruikt": _model.gedaan.duplicate(),
			&"foutcode": _foutcode,
		})
		return

	await _pauze(0.5)
	_wis_console()
	_console.alignment = BoxContainer.ALIGNMENT_CENTER
	_console_regel(titel, UiKit.GROEN, UiKit.FS_HEAD)
	_console_regel(tekst, UiKit.WIT, UiKit.FS_SMALL)
	AudioDirector.play_ui(&"deploy_ok")
	await _pauze(1.8)

	# P2: de banner van MinigameBase zit sinds `finish_with_banner()` in de
	# footer-strook, niet meer los over het veld.
	await finish_with_banner(true, titel, score, {
		&"score": score,
		&"titel": titel,
		&"tekst": tekst,
		&"eind": _model.toestand.duplicate(),
		&"gebruikt": _model.gedaan.duplicate(),
		&"foutcode": _foutcode,
	})


## Vertrouwen en scope zijn wat je oplevert, bugs is wat je meelevert, en getest
## is wat je erover weet. De som zelf staat niet hier maar in
## `Gevolgen.oplevering_score()`: zo rekent de testsuite met dezelfde som als
## de finale, en niet met een kopie die stilletjes uit de pas kan lopen.
func _score() -> int:
	return _model.score()


## Eerste uitkomst waarvan de drempel gehaald is; de data staat aflopend.
## Onder deze score gaat de eerste deploy mis: de drempel van de op één na
## laagste uitkomst ("KRAP"), uit de data.
func _faal_drempel() -> int:
	var uitkomsten: Array = content().get("uitkomsten", [])
	if uitkomsten.size() < 2:
		return 0
	return int((uitkomsten[uitkomsten.size() - 2] as Dictionary).get("min", 0))


## Statisch, zodat de testsuite de regel kaal kan doorrekenen: te laag én de
## eerste poging.
static func faalt_deploy(score: int, drempel: int, pogingen: int) -> bool:
	return score < drempel and pogingen == 0


func _uitkomst(score: int) -> Dictionary:
	for raw: Variant in content().get("uitkomsten", []):
		var u := raw as Dictionary
		if score >= int(u.get("min", 0)):
			return u
	return {"titel": "OPGELEVERD", "tekst": ""}


# --- Vormgeving -----------------------------------------------------------

## Sinds de meters van het scherm zijn (zie `_bouw_kop()`) is `_waarde` leeg en
## doet dit stil niets. De functie blijft staan omdat `_toon_veranderd()` hem
## op elke handeling aanroept en de toestand zelf nog wél bestaat: hij zaait de
## voorsprong en de vuursnelheid. Zou er ooit weer een cijferweergave komen,
## dan hangt hij hier.
func _refresh() -> void:
	if _model == null or _waarde.is_empty():
		return
	for m: StringName in METERS:
		var l := _waarde[m] as Label
		if bool(_model.bekend.get(m, false)) or not _verbergt(m):
			l.text = str(int(_model.toestand[m]))
			l.add_theme_color_override("font_color", _meter_kleur(m))
		else:
			# Je weet niet hoe erg het is tot je kijkt. Een 3 die er vanaf het
			# begin staat haalt de hele reden om te testen weg.
			l.text = "?"
			l.add_theme_color_override("font_color", UiKit.GRIJS_OP_LICHT)


## Een meter blijft verborgen zolang een keuze belooft hem te onthullen.
func _verbergt(m: StringName) -> bool:
	for raw: Variant in content().get("keuzes", []):
		if StringName((raw as Dictionary).get("onthult", "")) == m:
			return true
	return false


## GROEN_OP_LICHT/ROOD_OP_LICHT, niet GROEN/ROOD: de meterstrook staat op
## UiKit.WIT — een lichte ondergrond (P3).
func _meter_kleur(m: StringName) -> Color:
	var v := int(_model.toestand[m])
	match m:
		&"bugs":
			return UiKit.GROEN_OP_LICHT if v == 0 else UiKit.ROOD_OP_LICHT
		&"vertrouwen":
			return UiKit.GROEN_OP_LICHT if v >= 5 else (UiKit.ORANJE if v >= 3 else UiKit.ROOD_OP_LICHT)
		&"getest":
			return UiKit.BLUEBIRD_INK if v > 0 else UiKit.GRIJS_OP_LICHT
	return UiKit.INK


## Een waarde die verandert moet je zien veranderen, anders leest een handeling
## als niets: het getal springt op en de kleur komt van groen of rood terug naar
## waar hij hoort.
func _flits(m: StringName, beter: bool) -> void:
	var l := _waarde.get(m) as Label
	if l == null:
		return
	var oud := _tweens.get(m) as Tween
	if oud != null and oud.is_valid():
		oud.kill()

	var vanaf := UiKit.GROEN_OP_LICHT if beter else UiKit.ROOD_OP_LICHT
	var doel := _meter_kleur(m) if l.text != "?" else UiKit.GRIJS_OP_LICHT
	l.pivot_offset = l.size * 0.5
	l.scale = Vector2(1.5, 1.5)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(l, "scale", Vector2.ONE, 0.34) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_method(func(t: float) -> void:
		l.add_theme_color_override("font_color", vanaf.lerp(doel, t)), 0.0, 1.0, 0.34)
	_tweens[m] = tw


func _zeg(tekst: String, kleur: Color) -> void:
	if tekst == "":
		return
	_regel.text = tekst
	_regel.add_theme_color_override("font_color", kleur)


## Links de klok, rechts de voorsprong. Die twee stonden in de kopstrook tot de
## straat daar kwam; als getal horen ze nu naast elkaar direct onder de strook,
## waar ze eraan aflezen wat de strook laat voelen. De strook draagt het gevoel,
## het getal draagt de precisie: zeventien seconden voorsprong is op 168 px maar
## achtendertig pixels, en dat verschil moet je kunnen náslaan.
func _status_regel() -> void:
	if _fase == Fase.HERSTELLEN:
		set_status("nog %d handelingen" % _acties if _acties != 1 else "nog 1 handeling")
		return
	if _model == null:
		return
	var s := int(ceil(_model.klok))
	set_status("%d:%02d  ·  %d s voorsprong" % [s / 60, s % 60, maxi(0, floori(_model.voorsprong))])


func _refresh_klok() -> void:
	if _klok_label == null or _model == null:
		return
	var s := int(ceil(_model.klok))
	_klok_label.text = "%d:%02d" % [s / 60, s % 60]
	_klok_label.add_theme_color_override("font_color",
		UiKit.ROOD if _model.klok <= KLOK_ALARM else UiKit.ORANJE)


## F5-a: `process_always = true` staat hier nog steeds op de console-pauzes.
## Backgrounden (`Shell._naar_achtergrond()`) pauzeert de tree onvoorwaardelijk,
## ook tijdens deze minigame, en een console die dan halverwege blijft hangen is
## een minigame die niet meer af te maken is. De klok van fase 1 loopt sinds P5
## wél gewoon mee met de tree (`_process`) en staat dus stil als de speler in
## een andere app zit.
func _pauze(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout


func _exit_tree() -> void:
	for m: Variant in _tweens:
		var tw := _tweens[m] as Tween
		if tw != null and tw.is_valid():
			tw.kill()
	_tweens.clear()


# --- QA -------------------------------------------------------------------

## Speelt de finale langs de echte route: blus telkens het brandje met de
## kortste balk, en in fase 3 de twee herstelhandelingen. Geen kortsluiting
## naar succeed(), want dan test dit niets van de mechaniek.
##
## Wordt door `Autopilot` en `boot.gd` elke halve seconde opnieuw aangeroepen,
## dus hij doet per aanroep één handeling en is idempotent: hij mag niet zelf
## een lus draaien die de tweede aanroep dubbel laat lopen.
func qa_solve() -> void:
	if _bezig:
		return
	match _fase:
		Fase.VOORBEREIDEN:
			# Staat de ontwarring open, dan is dát de opgave: per aanroep één
			# werk-fragment, in de volgorde die het bericht zelf aangeeft. De
			# QA-route loopt zo langs de echte winroute en niet eromheen.
			if _puzzel_nr >= 0:
				_qa_fragment()
				return
			var b := _model.kortste() if _model != null else {}
			if not b.is_empty():
				_op_handeling(StringName(b[&"handeling"]))
		Fase.HERSTELLEN:
			# Eerst de klant, dan nog een keer kijken: precies de les die de
			# minigame wil leren, en daarmee de bovenste uitkomst.
			var route: Array[StringName] = [&"informeren", &"nakijken"]
			if _acties > 0 and _qa_stap < route.size():
				_op_handeling(route[_qa_stap])
				_qa_stap += 1
			else:
				await _op_deploy()
		_:
			pass
