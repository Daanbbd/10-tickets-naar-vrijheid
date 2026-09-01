class_name Haptiek
extends RefCounted
## Trillingen als tweede feedbackkanaal naast geluid.
##
## Een telefoon speelt vaak met de klank uit, dus elke bevestiging die alleen
## een sample is komt op mobiel niet aan. Alle duurwaarden staan hier bij
## elkaar zodat "een tik" overal even lang duurt.

enum Sterkte {
	TIK,      ## selectie verschuift, knop ingedrukt
	STOOT,    ## interactie geslaagd, dialoog begint
	SLAG,     ## minigame verloren, deur zit op slot
	GELUKT,   ## ticket afgerond
}

const _DUUR := {
	Sterkte.TIK: 15,
	Sterkte.STOOT: 40,
	Sterkte.SLAG: 100,
	Sterkte.GELUKT: 250,
}


## Godot doet Android zelf. iOS heeft een native plugin nodig; zolang die er
## niet is blijft het daar stil in plaats van dat het een fout oplevert.
static func tril(sterkte: Sterkte) -> void:
	if not OS.has_feature("mobile"):
		return
	match OS.get_name():
		"Android":
			Input.vibrate_handheld(int(_DUUR[sterkte]))
		"iOS":
			if Engine.has_singleton("iOSHaptics"):
				Engine.get_singleton("iOSHaptics").call("impact", int(sterkte))
