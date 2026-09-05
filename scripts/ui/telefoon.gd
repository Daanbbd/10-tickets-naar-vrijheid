class_name Telefoon
extends CanvasLayer
## Het telefoonscherm van De Klant.
##
## Zij is één persoon op twee plekken. In de entree staat ze als NPC `klant`
## (`data/npcs.json`, zone `z1_entree`) met een uitgeprinte screenshot voor
## BBD-203; hier op je telefoon meldt ze zich op een moment dat je iets anders
## aan het doen was. Dat tweede is wat dit scherm bestaat te doen: een klant die
## je kunt opzoeken kan wachten, een klant die jóu opzoekt niet.
##
## Daarom komt haar melding in twee stappen. Eerst een meldingsscherm met haar
## naam en één knop, dan het bericht zelf. Zonder die eerste stap valt haar
## eerste push koud binnen: `Gevolgen.DREMPELS` begint op 1, dus k1 kan al vallen
## voordat de speler ooit in de entree is geweest, en dan staat er een vreemde
## tekst op het scherm zonder dat iemand haar heeft geïntroduceerd. De melding
## heeft bewust geen sluitknop — haar berichten dragen `effects` en horen niet
## weggetikt te kunnen worden vóór je ze gelezen hebt.
##
## Dit is ook waar de spanningsboog zichtbaar wordt. Wat oploopt is hoeveel je
## gedaan hebt: zij meldt zich op elke drempel in `Gevolgen.DREMPELS`, steeds
## enthousiaster, steeds duurder. Sommige van haar berichten doen ook iets: ze
## ontgrendelen een ticket of veranderen er een, via de `effects`-array op de
## variant die uiteindelijk getoond wordt.
##
## Wát ze stuurt hangt af van je keuzes: de varianten in
## `data/klant_berichten.json` staan achter gewone `when`-condities op de
## gevolgvlaggen uit `Gevolgen`. Beloofde je haar Comic Sans, dan bedankt ze je
## daarvoor. Liet je de webshop weg, dan vraagt ze op de avond voor de
## oplevering of mensen wel iets kunnen kopen.

const PATH := "res://data/klant_berichten.json"

## Breedte van het toestel op een canvas van 192 px. Smal genoeg dat je het
## kantoor ernaast ziet liggen: de melding onderbreekt je dag, hij vervangt
## hem niet.
const BREEDTE := 150
const HOOGTE := 210

## De laagste laag die boven de dialoog (20) uitkomt en onder de minigame (50)
## blijft. Een melding mag een gesprek overstemmen maar nooit een minigame.
const LAAG := 30

var _berichten: Dictionary = {}
var _afzender: String = ""
## Welke drempels al gevallen zijn. Idempotent, want `replay_all()` en een
## herstart uit de save mogen geen tweede melding opleveren.
var _gehad: Dictionary = {}
## De berichten die klaarstaan maar nog niet mogen. Zie `_process`.
##
## Een rij en niet één slot. Dit stond eerst op één `StringName`, en dan gaat
## het mis zodra de volgende drempel valt voordat de vorige melding een rustig
## frame heeft gevonden: die overschreef de wachtende, en omdat `_gehad` al
## afgevinkt was kwam de oudste nooit meer. In een `--playthrough` gebeurde dat
## elke keer — k1 viel bij 3/10 en werd bij 5/10 door k2 verdrongen, dus de
## eerste escalatiebeat van de hele dag ontbrak. Zonder fout, want een
## overschreven slot klaagt niet.
var _wachtrij: Array[StringName] = []
var _open: bool = false
## Staat het bericht zélf op het scherm, of nog de melding ervoor? Los van
## `_open`, want tussen die twee zit een knopdruk: `_open` dekt beide stappen
## (zodat `_process()` er geen tweede melding bovenop legt), deze alleen de
## tweede. `_input()` mag pas wegleggen als deze waar is.
var _bericht_zichtbaar: bool = false
## Welk bericht de melding aankondigt. Nodig omdat `_toon()` en het openen nu
## twee losse momenten zijn en de knop moet weten wat hij opent.
var _huidig: StringName = &""
## De variant die bij de melding gekozen is, bewaard tot het openen. Niet
## opnieuw kiezen achter de knop: tussen aankondiging en druk kan een
## `when`-conditie omgaan, en dan draaien de effects van een ander bericht dan
## dat de speler leest.
var _huidig_variant: Dictionary = {}

