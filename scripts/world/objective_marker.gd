class_name ObjectiveMarker
extends Node2D
## Wijst het huidige doel aan in de wereld: eerst de collega die je moet ophalen,
## daarna het object zelf. Zonder dit moet de speler op gevoel zoeken naar een
## A4 die alleen in de dialoog bestaat.
##
## Geen art-asset: een driehoekje dat zichzelf tekent, dus geen atlas-tile en
## geen import-stap. Er leeft er altijd maximaal één.
##
## **En hij verdwijnt niet als het doel buiten beeld ligt.** Dat deed hij wel, en
## dat is 91% van de tijd: de camera toont twaalf tegels van de honderddertig die
## de vloer vandaag telt, dus een wijzer die alleen boven het object hangt wijst
## vrijwel nooit iets aan.
## Je zag hem één keer — op het moment dat je er al voor stond. Ligt het doel
## buiten beeld, dan klemt de pijl zich tegen de schermrand en zegt hij welke
## ruimte het is en hoe ver. Dat is de informatie die je nodig hebt vóórdat je
## de goede kant op loopt, niet erna.
##
## Alleen horizontaal klemmen: de verdieping is 26 tegels hoog en de viewport
## precies even hoog, dus de camera klemt Y volledig vast en verticaal valt er
## nooit iets buiten beeld. Zie `game_camera.gd`.

const HOOGTE := 34.0
const AMPLITUDE := 2.5
const SNELHEID := 3.2

## Hoe ver de geklemde pijl van de schermrand blijft staan.
const RANDMARGE := 12.0

## Waarvandaan de afstand gemeten wordt. `main.gd` zet dit; zonder speler valt
## hij terug op zijn eigen positie en klopt de afstand nog steeds ongeveer.
var speler: Node2D = null
## De naam van de ruimte waar het doel staat, voor het bijschrift.
var plek: String = ""
## Meters per wereldpixel. Uit `WorldBuilder`, want de schaal van het gebouw is
## een eigenschap van de vloer en niet van dit driehoekje.
var meter_per_px: float = 0.0

var _t: float = 0.0
var _basis: float = 0.0
## -1 links buiten beeld, 0 in beeld, 1 rechts buiten beeld.
var _kant: int = 0
var _kaartje: PanelContainer = null
var _kaartje_label: Label = null
var _hud: Hud = null


func _ready() -> void:
	add_to_group(&"objective_marker")
	z_index = 60
	_basis = -HOOGTE
	position = Vector2(0.0, _basis)
	_hud = get_tree().get_first_node_in_group(&"hud") as Hud
	_bouw_kaartje()


## Ruimtenaam en afstand, als paneeltje in plaats van als losse `draw_string()`:
## dan komt het projectfont vanzelf mee, en het krijgt een dekkende ondergrond.
## De vloer is licht beton — witte tekst er los overheen is onleesbaar.
func _bouw_kaartje() -> void:
	_kaartje = PanelContainer.new()
	_kaartje.add_theme_stylebox_override("panel",
		UiKit.panel_krap(UiKit.PANEL_DARK, UiKit.ORANJE))
	_kaartje.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_kaartje.visible = false
	_kaartje_label = UiKit.label("", UiKit.FS_SMALL, UiKit.WIT)
	_kaartje_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_kaartje.add_child(_kaartje_label)
	add_child(_kaartje)


func _process(delta: float) -> void:
	_t += delta
	var ouder := get_parent() as Node2D
	if ouder == null:
		return

	var zicht := _zichtbaar()
	var doel := ouder.global_position
	var kant := 0
	if zicht.size.x > 0.0:
		if doel.x < zicht.position.x + RANDMARGE:
			kant = -1
		elif doel.x > zicht.end.x - RANDMARGE:
			kant = 1

	if kant != _kant:
		_kant = kant
		queue_redraw()

	# Alleen de positie beweegt; de vorm blijft gelijk, dus geen queue_redraw.
	var deining := sin(_t * SNELHEID) * AMPLITUDE
	if kant == 0:
		position = Vector2(0.0, _basis + deining)
		_kaartje.visible = false
		return

	# Geklemd: de X gaat naar de schermrand, de Y blijft zo dicht mogelijk bij die
	# van het doel. Dat laatste is geen detail — de pijl staat daarmee op de
	# hoogte van de rij waar het doel echt ligt, en dat scheelt bij het
	# binnenlopen een halve ruimte. Maar niet achter de HUD: de hele noordelijke
	# strook van het kantoor ligt op schermhoogte van de ticketteller.
	var x := zicht.position.x + RANDMARGE if kant < 0 else zicht.end.x - RANDMARGE
	global_position = Vector2(x, _geklemde_y(doel.y - HOOGTE) + deining)
	_zet_kaartje(doel, kant)


