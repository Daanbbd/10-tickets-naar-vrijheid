class_name DeployStraat
extends Control
## De visuele strook van "De oplevering" (BBD-210, race-vorm): de deploy rijdt
## over de CI/CD-straat, achtervolgd door een brandende laag. Deze node tekent
## zichzelf en kent geen kinderen — dat scheelt layoutkosten op een canvas dat
## nog maar 9 px speling heeft (192x416, `docs/AUDIT-2026-09-07-MINIGAMES.md`).
##
## Zelfstandig bestand: de rekenkern (voortgang/vuur) en de integratie in het
## scherm zijn andermans taak. Deze node bewaart alleen wat hij moet tekenen en
## kent geen `Session`, geen signalen naar buiten, geen Tween — een gekillde
## Tween waarop iets `await`t is de bekende vastloper van dit project
## (`docs/`, "De vastloper"), dus hobbel en flikkering lopen hier via
## `_process()` en eigen velden die vanzelf uitdoven.
##
## Binnenbreedte ligt in de praktijk rond 168 px (een paneel met 2 px marge),
## maar elke afmeting hieronder rekent met `size.x`/`size.y` — nooit een
## hardcoded breedte.

const _HOOGTE := 28.0

## Wegvlak: een baan met wat lucht erboven en eronder voor de hobbel van de
## wagen en de vlamtongen van het vuur.
const _WEG_TOP := 8.0
const _WEG_ONDER := 24.0

## De wagen: een kort blok met een lichter "dak" erop, net zo breed als een
## ticket-badge maar dan liggend.
const _WAGEN_BREED := 26.0
const _WAGEN_HOOG := 12.0
const _WAGEN_DAK_HOOG := 4.0

## De finish: een geblokt lint vlak voor de rechterrand.
const _FINISH_BREED := 10.0
const _FINISH_VAK := 3.0

## Wegmarkering: korte streepjes op het midden van de baan.
const _STREEP_BREED := 6.0
const _STREEP_GAT := 6.0
const _STREEP_DIK := 2.0

## Hobbel: een korte veer die na `hobbel()` binnen ongeveer een kwart seconde
## uitdooft. Kritisch gedempt aanvoelen zonder een echte veerberekening: gewoon
## exponentieel laten verdwijnen is hier goedkoop genoeg en niemand meet het na.
const _HOBBEL_DEMPING := 14.0

## Flikkersnelheid van het vuur en van het alarm-wegvlak.
const _FLIKKER_SNELHEID := 13.0


var _voortgang: float = 0.0
var _vuur: float = 0.0
var _alarm: bool = false
var _brandt: bool = false

var _hobbel: float = 0.0
var _t: float = 0.0

## Kort groen glimlicht na `toon_over()`; loopt in `_process()` terug naar 0.
var _over_gloed: float = 0.0
const _OVER_DUUR := 0.6


