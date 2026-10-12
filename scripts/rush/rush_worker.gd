class_name RushWorker
extends Node2D
## Een bureau met een collega erachter. De oorsprong is de voorkant van het
## bureau, zodat y-sortering de speler ervoor en de collega erachter zet.
##
## Is dit jouw eigen bureau, dan zit er niemand: daar doe je je eigen vak zelf.

signal klaar(worker: RushWorker)

var persoon: StringName = &""
var vak: int = RushData.Vak.FE
## Alle vakken die hier gedaan worden. Eén, behalve aan het bureau van een
## zelfgemaakt personage met een rol die er twee doet (Developer).
var vakken: Array = []
var naam: String = ""
var is_eigen := false
## Alleen op de dag dat zijn vak meedoet; anders zit hij met iets anders bezig.
var actief := true

var ticket: RushTicket = null
var voortgang: float = 0.0
var is_klaar := false
## Jonathan in de stand-up: hij praat, en zijn rij staat stil.
var praat := false
var stilgelegd := false
## Je houdt een ticket vast dat hier terecht kan: het bureau licht op.
var gloed := false

var sprite: AnimatedSprite2D
var _tijd: float = 0.0
var _hop: float = 0.0


func setup(id: StringName, eigen: bool) -> void:
	persoon = id
	is_eigen = eigen
	if id == RushProfiel.ID:
		vakken = RushProfiel.vakken().duplicate()
		naam = RushProfiel.naam
	else:
		vakken = [RushData.vak_van(id)]
	vak = vakken[0]
	var def: CharacterDef = GameData.character(id)
	if id != RushProfiel.ID:
		naam = def.name if def != null else String(id).capitalize()

	sprite = AnimatedSprite2D.new()
	sprite.show_behind_parent = true
	sprite.offset = Vector2(0, -16)
	sprite.position = Vector2(0, -8)
	add_child(sprite)
	if def != null and not eigen:
		sprite.sprite_frames = CharacterSprites.frames_for(
			def.look, def.color, def.skin, def.hair, def.pants, def.accent)
		sprite.play(&"idle_down")
		sprite.frame = randi() % 3
	else:
		sprite.visible = false


func doet(v: int) -> bool:
	return v in vakken


func vak_naam() -> String:
	var namen: Array[String] = []
	for v: int in vakken:
		namen.append(RushData.VAK_NAAM[v])
	return " en ".join(namen)


func benader_punt() -> Vector2:
	return position + Vector2(0, 9)


func hoofd() -> Vector2:
	return position + Vector2(0, -44)


func vrij() -> bool:
	return ticket == null


func geef(t: RushTicket) -> void:
	ticket = t
	t.staat = RushTicket.Staat.WERK
	t.werker = self
	voortgang = 0.0
	is_klaar = false
	_hop = 0.6
	queue_redraw()


func neem() -> RushTicket:
	var t := ticket
	ticket = null
	is_klaar = false
	voortgang = 0.0
	queue_redraw()
	return t


func tik(delta: float, werktijd: float) -> void:
	_tijd += delta
	if _hop > 0.0:
		_hop = maxf(0.0, _hop - delta * 3.0)
	if ticket != null and not is_klaar and not stilgelegd and not praat:
		voortgang += delta / werktijd
		if voortgang >= 1.0:
			voortgang = 1.0
			is_klaar = true
			ticket.staat = RushTicket.Staat.KLAAR
			ticket.geduld = maxf(ticket.geduld, 0.6)
			_hop = 1.0
			klaar.emit(self)
	if sprite.visible:
		var bezig := ticket != null and not is_klaar and not stilgelegd and not praat
		sprite.position.y = -8 - (absf(sin(_tijd * 14.0)) * 1.0 if bezig else 0.0) \
			- sin(_hop * PI) * 3.0
		if praat:
			if sprite.animation != &"talk_down":
				sprite.play(&"talk_down")
		elif sprite.animation != &"idle_down":
			sprite.play(&"idle_down")
	queue_redraw()


