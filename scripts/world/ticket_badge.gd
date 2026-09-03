class_name TicketBadge
extends Node2D
## Een briefje dat boven een object zweeft zolang daar werk ligt.
##
## **Waarom dit er moest komen.** Geen van de 41 objecten in `objects.json`
## heeft een eigen sprite: ze zijn onzichtbare interactiepunten die bovenop de
## props uit `floor.json` liggen. Een serverrack met BBD-205 erop ziet er
## daardoor precies zo uit als het rack ernaast dat alleen een grapje is, en
## "de tickets liggen verspreid door het kantoor, vind ze door rond te lopen"
## was een belofte zonder beeld — je liep een ruimte in en er verscheen een
## toast, maar er was nooit iets te zíen.
##
## Dit briefje is dat beeld. Het hangt alleen boven een anker waar op dít
## moment een openstaand ticket ligt, dus het verdwijnt zodra het werk gedaan
## is en het verschijnt pas als het ticket vrijkomt. Daarmee doet het meteen
## het tweede ding dat ontbrak: onderscheid tussen "hier moet je zijn" en "dit
## is aankleding".
##
## Bewust géén sprite uit `assets/`: dit ding moet van kleur en vorm kunnen
## veranderen met de ticketstand, en de generatoren draaien op een Pillow-venv
## die niet overal staat. `_draw()` is hier goedkoper dan een atlas.

## Hoe hoog boven het midden van het object het briefje zweeft.
const HOOGTE := -16.0
## Uitslag en snelheid van het dobberen. Klein genoeg om niet af te leiden,
## groot genoeg om in een stilstaand beeld op te vallen.
const DOBBER := 1.5
const SNELHEID := 2.2

const BREED := 9.0
const HOOG := 9.0
## Hoe groot de omgevouwen punt rechtsonder is.
const VOUW := 3.0

var world_id: StringName = &""

var _t: float = 0.0
var _actief: bool = false


func _ready() -> void:
	# Boven de props en de speler: dit is een wegwijzer, geen meubel. De
	# objectlaag y-sorteert, en een briefje dat achter een bureau verdwijnt is
	# precies zo onzichtbaar als geen briefje.
	z_index = 20
	top_level = false
	_verbind()
	_werk_bij()


## Alles wat de beschikbaarheid van een ticket kan veranderen. `flag_changed`
## zit erbij omdat `available_when` op vlaggen kan staan, niet alleen op
## afgeronde tickets.
func _verbind() -> void:
	Bus.ticket_state_changed.connect(
		func(_a: StringName, _b: GameEnums.TicketState) -> void: _werk_bij())
	Bus.ticket_completed.connect(
		func(_a: StringName, _b: MinigameResult) -> void: _werk_bij())
	Bus.ticket_discovered.connect(func(_a: StringName) -> void: _werk_bij())
	Bus.flag_changed.connect(func(_a: StringName, _b: bool) -> void: _werk_bij())


func _werk_bij() -> void:
	var nu := QuestEngine.preferred_at_anchor(world_id) != null
	if nu == _actief:
		return
	_actief = nu
	visible = nu
	set_process(nu)
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	position.y = HOOGTE + sin(_t * SNELHEID) * DOBBER
	queue_redraw()


## Een post-it met een omgevouwen punt en twee regels tekst erop. Dezelfde
## papierkleur als de briefjes op het ticketbord, zodat het beeld in de wereld
## en het beeld op het bord hetzelfde ding zijn.
func _draw() -> void:
	if not _actief:
		return
	var l := -BREED * 0.5
	var b := -HOOG * 0.5

	# Slagschaduw: zonder deze valt geel papier weg tegen een lichte vloer.
	draw_rect(Rect2(l + 1.0, b + 1.0, BREED, HOOG), Color(0, 0, 0, 0.25))

	# Het blad, met de rechteronderhoek eraf zodat de vouw kan.
	var blad := PackedVector2Array([
		Vector2(l, b),
		Vector2(l + BREED, b),
		Vector2(l + BREED, b + HOOG - VOUW),
		Vector2(l + BREED - VOUW, b + HOOG),
		Vector2(l, b + HOOG),
	])
	draw_colored_polygon(blad, UiKit.POSTIT)
	draw_polyline(blad + PackedVector2Array([Vector2(l, b)]), UiKit.POSTIT_RAND, 1.0)

	# De omgevouwen punt zelf, iets donkerder dan het blad.
	draw_colored_polygon(PackedVector2Array([
		Vector2(l + BREED - VOUW, b + HOOG),
		Vector2(l + BREED, b + HOOG - VOUW),
		Vector2(l + BREED - VOUW, b + HOOG - VOUW),
	]), UiKit.POSTIT_RAND)

	# Twee regels "tekst". Geen echte letters: op negen pixels leest dat als
	# ruis, en twee streepjes lezen als een briefje.
	draw_line(Vector2(l + 2.0, b + 3.0), Vector2(l + BREED - 2.0, b + 3.0),
		UiKit.INK, 1.0)
	draw_line(Vector2(l + 2.0, b + 5.0), Vector2(l + BREED - 3.0, b + 5.0),
		UiKit.INK, 1.0)
