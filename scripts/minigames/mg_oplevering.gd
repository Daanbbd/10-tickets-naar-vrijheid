extends MinigameBase
## BBD-210 — de oplevering. De finale. Elke geslaagde uitkomst is een
## oplevering: de titel begint met OPGELEVERD en beweegt mee met de score, en
## wat echt verschilt is wat je er achteraf over kunt zeggen.
##
## Sinds Fase 3b kan de eerste poging wél mislukken: onder de laagste
## geslaagde drempel op de eerste deploy volgt een ROLLBACK met de foutcode van
## je eigen personage, het ticket blijft open en je probeert het opnieuw. De
## tweede poging slaagt altijd ("OPGELEVERD, EINDELIJK") — een dag die zelfs met
## perfect spel niet boven de drempel komt bestaat (0,7% van alle
## dagcombinaties, doorgerekend) en mag niemand vastzetten. Falen kost dus één
## keer tijd en gezicht, nooit voortgang. Zie `faalt_deploy()`.
##
## Het werkwoord is beperkte handelingen met echte gevolgen. Acht handelingen,
## vier waarden, en een aantal bugs dat je niet kent tot je gaat kijken —
## kijken kost precies de handelingen die je daarna niet meer aan fixen kwijt
## kunt. Dat is de hele spanning, en het is ook de les.

enum Fase { VOORBEREIDEN, DEPLOYEN, HERSTELLEN, KLAAR }

## De vier waarden, in de leesrichting van het dashboard.
const METERS: Array[StringName] = [&"bugs", &"vertrouwen", &"getest", &"scope"]
const METER_NAAM := {
	&"bugs": "BUGS", &"vertrouwen": "VERTROUWEN",
	&"getest": "GETEST", &"scope": "SCOPE",
}

## Handelingen in fase 3: genoeg om te reageren, te weinig om het op te lossen.
const HERSTEL_ACTIES := 2
## Hoeveel keer er al gedeployd is deze dag; alleen de eerste keer kan misgaan.
const POGINGEN_TELLER := &"deploy_pogingen"

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

## Hoe lang fase 1 duurt zonder een `klok_seconden` in de content. Een minuut
## en een kwart is genoeg om acht handelingen te overwegen, niet genoeg om ze
## op je gemak uit te rekenen.
const KLOK_STANDAARD := 75.0
## Vanaf hier kleurt de klok rood: een laatste visuele waarschuwing voordat hij
## voor je beslist.
const KLOK_ALARM := 15.0


var _fase: Fase = Fase.VOORBEREIDEN
var _acties: int = 0
var _acties_max: int = 0
## Verbruikte handelingen, en niet het aantal keuzes: de gebeurtenissen vuren op
## `na`, en een keuze van 0 handelingen brengt je dus geen stap dichter bij de
## telefoon van 21:47.
var _verbruikt: int = 0
var _toestand: Dictionary = {}
var _start_bugs: int = 0
var _bekend: Dictionary = {}
var _gedaan: Array[String] = []
var _eenmalig_op: Dictionary = {}
var _gebeurtenis: int = 0
var _foutcode: String = ""
var _foutregel: String = ""
## Resterende seconden in fase 1. Loopt door tijdens het lezen van een keuze,
## niet alleen tussen keuzes: dat is precies het verschil tussen een klok en
## een teller.
var _klok_resterend: float = 0.0
var _klok_gestart: bool = false
## Waar staat tijdens een handeling die zich nog aan het afspelen is; zonder dit
## kan een snelle tikker twee keuzes over elkaar heen zetten.
var _bezig: bool = false
var _qa_bezig: bool = false

var _waarde: Dictionary = {}
var _tweens: Dictionary = {}
var _pips: HBoxContainer = null
var _regel: Label = null
var _keuzes: VBoxContainer = null
var _deploy: Button = null
var _foutbalk: PanelContainer = null
var _foutbalk_label: Label = null
var _console_paneel: PanelContainer = null
var _console: VBoxContainer = null
var _klok_label: Label = null


