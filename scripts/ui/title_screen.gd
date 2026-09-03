extends Control
## Titelscherm.

## Hoe ver de kolom van de canvasranden blijft. Zelfde getal als `Hud.MARGE`,
## maar niet daaruit geleend: dit scherm kent de HUD niet.
const MARGE := 4

func _ready() -> void:
	UiKit.full_rect(self)
	var bg := ColorRect.new()
	bg.color = UiKit.SCHERM_NACHT
	UiKit.full_rect(bg)
	add_child(bg)

	# Verticaal gecentreerd, horizontaal aan de canvasranden met een marge —
	# niet op een vaste breedte. Dit stond op -140/140, dus 280 px op een canvas
	# van 192: de knoppen rekken met de VBox mee, dus "Doorgaan" en "Afsluiten"
	# liepen er 44 px aan elke kant buiten. Zelfde patroon als
	# `character_select.gd`, dat zijn wortel op 4/-4 zet.
	var v := VBoxContainer.new()
	v.anchor_left = 0.0; v.anchor_right = 1.0
	v.anchor_top = 0.5; v.anchor_bottom = 0.5
	v.offset_left = MARGE; v.offset_right = -MARGE
	v.offset_top = -70; v.offset_bottom = 70
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 4)
	add_child(v)

	var t1 := UiKit.label("10 TICKETS", UiKit.FS_TITLE, UiKit.BLUEBIRD_BRIGHT)
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t1)

	var t2 := UiKit.label("NAAR VRIJHEID", UiKit.FS_HEAD, UiKit.BLUEBIRD_BRIGHT)
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t2)

	var sub := UiKit.label("Een werkdag bij Bluebird Day", UiKit.FS_SMALL, UiKit.GRIJS_OP_DONKER)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)

	v.add_child(UiKit.spacer(10))

	# "Beginnen" is nu áltijd de primaire, gefocuste knop, ook als er een
	# lopende dag ligt. Dat stond hiervoor op "Doorgaan" zodra er een save was
	# ("wie een dag heeft openstaan wil die meestal afmaken") — maar dat
	# betekende dat een enkele Enter of tik op het titelscherm genoeg was om
	# er zonder het te willen middenin te belanden, en dan sla je de intro en
	# de personagekeuze allebei over zonder dat te beseffen. "Beginnen" vraagt
	# nu eerst bevestiging als dat een lopende dag zou wegschrijven — zie
	# `_op_beginnen()` — en is daarmee zowel de veiligste als de meest
	# voorspelbare knop om te focussen.
	var heeft_save := Session.has_saved_run()

	var start := UiKit.knop_primair("Beginnen", UiKit.FS_BODY)
	start.pressed.connect(_op_beginnen)
	v.add_child(start)

	# "Doorgaan" staat er alleen als er echt iets is om naar terug te keren. De
	# save wordt bij elk opgelost ticket en bij het naar de achtergrond gaan
	# weggeschreven, dus hij bestaat allang — hij had tot nu toe alleen geen
	# enkele lezer, en een half uur spelen was op een telefoon onherstelbaar weg
	# terwijl het bestand er gewoon stond. Secundaire stijl: "Beginnen" is de
	# gefocuste, primaire actie, "Doorgaan" is er voor wie hem gericht opzoekt.
	var verder: Button = null
	if heeft_save:
		verder = UiKit.button("Doorgaan", UiKit.FS_BODY)
		verder.pressed.connect(_on_doorgaan)
		v.add_child(verder)

	var quit := UiKit.button("Afsluiten", UiKit.FS_BODY)
	quit.pressed.connect(func() -> void: get_tree().quit())
	v.add_child(quit)

	start.grab_focus()
	AudioDirector.set_base(&"intro")
	_qa_doorgaan(verder)


## QA: `-- --scherm=titel --doorgaan` drukt de knop zelf in.
##
## De laadroute is anders alleen te bereiken door met de hand op een knop te
## klikken die er bovendien alleen staat als er toevallig een save ligt — en dat
## is precies de route waar een speler zijn halve dag aan ophangt. Zonder deze
## vlag is hij in een headless doorloop niet te bewijzen.
func _qa_doorgaan(knop: Button) -> void:
	if "--doorgaan" not in OS.get_cmdline_user_args():
		return
	if knop == null:
		printerr("[QA] --doorgaan, maar er ligt geen bewaarde run")
		get_tree().quit(1)
		return
	# Ruim ná de infade: `Shell._change_scene()` weigert stil zolang de vorige
	# transitie loopt, en dan drukt deze vlag een knop in die niets doet.
	await get_tree().create_timer(1.2).timeout
	print("[QA] Doorgaan indrukken")
	knop.pressed.emit()


## "Beginnen" is onschuldig zolang er niets te verliezen is. Ligt er een
## lopende dag, dan overschrijft een nieuwe run die zodra hij zijn eerste
## ticket oplost of naar de achtergrond gaat (`Shell._naar_achtergrond()`),
## dus dit is het enige moment waarop de speler dat nog kan weten vóórdat het
## gebeurt.
func _op_beginnen() -> void:
	if Session.has_saved_run():
		_toon_bevestiging()
		return
	_start_nieuwe_dag()


