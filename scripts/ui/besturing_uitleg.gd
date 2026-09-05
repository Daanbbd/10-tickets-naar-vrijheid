class_name BesturingUitleg
extends Control
## Hoe je dit spel bestuurt, op één scherm, tussen de personagekeuze en het
## spel zelf.
##
## Dit stond in de wereld: `Hud.show_controls_card()` werd aan het eind van
## `Main._intro_beat()` aangeroepen — dus ná de ochtendgroet, ná de wandeling
## naar het bord en ná twee briefjes die je zag landen. Je kreeg de uitleg over
## hóé je loopt op het moment dat je al een minuut gelopen had, als modaal
## venster over een spel dat al draaide. De vraag was één scherm, vóór de start,
## met één knop eronder.
##
## De kaart in de HUD blijft bestaan als naslag (F1, en `--kaart` voor QA), met
## dezelfde regels: `Hud.kaartregels()` leest `regels()` hieronder. Eén tekst,
## twee plekken.

const KOP := "ZO BESTUUR JE DIT"


## Wat er op dit apparaat te besturen valt.
##
## Losstaand van de UI-opbouw, om dezelfde reden als `IntroUitleg.lessen()`: de
## testsuite kan de tekst dan controleren zonder de scene te bouwen.
##
## **Deze regels noemen het apparaat waarop je speelt.** Dat is de enige plek in
## het spel waar dat mag: hier stond ooit alleen de duimversie, en op een laptop
## kreeg je dus instructies voor een duim die je niet hebt terwijl over WASD —
## waar de README mee opent — geen woord stond. De staande regel "nergens een
## toetsnaam" blijft overeind waar hij hoort: in `IntroUitleg` en in alle
## dialoog, die op beide apparaten dezelfde tekst tonen.
static func regels() -> Array[String]:
	if DisplayServer.is_touchscreen_available():
		return [
			"Duim rechts     lopen",
			"Ver uitduwen    rennen",
			"Tik op object   interactie",
			"?               hint",
			"☰               pauze, stoppen",
			"Ticketbord      bij het bord",
		]
	return [
		"WASD of pijltjes  lopen",
		"Shift             rennen",
		"E                 interactie",
		"Tab               ticketbord",
		"Q                 hint",
		"Esc of ☰          pauze, stoppen",
	]


func _ready() -> void:
	UiKit.full_rect(self)
	var bg := ColorRect.new()
	bg.color = UiKit.SCHERM_NACHT
	UiKit.full_rect(bg)
	add_child(bg)

	# Dezelfde kolomopbouw als `IntroUitleg`: gevuld van boven, knop tegen de
	# onderrand. Zo staat de knop op beide schermen op dezelfde plek, wat er ook
	# boven hangt — en de regels hieronder zijn per apparaat verschillend lang.
	var v := VBoxContainer.new()
	UiKit.full_rect(v)
	v.offset_left = 12; v.offset_right = -12
	v.offset_top = 16; v.offset_bottom = -12
	v.add_theme_constant_override("separation", 4)
	add_child(v)

	# Vijf korte regels op een scherm van 416 px hoog: bovenaan geplakt laat dat
	# tweederde leeg en leest het als een scherm dat nog niet af is. Rek boven én
	# onder zet het blok in het midden, met de knop nog steeds tegen de onderrand.
	v.add_child(_rek())
	v.add_child(UiKit.label(KOP, UiKit.FS_SMALL, UiKit.BLUEBIRD_BRIGHT))
	v.add_child(UiKit.spacer(4))
	# FS_SMALL en de autowrap van `UiKit.label()` blijft aan, allebei met reden.
	#
	# Deze regels lijnen hun tweede kolom met spaties uit, dus autowrap uitzetten
	# lijkt logisch. Dat is precies de valkuil uit docs/ARCHITECTURE.md: een
	# Label zonder autowrap meldt zijn volledige tekstbreedte als minimum, en een
	# kolom met GROW_DIRECTION_BOTH groeit daar aan béide kanten buiten beeld
	# voor. Op 192 px verloor dit scherm daardoor zijn linkermarge én het eind
	# van de langste regel.
	#
	# FS_SMALL houdt de langste regel binnen de 168 px die er zijn, zodat er
	# niets te breken valt. Dezelfde maat als de kaart in de HUD, die deze regels
	# al jaren op deze manier zet.
	for r: String in regels():
		v.add_child(UiKit.label(r, UiKit.FS_SMALL, UiKit.WIT))
		v.add_child(UiKit.spacer(3))

	v.add_child(_rek())

	var verder := UiKit.knop_primair("Begrepen", UiKit.FS_BODY)
	verder.pressed.connect(_on_verder)
	v.add_child(verder)
	verder.grab_focus()


## Lege ruimte die meegroeit. Twee ervan boven en onder een blok centreren het.
static func _rek() -> Control:
	var c := Control.new()
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _on_verder() -> void:
	AudioDirector.play_ui(&"klik")
	Shell.goto_game()
