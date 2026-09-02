class_name Hud
extends CanvasLayer
## Ticketteller, doelregel, interactieprompt, zonenaam, toasts, besturingskaart
## en ticketbord. Je tickets staan in het bord, niet permanent op het scherm.

## Portretcanvas van 192 px breed: alles hangt aan de randen in plaats van
## aan vaste pixelposities uit de oude 480x270-indeling.
const MARGE := 4

## Hoe lang een nieuw briefje in beeld blijft. Dit gebeurt tien keer per
## speelbeurt, dus het mag nooit in de weg gaan zitten.
const BRIEFJE_ZICHTBAAR := 1.4

const NUDGE_NA := 45.0          ## seconden zonder voortgang voor een gratis hint

## Hoe lang de klok vooruitrolt na een opgelost ticket. Dit is de sleutelbeat
## van de urenstaat: je ziet je dag korter worden.
const ROL_DUUR := 0.6
## Kleine stilte na de rol, zodat de dialoog er niet bovenop valt.
const NA_ROL := 0.15
## Hoe lang "+45 min" blijft staan terwijl hij omhoog drijft.
const PLUS_DUUR := 0.9
const KAART_ZICHTBAAR := 9.0

## Hoe ver de onderste HUD-regels omhoog moeten. De knoppenbalk staat daar, en
## alles wat eronder blijft hangen wordt door een hand afgedekt op precies het
## moment dat je het nodig hebt — de prompt zegt immers wat er gebeurt als je
## die knop indrukt.
##
## Uit `Besturing` en niet zelf geteld: de balk bepaalt zijn eigen hoogte uit
## de duimmaat, en twee plekken die hetzelfde getal raden lopen uit elkaar.
const DUIMZONE := Besturing.BALK_RUIMTE

var _prompt: PanelContainer
var _prompt_label: Label
var _counter: Label
var _klok: Label
var _plus: Label
## De minuten die de klok nu TOONT. Loopt tijdens de rol achter op
## Session.worked_minutes; dat verschil is precies de animatie.
var _klok_min: int = 0
var _rol: Tween = null
var _plus_tween: Tween = null
var _plus_top: float = 0.0
var _overwerk_gemeld: bool = false
var _objective: PanelContainer
var _objective_label: Label
var _zone: Label
var _zone_tween: Tween = null
var _toasts: VBoxContainer
var _board: Control
var _bord: Scrumbord
var _card: PanelContainer
var _card_tween: Tween = null
var _nudge: Timer

## De laatste promptargumenten. InteractionProbe stuurt alleen een signaal als
## het dichtstbijzijnde object verandert; sluit er iemand aan terwijl je
## stilstaat, dan zou de suffix zonder deze cache verouderd blijven staan.
var _prompt_tekst: String = ""
var _prompt_world: StringName = &""
var _prompt_verb: String = ""
var _prompt_aan: bool = false


