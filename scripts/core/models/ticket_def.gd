class_name TicketDef
extends Resource
## Eén ticket. Uit data/tickets/*.json.
##
## Strikte scheiding:
##   reward_effects -> state-mutaties, draaien exact een keer
##   world_changes  -> visuele mutaties, idempotent, herspeelbaar bij replay_all()

@export var id: StringName = &""
@export var code: String = ""              ## "BBD-201", getoond in de UI
## Narratieve nummering, **niet** de volgorde waarin je ze kunt spelen. Bepaalt
## alleen de leesvolgorde van het bord, de inventaris en de hint.
##
## Sinds de ticketketen erin zit lopen de twee uiteen: BBD-201 ("Wat moeten we
## eigenlijk bouwen?") heeft `order: 1` en gaat pas open ná BBD-208 — dat is de
## grap, want pas als de video klaar is blijkt dat niemand de user story heeft
## opgeschreven. Wie wil weten wat er nú open kan, moet `available_when` lezen
## of `QuestEngine.open_tickets()` gebruiken, niet dit veld.
@export var order: int = 0
@export var title: String = ""
@export var summary: String = ""
@export var zone: StringName = &""
@export var zone_name: String = ""
@export var anchor: StringName = &""       ## world_id van het object waar je het oplost
@export var owner_character: StringName = &""
@export var owner_role: String = ""
@export var available_when: Dictionary = {}
@export var requirements: Dictionary = {}
@export var dialogue_ids: Dictionary = {}  ## offer / blocked / fetch / fail / complete
@export var minigame_id: StringName = &""
@export var minigame_config: Dictionary = {}
@export var reward_effects: Array = []
@export var unlocks: Array[StringName] = []
@export var world_changes: Array = []
@export var hint: String = ""              ## getoond door de Blauwe Vogel / ticketbord
## F4-b: dit ticket lost op door in de wereld te handelen (een gesprek, een
## keuze bij een object, een collega aanspreken) in plaats van door een
## afgesloten minigame-overlay.
## Zie TicketController._resolve_wereldhandeling().
@export var wereldhandeling: bool = false
