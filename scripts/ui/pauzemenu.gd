class_name Pauzemenu
extends CanvasLayer
## Het pauzemenu: doorgaan, volume, de run verlaten.
##
## **Waarom laag 40.** Boven de telefoon van De Klant (30), zodat een melding die
## net binnenkomt niet over je menu heen valt, en onder de minigame (50), zodat
## een lopende minigame niet ineens een menu over zich heen krijgt. De volgorde
## is dezelfde afweging als bij `Telefoon.LAAG`: wie mag wie overstemmen.
##
## **Wie de pauze bezit.** Dit menu niet. `Shell` is de enige plek die
## `get_tree().paused` aanraakt; hier staat alleen `Shell.pauzeer_voor_menu()`.
## Zonder die scheiding ontpauzeert een sluitend menu de minigame die eronder
## draait, of het achtergrondslot van een app die net terugkomt.
##
## De knoppen zijn geen sneltoetsen: `cancel` opent en sluit, en de knoppenbalk
## heeft er een vierde knop voor die diezelfde actie indrukt. Zo is er ook hier
## één besturing op elk apparaat.

## Boven de telefoon (30), onder de minigame (50).
const LAAG := 40

const BREEDTE := 150

var _root: Control = null
var _paneel: PanelContainer = null
var _volume: HSlider = null
var _volume_label: Label = null
var _open: bool = false


func setup() -> void:
	layer = LAAG
	# De hele reden van bestaan: dit scherm moet werken terwijl de wereld stilstaat.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bouw()


func is_open() -> bool:
	return _open


# --- Opbouw ---------------------------------------------------------------

func _bouw() -> void:
	_root = UiKit.fill_viewport(Control.new())
	_root.visible = false
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	_root.add_child(UiKit.dimmer(0.78))

	_paneel = PanelContainer.new()
	_paneel.add_theme_stylebox_override("panel", UiKit.panel(UiKit.PANEL, UiKit.INK, 2))
	_paneel.set_anchors_preset(Control.PRESET_CENTER)
	_paneel.anchor_left = 0.5; _paneel.anchor_right = 0.5
	_paneel.anchor_top = 0.5; _paneel.anchor_bottom = 0.5
	_paneel.offset_left = -BREEDTE / 2.0
	_paneel.offset_right = BREEDTE / 2.0
	_paneel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_root.add_child(_paneel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	_paneel.add_child(v)

	var kop := UiKit.label("PAUZE", UiKit.FS_BODY, UiKit.BLUEBIRD_INK)
	kop.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(kop)

	var door := UiKit.button("Doorgaan", UiKit.FS_BODY)
	door.pressed.connect(sluit)
	v.add_child(door)

	v.add_child(UiKit.spacer(2))

	_volume_label = UiKit.label("", UiKit.FS_SMALL, UiKit.INK)
	v.add_child(_volume_label)

	_volume = HSlider.new()
	_volume.min_value = 0.0
	_volume.max_value = 1.0
	_volume.step = 0.05
	_volume.value = AudioDirector.master_volume
	_volume.custom_minimum_size = Vector2(0, UiKit.KNOP_MIN_H)
	_volume.value_changed.connect(_op_volume)
	v.add_child(_volume)
	_toon_volume(AudioDirector.master_volume)

	v.add_child(UiKit.spacer(2))

	# Geen bevestigingsvraag, wel eerst opslaan. Weglopen uit een run mag geen
	# manier zijn om hem kwijt te raken: "Doorgaan" op het titelscherm zet je
	# precies terug waar je hier stopte.
	var weg := UiKit.button("Run verlaten", UiKit.FS_BODY)
	weg.pressed.connect(_op_verlaten)
	v.add_child(weg)

	var uitleg := UiKit.label("Je dag wordt bewaard.", UiKit.FS_SMALL, UiKit.GRIJS_OP_LICHT)
	uitleg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(uitleg)


# --- Openen en sluiten ----------------------------------------------------

func open() -> void:
	if _open:
		return
	_open = true
	_volume.value = AudioDirector.master_volume
	_root.visible = true
	Shell.pauzeer_voor_menu(true)
	AudioDirector.play_ui(&"klik")
	_volume.release_focus()


func sluit() -> void:
	if not _open:
		return
	_open = false
	_root.visible = false
	Shell.pauzeer_voor_menu(false)
	AudioDirector.play_ui(&"klik")


func toggle() -> void:
	if _open:
		sluit()
	else:
		open()


## De tree staat stil, dus dit is de enige node in de wereldscene die nog invoer
## ziet. Vandaar `_input` en niet `_unhandled_input`: de knoppen eronder zijn
## Controls en die zouden `cancel` niet doorlaten.
func _input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		sluit()


## Zou de scene onder een open menu weggaan, dan mag de pauze niet blijven staan.
## `Shell._change_scene()` gooit hem zelf ook los; dit is het vangnet voor elke
## andere route waarlangs deze node verdwijnt.
func _exit_tree() -> void:
	if _open:
		_open = false
		Shell.pauzeer_voor_menu(false)


# --- Volume ---------------------------------------------------------------

func _op_volume(waarde: float) -> void:
	AudioDirector.set_master_volume(waarde)
	_toon_volume(waarde)


func _toon_volume(waarde: float) -> void:
	_volume_label.text = "Volume  %d%%" % int(round(waarde * 100.0))


# --- De run verlaten ------------------------------------------------------

func _op_verlaten() -> void:
	AudioDirector.play_ui(&"klik")
	Session.save_to_disk()
	_open = false
	_root.visible = false
	Shell.pauzeer_voor_menu(false)
	Shell.goto_title()
