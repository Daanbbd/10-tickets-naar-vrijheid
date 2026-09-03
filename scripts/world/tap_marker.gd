class_name TapMarker
extends Node2D
## Wijst aan dat je op dít object kunt tikken, en zegt wat dat oplevert —
## de vervanging van de vaste actieknop. `main.gd` bouwt en breekt er hooguit
## één tegelijk, gehangen aan `Interactable.global_position`.
##
## **Waarom het bijschrift hier hangt en niet in de HUD.** De prompt stond
## onderaan het scherm, gecentreerd, net boven de knoppenbalk: `Hud._prompt` in
## de onderstapel. Dat klopte zolang er een actieknop was — de tekst hoorde bij
## de knop, en die knop stond daar. Sinds je direct op het object tikt, staat de
## enige regel die zegt wát een tik doet maximaal ver van het ding dat je
## aantikt, in de strook waar ook de joystick onder je duim opkomt.
##
## Nu staan de ring en de tekst op één plek: bij het object.
##
## Geen art-asset: een pulserende ring die zichzelf tekent, net als
## `ObjectiveMarker`. Andere kleur dan die driehoek (`UiKit.ORANJE`, expliciet
## gereserveerd voor "doel"): dit betekent iets anders — niet "ga hierheen"
## maar "hier kun je nu iets doen" — en verdient dus zijn eigen kleur.

const STRAAL := 9.0
const AMPLITUDE := 1.5
const SNELHEID := 4.0

## Hoe ver het kaartje van de schermrand blijft, in wereldpixels.
const RANDMARGE := 4.0

## Hoe ver het kaartje boven (of onder) de ring hangt.
const KAARTJE_LUCHT := 12.0

var _t: float = 0.0
## De ring hoort alleen bij een kern-object dat je nog nooit hebt aangetikt; het
## bijschrift hoort bij álles waar je voor staat. Zie
## `Interactable.should_show_tik_marker()`.
var _ring: bool = true
var _kaartje: PanelContainer = null
var _kaartje_label: Label = null
var _hud: Hud = null


func _ready() -> void:
	z_index = 60
	# Iets boven het object, zodat de ring niet over de tegelkunst zelf ligt.
	position = Vector2(0.0, -6.0)
	_hud = get_tree().get_first_node_in_group(&"hud") as Hud
	_bouw_kaartje()
	# De dialoogbox (laag 20) en de telefoon (30) dekken de wereld af, maar niet
	# op de hoogte waar dit kaartje hangt — en een prompt die zegt "Praten met
	# Victor" terwijl je al met Victor praat is verkeerd, niet onzichtbaar.
	# Dezelfde reden waarom `Hud._on_input_lock()` de oude prompt verborg.
	Bus.input_lock_changed.connect(_op_input_slot)
	visible = not Session.input_locked


## Ruimtenaam en werkwoord als paneeltje in plaats van een losse
## `draw_string()`: dan komt het projectfont vanzelf mee en krijgt de tekst een
## dekkende ondergrond. Hetzelfde model als `ObjectiveMarker._bouw_kaartje()`.
func _bouw_kaartje() -> void:
	_kaartje = PanelContainer.new()
	_kaartje.add_theme_stylebox_override("panel",
		UiKit.panel_krap(UiKit.PANEL_DARK, UiKit.BLUEBIRD_BRIGHT))
	_kaartje.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_kaartje.visible = false
	_kaartje_label = UiKit.label("", UiKit.FS_SMALL, UiKit.WIT)
	_kaartje_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_kaartje.add_child(_kaartje_label)
	add_child(_kaartje)


## `main.gd` zet dit meteen na het aanmaken, uit hetzelfde signaal dat de oude
## HUD-prompt aandreef.
func zet(tekst: String, ring: bool) -> void:
	_ring = ring
	if _kaartje_label != null:
		_kaartje_label.text = tekst
		_kaartje.visible = tekst != ""
	queue_redraw()


func _op_input_slot(op_slot: bool) -> void:
	visible = not op_slot


func _process(delta: float) -> void:
	_t += delta
	if _ring:
		queue_redraw()
	_leg_kaartje()


## Gecentreerd boven de ring, tenzij het daar niet past.
##
## Twee klemmen, en ze zijn er allebei omdat dit kaartje in de wereld hangt in
## plaats van aan een schermrand:
##
## - **Horizontaal**, want een object dicht bij de rand van het beeld zou zijn
##   bijschrift half buiten beeld duwen. `ObjectiveMarker` lost dat op door naar
##   binnen uit te klappen; dat kan hier niet, want dit kaartje hoort boven het
##   object te staan en niet ernaast.
## - **Verticaal**, want de vergaderkamers liggen op rij 1 tot 6 en de HUD-chips
##   staan bovenin. Past het kaartje niet boven de ring, dan klapt het eronder.
func _leg_kaartje() -> void:
	if _kaartje == null or not _kaartje.visible:
		return
	_kaartje.size = _kaartje.get_combined_minimum_size()
	var half := _kaartje.size.x * 0.5
	var zicht := _zichtbaar()
	var x := -half
	if zicht.size.x > 0.0:
		var links := zicht.position.x + RANDMARGE + half
		var rechts := zicht.end.x - RANDMARGE - half
		if rechts > links:
			x = clampf(global_position.x, links, rechts) - global_position.x - half
	_kaartje.position = Vector2(floorf(x), floorf(_kaartje_y()))


## Boven de ring als dat binnen de vrije band van de HUD valt, anders eronder.
func _kaartje_y() -> float:
	var boven := -KAARTJE_LUCHT - _kaartje.size.y
	var vp := get_viewport()
	if vp == null or not is_instance_valid(_hud):
		return boven
	var band := _hud.vrije_band()
	var terug := vp.get_canvas_transform().affine_inverse()
	if global_position.y + boven >= (terug * Vector2(0.0, band.x)).y:
		return boven
	return KAARTJE_LUCHT


## Het zichtbare stuk wereld, in wereldcoördinaten. Uit de canvastransform en
## niet uit de camera: dan hoeft dit ding geen camera te kennen, en het klopt
## ook tijdens een `focus_on()` waarin de camera los van de speler staat — en
## het neemt de HUD-offset van `GameCamera.zak_onder_hud()` vanzelf mee.
func _zichtbaar() -> Rect2:
	var vp := get_viewport()
	if vp == null:
		return Rect2()
	return vp.get_canvas_transform().affine_inverse() * \
		Rect2(Vector2.ZERO, vp.get_visible_rect().size)


func _draw() -> void:
	if not _ring:
		return
	var straal := STRAAL + sin(_t * SNELHEID) * AMPLITUDE
	draw_arc(Vector2.ZERO, straal, 0.0, TAU, 20, Color(UiKit.INK, 0.5), 3.0)
	draw_arc(Vector2.ZERO, straal, 0.0, TAU, 20, UiKit.BLUEBIRD_BRIGHT, 1.5)
