class_name QuestEngine
extends RefCounted
## Ticketstroom-logica en state-effecten. Volledig statisch en scene-loos, dus
## headless testbaar. Alle state leeft in de Session-autoload.
##
## Strikte scheiding:
##   run_effects()  -> state-mutaties, draaien exact een keer
##   world_changes  -> visueel, idempotent (zie WorldMutator)

const EFFECT_OPS: Array[String] = [
	"set_flag", "add_item", "remove_item", "add_counter",
	"unlock_ticket", "toast", "cue", "kost_tijd", "reopen_ticket",
]

## De ops die bij twee keer draaien een ánder resultaat geven. Alles wat hier
## niet in staat is idempotent (`set_flag`, `unlock_ticket`, `reopen_ticket`)
## of puur presentatie (`toast`, `cue`), en mag dus zonder bezwaar opnieuw.
##
## `kost_tijd` staat er bewust NIET in: dat is geen beloning maar een prijs, en
## opnieuw werken kost opnieuw tijd.
const NIET_HERHAALBARE_OPS: Array[String] = ["add_item", "remove_item", "add_counter"]


# --- Ticketstroom ---------------------------------------------------------

## De enige manier om een speelbeurt te beginnen. Personage kiezen en de
## tickets op hun beginstaat zetten horen bij elkaar: stonden ze los, dan kon
## een startroute de tweede vergeten. Dan blijft elk ticket LOCKED, zegt elk
## object "hier is nu niets te doen", start er nooit een minigame en meldt de
## hint dat alles al opgelost is. De pijl wijst hier de goede kant op —
## QuestEngine kent Session, niet andersom.
static func start_run(chosen: StringName) -> void:
	Session.start_new(chosen)
	initialise_tickets()


## Zet alle tickets op hun beginstaat. Tickets zonder available_when starten open.
static func initialise_tickets() -> void:
	for id: StringName in GameData.ticket_ids():
		Session.ticket_states[id] = GameEnums.TicketState.LOCKED
	refresh_availability()


## Promoveert LOCKED -> AVAILABLE zodra available_when klopt. Idempotent.
##
## **Alleen omhoog, en dat is opzet.** De `continue` hieronder slaat alles over
## dat niet LOCKED is, dus deze functie kan een ticket nooit terugzetten. Dat is
## precies wat de ticketketen veilig maakt: staat t01 open omdat t08 klaar was,
## en wordt t08 daarna heropend door een storing, dan blijft t01 open. Haalt
## iemand die `continue` weg om "de conditie klopt niet meer" af te dwingen, dan
## wordt een heropening ineens progressieverlies — en dat verbiedt het
## faalbeleid in `docs/GAME_DESIGN.md`.
static func refresh_availability() -> void:
	for id: StringName in GameData.ticket_ids():
		if Session.ticket_state(id) != GameEnums.TicketState.LOCKED:
			continue
		var t: TicketDef = GameData.ticket(id)
		if t == null:
			continue
		if Conditions.check(t.available_when):
			_set_state(id, GameEnums.TicketState.AVAILABLE)


## Het ticket dat dit ticket nog tegenhoudt, of null. Leest de blokkade uit
## `available_when` en niet uit losse data: die conditie ís de reden, dus een
## aparte tekst per ticket zou er alleen naast kunnen komen te staan.
##
## Geeft het eerste nog niet opgeleverde ticket uit `tickets_done` terug — bij
## één blokkade is dat de blokkade, en meer dan één heeft geen ticket.
static func blokkerend_ticket(id: StringName) -> TicketDef:
	var t: TicketDef = GameData.ticket(id)
	if t == null:
		return null
	for raw: Variant in (t.available_when.get("tickets_done", []) as Array):
		var nodig := StringName(raw)
		if not Session.is_done(nodig):
			return GameData.ticket(nodig)
	return null


## Hoeveel tickets er nog af moeten voordat dit ticket opengaat. 0 als er geen
## `min_tickets_done` op staat of als de drempel al gehaald is. Voor de finale,
## die niet op één ticket wacht maar op de hele dag.
static func blokkerend_aantal(id: StringName) -> int:
	var t: TicketDef = GameData.ticket(id)
	if t == null:
		return 0
	return maxi(0, int(t.available_when.get("min_tickets_done", 0)) - Session.done_count())


