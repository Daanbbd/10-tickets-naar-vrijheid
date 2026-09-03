class_name Scrumbord
extends Control
## Het sprintbord: je voortgang als briefjes op een whiteboard.
##
## Vervangt de platte lijst. Tien tickets zijn tien post-its die van To do naar
## Doing naar Done schuiven, met de kleur van het vakgebied dat erbij hoort. Dat
## is waar het spel over gaat, dus het hoort er ook uit te zien.
##
## Twee ingangen, dezelfde opbouw: TAB overal om te kijken waar je stond, en
## het bord zelf, waar een nieuw briefje op landt.
##
## Sinds alle tickets tegelijk openstaan is dit je inventaris in plaats van een
## voortgangslijst. "Welke bestaan er" is geen informatie meer; "welke heb ik
## gevonden" wel. Dus staan hier alleen de briefjes die je bij je hebt, met
## eronder hoeveel er nog ergens op de vloer liggen — dat leest als een reden om
## te gaan kijken, waar negen geblokkeerde briefjes als negen weigeringen lazen.
##
## Een briefje aantikken kiest het: dat wordt je doel, en de doelregel, de hint
## en de wijzer in de wereld volgen mee.

const KOLOMMEN: Array[String] = ["BIJ JE", "OPGELOST"]


var _kolom: Array[VBoxContainer] = []
var _detail: RichTextLabel
var _titel: Label
var _sluit: Button
var _onder: Label


func bouw() -> void:
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

	_titel = UiKit.label("JOUW TICKETS", UiKit.FS_SUB, UiKit.INK)
	v.add_child(_titel)
	_onder = UiKit.label("", UiKit.FS_SMALL, UiKit.GRIJS_OP_LICHT)
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
		var k := UiKit.label(naam, UiKit.FS_SMALL, UiKit.GRIJS_OP_LICHT)
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

	# Een echte knop, geen regel met "TAB  sluiten" erin. Het bord vult het
	# scherm en scrollt, dus "tik ergens om te sluiten" kan niet: elke tik is
	# daar ook het begin van een veeg. Zelfde vorm als de Stoppen-knop in een
	# minigame, zodat "hier kom je weg" er overal eender uitziet.
	# Primair, want dit scherm is een keuze: het bord popte eerst zelf open bij
	# elk ticket dat je kreeg, en dan is "Sluiten" het enige wat er te doen is.
	# Nu open je het zelf om te kiezen, en dan hoort de knop te zeggen dat je
	# daarmee klaar bent. Het label volgt de keuze — zie `vul()`.
	_sluit = UiKit.knop_primair("Sluiten", UiKit.FS_SMALL)
	_sluit.focus_mode = Control.FOCUS_NONE
	v.add_child(_sluit)


func zet_sluitknop(bij_klik: Callable) -> void:
	if _sluit != null:
		_sluit.pressed.connect(bij_klik)


func vul() -> void:
	for kol: VBoxContainer in _kolom:
		for c: Node in kol.get_children():
			kol.remove_child(c)
			c.queue_free()

	var ids: Array[StringName] = GameData.ticket_ids()
	ids.sort_custom(func(a: StringName, b: StringName) -> bool:
		return GameData.ticket(a).order < GameData.ticket(b).order)

	# Alleen wat je gevonden of opgelost hebt. Wat je nog niet bent tegengekomen
	# hoort niet in een inventaris thuis; daarvoor is de regel eronder.
	var eerste: TicketDef = null
	for id: StringName in ids:
		if not (Session.is_discovered(id) or Session.is_done(id)):
			continue
		var t: TicketDef = GameData.ticket(id)
		var st: GameEnums.TicketState = Session.ticket_state(id)
		_kolom[_kolom_van(st)].add_child(_briefje(t, st))
		if st != GameEnums.TicketState.DONE and (eerste == null or Session.is_pinned(id)):
			eerste = t

	# `total_tickets()` en niet een hardgecodeerde 10, net als de HUD-teller.
	# Stond hier als "%d/10", en een elfde ticket maakte daarmee van het bord
	# een leugenaar en van de HUD niet.
	_titel.text = "JOUW TICKETS   %d/%d" % [Session.done_count(), Session.total_tickets()]
	_onder.text = _restregel()
	_onder.visible = true
	# Heb je iets vastgezet, dan is dit scherm af en gaat de dag verder. Zonder
	# keuze is het nog steeds gewoon dichtdoen.
	if _sluit != null:
		_sluit.text = "Aan de slag" if Session.pinned_ticket != &"" else "Sluiten"

	if eerste != null:
		toon_detail(eerste)
	elif Session.all_done():
		_detail.text = "[color=#%s]Alles opgelost. Ga naar de voordeur.[/color]" % UiKit.GROEN.to_html(false)
	else:
		_detail.text = "[color=#%s]Je hebt nog niets gevonden. Elk ticket ligt in de ruimte waar het hoort.[/color]" % UiKit.GRIJS_OP_LICHT.to_html(false)


