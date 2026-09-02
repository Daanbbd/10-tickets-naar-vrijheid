class_name Hud
extends CanvasLayer
## Ticketteller, doelregel, interactieprompt, zonenaam, toasts, besturingskaart
## en ticketbord. Je tickets staan in het bord, niet permanent op het scherm.

## Portretcanvas: alles hangt aan de randen in plaats van aan vaste
## pixelposities uit de oude 480x270-indeling. De breedte van dat canvas staat
## nergens meer als getal — een rij die de volle breedte moet vullen zegt dat
## met ankers, en dan telt de viewport hem uit in plaats van deze constante.
const MARGE := 4

## Hoe ver de onderste stapel van de knoppenbalk af blijft.
const ONDERMARGE := 16

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

## De kompasstrip: de hele verdieping op één regel, één pixel per tegel.
##
## De camera toont twaalf tegels; de vloer is er vandaag 130 breed. Je kijkt dus
## naar 9% van het gebouw, en zonder iets dat de andere 91% laat zien is "Haal
## Victor uit De Vloer" een opdracht zonder richting: je weet wát, niet welke
## kant op en hoe ver.
##
## GAME_DESIGN.md wees een minimap af als "een plaatje van een lijn". Dat klopt,
## en daarom is dit er een: deze vloer *is* een lijn, veel breder dan hoog, dus
## de plattegrond past op één regel en er gaat niets verloren in de vertaling.
## Een strip die je eigen plek en je doel op ware schaal naast elkaar zet is geen
## tweede scherm — het is de doelregel met een afstand erbij.
##
## Het aantal tegels komt uit `floor.json` en niet uit een constante hier. De
## vloer wordt herontworpen, en een strip die dat niet meekrijgt liegt zonder
## te klagen: hij zou nog steeds 130 vakjes tekenen op een gebouw dat er 90
## heeft, en dan wijst hij je consequent te ver naar rechts.
class Kompas extends Control:
	const HOOGTE := 9

	var _tegels: int = 1
	## Linkerrand van elke ruimte, in tegels. Uitgelezen bij het bouwen: de
	## zones veranderen niet tijdens een speelbeurt en `_draw()` wel vaak.
	var _kamers: PackedInt32Array = PackedInt32Array()
	var _eigen: int = -1
	var _doel: int = -1

	func _init() -> void:
		custom_minimum_size = Vector2(0, HOOGTE)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tegels = maxi(1, Kompas.vloerbreedte())
		for z: Variant in (GameData.floor_data.get("zones", []) as Array):
			var r: Array = (z as Dictionary).get("rect", [])
			if r.size() == 4:
				_kamers.append(int(r[0]))

	## De breedte van de vloer in tegels, uit data/floor.json.
	##
	## `size` is de bron; de zones zijn het vangnet, want een vloer zonder `size`
	## laadt sowieso niet en dan is de verste zonerand nog steeds een beter
	## antwoord dan een getal dat hier is ingetypt.
	static func vloerbreedte() -> int:
		var maat: Variant = GameData.floor_data.get("size", null)
		if maat is Array and (maat as Array).size() >= 1:
			return int((maat as Array)[0])
		var breedste := 0
		for z: Variant in (GameData.floor_data.get("zones", []) as Array):
			var r: Array = (z as Dictionary).get("rect", [])
			if r.size() == 4:
				breedste = maxi(breedste, int(r[2]) + 1)
		return breedste

	## `doel` op -1 betekent "geen doel"; dan blijft alleen je eigen streepje over.
	func zet(eigen: int, doel: int) -> void:
		if eigen == _eigen and doel == _doel:
			return
		_eigen = eigen
		_doel = doel
		queue_redraw()

	func _draw() -> void:
		# Eén pixel per tegel, tenzij de vloer breder wordt dan het canvas — dan
		# krimpt de schaal mee in plaats van dat de strip buiten beeld loopt.
		var schaal := minf(1.0, size.x / float(_tegels))
		var breed := float(_tegels) * schaal
		var x0 := floorf((size.x - breed) * 0.5)
		var midden := floorf(size.y * 0.5)

		draw_rect(Rect2(x0, midden, breed, 1.0), UiKit.LINE)
		# De kamergrenzen maken er een plattegrond van in plaats van een liniaal:
		# je ziet dat je nog drie deuren van je doel af bent.
		for k: int in _kamers:
			draw_rect(Rect2(x0 + float(k) * schaal, midden - 1.0, 1.0, 3.0), UiKit.GRIJS)
		if _doel >= 0:
			_streepje(x0 + float(_doel) * schaal, UiKit.ORANJE, 3.0)
		if _eigen >= 0:
			_streepje(x0 + float(_eigen) * schaal, UiKit.WIT, 1.0)

	func _streepje(x: float, kleur: Color, breed: float) -> void:
		draw_rect(Rect2(floorf(x - breed * 0.5), 1.0, breed, size.y - 2.0), kleur)


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
var _bovenstapel: VBoxContainer = null
var _onderstapel: VBoxContainer = null
var _objective: PanelContainer
var _objective_label: Label
var _kompas: Kompas = null
var _zone: Label
var _zone_tween: Tween = null
var _toasts: VBoxContainer
## De hint blijft staan tot je hem weglegt, dus er kan er maar één zijn.
var _hint_briefje: PanelContainer = null
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
var _prompt_aan: bool = false


