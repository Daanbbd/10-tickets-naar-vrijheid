class_name RushKlank
extends RefCounted
## Alle geluid van de rush via één plek: de eigen `rush_*`-geluiden, met een
## terugval op de oude set zolang een nieuw geluid er (nog) niet is.

const SFX_PAD := "res://assets/audio/sfx/%s.wav"
const MUZIEK_PAD := "res://assets/audio/music/%s.ogg"

static var _bestaat: Dictionary = {}


static func sfx(cue: StringName, terugval: StringName = &"", jitter: float = 0.06, db: float = 0.0) -> void:
	AudioDirector.play_sfx(_kies(cue, terugval, SFX_PAD), jitter, db)


static func toon(cue: StringName, terugval: StringName, toonhoogte: float, db: float = 0.0) -> void:
	AudioDirector.play_sfx_toon(_kies(cue, terugval, SFX_PAD), toonhoogte, db)


static func ui(cue: StringName, terugval: StringName = &"klik") -> void:
	AudioDirector.play_ui(_kies(cue, terugval, SFX_PAD))


static func muziek(track: StringName, terugval: StringName, fade: float = 0.8) -> void:
	AudioDirector.set_base(_kies(track, terugval, MUZIEK_PAD), fade)


static func laag(laag_naam: StringName, track: StringName, terugval: StringName, fade: float = 0.3) -> void:
	AudioDirector.set_layer(laag_naam, _kies(track, terugval, MUZIEK_PAD), fade)


static func _kies(cue: StringName, terugval: StringName, pad: String) -> StringName:
	if not _bestaat.has(cue):
		_bestaat[cue] = ResourceLoader.exists(pad % cue)
	return cue if _bestaat[cue] or terugval == &"" else terugval
