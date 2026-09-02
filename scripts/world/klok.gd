class_name Klok
extends Node
## Laat de speeltijd meelopen met de wandklok.
##
## Vier seconden en veertien minuten in het spel stonden er allebei 09:12: de
## enige klokbewegingen kwamen van een opgeleverd ticket (30/45 min) of een
## opgehaalde collega (15 min), en die blijven bestaan als hun eigen boeking —
## de urenrol-animatie erop is al goed. Deze node levert de onderstroom
## eronder: elke `TICK_SEC` seconden speeltijd een minuut op de klok, via
## `Session.book_time()`, dezelfde en enige plek die `worked_minutes` verhoogt.
## De HUD-klok en de `overwerk`-conditie lopen daardoor vanzelf mee; niets in
## deze node kent een van beide.
##
## Loopt NIET tijdens dialoog, de telefoon of het vertrek — dezelfde
## `Session.input_locked` als `telefoon.gd::_process()` gebruikt, anders straf
## je lezen. Loopt ook niet tijdens het pauzemenu of de achtergrondgang
## (`get_tree().paused`, de enige twee dingen die de tree na F5-a nog
## pauzeren).
##
## Loopt WEL door tijdens een minigame — dat is F5's hele punt: "geen klok kon
## tikken" was precies de klacht over het oude pauzemodel. Sinds F5-a zet
## `Shell.run_minigame()` ook `Session.lock_input()` (zodat de speler niet kan
## weglopen), dus `Session.input_locked` staat tijdens een minigame ook aan —
## zonder de uitzondering hieronder zou deze klok daardoor alsnog stilvallen,
## precies het probleem dat F5 moest oplossen. Vandaar de expliciete
## `Shell.minigame_active()`-uitzondering: het slot mag de speler tegenhouden
## zonder de klok tegen te houden.
##
## Getal: 1 in-game minuut per 2,5 reële seconden. Een sessie van ~25 minuten
## reëel bestrijkt dan ~600 in-game minuten: 09:12 -> iets voorbij 19:00,
## precies de doelspanne uit het plan.
const TICK_SEC := 2.5

var _t: float = 0.0


func _process(delta: float) -> void:
	if Session.all_done() or get_tree().paused:
		return
	if Session.input_locked and not Shell.minigame_active():
		return
	_t += delta
	while _t >= TICK_SEC:
		_t -= TICK_SEC
		Session.book_time(1, &"verloop")
