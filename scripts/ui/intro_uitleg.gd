class_name IntroUitleg
extends Control
## Het scherm tussen titel en personagekeuze dat de premisse uitlegt: tickets
## liggen verspreid, er zijn er tien, het bord is waar je kiest, en niet-eigen
## werk vraagt om een collega.
##
## Dit verving de zes dialoognodes die vroeger bij het spawnen speelden. Die
## kwamen te laat: op de personagekeuze staat de ticketbalk en "één ticket
## zelf" al vóór iemand ook maar wist dát er tickets bestonden om zelf te
## kunnen doen. Nu staat de uitleg vóór die keuze, niet erna.
##
## Eén statisch scherm, geen wizard: vier korte regels, één knop.

## Losstaand van de UI-opbouw, zodat _test_intro() in test_runner.gd dezelfde
## tekst controleert als wat er op het scherm staat, zonder de scene te hoeven
## bouwen of instantiëren.
## Getallen in woorden, zodat regel 3 dezelfde typografie heeft als "Tien
## tickets" in regel 1 en er geen cijfer tussen de woorden staat.
## Ruimte voor het telefoonkaartje in de kolom; het kaartje zelf hangt met
## ankers in een gewone Control zodat het kan binnenglijden.
const KAART_RUIMTE := 118.0
## Breedte waarop het bericht zijn regels breekt: de kolom (192 − 2×12) min de
## behuizingsmarge van het kaartje.
const KAART_TEKSTBREEDTE := 154.0
var _kaart: PanelContainer = null

## Kleine letter: het telwoord staat altijd midden in een zin (zie `lessen()`),
## nooit aan het begin.
const TELWOORDEN: Array[String] = [
	"geen", "één", "twee", "drie", "vier", "vijf",
	"zes", "zeven", "acht", "negen", "tien",
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


## Bij hoeveel opgeloste tickets de deploycomputer (t10) meedoet:
## `data/tickets/t10.json`'s `available_when.min_tickets_done`. Zo blijft
## `lessen()` in sync met de data in plaats van "alle tien" hard te coderen,
## terwijl de deur in de praktijk al opent zodra dat aantal gehaald is.
static func deploy_bij() -> int:
	var t10: TicketDef = GameData.ticket(&"t10")
	if t10 == null:
		return 0
	return int(t10.available_when.get("min_tickets_done", 0))


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
		"Laatste dag van sprint veertien. Jij werkt vandaag mee bij Bluebird Day.",
	]


## Wie de klant is en wat ze wil, uit haar eigen mond: het eerste wat je ziet
## is haar berichtje, in het toestel dat de rest van de dag haar kanaal is
## (`Telefoon`). Het waarom (morgen live), het wat (de webshop voor de
## supplementen) en de toon van de dag (ze heeft het al aan de dierenarts
## verteld) in vier zinnen — en het paard dat naar links moet, zodat die grap
## later landt.
static func afzender() -> String:
	return "Manege De Vrije Teugel"


static func bericht() -> String:
	return ("Hoi! Morgen gaat de webshop voor de supplementen live, toch? "
		+ "Ik heb het al aan iedereen doorgestuurd. Ook aan de dierenarts.")


