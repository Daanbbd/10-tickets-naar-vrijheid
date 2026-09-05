class_name MinigameBase
extends Control
## Root van elke minigame. Draait als overlay op Shell/MinigameLayer, met
## `Session.input_locked` aan (`Shell.run_minigame()` zet dat) zodat de speler
## niet weg kan lopen — de wereld eromheen staat sinds F5-a niet meer stil.
## Mag Session LEZEN, nooit schrijven: de uitkomst gaat uitsluitend via
## finish() terug naar de TicketController.

signal finished(result: MinigameResult)

var minigame_id: StringName = &""
var config: Dictionary = {}

var _done: bool = false


func _ready() -> void:
	add_to_group(&"minigame")


## Wordt aangeroepen na add_child, dus @onready-refs bestaan al.
func setup(cfg: Dictionary) -> void:
	config = cfg
	# Inhoud die van buiten komt wint van het bestand. Zo kan een aanroeper
	# dezelfde mechaniek met een andere opgave draaien — dat is precies wat een
	# trait doet — zonder dat elke minigame apart moet weten dat dat bestaat.
	content_override = cfg.get("inhoud", {}) as Dictionary
	_on_setup()


## QA: lost de minigame direct correct op. Overschrijven waar dat kan;
## de standaard slaagt gewoon, zodat de questketen altijd doorloopt.
func qa_solve() -> void:
	succeed(100, {"qa": true})


## Overschrijven in elke minigame.
func _on_setup() -> void:
	push_error("MinigameBase._on_setup() niet overschreven in %s" % scene_file_path)


func succeed(score: int = 0, payload: Dictionary = {}) -> void:
	_finish(GameEnums.Outcome.SUCCESS, score, payload)

func fail(score: int = 0, payload: Dictionary = {}) -> void:
	_finish(GameEnums.Outcome.FAIL, score, payload)

func abort() -> void:
	_finish(GameEnums.Outcome.ABORT, 0, {})


func _finish(oc: GameEnums.Outcome, score: int, payload: Dictionary) -> void:
	if _done:
		return
	_done = true
	finished.emit(MinigameResult.make(minigame_id, oc, score, payload))


## Handige helpers voor de afgeleide minigames.
func player_character() -> CharacterDef:
	return Session.character()

func cfg(key: String, fallback: Variant = null) -> Variant:
	return config.get(key, fallback)


# --- Gedeelde vormgeving -------------------------------------------------

var _body: VBoxContainer = null
var _kolom: VBoxContainer = null
var _scroll: ScrollContainer = null
var _header: VBoxContainer = null
var _footer: VBoxContainer = null
var _status: Label = null
var _banner: PanelContainer = null
var _banner_label: Label = null
var _storing_paneel: PanelContainer = null
var _storing_label: Label = null

## P1.2: de WAT-overlay ín het veld en zijn tween. Bijgehouden zodat een echte
## aanraking hem kan wegvegen (`_unhandled_input()`) en `_exit_tree()` de tween
## nooit los in de lucht laat hangen.
var _intro_overlay: Control = null
var _intro_tween: Tween = null