func setup() -> void:
	layer = 10
	var root := UiKit.full_rect(Control.new())
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Alles wat aan een rand plakt hangt aan de veilige zone; het ticketbord
	# hangt bewust aan `root` omdat een overlay tot in de notch moet doorlopen.
	var veilig := UiKit.veilige_laag(root)

	# --- ticketteller linksboven ---
	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", UiKit.panel(UiKit.PANEL_DARK, UiKit.INK))
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = MARGE
	top.offset_right = -MARGE
	top.offset_top = MARGE
	veilig.add_child(top)
	# Teller links, klok rechts. Een PanelContainer legt alle kinderen in
	# hetzelfde rect, dus dit moet via een HBox.
	var top_rij := HBoxContainer.new()
	top.add_child(top_rij)
	# Beide bewust zonder autowrap: UiKit.label() zet die standaard aan, en in een
	# HBox krijgt een afbrekend Label een minimumbreedte van ongeveer één teken.
	# De klok werd daardoor verticaal afgebroken tot "0 9 : 0 0", wat de balk vijf
	# regels hoog maakte en over de doelregel heen duwde.
	_counter = UiKit.label("", UiKit.FS_BODY, UiKit.WIT)
	_counter.autowrap_mode = TextServer.AUTOWRAP_OFF
	_counter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_rij.add_child(_counter)
	_klok = UiKit.label("", UiKit.FS_BODY, UiKit.WIT)
	_klok.autowrap_mode = TextServer.AUTOWRAP_OFF
	_klok.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_rij.add_child(_klok)

	# "+45 min", drijft omhoog vlak onder de klok. Hangt los van de balk zodat
	# hij eroverheen kan zweven.
	_plus = UiKit.label("", UiKit.FS_SMALL, UiKit.GEBOEKT)
	_plus.autowrap_mode = TextServer.AUTOWRAP_OFF
	_plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_plus.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_plus.anchor_left = 1.0
	_plus.offset_left = -70
	_plus.offset_right = -MARGE - 2
	_plus_top = MARGE + 16
	_plus.offset_top = _plus_top
	_plus.offset_bottom = _plus_top + 12
	_plus.modulate.a = 0.0
	_plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veilig.add_child(_plus)

	# --- doelregel, direct onder de teller, permanent zichtbaar ---
	# Dit is het antwoord op "ik weet niet waar ik moet beginnen": er staat
	# altijd precies een doel op het scherm, ook als de DAG er twee openzet.
	_objective = PanelContainer.new()
	# Dekkend, niet half-doorzichtig. Het stond op 80% zodat je de bovenrand van
	# de wereld nog zag, maar daar lopen collega's langs: hun kleding schijnt er
	# in gedempte vlekken door en dan staat "Daan is langs geweest" in wit op een
	# lapjesdeken. Dit is de regel die antwoord geeft op "waar begin ik", dus
	# leesbaarheid gaat hier vóór doorkijk — dezelfde afweging als de dekkende
	# balk erboven.
	_objective.add_theme_stylebox_override("panel",
		UiKit.panel(UiKit.PANEL_DARK, UiKit.ORANJE))
	_objective.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_objective.offset_left = MARGE
	_objective.offset_right = -MARGE
	_objective.offset_top = MARGE + 18
	veilig.add_child(_objective)
	_objective_label = UiKit.label("", UiKit.FS_SMALL, UiKit.WIT)
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective.add_child(_objective_label)

	# --- zonenaam onderaan ---
	_zone = UiKit.label("", UiKit.FS_BODY, UiKit.WIT)
	_zone.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_zone.anchor_left = 0.5
	_zone.anchor_right = 0.5
	_zone.anchor_top = 1.0
	_zone.anchor_bottom = 1.0
	_zone.offset_top = -30 - DUIMZONE
	_zone.offset_bottom = -16 - DUIMZONE
	_zone.offset_left = -90
	_zone.offset_right = 90
	_zone.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zone.modulate.a = 0.0
	veilig.add_child(_zone)

	# --- interactieprompt ---
	_prompt = PanelContainer.new()
	_prompt.add_theme_stylebox_override("panel", UiKit.panel(UiKit.PANEL, UiKit.INK))
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.anchor_left = 0.5
	_prompt.anchor_right = 0.5
	_prompt.anchor_top = 1.0
	_prompt.anchor_bottom = 1.0
	_prompt.offset_top = -50 - DUIMZONE
	_prompt.offset_bottom = -32 - DUIMZONE
	_prompt.offset_left = -90
	_prompt.offset_right = 90
	_prompt.visible = false
	veilig.add_child(_prompt)
	_prompt_label = UiKit.label("", UiKit.FS_SMALL)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_child(_prompt_label)

	# --- toasts rechtsboven ---
	_toasts = VBoxContainer.new()
	_toasts.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_toasts.anchor_left = 1.0
	_toasts.anchor_right = 1.0
	_toasts.offset_left = -(192 - MARGE * 2)
	_toasts.offset_right = -MARGE
	_toasts.offset_top = 46
	_toasts.alignment = BoxContainer.ALIGNMENT_END
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veilig.add_child(_toasts)

	_build_card(veilig)
	_build_board(root)

	_nudge = Timer.new()
	_nudge.one_shot = true
	_nudge.wait_time = NUDGE_NA
	_nudge.timeout.connect(_on_nudge)
	add_child(_nudge)
	_nudge.start()

	Bus.interaction_prompt_changed.connect(_on_prompt)
	Bus.ticket_state_changed.connect(func(_a: StringName, _b: GameEnums.TicketState) -> void: _refresh())
	Bus.ticket_completed.connect(func(_a: StringName, _b: MinigameResult) -> void: _refresh())
	Bus.ticket_discovered.connect(func(_a: StringName) -> void: _refresh())
	Bus.ticket_pinned.connect(func(_a: StringName) -> void: _refresh())
	Bus.item_added.connect(func(_a: StringName, _b: int) -> void: _refresh())
	Bus.item_removed.connect(func(_a: StringName, _b: int) -> void: _refresh())
	Bus.time_booked.connect(_on_time_booked)
	Bus.toast_requested.connect(_on_toast)
	Bus.zone_entered.connect(_on_zone)
	Bus.hint_requested.connect(_on_hint)
	Bus.input_lock_changed.connect(_on_input_lock)
	Bus.follower_joined.connect(func(_a: StringName) -> void: _volgers_veranderd())
	Bus.follower_released.connect(func(_a: StringName) -> void: _volgers_veranderd())

	_klok_min = Session.worked_minutes
	_overwerk_gemeld = Urenstaat.is_overwerk()
	_refresh_klok()
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_panel"):
		get_viewport().set_input_as_handled()
		toggle_controls_card()


