class_name Conditions
extends RefCounted
## Statische evaluator voor de 'when'-grammatica. Dit is de ENIGE plek waar een
## conditie-dictionary betekenis krijgt. Gebruikt door quest-requirements,
## dialoogvarianten en interactable-gating.

const KEYS: Array[String] = [
	"character", "trait", "flags_all", "flags_none",
	"tickets_done", "tickets_not_done", "has_item", "min_tickets_done",
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

	return true

## Onbekende keys zijn bijna altijd een typefout in de data. De validator gebruikt dit.
static func unknown_keys(c: Dictionary) -> Array[String]:
	var bad: Array[String] = []
	for k: Variant in c.keys():
		if not (String(k) in KEYS):
			bad.append(String(k))
	return bad

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
