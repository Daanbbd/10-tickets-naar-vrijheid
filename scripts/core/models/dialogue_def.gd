class_name DialogueDef
extends Resource
## Eén dialoogboom. Uit data/dialogue/*.json. Bewust zonder afhankelijkheden:
## het kiezen van varianten gebeurt in Conditions.pick_variant().
##
## Node-vorm:
##   {"speaker":"dennis",
##    "variants":[{"when":{...},"text":"..."}],
##    "choices":[{"text":"...","when":{...},"next":"...","effects":[...]}],
##    "next":"...", "effects":[...], "outcome":"..."}
##
## Een variant met een lege `text` is geen fout maar een stilte: de controller
## slaat het venster dan over en loopt door naar `next`. Zo kan een node zijn
## derde regel laten vallen zodra hij niet meer klopt, zonder dat de boom een
## aparte tak nodig heeft (zie `ticketbord/derde`).

@export var id: StringName = &""
@export var nodes: Dictionary = {}
@export var start_node: StringName = &"start"

func node(nid: StringName) -> Dictionary:
	return nodes.get(nid, {}) as Dictionary

func has_node_id(nid: StringName) -> bool:
	return nodes.has(nid)