func _draw() -> void:
	var kleur: Color = RushData.VAK_KLEUR[vak]
	# Stoel achter het bureau, alleen zichtbaar als er niemand zit.
	if not sprite.visible:
		draw_rect(Rect2(-6, -22, 12, 10), Color("#2a2d38"))
		draw_rect(Rect2(-5, -21, 10, 4), Color("#3b4050"))
	if gloed:
		var a := 0.45 + 0.35 * sin(_tijd * 8.0)
		draw_rect(Rect2(-19, -16, 38, 18), Color(kleur.r, kleur.g, kleur.b, a), false, 2.0)
	# Bureaublad, voorkant en schaduw.
	draw_rect(Rect2(-17, -13, 34, 14), Color(0, 0, 0, 0.22))
	draw_rect(Rect2(-16, -14, 32, 9), Color("#e9e6dc"))
	draw_rect(Rect2(-16, -5, 32, 5), Color("#b9b4a6"))
	draw_rect(Rect2(-16, -14, 32, 14), Color("#5d5a52"), false, 1.0)
	# Naamplaatje in de vakkleur; bij twee vakken half om half.
	var deel := 18.0 / vakken.size()
	for i: int in vakken.size():
		var k: Color = RushData.VAK_KLEUR[vakken[i]]
		draw_rect(Rect2(-9 + i * deel, -4, deel, 3), k if actief else k.lerp(Color("#8a8a8a"), 0.6))
	# Monitor: achterkant, je kijkt over de schouder van de collega.
	draw_rect(Rect2(-7, -20, 14, 8), Color("#23262f"))
	draw_rect(Rect2(-6, -19, 12, 6), Color("#3a3f4d"))
	draw_rect(Rect2(-1, -12, 2, 2), Color("#23262f"))
	# Toetsenbord en mok.
	draw_rect(Rect2(-6, -10, 10, 2), Color("#cfcabd"))
	draw_rect(Rect2(8, -12, 3, 3), kleur.darkened(0.2))

	if ticket != null and not is_klaar:
		# Het kaartje op het bureau, en de voortgang boven het hoofd.
		draw_rect(Rect2(-14, -13, 6, 7), Color("#fbf8ef"))
		draw_rect(Rect2(-14, -13, 6, 2), kleur)
		_ring(Vector2(14, -36), voortgang, kleur)
		if stilgelegd or praat:
			_zzz()
	if is_klaar:
		var y := -36.0 - sin(_hop * PI) * 6.0 - absf(sin(_tijd * 4.0)) * 1.5
		_vinkje(Vector2(14, y))


func _ring(c: Vector2, deel: float, kleur: Color) -> void:
	draw_circle(c, 6.0, Color(0, 0, 0, 0.5))
	draw_arc(c, 4.5, -PI / 2.0, -PI / 2.0 + TAU, 20, Color(1, 1, 1, 0.18), 2.0)
	if deel > 0.0:
		draw_arc(c, 4.5, -PI / 2.0, -PI / 2.0 + TAU * deel, 20, kleur.lightened(0.25), 2.0)


func _vinkje(c: Vector2) -> void:
	draw_circle(c + Vector2(0, 1), 7.0, Color(0, 0, 0, 0.35))
	draw_circle(c, 7.0, Color("#2fb67c"))
	draw_circle(c, 7.0, Color("#1d7a52"), false, 1.0)
	var w := Color.WHITE
	draw_line(c + Vector2(-3, 0), c + Vector2(-1, 2), w, 2.0)
	draw_line(c + Vector2(-1, 2), c + Vector2(3, -3), w, 2.0)


func _zzz() -> void:
	var f := fmod(_tijd, 1.2) / 1.2
	var p := Vector2(-14, -40 - f * 6.0)
	var k := Color(1, 1, 1, 1.0 - f)
	draw_line(p, p + Vector2(3, 0), k)
	draw_line(p + Vector2(3, 0), p + Vector2(0, 3), k)
	draw_line(p + Vector2(0, 3), p + Vector2(3, 3), k)


func hit(p: Vector2) -> bool:
	return Rect2(position + Vector2(-17, -50), Vector2(34, 54)).has_point(p)