## Bouwt het venster en geeft de VBox terug waar de minigame zijn eigen UI in zet.
##
## `_intro` zelf blijft ongebruikt: `_bouw_intro_overlay()` hieronder leest
## `content().get("intro")` rechtstreeks, gevuld via `Briefing.vul()`, zodat
## een trait die de opgave aanpast (`content_override`) ook de overlay meekrijgt.
## De parameter blijft bestaan zodat alle elf aanroepen ongewijzigd blijven —
## zie `scripts/ui/minigame_intro.gd`.
func build_chrome(title: String, _intro: String) -> VBoxContainer:
	UiKit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(UiKit.dimmer(0.72))

	# Donker oppervlak, net als de rest van de shell. Dit was een crème
	# `UiKit.panel()`, en dat maakte de minigames het enige lichte scherm in een
	# spel waarvan het titelscherm, het uitlegscherm, de karakterselectie en de
	# HUD allemaal donker zijn. Je speelt tien keer per beurt zo'n scherm; de
	# flits bij het openen was daarmee het meest voorkomende beeld van het spel.
	#
	# SCHERM_NACHT en niet PANEL_DARK: dit is een scherm en geen paneeltje in de
	# HUD, en het is dezelfde ondergrond als het uitlegscherm en het titelscherm.
	# De rand blijft LINE, zodat het venster nog leest als iets dat bovenop de
	# gedimde wereld ligt in plaats van als de wereld zelf.
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UiKit.panel(UiKit.SCHERM_NACHT, UiKit.LINE))
	UiKit.full_rect(frame)
	frame.offset_left = 4; frame.offset_right = -4
	frame.offset_top = 4; frame.offset_bottom = -4
	add_child(frame)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	frame.add_child(col)
	_kolom = col

	# Titel en status onder elkaar, niet naast elkaar: op 192 px is een kop op
	# FS_HEAD naast een statusregel breder dan het scherm, en een Container
	# groeit buiten zijn ankers om zijn kinderen te laten passen.
	#
	# FS_HEAD is de schermkop van de ladder, en dit is een scherm. Dat een titel
	# van twee woorden hier over twee regels valt is de prijs; de inhoud eronder
	# zit in een ScrollContainer en vangt dat op. Kleur en maat komen van het
	# uitlegscherm: BLUEBIRD_BRIGHT op FS_HEAD, want bb-blue zelf is op een
	# donkere ondergrond niet te lezen.
	var t := UiKit.label(title, UiKit.FS_HEAD, UiKit.BLUEBIRD_BRIGHT)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(t)
	_status = UiKit.label("", UiKit.FS_SMALL, UiKit.GRIJS_OP_DONKER)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(_status)

	# Op een portretcanvas past de inhoud van een minigame lang niet altijd in
	# beeld. Zonder scroll valt de knop onderaan buiten het scherm en is de
	# minigame niet uit te spelen.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_scroll = scroll

	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 3)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(_body)

	# Esc bestaat niet op een telefoon. Zonder een zichtbare uitweg zit een
	# speler vast in een minigame die hij niet kan oplossen, en dat is de enige
	# plek in het spel waar de wereld niet meer bereikbaar is. Dus een knop, op
	# elk apparaat; Esc blijft ernaast werken als sneltoets.
	var stop := UiKit.button("Stoppen", UiKit.FS_SMALL)
	stop.focus_mode = Control.FOCUS_NONE
	stop.pressed.connect(abort)
	col.add_child(stop)

	# P2: de banner zelf wordt pas gebouwd in `finish_with_banner()`, als
	# laatste kind van `chrome_footer()` — niet hier meer midden over het veld.
	_bouw_intro_overlay()

	return _body