# --- Besturingskaart -----------------------------------------------------

func _build_card(root: Control) -> void:
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", UiKit.panel(UiKit.PANEL_DARK, UiKit.INK))
	_card.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_card.anchor_left = 1.0
	_card.anchor_top = 1.0
	_card.anchor_right = 1.0
	_card.anchor_bottom = 1.0
	_card.offset_left = -(192 - MARGE * 2)
	# Ook boven de duimzone: deze kaart legt juist die knoppen uit, dus hij
	# mag ze niet afdekken terwijl hij in beeld staat.
	_card.offset_top = -78 - DUIMZONE
	_card.offset_right = -MARGE
	_card.offset_bottom = -MARGE - DUIMZONE
	_card.modulate.a = 0.0
	_card.visible = false
	root.add_child(_card)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	_card.add_child(v)
	for regel: String in _kaartregels():
		v.add_child(UiKit.label(regel, UiKit.FS_SMALL, UiKit.WIT))


## Eén kaart, en die noemt alleen wat je niet kunt zien.
##
## De knoppenbalk staat in beeld met zijn werkwoord erop, dus die hoeft niet
## uitgelegd te worden. Wat onzichtbaar is: dat de stick overal in de
## linkerhelft opkomt, en dat ver uitduwen rennen is. De toetsen staan op één
## regel onderaan omdat ze precies dat zijn — een snellere weg naar dezelfde
## knoppen, niet een tweede besturing.
func _kaartregels() -> Array[String]:
	return [
		"Duim links      lopen",
		"Ver uitduwen    rennen",
		"▤ ticketbord    ? hint",
		"Toetsen  WASD Shift E Tab Q",
	]


## Laat de kaart even zien en fade hem daarna weg. F1 haalt hem terug.
func show_controls_card(duur: float = KAART_ZICHTBAAR) -> void:
	if _card_tween != null and _card_tween.is_running():
		_card_tween.kill()
	_card.visible = true
	_card_tween = create_tween()
	_card_tween.tween_property(_card, "modulate:a", 1.0, 0.25)
	_card_tween.tween_interval(duur)
	_card_tween.tween_property(_card, "modulate:a", 0.0, 0.6)
	_card_tween.tween_callback(func() -> void: _card.visible = false)


func toggle_controls_card() -> void:
	if _card.visible and _card.modulate.a > 0.5:
		if _card_tween != null and _card_tween.is_running():
			_card_tween.kill()
		_card_tween = create_tween()
		_card_tween.tween_property(_card, "modulate:a", 0.0, 0.2)
		_card_tween.tween_callback(func() -> void: _card.visible = false)
	else:
		show_controls_card(20.0)
	AudioDirector.play_ui(&"klik")


# --- Ticketbord -----------------------------------------------------------

