class_name BrandjesModel
extends RefCounted
## De rekenkern van de finale (BBD-210), zonder scene en zonder Session.
##
## De oplevering is sinds P5 geen lijst knoppen met een budget meer maar een
## avond waarin alles tegelijk schreeuwt: brandjes komen binnen als kaartjes met
## een eigen aflopende balk, elk met precies één juiste handeling uit de zeven.
## Blus je op tijd, dan geldt het `effect` van die handeling; laat je de balk
## verlopen, dan geldt de `straf` van het brandje.
##
## Waarom een losse klasse en niet gewoon in `mg_oplevering.gd`: de kalibratie
## van deze finale is een getallenvraag ("haalt een zorgvuldige dag met perfect
## spel VLEKKELOOS, en een rampdag níet?") en die vraag hoort headless
## beantwoord te worden, in `_test_finale_brandjes()`, in seconden, zonder
## viewport. Alles wat hier staat is daarom puur: de klasse leest `Session`
## niet, roept `GameData` niet aan en kent geen enkele node. De scene geeft de
## vlaggen en de open tickets als parameters mee en vertaalt de gebeurtenissen
## die `tik()` teruggeeft naar beeld en geluid.
##
## Dit is de "Wave-State"-vorm uit de godot-master-module `game-loop-waves`:
## de spawncurve is data (`spawn_curve` in `minigame_content.json`), niet code,
## en de manager (deze klasse) bezit de tijdlijn terwijl de weergave alleen
## luistert. De klokdruk zelf komt uit `game-loop-time-trial`: één aflopende
## klok die de deploy forceert, en per brandje een tweede, kortere klok.

## De zeven handelingen. Even veel als de knoppen op het scherm, en elk brandje
## vraagt er precies één van.
const HANDELINGEN: Array[StringName] = [
	&"testen", &"fixen", &"scope", &"collega", &"informeren", &"nakijken", &"risico",
]

## De vier waarden waar een effect of straf op mag landen.
const METERS: Array[StringName] = [&"bugs", &"vertrouwen", &"getest", &"scope"]

## Hoeveel open tickets er hoogstens een eigen brandje krijgen. Een rampdag
## moet duur zijn, niet onspeelbaar: dezelfde aftopping als `Gevolgen.
## finale_start()` op `Session.niet_af()`.
const NIET_AF_MAX := 2

## Wat `tik()` terugmeldt. De scene vertaalt dit naar kaartjes, geluid en
## flitsen; het model tekent zelf niets.
enum Soort { SPAWN, VERLOPEN, GEBEURTENIS, TIJD_OM }


var toestand: Dictionary = {}
## Welke meters de speler al gezien heeft. `bugs` staat op "?" tot de eerste
## geblusde `testen`; blind deployen blijft duur (`Gevolgen.oplevering_score`).
var bekend: Dictionary = {}
var start_bugs: int = 0

## De brandjes die nu op het scherm horen te staan, hoogstens `max_zichtbaar`.
## Elk item: {id, tekst, handeling, duur, straf, resterend}.
var zichtbaar: Array[Dictionary] = []
## Wat nog moet komen, in volgorde. Leeg betekent: er komt niets meer, de klok
## loopt gewoon door.
var rij: Array[Dictionary] = []
## De handelingen die de speler daadwerkelijk uitvoerde, voor de payload.
var gedaan: Array[String] = []

var klok: float = 0.0
var verstreken: float = 0.0
var max_zichtbaar: int = 3
## Staat aan zolang het OPGELET-scherm open is: dan staan de balken stil. Een
## storing die je kaartjes laat verlopen terwijl je er niet bij kunt is geen
## onderbreking maar een straf voor het lezen ervan.
var gepauzeerd: bool = false

var _keuzes: Dictionary = {}
var _spawn_curve: Array = []
var _gebeurtenissen: Array = []
var _gebeurtenis: int = 0
var _volgende_spawn: float = 0.0
var _tijd_om_gemeld: bool = false
var _teller: int = 0


## `inhoud` is het `mg_deploy`-blok uit `data/minigame_content.json`, `start` de
## begintoestand (`Gevolgen.finale_start()`), `vlaggen` een kaart van
## `gevolg_*` naar bool en `niet_af` de codes van de tickets die om vijf uur nog
## open stonden. Geen van drieën wordt hier opgehaald: dat is precies wat deze
## klasse testbaar maakt.
func _init(inhoud: Dictionary, start: Dictionary, vlaggen: Dictionary,
		niet_af: Array[String], zaad: int = 0) -> void:
	for m: StringName in METERS:
		toestand[m] = maxi(0, int(start.get(String(m), start.get(m, 0))))
	start_bugs = int(toestand[&"bugs"])

	for raw: Variant in inhoud.get("keuzes", []):
		var k := raw as Dictionary
		_keuzes[StringName(k.get("id", ""))] = k

	_spawn_curve = inhoud.get("spawn_curve", [[0, 9]]) as Array
	_gebeurtenissen = inhoud.get("gebeurtenissen", []) as Array
	max_zichtbaar = maxi(1, int(inhoud.get("max_zichtbaar", 3)))
	klok = maxf(1.0, float(inhoud.get("klok_seconden", 75)))
	_bouw_rij(inhoud, vlaggen, niet_af, zaad)