static func unlock(id: StringName) -> void:
	if Session.ticket_state(id) == GameEnums.TicketState.LOCKED:
		_set_state(id, GameEnums.TicketState.AVAILABLE)


## Een opgeleverd ticket terug naar TO DO — "iets gaat stuk" uit een storing.
## `docs/GAME_DESIGN.md` staat dit expliciet toe: falen (of hier, pech) kost
## nooit voortgang, alleen tijd. Gaat terug naar AVAILABLE en niet LOCKED: het
## was al opgelost, dus het hoort weer meteen oppakbaar te zijn, niet opnieuw
## achter een available_when te zitten dat misschien niet meer klopt.
##
## Haalt het ook uit done_order, want anders blijft het meetellen voor
## done_count()/all_done() terwijl het weer open op de vloer ligt.
##
## Zet `alle_tickets_klaar` ook weer uit. Die vlag was eenrichting — hij ging
## in `complete()` aan en nooit meer uit — terwijl `all_done()` er wél op terug
## kan. De voordeur leest `Session.all_done()` en zat dus goed, maar zes
## dialoogvarianten in `data/dialogue/wereld.json` lezen de vlag, en die zouden
## over een afgeronde dag praten terwijl de deur dicht blijft.
static func reopen(id: StringName) -> void:
	if Session.ticket_state(id) != GameEnums.TicketState.DONE:
		return
	Session.done_order.erase(id)
	_set_state(id, GameEnums.TicketState.AVAILABLE)
	if not Session.all_done():
		Session.set_flag(&"alle_tickets_klaar", false)


static func activate(id: StringName) -> void:
	# Er met je neus bovenop staan telt als vinden, ook als je de zone-melding
	# gemist hebt (of als QA je er rechtstreeks naartoe zet).
	Session.discover(id)
	if Session.ticket_state(id) == GameEnums.TicketState.AVAILABLE:
		_set_state(id, GameEnums.TicketState.ACTIVE)


## Kan het gekozen personage dit ticket zelf oplossen, of moet er een collega bij?
## Een ticket zonder eigenaar (de finale) is voor iedereen eigen werk: elk
## personage krijgt daar zijn eigen variant van.
static func is_own_expertise(id: StringName) -> bool:
	var t: TicketDef = GameData.ticket(id)
	if t == null:
		return false
	if t.owner_character == &"":
		return true
	return t.owner_character == Session.character_id


static func helper_flag(id: StringName) -> StringName:
	return StringName("helper_bij_%s" % id)


## Hier en niet in de TicketController, want deze functie heeft drie aanroepers
## (de controller, --playthrough en de testsuite) en alleen zo telt een
## geautomatiseerde doorloop de ophaaltijd ook mee.
##
## set_flag is idempotent maar een boeking niet, dus die wacht staat hier zelf.
static func mark_helper_present(id: StringName) -> void:
	if Session.get_flag(helper_flag(id)):
		return
	Session.set_flag(helper_flag(id), true)
	Session.book_time(Urenstaat.OPHALEN_MIN, &"ophalen")


## Zijn de voorwaarden vervuld om de minigame te mogen starten?
static func requirements_met(id: StringName) -> bool:
	var t: TicketDef = GameData.ticket(id)
	if t == null:
		return false
	if not Conditions.check(t.requirements):
		return false
	if is_own_expertise(id):
		return true
	return Session.get_flag(helper_flag(id))


## Welke collega moet je ophalen voor dit ticket? Leeg = niemand.
static func required_helper(id: StringName) -> StringName:
	var t: TicketDef = GameData.ticket(id)
	if t == null or is_own_expertise(id):
		return &""
	return StringName("npc_%s" % t.owner_character)


