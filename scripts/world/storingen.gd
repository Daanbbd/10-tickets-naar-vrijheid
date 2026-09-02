class_name Storingen
extends Node
## Generaliseert "storingen": onderbrekingen die het kantoor je stuurt.
##
## Dirk was de eerste en enige, hardcoded op zijn naam in main.gd. Deze node
## maakt daar een databestand van (data/storingen.json). Drie soorten uit het
## plan, plus één optionele:
##
##   npc_komt_langs  - een collega volgt je zolang `when` klopt (Dirk-model).
##                      Niets nieuws: Conditions.check() plus
##                      Npc.start_following()/stop_following().
##   iets_gaat_stuk   - eenmalige wereldverandering + state-mutatie. Draait
##                      precies één keer per speelbeurt, bewaakt door deze
##                      node zelf en niet door de dataschrijver.
##   ticket_wijzigt   - zelfde eenmalige mechanisme, andere betekenis.
##   afleiding        - optioneel ("weekend maakt lawaai"): kost tijd, geen
##                       wereldverandering. Zelfde eenmalige mechanisme.
##
## `trigger` bepaalt WANNEER geëvalueerd wordt, `when` OF het dan afgaat.
## `trigger` is met opzet een eigen klein format en geen Conditions-grammatica:
## het gaat over een moment ("vanaf hier"), niet over een toestand. `when`,
## `effects` en `world_changes` zijn dat wel, en hergebruiken volledig wat er
## al is: Conditions.check(), QuestEngine.run_effects(), WorldMutator.apply().
## Nul nieuwe grammatica daar.
##
## Harde regel, letterlijk uit het faalbeleid: een storing kost tijd en
## informatie, nooit voortgang. Geen enkele storing zet hier een ticket naar
## LOCKED of sluit een deur — QuestEngine.reopen() gaat bewust naar AVAILABLE.

const STORINGEN_JSON := "res://data/storingen.json"
const SOORTEN: Array[String] = [
	"npc_komt_langs", "iets_gaat_stuk", "ticket_wijzigt", "afleiding",
]
const TRIGGER_KEYS: Array[String] = ["min_tickets_done", "na_minuten", "zone"]

var _defs: Array[Dictionary] = []
var _npc_layer: NpcLayer = null
var _mutator: WorldMutator = null
var _speler: Node2D = null
## Alleen de laatst betreden zone, voor de `zone`-trigger. Geen geschiedenis:
## een storing die "in deze zone" betekent hoeft niet te weten waar je hiervoor
## stond.
var _laatste_zone: StringName = &""


func setup(npc_layer: NpcLayer, mutator: WorldMutator, speler: Node2D) -> void:
	_npc_layer = npc_layer
	_mutator = mutator
	_speler = speler
	_defs = laad()

	Bus.ticket_completed.connect(func(_a: StringName, _b: MinigameResult) -> void: _evalueer())
	Bus.time_booked.connect(func(_a: int, _b: StringName, _c: int) -> void: _evalueer())
	Bus.flag_changed.connect(func(_a: StringName, _b: bool) -> void: _evalueer())
	Bus.zone_entered.connect(func(zid: StringName, _naam: String) -> void:
		_laatste_zone = zid
		_evalueer())

	# Eerst de blijvende gevolgen van al afgegane storingen terugzetten (een
	# geladen speelbeurt kan het serverrack al kapot hebben gemaakt), dan pas
	# evalueren. Zonder die tweede aanroep zou bijvoorbeeld Dirk pas bij de
	# eerstvolgende gebeurtenis beginnen met volgen in plaats van meteen, en
	# een speler die net heeft geladen ziet hem dan een paar seconden ten
	# onrechte stilstaan.
	replay()
	_evalueer()


## Herbouwt de zichtbare gevolgen van storingen die deze speelbeurt al zijn
## afgegaan. Zelfde reden als WorldMutator.replay_all(): de wereld is een pure
## functie van Session, dus zonder dit staat een herladen server weer groen
## terwijl de speler hem al kapot had gemaakt.
func replay() -> void:
	for d: Dictionary in _defs:
		var id := String(d.get("id", ""))
		if id == "" or String(d.get("soort", "")) == "npc_komt_langs":
			continue
		if Session.get_flag(gevuurd_vlag(id)):
			_mutator.apply(d.get("world_changes", []) as Array, false)


static func laad() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not FileAccess.file_exists(STORINGEN_JSON):
		return out
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(STORINGEN_JSON))
	for raw: Variant in (parsed as Array if parsed is Array else []):
		var d := raw as Dictionary
		if d != null:
			out.append(d)
	return out


func _evalueer() -> void:
	for d: Dictionary in _defs:
		var trigger := d.get("trigger", {}) as Dictionary
		if String(d.get("soort", "")) == "npc_komt_langs":
			var moet_volgen := _trigger_klopt(trigger) \
				and Conditions.check(d.get("when", {}) as Dictionary)
			_volg(d, moet_volgen)
			continue

		var id := String(d.get("id", ""))
		if id == "" or Session.get_flag(gevuurd_vlag(id)):
			continue
		if not _trigger_klopt(trigger):
			continue
		if not Conditions.check(d.get("when", {}) as Dictionary):
			continue
		_vuur_eenmalig(d)


func _trigger_klopt(t: Dictionary) -> bool:
	if t.is_empty():
		return true
	if t.has("min_tickets_done") and Session.done_count() < int(t["min_tickets_done"]):
		return false
	if t.has("na_minuten") and Session.worked_minutes < int(t["na_minuten"]):
		return false
	if t.has("zone") and _laatste_zone != StringName(String(t["zone"])):
		return false
	return true


func _volg(d: Dictionary, moet_volgen: bool) -> void:
	if _npc_layer == null:
		return
	var npc := _npc_layer.find_npc(StringName(d.get("npc", "")))
	if npc == null:
		return
	if moet_volgen:
		if not npc.is_following():
			npc.start_following(_speler)
			var tekst := String(d.get("dialogue", ""))
			if tekst != "":
				Bus.toast_requested.emit(tekst, &"tijd")
	elif npc.is_following():
		npc.stop_following(true)


## Zet de vlag vóór de effecten draaien, niet erna: een effect kan zelf weer
## een gebeurtenis veroorzaken die `_evalueer()` opnieuw aanroept (bijvoorbeeld
## `reopen_ticket`, via Bus.ticket_state_changed elders in de wereld), en dan
## mag deze storing zichzelf niet in dezelfde adem opnieuw afvuren.
func _vuur_eenmalig(d: Dictionary) -> void:
	Session.set_flag(gevuurd_vlag(String(d.get("id", ""))), true)
	QuestEngine.run_effects(d.get("effects", []) as Array)
	if _mutator != null:
		_mutator.apply(d.get("world_changes", []) as Array, true)


static func gevuurd_vlag(id: String) -> StringName:
	return StringName("storing_gevuurd_%s" % id)


# --- Validatie (voor de testsuite) ----------------------------------------

static func unknown_soort(soort: String) -> bool:
	return not (soort in SOORTEN)


static func unknown_trigger_keys(t: Dictionary) -> Array[String]:
	var bad: Array[String] = []
	for k: Variant in t.keys():
		if not (String(k) in TRIGGER_KEYS):
			bad.append(String(k))
	return bad