## Hoeveel er nog liggen, en in de close-up ook waar je staat. Dit is de reden
## om het kantoor in te lopen, dus het staat direct onder de kop.
##
## `op slot` is het tweede onbekende getal: `undiscovered_count()` telt alleen
## wat al opengesteld is, dus zonder die tweede helft zei deze regel "Alles
## gevonden." terwijl er zes tickets achter ander werk wachtten.
func _restregel() -> String:
	var rest := QuestEngine.undiscovered_count()
	var op_slot := QuestEngine.locked_count()
	if Session.all_done():
		return "Klaar. Naar de voordeur."
	# Kort houden: op 192 px breed breekt een langere regel over twee regels en
	# duwt hij de briefjes uit beeld. Vandaar "wacht" en niet "wachten nog op
	# ander werk".
	if rest <= 0:
		if op_slot > 0:
			return "Alles gevonden. Nog %d wacht op ander werk." % op_slot
		return "Alles gevonden."
	var regel := "Nog %s op de vloer." % ("één" if rest == 1 else str(rest))
	if op_slot > 0:
		# "6 wacht nog" stond hier: het getal bepaalt het werkwoord, niet het
		# ticket. Eén wacht, meer wachten.
		regel += " %s nog." % ("één wacht" if op_slot == 1 else "%d wachten" % op_slot)
	return regel


static func _kolom_van(st: GameEnums.TicketState) -> int:
	return 1 if st == GameEnums.TicketState.DONE else 0


func _briefje(t: TicketDef, st: GameEnums.TicketState) -> Control:
	var p := PanelContainer.new()
	var kleur := papierkleur(t)
	if st == GameEnums.TicketState.DONE:
		# opgelost wijkt terug: die kolom is een archief, geen keuze
		kleur = kleur.lerp(UiKit.WIT, 0.45)
	# Het gekozen briefje krijgt een paarse rand. Dat wás de oranje van de
	# doelwijzer, maar oranje betekende toen ook overwerk en net-geboekte tijd,
	# en een kleur die vier dingen zegt zegt niets. Paars is hier bovendien de
	# enige tint die tegen álle vijf de papierkleuren afsteekt — geel, roze,
	# blauw, groen en oranje papier.
	var rand := UiKit.VASTGEZET if Session.is_pinned(t.id) else kleur.darkened(0.30)
	# Nog niet gezien: hetzelfde blauw als de ring op een object dat je nog nooit
	# hebt aangetikt, en als de badge op ▤ die je hierheen stuurde. Drie plekken,
	# één betekenis — "hier is iets nieuws" — en dus één kleur. Vastgezet wint,
	# want dat is een keuze en dit alleen nieuws.
	if not Session.is_pinned(t.id) and st != GameEnums.TicketState.DONE \
			and not Session.get_flag(QuestEngine.bord_gezien_vlag(t.id)):
		rand = UiKit.BLUEBIRD_BRIGHT
	p.add_theme_stylebox_override("panel", UiKit.postit(kleur, rand))
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.tooltip_text = t.title
	p.set_meta(&"ticket", t.id)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	p.add_child(v)

	var code := UiKit.label(t.code.replace("BBD-", ""), UiKit.FS_BODY, UiKit.INK)
	code.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(code)

	# Wie het moet doen is alleen nog nieuws zolang het niet gedaan is. Een
	# opgelost briefje blijft zo half zo hoog, en dan is de archiefkolom niet
	# langer luider dan je inventaris ernaast.
	var wie := "" if st == GameEnums.TicketState.DONE else _korte_eigenaar(t)
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
		_kies(t))
	p.add_child(knop)
	return p