## Hoe de collega van dit ticket ervoor staat. De HUD, het scrumbord en de hint
## lezen hier alle drie uit, zodat "Willem loopt mee" overal tegelijk verschijnt
## in plaats van op één plek 2,6 seconden lang.
##
## MEE gaat vóór GEWEEST: loopt hij toevallig allebei, dan is "hij is hier" de
## bruikbaarder zin.
static func helper_stand(id: StringName) -> GameEnums.HelperStand:
	if is_own_expertise(id):
		return GameEnums.HelperStand.EIGEN
	if Session.is_following(required_helper(id)):
		return GameEnums.HelperStand.MEE
	if Session.get_flag(helper_flag(id)):
		return GameEnums.HelperStand.GEWEEST
	return GameEnums.HelperStand.NODIG


static func complete(id: StringName, result: MinigameResult) -> void:
	if Session.is_done(id):
		return
	var t: TicketDef = GameData.ticket(id)
	if t == null:
		push_error("QuestEngine: onbekend ticket '%s'" % id)
		return

	_set_state(id, GameEnums.TicketState.DONE)
	if not (id in Session.done_order):
		Session.done_order.append(id)
	# De keuze is uitgevoerd; laat hem los zodat de doelregel niet naar een
	# opgelost ticket blijft wijzen.
	if Session.is_pinned(id):
		Session.unpin()

	# Tweede oplevering van hetzelfde ticket (na een `reopen()` uit een storing)
	# deelt de beloning niet opnieuw uit. De wacht bovenaan is `is_done()`, en
	# die staat na een heropening weer op false, dus zonder dit draaide
	# `run_effects()` een tweede keer: elke doorloop eindigde met `productdata`
	# op aantal 2. De klassecommentaar bovenaan belooft "draaien exact een keer"
	# en dat was dus niet waar.
	#
	# Alleen de niet-idempotente ops worden overgeslagen — zie
	# `NIET_HERHAALBARE_OPS`. `toast` en `cue` moeten juist wél opnieuw, anders
	# krijgt de speler bij zijn tweede oplevering geen enkele bevestiging, en
	# `kost_tijd` ook: opnieuw werken kost opnieuw tijd, en tijd is geen
	# beloning maar een prijs.
	var eerder_beloond := id in Session.beloond
	run_effects(t.reward_effects, eerder_beloond)
	if not eerder_beloond:
		Session.beloond.append(id)

	# Blijft staan naast de afgeleide `available_when` in de ticketdata: een
	# `unlock_ticket`-effect elders (De Klant trekt in `klant_berichten.json`
	# t07 en t01 naar voren) is een tweede, bewuste route.
	for u: StringName in t.unlocks:
		unlock(u)

	# Vóór de save, anders is het crash-vangnet altijd een ticket achter. Kan
	# bewust niet uit de data komen: reward_effects is per ticket identiek voor
	# elk personage en kent geen `when`, terwijl de prijs afhangt van of dit
	# jouw vakgebied was. Code boekt wat het systeem kost, data wat een scène kost.
	Session.book_time(Urenstaat.kosten_voor_ticket(is_own_expertise(id)), &"ticket")

	# Vóór het signaal en vóór de save: een luisteraar op ticket_completed —
	# de HUD, het eindscherm, de telefoon van De Klant — hoort de gevolgen van
	# dit ticket al te kunnen lezen, niet die van het vorige.
	Gevolgen.boek(t.minigame_id, result)

	# Ná `run_effects()`, `unlock()`, `book_time()` én `Gevolgen.boek()`, en
	# vóór het signaal en de save. Hier stond hij vlak na de unlocks, en toen
	# kon elke mutatie daarónder de beschikbaarheid nog verschuiven zonder dat
	# iemand hem opnieuw woog — een `available_when` op `overwerk` of op een
	# vlag uit `Gevolgen` viel daardoor een oplevering te laat. Zo is de stand
	# van zaken compleet op het moment dat de HUD, het bord en het eindscherm
	# hem lezen.
	refresh_availability()

	Bus.ticket_completed.emit(id, result)
	Session.save_to_disk()

	if Session.all_done():
		Session.set_flag(&"alle_tickets_klaar", true)
		Bus.all_tickets_done.emit()