func _on_setup() -> void:
	var c := content()
	if c.is_empty():
		fail()
		return

	# config wint van content: zo kan de opgetelde dag van de speler de
	# begintoestand bepalen zonder dat deze minigame iets over de wereld hoeft
	# te weten. Nu altijd leeg; straks niet meer, en dan hoeft hier niets bij.
	var start: Dictionary = {}
	for k: Variant in (c.get("start", {}) as Dictionary):
		start[String(k)] = (c.get("start", {}) as Dictionary)[k]
	for k: Variant in (cfg("start_override", {}) as Dictionary):
		start[String(k)] = (cfg("start_override", {}) as Dictionary)[k]

	for m: StringName in METERS:
		_toestand[m] = maxi(0, int(start.get(String(m), 0)))
	_start_bugs = int(_toestand[&"bugs"])
	_acties = maxi(1, int(c.get("acties", 8)))
	_acties_max = _acties

	_lees_variant(c)
	_bouw(c)
	_refresh()
	_status_regel()

	_klok_resterend = maxf(1.0, float(c.get("klok_seconden", KLOK_STANDAARD)))
	_refresh_klok()
	_klok_gestart = true
	_klok_loop()


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

func _bouw(c: Dictionary) -> void:
	var body := build_chrome(default_title(), String(c.get("intro", "")))

	# Het dashboard is het enige dat nooit mag wegscrollen, dus het gaat in de
	# kopstrook van het chrome.
	_bouw_dashboard()
	_bouw_foutbalk()

	# Op de chrome zelf en niet op het witte dashboard, dus de donkere-ondergrond
	# tint. Diezelfde regel wisselt van kleur via `_zeg()`; die kleuren staan daar.
	_regel = UiKit.label("Hoeveel bugs erin zitten weet je niet. Testen vertelt het je.",
		UiKit.FS_SMALL, UiKit.GRIJS_OP_DONKER)
	# Twee regels reserveren: de reactie op een handeling verschijnt hier, en een
	# lijst keuzes die bij elke tik een paar pixels opschuift is niet te raken.
	_regel.custom_minimum_size = Vector2(0, 26)
	body.add_child(_regel)

	_keuzes = VBoxContainer.new()
	_keuzes.add_theme_constant_override("separation", 2)
	body.add_child(_keuzes)

	# De knop die de finale afsluit hoort buiten de scroll: hij mag nooit onder de
	# lijst keuzes wegzakken, want dan is de finale niet af te maken.
	# Dit was de enige knop in het spel met een eigen blauwe stijl; die stijl is
	# nu UiKit.knop_primair() en staat op elke bevestigende actie. De eigen
	# hoogte van 26 mocht mee weg: die zat onder UiKit.KNOP_MIN_H.
	_deploy = UiKit.knop_primair(String(c.get("deploy_label", "DEPLOYEN")), UiKit.FS_BODY)
	_deploy.focus_mode = Control.FOCUS_NONE
	_deploy.pressed.connect(_op_deploy)
	chrome_footer().add_child(_deploy)

	_bouw_keuzes()


func _bouw_dashboard() -> void:
	var paneel := PanelContainer.new()
	paneel.add_theme_stylebox_override("panel", UiKit.panel_krap(UiKit.WIT, UiKit.LINE))
	paneel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	chrome_header().add_child(paneel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	paneel.add_child(v)

	var kop := HBoxContainer.new()
	kop.add_theme_constant_override("separation", 4)
	v.add_child(kop)
	kop.add_child(_vast("HANDELINGEN", UiKit.FS_SMALL, UiKit.GRIJS_OP_LICHT))
	_pips = HBoxContainer.new()
	_pips.add_theme_constant_override("separation", 2)
	_pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	kop.add_child(_pips)

	# De klok hangt rechts uitgelijnd op dezelfde regel: hij hoort bij de
	# handelingen, niet bij de meters eronder. Een losse rij zou suggereren
	# dat hij een vijfde waarde is; dat is hij niet, hij is een deadline.
	var vulling := Control.new()
	vulling.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kop.add_child(vulling)
	_klok_label = _vast("", UiKit.FS_SMALL, UiKit.ORANJE)
	_klok_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	kop.add_child(_klok_label)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 9)
	grid.add_theme_constant_override("v_separation", 1)
	v.add_child(grid)
	for m: StringName in METERS:
		var cel := HBoxContainer.new()
		cel.add_theme_constant_override("separation", 2)
		cel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(cel)
		var naam := _vast(String(METER_NAAM[m]), UiKit.FS_SMALL, UiKit.GRIJS_OP_LICHT)
		naam.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cel.add_child(naam)
		var w := _vast("0", UiKit.FS_BODY, UiKit.INK)
		w.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cel.add_child(w)
		_waarde[m] = w