## Een briefje aantikken kiest het. Dat is het hele punt van dit scherm: de
## doelregel, de hint en de wijzer in de wereld lezen alle drie uit die keuze.
## Nog een keer tikken laat hem weer los, voor als je toch wilt rondkijken.
func _kies(t: TicketDef) -> void:
	if Session.is_done(t.id):
		toon_detail(t)
		return
	if Session.is_pinned(t.id):
		Session.unpin()
	else:
		Session.pin(t.id)
	vul()
	toon_detail(t)


## Papierkleur uit de accentkleur van de eigenaar, niet uit zijn rol. Er zijn
## twee frontenders en twee backenders, dus op rol zouden vier briefjes twee
## kleuren delen en zegt de kleur niets meer. De accentkleur is per persoon
## uniek; verbleekt naar papier levert vanzelf een pastel post-it op.
## Publiek: `Hud.toon_ticket_melding()` gebruikt dezelfde papierkleur voor het
## briefje dat naar de ▤-knop vliegt, zodat het hetzelfde briefje is als het
## briefje dat straks op het bord ligt.
static func papierkleur(t: TicketDef) -> Color:
	if t.owner_character == &"":
		return UiKit.POSTIT                     # de gedeelde finale
	var c: CharacterDef = GameData.character(t.owner_character)
	if c == null:
		return UiKit.POSTIT
	return c.accent.lerp(UiKit.WIT, 0.62)


## Alleen de voornaam: op een briefje van 56 px past geen rol.
static func _korte_eigenaar(t: TicketDef) -> String:
	var d: NpcDef = GameData.npc(QuestEngine.required_helper(t.id))
	match QuestEngine.helper_stand(t.id):
		GameEnums.HelperStand.EIGEN:
			return "jij"
		GameEnums.HelperStand.MEE:
			# Zonder naam: het briefje trimt met ellipsis en zou "loopt mee"
			# als eerste opeten. Wie het is staat op de detailregel eronder.
			return "loopt mee"
		GameEnums.HelperStand.GEWEEST:
			return ""
		_:
			return d.name if d != null else t.owner_role


## Twee regels, meer niet: wat het is en waar je heen moet. De code staat al op
## het briefje, de paarse rand zegt al dat het gekozen is, en de hint staat
## achter de hintknop én wordt door de wijzer in de wereld aangewezen. Dat drie
## keer herhalen onder aan een telefoonscherm maakt er geen keuzescherm van maar
## een lap tekst waar niemand iets mee doet.
func toon_detail(t: TicketDef) -> void:
	var regels := "%s\n" % t.title
	if Session.is_done(t.id):
		regels += "[color=#%s]Opgelost.[/color]" % UiKit.GROEN.to_html(false)
	else:
		regels += "[color=#%s]%s  ·  %s[/color]" % [
			UiKit.GRIJS_OP_LICHT.to_html(false), t.zone_name, _volledige_eigenaar(t)]
	_detail.text = regels


static func _volledige_eigenaar(t: TicketDef) -> String:
	var d: NpcDef = GameData.npc(QuestEngine.required_helper(t.id))
	if d == null:
		return "jouw vakgebied" if QuestEngine.is_own_expertise(t.id) else t.owner_role
	match QuestEngine.helper_stand(t.id):
		GameEnums.HelperStand.EIGEN:
			return "jouw vakgebied"
		GameEnums.HelperStand.MEE:
			return "%s loopt met je mee" % d.name
		GameEnums.HelperStand.GEWEEST:
			return "%s is langs geweest" % d.name
		_:
			return "haal %s" % d.name


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
