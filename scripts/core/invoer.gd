class_name Invoer
extends RefCounted
## Eén plek die weet of dit spel op een aanraakscherm draait.
##
## Staat hier en niet op een UI-klasse, omdat ook de minigames en de
## dialoogbox het moeten kunnen vragen zonder van de wereld-HUD af te hangen.

## `--touch` zet de aanraakroute aan op de desktop zodat de QA-shots hem laten
## zien; `--geen-touch` zet hem uit op een aanraakscherm dat met een
## toetsenbord getest wordt.
static func touch() -> bool:
	var args := OS.get_cmdline_user_args()
	if "--touch" in args:
		return true
	if "--geen-touch" in args:
		return false
	return OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
