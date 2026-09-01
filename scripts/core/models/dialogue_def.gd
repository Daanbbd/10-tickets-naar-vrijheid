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

@export var id: StringName = &""
@export var nodes: Dictionary = {}
@export var start_node: StringName = &"start"

func node(nid: StringName) -> Dictionary:
	return nodes.get(nid, {}) as Dictionary

func has_node_id(nid: StringName) -> bool:
	return nodes.has(nid)