## Eigen idempotentie-wacht voor de effects, los van `_gehad`. `_gehad[bid]`
## wordt al gezet in `_op_ticket()` en `_qa_bericht()` — allebei vóórdat
## `_toon()` ooit draait — dus die kan niet gebruikt worden om te zien of de
## effects van dít bericht al gedraaid hebben. Zonder deze eigen wacht draaien
## de effects opnieuw zodra `_toon()` een tweede keer wordt aangeroepen (een
## save/load-replay, of `--klant=` terwijl de wachtrij al bezig was).
var _effecten_gedaan: Dictionary = {}

## **Geen wachttijd bovenop het eerste stille frame.** Ik heb hier een rust van
## 0,35 s in gehad, en daarna een voorwaarde "niet terwijl er een ticketstroom
## loopt". Beide klonken redelijk en beide waren fout: van de vier drempels
## haalde er toen precies één het scherm, want de volgende stroom begint binnen
## die rust en dan schuift de melding vooruit tot het spel al klaar is.
##
## Wat die guards moesten oplossen was een race in de QA-harnas — die begon het
## volgende ticket zodra `is_done` viel, terwijl de stroom nog liep. Dat is
## gerepareerd waar het zat: `main.gd` wacht nu op `tickets.bezig()`. Een echte
## speler kan zijn eigen dialoog niet inhalen, dus hier is één stil frame
## precies goed.

var _scrim: ColorRect = null
var _toestel: PanelContainer = null
var _tekst: RichTextLabel = null
var _kop: Label = null
var _tijd: Label = null
var _paard: TextureRect = null
var _puntjes: Label = null
var _meldingvak: VBoxContainer = null
var _berichtvak: VBoxContainer = null
var _openen: Button = null
var _paard_tween: Tween = null
var _punt_tween: Tween = null
var _schuif_tween: Tween = null

## De ticketstroom, om te weten of de vloer echt stil is. Zie `_process()`.
var _tickets: TicketController = null


func setup(tickets: TicketController = null) -> void:
	layer = LAAG
	_tickets = tickets
	_laad()
	_bouw()
	Bus.ticket_completed.connect(_op_ticket)
	_qa_bericht()


## QA: `-- --klant=2` legt bericht k2 klaar zonder dat je er drie tickets voor
## hoeft op te lossen. De enige manier om haar schermen visueel na te kijken; de
## gevolgvlaggen die de variant kiezen zet je met de gewone
## `--ticket=`/`--gedaan=`-vlaggen.
##
## De bovengrens komt uit `Gevolgen.DREMPELS` en niet uit een eigen getal, dus
## een drempel erbij werkt hier meteen. Dat zijn er nu zes.
func _qa_bericht() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--klant="):
			var n := int(a.trim_prefix("--klant="))
			if n >= 1 and n <= Gevolgen.DREMPELS.size():
				_gehad[StringName("k%d" % n)] = true
				_wachtrij.append(StringName("k%d" % n))


func _laad() -> void:
	if not FileAccess.file_exists(PATH):
		push_error("Telefoon: %s ontbreekt" % PATH)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not (parsed is Dictionary):
		push_error("Telefoon: %s bevat geen geldig JSON-object" % PATH)
		return
	_afzender = String((parsed as Dictionary).get("afzender", ""))
	_berichten = (parsed as Dictionary).get("berichten", {}) as Dictionary


# --- Opbouw ---------------------------------------------------------------