func _build_board(root: Control) -> void:
	_board = UiKit.full_rect(Control.new())
	_board.visible = false
	_board.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_board)
	_board.add_child(UiKit.dimmer(0.78))

	_bord = Scrumbord.new()
	UiKit.full_rect(_bord)
	_bord.bouw()
	_board.add_child(_bord)

	_bord.zet_sluitknop(func() -> void: toggle_board())


func toggle_board(close_up: bool = false) -> void:
	_board.visible = not _board.visible
	AudioDirector.play_ui(&"klik")
	if _board.visible:
		_fill_board()


## Het bord openen en een net gevonden briefje zien landen. Dit is wat een
## ticket vinden tot een moment maakt in plaats van een regel in een lijst.
##
## `duur` is instelbaar zodat het allereerste briefje (het intro-nabeat, waar
## dit ook het "haal een collega"-voorbeeld moet laten zien) langer mag blijven
## staan dan de tien routineuze vondsten erna.
func toon_nieuw_briefje(t: TicketDef, duur: float = BRIEFJE_ZICHTBAAR) -> void:
	# Tijdens een geautomatiseerde speelbeurt niets tonen: die drukt geen toets
	# in om weg te klikken en zou hier blijven hangen.
	if t == null or _board.visible or Autopilot.gevraagd():
		return
	_board.visible = true
	_fill_board()
	_bord.laat_briefje_landen(t)
	await get_tree().create_timer(duur, true, false, true).timeout
	_board.visible = false


# --- De urenstaat ---------------------------------------------------------

## De klok, en na vijven in de overwerkkleur. Los van _refresh() gehouden — zie daar.
func _refresh_klok() -> void:
	if _klok == null:
		return
	_klok.text = Urenstaat.formatteer(Urenstaat.START_MIN + _klok_min)
	_klok.add_theme_color_override("font_color",
		UiKit.OVERWERK if _klok_min >= Urenstaat.BUDGET_MIN else UiKit.WIT)


## De boeking is de trigger van de rol, niet het opgeloste ticket: anders staat
## de nieuwe tijd er al voordat de animatie begint.
func _on_time_booked(minuten: int, _reden: StringName, totaal: int) -> void:
	if Autopilot.gevraagd():
		_klok_min = totaal
		_refresh_klok()
		_meld_overwerk(totaal)
		return
	_toon_plus(minuten)
	AudioDirector.play_ui(&"klik")
	_rol_naar(totaal)
	_meld_overwerk(totaal)


## Eén keer per speelbeurt: het moment dat je acht uur op zijn. Er gaat niets
## dicht — er staat alleen iets anders op het scherm.
func _meld_overwerk(totaal: int) -> void:
	if _overwerk_gemeld or totaal < Urenstaat.BUDGET_MIN:
		return
	_overwerk_gemeld = true
	Bus.toast_requested.emit("%s. Je acht uur zijn op." %
		Urenstaat.formatteer(Urenstaat.START_MIN + Urenstaat.BUDGET_MIN), &"tijd")


## Een Label.text is niet te tween_property'en, dus tween_method op een float en
## in de callback formatteren.
func _rol_naar(doel: int) -> void:
	if _rol != null and _rol.is_valid():
		_rol.kill()
	_rol = create_tween()
	_rol.tween_method(
		func(v: float) -> void:
			_klok_min = int(round(v))
			_refresh_klok(),
		float(_klok_min), float(doel), ROL_DUUR)


func _toon_plus(minuten: int) -> void:
	if _plus == null or minuten <= 0:
		return
	if _plus_tween != null and _plus_tween.is_valid():
		_plus_tween.kill()
	_plus.text = "+%s" % Urenstaat.formatteer_duur(minuten)
	_plus.modulate.a = 1.0
	_plus_tween = create_tween().set_parallel(true)
	# offset_top/bottom samen, want een geankerd Control heeft geen vrije positie.
	_plus_tween.tween_method(
		func(v: float) -> void:
			_plus.offset_top = v
			_plus.offset_bottom = v + 12.0,
		_plus_top, _plus_top - 10.0, PLUS_DUUR)
	_plus_tween.tween_property(_plus, "modulate:a", 0.0, PLUS_DUUR)