func _init() -> void:
	custom_minimum_size = Vector2(0, _HOOGTE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Bewaart voortgang, vuur en alarmstatus en tekent opnieuw. `voortgang` en
## `vuur` zijn de genormaliseerde (0..1) posities van de deploy en van de
## voorkant van het vuur; beide worden geklemd, zodat een rekenfout in de kern
## hier nooit een tekening buiten de strook oplevert.
func zet(voortgang: float, vuur: float, alarm: bool) -> void:
	_voortgang = clampf(voortgang, 0.0, 1.0)
	_vuur = clampf(vuur, 0.0, 1.0)
	_alarm = alarm
	queue_redraw()


## Een korte verticale veer op de wagen. `kracht` is de uitwijking in
## canvaspixels bij de eerste tik; hij dooft daarna vanzelf uit in `_process()`.
func hobbel(kracht: float = 3.0) -> void:
	_hobbel = kracht


## De streep is gehaald: een kort groen gloeien over de strook.
func toon_over() -> void:
	_over_gloed = _OVER_DUUR


## De wagen staat in de vlammen. Blijft aan tot de volgende `zet()` — er is
## bewust geen tegenhanger "toon_niet_meer_brandt": de aanroeper regelt dat via
## een volgende `zet()`-cyclus vanuit de rekenkern.
func toon_brandt() -> void:
	_brandt = true


func _process(delta: float) -> void:
	var iets_beweegt := false

	if _hobbel != 0.0:
		_hobbel = lerpf(_hobbel, 0.0, minf(1.0, delta * _HOBBEL_DEMPING))
		if absf(_hobbel) < 0.05:
			_hobbel = 0.0
		iets_beweegt = true

	if _over_gloed > 0.0:
		_over_gloed = maxf(0.0, _over_gloed - delta)
		iets_beweegt = true

	# Flikkering loopt alleen door als er iets is om te flikkeren: vuur zichtbaar,
	# alarm aan, of de wagen staat in brand. Anders tikt _t voor niets door.
	if _vuur > 0.0 or _alarm or _brandt:
		_t += delta
		iets_beweegt = true

	if iets_beweegt:
		queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var flikker := 0.5 + 0.5 * sin(_t * _FLIKKER_SNELHEID)

	_teken_weg(w, h, flikker)
	_teken_finish(w, h)
	_teken_vuur(w, h, flikker)
	_teken_wagen(w, h)
	if _over_gloed > 0.0:
		_teken_over_gloed(w, h)


func _teken_weg(w: float, h: float, flikker: float) -> void:
	var baan := Rect2(0.0, _WEG_TOP, w, _WEG_ONDER - _WEG_TOP)
	var kleur := UiKit.LINE
	if _alarm:
		kleur = UiKit.LINE.lerp(UiKit.ROOD_OP_LICHT, 0.35 + 0.35 * flikker)
	draw_rect(baan, kleur)

	# Wegmarkering: streepjes op het midden van de baan, doorlopend over de
	# breedte in plaats van gekoppeld aan de voortgang — dit is de weg zelf,
	# niet een afstandsmeter.
	var midden_y := _WEG_TOP + (_WEG_ONDER - _WEG_TOP) * 0.5 - _STREEP_DIK * 0.5
	var streep := UiKit.GRIJS
	var x := 2.0
	var stap := _STREEP_BREED + _STREEP_GAT
	while x < w - _FINISH_BREED:
		draw_rect(Rect2(x, midden_y, _STREEP_BREED, _STREEP_DIK), streep)
		x += stap


func _teken_finish(w: float, h: float) -> void:
	var links := w - _FINISH_BREED
	var y := _WEG_TOP
	var rij := 0
	while y < _WEG_ONDER:
		var vak_h := minf(_FINISH_VAK, _WEG_ONDER - y)
		var kol := 0
		var x := links
		while x < w:
			var vak_w := minf(_FINISH_VAK, w - x)
			var wit := (rij + kol) % 2 == 0
			draw_rect(Rect2(x, y, vak_w, vak_h), Color.WHITE if wit else Color.BLACK)
			x += _FINISH_VAK
			kol += 1
		y += _FINISH_VAK
		rij += 1


func _teken_vuur(w: float, h: float, flikker: float) -> void:
	var breedte := _vuur * w
	if breedte <= 0.0:
		return
	# Twee lagen kartels: rood achter (iets hoger, trager), oranje ervoor (iets
	# lager, feller). De kartelhoogte flikkert mee met sin(_t * snelheid), zodat
	# het vuur ademt zonder een Tween nodig te hebben.
	var basis_y := _WEG_ONDER + 2.0
	_teken_vlam_laag(breedte, basis_y, 10.0, 0.6, UiKit.ROOD, flikker)
	_teken_vlam_laag(breedte, basis_y, 7.0, 1.0, UiKit.ORANJE, 1.0 - flikker)


func _teken_vlam_laag(breedte: float, basis_y: float, piek: float, fase: float,
		kleur: Color, flikker: float) -> void:
	var punten := PackedVector2Array()
	punten.append(Vector2(0.0, basis_y))
	var tanden := maxi(2, int(breedte / 8.0))
	for i: int in tanden + 1:
		var fx := float(i) / float(tanden)
		var x := fx * breedte
		var golf := sin(fx * TAU * 2.0 + _t * _FLIKKER_SNELHEID * fase)
		var tand_hoog := piek * (0.55 + 0.45 * golf) * (0.7 + 0.3 * flikker)
		var y := basis_y - maxf(1.0, tand_hoog)
		punten.append(Vector2(x, y))
	punten.append(Vector2(breedte, basis_y))
	draw_colored_polygon(punten, kleur)


func _teken_wagen(w: float, h: float) -> void:
	var x := lerpf(4.0, w - _WAGEN_BREED - 4.0, _voortgang)
	var y := _WEG_TOP + (_WEG_ONDER - _WEG_TOP - _WAGEN_HOOG) * 0.5
	y += _hobbel

	var kleur := UiKit.ROOD if _brandt else UiKit.BLUEBIRD_BRIGHT
	var romp := Rect2(x, y, _WAGEN_BREED, _WAGEN_HOOG)
	draw_rect(romp, kleur)

	var dak := Rect2(x + 3.0, y - _WAGEN_DAK_HOOG, _WAGEN_BREED - 6.0, _WAGEN_DAK_HOOG)
	draw_rect(dak, kleur.lightened(0.35) if not _brandt else kleur.lightened(0.2))


func _teken_over_gloed(w: float, h: float) -> void:
	var alpha := clampf(_over_gloed / _OVER_DUUR, 0.0, 1.0)
	var gloed := UiKit.GROEN
	gloed.a = 0.55 * alpha
	draw_rect(Rect2(0.0, _WEG_TOP - 2.0, w, _WEG_ONDER - _WEG_TOP + 4.0), gloed)
