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

## Hoeveel afleiders er maximaal verdwijnen bij eigen vakgebied.
const MINDER_AFLEIDERS := 2
const EXTRA_TIJD := 1.25


## Geeft de config terug die de minigame moet draaien. Zonder voordeel is dat
## letterlijk dezelfde dictionary.
static func pas_toe(t: TicketDef) -> Dictionary:
	if t == null:
		return {}
	var config: Dictionary = t.minigame_config.duplicate(true)
	if not QuestEngine.is_own_expertise(t.id):
		return config

	match String(config.get("type", "")):
		"slotboard":  _slotboard(config)
		"cableboard": _cableboard(config)
		"tagpicker":  _tagpicker(config)
		"whack":      _whack(config)
		"choicescene": _choicescene(config)
	return config


## Korte regel voor de speler. Een voordeel dat je niet opmerkt bestaat niet.
static func voordeel_tekst(t: TicketDef) -> String:
	if t == null or not QuestEngine.is_own_expertise(t.id):
		return ""
	match String(t.minigame_config.get("type", "")):
		"slotboard":   return "Jouw vakgebied. Minder afleiders."
		"cableboard":  return "Jouw vakgebied. Minder losse draden."
		"tagpicker":   return "Jouw vakgebied. Een poging extra."
		"whack":       return "Jouw vakgebied. Wat meer tijd."
		"choicescene": return "Jouw vakgebied. Je hoeft minder te raden."
	return "Jouw vakgebied."


# --- per mechaniek ---------------------------------------------------------

## Haalt afleiderkaarten weg: kaarten die in geen enkel vak passen.
static func _slotboard(c: Dictionary) -> void:
	var goed := {}
	for raw: Variant in (c.get("slots", []) as Array):
		for id: Variant in ((raw as Dictionary).get("accepts", []) as Array):
			goed[String(id)] = true

	var kaarten: Array = c.get("cards", []) as Array
	var over: Array = []
	var weg := 0
	for raw: Variant in kaarten:
		var kaart := raw as Dictionary
		if weg < MINDER_AFLEIDERS and not goed.has(String(kaart.get("id", ""))):
			weg += 1
			continue
		over.append(kaart)
	c["cards"] = over
	c["max_fouten"] = int(c.get("max_fouten", 2)) + 1


static func _cableboard(c: Dictionary) -> void:
	var afleiders: Array = c.get("afleiders", []) as Array
	c["afleiders"] = afleiders.slice(0, maxi(0, afleiders.size() - MINDER_AFLEIDERS))


static func _tagpicker(c: Dictionary) -> void:
	c["pogingen"] = int(c.get("pogingen", 2)) + 1


static func _whack(c: Dictionary) -> void:
	c["duur"] = float(c.get("duur", 30.0)) * EXTRA_TIJD


static func _choicescene(c: Dictionary) -> void:
	# de drempel is het aantal goede keuzes dat je moet halen
	c["drempel"] = maxi(1, int(c.get("drempel", 3)) - 1)
