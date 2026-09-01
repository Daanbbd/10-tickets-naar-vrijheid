class_name Scrumbord
extends Control
## Het sprintbord: je voortgang als briefjes op een whiteboard.
##
## Vervangt de platte lijst. Tien tickets zijn tien post-its die van To do naar
## Doing naar Done schuiven, met de kleur van het vakgebied dat erbij hoort. Dat
## is waar het spel over gaat, dus het hoort er ook uit te zien.
##
## Twee gedaantes, dezelfde opbouw:
##   TAB overal        -> compact, om even te kijken waar je stond
##   het bord zelf     -> close-up, met de landingsanimatie van een nieuw briefje
##
## Kolommen zijn de bestaande TicketState. LOCKED en AVAILABLE staan allebei in
## To do, want dat is waar ze op een echt bord ook hangen; geblokkeerd is
## vervaagd in plaats van weggelaten. Negen geredigeerde regels lezen als negen
## weigeringen, en dat was al een bewuste keuze van dit bord.

const KOLOMMEN: Array[String] = ["TO DO", "DOING", "DONE"]


var _kolom: Array[VBoxContainer] = []
var _detail: RichTextLabel
var _titel: Label
var _inventaris: Label
var _sluit: Label
var _onder: Label
var _close_up: bool = false


func zet_close_up(aan: bool) -> void:
	_close_up = aan
	if _onder != null:
		_onder.visible = aan


func bouw(close_up: bool = false) -> void:
	_close_up = close_up
	var paneel := PanelContainer.new()
	paneel.add_theme_stylebox_override("panel", UiKit.panel(UiKit.WIT, UiKit.LINE))
	UiKit.full_rect(paneel)
	paneel.offset_left = 4
	paneel.offset_right = -4
	paneel.offset_top = 4
	paneel.offset_bottom = -4
	add_child(paneel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	paneel.add_child(v)

	_titel = UiKit.label("SPRINTBORD", UiKit.FS_BODY, UiKit.INK)
	v.add_child(_titel)
	_onder = UiKit.label("Je staat er met je neus bovenop.", UiKit.FS_SMALL, UiKit.GRIJS)
	_onder.visible = close_up
	v.add_child(_onder)

	# de markerstreep onder de kop: het is een whiteboard, geen dialoogvenster
	var streep := ColorRect.new()
	streep.color = UiKit.BLUEBIRD_INK
	streep.custom_minimum_size = Vector2(0, 1)
	v.add_child(streep)

	var koppen := HBoxContainer.new()
	koppen.add_theme_constant_override("separation", 2)
	v.add_child(koppen)
	for naam: String in KOLOMMEN:
		var k := UiKit.label(naam, UiKit.FS_SMALL, UiKit.GRIJS)
		k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		koppen.add_child(k)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)

	var rij := HBoxContainer.new()
	rij.add_theme_constant_override("separation", 2)
	rij.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rij)
	for i: int in KOLOMMEN.size():
		var baan := PanelContainer.new()
		baan.add_theme_stylebox_override("panel",
			UiKit.panel(UiKit.WIT.darkened(0.03), UiKit.NEUTRAAL_TINT))
		baan.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		baan.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		rij.add_child(baan)
		var kol := VBoxContainer.new()
		kol.add_theme_constant_override("separation", 2)
		kol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		baan.add_child(kol)
		_kolom.append(kol)

	_detail = UiKit.rich(UiKit.FS_SMALL, UiKit.INK)
	_detail.fit_content = true
	_detail.custom_minimum_size = Vector2(0, 34)
	v.add_child(_detail)

	# Wat je bij je hebt hoort hier en niet permanent in beeld: het is iets wat
	# je opzoekt, geen statusregel.
	_inventaris = UiKit.label("", UiKit.FS_SMALL, UiKit.GRIJS)
	v.add_child(_inventaris)

	_sluit = UiKit.label("", UiKit.FS_SMALL, UiKit.GRIJS)
	_sluit.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(_sluit)


func toon_sluitregel(regel: String) -> void:
	if _sluit != null:
		_sluit.text = regel


func toon_inventaris(regel: String) -> void:
	if _inventaris != null:
		_inventaris.text = regel


func vul() -> void:
	for kol: VBoxContainer in _kolom:
		for c: Node in kol.get_children():
			kol.remove_child(c)
			c.queue_free()

	var ids: Array[StringName] = GameData.ticket_ids()
	ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return GameData.ticket(a).order < GameData.ticket(b).order)

	var eerste: TicketDef = null
	for id: StringName in ids:
		var t: TicketDef = GameData.ticket(id)
		var st: GameEnums.TicketState = Session.ticket_state(id)
		_kolom[_kolom_van(st)].add_child(_briefje(t, st))
		if eerste == null and st == GameEnums.TicketState.AVAILABLE:
			eerste = t

	_titel.text = "SPRINTBORD   %d/10" % Session.done_count()
	if eerste != null:
		toon_detail(eerste)
	else:
		_detail.text = "[color=#%s]Tik een briefje aan.[/color]" % UiKit.GRIJS.to_html(false)


