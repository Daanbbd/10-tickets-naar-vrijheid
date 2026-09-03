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
## Getallen in woorden, zodat regel 3 dezelfde typografie heeft als "Tien
## tickets" in regel 1 en er geen cijfer tussen de woorden staat.
const TELWOORDEN: Array[String] = [
	"Geen", "Eén", "Twee", "Drie", "Vier", "Vijf",
	"Zes", "Zeven", "Acht", "Negen", "Tien",
]


## Hoeveel tickets er bij het begin van de dag openstaan: die zonder
## `available_when`. `QuestEngine.start_run()` zet precies die op open, de rest
## begint LOCKED en komt via de keten vrij.
static func open_bij_start() -> int:
	var n := 0
	for id: StringName in GameData.ticket_ids():
		var t: TicketDef = GameData.ticket(id)
		if t != null and t.available_when.is_empty():
			n += 1
	return n


## Waar de dag over gaat. Twee regels, vóór de spelregels.
##
## Dit ontbrak volledig. Het uitlegscherm vertelde hoe je tickets vindt en
## afvinkt, maar nergens stond wát er die dag gebouwd wordt — en dan is het
## eerste ticket "de klant heeft feedback" op een product waar je nog nooit van
## gehoord hebt. Elke grap in dit spel hangt aan die opdracht: de webshop, het
## paard dat naar links moet, de AI-video. Wie de opdracht niet kent, ziet
## alleen losse sketches.
##
## Bewust geen derde regel over de deadline: die staat in Daans ochtendgroet in
## `Main._intro_beat()`, waar hij uit een mond komt in plaats van van een dia.
static func opdracht() -> Array[String]:
	return [
		"Manege De Vrije Teugel wil een webshop voor paardensupplementen.",
		"Jij werkt vandaag mee bij Bluebird Day.",
	]


## De vier regels, los van de scene-opbouw zodat `_test_intro()` ze kan
## controleren zonder de scene te bouwen.
##
## Regel 3 leest zijn getal uit de ticketdata en staat er niet meer hard in.
## Er stond "Negen staan meteen open", en dat was waar tot F3-a de inbox liet
## vollopen: sindsdien hebben alleen t02, t03, t04 en t05 een lege
## `available_when` en staan er vier open. Het uitlegscherm is het eerste en
## enige dat een nieuwe speler over het keuzemechaniek vertelt, dus dat getal
## moet uit de data komen — een tweede kopie gaat een tweede keer stilstaan.
static func lessen() -> Array[String]:
	var open := open_bij_start()
	var telwoord := TELWOORDEN[open] if open < TELWOORDEN.size() else str(open)
	return [
		"Tien tickets, verspreid door het kantoor. Vind ze door rond te lopen.",
		"Zijn ze alle tien opgelost, dan mag je naar buiten.",
		"%s staan meteen open. Op het ticketbord kies je wat je oppakt." % telwoord,
		"Niet jouw vak? Haal er een collega bij.",
	]


func _ready() -> void:
	UiKit.full_rect(self)
	var bg := ColorRect.new()
	bg.color = UiKit.SCHERM_NACHT
	UiKit.full_rect(bg)
	add_child(bg)

	# Twee blokken passen niet meer op één gecentreerde kolom van 220 px hoog:
	# de opdracht erbij maakt het scherm hoger dan 416 px. De kolom vult nu de
	# hele hoogte binnen een marge, met de knop onderaan vastgezet — anders
	# schuift die bij een langere opdrachtregel onder het scherm, precies de
	# fout die de knoppenbalk eerder maakte.
	var v := VBoxContainer.new()
	UiKit.full_rect(v)
	v.offset_left = 12; v.offset_right = -12
	v.offset_top = 16; v.offset_bottom = -12
	v.add_theme_constant_override("separation", 4)
	add_child(v)

	_blok(v, "VANDAAG", opdracht(), UiKit.WIT)
	v.add_child(UiKit.spacer(8))
	_blok(v, "HOE DIT WERKT", lessen(), UiKit.WIT)

	# Duwt de knop naar de onderrand, wat er ook boven staat.
	var rek := Control.new()
	rek.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rek.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(rek)

	var verder := UiKit.knop_primair("Begrepen", UiKit.FS_BODY)
	verder.pressed.connect(_on_verder)
	v.add_child(verder)

	verder.grab_focus()


## Eén kop met zijn regels eronder. Linksuitgelijnd en niet gecentreerd: twee
## blokken onder elkaar hebben een linkerkantlijn nodig om als twee blokken te
## lezen, en gecentreerde lopende tekst van drie regels is op 168 px breed
## simpelweg trager te lezen.
func _blok(ouder: VBoxContainer, kop: String, regels: Array[String], kleur: Color) -> void:
	ouder.add_child(UiKit.label(kop, UiKit.FS_SMALL, UiKit.BLUEBIRD_BRIGHT))
	ouder.add_child(UiKit.spacer(2))
	for r: String in regels:
		ouder.add_child(UiKit.label(r, UiKit.FS_SMALL, kleur))
		ouder.add_child(UiKit.spacer(3))


## Waar "Begrepen" naartoe gaat. Bij een nieuwe dag naar de personagekeuze; bij
## "Doorgaan" is die keuze al gemaakt en gaat hij het spel in.
##
## Dit scherm zat alleen op de route Titel -> Uitleg -> Keuze, en "Doorgaan"
## ging rechtstreeks naar de wereld. Wie op een save terugkwam kreeg de
## opdracht dus nooit te zien — en dat is precies de speler die er het meest
## aan heeft, want die was hem misschien al vergeten. Bij een save die al
## onderweg is (`done_count() > 0`) blijft hij weg: dan is het een tolpoort.
static var na_uitleg_het_spel_in: bool = false


func _on_verder() -> void:
	AudioDirector.play_ui(&"klik")
	if na_uitleg_het_spel_in:
		na_uitleg_het_spel_in = false
		Shell.goto_game()
		return
	Shell.goto_character_select()
