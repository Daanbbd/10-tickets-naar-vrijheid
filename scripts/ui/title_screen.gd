extends Control
## Titelscherm.

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
	v.offset_left = -140; v.offset_right = 140
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

	# Precies één blauwe knop per scherm, en dat is dezelfde knop die de focus
	# krijgt — zie de regel onderaan: wie een dag heeft openstaan wil die
	# afmaken, en anders begin je een nieuwe. "Beginnen" en "Afsluiten" waren
	# hiervoor pixelidentiek, dus stoppen met spelen zag er even uitnodigend uit
	# als beginnen.
	var heeft_save := Session.has_saved_run()

	var start := (UiKit.button("Beginnen", UiKit.FS_BODY) if heeft_save
		else UiKit.knop_primair("Beginnen", UiKit.FS_BODY))
	start.pressed.connect(_on_start)
	v.add_child(start)

	# "Doorgaan" staat er alleen als er echt iets is om naar terug te keren. De
	# save wordt bij elk opgelost ticket en bij het naar de achtergrond gaan
	# weggeschreven, dus hij bestaat allang — hij had tot nu toe alleen geen
	# enkele lezer, en een half uur spelen was op een telefoon onherstelbaar weg
	# terwijl het bestand er gewoon stond.
	var verder: Button = null
	if heeft_save:
		verder = UiKit.knop_primair("Doorgaan", UiKit.FS_BODY)
		verder.pressed.connect(_on_doorgaan)
		v.add_child(verder)

	var quit := UiKit.button("Afsluiten", UiKit.FS_BODY)
	quit.pressed.connect(func() -> void: get_tree().quit())
	v.add_child(quit)

	# Wie een dag heeft openstaan wil die meestal afmaken.
	(verder if verder != null else start).grab_focus()
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


func _on_start() -> void:
	AudioDirector.play_ui(&"klik")
	Shell.goto_intro_uitleg()


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
