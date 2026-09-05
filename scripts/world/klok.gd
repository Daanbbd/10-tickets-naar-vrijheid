class_name Klok
extends Node
## Laat de speeltijd meelopen met de wandklok — als onderstroom, niet als
## hoofdstroom.
##
## Er is één waarheid over de tijd: `Session.worked_minutes`. Twee dingen
## schrijven erin, en ze horen sámen één werkdag te vullen:
##
## 1. **Het grootboek** (`Urenstaat`): elke oplevering boekt 30 of 45 minuten,
##    elke opgehaalde collega 15, elke mislukte poging 15. Voor een schone dag
##    is dat ~510 minuten (Daan, Danny) tot ~540 (de rest) — 09:12 → ~17:42 of
##    ~18:12, en dat is op zichzelf al voorbij de acht uur. Dat is de grap van
##    de urenstaat, en `_test_urenstaat()` bewaakt hem.
## 2. **Deze node**: elke `TICK_SEC` seconden speeltijd één minuut, reden
##    `&"verloop"`, zodat de klok ook beweegt terwijl je loopt en niet alleen
##    springt bij een oplevering. Dit is wat `storingen.gd` gebruikt voor
##    `wachttijd_min` (verstreken minuten waarin de speler zelf aan zet was).
##
## **Waarom 20 seconden en niet 2,5.** Op 2,5 s boekte deze node in een sessie
## van ~25 minuten reëel ~600 minuten — genoeg voor een hele dag in zijn eentje.
## Maar het grootboek boekte zijn 510-540 er gewoon bovenop, want beide waren
## los van elkaar op "een hele dag" gemaatvoerd. Het einde printte daardoor
## ~28:12 waar `ending.gd` 17:42 beloofde, en de HUD-klok stond al vóór de
## helft van de tickets op overwerk. Op 20 s levert deze node ~75 minuten in
## 25 minuten reëel: samen met het grootboek ~585-615, dus een schone dag
## eindigt rond 19:00-19:30 en je acht uur zijn op bij ongeveer driekwart van
## de beurt. `_test_dagvenster()` legt dat venster vast (17:12 tot 20:12) zodat
## een dubbele klok niet stil terugkomt.
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
## zonder de uitzondering hieronder zou deze klok daardoor alsnog stilvallen.
## Vandaar de expliciete `Shell.minigame_active()`-uitzondering.
const TICK_SEC := 20.0

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