func _start_nieuwe_dag() -> void:
	AudioDirector.play_ui(&"klik")
	Shell.goto_intro_uitleg()


## Eén bevestigingsscherm, en de enige plek in het spel die er een heeft. Dat
## is bewust: `pauzemenu.gd::_op_verlaten()` heeft er expres geen, want die
## actie is nooit destructief — hij slaat eerst op. Dit wél: "Ja" gooit de
## huidige dag zonder terugweg weg.
var _bevestiging: Control = null


func _toon_bevestiging() -> void:
	AudioDirector.play_ui(&"klik")
	_bevestiging = UiKit.full_rect(Control.new())
	_bevestiging.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bevestiging)
	_bevestiging.add_child(UiKit.dimmer())

	var paneel := PanelContainer.new()
	paneel.add_theme_stylebox_override("panel", UiKit.panel(UiKit.PANEL, UiKit.INK, 2))
	paneel.set_anchors_preset(Control.PRESET_CENTER)
	paneel.anchor_left = 0.5; paneel.anchor_right = 0.5
	paneel.anchor_top = 0.5; paneel.anchor_bottom = 0.5
	paneel.offset_left = -84; paneel.offset_right = 84
	paneel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_bevestiging.add_child(paneel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	paneel.add_child(v)

	var kop := UiKit.label("Opnieuw beginnen?", UiKit.FS_SUB, UiKit.INK)
	kop.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(kop)

	var uitleg := UiKit.label(
		"Je huidige dag wordt gewist. Wat je al hebt opgelost is dan weg.",
		UiKit.FS_SMALL, UiKit.GRIJS_OP_LICHT)
	uitleg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	uitleg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(uitleg)

	v.add_child(UiKit.spacer(4))

	# Rood, niet blauw: de blauwe knop op dit scherm is "Beginnen" zelf, en
	# een tweede primaire kleur voor een destructieve actie zou de twee door
	# elkaar laten lopen. Rood is hier de enige plek in de boot-schermen die
	# een waarschuwing draagt.
	#
	# En `keuzeknop()` en niet `button()`. Een `UiKit.button()` zet bewust geen
	# autowrap (zie de gemeten tabel bij die functie), dus hij meldde deze 33
	# tekens als minimumbreedte: ~210 px op een paneel dat 168 vraagt. Een
	# Control kan niet onder zijn minimum, dus het paneel groeide buiten het
	# canvas en de knop las "Ja, dag wissen en opnieuw be" met de rest eraf.
	# `keuzeknop()` breekt af en past zich aan de breedte aan in plaats van
	# eraan te trekken; twee regels is hier geen bezwaar.
	var wis := UiKit.keuzeknop("Ja, dag wissen en opnieuw beginnen", UiKit.FS_BODY)
	for kleur: StringName in [&"font_color", &"font_hover_color", &"font_focus_color"]:
		wis.add_theme_color_override(kleur, UiKit.ROOD_OP_LICHT)
	wis.pressed.connect(_op_wis_en_begin)
	v.add_child(wis)

	var annuleer := UiKit.button("Annuleren", UiKit.FS_BODY)
	annuleer.pressed.connect(_sluit_bevestiging)
	v.add_child(annuleer)

	# Veiligste focus: een per ongeluk doorgedrukte Enter/bevestiging mag nooit
	# de dag wissen. "Annuleren" is hier de onschuldige default, niet "Beginnen"
	# zelf zoals op het titelscherm erachter.
	annuleer.grab_focus()


func _op_wis_en_begin() -> void:
	AudioDirector.play_ui(&"klik")
	Session.delete_saved_run()
	_sluit_bevestiging()
	_start_nieuwe_dag()


func _sluit_bevestiging() -> void:
	if _bevestiging == null:
		return
	AudioDirector.play_ui(&"klik")
	_bevestiging.queue_free()
	_bevestiging = null


## `cancel` sluit de bevestiging net als overal elders in het spel — zie
## `pauzemenu.gd::_input()` voor hetzelfde patroon.
func _unhandled_input(event: InputEvent) -> void:
	if _bevestiging != null and event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		_sluit_bevestiging()


## De bewaarde dag hervatten.
##
## Meer dan dit is er niet nodig: de wereld is een pure functie van de sessie, en
## `WorldMutator.replay_all()` in `Main._ready()` speelt alle `world_changes` van
## de opgeloste tickets opnieuw af. `refresh_availability()` staat hier omdat een
## save van vóór een contentwijziging tickets kan bevatten die inmiddels open
## horen te staan; die promotie is idempotent.
##
## Wat bewust *niet* terugkomt: `Session.followers`. Die staat niet in de save
## (zie `session.gd`), want na het laden staat iedere collega weer op zijn eigen
## post — een bewaarde lijst zou beweren dat Willem achter je aan loopt terwijl
## hij aan zijn bureau zit. De vlag `helper_bij_<ticket>` overleeft wél, dus werk
## waar je een collega al voor had opgehaald blijft oplosbaar.
func _on_doorgaan() -> void:
	AudioDirector.play_ui(&"klik")
	if not Session.load_from_disk():
		push_warning("Titelscherm: de save kon niet gelezen worden")
		return
	QuestEngine.refresh_availability()
	Shell.goto_game()