func _bouw() -> void:
	var root := UiKit.fill_viewport(Control.new())
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.visible = false
	add_child(root)

	_scrim = UiKit.dimmer(0.55)
	root.add_child(_scrim)

	_toestel = PanelContainer.new()
	_toestel.add_theme_stylebox_override("panel", _behuizing())
	_toestel.set_anchors_preset(Control.PRESET_CENTER)
	_toestel.anchor_left = 0.5
	_toestel.anchor_right = 0.5
	_toestel.anchor_top = 0.5
	_toestel.anchor_bottom = 0.5
	_toestel.offset_left = -BREEDTE / 2.0
	_toestel.offset_right = BREEDTE / 2.0
	_toestel.offset_top = -HOOGTE / 2.0
	_toestel.offset_bottom = HOOGTE / 2.0
	root.add_child(_toestel)

	var kolom := VBoxContainer.new()
	kolom.add_theme_constant_override("separation", 3)
	_toestel.add_child(kolom)

	# Kopregel: haar merk en niet haar naam, zoals een zakelijk gesprek in een
	# chat-app zijn bedrijfsnaam bovenaan draagt. Haar eigen naam staat in de
	# melding ervóór — dat is de plek waar je wil weten wie er belt, en dit is
	# de plek waar je al weet met wie je in gesprek bent.
	var balk := HBoxContainer.new()
	balk.add_theme_constant_override("separation", 3)
	kolom.add_child(balk)
	_kop = UiKit.label(_afzender, UiKit.FS_SMALL, UiKit.WIT)
	_kop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_kop.autowrap_mode = TextServer.AUTOWRAP_OFF
	_kop.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_kop.clip_text = true
	balk.add_child(_kop)
	# Autowrap uit, en breed genoeg voor "11:20". `_kop` hiernaast staat op
	# EXPAND_FILL en knijpt deze anders tot een paar pixels, waarna de autowrap
	# uit UiKit.label() de tijd per teken afbreekt: een kolom van "1 1 : 2 0"
	# die de kopbalk ook nog vijf regels hoog maakt.
	_tijd = UiKit.label("", UiKit.FS_SMALL, UiKit.GRIJS_OP_DONKER)
	_tijd.autowrap_mode = TextServer.AUTOWRAP_OFF
	_tijd.custom_minimum_size = Vector2(28, 0)
	_tijd.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	balk.add_child(_tijd)

	var streep := ColorRect.new()
	streep.color = UiKit.LINE
	streep.custom_minimum_size = Vector2(0, 1)
	kolom.add_child(streep)

	# --- stap 1: de melding ------------------------------------------------
	#
	# Wat hier moet landen is niet de inhoud maar de afzender: dit is een
	# telefoon, en er staat iemand op die jij kent uit de entree. Vandaar haar
	# naam groot en haar rol eronder, en niet alvast een stuk tekst.
	_meldingvak = VBoxContainer.new()
	_meldingvak.add_theme_constant_override("separation", 2)
	_meldingvak.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Gecentreerd, want de melding is drie regels en een knop op een toestel van
	# 210 px hoog. Boven aan uitgelijnd gaapt er een leeg vlak onder de knop en
	# ziet het scherm er half afgebouwd uit.
	_meldingvak.alignment = BoxContainer.ALIGNMENT_CENTER
	kolom.add_child(_meldingvak)

	_meldingvak.add_child(UiKit.label("1 nieuw bericht", UiKit.FS_SMALL, UiKit.GRIJS_OP_DONKER))

	# Naam en rol uit `data/npcs.json` en niet hier ingetypt: zij staat als NPC
	# `klant` in de entree, en een tweede plek waar "Mevrouw P. Aardenmens"
	# letterlijk staat gaat bij de eerste naamswijziging stil uit elkaar lopen.
	var klant: NpcDef = GameData.npc(&"klant")
	var naam := "De Klant" if klant == null else klant.name
	# Alleen het stuk vóór de komma: haar `role` is "Klant, Manege De Vrije
	# Teugel", en de kopbalk hierboven draagt die manege al — daar stond hij
	# zelfs afgekapt als "Manege De Vrije Teu…". Twee keer dezelfde bedrijfsnaam
	# op 150 px breed, waarvan één met een ellips, is precies de rommel die dit
	# scherm moest wegnemen.
	var rol := "" if klant == null else klant.role.split(",")[0].strip_edges()
	var naamlabel := UiKit.label(naam, UiKit.FS_BODY, UiKit.WIT)
	naamlabel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_meldingvak.add_child(naamlabel)
	if not rol.is_empty():
		var rollabel := UiKit.label(rol, UiKit.FS_SMALL, UiKit.GRIJS_OP_DONKER)
		rollabel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_meldingvak.add_child(rollabel)

	_meldingvak.add_child(UiKit.spacer(8))

	# Eén knop en geen tweede. Haar berichten dragen `effects` — een ticket dat
	# opengaat, een vlag die omgaat — dus wegleggen vóór lezen mag niet kunnen.
	# Dit is ook wat de autopilot nodig heeft: `Autopilot._process()` drukt op
	# de knop met focus, dus de doorloop komt hier langs zonder eigen uitzondering.
	_openen = UiKit.knop_primair("Openen", UiKit.FS_BODY)
	_openen.pressed.connect(_open_bericht)
	_meldingvak.add_child(_openen)

	# --- stap 2: het bericht ----------------------------------------------
	_berichtvak = VBoxContainer.new()
	_berichtvak.add_theme_constant_override("separation", 3)
	_berichtvak.size_flags_vertical = Control.SIZE_EXPAND_FILL
	kolom.add_child(_berichtvak)

	# Het paard. In de canon lóópt haar GIF; hij stopt nooit. Een bewegende
	# afbeelding in een pixel-art game van 16 px is niet te doen, dus hij
	# deint — en hij deint door, ook als er niets gebeurt.
	_paard = TextureRect.new()
	_paard.texture = load("res://assets/sprites/props/paard_klant.png")
	_paard.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_paard.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_paard.custom_minimum_size = Vector2(0, 34)
	_berichtvak.add_child(_paard)

	_tekst = UiKit.rich(UiKit.FS_SMALL, UiKit.WIT)
	_tekst.fit_content = true
	_tekst.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_berichtvak.add_child(_tekst)

	# De typing-indicator knippert ook als ze niets stuurt. Dat is geen
	# animatiefoutje maar het punt: er komt altijd nog iets.
	_puntjes = UiKit.label("...", UiKit.FS_BODY, UiKit.GRIJS_OP_DONKER)
	_berichtvak.add_child(_puntjes)

	var voet := UiKit.label("tik om weg te leggen", UiKit.FS_SMALL, UiKit.GRIJS_OP_DONKER)
	voet.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_berichtvak.add_child(voet)