func setup() -> void:
	layer = 10
	# De doelwijzer in de wereld vraagt hier hoeveel scherm de HUD bezet. Via een
	# groep en niet via een verwijzing: de wijzer wordt aangemaakt en weggegooid
	# bij elke doelwissel, en die hoort niet te weten wie hem gemaakt heeft.
	add_to_group(&"hud")
	var root := UiKit.full_rect(Control.new())
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Alles wat aan een rand plakt hangt aan de veilige zone; het ticketbord
	# hangt bewust aan `root` omdat een overlay tot in de notch moet doorlopen.
	var veilig := UiKit.veilige_laag(root)

	_bouw_bovenstapel(veilig)
	_bouw_onderstapel(veilig)
	_bouw_plus(veilig)
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


## De bovenkant van het scherm is één stapel, geen vier losse panelen op geraden
## y-waarden.
##
## Dat waren er vier, en ze vielen over elkaar heen zodra een regel afbrak. De
## doelbalk begon op `MARGE + 18` = y22 terwijl de tellerbalk daaronder tot y30
## doorloopt, dus de doelregel lag standaard over de klok. De toasts begonnen op
## y46 terwijl de doelregel bij twee regels tot y76 komt — en twee regels is de
## normale toestand, niet de uitzondering: "Nu: BBD-204 · Haal Victor uit De
## Vloer" past niet op één regel van 184 px.
##
## Elk van die getallen klopte voor precies één tekstlengte. Een VBox telt ze op
## in plaats van ze te raden, en dan kan geen enkele rij nog over de vorige
## vallen, ongeacht hoe lang de tekst wordt of hoeveel toasts er staan.
func _bouw_bovenstapel(veilig: Control) -> void:
	var kolom := VBoxContainer.new()
	kolom.set_anchors_preset(Control.PRESET_TOP_WIDE)
	kolom.offset_left = MARGE
	kolom.offset_right = -MARGE
	kolom.offset_top = MARGE
	# Geen tussenruimte tussen de vaste balken. Met twee pixels ertussen kijk je
	# door de HUD heen op de wereld, en op de bovenste rij van het kantoor staan
	# de collega's: dan loopt er een reepje kruin en kapsel tussen de teller en
	# de doelregel door. Elke balk heeft zijn eigen rand, dus tegen elkaar aan
	# leest het als één stapel.
	kolom.add_theme_constant_override("separation", 0)
	kolom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veilig.add_child(kolom)
	_bovenstapel = kolom

	# --- ticketteller en klok ---
	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", UiKit.panel(UiKit.PANEL_DARK, UiKit.INK))
	kolom.add_child(top)
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
	kolom.add_child(_objective)
	_objective_label = UiKit.label("", UiKit.FS_SMALL, UiKit.WIT)
	_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective.add_child(_objective_label)

	# --- kompasstrip, direct onder de doelregel ---
	# De doelregel zegt wát en de strip zegt waar: dezelfde informatie, één
	# ruimtelijk in plaats van in woorden. Ze horen naast elkaar te staan.
	var kompaspaneel := PanelContainer.new()
	kompaspaneel.add_theme_stylebox_override("panel",
		UiKit.panel_krap(UiKit.PANEL_DARK, UiKit.INK))
	kolom.add_child(kompaspaneel)
	_kompas = Kompas.new()
	kompaspaneel.add_child(_kompas)

	# --- toasts, onder de doelregel en de strip ---
	_toasts = VBoxContainer.new()
	_toasts.add_theme_constant_override("separation", 2)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kolom.add_child(_toasts)


