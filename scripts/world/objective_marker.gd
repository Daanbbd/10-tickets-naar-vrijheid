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

## Hoe ver het kaartje onder de pijl hangt, en hoe ver het zijwaarts van de pijl
## af staat. Constanten en geen losse getallen in `_zet_kaartje()`, want
## `_wijk_voor_tikkaartje()` rekent met dezelfde maten: twee plekken die dit
## apart intypen lopen bij de eerste verschuiving uit elkaar.
const KAARTJE_ONDER := 6.0
const KAARTJE_ZIJ := 4.0

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
	var y := _wijk_voor_tikkaartje(x, _geklemde_y(doel.y - HOOGTE), kant)
	global_position = Vector2(x, y + deining)
	_zet_kaartje(doel, kant)


## De doel-Y, teruggebracht tot de band die de HUD vrij laat. Rekent in
## wereldcoördinaten; de HUD antwoordt in canvaspixels, dus de canvastransform
## zit ertussen — dat is dezelfde omrekening die `UiKit.veilige_insets()` doet.
func _geklemde_y(wens: float) -> float:
	var band := _band()
	if band.y <= band.x:
		return band.x
	return clampf(wens, band.x, band.y)


## De band waarin de geklemde pijl mag staan, in wereldcoördinaten. Boven de
## HUD-chips vandaan, onder de knoppenbalk vandaan.
##
## Een lege band (y <= x) betekent "er is geen ruimte"; de aanroeper valt dan
## terug op de bovengrens.
func _band() -> Vector2:
	var vp := get_viewport()
	if vp == null:
		return Vector2(-1e9, 1e9)
	var band := _hud.vrije_band() if is_instance_valid(_hud) else Vector2.ZERO
	var terug := vp.get_canvas_transform().affine_inverse()
	# Ruimte voor het kaartje eronder: dat hangt zes pixels lager en is er
	# ongeveer twintig hoog.
	return Vector2((terug * Vector2(0.0, band.x)).y + 8.0,
		(terug * Vector2(0.0, band.y)).y - 28.0)


## Niet bovenop het bijschrift van `TapMarker` gaan staan.
##
## Die twee kaartjes wisten niets van elkaar, en dat gaat mis in het geval dat
## juist vaak voorkomt: je staat voor een collega ("Praten Willem") terwijl je
## doel elders in het gebouw ligt, dus deze pijl klemt zich tegen de schermrand
## op de hoogte van dat doel. Ligt dat doel op dezelfde tegelrij als waar je
## staat — en de vloer is één lange strook, dus dat is de normale situatie —
## dan komen de twee panelen over elkaar heen.
##
## Deze pijl wijkt en het tikkaartje niet: dat hoort bij het ding waar je vlak
## voor staat en heeft de vaste plek. Hij gaat naar boven of naar onder, welke
## van de twee het dichtst bij de gewenste hoogte blijft en nog binnen de band
## past. Past geen van beide, dan blijft hij staan — de band weegt zwaarder dan
## de overlap, want achter de HUD is hij helemaal niet te zien.
func _wijk_voor_tikkaartje(x: float, y: float, kant: int) -> float:
	var tik := get_tree().get_first_node_in_group(&"tap_marker") as TapMarker
	if tik == null:
		return y
	var bezet := tik.kaartje_rect()
	if bezet.size == Vector2.ZERO:
		return y
	# Het eigen kaartje meet zichzelf in `_zet_kaartje()`, dus deze maat is die
	# van het vorige frame. In het eerste frame is hij nul en gebeurt er niets;
	# een frame later staat hij goed.
	var maat := _kaartje.size
	if maat == Vector2.ZERO:
		return y
	if not _eigen_rect(x, y, maat, kant).intersects(bezet):
		return y

	# `AMPLITUDE` erbij als lucht: de pijl deint op en neer en het kaartje deint
	# met hem mee, dus een uitwijking die exact aansluit zou de overlap elke
	# halve seconde terugbrengen.
	var band := _band()
	var kandidaten: Array[float] = [
		bezet.position.y - KAARTJE_ONDER - maat.y - AMPLITUDE,
		bezet.end.y - KAARTJE_ONDER + AMPLITUDE,
	]
	var beste := y
	var afstand := INF
	for k: float in kandidaten:
		if band.y > band.x and (k < band.x or k > band.y):
			continue
		if _eigen_rect(x, k, maat, kant).intersects(bezet):
			continue
		if absf(k - y) < afstand:
			afstand = absf(k - y)
			beste = k
	return beste


## Waar het eigen kaartje komt te liggen als de pijl op (`x`, `y`) staat.
## Zelfde som als `_zet_kaartje()`, en daarom uit dezelfde constanten.
func _eigen_rect(x: float, y: float, maat: Vector2, kant: int) -> Rect2:
	var dx := KAARTJE_ZIJ if kant < 0 else -maat.x - KAARTJE_ZIJ
	return Rect2(Vector2(x + dx, y + KAARTJE_ONDER), maat)


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
		KAARTJE_ZIJ if kant < 0 else -_kaartje.size.x - KAARTJE_ZIJ, KAARTJE_ONDER)
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
