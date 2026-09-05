class_name Urenstaat
extends RefCounted
## De klok van de werkdag. Je begint om 09:00 met acht uur, en er is meer werk
## dan uren — voor elk personage, altijd. Om vijf uur ga je niet naar huis; je
## gaat overwerken en de klok loopt gewoon door.
##
## Eén harde regel: tijd blokkeert nooit iets en kan het spel nooit onwinbaar
## maken. De urenstaat is een scorebord en een grap, geen grondstof. Zodra de
## klok een ticket, een deur of een collega afsluit botst hij met het faalbeleid
## uit docs/GAME_DESIGN.md ("falen kost nooit voortgang — het kost alleen tijd,
## en tijd is geen voortgang").
##
## Kent bewust alléén Session. Niet QuestEngine, Conditions, GameData of
## TicketDef: die kennen ons, en GDScript struikelt over wederzijdse
## class_name-verwijzingen (zie docs/ARCHITECTURE.md). Daarom krijgt
## kosten_voor_ticket() het vakgebied als parameter in plaats van het zelf op te
## vragen.
##
## Alle methodes statisch, net als QuestEngine en TraitModifier, zodat dit
## headless testbaar is.

## Hoe laat je binnenkomt, in minuten sinds middernacht zodat formatteer() puur
## rekenwerk is.
##
## 9:12 en niet 9:00, omdat de intro dat al zei: "Woensdag. 9:12. Je bent
## binnen." Die regel stond er eerder dan deze klok, dus de klok volgt hem.
const START_MIN := 9 * 60 + 12
## Acht uur. Wat je mag boeken, niet wat je gaat werken.
const BUDGET_MIN := 8 * 60

# --- Het grootboek --------------------------------------------------------
# Gebeurtenisgestuurd, niet op de wandklok: rondlopen en onderzoeken is gratis.
# Verkennen levert werk op (zie QUESTS.md), dat mag geen straf worden. En het is
# headless testbaar, wat op de wandklok niet lukt.

## Ticket in je eigen vakgebied. Je zit er zelf bovenop.
const EIGEN_MIN := 30
## Ticket met een collega erbij. Het werk zelf duurt langer omdat je het samen doet.
const HULP_MIN := 45
## De collega ophalen. De HUD zei het al: de werkelijke kosten van ophalen zijn zoektijd.
const OPHALEN_MIN := 15
## Een mislukte minigame. Kost tijd, nooit voortgang.
const FOUT_MIN := 15


## Wat een ticket je kost. Krijgt het vakgebied als feit aangereikt — zie de
## opmerking over cycli hierboven. `override_min` is de uitzondering voor de
## finale (BBD-210): die kost altijd 60 minuten, ongeacht vakgebied, want de
## oplevering is het uur waarin het hele team meekijkt.
static func kosten_voor_ticket(eigen_vakgebied: bool, override_min: int = 0) -> int:
	if override_min > 0:
		return override_min
	return EIGEN_MIN if eigen_vakgebied else HULP_MIN


## Hoe laat het nu is, in minuten sinds middernacht.
static func nu() -> int:
	return START_MIN + Session.worked_minutes


## Ben je over je acht uur heen?
static func is_overwerk() -> bool:
	return Session.worked_minutes >= BUDGET_MIN


## Hoeveel er van je budget over is. Nooit negatief: wat je over je dag heen
## gaat lees je aan de klok af, niet aan een min-teken.
static func resterend() -> int:
	return maxi(0, BUDGET_MIN - Session.worked_minutes)


## Hoeveel je over je dag heen bent. 0 zolang je binnen het budget zit.
static func overwerk_min() -> int:
	return maxi(0, Session.worked_minutes - BUDGET_MIN)


## Een tijdstip: "09:00", "17:30". Loopt bewust dóór na middernacht ("25:00")
## in plaats van terug te vallen naar 01:00 — dat leest als een nachtdienst en
## niet als een nieuwe dag, en dat is precies de bedoeling.
static func formatteer(minuten: int) -> String:
	var m := maxi(0, minuten)
	return "%02d:%02d" % [m / 60, m % 60]


## Een duur in Dirks notatie: "8u", "9u30", "45 min". Onder het uur schrijft hij
## minuten uit; daarboven plakt hij het aan elkaar.
static func formatteer_duur(minuten: int) -> String:
	var m := maxi(0, minuten)
	# Nul is "0u" en niet "0 min": zo staat het in Dirks berichten ("er staat
	# 0u geboekt"), en op een urenstaat lees je uren, geen minuten.
	if m == 0:
		return "0u"
	if m < 60:
		return "%d min" % m
	if m % 60 == 0:
		return "%du" % (m / 60)
	return "%du%02d" % [m / 60, m % 60]


# --- Het daglicht ---------------------------------------------------------
# De klok is de ruggengraat van de dag en was tot nu toe onzichtbaar in de
# pixels: de zonemoods (`main.gd::LICHT`) veranderden alleen met het aantal
# opgeloste tickets. Dit is de dagfase als kleur, zodat `Main._tint_zone()`
# hem over de zonemood heen kan leggen. Puur presentatie — leest de klok,
# beslist niets.

## Ankerpunten: [minuten sinds middernacht, kleur]. Tussenliggende minuten
## worden lineair gemengd; vóór het eerste en na het laatste punt blijft de
## kleur staan. Waarden dicht bij wit, net als `LICHT`: dit is een tint, geen
## filter — de betonvloer moet grijs blijven lezen.
const DAGLICHT: Array[Array] = [
	[8 * 60,                 Color(0.94, 0.97, 1.05)],  # koele ochtend, het licht komt van buiten
	[12 * 60,                Color(1.00, 1.00, 1.00)],  # middag, neutraal
	[15 * 60 + 30,           Color(1.04, 1.00, 0.95)],  # warme namiddag
	[START_MIN + BUDGET_MIN, Color(1.08, 0.98, 0.88)],  # 17:12, het gouden uur: je acht uur zijn op
	[18 * 60 + 30,           Color(0.97, 0.97, 1.02)],  # schemer, de tl-buizen nemen het over
	[20 * 60,                Color(0.90, 0.93, 1.03)],  # avond: kantoorlicht, koud en een tik donkerder
]


## De kleur van het daglicht op een tijdstip (minuten sinds middernacht).
static func daglicht(minuten: int) -> Color:
	if minuten <= int(DAGLICHT[0][0]):
		return DAGLICHT[0][1] as Color
	for i: int in range(1, DAGLICHT.size()):
		var t1 := int(DAGLICHT[i][0])
		if minuten <= t1:
			var t0 := int(DAGLICHT[i - 1][0])
			var f := float(minuten - t0) / float(maxi(1, t1 - t0))
			return (DAGLICHT[i - 1][1] as Color).lerp(DAGLICHT[i][1] as Color, f)
	return DAGLICHT[DAGLICHT.size() - 1][1] as Color


## Het daglicht van dit moment.
static func daglicht_nu() -> Color:
	return daglicht(nu())