## "+45 min", drijft omhoog vlak onder de klok. Hangt bewust buiten de stapel:
## hij mag over de doelregel heen zweven en hij mag niets verschuiven.
func _bouw_plus(veilig: Control) -> void:
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


## De onderkant is om dezelfde reden één stapel, en groeit naar boven.
##
## De prompt was 18 px hoog gezet (`offset_top = -50`, `offset_bottom = -32`)
## terwijl een PanelContainer met een regel van 10 px en 6 px binnenmarge er 26
## nodig heeft. Bij `GROW_DIRECTION_END` — de standaard — komen die acht pixels
## er aan de onderkant bij, precies over de zonenaam die op y-30 begint. De
## zonenaam is de bevestiging dat je de goede ruimte binnenloopt, en die lag dus
## permanent onder het paneel dat vertelt waar je voor staat.
##
## Een VBox die van de onderrand naar boven groeit heeft dat probleem niet: de
## zonenaam staat vast onderaan en de prompt duwt zichzelf omhoog zo hoog als
## hij nodig heeft. Er valt niets meer te raden en niets meer te overlappen.
func _bouw_onderstapel(veilig: Control) -> void:
	var kolom := VBoxContainer.new()
	kolom.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	kolom.anchor_left = 0.5
	kolom.anchor_right = 0.5
	kolom.anchor_top = 1.0
	kolom.anchor_bottom = 1.0
	kolom.offset_left = -90
	kolom.offset_right = 90
	kolom.offset_top = -ONDERMARGE - DUIMZONE
	kolom.offset_bottom = -ONDERMARGE - DUIMZONE
	kolom.grow_horizontal = Control.GROW_DIRECTION_BOTH
	kolom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	kolom.add_theme_constant_override("separation", 2)
	kolom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veilig.add_child(kolom)
	_onderstapel = kolom

	# --- interactieprompt ---
	_prompt = PanelContainer.new()
	_prompt.add_theme_stylebox_override("panel", UiKit.panel(UiKit.PANEL, UiKit.INK))
	_prompt.visible = false
	kolom.add_child(_prompt)
	_prompt_label = UiKit.label("", UiKit.FS_SMALL)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_child(_prompt_label)

	# --- zonenaam, onderste regel boven de knoppenbalk ---
	# Faden via `modulate` en niet via `visible`: een regel die uit de stapel
	# verdwijnt laat de prompt erboven een paar pixels zakken, en dan verspringt
	# het ding waar de speler net naar wees.
	_zone = UiKit.label("", UiKit.FS_BODY, UiKit.WIT)
	_zone.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zone.autowrap_mode = TextServer.AUTOWRAP_OFF
	_zone.modulate.a = 0.0
	kolom.add_child(_zone)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_panel"):
		get_viewport().set_input_as_handled()
		toggle_controls_card()
		return
	# Esc/terug legt eerst de hint weg. Anders is de enige uitweg uit een briefje
	# dat blijft staan het aanraakscherm, en dat heeft een laptop niet.
	if _hint_briefje != null and event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		_leg_hint_weg()


