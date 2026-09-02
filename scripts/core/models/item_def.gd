class_name ItemDef
extends Resource
## Inventory-item. Uit data/items.json.

@export var id: StringName = &""
@export var name: String = ""
@export var description: String = ""
@export var icon: StringName = &""

## Het `world_id` van het object waar dit item te vinden is, en de ruimte waarin
## dat object staat. Leeg voor alles wat je als beloning krijgt in plaats van
## opraapt.
##
## Bestaat omdat de wijzer in de wereld een ontbrekend vereist item moet kunnen
## aanwijzen: zonder dit stuurt hij je bij 9/10 naar de deploycomputer die om de
## deploysleutel vraagt, terwijl die zestig tegels westelijker in de plantenkast
## ligt. `zone` staat er los bij en wordt niet uit het object afgeleid, omdat
## `GameData` `objects.json` niet inleest — `_test_item_vindplaats()` bewaakt dat
## de twee bij elkaar blijven horen.
@export var vindplaats: StringName = &""
@export var zone: StringName = &""
