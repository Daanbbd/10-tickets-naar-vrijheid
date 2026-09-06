class_name Conditions
extends RefCounted
## Statische evaluator voor de 'when'-grammatica. Dit is de ENIGE plek waar een
## conditie-dictionary betekenis krijgt. Gebruikt door quest-requirements,
## dialoogvarianten en interactable-gating.

const KEYS: Array[String] = [
	"character", "trait", "flags_all", "flags_none",
	"tickets_done", "tickets_not_done", "has_item", "min_tickets_done",
	"overwerk", "min_counter", "open_tickets_min",
]

static func check(c: Dictionary) -> bool:
	if c.is_empty():
		return true

	if c.has("character"):
		if not (Session.character_id in _names(c["character"])):
			return false

	if c.has("trait"):
		var traits: Array[StringName] = Session.character_traits()
		var wanted: Array[StringName] = _names(c["trait"])
		var hit := false
		for t: StringName in wanted:
			if t in traits:
				hit = true
				break
		if not hit:
			return false

	for f: StringName in _names(c.get("flags_all", [])):
		if not Session.get_flag(f):
			return false

	for f: StringName in _names(c.get("flags_none", [])):
		if Session.get_flag(f):
			return false

	for t: StringName in _names(c.get("tickets_done", [])):
		if not Session.is_done(t):
			return false

	for t: StringName in _names(c.get("tickets_not_done", [])):
		if Session.is_done(t):
			return false

	for i: StringName in _names(c.get("has_item", [])):
		if not Session.has_item(i):
			return false

	if Session.done_count() < int(c.get("min_tickets_done", 0)):
		return false

	# Hoeveel tickets (zonder t10 zelf) nog niet af zijn: `t10_offer`
	# waarschuwt hiermee vóór de deploy als er nog werk openstaat.
	if Session.niet_af().size() < int(c.get("open_tickets_min", 0)):
		return false

	# Bewust met has() eromheen, anders dan min_tickets_done hierboven: een bool
	# met default false zou elke lege conditie "het is geen overwerk" laten
	# beweren, en dat klapt na 17:00 elke fallbackvariant in de game om. Ook
	# niet via _names(), want dat maakt van een bool de StringName &"true".
	if c.has("overwerk"):
		if bool(c["overwerk"]) != Urenstaat.is_overwerk():
			return false

	# Eén of meer tellers die minstens een drempel gehaald moeten hebben, als
	# {"<naam>": n} — bijvoorbeeld hoe vaak je een gevecht al hebt verloren.
	# Zelfde patroon als `overwerk`: met `has()` en niet via `_names()`, want
	# de waarde is een dictionary van drempels, geen naam of lijst van namen.
	if c.has("min_counter"):
		var eis := c["min_counter"] as Dictionary
		for naam: Variant in eis:
			if Session.get_counter(StringName(naam)) < int(eis[naam]):
				return false

	return true

## Onbekende keys zijn bijna altijd een typefout in de data. De validator gebruikt dit.
static func unknown_keys(c: Dictionary) -> Array[String]:
	var bad: Array[String] = []
	for k: Variant in c.keys():
		if not (String(k) in KEYS):
			bad.append(String(k))
	return bad

## Dezelfde soepelheid als de grammatica zelf (één naam mag ook zonder lijst),
## voor code die een conditie moet *uitlezen* in plaats van evalueren. De wijzer
## in de wereld doet dat: die wil weten wélk item nog ontbreekt, niet of het
## ontbreekt. Publiek zodat die tolerantie op één plek staat — een tweede,
## eigen lus over `has_item` zou er stil van af kunnen wijken.
static func namen(v: Variant) -> Array[StringName]:
	return _names(v)


static func _names(v: Variant) -> Array[StringName]:
	var out: Array[StringName] = []
	if v is Array:
		for e: Variant in v:
			out.append(StringName(e))
	elif v != null and String(v) != "":
		out.append(StringName(v))
	return out


## Kiest de eerste variant waarvan de conditie klopt. De laatste variant zonder
## 'when' is de verplichte fallback; de validator dwingt af dat die bestaat.
static func pick_variant(variants: Array) -> Dictionary:
	for v: Variant in variants:
		var d := v as Dictionary
		if d == null:
			continue
		if check(d.get("when", {}) as Dictionary):
			return d
	return {}


## Kiest alle keuzes waarvan de conditie klopt.
static func filter_choices(choices: Array) -> Array:
	var out: Array = []
	for c: Variant in choices:
		var d := c as Dictionary
		if d != null and check(d.get("when", {}) as Dictionary):
			out.append(d)
	return out