## De vier regels, los van de scene-opbouw zodat `_test_intro()` ze kan
## controleren zonder de scene te bouwen.
##
## Regel 3 leest zijn getal uit de ticketdata en staat er niet meer hard in.
## Er stond "Negen staan meteen open", en dat was waar tot F3-a de inbox liet
## vollopen: sindsdien hebben alleen t01, t02, t04 en t05 een lege
## `available_when` en staan er vier open. Het uitlegscherm is het eerste en
## enige dat een nieuwe speler over het keuzemechaniek vertelt, dus dat getal
## moet uit de data komen — een tweede kopie gaat een tweede keer stilstaan.
##
## Sinds de bordintroductie (`Main._intro_beat()`) begint het ticketbord leeg
## en hangt Dennis er de eerste twee zelf op — dit scherm mag dus niet meer
## zeggen dat je zelf naar het bord loopt om uit vier te kiezen. Het getal
## blijft wel de moeite waard om te noemen: het is de eerste indruk van de
## schaal van de dag ("dit is groter dan de twee die je net kreeg").
static func lessen() -> Array[String]:
	var open := open_bij_start()
	var telwoord := TELWOORDEN[open] if open < TELWOORDEN.size() else str(open)
	var deploy := deploy_bij()
	var deploy_telwoord := TELWOORDEN[deploy] if deploy < TELWOORDEN.size() else str(deploy)
	# Twee regels en niet vier: de rest leer je in de wereld zelf (Dennis loopt
	# met je mee naar het bord, de tickets landen erop, de besturingskaart komt
	# daarna). Dit is de voetnoot onder het berichtje, niet het scherm.
	return [
		"Tien tickets, verspreid door het kantoor. Dennis hangt je eerste twee op het ticketbord. Daarna staan er %s open. Kies zelf." % telwoord,
		"Niet jouw vak? Haal een collega. Bij %s van de tien mag je live. De rest gaat half mee." % deploy_telwoord,
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
	v.offset_top = 12; v.offset_bottom = -12
	v.add_theme_constant_override("separation", 4)
	add_child(v)

	# Woensdag, 09:12 — en dan gaat haar telefoon. De opdracht komt niet van een
	# dia maar uit de mond van de klant, in het toestel dat de rest van de dag
	# haar kanaal is. Het kaartje glijdt binnen met het geluid dat de telefoon
	# de hele dag maakt, zodat je dat geluid daarna herkent als "zij weer".
	v.add_child(UiKit.label("Woensdag  ·  09:12", UiKit.FS_SMALL, UiKit.GRIJS_OP_DONKER))
	v.add_child(UiKit.spacer(2))
	var houder := Control.new()
	houder.custom_minimum_size = Vector2(0, KAART_RUIMTE)
	houder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(houder)
	_kaart = _bouw_kaart()
	_kaart.set_anchors_preset(Control.PRESET_TOP_WIDE)
	# Naar beneden groeien als de tekst meer ruimte vraagt, nooit over de kop.
	_kaart.grow_vertical = Control.GROW_DIRECTION_END
	_kaart.visible = false
	houder.add_child(_kaart)
	v.add_child(UiKit.spacer(3))
	# Eén regel context onder het berichtje; geen eigen kop, het kaartje ís het
	# "vandaag".
	for r: String in opdracht():
		v.add_child(UiKit.label(r, UiKit.FS_SMALL, UiKit.WIT))
	v.add_child(UiKit.spacer(6))
	_blok(v, "HOE DIT WERKT", lessen(), UiKit.GRIJS_OP_DONKER)

	# Duwt de knop naar de onderrand, wat er ook boven staat.
	var rek := Control.new()
	rek.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rek.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(rek)

	var verder := UiKit.knop_primair("Aan het werk", UiKit.FS_BODY)
	verder.pressed.connect(_on_verder)
	v.add_child(verder)

	verder.grab_focus()
	_laat_binnenkomen()


## Het telefoonkaartje: dezelfde behuizing als `Telefoon` in het spel, met de
## afzender, een tijd van één minuut vóór de klok, een streep en het bericht.
func _bouw_kaart() -> PanelContainer:
	var kaart := PanelContainer.new()
	kaart.add_theme_stylebox_override("panel", Telefoon._behuizing())
	var kolom := VBoxContainer.new()
	kolom.add_theme_constant_override("separation", 3)
	kaart.add_child(kolom)
	var balk := HBoxContainer.new()
	balk.add_theme_constant_override("separation", 3)
	kolom.add_child(balk)
	var kop := UiKit.label(afzender(), UiKit.FS_SMALL, UiKit.WIT)
	kop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kop.autowrap_mode = TextServer.AUTOWRAP_OFF
	kop.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	kop.clip_text = true
	balk.add_child(kop)
	var tijd := UiKit.label("09:11", UiKit.FS_SMALL, UiKit.GRIJS_OP_DONKER)
	tijd.autowrap_mode = TextServer.AUTOWRAP_OFF
	tijd.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	balk.add_child(tijd)
	var streep := ColorRect.new()
	streep.color = UiKit.LINE
	streep.custom_minimum_size = Vector2(0, 1)
	kolom.add_child(streep)
	var tekst := UiKit.label(bericht(), UiKit.FS_SMALL, UiKit.WIT)
	tekst.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Een autowrap-label zonder breedte rekent zijn minimumhoogte uit voor een
	# kolom van nul pixels breed — één woord per regel, 1800 px hoog — en een
	# kaartje dat niet in een Container hangt krimpt daarna nooit meer terug.
	# Met een minimumbreedte klopt de som vanaf de eerste frame.
	tekst.custom_minimum_size = Vector2(KAART_TEKSTBREEDTE, 0.0)
	kolom.add_child(tekst)
	return kaart


## Even stilte, dan de telefoon: het geluid, de trilling en het kaartje dat
## van onderen binnenglijdt. `Juice.schuif_in()` werkt hier omdat het kaartje
## in een gewone Control hangt en niet in een Container.
func _laat_binnenkomen() -> void:
	await get_tree().create_timer(0.35).timeout
	if not is_inside_tree() or _kaart == null:
		return
	AudioDirector.play_ui(&"hinnik")
	Haptiek.tril(Haptiek.Sterkte.STOOT)
	_kaart.reset_size()
	_kaart.visible = true
	Juice.schuif_in(_kaart, Vector2(0.0, 28.0), 0.22)


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