## Eigen behuizing in plaats van `UiKit.panel()`: een telefoon heeft ronde
## hoeken, en dat is het enige in het spel waar dat voor geldt. Daarom staat
## deze stijl hier en niet in UiKit.
static func _behuizing() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiKit.INK
	sb.border_color = UiKit.GRIJS
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(5)
	sb.set_content_margin_all(6)
	return sb


# --- Wanneer zij zich meldt -----------------------------------------------

func _op_ticket(_id: StringName, _result: MinigameResult) -> void:
	var fase := Gevolgen.druk()
	if fase <= 0:
		return
	var bid := StringName("k%d" % fase)
	if _gehad.has(bid) or not _berichten.has(String(bid)):
		return
	_gehad[bid] = true
	_wachtrij.append(bid)


## De melding komt niet meteen. Een ticket afronden loopt door een urenrol en
## een afsluitende dialoog, en daar bovenop vallen is precies het moment waarop
## een speler op de verkeerde knop drukt. Dus wachten we tot de vloer weer stil
## is: geen gesprek, geen minigame, geen invoerslot, geen lopende ticketstroom.
##
## Die laatste voorwaarde ontbrak, en daarmee dekten de andere drie de bedoeling
## hierboven niet. `TicketController._handle_inner()` doet ná de minigame nog
## `QuestEngine.complete()`, `await Hud.toon_urenrol()` en pas dán de
## `complete`-dialoog — en `toon_urenrol()` zet geen invoerslot. In dat gat is
## `input_locked` false en `minigame_active()` false, dus precies daar sprong de
## melding ertussen: over de afsluitende regel van je collega heen, bij het
## eerste opgeloste ticket van de dag (`Gevolgen.DREMPELS[0] == 1`). Je hoorde
## dan niet meer wat er gezegd werd. `TicketController.bezig()` dekt de hele
## stroom van interactie tot afsluitende dialoog en bestond al.
##
## `Shell.minigame_active()` staat er sinds F5-a expliciet bij in plaats van
## impliciet mee te liften op `Session.input_locked`: `Shell.run_minigame()`
## zet tegenwoordig ook `Session.lock_input()`, dus die ene voorwaarde dekt een
## minigame vandaag toevallig al mee — maar deze laag (30) mag sowieso nooit
## over een minigame (50) heen vallen (zie `LAAG` hierboven), dus die aanname
## staat hier hard neergezet in plaats van er terloops van te profiteren.
func _process(_delta: float) -> void:
	if _wachtrij.is_empty() or _open:
		return
	if Session.input_locked or get_tree().paused or Shell.minigame_active():
		return
	if _tickets != null and _tickets.bezig():
		return
	_toon(_wachtrij.pop_front())


