extends Control
## Titelscherm.

func _ready() -> void:
	UiKit.full_rect(self)
	var bg := ColorRect.new()
	bg.color = Color("#141824")
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

	var sub := UiKit.label("Een werkdag bij Bluebird Day", UiKit.FS_SMALL, UiKit.GRIJS)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)

	v.add_child(UiKit.spacer(10))

	var start := UiKit.button("Beginnen", UiKit.FS_BODY)
	start.pressed.connect(_on_start)
	v.add_child(start)

	var quit := UiKit.button("Afsluiten", UiKit.FS_BODY)
	quit.pressed.connect(func() -> void: get_tree().quit())
	v.add_child(quit)

	start.grab_focus()
	AudioDirector.set_base(&"intro")


func _on_start() -> void:
	AudioDirector.play_ui(&"klik")
	Shell.goto_intro_uitleg()
