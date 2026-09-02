class_name Invoer
extends RefCounted
## Eén plek die weet hoe invoer op dit apparaat aankomt.
##
## Hier stond ook `touch()`, en daarmee de vraag "is dit een telefoon". Die
## vraag is weg omdat het antwoord niets meer mocht bepalen: de knoppenbalk
## staat er op elk apparaat, en de zes plekken die er hun eigen indeling uit
## haalden — de HUD, de besturingskaart, het ticketbord, de dialoogbox, de
## prompt en elke minigame — hadden samen twee spellen met dezelfde inhoud
## opgeleverd. Toetsen zijn nu sneltoetsen naar dezelfde knoppen. Zie
## `Besturing`.
##
## Wat overblijft is één echte apparaatvraag, en die gaat niet over indeling
## maar over gebeurtenistypes.

## Mag een muisklik doorgaan voor een vingertik?
##
## Ja, zolang er geen aanraakscherm is. Zonder deze regel is de duimbesturing
## op een laptop niet te spelen — de joystick en het dialoogvenster luisteren
## op `InputEventScreenTouch`, en die gebeurtenis bestaat daar niet. De balk
## was dus te bekijken maar niet te gebruiken, en daarmee niet te valideren.
##
## De voorwaarde is geen luxe. Godot emuleert standaard de andere kant op
## (`emulate_mouse_from_touch` staat aan, `emulate_touch_from_mouse` uit), dus
## op een echte telefoon levert één vinger zowel een ScreenTouch als een
## MouseButton op. Zonder deze wacht zou die ene vinger elke tik twee keer
## afvuren.
static func muis_als_vinger() -> bool:
	return not DisplayServer.is_touchscreen_available()