func _toon(bid: StringName) -> void:
	var b := _berichten.get(String(bid), {}) as Dictionary
	var variant := Conditions.pick_variant(b.get("variants", []) as Array)
	if variant.is_empty():
		# Hardop, want dit is de tweede manier waarop een melding stil kon
		# verdwijnen: geen variant die past betekent dat elke `when` faalt, en
		# dat is een inhoudsfout in `klant_berichten.json` en geen toestand om
		# van weg te lopen. Elk bericht hoort een variant zonder `when` te
		# hebben als bodem.
		push_error("Telefoon: bericht '%s' heeft geen passende variant" % bid)
		return

	_open = true
	_bericht_zichtbaar = false
	_huidig = bid
	_huidig_variant = variant
	Session.lock_input()
	# De tekst staat al klaar maar hangt in een vak dat nog onzichtbaar is: de
	# variant wordt hier gekozen en niet bij het openen, want tussen de melding
	# en de knopdruk kan een `when`-conditie omgaan (een effect van een storing,
	# de klok) en dan zou je een ander bericht lezen dan er aangekondigd werd.
	_tekst.text = String(variant.get("text", ""))
	_tijd.text = String(b.get("tijd", ""))
	_meldingvak.visible = true
	_berichtvak.visible = false

	var root := _scrim.get_parent() as Control
	root.visible = true
	root.mouse_filter = Control.MOUSE_FILTER_STOP

	# Gehinnik op de melding en niet op het bericht: dít is het moment dat je
	# telefoon om je aandacht vraagt. Haar GIF is een paard, dus haar melding is
	# een paard — de cue bestond al voor de paardenbugs.
	AudioDirector.play_ui(&"hinnik")

	# Omhoog schuiven zoals een melding hoort binnen te komen.
	var eind := _toestel.offset_top
	_toestel.offset_top = eind + 40.0
	_toestel.offset_bottom += 40.0
	_toestel.modulate.a = 0.0
	_schuif_tween = _herstart(_schuif_tween)
	_schuif_tween.set_parallel(true)
	_schuif_tween.tween_property(_toestel, "offset_top", eind, 0.26) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_schuif_tween.tween_property(_toestel, "offset_bottom", eind + HOOGTE, 0.26) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_schuif_tween.tween_property(_toestel, "modulate:a", 1.0, 0.16)

	# Focus op de enige knop. Dubbel nodig: een speler met een toetsenbord kan
	# zo openen zonder de muis te pakken, en `Autopilot` drukt op precies de
	# knop met focus — daarmee loopt de `--playthrough` hier zonder eigen
	# uitzondering langs, in plaats van dat de melding hem laat hangen.
	_openen.grab_focus()


