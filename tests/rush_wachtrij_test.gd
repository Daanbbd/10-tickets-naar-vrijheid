extends Node
## Test voor het stapelen van acties: drie tikken geven drie stops, nog eens
## tikken op een geplande stop schrapt hem (ook de lopende), en op jezelf
## tikken stopt alles. Laat aan het eind een route van drie stops staan, voor
## een schot met --write-movie.
##
##     Godot --headless --path . tests/rush_wachtrij_test.tscn

var _fouten := 0


func _ready() -> void:
	RushSave._geladen = true
	RushSave.uitleg_gezien = true
	RushSave.karakter = &"danny"
	RushSave.dag = 0
	var spel: RushGame = (load("res://scenes/rush/rush_game.tscn") as PackedScene).instantiate()
	add_child(spel)
	await get_tree().process_frame
	spel.hud._sluit_overlay()
	spel._begin()
	# Wachten tot er een ticket op het bord ligt.
	for i: int in 300:
		if spel.bord.any(func(t: Variant) -> bool: return t != null):
			break
		await get_tree().process_frame
	var slot: int = spel.bord.find(spel.bord.filter(func(t: Variant) -> bool: return t != null)[0])
	var victor: RushWorker = spel.werkers[0]
	var ticket_p: Vector2 = spel.kantoor.slot_positie(slot)
	var victor_p := victor.position + Vector2(0, -24)
	var server_p := RushKantoor.SERVER_RECT.get_center()

	spel._tik(ticket_p)
	spel._tik(victor_p)
	spel._tik(server_p)
	_check(_stops(spel) == 3, "drie tikken, drie stops (%d)" % _stops(spel))
	spel._tik(victor_p)
	_check(_stops(spel) == 2, "nog eens tikken schrapt (%d)" % _stops(spel))
	spel._tik(ticket_p)
	_check(_stops(spel) == 1 and spel.huidige["soort"] == "server", "de lopende stop is ook te schrappen")
	spel._tik(spel.speler.position + Vector2(0, -16))
	_check(_stops(spel) == 0 and spel.speler.pad.is_empty(), "op jezelf tikken stopt alles")

	spel._tik(ticket_p)
	spel._tik(victor_p)
	spel._tik(server_p)
	print("rush_wachtrij_test: %s (%d fout)" % ["OK" if _fouten == 0 else "FOUT", _fouten])
	if DisplayServer.get_name() == "headless":
		get_tree().quit(0 if _fouten == 0 else 1)


func _stops(spel: RushGame) -> int:
	return spel.wachtrij.size() + (0 if spel.huidige.is_empty() else 1)


func _check(ok: bool, wat: String) -> void:
	if not ok:
		_fouten += 1
		print("FOUT: ", wat)
