class_name IntroUitleg
extends Control
## Het scherm tussen titel en personagekeuze dat de premisse uitlegt: tickets
## liggen verspreid, er zijn er tien, het bord is waar je kiest, en niet-eigen
## werk vraagt om een collega.
##
## Dit verving de zes dialoognodes die vroeger bij het spawnen speelden. Die
## kwamen te laat: op de personagekeuze staat de ticketbalk en "twee tickets
## zelf" al vóór iemand ook maar wist dát er tickets bestonden om zelf te
## kunnen doen. Nu staat de uitleg vóór die keuze, niet erna.
##
## Eén statisch scherm, geen wizard: vier korte regels, één knop.

## Losstaand van de UI-opbouw, zodat _test_intro() in test_runner.gd dezelfde
## tekst controleert als wat er op het scherm staat, zonder de scene te hoeven
## bouwen of instantiëren.
const LESSEN: Array[String] = [
	"Tien tickets, verspreid door het kantoor. Vind ze door rond te lopen.",
	"Zijn ze alle tien opgelost, dan mag je naar buiten.",
	"Negen staan meteen open. Op het ticketbord kies je wat je oppakt.",
	"Niet jouw vak? Haal er een collega bij.",
]


func _ready() -> void:
	UiKit.full_rect(self)
	var bg := ColorRect.new()
	bg.color = UiKit.SCHERM_NACHT
	UiKit.full_rect(bg)
	add_child(bg)

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.anchor_left = 0.5; v.anchor_right = 0.5
	v.anchor_top = 0.5; v.anchor_bottom = 0.5
	v.offset_left = -80; v.offset_right = 80
	v.offset_top = -110; v.offset_bottom = 110
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 6)
	add_child(v)

	var kop := UiKit.label("HOE DIT WERKT", UiKit.FS_HEAD, UiKit.BLUEBIRD_BRIGHT)
	kop.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(kop)

	v.add_child(UiKit.spacer(8))

	for les: String in LESSEN:
		var l := UiKit.label(les, UiKit.FS_SMALL, UiKit.WIT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
		v.add_child(UiKit.spacer(4))

	v.add_child(UiKit.spacer(6))

	var verder := UiKit.knop_primair("Begrepen", UiKit.FS_BODY)
	verder.pressed.connect(_on_verder)
	v.add_child(verder)

	verder.grab_focus()


func _on_verder() -> void:
	AudioDirector.play_ui(&"klik")
	Shell.goto_character_select()
