extends MinigameBase
## De urenstaat van Dirk (`mg_urenstaat`), en verder niets: elk ander ticket
## heeft inmiddels zijn eigen mechaniek.
##
## Er is geen goed antwoord. Elke regel neemt elk uurblok, een regel neemt er
## meer dan een, en je slaagt zodra alles verdeeld is. Wat je koos komt in
## MinigameResult.payload terecht, en daar reageert Dirk op. Geen fouten, alleen
## een keuze die genoteerd wordt.
##
## De regels van echt werk komen niet uit de data maar uit
## `Session.completed_tickets_in_order()`; de data levert alleen de posten die
## niet aan een ticket hangen.

# Portret: 192 px breed met 4 px chrome-marge laat ~176 px over. Twee
# kaarten naast elkaar past, drie niet.
const CARD_W := 84
const CARD_H := 22


class DragCard extends PanelContainer:
	var card_id: String = ""
	var text: String = ""
	var tint: Color = UiKit.PANEL
	var board: Node = null

	func _init(id: String, t: String, col: Color, b: Node,
			w: int = CARD_W, h: int = CARD_H) -> void:
		card_id = id
		text = t
		tint = col
		board = b
		custom_minimum_size = Vector2(w, h)
		mouse_filter = Control.MOUSE_FILTER_STOP
		add_theme_stylebox_override("panel", UiKit.postit())
		var l := UiKit.label(t, UiKit.FS_SMALL, UiKit.INK)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(l)

	func _get_drag_data(_pos: Vector2) -> Variant:
		var ghost := PanelContainer.new()
		ghost.add_theme_stylebox_override("panel", UiKit.postit(UiKit.POSTIT.lightened(0.12), UiKit.BLUEBIRD_INK))
		ghost.custom_minimum_size = Vector2(CARD_W, CARD_H)
		var gl := UiKit.label(text, UiKit.FS_SMALL, UiKit.INK)
		gl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ghost.add_child(gl)
		set_drag_preview(ghost)
		AudioDirector.play_ui(&"pak")
		return {"card_id": card_id, "node": self}

	## Tikken is de hoofdinteractie, slepen blijft bestaan voor wie het probeert.
	## Op een telefoon is er geen enkele aanwijzing dat je iets kunt slepen, dus
	## kiezen-en-plaatsen moet ook zonder sleepgebaar werken.
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed \
				and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			board.call(&"tik_kaart", self)

	func toon_opgepakt(aan: bool) -> void:
		add_theme_stylebox_override("panel", UiKit.postit(
			UiKit.POSTIT.lightened(0.18) if aan else UiKit.POSTIT,
			UiKit.BLUEBIRD_INK if aan else UiKit.POSTIT_RAND))


class DropSlot extends PanelContainer:
	var slot_label: String = ""
	var slot_id: String = ""
	var holder: HBoxContainer = null
	var board: Node = null
	## Hoeveel uurblokken er op deze regel passen.
	var cap: int = 1

	func _init(lbl: String, b: Node, capaciteit: int = 1, id: String = "") -> void:
		slot_label = lbl
		board = b
		cap = maxi(1, capaciteit)
		slot_id = id if id != "" else lbl
		add_theme_stylebox_override("panel", UiKit.postit(UiKit.POSTIT_LEEG, UiKit.POSTIT_LEEG_RAND))

		# Een urenstaat leest als regels, niet als vakken: naam links, de uren
		# die je erop schrijft rechts, over de volle breedte.
		custom_minimum_size = Vector2(0, 24)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 2)
		add_child(h)
		var rl := UiKit.label(lbl, UiKit.FS_SMALL, UiKit.GRIJS)
		rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(rl)
		holder = HBoxContainer.new()
		holder.custom_minimum_size = Vector2(76, 16)
		holder.alignment = BoxContainer.ALIGNMENT_END
		holder.add_theme_constant_override("separation", 1)
		h.add_child(holder)

	func is_filled() -> bool:
		return holder.get_child_count() >= cap

	func heeft_kaart() -> bool:
		return holder.get_child_count() > 0

	## De laatst neergelegde kaart. Bij capaciteit 1 is dat de enige.
	func card() -> DragCard:
		return holder.get_child(holder.get_child_count() - 1) as DragCard if heeft_kaart() else null

	func aantal() -> int:
		return holder.get_child_count()

	func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
		return data is Dictionary and (data as Dictionary).has("card_id") and not is_filled()

	func _drop_data(_pos: Vector2, data: Variant) -> void:
		board.call(&"place_card", (data as Dictionary)["node"], self)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed \
				and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			board.call(&"tik_vak", self)


var _opgepakt: DragCard = null
var _slots: Array[DropSlot] = []
var _pool: HFlowContainer = null
## Wat een kaart aan minuten waard is.
var _blok_min: int = 60


