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
##
## F5-b: draait een minigame (`Shell.minigame_active()`), dan is de wereld
## erachter niet zichtbaar — de HUD-toast (laag 10) en de telefoon (laag 30)
## liggen allebei onder de minigame (laag 50). De eenmalige soorten
## (`iets_gaat_stuk`, `ticket_wijzigt`, `afleiding`; zie `_vuur_eenmalig()`)
## routeren hun bericht dan ook naar `MinigameBase.storing()` op
## `Shell.active_minigame()`, naast (niet in plaats van) hun normale
## state-mutatie: die moet altijd hetzelfde gebeuren, gezien of gehoord of
## niet, anders is de wereld geen pure functie van Session meer. `npc_komt_langs`
## doet dit bewust niet mee — zie de klassecommentaar bij `_volg()`.
## Hoogstens één onderbreking per minigame en nooit in de eerste vijf
## seconden: zie `mag_onderbreken_minigame()`.

const STORINGEN_JSON := "res://data/storingen.json"
const SOORTEN: Array[String] = [
	"npc_komt_langs", "iets_gaat_stuk", "ticket_wijzigt", "afleiding",
]
const TRIGGER_KEYS: Array[String] = [
	"min_tickets_done", "na_minuten", "zone", "wachttijd_min",
]

## F5-b: frequentie is een ontwerpknop, geen technische. Een onderbreking die
## je een oplossing kost is chaos; twee die je een oplossing kosten zijn een
## bug — dus hoogstens één per minigame, en de eerste vijf seconden blijven
## sowieso met rust, zodat een speler eerst kan zien wat de opgave is.
const MIN_WACHT_MINIGAME_SEC := 5.0

## Waar de verstreken minuten van vandaag bijgehouden worden, voor
## `wachttijd_min`. In `Session.counters` en niet in een veld hier, zodat een
## wachtende storing de save overleeft. Deze node is de enige schrijver.
const VERSTREKEN_TELLER := &"storing_verstreken_min"

var _defs: Array[Dictionary] = []
var _npc_layer: NpcLayer = null
var _mutator: WorldMutator = null
var _speler: Node2D = null
## Alleen de laatst betreden zone, voor de `zone`-trigger. Geen geschiedenis:
## een storing die "in deze zone" betekent hoeft niet te weten waar je hiervoor
## stond.
var _laatste_zone: StringName = &""

## Of deze minigame-sessie zijn ene onderbreking al gehad heeft, of er überhaupt
## een minigame-sessie loopt om aan te haken, en wanneer die begon (in seconden
## sinds engine-start). Twee losse velden voor "loopt er iets" en "wanneer" —
## en niet één met een negatieve sentinel voor "nog niet begonnen" — want
## `_mg_gestart_op` moet ook een waarde ver in het verleden kunnen dragen
## (`_test_storingen()` zet hem zo terug om de vijf-secondengrens te testen
## zonder er echt vijf seconden op te wachten) zonder dat dat per ongeluk als
## "niet begonnen" leest. Bewust géén Session-state: dit is per-minigame-sessie
## en hoort niet in de save, net als `followers`.
var _mg_onderbroken: bool = false
var _mg_actief: bool = false
var _mg_gestart_op: float = 0.0

## Staat er al een evaluatie klaar voor het einde van deze frame? Zie
## `_plan_evaluatie()`.
var _gepland: bool = false


func setup(npc_layer: NpcLayer, mutator: WorldMutator, speler: Node2D) -> void:
	_npc_layer = npc_layer
	_mutator = mutator
	_speler = speler
	_defs = laad()

	# Alle vier uitgesteld, en met opzet niet met CONNECT_DEFERRED: `zone_entered`
	# moet `_laatste_zone` wél meteen vastleggen, alleen de evaluatie mag wachten.
	Bus.ticket_completed.connect(func(_a: StringName, _b: MinigameResult) -> void: _plan_evaluatie())
	Bus.time_booked.connect(func(m: int, reden: StringName, _c: int) -> void:
		if reden == &"verloop":
			Session.counters[VERSTREKEN_TELLER] = Session.get_counter(VERSTREKEN_TELLER) + m
		_plan_evaluatie())
	Bus.flag_changed.connect(func(_a: StringName, _b: bool) -> void: _plan_evaluatie())
	Bus.zone_entered.connect(func(zid: StringName, _naam: String) -> void:
		_laatste_zone = zid
		_plan_evaluatie())
	Bus.minigame_started.connect(_op_minigame_gestart)
	Bus.minigame_finished.connect(_op_minigame_klaar)

	# Eerst de blijvende gevolgen van al afgegane storingen terugzetten (een
	# geladen speelbeurt kan het serverrack al kapot hebben gemaakt), dan pas
	# evalueren. Zonder die tweede aanroep zou bijvoorbeeld Dirk pas bij de
	# eerstvolgende gebeurtenis beginnen met volgen in plaats van meteen, en
	# een speler die net heeft geladen ziet hem dan een paar seconden ten
	# onrechte stilstaan.
	replay()
	_evalueer()