# --- De rij ----------------------------------------------------------------

## De dag zaait de brandjes. Drie regels, in deze volgorde:
##
## 1. een brandje met `eerst: true` komt vooraan (de losse kabel van BBD-205 is
##    het eerste wat je die avond in je gezicht krijgt);
## 2. daarna een gegenereerd brandje per ticket dat nog open stond;
## 3. daarna de rest, gehusseld, zodat twee speelbeurten niet dezelfde avond
##    zijn.
##
## De husseling gebruikt een gezaaide generator en geen `Array.shuffle()`: zo
## kan de kalibratietest dezelfde avond twee keer draaien.
func _bouw_rij(inhoud: Dictionary, vlaggen: Dictionary, niet_af: Array[String],
		zaad: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = zaad

	var eerst: Array[Dictionary] = []
	var rest: Array[Dictionary] = []
	for raw: Variant in inhoud.get("brandjes", []):
		var b := raw as Dictionary
		if not mag(b.get("when", {}) as Dictionary, vlaggen):
			continue
		var lijst := eerst if bool(b.get("eerst", false)) else rest
		lijst.append(_maak(b))
		# De ontevreden klant belt twee keer. Geen nieuwe mechaniek: hetzelfde
		# brandje staat gewoon een tweede keer in de rij.
		if b.has("dubbel") and mag(b.get("dubbel", {}) as Dictionary, vlaggen):
			lijst.append(_maak(b))

	var open_werk: Array[Dictionary] = []
	var sjabloon := inhoud.get("brandje_niet_af", {}) as Dictionary
	if not sjabloon.is_empty():
		for code: String in niet_af.slice(0, NIET_AF_MAX):
			var b := sjabloon.duplicate(true)
			b["id"] = "niet_af_%s" % code
			b["tekst"] = String(sjabloon.get("tekst", "%s")) % code
			open_werk.append(_maak(b))

	_hussel(eerst, rng)
	_hussel(rest, rng)
	rij = eerst
	rij.append_array(open_werk)
	rij.append_array(rest)


## `nr` is het volgnummer waarmee de scene zijn kaartje terugvindt. Niet `id`:
## de ontevreden klant belt twee keer, dus hetzelfde brandje kan twee keer in de
## rij staan en straks twee keer tegelijk branden.
func _maak(b: Dictionary) -> Dictionary:
	_teller += 1
	return {
		&"nr": _teller,
		&"id": StringName(b.get("id", "")),
		&"tekst": String(b.get("tekst", "")),
		&"handeling": StringName(b.get("handeling", "")),
		&"duur": maxf(0.5, float(b.get("duur", 8))),
		&"straf": (b.get("straf", {}) as Dictionary).duplicate(),
		&"resterend": maxf(0.5, float(b.get("duur", 8))),
	}


static func _hussel(lijst: Array[Dictionary], rng: RandomNumberGenerator) -> void:
	for i: int in range(lijst.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := lijst[i]
		lijst[i] = lijst[j]
		lijst[j] = tmp


## De `when`-grammatica die dit model aankan: alleen `flags_all` en
## `flags_none`. Bewust minder dan `Conditions.KEYS` — de rest van die
## grammatica leest `Session`, en dan is deze klasse niet meer headless te
## rekenen. `_test_finale_brandjes()` bewaakt dat de data niets anders gebruikt.
static func mag(when: Dictionary, vlaggen: Dictionary) -> bool:
	if when.is_empty():
		return true
	for f: Variant in when.get("flags_all", []):
		if not bool(vlaggen.get(StringName(f), false)):
			return false
	for f: Variant in when.get("flags_none", []):
		if bool(vlaggen.get(StringName(f), false)):
			return false
	return true


# --- De tijdlijn -----------------------------------------------------------

## Eén stap van `delta` seconden. Geeft terug wat er in die stap gebeurde, in
## volgorde: eerst wat er binnenkwam, dan wat de dag zelf deed, dan wat er
## verliep. De aanroeper hoeft niets van de interne toestand te weten.
func tik(delta: float) -> Array[Dictionary]:
	var uit: Array[Dictionary] = []
	if gepauzeerd or _tijd_om_gemeld:
		return uit

	_spawn(uit)
	_vuur_gebeurtenissen(uit)
	_tel_af(delta, uit)

	verstreken += delta
	klok = maxf(0.0, klok - delta)
	if klok <= 0.0:
		_tijd_om_gemeld = true
		uit.append({&"soort": Soort.TIJD_OM})
	return uit


func _spawn(uit: Array[Dictionary]) -> void:
	while (verstreken >= _volgende_spawn and not rij.is_empty()
			and zichtbaar.size() < max_zichtbaar):
		var b: Dictionary = rij.pop_front()
		zichtbaar.append(b)
		_volgende_spawn = verstreken + interval_op(verstreken)
		uit.append({&"soort": Soort.SPAWN, &"brandje": b})


## Het spawn-interval dat op tijdstip `t` geldt. De curve staat oplopend in `t`
## en niet-stijgend in interval: hoe later op de avond, hoe sneller het komt.
func interval_op(t: float) -> float:
	var iv := 9.0
	for raw: Variant in _spawn_curve:
		var paar := raw as Array
		if paar.size() < 2:
			continue
		if t >= float(paar[0]):
			iv = maxf(0.5, float(paar[1]))
	return iv


## Gebeurtenissen vuren sinds P5 op klokseconden en niet meer op verbruikte
## handelingen: er zíjn geen verbruikte handelingen meer. `storing: true`
## houdt het OPGELET-scherm; de scene pauzeert dit model zolang dat open staat.
func _vuur_gebeurtenissen(uit: Array[Dictionary]) -> void:
	while _gebeurtenis < _gebeurtenissen.size():
		var g := _gebeurtenissen[_gebeurtenis] as Dictionary
		if verstreken < float(g.get("na", 0)):
			return
		_gebeurtenis += 1
		var veranderd := pas_effect(g.get("effect", {}) as Dictionary)
		uit.append({&"soort": Soort.GEBEURTENIS, &"gebeurtenis": g,
			&"veranderd": veranderd})


func _tel_af(delta: float, uit: Array[Dictionary]) -> void:
	var weg: Array[Dictionary] = []
	for b: Dictionary in zichtbaar:
		b[&"resterend"] = float(b[&"resterend"]) - delta
		if float(b[&"resterend"]) <= 0.0:
			weg.append(b)
	for b: Dictionary in weg:
		zichtbaar.erase(b)
		var veranderd := pas_effect(b[&"straf"] as Dictionary)
		uit.append({&"soort": Soort.VERLOPEN, &"brandje": b, &"veranderd": veranderd})


# --- Blussen ---------------------------------------------------------------

## Voert `handeling` uit. Is er een zichtbaar brandje dat er precies om vraagt,
## dan dooft het brandje met de kórtste balk: wie het meest haast heeft gaat
## eerst, want anders blust een tik het verkeerde kaartje en verloopt het
## andere alsnog.
##
## Leeg terug betekent: niets brandt daar. Dan gebeurt er ook niets — een loze
## handeling mag de meters niet opdrijven, anders is zeven keer blind tikken de
## hoogste score van het spel.
func blus(handeling: StringName) -> Dictionary:
	var i := doel_index(handeling)
	if i < 0:
		return {}
	var b: Dictionary = zichtbaar[i]
	zichtbaar.remove_at(i)
	gedaan.append(String(handeling))

	var keuze := _keuzes.get(handeling, {}) as Dictionary
	var onthuld := &""
	var onthult := StringName(keuze.get("onthult", ""))
	if onthult != &"" and not bool(bekend.get(onthult, false)):
		bekend[onthult] = true
		onthuld = onthult
	return {
		&"brandje": b,
		&"regel": String(keuze.get("regel", "")),
		&"onthuld": onthuld,
		&"veranderd": pas_effect(keuze.get("effect", {}) as Dictionary),
	}


## De index in `zichtbaar` van het brandje dat deze handeling zou doven, of -1.
func doel_index(handeling: StringName) -> int:
	var beste := -1
	for i: int in zichtbaar.size():
		if StringName(zichtbaar[i][&"handeling"]) != handeling:
			continue
		if beste < 0 or float(zichtbaar[i][&"resterend"]) < float(zichtbaar[beste][&"resterend"]):
			beste = i
	return beste


## Het zichtbare brandje met de kortste balk, of leeg. De autopilot blust dit
## brandje; een mens doet meestal hetzelfde.
func kortste() -> Dictionary:
	var beste: Dictionary = {}
	for b: Dictionary in zichtbaar:
		if beste.is_empty() or float(b[&"resterend"]) < float(beste[&"resterend"]):
			beste = b
	return beste


## Verwerkt een effect of een straf. Geeft per geraakte meter terug of het de
## goede kant op ging, zodat de scene weet welke kleur de flits krijgt.
##
## Geen negatieve meters: minder dan nul bugs bestaat niet, en een negatief
## getal zou de score cadeau doen aan wie doorfixt.
func pas_effect(effect: Dictionary) -> Dictionary:
	var uit: Dictionary = {}
	for k: Variant in effect:
		var m := StringName(k)
		if not toestand.has(m):
			continue
		var oud := int(toestand[m])
		var nieuw := maxi(0, oud + int(effect[k]))
		if nieuw == oud:
			continue
		toestand[m] = nieuw
		uit[m] = (nieuw < oud) if m == &"bugs" else (nieuw > oud)
	return uit


# --- Uitkomst --------------------------------------------------------------

func score() -> int:
	return Gevolgen.oplevering_score(toestand, start_bugs, bool(bekend.get(&"bugs", false)))


func tijd_om() -> bool:
	return klok <= 0.0


## Hoeveel er nog kan komen. Alleen voor de statusregel.
func open_brandjes() -> int:
	return zichtbaar.size() + rij.size()
