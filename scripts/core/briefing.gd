class_name Briefing
extends RefCounted
## Wat de collega je vertelt voordat je aan zijn ticket begint.
##
## Dit is het antwoord op de vraag waar de personages voor gebruikt werden en
## niet in gebruikt wérden. Een collega ophalen veranderde tot nu toe vooral
## *dat* hij meeliep: het ticket ging open, er kwam een regel dialoog, en de
## opgave was voor iedereen identiek. Wie er meeliep was daarmee een sleutel en
## geen mens.
##
## Nu geeft de eigenaar je één waar feit over zijn eigen ticket, in zijn eigen
## stem. Dat is de tegenhanger van `TraitModifier`: is het jouw vakgebied, dan
## krijg je een voordeel in de mechaniek; is het dat niet, dan krijg je de
## kennis van degene van wie het wél is. Beide routes geven je iets, en in beide
## gevallen komt het van een persoon.
##
## **De feiten staan niet in de tekst.** De briefing in
## `data/minigame_content.json` bevat plaatshouders, en die worden hier gevuld
## uit dezelfde config die de minigame straks draait. Een briefing kan dus niet
## liegen en niet verouderen: verandert de capaciteit van de sprint, dan
## verandert wat Daan zegt mee. `_test_briefings()` eist dat er na het vullen
## geen enkele accolade overblijft, want een onopgeloste `{knelpunt}` op het
## scherm is precies het soort fout dat niemand meldt.


## De regel van de eigenaar, of "" als dit ticket er geen heeft.
static func regel(t: TicketDef) -> String:
	if t == null or t.minigame_id == &"":
		return ""
	var c: Dictionary = MinigameContent.get_config(t.minigame_id)
	return vul(String(c.get("briefing", "")), c)


## Vult elke `{plaatshouder}` in `tekst` met de bijpassende waarde uit `c`,
## dezelfde config die de minigame straks draait. Losgetrokken uit `regel()`
## zodat ook `MinigameIntro` (het wat/waarom-scherm vóór de minigame) er
## dezelfde plaatshoudertaal mee kan vullen — één bron van waarheid voor élke
## tekst uit `data/minigame_content.json`, niet alleen de briefing.
static func vul(tekst: String, c: Dictionary) -> String:
	if tekst == "":
		return ""
	# `str()` en niet `String()`: de waarden zijn deels int en deels String, en
	# `String(int)` bestaat niet als constructor.
	var feiten := _feiten(c)
	for sleutel: Variant in feiten:
		tekst = tekst.replace("{%s}" % sleutel, str(feiten[sleutel]))
	return tekst


## Elke plaatshouder die deze mechaniek kan vullen, met de waarde uit de config.
##
## Per type alleen wat er echt in staat: een plaatshouder verzinnen die de
## minigame niet kent levert een accolade op het scherm, en dat vangt de test.
static func _feiten(c: Dictionary) -> Dictionary:
	var f := {}
	match String(c.get("type", "")):
		"scope":
			f["capaciteit"] = int(c.get("capaciteit", 0))
			f["tevreden_min"] = int(c.get("tevreden_min", 0))
			f["wensen"] = (c.get("wensen", []) as Array).size()
			f["zwaar"] = _zware_wensen(c)
		"standup":
			f["tijd"] = int(round(float(c.get("tijd", 0.0))))
			f["ingrepen"] = int(c.get("ingrepen", 0))
			f["belangrijk"] = _belangrijke_aanwijzing(c)
			f["sprekers"] = (c.get("sprekers", []) as Array).size()
		"choicescene":
			f["drempel"] = int(c.get("drempel", 0))
			f["rondes"] = (c.get("rondes", []) as Array).size()
		"uitlijnen":
			f["raster"] = int(c.get("raster", 0))
			f["tolerantie"] = int(c.get("tolerantie", 0))
			f["elementen"] = (c.get("elementen", []) as Array).size()
		"cableboard":
			f["verbindingen"] = (c.get("verbindingen", []) as Array).size()
			f["afleiders"] = (c.get("afleiders", []) as Array).size()
		"abtest":
			f["basis"] = _getal(float(c.get("basis", 0.0)))
			f["doel"] = _getal(float(c.get("doel", 0.0)))
			f["eenheid"] = String(c.get("eenheid", ""))
			f["rondes"] = (c.get("rondes", []) as Array).size()
		"abgevecht":
			f["hp_a"] = int(c.get("hp_a", 0))
			f["hp_b"] = int(c.get("hp_b", 0))
			f["rondes"] = (c.get("rondes", []) as Array).size()
		"pijplijn":
			f["doel"] = int(c.get("doel", 0))
			f["credits"] = int(c.get("credits", 0))
			f["knelpunt"] = _knelpunt(c)
		"whack":
			f["doel"] = int(c.get("doel", 0))
			f["duur"] = int(round(float(c.get("duur", 0.0))))
	return f


## Hoeveel van haar wensen eigenlijk projecten zijn.
##
## Uit `Gevolgen.ZWARE_WENSEN`, dezelfde lijst die na het ticket bepaalt of je
## scope te groot was. Daan mag dus precies zeggen wat het je later kost. Hier
## stond eerst "de helft", en dat was met drie van de negen simpelweg onwaar —
## een briefing die afrondt is een briefing die liegt.
static func _zware_wensen(c: Dictionary) -> int:
	var n := 0
	for raw: Variant in (c.get("wensen", []) as Array):
		if String((raw as Dictionary).get("id", "")) in Gevolgen.ZWARE_WENSEN:
			n += 1
	return n


## Een categorie-aanwijzing over de eerste spreker die echt iets te melden
## heeft — nooit zijn naam. Bewust één en niet alle: wie ze allemaal kent
## hoeft niet meer af te wegen, en dan is de stand-up geen opgave meer maar een
## lijstje.
##
## De naam zelf zou de speler het antwoord in de mond leggen: "kap iedereen
## behalve Jonathan af" is geen afweging meer. `aanwijzing` beschrijft zijn rol
## in plaats van zijn naam, en de tweede belangrijke spreker (Danny) krijgt
## bewust geen aanwijzing — dat is de enige verborgen informatie in het spel.
static func _belangrijke_aanwijzing(c: Dictionary) -> String:
	for raw: Variant in (c.get("sprekers", []) as Array):
		var sp := raw as Dictionary
		if bool(sp.get("belangrijk", false)):
			return String(sp.get("aanwijzing", ""))
	return ""


## Waar de rij stilstaat: de stap met de kleinste capaciteit, en bij gelijke
## capaciteit de langzaamste. Berekend en niet opgeschreven, want dit is precies
## het getal dat iemand later in de data bijstelt zonder de tekst te lezen.
static func _knelpunt(c: Dictionary) -> String:
	var beste := {}
	for raw: Variant in (c.get("stages", []) as Array):
		var st := raw as Dictionary
		if beste.is_empty():
			beste = st
			continue
		var cap := int(st.get("capaciteit", 99))
		var cap_beste := int(beste.get("capaciteit", 99))
		if cap < cap_beste or (cap == cap_beste
				and float(st.get("duur", 0.0)) > float(beste.get("duur", 0.0))):
			beste = st
	return String(beste.get("label", ""))


## Nederlandse komma, en een heel getal blijft heel: "1,8" en "3" in plaats van
## "1.8" en "3,0".
static func _getal(v: float) -> String:
	if is_equal_approx(v, roundf(v)):
		return str(int(roundf(v)))
	return ("%.1f" % v).replace(".", ",")