# --- Onderbreken tijdens een minigame (F5-b) -------------------------------

func _op_minigame_gestart(_id: StringName) -> void:
	_mg_onderbroken = false
	_mg_actief = true
	_mg_gestart_op = Time.get_ticks_msec() / 1000.0


func _op_minigame_klaar(_id: StringName, _result: MinigameResult) -> void:
	_mg_actief = false


## Mag er nu een storing in de actieve minigame landen? `nu` is injecteerbaar
## voor de testsuite (seconden, dezelfde klok als `Time.get_ticks_msec()`);
## leeg laten gebruikt de echte klok.
func mag_onderbreken_minigame(nu: float = -1.0) -> bool:
	if not Shell.minigame_active() or _mg_onderbroken or not _mg_actief:
		return false
	var t := nu if nu >= 0.0 else Time.get_ticks_msec() / 1000.0
	return t - _mg_gestart_op >= MIN_WACHT_MINIGAME_SEC


## Leest de tijdskosten van een storing uit zijn eigen `effects` — geen nieuwe
## grammatica, want `kost_tijd` bestaat al (zie `QuestEngine.run_effects()`).
## Een storing zonder `kost_tijd`-effect (bijvoorbeeld een `reopen_ticket`)
## levert een lege dictionary: de minigame krijgt dan alleen de tekst.
static func _kosten_uit_effects(effects: Array) -> Dictionary:
	for raw: Variant in effects:
		var e := raw as Dictionary
		if e != null and String(e.get("op", "")) == "kost_tijd":
			return {"minuten": int(e.get("minuten", 0)), "reden": String(e.get("reden", ""))}
	return {}


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


## Zet een evaluatie klaar voor het einde van de frame in plaats van hem midden
## in de gebeurtenis te draaien die hem uitlokte.
##
## **Waarom uitgesteld.** `QuestEngine.complete()` stuurt onderweg drie
## signalen uit waar deze node aan hangt: `flag_changed` (uit `run_effects()`,
## voor de drie tickets met een `set_flag`-beloning), `time_booked` (uit de
## urenboeking) en `ticket_completed` aan het eind. Een storing die op zo'n
## signaal afvuurt draait dus *binnen* een afronding die nog niet klaar is.
## `storing_backend_crash` deed precies dat: hij riep `QuestEngine.reopen()`
## aan terwijl `complete()` halverwege stond, dus `Bus.ticket_completed` ging
## uit voor een ticket dat op dat moment alweer AVAILABLE was, en
## `save_to_disk()` schreef het als open weg. Een doorloop eindigde daardoor
## op elf opleveringen voor een dag van tien tickets.
##
## **Waarom gecoalesceerd.** Die drie signalen vallen bij één afronding
## gegarandeerd in dezelfde frame, en dan hoeft de lijst niet drie keer
## langsgelopen te worden. De bool gaat weer open aan het begin van
## `_evalueer()` en niet aan het eind: een storing die zelf een signaal
## veroorzaakt (een `set_flag`, een `kost_tijd`) hoort nog een volgende ronde
## te krijgen.
func _plan_evaluatie() -> void:
	if _gepland:
		return
	_gepland = true
	_evalueer.call_deferred()


func _evalueer() -> void:
	_gepland = false
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
		if not _wachttijd_verstreken(id, trigger):
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