## Een label dat niet mag afbreken. UiKit.label() zet autowrap aan omdat een
## lange regel anders de indeling van een 192px-canvas opentrekt, maar in een
## HBox is het omgekeerde het probleem: een afbrekend label meldt een minimum
## van één letter, en dan zet de container HANDELINGEN rechtop.
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
	# Na het dashboard, dus vlak boven de keuzes waar je in fase 3 op reageert.
	chrome_header().add_child(_foutbalk)
	# ROOD_OP_LICHT, niet ROOD: _foutbalk staat op UiKit.PANEL (licht), en ROOD
	# zelf is een derivaat voor een donkere ondergrond (P3) — die dit paneel
	# niet heeft, in tegenstelling tot de rest van deze minigame.
	_foutbalk_label = UiKit.label("", UiKit.FS_SMALL, UiKit.ROOD_OP_LICHT)
	_foutbalk.add_child(_foutbalk_label)


func _bouw_keuzes() -> void:
	for ch: Node in _keuzes.get_children():
		_keuzes.remove_child(ch)
		ch.queue_free()

	for raw: Variant in content().get("keuzes", []):
		var o := raw as Dictionary
		var reden := _reden(o)
		var tekst := "%s  ·%d" % [String(o.get("label", "?")), int(o.get("kost", 0))]
		if reden != "":
			tekst += "  (%s)" % reden
		var b := UiKit.keuzeknop(tekst, UiKit.FS_SMALL)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		if reden == "":
			b.pressed.connect(_kies.bind(o))
		else:
			# Zichtbaar maar dood, met de reden erin. Een keuze die je niet mag
			# doen is informatie: dat fixen pas kan na testen is precies wat de
			# speler moet leren, en een verborgen knop leert hem niets.
			b.disabled = true
			b.add_theme_color_override("font_disabled_color", UiKit.GRIJS)
			b.add_theme_stylebox_override("disabled",
				UiKit.panel(UiKit.NEUTRAAL_TINT, UiKit.GRIJS))
		_keuzes.add_child(b)


## Leeg betekent: deze keuze mag. Anders staat er waarom niet, kort genoeg om
## op de knop zelf te passen.
func _reden(o: Dictionary) -> String:
	if bool(o.get("eenmalig", false)) and _eenmalig_op.has(String(o.get("id", ""))):
		return "al gedaan"
	var nodig := int(o.get("vereist_getest", 0))
	if nodig > 0 and int(_toestand[&"getest"]) < nodig:
		return "test eerst"
	if not can_perform_action(int(o.get("kost", 0))):
		return "te weinig"
	return ""


# --- Handelingen ----------------------------------------------------------

## Contract uit de turn-systeemregels: dit gaat altijd voor het verlagen van
## `_acties`, nooit erna.
func can_perform_action(kost: int) -> bool:
	return _acties >= kost


func _kies(o: Dictionary) -> void:
	if _bezig or _fase == Fase.DEPLOYEN or _fase == Fase.KLAAR:
		return
	var kost := int(o.get("kost", 0))
	if _reden(o) != "" or not can_perform_action(kost):
		return

	_bezig = true
	_acties -= kost
	_verbruikt += kost
	_gedaan.append(String(o.get("id", "")))
	if bool(o.get("eenmalig", false)):
		_eenmalig_op[String(o.get("id", ""))] = true

	# Onthullen voor het effect: zo zie je bij de eerste test het getal
	# verschijnen dat er de hele tijd al stond.
	var onthult := StringName(o.get("onthult", ""))
	if onthult != &"" and not bool(_bekend.get(onthult, false)):
		_bekend[onthult] = true
		_refresh()
		_flits(onthult, false)

	_pas_effect(o.get("effect", {}) as Dictionary)
	_zeg(String(o.get("regel", "")), UiKit.BLUEBIRD_BRIGHT)
	AudioDirector.play_ui(&"klik")
	_bouw_keuzes()
	_status_regel()
	await _pauze(TIK_REGEL)

	# Toestand eerst helemaal bijwerken, dan pas de volgende fase in. Een
	# gebeurtenis die na de overgang landt zou een fase raken die er niet is.
	await _gebeurtenissen()
	_bezig = false

	if _acties <= 0:
		await _op_deploy()