## De doel-Y, teruggebracht tot de band die de HUD vrij laat. Rekent in
## wereldcoördinaten; de HUD antwoordt in canvaspixels, dus de canvastransform
## zit ertussen — dat is dezelfde omrekening die `UiKit.veilige_insets()` doet.
func _geklemde_y(wens: float) -> float:
	var vp := get_viewport()
	if vp == null:
		return wens
	var band := _hud.vrije_band() if is_instance_valid(_hud) else Vector2.ZERO
	var terug := vp.get_canvas_transform().affine_inverse()
	# Ruimte voor het kaartje eronder: dat hangt zes pixels lager en is er
	# ongeveer twintig hoog.
	var boven := (terug * Vector2(0.0, band.x)).y + 8.0
	var onder := (terug * Vector2(0.0, band.y)).y - 28.0
	if onder <= boven:
		return boven
	return clampf(wens, boven, onder)


## Het zichtbare stuk wereld, in wereldcoördinaten. Uit de canvastransform en
## niet uit de camera: dan hoeft dit ding geen camera te kennen, en het klopt
## ook tijdens een `focus_on()` waarin de camera los van de speler staat.
func _zichtbaar() -> Rect2:
	var vp := get_viewport()
	if vp == null:
		return Rect2()
	return vp.get_canvas_transform().affine_inverse() * \
		Rect2(Vector2.ZERO, vp.get_visible_rect().size)


func _zet_kaartje(doel: Vector2, kant: int) -> void:
	_kaartje_label.text = _bijschrift(doel)
	_kaartje.size = _kaartje.get_combined_minimum_size()
	# Naar binnen toe uitklappen: aan de rechterrand hangt het kaartje links van
	# de pijl, anders staat de helft ervan buiten beeld.
	_kaartje.position = Vector2(
		4.0 if kant < 0 else -_kaartje.size.x - 4.0, 6.0)
	_kaartje.visible = true


## "De Vloer  27 m". De ruimte zegt waar je heen loopt, de meters zeggen of dat
## de moeite van het rennen waard is.
func _bijschrift(doel: Vector2) -> String:
	var vanaf := speler.global_position if is_instance_valid(speler) else global_position
	var meter := int(round(absf(doel.x - vanaf.x) * meter_per_px))
	if plek == "":
		return "%d m" % meter
	return "%s  %d m" % [plek, meter]


func _draw() -> void:
	if _kant == 0:
		var punten := PackedVector2Array([
			Vector2(-4.0, -5.0), Vector2(4.0, -5.0), Vector2(0.0, 2.0)])
		draw_colored_polygon(punten, UiKit.ORANJE)
		draw_polyline(PackedVector2Array([
			Vector2(-4.0, -5.0), Vector2(4.0, -5.0), Vector2(0.0, 2.0),
			Vector2(-4.0, -5.0)]), UiKit.INK, 1.0)
		return

	# Buiten beeld wijst hij opzij in plaats van omlaag: er staat daar niets om
	# naar te wijzen, dus hij wijst de weg.
	var d := float(_kant)
	var zij := PackedVector2Array([
		Vector2(-5.0 * d, -4.0), Vector2(-5.0 * d, 4.0), Vector2(4.0 * d, 0.0)])
	draw_colored_polygon(zij, UiKit.ORANJE)
	draw_polyline(PackedVector2Array([
		Vector2(-5.0 * d, -4.0), Vector2(-5.0 * d, 4.0),
		Vector2(4.0 * d, 0.0), Vector2(-5.0 * d, -4.0)]), UiKit.INK, 1.0)
