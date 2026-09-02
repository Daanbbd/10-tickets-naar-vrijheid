extends MinigameBase
## De urenstaat van Dirk (`mg_urenstaat`), en verder niets: elk ander ticket
## heeft inmiddels zijn eigen mechaniek.
##
## F4-a: dit was een sleepspel met 22 elementen en kaartjes van 36×16 px, het
## kleinste interactieve element van het spel. Er was toch al geen goed
## antwoord: elke verdeling wordt aangenomen, zie `_dirk_oordeel()` in
## `ticket_controller.gd`. Dus is de vorm nu een dialoogkeuze: drie
## kant-en-klare tijdverdelingen, kiezen is klikken en niet meer slepen.
##
## De regels van echt werk komen niet uit de data maar uit
## `Session.completed_tickets_in_order()`: de drie opties rekenen hun eigen
## verdeling daarop uit. De data levert alleen de teksten op het scherm.

var _reactie: Label = null
var _knoppen: VBoxContainer = null
var _gekozen: bool = false


func _on_setup() -> void:
	var c := content()
	if c.is_empty():
		fail()
		return

	var body := build_chrome(String(c.get("titel", default_title())), String(c.get("intro", "")))

	var voltooid := Session.completed_tickets_in_order()
	set_status("%d %s afgerond vandaag" % [
		voltooid.size(), "ticket" if voltooid.size() == 1 else "tickets"])

	_knoppen = VBoxContainer.new()
	_knoppen.add_theme_constant_override("separation", 3)
	body.add_child(_knoppen)

	for raw: Variant in c.get("opties", []):
		var o := raw as Dictionary
		var b := UiKit.keuzeknop(String(o.get("tekst", "...")), UiKit.FS_BODY)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_kies.bind(o))
		_knoppen.add_child(b)

	if _knoppen.get_child_count() > 0:
		(_knoppen.get_child(0) as Button).grab_focus()

	_reactie = UiKit.label("", UiKit.FS_SMALL, UiKit.GRIJS_OP_DONKER)
	_reactie.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_reactie)


## Een keuze ligt vast zodra hij valt: nog een keer kiezen (de autopilot roept
## `qa_solve()` elke 0,45 s aan zolang de minigame leeft) mag de eerste keuze
## niet meer overschrijven.
func _kies(o: Dictionary) -> void:
	if _gekozen:
		return
	_gekozen = true
	for k: Node in _knoppen.get_children():
		(k as Button).disabled = true

	var id := String(o.get("id", ""))
	_reactie.text = String(o.get("reactie", ""))
	AudioDirector.play_ui(&"klik")

	await get_tree().create_timer(0.9, true).timeout
	_afronden(id)


## Geen fouten, alleen een keuze die genoteerd wordt. Wat je koos komt in
## MinigameResult.payload terecht en Dirk leest het af — hij accepteert alles.
func _afronden(id: String) -> void:
	var c := content()
	var v := _verdeling(id)
	await finish_with_banner(true, String(c.get("success", "Geboekt.")), int(v.get("geboekt_min", 0)), v)


## Rekent één van de drie tijdverdelingen uit tegen de tickets die vandaag
## echt zijn afgerond. Vast budget (`Urenstaat.BUDGET_MIN`), net als voorheen:
## je vult altijd een volle dag in, ongeacht hoeveel er echt gewerkt is — dat
## boekt `Session.book_time()` al los bij.
func _verdeling(id: String) -> Dictionary:
	var tickets := Session.completed_tickets_in_order()
	var budget := Urenstaat.BUDGET_MIN
	var op_rest := 0
	var leeg := 0

	match id:
		"tickets":
			# Vrijwel alles op het werk zelf. Zonder afgeronde tickets kán dat
			# niet, en valt de hele dag noodgedwongen op overig.
			if tickets.is_empty():
				op_rest = budget
			else:
				for m: int in _verdeel(tickets.size(), budget):
					if m == 0:
						leeg += 1
		"eerlijk":
			# Overleg, kennisdeling en overig tellen mee als drie extra regels
			# naast de tickets, en krijgen ieder een gelijk deel.
			var slots := tickets.size() + 3
			var delen := _verdeel(slots, budget)
			for i: int in tickets.size():
				if delen[i] == 0:
					leeg += 1
			for i: int in range(tickets.size(), slots):
				op_rest += delen[i]
		"overig":
			# Het gros op overig, de rest dun over de tickets — precies de
			# verdeling waar Dirk een vraagteken bij zet (`_dirk_oordeel()`,
			# `rest >= 4 * 60`).
			op_rest = budget if tickets.is_empty() else int(budget * 0.65)
			for m: int in _verdeel(tickets.size(), budget - op_rest):
				if m == 0:
					leeg += 1

	return {
		"keuze": id,
		"geboekt_min": budget,
		"op_rest": op_rest,
		"op_echt_werk": budget - op_rest,
		"lege_tickets": leeg,
	}


## `n` gehele porties van `budget` die er precies optellen: de rest gaat naar
## de laatste portie. Lege array voor `n <= 0`, zodat een dag zonder tickets
## niet deelt door nul.
static func _verdeel(n: int, budget: int) -> Array[int]:
	var uit: Array[int] = []
	if n <= 0:
		return uit
	var basis := budget / n
	for _i: int in n:
		uit.append(basis)
	uit[n - 1] += budget - basis * n
	return uit


## QA: kiest de eerste optie. Dirk accepteert toch alles, dus welke maakt niet uit.
func qa_solve() -> void:
	if _gekozen:
		return
	var opties: Array = content().get("opties", [])
	if opties.is_empty():
		fail()
		return
	_kies(opties[0] as Dictionary)