## Gebeurtenissen overkomen je; je kiest ze niet. Ze vuren op verbruikte
## handelingen, en de laatste zet er een bug bíj — wie zijn handelingen tot op
## nul uitrekent komt daar precies bedrogen mee uit.
##
## Een gebeurtenis met `storing: true` krijgt een echte onderbreking: een korte
## overname van het scherm in plaats van dezelfde stille `_zeg()`-regel als de
## andere twee. Het effect verwerkt zich altijd eerst, dus het dashboard flitst
## er al onderdoor terwijl de overname nog in beeld staat.
func _gebeurtenissen() -> void:
	var lijst: Array = content().get("gebeurtenissen", [])
	while _gebeurtenis < lijst.size():
		var g := lijst[_gebeurtenis] as Dictionary
		if _verbruikt < int(g.get("na", 0)):
			return
		_gebeurtenis += 1
		var effect := g.get("effect", {}) as Dictionary
		var tekst := String(g.get("tekst", ""))
		_pas_effect(effect)
		if bool(g.get("storing", false)):
			_bouw_keuzes()
			await _toon_storing(tekst)
		else:
			_zeg(tekst, UiKit.ORANJE)
			if not effect.is_empty():
				AudioDirector.play_ui(&"fout")
			_bouw_keuzes()
			await _pauze(TIK_GEBEURTENIS)


## Neemt het scherm heel even helemaal over: een storing landt in je dag, niet
## in een regel onderaan. `finish_with_banner()` blijft ongemoeid — dit is
## opvoering, geen nieuwe uitkomst.
func _toon_storing(tekst: String) -> void:
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
	var in_tw := create_tween()
	in_tw.tween_property(overlay, "modulate:a", 1.0, 0.1)
	await in_tw.finished
	await _pauze(TIK_GEBEURTENIS + 0.6)
	if not is_instance_valid(overlay):
		return
	var uit_tw := create_tween()
	uit_tw.tween_property(overlay, "modulate:a", 0.0, 0.15)
	await uit_tw.finished
	if is_instance_valid(overlay):
		overlay.queue_free()


func _pas_effect(effect: Dictionary) -> void:
	var veranderd: Array[StringName] = []
	var beter: Dictionary = {}
	for k: Variant in effect:
		var m := StringName(k)
		if not _toestand.has(m):
			continue
		var oud := int(_toestand[m])
		# Geen negatieve meters: minder dan nul bugs bestaat niet, en een
		# negatief getal zou de score cadeau doen aan wie doorfixt.
		var nieuw := maxi(0, oud + int(effect[k]))
		if nieuw == oud:
			continue
		_toestand[m] = nieuw
		veranderd.append(m)
		beter[m] = (nieuw < oud) if m == &"bugs" else (nieuw > oud)
	_refresh()
	for m: StringName in veranderd:
		_flits(m, bool(beter[m]))


