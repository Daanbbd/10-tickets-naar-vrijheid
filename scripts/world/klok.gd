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
## Loopt NIET tijdens dialoog en menu's — dezelfde guards als
## `telefoon.gd::_process()` (Session.input_locked en get_tree().paused),
## anders straf je lezen. Pauzeert bewust NIET tijdens een minigame: dat is
## expliciet F5, nog niet begonnen, en de wereld pauzeert daar vandaag niet
## voor.
##
## Getal: 1 in-game minuut per 2,5 reële seconden. Een sessie van ~25 minuten
## reëel bestrijkt dan ~600 in-game minuten: 09:12 -> iets voorbij 19:00,
## precies de doelspanne uit het plan.
const TICK_SEC := 2.5

var _t: float = 0.0


func _process(delta: float) -> void:
	if Session.all_done() or Session.input_locked or get_tree().paused:
		return
	_t += delta
	while _t >= TICK_SEC:
		_t -= TICK_SEC
		Session.book_time(1, &"verloop")
