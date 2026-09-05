class_name MinigameIntro
extends Control
## Het scherm tussen de briefing van de eigenaar en de minigame zelf: wat de
## opgave is en waarom ze ertoe doet, met één knop.
##
## Geen personage, geen portret — dat onderscheid is het hele punt. Vlak
## hiervoor kan de eigenaar van het ticket iets over zijn eigen ticket gezegd
## hebben, met naam en portret in de `DialogueBox` (`Briefing`/
## `TicketController._briefing()`). Zonder een duidelijke breuk daarna leest
## de speler de eerstvolgende tekst als een voortzetting van diezelfde
## uitspraak — ook als die tekst over iemand anders gaat (bv. Dennis, tijdens
## de stand-up) en dus helemaal niet in Daans mond past. Dit scherm is die
## breuk: geen collega die praat, maar het spel dat de regels uitlegt.
##
## Verschijnt daarom met dezelfde ondergrond en hetzelfde kader als
## `MinigameBase.build_chrome()` — dit scherm en de minigame die erop volgt
## horen zichtbaar bij elkaar — maar zonder enige DialogueBox-conventie
## (geen naam, geen portret, geen post-it-stijl).
##
## Verschijnt alleen de eerste keer per minigame-id per speelbeurt
## (`gezien_vlag()`, hetzelfde patroon als `Storingen.gevuurd_vlag()`), en
## nooit tijdens een geautomatiseerde speelbeurt (`Autopilot.gevraagd()`) —
## zelfde vroege-return-idioom als de hint-toast in `hud.gd`.

signal besloten(doorgegaan: bool)


## P1: dit scherm blijft alleen bestaan voor de finale. De andere tien
## minigames kregen hun WAT-regel terug als overlay ín het veld
## (`MinigameBase.build_chrome()`), niet meer als apart scherm ervoor — dat
## halveerde de tekstlaag vóór het spel (`docs/AUDIT-2026-09-05.md` deel 2,
## M1/P1). `mg_deploy` heeft geen eigenaar en geen briefer die hem aankondigt
## (de dialoogbox blijft dus leeg), en is het enige moment waar de speler
## bewust "Starten" drukt vóór de climax van het spel — die drempel verdient
## hij, de andere tien niet.
const INTRO_KAART_VOOR: StringName = &"mg_deploy"


static func gezien_vlag(id: StringName) -> StringName:
	return StringName("mg_intro_gezien_%s" % id)


## Of `Shell.run_minigame()` dit scherm voor `id` moet tonen.
static func moet_getoond(id: StringName) -> bool:
	return id == INTRO_KAART_VOOR \
		and not Autopilot.gevraagd() and not Session.get_flag(gezien_vlag(id))


## Aangeroepen na add_child, zelfde volgorde-contract als
## `MinigameBase.setup()`: @onready-refs bestaan dan al, hier niet van
## toepassing omdat dit scherm zichzelf volledig in code opbouwt.
##
## `inhoud_override` is dezelfde `config["inhoud"]` die straks ook naar de
## minigame gaat (een trait kan de opgave aanpassen) — zo lezen "Wat" en
## "Waarom" hier exact de cijfers die de minigame ook gaat draaien.
func setup(minigame_id: StringName, inhoud_override: Dictionary) -> void:
	# Zelfde vindbaarheid als MinigameBase (`add_to_group(&"minigame")` in
	# `_ready()`): de testsuite en eventuele andere systemen kunnen dit scherm
	# zo opzoeken zonder in Shell's interne `_minigame_layer` te graven.
	add_to_group(&"minigame_intro")
	var titel := String((GameData.minigames.get(minigame_id, {}) as Dictionary)
		.get("title", "Opdracht"))
	var c: Dictionary = inhoud_override if not inhoud_override.is_empty() \
		else MinigameContent.get_config(minigame_id)
	var wat := Briefing.vul(String(c.get("intro", "")), c)
	var waarom := Briefing.vul(String(c.get("waarom", "")), c)
	_bouw(titel, wat, waarom)


func _bouw(titel: String, wat: String, waarom: String) -> void:
	# `fill_viewport` en niet `full_rect`: dit scherm hangt onder Shells
	# `MinigameLayer`, en een Control onder een CanvasLayer krijgt geen
	# ouderrect. Met alleen ankers bleef dit scherm 0x0, en omdat `full_rect`
	# ook `GROW_DIRECTION_BOTH` zet groeide het kader vanuit de oorsprong naar
	# twee kanten: de kaart hing linksboven half buiten beeld, met WAT en
	# WAAROM volledig onzichtbaar en "Starten" nauwelijks aan te tikken.
	UiKit.fill_viewport(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(UiKit.dimmer(0.72))

	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UiKit.panel(UiKit.SCHERM_NACHT, UiKit.LINE))
	UiKit.full_rect(frame)
	frame.offset_left = 4; frame.offset_right = -4
	frame.offset_top = 4; frame.offset_bottom = -4
	add_child(frame)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	frame.add_child(col)

	var t := UiKit.label(titel, UiKit.FS_HEAD, UiKit.BLUEBIRD_BRIGHT)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(t)
	col.add_child(UiKit.spacer(4))

	# Scroll, net als build_chrome(): op 192x416 past "Wat" plus "Waarom" van
	# een langere opgave (bv. de oplevering) lang niet altijd zonder te scrollen.
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)

	if wat != "":
		body.add_child(_sectie("WAT", wat))
	if waarom != "":
		body.add_child(_sectie("WAAROM", waarom))

	col.add_child(UiKit.spacer(4))

	var starten := UiKit.knop_primair("Starten", UiKit.FS_BODY)
	starten.pressed.connect(func() -> void:
		AudioDirector.play_ui(&"klik")
		besloten.emit(true))
	col.add_child(starten)

	# Esc bestaat niet op een telefoon, dus ook hier een knop naast de
	# sneltoets — zelfde afweging als "Stoppen" in build_chrome(). Anders dan
	# daar is dit geen opgeven van de minigame (die is nog niet eens begonnen),
	# dus "Terug" in plaats van "Stoppen".
	var terug := UiKit.button("Terug", UiKit.FS_SMALL)
	terug.focus_mode = Control.FOCUS_NONE
	terug.pressed.connect(_terug)
	col.add_child(terug)

	starten.grab_focus()


static func _sectie(kop: String, tekst: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	v.add_child(UiKit.label(kop, UiKit.FS_SMALL, UiKit.GRIJS_OP_DONKER))
	var l := UiKit.label(tekst, UiKit.FS_BODY, UiKit.WIT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	return v


func _terug() -> void:
	AudioDirector.play_ui(&"klik")
	besloten.emit(false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		_terug()