# --- Besturingskaart -----------------------------------------------------

func _build_card(root: Control) -> void:
	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", UiKit.panel(UiKit.PANEL_DARK, UiKit.INK))
	# De kaart is een brede strook onderaan. Dat stond er als `offset_left =
	# -(192 - MARGE * 2)` bij een rechterrand op `-MARGE`, wat op precies één
	# canvasbreedte neerkomt op "vier pixels van links": een viewportmaat die in
	# code was uitgerekend in plaats van uit de viewport gehaald. Twee ankers
	# zeggen hetzelfde en blijven kloppen als het canvas verandert.
	_card.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_card.anchor_top = 1.0
	_card.anchor_bottom = 1.0
	_card.offset_left = MARGE
	_card.offset_right = -MARGE
	# Ook boven de duimzone: deze kaart legt juist die knoppen uit, dus hij
	# mag ze niet afdekken terwijl hij in beeld staat. Groeit naar boven, zodat
	# een vijfde regel de balk niet alsnog afdekt.
	_card.offset_top = -78 - DUIMZONE
	_card.offset_bottom = -MARGE - DUIMZONE
	_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
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
## linkerhelft opkomt, dat ver uitduwen rennen is, en dat je direct op een
## oplichtend object kunt tikken in plaats van er een knop voor te zoeken.
##
## Dit spel is mobile-only; er staat hier bewust geen toetsenregel meer. WASD/
## E/Tab/Q blijven in de InputMap staan als stille sneltoetsen zodat jij tijdens
## development nog met een toetsenbord kunt testen (zie `Invoer.muis_als_vinger()`
## voor hetzelfde idee met de muis), maar een speler ziet er nooit iets van —
## en een kaart die naar een toetsenbord verwijst hoort dus niet in een spel dat
## er geen heeft, ook al was die regel al onzichtbaar op een echt toestel.
func _kaartregels() -> Array[String]:
	return [
		"Duim links      lopen",
		"Ver uitduwen    rennen",
		"Tik op object   interactie",
		"▤ ticketbord    ? hint",
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
##
## Sinds `Klok` (F3-d) elke ~2,5s zelf een minuut boekt met reden `&"verloop"`,
## vuurt dit signaal continu tijdens gewoon rondlopen — niet alleen bij een
## opgelost ticket of een opgehaalde collega. Het "klik"-geluid en de "+1 min"
## popup zijn bedoeld voor die laatste, echte sprongen; op de ambient tik
## klinken ze non-stop zolang de speler beweegt. Vandaar de uitzondering.
func _on_time_booked(minuten: int, reden: StringName, totaal: int) -> void:
	if Autopilot.gevraagd():
		_klok_min = totaal
		_refresh_klok()
		_meld_overwerk(totaal)
		return
	if reden != &"verloop":
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
	# Wat je nog moet oprapen gaat vóór "je kunt dit zelf". Bij 9/10 vraagt de
	# deploycomputer om de deploysleutel, en die ligt in de plantenkast aan de
	# andere kant van de vloer: zonder deze regel zei de doelregel "Jij kunt dit
	# zelf" terwijl de wijzer naar De Vloer wees. Twee aanwijzingen die elkaar
	# tegenspreken, op het enige moment in de dag dat het erop aankomt.
	#
	# Zelfde zinsvorm als bij een collega hieronder ("Haal Victor uit De
	# Vloer"), dus de naam van het item gaat er onbewerkt in: een lidwoord
	# erbij verzinnen gaat mis op het eerste onzijdige item.
	var mist: ItemDef = QuestEngine.ontbrekend_item(t.id)
	if mist != null:
		var plek := _zone_naam(mist.zone)
		return "Haal %s%s" % [mist.name, "" if plek == "" else " uit %s" % plek]
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
		_objective_label.text = "Nu:  %s%s" % [t.code, _waarheen(t)]
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
	# `locked_count()` erbij, om dezelfde reden als op het bord: staat er niets
	# meer op de vloer maar wacht er nog werk achter ander werk, dan is "loop
	# een ruimte in" het verkeerde advies — er is dan niets te vinden, er is
	# iets af te maken.
	var rest := QuestEngine.undiscovered_count()
	var op_slot := QuestEngine.locked_count()
	if rest <= 0 and op_slot > 0:
		_objective_label.text = "Niets meer te vinden. %d wacht op ander werk." % op_slot
		return
	_objective_label.text = "Nog %d op de vloer. Loop een ruimte in." % rest


## De plaats en de opdracht, zonder de plaats twee keer.
##
## Dit was `"%s  ·  %s  ·  %s" % [code, zone_name, _wie(t)]`, en `_wie()` eindigt
## bij een op te halen collega al op "uit <ruimte>". Op BBD-204 leverde dat op:
##
##     Nu:  BBD-204  ·  De Vloer  ·  Haal Victor uit De Vloer
##
## Drie stukken tekst voor twee feiten, over twee regels op een canvas van 184
## px, met de zone precies één woord voor de tweede vermelding ervan. De regel
## die vertelt waar je moet beginnen is dan zelf een klein leesraadsel.
##
## Alleen ontdubbelen als het echt dezelfde ruimte is: staat de collega ergens
## anders dan het ticket, dan zijn het twee plekken en horen ze er allebei te
## staan — je moet er immers ook allebei langs.
static func _waarheen(t: TicketDef) -> String:
	var wie := _wie(t)
	if t.zone_name == "" or wie.contains(t.zone_name):
		return "  ·  %s" % wie
	return "  ·  %s  ·  %s" % [t.zone_name, wie]


## Wie dit ticket bezit hoort zichtbaar te zijn vóór de interactie, niet pas
## nadat de speler er vergeefs op E heeft gedrukt.
func _on_prompt(text: String, shown: bool, world_id: StringName, _verb: String) -> void:
	_prompt_tekst = text
	_prompt_aan = shown
	_prompt_world = world_id
	_teken_prompt()


## Er is geen actieknop meer die het werkwoord draagt — je tikt direct op het
## object. Deze prompt is dus de enige plek die nog zegt wát een tik doet, dus
## hij toont weer de volledige tekst inclusief werkwoord ("Praten met Victor"
## i.p.v. alleen "Victor").
func _teken_prompt() -> void:
	_prompt.visible = _prompt_aan and not Session.input_locked
	_prompt_label.text = "%s%s" % [_prompt_tekst, _eigenaar_suffix(_prompt_world)]


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


## Hoe lang een gewone toast in beeld blijft.
const TOAST_ZICHTBAAR := 2.6


func _on_toast(text: String, icon: StringName) -> void:
	# Een hint is geen mededeling maar een instructie, en die leest niet op een
	# klok. Tijdens een geautomatiseerde speelbeurt wél: die tikt niets weg en
	# zou achter een briefje blijven staan dat op niemand wacht.
	if icon == &"hint" and not Autopilot.gevraagd():
		_toon_hint(text)
		return
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.panel(UiKit.PANEL_DARK, UiKit.INK))
	var l := UiKit.label(text, UiKit.FS_SMALL, UiKit.WIT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.add_child(l)
	_toasts.add_child(p)
	var tw := create_tween()
	tw.tween_interval(TOAST_ZICHTBAAR)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)