## Deployen mag ook vroeg, met handelingen over. Niet terwijl er nog een
## handeling aan het landen is: dan zou een gebeurtenis de toestand nog raken
## terwijl de console al loopt.
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
	# De klok hoort bij fase 1. Zodra je deployt is de deadline gehaald of
	# geforceerd, en een bevroren tijd op het scherm zou allebei ontkennen.
	if _klok_label != null:
		_klok_label.text = ""
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
	_acties_max = HERSTEL_ACTIES
	_foutbalk_label.text = _foutcode
	_foutbalk.visible = true
	_deploy.text = "LIVE ZETTEN"
	_sluit_console()
	_fase = Fase.HERSTELLEN
	_bezig = false

	_zeg("Twee handelingen. Daarna gaat hij live, wat je ook doet.", UiKit.WIT)
	_bouw_keuzes()
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
	if not bool(_bekend.get(&"bugs", false)):
		_console_regel("ONGETEST — elke bug telt dubbel", UiKit.ROOD, UiKit.FS_SMALL)
		await _pauze(0.7)

	var score := _score()
	var uit := _uitkomst(score)
	var titel := String(uit.get("titel", "OPGELEVERD"))
	var tekst := String(uit.get("tekst", ""))

	# Eén keer mag het misgaan — en dan gaat het ook echt mis. Zie de kop.
	if faalt_deploy(score, _faal_drempel(), Session.get_counter(POGINGEN_TELLER)):
		Session.add_counter(POGINGEN_TELLER)
		await _pauze(0.5)
		_wis_console()
		_console.alignment = BoxContainer.ALIGNMENT_CENTER
		_console_regel("ROLLBACK", UiKit.ROOD, UiKit.FS_HEAD)
		_console_regel(_foutcode, UiKit.ROOD, UiKit.FS_SMALL)
		_console_regel("Het staat niet live. Dat hoorde iedereen.", UiKit.WIT, UiKit.FS_SMALL)
		AudioDirector.play_ui(&"fout")
		Juice.schok(3.0, 0.4)
		await _pauze(1.8)
		move_child(_banner, get_child_count() - 1)
		await finish_with_banner(false, "ROLLBACK", score, {
			&"score": score,
			&"titel": "ROLLBACK",
			&"tekst": "",
			&"eind": _toestand.duplicate(),
			&"gebruikt": _gedaan.duplicate(),
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

	# De banner van MinigameBase is vóór de console aangehangen en zou er dus
	# achter verdwijnen; hij hoort het laatste woord te hebben.
	move_child(_banner, get_child_count() - 1)
	await finish_with_banner(true, titel, score, {
		&"score": score,
		&"titel": titel,
		&"tekst": tekst,
		&"eind": _toestand.duplicate(),
		&"gebruikt": _gedaan.duplicate(),
		&"foutcode": _foutcode,
	})


## Vertrouwen en scope zijn wat je oplevert, bugs is wat je meelevert, en getest
## is wat je erover weet. De som zelf staat niet meer hier maar in
## `Gevolgen.oplevering_score()`: zo rekent de testsuite met dezelfde som als
## de finale, en niet met een kopie die stilletjes uit de pas kan lopen.
##
## Twee afwijkingen van de suggestie uit het ontwerp, allebei daar: `getest`
## telt tot een plafond mee (twee controles per bug waarmee je begon; daarna
## moet winst uit fixen komen, anders is acht keer de suite draaien de hoogste
## score van het spel), en wie nooit getest heeft betaalt per bug extra. Blind
## deployen was met nul handelingen te winnen — precies het gedrag dat de
## minigame wil afleren — en `_bekend[&"bugs"]` is de enige eerlijke maat voor
## blind: niet hoeveel je getest hebt, maar of je ooit gekeken hebt.
func _score() -> int:
	return Gevolgen.oplevering_score(_toestand, _start_bugs, bool(_bekend.get(&"bugs", false)))


## Eerste uitkomst waarvan de drempel gehaald is; de data staat aflopend.
## Onder deze score gaat de eerste deploy mis: de drempel van de op één na
## laagste uitkomst ("KRAP"), uit de data. Alles daaronder was toch al "het
## enige wat je er nu over kunt zeggen".
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

func _refresh() -> void:
	for m: StringName in METERS:
		var l := _waarde[m] as Label
		if bool(_bekend.get(m, false)) or not _verbergt(m):
			l.text = str(int(_toestand[m]))
			l.add_theme_color_override("font_color", _meter_kleur(m))
		else:
			# Je weet niet hoe erg het is tot je kijkt. Een 3 die er vanaf het
			# begin staat haalt de hele keuze om te testen weg.
			l.text = "?"
			l.add_theme_color_override("font_color", UiKit.GRIJS_OP_LICHT)
	_refresh_pips()


## Een meter blijft verborgen zolang een keuze belooft hem te onthullen.
func _verbergt(m: StringName) -> bool:
	for raw: Variant in content().get("keuzes", []):
		if StringName((raw as Dictionary).get("onthult", "")) == m:
			return true
	return false


func _refresh_pips() -> void:
	for ch: Node in _pips.get_children():
		_pips.remove_child(ch)
		ch.queue_free()
	for i: int in _acties_max:
		var p := ColorRect.new()
		p.custom_minimum_size = Vector2(4, 8)
		p.color = UiKit.BLUEBIRD_INK if i < _acties else UiKit.NEUTRAAL_TINT
		_pips.add_child(p)


## GROEN_OP_LICHT/ROOD_OP_LICHT, niet GROEN/ROOD: `_waarde[m]` staat op het
## dashboard, en dat paneel is UiKit.WIT — een lichte ondergrond (P3).
func _meter_kleur(m: StringName) -> Color:
	var v := int(_toestand[m])
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


func _status_regel() -> void:
	match _acties:
		0: set_status("handelingen op")
		1: set_status("nog 1 handeling")
		_: set_status("nog %d handelingen" % _acties)


## Tikt fase 1 weg in echte seconden, niet in handelingen: hij loopt ook door
## terwijl je een keuze aan het lezen bent. Op nul forceert hij `_op_deploy()`
## met wat er dan ligt — geen nieuwe mechaniek, alleen een grens aan hoe lang
## je over de acht handelingen mag nadenken.
func _klok_loop() -> void:
	while _fase == Fase.VOORBEREIDEN and _klok_resterend > 0.0:
		await _pauze(1.0)
		# De minigame kan tussentijds afgesloten zijn (bv. een vroege abort);
		# zonder deze wacht raakt deze achtergrondlus een vrijgegeven object.
		if not is_inside_tree() or _fase != Fase.VOORBEREIDEN:
			return
		_klok_resterend = maxf(0.0, _klok_resterend - 1.0)
		_refresh_klok()
	if not is_inside_tree() or _fase != Fase.VOORBEREIDEN:
		return

	# Tijd op, maar niet midden in een handeling grijpen: een gebeurtenis die
	# nog moet landen mag dat eerst doen.
	while _fase == Fase.VOORBEREIDEN and _bezig:
		await _pauze(0.1)
		if not is_inside_tree():
			return
	if _fase != Fase.VOORBEREIDEN:
		return
	_zeg("De tijd is om. Je gaat nu live met wat er ligt.", UiKit.ORANJE)
	AudioDirector.play_ui(&"fout")
	await _pauze(TIK_REGEL)
	if not is_inside_tree():
		return
	await _op_deploy()


func _refresh_klok() -> void:
	if _klok_label == null or not _klok_gestart:
		return
	var s := int(ceil(_klok_resterend))
	_klok_label.text = "%d:%02d" % [s / 60, s % 60]
	_klok_label.add_theme_color_override("font_color",
		UiKit.ROOD if _klok_resterend <= KLOK_ALARM else UiKit.ORANJE)


## F5-a: dit was `process_always = true` omdat de wereld gepauzeerd stond
## zolang deze minigame liep, en anders nooit was afgelopen. Dat is niet meer
## zo tijdens een gewone speelbeurt — maar backgrounden (`Shell._naar_achtergrond()`)
## pauzeert de tree nog altijd wél, onvoorwaardelijk, ook tijdens deze
## minigame. Blijft dit op `true` staan, dan tikt `_klok_loop()` hierboven
## door terwijl de speler in een andere app zit — precies hetzelfde als elke
## niet-geflagde timer in `main.gd` vandaag al doet (`create_timer()` staat
## standaard al op `process_always = true` in Godot zelf). Dat is dus geen
## nieuwe aanname van deze functie, maar een bestaande eigenschap van de hele
## codebase, en die in zijn geheel herzien hoort niet bij F5. Blijft daarom
## bewust op `true` staan, in plaats van hier alleen deze ene minigame anders
## te laten gedragen dan de rest.
func _pauze(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout


func _exit_tree() -> void:
	for m: Variant in _tweens:
		var tw := _tweens[m] as Tween
		if tw != null and tw.is_valid():
			tw.kill()
	_tweens.clear()


# --- QA -------------------------------------------------------------------

## Speelt de finale langs de echte route: keuzes via _kies(), fase 2 via
## _op_deploy(), en dan de twee herstelhandelingen. Geen kortsluiting naar
## succeed(), want dan test dit niets van de mechaniek.
func qa_solve() -> void:
	if _qa_bezig:
		return
	_qa_bezig = true
	await _qa_route()


## Eerst kijken wat er is, dan fixen, dan iemand laten meekijken — precies de
## les die de minigame wil leren, en daarmee de bovenste uitkomst.
func _qa_route() -> void:
	for id: StringName in [&"testen", &"testen", &"fixen", &"fixen", &"collega"]:
		if _fase != Fase.VOORBEREIDEN:
			break
		await _qa_kies(id)
	if _fase == Fase.VOORBEREIDEN:
		await _op_deploy()
	for id: StringName in [&"informeren", &"nakijken"]:
		if _fase != Fase.HERSTELLEN:
			break
		await _qa_kies(id)
	if _fase == Fase.HERSTELLEN:
		await _op_deploy()


func _qa_kies(id: StringName) -> void:
	for raw: Variant in content().get("keuzes", []):
		var o := raw as Dictionary
		if StringName(o.get("id", "")) == id:
			await _kies(o)
			return
