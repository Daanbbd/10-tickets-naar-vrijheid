class_name Telefoon
extends CanvasLayer
## Het telefoonscherm van De Klant.
##
## Zij komt niet in het kantoor. Ze heeft geen sprite, geen bureau en geen
## standplaats — ze bestaat uitsluitend als melding die aankomt op een moment
## dat je iets anders aan het doen was. Dat is de hele reden dat dit scherm
## bestaat in plaats van een NPC: een klant die je kunt opzoeken is een collega,
## en een klant die je opzoekt kan wachten.
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
var _paard_tween: Tween = null
var _punt_tween: Tween = null
var _schuif_tween: Tween = null


func setup() -> void:
	layer = LAAG
	_laad()
	_bouw()
	Bus.ticket_completed.connect(_op_ticket)
	_qa_bericht()


## QA: `-- --klant=2` legt bericht k2 klaar zonder dat je er vijf tickets voor
## hoeft op te lossen. De enige manier om haar vier schermen visueel na te
## kijken; de gevolgvlaggen die de variant kiezen zet je met de gewone
## `--ticket=`/`--gedaan=`-vlaggen.
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

	# Kopregel: haar merk, niet haar naam. In de canon is haar profielfoto het
	# logo van de manege — je hebt haar nog nooit gezien.
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

	# Het paard. In de canon lóópt haar GIF; hij stopt nooit. Een bewegende
	# afbeelding in een pixel-art game van 16 px is niet te doen, dus hij
	# deint — en hij deint door, ook als er niets gebeurt.
	_paard = TextureRect.new()
	_paard.texture = load("res://assets/sprites/props/paard_klant.png")
	_paard.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_paard.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_paard.custom_minimum_size = Vector2(0, 34)
	kolom.add_child(_paard)

	_tekst = UiKit.rich(UiKit.FS_SMALL, UiKit.WIT)
	_tekst.fit_content = true
	_tekst.size_flags_vertical = Control.SIZE_EXPAND_FILL
	kolom.add_child(_tekst)

	# De typing-indicator knippert ook als ze niets stuurt. Dat is geen
	# animatiefoutje maar het punt: er komt altijd nog iets.
	_puntjes = UiKit.label("...", UiKit.FS_BODY, UiKit.GRIJS_OP_DONKER)
	kolom.add_child(_puntjes)

	var voet := UiKit.label("tik om weg te leggen", UiKit.FS_SMALL, UiKit.GRIJS_OP_DONKER)
	voet.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	kolom.add_child(voet)


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
## is: geen gesprek, geen minigame, geen invoerslot.
func _process(_delta: float) -> void:
	if _wachtrij.is_empty() or _open:
		return
	if Session.input_locked or get_tree().paused:
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
	Session.lock_input()
	_tekst.text = String(variant.get("text", ""))
	_tijd.text = String(b.get("tijd", ""))

	var root := _scrim.get_parent() as Control
	root.visible = true
	root.mouse_filter = Control.MOUSE_FILTER_STOP

	# Gehinnik. Haar GIF is een paard, dus haar melding is een paard. De cue
	# bestond al voor de paardenbugs; dit is dezelfde grap op een ander moment.
	AudioDirector.play_ui(&"hinnik")
	Bus.klant_bericht.emit(bid)

	# Ná het signaal, niet ervoor: de speler moet het gevolg zien komen uit het
	# bericht dat al op het scherm staat, niet uit een ticket dat al openging
	# terwijl de telefoon nog trilde. Eigen wacht (`_effecten_gedaan`), want
	# `_gehad[bid]` is hier al lang waar.
	if not _effecten_gedaan.has(bid):
		_effecten_gedaan[bid] = true
		QuestEngine.run_effects(variant.get("effects", []) as Array)

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
func _input(event: InputEvent) -> void:
	if not _open:
		return
	var raak := event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed
	raak = raak or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed)
	raak = raak or event.is_action_pressed("interact") or event.is_action_pressed("cancel")
	if raak:
		get_viewport().set_input_as_handled()
		_weg()


func is_open() -> bool:
	return _open
