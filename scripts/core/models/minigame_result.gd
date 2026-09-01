class_name MinigameResult
extends Resource
## Uitkomst van een minigame. Getypeerd zodat signal-signatures geen Variant hoeven.

@export var minigame_id: StringName = &""
@export var outcome: GameEnums.Outcome = GameEnums.Outcome.ABORT
@export var score: int = 0
@export var payload: Dictionary = {}

static func make(id: StringName, oc: GameEnums.Outcome, sc: int = 0, pl: Dictionary = {}) -> MinigameResult:
	var r := MinigameResult.new()
	r.minigame_id = id
	r.outcome = oc
	r.score = sc
	r.payload = pl
	return r

static func aborted(id: StringName) -> MinigameResult:
	return make(id, GameEnums.Outcome.ABORT)

func is_success() -> bool:
	return outcome == GameEnums.Outcome.SUCCESS
