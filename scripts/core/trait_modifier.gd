class_name TraitModifier
extends RefCounted
## Vertaalt het vakgebied van je personage naar een echt voordeel in een minigame.
##
## Tot nu toe waren traits alleen dialoog: Willem en Jonathan losten dezelfde
## minigame op precies dezelfde manier op. Nu scheelt het vakgebied iets in de
## opgave zelf.
##
## Eén harde regel: een trait geeft alleen voordeel, nooit nadeel. Buiten je
## vakgebied krijg je de gewone versie, niet een strafversie. Anders botst het
## met het faalbeleid uit docs/GAME_DESIGN.md ("falen kost nooit voortgang") en
## voelt de personagekeuze als een handicap in plaats van als een kleur.
##
## Alle statische methodes, net als QuestEngine, zodat dit headless testbaar is.
##
## **Waarom dit een tabel is en geen losse `match`.** Zes van de elf minigames
## kregen nieuwe mechanieken en nieuwe `type`-namen, en de `match` hieronder
## kende die niet. Gevolg: in vijf van de tien tickets deed je vakgebied
## helemaal niets, en `voordeel_tekst()` viel terug op een kale "Jouw
## vakgebied." zonder dat er iets veranderde. Geen fout, geen melding — precies
## de halve migratie die docs/ARCHITECTURE.md verbiedt. Daarom is `VOORDEEL`
## nu tegelijk de dekkingslijst: `_test_traits()` eist dat elk type uit
## `minigame_content.json` hier staat of in `GEEN_VOORDEEL`, én dat een belofte
## uit deze tabel de opgave echt verandert. Een nieuwe mechaniek kán dus niet
## meer stil voordeelloos blijven.

## Wat een eigen vakgebied per mechaniek oplevert, in de woorden die de speler
## te zien krijgt. Een voordeel dat je niet opmerkt bestaat niet, dus elke
## regel noemt wat er concreet anders is en niet dat er iets anders is.
const VOORDEEL := {
	"cableboard":  "Jouw vakgebied. Minder losse draden.",
	"abgevecht":   "Jouw vakgebied. Je ziet de tegenklap van elke klap vooraf.",
	"whack":       "Jouw vakgebied. Je hoeft ze niet op te zoeken.",
	"choicescene": "Jouw vakgebied. Je hoeft minder te raden.",
	"scope":       "Jouw vakgebied. Twee punten meer ruimte.",
	"standup":     "Jouw vakgebied. Je mag één keer extra afkappen.",
	"uitlijnen":   "Jouw vakgebied. Eén pixel meer speling.",
	"heatmap":     "Jouw vakgebied. Je ziet per element hoe vaak erop geklikt is.",
	"pijplijn":    "Jouw vakgebied. Twintig credits extra.",
}

## Mechanieken die bewust géén voordeel kennen, met de reden erbij. Staat hier
## zodat "vergeten" en "besloten" te onderscheiden zijn.
const GEEN_VOORDEEL := {
	"oplevering": "de finale begint met de dag die je gehad hebt (Gevolgen.finale_start); "
		+ "een korting daarbovenop zou het gevolgensysteem uithollen, en elk personage "
		+ "heeft daar al zijn eigen foutcode",
	"slotboard": "de urenstaat kent geen goed antwoord, dus er valt niets makkelijker te "
		+ "maken; hij hangt bovendien aan Dirk en niet aan een ticket, dus pas_toe() "
		+ "krijgt hem nooit te zien",
}

## Hoeveel afleiders er maximaal verdwijnen bij eigen vakgebied.
const MINDER_AFLEIDERS := 2
const EXTRA_TIJD := 1.25
## Sprintruimte erbij in de scope-minigame. Twee punten is de kleinste wens uit
## BBD-201, dus het is precies "er past nog net iets bij" en geen vrijbrief.
const EXTRA_PUNTEN := 2
const EXTRA_INGREEP := 1
const EXTRA_SPELING := 1
const EXTRA_CREDITS := 20