## Wachten tot de klok stilstaat. De aanroeper await hierop zodat de
## complete-dialoog pas komt als je je uren hebt zien weglopen.
##
## Zelf niets animeren: dat doet _on_time_booked al op het signaal. Deze functie
## is alleen de wachter, anders zouden er twee dingen dezelfde tween starten.
func toon_urenrol() -> void:
	if Autopilot.gevraagd():
		return
	if _rol != null and _rol.is_valid() and _rol.is_running():
		await _rol.finished
	await get_tree().create_timer(NA_ROL, true, false, true).timeout


func _fill_board() -> void:
	if _bord != null:
		_bord.vul()


## "Jij kunt dit zelf" of de naam van de collega die je moet ophalen — met de
## ruimte waar hij staat, want de werkelijke kosten van ophalen zijn zoektijd.
static func _wie(t: TicketDef) -> String:
	var stand := QuestEngine.helper_stand(t.id)
	if stand == GameEnums.HelperStand.EIGEN:
		return "Jij kunt dit zelf"
	var d: NpcDef = GameData.npc(QuestEngine.required_helper(t.id))
	if d == null:
		return "Vraag: %s" % t.owner_role
	match stand:
		GameEnums.HelperStand.MEE:
			return "%s loopt mee" % d.name
		GameEnums.HelperStand.GEWEEST:
			return "%s is langs geweest" % d.name
		_:
			var waar := _zone_naam(d.zone)
			return "Haal %s%s" % [d.name, "" if waar == "" else " uit %s" % waar]


static func _zone_naam(zone_id: StringName) -> String:
	if zone_id == &"":
		return ""
	for z: Variant in (GameData.floor_data.get("zones", []) as Array):
		var d := z as Dictionary
		if StringName(d.get("id", "")) == zone_id:
			return String(d.get("name", ""))
	return ""


# --- Reacties -------------------------------------------------------------

func _refresh() -> void:
	# De klok staat hier bewust niet in: _refresh() hangt aan ticket_completed
	# en zou de cijfers al doen springen voordat de rol begint. En hij herstart
	# de hintnudge, wat een kop koffie niet mag doen. Zie _refresh_klok().
	_counter.text = "Tickets  %d/%d" % [Session.done_count(), Session.total_tickets()]
	_refresh_objective()
	if _board.visible:
		_fill_board()
	if _nudge != null:
		_nudge.start()


## Drie gedaanten, want er is niet meer één juiste volgorde.
##
## Heb je gekozen, dan staat je keuze er. Heb je niet gekozen maar wel werk bij
## je, dan zegt de regel hoeveel je kunt kiezen en waar dat gebeurt — dat is de
## uitnodiging, niet een opdracht. Heb je nog niets gevonden, dan stuurt hij je
## het kantoor in.
func _refresh_objective() -> void:
	if Session.all_done():
		_objective_label.text = "Nu:  alles is opgelost — ga naar de voordeur"
		return

	if Session.pinned_ticket != &"" and Session.is_available(Session.pinned_ticket):
		var t: TicketDef = GameData.ticket(Session.pinned_ticket)
		_objective_label.text = "Nu:  %s  ·  %s  ·  %s" % [t.code, t.zone_name, _wie(t)]
		return

	var bij_je := QuestEngine.inventory_tickets().size()
	if bij_je > 0:
		_objective_label.text = "%d ticket%s open  ·  %s om te kiezen" % [
			bij_je, "" if bij_je == 1 else "s", "▤"]
		return

	# Vóór dit een getal noemde, was "loop rond" de enige aanwijzing dat
	# binnenlopen iets oplevert. Hetzelfde getal als de lege bordtekst
	# (undiscovered_count, niet done_count), zodat HUD en bord elkaar niet
	# tegenspreken.
	var rest := QuestEngine.undiscovered_count()
	_objective_label.text = "Nog %d op de vloer. Loop een ruimte in." % rest


## Wie dit ticket bezit hoort zichtbaar te zijn vóór de interactie, niet pas
## nadat de speler er vergeefs op E heeft gedrukt.
func _on_prompt(text: String, shown: bool, world_id: StringName, verb: String) -> void:
	_prompt_tekst = text
	_prompt_aan = shown
	_prompt_world = world_id
	_prompt_verb = verb
	_teken_prompt()