## P1.2: de WAT-regel als overlay ín het veld, 2,5 s zichtbaar en dan
## wegvagend — vervangt het aparte `MinigameIntro`-scherm voor alle minigames
## behalve `mg_deploy` (die drempel houdt hij, zie
## `MinigameIntro.INTRO_KAART_VOOR`). De speler ziet het spel meteen; de
## uitleg staat erover, niet ervoor.
##
## `mouse_filter = IGNORE` op overlay én paneel: de eerste tik moet het spel
## bereiken, niet dit venster — en de `Autopilot` (M4) mag hier nooit door
## geblokkeerd worden, wat met IGNORE per definitie niet kan. Geen overlay als
## `intro` leeg is. Twee uitzonderingen: `MinigameIntro.INTRO_KAART_VOOR`
## (`mg_deploy`) toont zijn WAT al op zijn eigen kaartje vóór dit venster
## opent — deze overlay zou daar alleen een tweede keer hetzelfde herhalen —
## en `mg_urenstaat` (Dirk) is een formulier (M7), geen spel dat om affordance
## vraagt.
func _bouw_intro_overlay() -> void:
	if minigame_id == &"mg_urenstaat" or minigame_id == MinigameIntro.INTRO_KAART_VOOR:
		return
	var tekst := Briefing.vul(String(content().get("intro", "")), content())
	if tekst == "":
		return

	var overlay := CenterContainer.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.full_rect(overlay)
	add_child(overlay)

	var paneel := PanelContainer.new()
	paneel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paneel.add_theme_stylebox_override("panel", UiKit.panel(Color(UiKit.INK, 0.72), UiKit.LINE))
	overlay.add_child(paneel)

	var label := UiKit.label(tekst, UiKit.FS_BODY, UiKit.WIT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(168, 0)
	paneel.add_child(label)

	_intro_overlay = overlay
	_intro_tween = create_tween()
	_intro_tween.tween_interval(2.5)
	_intro_tween.tween_property(overlay, "modulate:a", 0.0, 0.4)
	_intro_tween.tween_callback(_weg_intro_overlay)


## Ruimt de overlay op, of hij nu wegvaagt via zijn eigen tween of via een
## echte aanraking (`_unhandled_input()`). Idempotent: een tweede aanroep (de
## tween ná een handmatige tik, of omgekeerd) doet niets.
func _weg_intro_overlay() -> void:
	if _intro_overlay == null:
		return
	if _intro_tween != null and is_instance_valid(_intro_tween):
		_intro_tween.kill()
	_intro_overlay.queue_free()
	_intro_overlay = null


func _exit_tree() -> void:
	if _intro_tween != null and is_instance_valid(_intro_tween):
		_intro_tween.kill()


## Twee stroken die **niet** meescrollen: boven en onder de inhoud.
##
## Vijf minigames hebben hier los van elkaar hetzelfde omheen gebouwd. Een
## meter, een klok, een dashboard of de enige actieknop mag niet wegscrollen —
## dan is hij precies weg op het moment dat je hem nodig hebt — maar
## `build_chrome()` gaf alleen de body *binnen* de ScrollContainer terug. Elke
## implementatie klom daarom via `body.get_parent().get_parent()` naar de kolom
## en schoof zijn node met `move_child()` op de goede index.
##
## Dat werkte, maar het is vijf keer dezelfde aanname over de binnenkant van
## deze klasse: wie hier een node tussenvoegt, breekt vijf minigames stil.
## Vandaar dat de stroken nu deel van het contract zijn.
##
## Beide worden pas gemaakt als je ze opvraagt, en de volgorde waarin dat
## gebeurt doet niet uit: de header landt altijd vóór de scroll en de footer
## altijd erna.
func chrome_header() -> VBoxContainer:
	if _header == null:
		_header = _strook()
		_kolom.add_child(_header)
		_kolom.move_child(_header, _scroll.get_index())
	return _header


func chrome_footer() -> VBoxContainer:
	if _footer == null:
		_footer = _strook()
		_kolom.add_child(_footer)
		_kolom.move_child(_footer, _scroll.get_index() + 1)
	return _footer


static func _strook() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Krimpen naar de inhoud: een strook die verticaal wil groeien vecht met de
	# ScrollContainer ernaast om de resterende hoogte.
	v.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return v


func set_status(text: String) -> void:
	if _status != null:
		_status.text = text


## F5-b: een storing landt hier, niet als overlay erboven. De telefoon (laag
## 30) en de HUD-toast (laag 10) liggen allebei onder de minigame (laag 50),
## dus onzichtbaar zolang dit scherm openstaat — `Storingen` roept dit aan op
## `Shell.active_minigame()` in plaats van de gewone wereldmelding te tonen.
##
## `kosten` is aan de minigame: een seconde van de klok, een mislukte
## handeling, een bug erbij. Deze basisklasse doet er niets mee — hij toont
## alleen de tekst in `chrome_header()`, wat het contract al vervult ("moet
## minstens visueel landen"). Een minigame die `kosten` wél wil verwerken
## overschrijft dit en roept `super.storing(tekst, kosten)` aan zodat de strook
## blijft verschijnen.
func storing(tekst: String, _kosten: Dictionary) -> void:
	var strook := chrome_header()
	if _storing_paneel == null:
		_storing_paneel = PanelContainer.new()
		_storing_paneel.add_theme_stylebox_override("panel", UiKit.panel(UiKit.ROOD, UiKit.INK))
		_storing_label = UiKit.label("", UiKit.FS_SMALL, UiKit.INK)
		_storing_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_storing_paneel.add_child(_storing_label)
		strook.add_child(_storing_paneel)
	_storing_label.text = tekst
	AudioDirector.play_ui(&"fout")
	Haptiek.tril(Haptiek.Sterkte.STOOT)


## Toont de uitslag en sluit daarna af.
##
## P2: de banner staat niet meer los over het veld — hij komt als laatste kind
## in `chrome_footer()`, volle breedte, en alle knoppen in de minigame gaan uit
## zodra hij verschijnt: de uitkomst staat vast, verder klikken kan er niets
## meer aan veranderen. Bij winst dimt het veld (`UiKit.dimmer(0.35)`,
## toegevoegd vlak vóórdat de banner verschijnt) en barst er confetti los; bij
## verlies schokt de camera. Beide bestonden al in `Juice`, maar werden hier
## nooit aangeroepen — het "yes"-moment was een tekstvak
## (`docs/AUDIT-2026-09-05.md` deel 2, M2).
##
## 36 px is een bodem (`custom_minimum_size`), geen plafond: een deel van
## `data/minigame_content.json`'s "success"/"failure"-teksten loopt op tot
## 168 tekens en moet op meerdere regels kunnen wrappen in de footer, die als
## `VBoxContainer`-strook meegroeit. Een harde 36 px zou die tekst afsnijden —
## de footer zit hoe dan ook nooit óver `_scroll` (het speelveld), wat de
## eigenlijke eis is.
func finish_with_banner(ok: bool, text: String, score: int = 0, payload: Dictionary = {}) -> void:
	if _done:
		return

	var strook := chrome_footer()
	_banner = PanelContainer.new()
	_banner.custom_minimum_size = Vector2(0, 36)
	_banner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_banner.add_theme_stylebox_override("panel",
		UiKit.panel(UiKit.GROEN if ok else UiKit.ROOD, UiKit.INK, 2))
	_banner_label = UiKit.label(text, UiKit.FS_BODY, UiKit.INK)
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.add_child(_banner_label)

	if ok:
		add_child(UiKit.dimmer(0.35))
	strook.add_child(_banner)

	# De uitslag staat vast: geen enkele knop in deze minigame doet nog iets.
	for knop: Button in find_children("*", "Button", true, false):
		knop.disabled = true

	if ok:
		Juice.confetti(self, _banner.global_position + _banner.size * 0.5)
	else:
		Juice.schok()

	AudioDirector.play_ui(&"ticket_klaar" if ok else &"fout")
	# De banner is groen of rood, maar op een telefoon in de trein is het geluid
	# uit en zit het scherm halverwege achter een duim. De trilling draagt hier
	# dezelfde uitslag: lang voor gelukt, kort en hard voor mislukt.
	Haptiek.tril(Haptiek.Sterkte.GELUKT if ok else Haptiek.Sterkte.SLAG)
	# F5-a: `process_always = true` was hier nodig zolang de wereld gepauzeerd
	# stond terwijl deze minigame liep. Dat geldt sinds F5-a niet meer voor een
	# gewone speelbeurt, maar backgrounden pauzeert de tree nog altijd wél,
	# ongeacht of er een minigame loopt (zie `Shell._naar_achtergrond()`).
	# Blijft op `true` staan: dat is ook Godot's eigen standaard voor
	# `create_timer()`, en elke ongeflagde timer in `main.gd` gedraagt zich nu
	# al zo. Dit hier anders laten gedragen dan de rest van de codebase is geen
	# scope van F5 — zie dezelfde afweging bij `Shell._qa_shot()` en
	# `mg_oplevering.gd::_pauze()`.
	await get_tree().create_timer(1.9 if ok else 1.6, true).timeout
	if ok:
		succeed(score, payload)
	else:
		fail(score, payload)


func _unhandled_input(event: InputEvent) -> void:
	# P1.2: de eerste echte aanraking veegt de WAT-overlay weg, ongeacht of
	# de 2,5 s al om zijn. `mouse_filter = IGNORE` op de overlay zorgt dat
	# dezelfde tik ook het spel zelf bereikt.
	if _intro_overlay != null and (event is InputEventScreenTouch
			or event is InputEventMouseButton or event is InputEventKey):
		_weg_intro_overlay()
	if event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		abort()


## Inhoud uit data/minigame_content.json, per minigame-id.
##
## Gezet door `setup()` uit de configsleutel `inhoud`, en anders leeg. De enige
## aanroeper vandaag is `TraitModifier` via `TicketController`: die leest de
## inhoud uit het bestand, past het voordeel van je vakgebied toe en geeft het
## geheel terug. Leeg = het bestand, ongewijzigd.
var content_override: Dictionary = {}

## Titel uit data/minigames.json, zodat elke minigame automatisch de juiste kop krijgt.
func default_title() -> String:
	var m := GameData.minigames.get(minigame_id, {}) as Dictionary
	return String(m.get("title", "Opdracht"))


func content() -> Dictionary:
	return content_override if not content_override.is_empty() else MinigameContent.get_config(minigame_id)