## Een storing die pas "later die dag" hoort te vallen. `wachttijd_min` telt de
## **verstreken** minuten vanaf het moment dat `trigger` en `when` voor het
## eerst allebei klopten.
##
## **Waarom niet `na_minuten`.** Dat is een absoluut tijdstip op de dag, en dat
## geeft geen enkele scheiding zodra de voorwaarde later valt dan dat tijdstip.
## `storing_backend_crash` botste daarop: zijn `when` (t05 is opgelost) wordt
## waar op precies het moment dat zijn `min_tickets_done` al lang klopt, want
## zeven tickets zijn oplosbaar zonder t05. Los je t05 als zevende of later op,
## dan is elke absolute drempel al gepasseerd en valt "BBD-205 staat weer open"
## over de regel "BBD-205 opgelost" heen.
##
## **Waarom verstreken minuten en niet alle geboekte.** Een oplevering boekt er
## 30 tot 45 in één sprong, en die sprong staat ín `QuestEngine.complete()`.
## Elke drempel boven ~20 wordt dus vrijwel altijd overschreden door precies de
## gebeurtenis waarvan deze storing afstand moet houden — de wachttijd meet dan
## feitelijk "één oplevering later" en botst alleen met een andere afronding.
## Dat was aantoonbaar zo: de heropening verschoof van BBD-207 naar BBD-208 en
## bleef in een afrondingsbeat vallen.
##
## De klok-onderstroom (`klok.gd`, één minuut per `Klok.TICK_SEC` reële seconden, reden
## `&"verloop"`) heeft die eigenschap niet, en beter nog: `Klok._process()`
## staat stil zolang `Session.input_locked` waar is en er geen minigame draait.
## Verstreken minuten lopen dus **alleen op terwijl de speler zelf aan zet is**,
## nooit tijdens een dialoog. Daarmee is de scheiding structureel in plaats van
## statistisch: deze storing kán niet meer in de afrondingsdialoog vallen, hij
## valt gegarandeerd terwijl je loopt.
##
## Het ijkpunt gaat in `Session.counters` en dus mee de save in: een storing die
## op zijn wachttijd staat hoort niet opnieuw te beginnen met aftellen omdat de
## speler het spel afsloot.
func _wachttijd_verstreken(id: String, t: Dictionary) -> bool:
	var wacht := int(t.get("wachttijd_min", 0))
	if wacht <= 0:
		return true
	# Twee sleutels, en dat onderscheid is essentieel voor wie hier een tweede
	# storing met een wachttijd bijzet: `VERSTREKEN_TELLER` is één gedeelde
	# teller die de hele dag oploopt, `wacht_teller(id)` is het ijkpunt van
	# déze storing erin. Zonder dat eigen ijkpunt zou een tweede storing meteen
	# afgaan, want de gedeelde teller staat dan al ver voorbij elke drempel.
	var sleutel := wacht_teller(id)
	var nu := Session.get_counter(VERSTREKEN_TELLER)
	# Rechtstreeks in `counters` en niet via `add_counter()`: dit is een ijkpunt
	# dat één keer gezet wordt, geen teller die oploopt.
	if not Session.counters.has(sleutel):
		Session.counters[sleutel] = nu
		return false
	return nu - Session.get_counter(sleutel) >= wacht


static func wacht_teller(id: String) -> StringName:
	return StringName("storing_wacht_%s" % id)


## F5-b: blijft buiten `storing()` om, met opzet. `npc_komt_langs` is geen
## eenmalig bericht maar een doorlopend meelopen — een collega kan uren met je
## meelopen, ophouden, en later weer beginnen als `when` opnieuw waar wordt.
## Er is ook geen apart "hij bereikt je"-moment om aan te haken: de toast
## hieronder valt op het moment dat het volgen BEGINT, niet wanneer hij je
## inhaalt (dat bestaat hier niet). Puur het lopen zelf hoeft de wereld tijdens
## een minigame niet te missen — de collega beweegt gewoon door (F5-a laat de
## wereld nu doorlopen), en dat is precies het soort chaos die deze stap wil.
## Alleen als deze mechaniek ooit een echt "collega bereikt je"-beat krijgt,
## hoort díe beat via `storing()` te lopen.
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

	# F5-b: dezelfde mutatie hierboven, maar het bericht erover moet landen
	# waar de speler kijkt. `run_effects()` kan al een toast sturen (de
	# "toast"-effect-op) — die blijft ongemoeid vuren (nul nieuwe grammatica),
	# maar is onzichtbaar achter een open minigame. Dan landt de tekst extra
	# in het minigameframe zelf.
	if mag_onderbreken_minigame():
		var actief := Shell.active_minigame()
		if actief != null:
			actief.storing(String(d.get("dialogue", "")), _kosten_uit_effects(d.get("effects", []) as Array))
			_mg_onderbroken = true


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
