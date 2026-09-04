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
## Ja, zolang er geen aanraakscherm is. Zonder deze regel is tikken op een
## object op een laptop niet te doen — de tikroute luistert op
## `InputEventScreenTouch`, en die gebeurtenis bestaat daar niet.
##
## De voorwaarde is geen luxe. Godot emuleert standaard de andere kant op
## (`emulate_mouse_from_touch` staat aan, `emulate_touch_from_mouse` uit), dus
## op een echte telefoon levert één vinger zowel een ScreenTouch als een
## MouseButton op. Zonder deze wacht zou die ene vinger elke tik twee keer
## afvuren.
static func muis_als_vinger() -> bool:
	return not DisplayServer.is_touchscreen_available()


## Mag een muisklik ook de duimjoystick opzetten?
##
## Nee — en dat was hij wel. `Besturing` liet de muis de volledige vingerrol
## spelen, dus op een laptop opende elke linkerklik in de rechteronderhoek van
## het beeld een joystick en zette de speler in beweging. Wie met WASD loopt en
## ergens op klikt, zag zijn personage wegschuiven zonder aanwijsbare reden;
## dat is de "besturing voelt raar" waar dit vandaan komt. Een muis is geen
## duim: je hebt er al WASD naast, en een stick onder de cursor concurreert met
## elke klik die je bedoelde als "kijk hier eens".
##
## Wat de muis wél blijft doen is tikken op een object waar je al naast staat —
## dezelfde route als een vingertik, en de enige waar hij iets toevoegt.
##
## `--stick-muis` zet het oude gedrag terug, zodat de duimbesturing zonder
## aanraakscherm te valideren blijft. Dat was de echte reden dat de muis de
## stick mocht aandrijven, en dat is een QA-behoefte en geen spelregel.
static func muis_stuurt_stick() -> bool:
	return "--stick-muis" in OS.get_cmdline_user_args()


## Is dit een telefoon — als losstaande app op Android/iOS, of als website in
## een mobiele browser?
##
## `OS.has_feature("mobile")` alleen dekt de eerste twee: die feature-tag zegt
## voor welk exportplatform dit gebouwd is, en "Web" is nooit "mobile" — ook
## niet op een telefoon. Zonder de aanvulling hieronder denkt elke webbuild op
## een telefoon dat hij op een desktop staat: geen trilling (`Haptiek.tril()`),
## geen inkeping voor de safe area (`UiKit.veilige_laag()`), en geen
## achtergrondpauze bij het wisselen van app (`Shell._notification()`).
##
## Een aanraakscherm heeft een laptop zelden en een telefoon altijd, dus die
## aanvulling dekt precies het gat dat `has_feature("mobile")` op Web laat
## liggen.
static func is_telefoon() -> bool:
	return OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
