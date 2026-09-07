class_name Ontwarring
extends GridContainer
## Het raster van door elkaar gestuurde berichtfragmenten in "De oplevering".
##
## Jonathan zat op Claude te wachten en las ondertussen zijn moeder: drie
## gesprekken staan door elkaar in zijn berichten, en de speler moet de
## werk-fragmenten eruit tikken. Dit bestand is alleen het weergavecomponent —
## welk fragment het juiste antwoord is en wat een misser kost, zit in
## `BrandjesModel` en de aanroeper. Dit component weet zelf niet welk
## fragment "werk" is; het toont knoppen en meldt alleen welke is ingedrukt.
##
## Komt op de plek van het zevenknoppen-raster van de finale
## (`mg_oplevering._bouw_knoppen()`) en volgt daarom hetzelfde recept: een
## `GridContainer` met twee kolommen en `UiKit.keuzeknop()`-knoppen, krappe
## separations. Dat raster heeft daar 126 px om drie rijen van 40 px te
## vullen — een harde grens, want de finale mag geen scrollbalk krijgen.

## Fragment ingedrukt; `id` is exact het fragment-id uit `toon()`.
signal gekozen(id: StringName)

## Hoe lang een foute tik rood oplicht voordat de knop weer gewoon oogt. Kort:
## een misser mag de puzzel niet vertragen, alleen even terugkoppelen.
const FLITS_DUUR := 0.35

## Knop per fragment-id, zodat `markeer()` precies dat ene fragment kan
## aanspreken zonder het raster opnieuw op te bouwen.
var _knoppen: Dictionary = {}   # StringName -> Button

## Eén rode-flits-tween per knop, bewaard zodat een tweede misser op dezelfde
## knop de vorige flits killt in plaats van ermee te vechten om `"normal"`.
## Nooit ge-awaited (zie `_test_geen_await_op_killbare_tween`): een tik die
## snel na elkaar twee keer mist, mag de vorige animatie gewoon afbreken.
var _flits_tweens: Dictionary = {}   # Button -> Tween


func _init() -> void:
	columns = 2
	# Zelfde krappe tussenruimte als het handelingenraster dat dit component
	# vervangt: bij twee kolommen en drie rijen telt elke pixel mee voor de
	# grens van ~126 px.
	add_theme_constant_override("h_separation", 2)
	add_theme_constant_override("v_separation", 2)


## Bouwt het raster opnieuw op uit `fragmenten`. Elk element is minstens
## `{"id": ..., "tekst": ...}`. Een eventuele sleutel `werk` wordt bewust
## genegeerd: dat is het antwoord, en dit component mag de puzzel niet
## verklappen door 'm anders te tekenen.
func toon(fragmenten: Array[Dictionary]) -> void:
	_ruim_op()
	visible = true
	var eerste_knop: Button = null
	for raw: Dictionary in fragmenten:
		var id := StringName(raw.get("id", ""))
		var tekst := String(raw.get("tekst", ""))
		# `keuzeknop()` en niet `button()`: die past zich aan de kolombreedte
		# aan en breekt af in plaats van de knop breder te trekken dan het
		# raster toestaat — precies wat een fragment van twee regels nodig
		# heeft binnen de 40px-rijhoogte.
		var knop := UiKit.keuzeknop(tekst, UiKit.FS_SMALL)
		knop.focus_mode = Control.FOCUS_ALL
		knop.pressed.connect(_op_ingedrukt.bind(id))
		add_child(knop)
		_knoppen[id] = knop
		if eerste_knop == null:
			eerste_knop = knop
	# Toetsenbordbediening is hier natuurlijk (het is tenslotte een keuze uit
	# een lijst); de eerste knop krijgt daarom focus. `call_deferred`, want
	# vlak na `add_child` zit deze knop nog niet met zekerheid in een venster
	# dat focus kan uitdelen.
	if eerste_knop != null:
		eerste_knop.call_deferred("grab_focus")


## Geeft één fragment terugkoppeling. Juist: het blijft staan, wordt groen en
## is niet meer indrukbaar. Fout: kort rood, maar blijft indrukbaar — een
## misser mag de puzzel niet onoplosbaar maken.
func markeer(id: StringName, juist: bool) -> void:
	if not _knoppen.has(id):
		return
	var knop: Button = _knoppen[id]
	if juist:
		knop.disabled = true
		knop.add_theme_stylebox_override("disabled", UiKit.panel(UiKit.GROEN_TINT, UiKit.GROEN_OP_LICHT))
		knop.add_theme_color_override("font_disabled_color", UiKit.GROEN_OP_LICHT)
	else:
		_flits_rood(knop)


## Maakt het raster leeg en verbergt het component.
func sluit() -> void:
	_ruim_op()
	visible = false


func _op_ingedrukt(id: StringName) -> void:
	gekozen.emit(id)


## Zet de knop kort rood via een bewaarde tween, zonder er ooit op te wachten.
## Een tweede misser op dezelfde knop killt de vorige flits eerst: anders
## vechten twee tweens om dezelfde `"normal"`-stylebox en wint willekeurig wie
## als laatste zijn callback vuurt.
func _flits_rood(knop: Button) -> void:
	var bestaande: Tween = _flits_tweens.get(knop)
	if bestaande != null and bestaande.is_valid():
		bestaande.kill()
	knop.add_theme_stylebox_override("normal", UiKit.panel(UiKit.PANEL, UiKit.ROOD_OP_LICHT, 2))
	var tw := create_tween()
	_flits_tweens[knop] = tw
	tw.tween_interval(FLITS_DUUR)
	tw.tween_callback(_herstel_normaal.bind(knop))


## Haalt de rode rand er weer af — via `tween_callback`, nooit via
## `await tw.finished`: deze tween kan door een volgende misser gekilld
## worden (zie `_flits_rood`), en een gekillde Tween emit `finished` nooit
## meer.
func _herstel_normaal(knop: Button) -> void:
	if is_instance_valid(knop):
		knop.remove_theme_stylebox_override("normal")


## Kinderen eerst uit de boom halen en dan pas `queue_free()`: zo geeft een
## tweede `toon()` vlak na de eerste nooit twee knoppen voor hetzelfde
## fragment, ook al is de vrijgave van de oude knoop nog niet verwerkt.
func _ruim_op() -> void:
	for tw: Variant in _flits_tweens.values():
		if tw != null and (tw as Tween).is_valid():
			(tw as Tween).kill()
	_flits_tweens.clear()
	for kind: Node in get_children():
		remove_child(kind)
		kind.queue_free()
	_knoppen.clear()


func _exit_tree() -> void:
	for tw: Variant in _flits_tweens.values():
		if tw != null and (tw as Tween).is_valid():
			(tw as Tween).kill()