func _on_setup() -> void:
	var c := content()
	if c.is_empty():
		fail()
		return

	_blok_min = int(c.get("blok_min", 60))
	var body := build_chrome(String(c.get("titel", default_title())), String(c.get("intro", "")))

	var slot_row := VBoxContainer.new()
	slot_row.add_theme_constant_override("separation", 2)
	body.add_child(slot_row)

	# De urenstaat begint met het werk dat je vandaag echt gedaan hebt. Dat is
	# per speelbeurt anders, dus die regels kunnen niet uit de data komen.
	var cap := int(c.get("capaciteit", 1))
	for tid: StringName in Session.completed_tickets_in_order():
		var t: TicketDef = GameData.ticket(tid)
		if t == null:
			continue
		var ts := DropSlot.new(t.code, self, cap, String(tid))
		slot_row.add_child(ts)
		_slots.append(ts)

	for raw: Variant in c.get("slots", []):
		var sd := raw as Dictionary
		var s := DropSlot.new(String(sd.get("label", "")), self, cap, String(sd.get("id", "")))
		slot_row.add_child(s)
		_slots.append(s)

	body.add_child(UiKit.label(
		String(c.get("uitleg", "Tik een uur aan en tik dan de regel waar het op moet.")),
		UiKit.FS_SMALL, UiKit.GRIJS))

	_pool = HFlowContainer.new()
	_pool.add_theme_constant_override("h_separation", 3)
	_pool.add_theme_constant_override("v_separation", 3)
	_pool.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_pool)

	# De kaarten zijn acht identieke uurblokken; die horen klein en naast
	# elkaar, niet als acht regels van 84 px onder elkaar.
	var kw := int(c.get("kaart_breedte", CARD_W))
	var kh := int(c.get("kaart_hoogte", CARD_H))
	for raw: Variant in c.get("cards", []):
		var cd := raw as Dictionary
		_pool.add_child(DragCard.new(String(cd.get("id", "")), String(cd.get("text", "")),
			UiKit.PANEL, self, kw, kh))

	var check := UiKit.knop_primair(String(c.get("knop", "Controleren")), UiKit.FS_BODY)
	check.pressed.connect(_check)
	body.add_child(check)

	_update_status()


# --- Sleepacties (aangeroepen door de inner classes) ----------------------

## Tik op een kaart: oppakken, weer neerleggen, of terughalen uit een vak.
func tik_kaart(c: DragCard) -> void:
	if c.get_parent() != _pool:          # kaart ligt in een vak
		_leg_neer()
		return_card(c)
		return
	if _opgepakt == c:
		_leg_neer()
		return
	_leg_neer()
	_opgepakt = c
	c.toon_opgepakt(true)
	AudioDirector.play_ui(&"pak")
	_update_status()


## Tik op een vak: de opgepakte kaart erin, of de kaart die er al ligt eruit.
func tik_vak(s: DropSlot) -> void:
	# Vol? Dan haalt een tik de bovenste kaart terug. Zit er nog ruimte in en
	# heb je niets opgepakt, dan ook — anders kun je een halfvolle urenregel
	# niet meer corrigeren.
	if s.is_filled() or (_opgepakt == null and s.heeft_kaart()):
		var c := s.card()
		_leg_neer()
		return_card(c)
		return
	if _opgepakt == null:
		return
	var c2 := _opgepakt
	_leg_neer()
	place_card(c2, s)


func _leg_neer() -> void:
	if _opgepakt != null:
		_opgepakt.toon_opgepakt(false)
		_opgepakt = null


func place_card(card: DragCard, slot: DropSlot) -> void:
	if slot.is_filled():
		return
	card.get_parent().remove_child(card)
	slot.holder.add_child(card)
	AudioDirector.play_ui(&"klik")
	_update_status()


func return_card(card: DragCard) -> void:
	if card.get_parent() == _pool:
		return
	card.get_parent().remove_child(card)
	_pool.add_child(card)
	AudioDirector.play_ui(&"klik")
	_update_status()


func _update_status() -> void:
	set_status("geboekt %s van %s" % [
		Urenstaat.formatteer_duur(_geboekt_min()),
		Urenstaat.formatteer_duur(_te_verdelen_min())])


func _geboekt_min() -> int:
	var n := 0
	for s: DropSlot in _slots:
		n += s.aantal()
	return n * _blok_min


## Alles bij elkaar: wat er al op de staat staat plus wat er nog los ligt.
func _te_verdelen_min() -> int:
	return _geboekt_min() + _pool.get_child_count() * _blok_min


# --- Nakijken -------------------------------------------------------------

## Geen goed antwoord: je slaagt zodra alles verdeeld is. Wat je koos gaat mee
## in de payload, zodat Dirk erop kan reageren zonder dat de minigame Session
## aanraakt (die mag hij alleen lezen).
func _check() -> void:
	var c := content()
	var los := _pool.get_child_count()
	if los > 0:
		set_status("Er is nog %s niet verdeeld." % Urenstaat.formatteer_duur(los * _blok_min))
		AudioDirector.play_ui(&"fout")
		return

	var verdeling := {}
	var op_echt_werk := 0
	var op_rest := 0
	for s: DropSlot in _slots:
		if s.aantal() == 0:
			continue
		verdeling[s.slot_id] = s.aantal() * _blok_min
		if s.slot_id.begins_with("t"):
			op_echt_werk += s.aantal() * _blok_min
		else:
			op_rest += s.aantal() * _blok_min

	# Hoeveel regels echt werk je op nul hebt laten staan. Dat is waar Dirk
	# een vraagteken bij zet.
	var leeg := 0
	for s: DropSlot in _slots:
		if s.slot_id.begins_with("t") and s.aantal() == 0:
			leeg += 1

	await finish_with_banner(true, String(c.get("success", "Geboekt.")), _geboekt_min(), {
		"verdeling": verdeling,
		"op_echt_werk": op_echt_werk,
		"op_rest": op_rest,
		"lege_tickets": leeg,
		"geboekt_min": _geboekt_min(),
	})


## QA: verdeelt alle uren en dient de staat in. Langs de echte winroute — de
## eerste regel die nog ruimte heeft — precies wat een speler ook moet doen.
func qa_solve() -> void:
	for n: Node in _pool.get_children().duplicate():
		var kaart := n as DragCard
		if kaart == null:
			continue
		for s: DropSlot in _slots:
			if not s.is_filled():
				place_card(kaart, s)
				break
	_check()