## Het werkwoord staat op de actieknop in de balk, dus de prompt houdt over
## waar je voor staat en wie daar iets mee kan. Hier stond eerder "E  praten
## met Victor": dat verwees naar een toets die op de helft van de apparaten
## niet bestaat, en het zei het werkwoord twee keer.
func _teken_prompt() -> void:
	_prompt.visible = _prompt_aan and not Session.input_locked
	var rest := _prompt_tekst.substr(_prompt_verb.length()).strip_edges()
	_prompt_label.text = "%s%s" % [rest if rest != "" else _prompt_verb,
		_eigenaar_suffix(_prompt_world)]


## Sluit er iemand aan of loopt hij weg, dan verandert de doelregel, het bord én
## de prompt. De prompt hangt niet aan een ticketsignaal, dus die moet apart.
func _volgers_veranderd() -> void:
	_refresh()
	_teken_prompt()


## Vóór de interactie zichtbaar maken dat je iemand nodig hebt; loopt hij al
## mee, dan bevestigen; is hij geweest, dan is er niets meer te melden.
static func _eigenaar_suffix(world_id: StringName) -> String:
	var t: TicketDef = QuestEngine.preferred_at_anchor(world_id)
	if t == null:
		return ""
	var d: NpcDef = GameData.npc(QuestEngine.required_helper(t.id))
	var naam := d.name if d != null else t.owner_role
	match QuestEngine.helper_stand(t.id):
		GameEnums.HelperStand.MEE:
			return " (met %s)" % naam
		GameEnums.HelperStand.NODIG:
			return " (%s)" % naam
		_:
			return ""


## De dialoogbox (layer 20) dekt de prompt en de zonenaam (layer 10) af. Verberg
## ze dus zolang de input op slot staat, in plaats van ze eronder te laten staan.
func _on_input_lock(locked: bool) -> void:
	if locked:
		_prompt.visible = false
		_zone.modulate.a = 0.0


func _on_toast(text: String, _icon: StringName) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.panel(UiKit.PANEL_DARK, UiKit.INK))
	var l := UiKit.label(text, UiKit.FS_SMALL, UiKit.WIT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.add_child(l)
	_toasts.add_child(p)
	var tw := create_tween()
	tw.tween_interval(2.6)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)


## Kill-before-recreate: langs een deuropening lopen hertriggert zone_entered op
## elke tile-overgang, en stapelende tweens vechten om dezelfde alpha.
func _on_zone(_id: StringName, zone_name: String) -> void:
	_zone.text = zone_name
	if _zone_tween != null and _zone_tween.is_running():
		_zone_tween.kill()
	_zone_tween = create_tween()
	_zone_tween.tween_property(_zone, "modulate:a", 1.0, 0.25)
	_zone_tween.tween_interval(1.6)
	_zone_tween.tween_property(_zone, "modulate:a", 0.0, 0.6)


func _on_hint() -> void:
	if _nudge != null:
		_nudge.start()
	var t: TicketDef = QuestEngine.next_hint_ticket()
	if t == null:
		Bus.toast_requested.emit("Alles is opgelost. Ga naar de voordeur.", &"hint")
		return
	# Wijst de hint naar iets wat je nog niet gevonden hebt, dan is het een
	# richting en geen ticket: noem de plek, niet de code.
	if not Session.is_discovered(t.id):
		Bus.toast_requested.emit("Er ligt nog werk in %s. %s" % [t.zone_name, t.hint], &"hint")
		return
	# De hint zelf hoort erbij: die stond alleen op het TAB-bord.
	Bus.toast_requested.emit("%s — %s. %s %s" % [t.code, t.zone_name, _wie(t) + ".", t.hint], &"hint")


## Niemand hoort langer dan 45 seconden vast te zitten. Dit leert bovendien
## wat Q doet, door het een keer voor te doen.
func _on_nudge() -> void:
	if Session.input_locked or Shell.minigame_active():
		_nudge.start()
		return
	Bus.hint_requested.emit()