static func _kolom_van(st: GameEnums.TicketState) -> int:
	match st:
		GameEnums.TicketState.ACTIVE: return 1
		GameEnums.TicketState.DONE: return 2
		_: return 0        # LOCKED en AVAILABLE hangen allebei in To do


func _briefje(t: TicketDef, st: GameEnums.TicketState) -> Control:
	var p := PanelContainer.new()
	var kleur := _papier(t)
	if st == GameEnums.TicketState.LOCKED:
		# geblokkeerd blijft leesbaar maar wijkt terug, zodat de kolom vertelt
		# waar je nu iets mee kunt
		kleur = kleur.lerp(UiKit.WIT, 0.55)
	p.add_theme_stylebox_override("panel", UiKit.postit(kleur, kleur.darkened(0.30)))
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.tooltip_text = t.title
	p.set_meta(&"ticket", t.id)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	p.add_child(v)

	var code := UiKit.label(t.code.replace("BBD-", ""), UiKit.FS_BODY, UiKit.INK)
	code.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(code)

	var wie := _korte_eigenaar(t)
	if wie != "":
		var w := UiKit.label(wie, UiKit.FS_SMALL, UiKit.INK.lightened(0.35))
		w.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		# een naam hoort af te kappen, niet af te breken: "Jonath / an" over twee
		# regels maakt de briefjes ongelijk hoog en leest als een fout
		w.autowrap_mode = TextServer.AUTOWRAP_OFF
		w.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		w.clip_text = true
		v.add_child(w)

	if st == GameEnums.TicketState.DONE:
		var vink := UiKit.label("klaar", UiKit.FS_SMALL, UiKit.GROEN.darkened(0.2))
		vink.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(vink)

	var knop := Button.new()
	knop.flat = true
	UiKit.full_rect(knop)
	knop.pressed.connect(func() -> void:
		AudioDirector.play_ui(&"klik")
		toon_detail(t))
	p.add_child(knop)
	return p


## Papierkleur uit de accentkleur van de eigenaar, niet uit zijn rol. Er zijn
## twee frontenders en twee backenders, dus op rol zouden vier briefjes twee
## kleuren delen en zegt de kleur niets meer. De accentkleur is per persoon
## uniek; verbleekt naar papier levert vanzelf een pastel post-it op.
static func _papier(t: TicketDef) -> Color:
	if t.owner_character == &"":
		return UiKit.POSTIT                     # de gedeelde finale
	var c: CharacterDef = GameData.character(t.owner_character)
	if c == null:
		return UiKit.POSTIT
	return c.accent.lerp(UiKit.WIT, 0.62)


## Alleen de voornaam: op een briefje van 56 px past geen rol.
static func _korte_eigenaar(t: TicketDef) -> String:
	if QuestEngine.is_own_expertise(t.id):
		return "jij"
	var d: NpcDef = GameData.npc(QuestEngine.required_helper(t.id))
	return d.name if d != null else t.owner_role


func toon_detail(t: TicketDef) -> void:
	var st: GameEnums.TicketState = Session.ticket_state(t.id)
	var regels := "[color=#%s]%s[/color]  %s\n" % [
		UiKit.BLUEBIRD_INK.to_html(false), t.code, t.title]
	if st == GameEnums.TicketState.DONE:
		regels += "[color=#%s]Opgelost.[/color]" % UiKit.GROEN.to_html(false)
	elif st == GameEnums.TicketState.LOCKED:
		regels += "[color=#%s]Nog niet aan de beurt.[/color]" % UiKit.GRIJS.to_html(false)
	else:
		regels += "[color=#%s]%s  ·  %s[/color]\n%s" % [
			UiKit.GRIJS.to_html(false), t.zone_name, _volledige_eigenaar(t), t.hint]
	_detail.text = regels


static func _volledige_eigenaar(t: TicketDef) -> String:
	if QuestEngine.is_own_expertise(t.id):
		return "jouw vakgebied"
	var d: NpcDef = GameData.npc(QuestEngine.required_helper(t.id))
	return "haal %s" % d.name if d != null else t.owner_role


## Een nieuw briefje landt op het bord. Dit is de enige plek waar voortgang
## een gebaar is in plaats van een getal, dus het mag even duren. Overslaan
## kan met een tik, want dit gebeurt tien keer per speelbeurt.
func laat_briefje_landen(t: TicketDef) -> void:
	var doel := _zoek_briefje(t)
	if doel == null:
		return
	toon_detail(t)
	var eind := doel.position
	doel.position = eind + Vector2(0, -26)
	doel.modulate.a = 0.0
	doel.pivot_offset = doel.size * 0.5
	doel.rotation = deg_to_rad(-8.0)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(doel, "position", eind, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(doel, "modulate:a", 1.0, 0.18)
	tw.tween_property(doel, "rotation", 0.0, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	AudioDirector.play_ui(&"pak")


func _zoek_briefje(t: TicketDef) -> Control:
	for kol: VBoxContainer in _kolom:
		for c: Node in kol.get_children():
			var p := c as Control
			if p != null and p.has_meta(&"ticket") and StringName(p.get_meta(&"ticket")) == t.id:
				return p
	return null