## Het huidige doel, voor de hintvogel, de doelregel en de wijzer in de wereld.
## Alle drie lezen hieruit, dus dit is de enige plek die bepaalt waar het spel
## je naartoe stuurt.
##
## Je eigen keuze wint. Heb je niets gekozen, dan het eerste ticket dat je bij
## je hebt; heb je nog niets gevonden, dan het eerste dat er nog ligt — zo
## stuurt de hint je op verkenning in plaats van dat hij zwijgt.
static func next_hint_ticket() -> TicketDef:
	if Session.pinned_ticket != &"" and Session.is_available(Session.pinned_ticket):
		return GameData.ticket(Session.pinned_ticket)

	var eerste_ongevonden: TicketDef = null
	for id: StringName in GameData.ticket_ids():
		if not Session.is_available(id):
			continue
		if Session.is_discovered(id):
			return GameData.ticket(id)
		if eerste_ongevonden == null:
			eerste_ongevonden = GameData.ticket(id)
	return eerste_ongevonden


static func open_tickets() -> Array[TicketDef]:
	var out: Array[TicketDef] = []
	for id: StringName in GameData.ticket_ids():
		if Session.is_available(id):
			out.append(GameData.ticket(id))
	return out


# --- Vinden en kiezen -----------------------------------------------------

## Alle openstaande tickets die aan dit object hangen. Dit is de ENIGE plek
## waar een anker naar tickets vertaald wordt: het scrumbord in de gang draagt
## er twee (de planning en de paardenbugs), en die kunnen allebei tegelijk open
## staan — BBD-202 vanaf de start, BBD-209 zodra BBD-202 klaar is.
static func tickets_at_anchor(world_id: StringName) -> Array[TicketDef]:
	var out: Array[TicketDef] = []
	if world_id == &"":
		return out
	for id: StringName in GameData.ticket_ids():
		var t: TicketDef = GameData.ticket(id)
		if t != null and t.anchor == world_id and Session.is_available(id):
			out.append(t)
	return out


## Het openstaande ticket op dit object waar de speler nu iets mee wil. Een pin
## wint van de volgorde: heb je BBD-209 gekozen, dan vraagt het scrumbord niet
## alsnog naar BBD-202.
static func preferred_at_anchor(world_id: StringName) -> TicketDef:
	var hier := tickets_at_anchor(world_id)
	if hier.is_empty():
		return null
	for t: TicketDef in hier:
		if Session.is_pinned(t.id):
			return t
	return hier[0]


## Alles wat in deze ruimte hangt komt in je inventaris. Geeft terug wat er
## nieuw bij kwam, zodat de HUD daar één melding van kan maken in plaats van
## drie als je De Vloer binnenloopt.
static func discover_in_zone(zone_id: StringName) -> Array[TicketDef]:
	var nieuw: Array[TicketDef] = []
	if zone_id == &"":
		return nieuw
	for id: StringName in GameData.ticket_ids():
		var t: TicketDef = GameData.ticket(id)
		if t == null or t.zone != zone_id or not Session.is_available(id):
			continue
		if Session.discover(id):
			nieuw.append(t)
	return nieuw


## Wat je bij je hebt: gevonden en nog niet opgelost.
static func inventory_tickets() -> Array[TicketDef]:
	var out: Array[TicketDef] = []
	for id: StringName in GameData.ticket_ids():
		if Session.is_discovered(id) and Session.is_available(id):
			out.append(GameData.ticket(id))
	return out


## Hoeveel er nog ergens op de vloer liggen.
static func undiscovered_count() -> int:
	var n := 0
	for id: StringName in GameData.ticket_ids():
		if Session.is_available(id) and not Session.is_discovered(id):
			n += 1
	return n


## Hoeveel tickets nog achter ander werk wachten. Het tweede onbekende getal
## van de dag: `undiscovered_count()` telt alleen wat al opengesteld ís, en
## sinds de ticketketen erin zit starten vijf van de tien LOCKED. Zonder dit
## getal zei het bord "Alles gevonden." zodra je de vier open tickets had
## opgeraapt, met zes stuks nog op slot en 0/10 op de kop.
static func locked_count() -> int:
	var n := 0
	for id: StringName in GameData.ticket_ids():
		if Session.ticket_state(id) == GameEnums.TicketState.LOCKED:
			n += 1
	return n