## Stap 2. Alles wat een gevolg heeft gebeurt hier en niet op de melding: de
## speler hoort het gevolg te zien komen uit een bericht dat hij gelezen heeft,
## niet uit een naam op een meldingsscherm.
func _open_bericht() -> void:
	if not _open or _bericht_zichtbaar:
		return
	_bericht_zichtbaar = true
	_meldingvak.visible = false
	_berichtvak.visible = true
	AudioDirector.play_ui(&"klik")

	Bus.klant_bericht.emit(_huidig)

	# Ná het signaal, niet ervoor: de speler moet het gevolg zien komen uit het
	# bericht dat al op het scherm staat, niet uit een ticket dat al openging
	# terwijl de telefoon nog trilde. Eigen wacht (`_effecten_gedaan`), want
	# `_gehad[bid]` is hier al lang waar.
	if not _effecten_gedaan.has(_huidig):
		_effecten_gedaan[_huidig] = true
		QuestEngine.run_effects(_huidig_variant.get("effects", []) as Array)

	_deinen()
	_knipperen()


func _deinen() -> void:
	_paard_tween = _herstart(_paard_tween)
	_paard_tween.set_loops()
	_paard_tween.tween_property(_paard, "position:y", 2.0, 0.5).as_relative() \
		.set_trans(Tween.TRANS_SINE)
	_paard_tween.tween_property(_paard, "position:y", -2.0, 0.5).as_relative() \
		.set_trans(Tween.TRANS_SINE)


func _knipperen() -> void:
	_punt_tween = _herstart(_punt_tween)
	_punt_tween.set_loops()
	_punt_tween.tween_property(_puntjes, "modulate:a", 0.15, 0.45)
	_punt_tween.tween_property(_puntjes, "modulate:a", 1.0, 0.45)


## Een tween op een node die weggegooid kan worden is een crash die je pas in
## een build ziet. Deze hangen aan de telefoon zelf, en `_exit_tree()` maakt ze
## dood, dus ze overleven dit scherm niet.
func _herstart(t: Tween) -> Tween:
	if t != null and t.is_valid():
		t.kill()
	return create_tween()


func _exit_tree() -> void:
	for t: Tween in [_paard_tween, _punt_tween, _schuif_tween]:
		if t != null and t.is_valid():
			t.kill()


# --- Weglegen -------------------------------------------------------------

func _weg() -> void:
	if not _open:
		return
	_open = false
	_bericht_zichtbaar = false
	_huidig = &""
	_huidig_variant = {}
	for t: Tween in [_paard_tween, _punt_tween]:
		if t != null and t.is_valid():
			t.kill()
	var root := _scrim.get_parent() as Control
	root.visible = false
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Session.unlock_input()
	AudioDirector.play_ui(&"klik")


## Elke tik en elke bevestigingstoets legt hem weg. Op een telefoon is er geen
## andere uitweg dan het scherm zelf, dus die moet altijd werken — ook als de
## tik naast het toestel valt.
##
## Maar pas zodra het bericht er echt staat. Op de melding is de knop de enige
## uitweg: een tik naast het toestel zou daar precies het weggooien zijn dat de
## melding moet voorkomen, en `cancel` (ESC) zou het bericht met zijn `effects`
## overslaan. Vandaar `_bericht_zichtbaar` en niet `_open`.
func _input(event: InputEvent) -> void:
	if not _bericht_zichtbaar:
		return
	var raak := event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed
	raak = raak or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed)
	raak = raak or event.is_action_pressed("interact") or event.is_action_pressed("cancel")
	if raak:
		get_viewport().set_input_as_handled()
		_weg()


## Op de melding opent de bevestigingstoets het bericht, in plaats van niets te
## doen. `interact` is E, spatie én enter (zie `[input]` in project.godot), maar
## alleen die laatste twee zijn ook `ui_accept` en drukken dus zelf de knop met
## focus in. Een speler die de hele dag met E heeft gepraat drukt hier op E, en
## dan hoort er iets te gebeuren — er ís geen andere uitweg op dit scherm.
##
## `_unhandled_input` en niet `_input`: een echte klik op de knop moet eerst
## door de GUI heen kunnen, anders vangt deze functie hem af vóór de Button.
func _unhandled_input(event: InputEvent) -> void:
	if not _open or _bericht_zichtbaar:
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_open_bericht()


func is_open() -> bool:
	return _open