## De aangepaste opgave, of een lege dictionary als er niets verandert.
##
## **Leeg betekent "gebruik het bestand".** De aanroeper geeft dit door als
## `inhoud` in de minigameconfig; `MinigameBase.setup()` zet dat op
## `content_override`, en `content()` valt zonder override terug op
## `data/minigame_content.json`. Zo hoeft geen enkele minigame te weten dat
## traits bestaan.
##
## Dit werkte hiervoor niet. Er stond `t.minigame_config.duplicate(true)`, en
## dat veld is in alle tien de tickets `{}` — dus `type` was altijd leeg, geen
## enkele `match`-tak liep, en het resultaat ging bovendien naar `config`
## terwijl elke minigame zijn opgave uit `content()` haalt. Twee losse redenen
## waarom hetzelfde niets gebeurde, en er stond wél een toast op het scherm die
## de speler een voordeel beloofde.
static func pas_toe(t: TicketDef) -> Dictionary:
	if t == null or not QuestEngine.is_own_expertise(t.id):
		return {}

	# Eerst de inhoud uit het bestand, dan de ticket-specifieke afwijkingen
	# eroverheen. Dat tweede veld is vandaag overal leeg, maar het contract
	# hoort intact te blijven: een ticket mag zijn eigen opgave bijstellen.
	var config: Dictionary = MinigameContent.get_config(t.minigame_id).duplicate(true)
	config.merge(t.minigame_config.duplicate(true), true)

	var soort := String(config.get("type", ""))
	if not VOORDEEL.has(soort):
		return {}

	match soort:
		"cableboard":  _cableboard(config)
		"abgevecht":   _abgevecht(config)
		"whack":       _whack(config)
		"choicescene": _choicescene(config)
		"scope":       _scope(config)
		"standup":     _standup(config)
		"uitlijnen":   _uitlijnen(config)
		"heatmap":     _heatmap(config)
		"pijplijn":    _pijplijn(config)
	return config


## Korte regel voor de speler, uit dezelfde bron als `pas_toe()`: een regel op het scherm die belooft wat
## de config niet levert is erger dan geen regel.
static func voordeel_tekst(t: TicketDef) -> String:
	if t == null or not QuestEngine.is_own_expertise(t.id):
		return ""
	return String(VOORDEEL.get(soort_van(t), ""))


## Welke mechaniek dit ticket draait.
static func soort_van(t: TicketDef) -> String:
	if t == null:
		return ""
	var config: Dictionary = MinigameContent.get_config(t.minigame_id)
	return String(t.minigame_config.get("type", config.get("type", "")))


# --- per mechaniek ---------------------------------------------------------

static func _cableboard(c: Dictionary) -> void:
	var afleiders: Array = c.get("afleiders", []) as Array
	c["afleiders"] = afleiders.slice(0, maxi(0, afleiders.size() - MINDER_AFLEIDERS))


## Danny's voordeel: hij ziet de tegenklap van elke klap vooraf, niet de
## schade. Dat vertelt hem wat een klap kost zonder te verklappen wat hij
## oplevert — genoeg om een dure klap te mijden, niet genoeg om de opgave over
## te slaan. `mg_abgevecht.gd` leest `toon_tegenklap` bij het bouwen van de
## knoppen.
static func _abgevecht(c: Dictionary) -> void:
	c["toon_tegenklap"] = true


## F4-b: BBD-209 is een wereldhandeling geworden, geen getimede minigame meer —
## `duur` boosten blijft staan (schaadt niets, en houdt de opgave identiek als
## `mg_whack` ooit teruggezet wordt), maar het echte voordeel voor Bastiaan is
## nu dat hij geen paard hoeft te zoeken: hij weet al waar de bug zit. Zie
## `TicketController._wh_paarden()`.
static func _whack(c: Dictionary) -> void:
	c["duur"] = float(c.get("duur", 30.0)) * EXTRA_TIJD
	c["geen_zoektocht"] = true


static func _choicescene(c: Dictionary) -> void:
	# de drempel is het aantal goede keuzes dat je moet halen
	c["drempel"] = maxi(1, int(c.get("drempel", 3)) - 1)


## Meer sprintruimte, niet minder eisen. Haar tevredenheidsgrens blijft staan:
## de opgave is nog steeds "wat neem je mee", alleen past er iets meer in.
static func _scope(c: Dictionary) -> void:
	c["capaciteit"] = int(c.get("capaciteit", 13)) + EXTRA_PUNTEN


## Eén keer extra afkappen. Het budget blijft, dus de afweging blijft ook:
## wie je afkapt kost je nog steeds wat hij ging melden.
static func _standup(c: Dictionary) -> void:
	c["ingrepen"] = int(c.get("ingrepen", 3)) + EXTRA_INGREEP


static func _uitlijnen(c: Dictionary) -> void:
	c["tolerantie"] = int(c.get("tolerantie", 2)) + EXTRA_SPELING


## BBD-206: de CRO'er ziet de data. Waar iedereen alleen hittepunten ziet
## landen, krijgt Danny per element een teller — genoeg om het hete element
## sneller te herkennen, niet genoeg om niet te hoeven kijken: de teller loopt
## pas op terwijl de ronde loopt. Zie `toon_tellers` in mg_heatmap.gd.
static func _heatmap(c: Dictionary) -> void:
	c["toon_tellers"] = true


static func _pijplijn(c: Dictionary) -> void:
	c["credits"] = int(c.get("credits", 100)) + EXTRA_CREDITS