## Het eerste vereiste item dat je nog niet hebt, of null. Voor de gidslaag: de
## wijzer in de wereld en de doelregel moeten kunnen zeggen wát je nog moet
## ophalen, niet alleen dát er iets ontbreekt.
##
## Hoort hier en niet in de HUD, om dezelfde reden als `helper_stand()`: de
## wijzer en de doelregel lezen er beide uit, en twee eigen lusjes over
## `requirements` zouden stil van elkaar gaan afwijken. Leest de conditie via
## `Conditions.namen()`, zodat "één naam mag ook zonder lijst" hier hetzelfde
## betekent als bij de evaluatie zelf.
##
## Alleen `has_item`: dat is de enige requirement-soort die naar een plek in de
## wereld verwijst. Een ontbrekende vlag of trait kun je niet gaan halen.
static func ontbrekend_item(id: StringName) -> ItemDef:
	var t: TicketDef = GameData.ticket(id)
	if t == null:
		return null
	for iid: StringName in Conditions.namen(t.requirements.get("has_item", [])):
		if not Session.has_item(iid):
			return GameData.item(iid)
	return null


static func _set_state(id: StringName, st: GameEnums.TicketState) -> void:
	if Session.ticket_states.get(id, -1) == st:
		return
	Session.ticket_states[id] = st
	Bus.ticket_state_changed.emit(id, st)


# --- Effecten (state-mutaties) -------------------------------------------

## Draait een lijst effecten. `sla_niet_herhaalbare_over` is voor de tweede
## oplevering van een heropend ticket: alles wat bij twee keer draaien een ander
## resultaat geeft blijft dan achterwege, de rest draait gewoon. Zie
## `complete()`.
static func run_effects(list: Array, sla_niet_herhaalbare_over: bool = false) -> void:
	for raw: Variant in list:
		var e := raw as Dictionary
		if e == null:
			continue
		var op := String(e.get("op", ""))
		if sla_niet_herhaalbare_over and op in NIET_HERHAALBARE_OPS:
			continue
		match op:
			"set_flag":
				Session.set_flag(StringName(e.get("flag", "")), bool(e.get("value", true)))
			"add_item":
				Session.add_item(StringName(e.get("item", "")), int(e.get("count", 1)))
			"remove_item":
				Session.remove_item(StringName(e.get("item", "")), int(e.get("count", 1)))
			"add_counter":
				Session.add_counter(StringName(e.get("counter", "")), int(e.get("value", 1)))
			"unlock_ticket":
				unlock(StringName(e.get("ticket", "")))
			"toast":
				Bus.toast_requested.emit(String(e.get("text", "")), StringName(e.get("icon", "")))
			"cue":
				Bus.audio_cue_requested.emit(StringName(e.get("cue", "")))
			"kost_tijd":
				Session.book_time(int(e.get("minuten", 0)), StringName(e.get("reden", "")))
			"reopen_ticket":
				reopen(StringName(e.get("ticket", "")))
			_:
				push_error("QuestEngine: onbekende effect-op '%s'" % e.get("op", ""))

	# Beschikbaarheid hoort bij de bron, niet bij één pad. `refresh_availability()`
	# had drie aanroepers (`initialise_tickets`, `complete` en het titelscherm na
	# het laden), terwijl `run_effects()` uit vier plekken gedraaid wordt:
	# ticketbeloningen, dialoognodes, de telefoon van De Klant en storingen.
	# Een `available_when` op een vlag, een item of `overwerk` ging daardoor pas
	# open bij de volgende oplevering in plaats van op het moment dat hij waar
	# werd — en bij `overwerk`, een tijdsconditie, praktisch nooit.
	#
	# Kan hier veilig staan: de functie is idempotent, promoveert alleen
	# LOCKED -> AVAILABLE en draait geen effecten, dus er is geen recursie.
	refresh_availability()


static func unknown_effect_ops(list: Array) -> Array[String]:
	var bad: Array[String] = []
	for raw: Variant in list:
		var e := raw as Dictionary
		if e != null and not (String(e.get("op", "")) in EFFECT_OPS):
			bad.append(String(e.get("op", "")))
	return bad