## De hint blijft staan tot je hem weglegt, precies zoals de telefoon dat doet.
##
## De langste hint is die van BBD-210: 184 tekens, die op dit canvas over zes
## regels vallen. Die stond 2,6 seconden in beeld — zeventig tekens per seconde,
## ongeveer drie keer zo snel als iemand kan lezen. En hij verscheen op het
## moment dat je vastzat, dus precies wanneer je hem het rustigst wilt lezen.
##
## Anders dan de telefoon zet dit briefje de invoer níet op slot: de telefoon
## onderbreekt je dag, de hint helpt je erdoorheen. Je moet ermee kunnen
## doorlopen. Daarom vangt het paneel zijn eigen tik op in plaats van elke tik
## op het scherm af te vangen — de duim in de linkerhelft blijft gewoon lopen.
func _toon_hint(text: String) -> void:
	_leg_hint_weg()

	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.panel(UiKit.PANEL_DARK, UiKit.ORANJE))
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	p.add_child(v)
	var l := UiKit.label(text, UiKit.FS_SMALL, UiKit.WIT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	var voet := UiKit.label("tik om weg te leggen", UiKit.FS_SMALL, UiKit.GRIJS_OP_DONKER)
	voet.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(voet)

	p.gui_input.connect(func(e: InputEvent) -> void:
		var raak := e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed
		raak = raak or (e is InputEventMouseButton and (e as InputEventMouseButton).pressed)
		if raak:
			p.accept_event()
			_leg_hint_weg())

	_toasts.add_child(p)
	# Bovenaan de stapel: het briefje blijft staan en de losse toasts schuiven
	# eronder langs, in plaats van het per vondst een regel lager te duwen.
	_toasts.move_child(p, 0)
	_hint_briefje = p


func _leg_hint_weg() -> void:
	if _hint_briefje == null:
		return
	if is_instance_valid(_hint_briefje):
		AudioDirector.play_ui(&"klik")
		_hint_briefje.queue_free()
	_hint_briefje = null


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


## De verticale band die vrij is van HUD-chrome, in canvaspixels: x is de
## onderkant van de bovenste stapel, y de bovenkant van de onderste.
##
## De doelwijzer klemt zich hierbinnen als hij tegen een schermrand hangt.
## Zonder dit schuift hij bij een doel in de noordelijke strook — waar de helft
## van het kantoor ligt — recht achter de ticketteller: de pijl is er dan wel en
## je ziet hem niet, wat precies de fout is die hij kwam oplossen.
##
## Gemeten en niet geteld, want de doelregel is één of twee regels hoog en er
## kunnen toasts onder hangen. Een getal dat dat probeert te voorspellen is het
## soort getal dat deze HUD net kwijt is.
func vrije_band() -> Vector2:
	var hoog := get_viewport().get_visible_rect().size.y
	var boven := 0.0
	if _bovenstapel != null:
		boven = _bovenstapel.global_position.y + _bovenstapel.size.y
	var onder := hoog
	if _onderstapel != null:
		onder = _onderstapel.global_position.y
	return Vector2(boven, minf(onder, hoog - DUIMZONE))


## De kompasstrip toont alleen. Welk ticket het doel is bepaalt
## `QuestEngine.next_hint_ticket()`, en welk object daarbij hoort weet `main.gd`
## — dat plaatst de wijzer in de wereld toch al. De HUD mag daar niet zelf
## achteraan gaan zoeken, want dan zijn er twee antwoorden op dezelfde vraag.
##
## `doel_tegel` op -1 betekent "geen doel"; dan blijft alleen je eigen plek over.
func zet_kompas(eigen_tegel: int, doel_tegel: int) -> void:
	if _kompas != null:
		_kompas.zet(eigen_tegel, doel_tegel)


## Niemand hoort langer dan 45 seconden vast te zitten. Dit leert bovendien
## wat Q doet, door het een keer voor te doen.
func _on_nudge() -> void:
	if Session.input_locked or Shell.minigame_active():
		_nudge.start()
		return
	Bus.hint_requested.emit()
