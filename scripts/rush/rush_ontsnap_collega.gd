class_name RushOntsnapCollega
extends Node2D
## Een collega die tussen jou en de deur staat. Raak je hem, dan heeft hij je
## even: "Kort vraagje!" en je staat stil.
##
## Na één gesprek laat hij je gaan en wordt hij doorzichtig. Dat is geen
## vriendelijkheid maar een garantie: een collega die in de enige deur blijft
## staan zou het level onspeelbaar maken, en zo kan dat nooit.

enum Gedrag {
	STAAN,     ## staat waar hij staat
	STAPPEN,   ## ziet je aankomen en stapt je pad in
	IJSBEREN,  ## loopt aan de telefoon heen en weer
}

## Halve maat van het raakvlak rond de voeten, gelijk aan dat van de speler.
const HALF := Vector2(5, 4)
## Hoe ver voor je uit een stapper je opmerkt. De dag telt erbij op.
const OPMERK := 64.0

const ZINNEN := [
	"Heb je even?",
	"Kort vraagje!",
	"Nog één dingetje...",
	"Kun je even meekijken?",
	"Ga je al?",
]
## Wie iets eigens te zeggen heeft. De rest kiest uit `ZINNEN`.
const EIGEN := {
	&"jonathan": "Even over de architectuur...",
	&"dennis": "Ben je morgen bij de retro?",
	&"koen": "Even over die video...",
	&"willem": "Heb je de klant gesproken?",
	&"bastiaan": "Nog even over de offerte!",
	&"danny": "Zag je die conversie?",
	&"victor": "Is dat ticket al gemerged?",
	&"daan": "Even over de planning...",
}

var persoon: StringName = &""
var gedrag := Gedrag.STAAN
var snelheid := 50.0
var opmerk := OPMERK
var gesproken := false
var sprite: AnimatedSprite2D

## Mag ik hier staan? Komt van de ontsnapping, die de vloer kent.
var _vrij: Callable
var _doel_y := 0.0
var _van := 0.0
var _tot := 0.0
var _gestapt := false
var _gegroet := false


func setup(id: StringName, g: Gedrag, vrij: Callable) -> void:
	persoon = id
	gedrag = g
	_vrij = vrij
	_doel_y = position.y
	sprite = AnimatedSprite2D.new()
	sprite.offset = Vector2(0, -16)
	sprite.position = Vector2(0, 3)
	add_child(sprite)
	sprite.sprite_frames = frames_voor(id)
	sprite.play(&"idle_right")
	# Niet allemaal tegelijk ademen.
	sprite.frame = randi() % 2


## Het loopje van iemand, speelbaar personage of niet.
static func frames_voor(id: StringName) -> SpriteFrames:
	var c: CharacterDef = GameData.character(id)
	if c != null:
		return CharacterSprites.frames_for(c.look, c.color, c.skin, c.hair, c.pants, c.accent)
	var n: NpcDef = GameData.npc(id)
	if n != null:
		return CharacterSprites.frames_for(n.look, n.color, n.skin, n.hair, n.pants, n.accent)
	return null


## IJsberen tussen twee hoogtes in dezelfde kolom.
func zet_baan(van: float, tot: float) -> void:
	_van = van
	_tot = tot
	_doel_y = tot


func zin() -> String:
	if EIGEN.has(persoon) and randf() < 0.6:
		return EIGEN[persoon]
	return ZINNEN[randi() % ZINNEN.size()]


func tik(delta: float, speler: Vector2) -> void:
	if gesproken:
		return
	var voor := position.x < speler.x
	var afstand := speler.x - position.x
	if voor and afstand < opmerk + 50.0 and not _gegroet and gedrag != Gedrag.STAPPEN:
		_gegroet = true
		RushOntsnapBallon.zeg(self, zin(), 1.6)
	match gedrag:
		Gedrag.STAPPEN:
			if voor and not _gestapt and afstand < opmerk and absf(speler.y - position.y) < 90.0:
				_gestapt = true
				_doel_y = speler.y
				RushOntsnapBallon.zeg(self, "Heb je even?", 1.4)
			_loop(delta)
		Gedrag.IJSBEREN:
			if absf(position.y - _doel_y) < 0.5:
				_doel_y = _van if is_equal_approx(_doel_y, _tot) else _tot
			_loop(delta)
		_:
			sprite.play(&"idle_right")


func _loop(delta: float) -> void:
	var dy := clampf(_doel_y - position.y, -snelheid * delta, snelheid * delta)
	if absf(dy) < 0.01:
		sprite.play(&"idle_right")
		return
	var nieuw := position + Vector2(0, dy)
	if not _vrij.call(nieuw):
		# Tegen een bureau aan: daar blijft hij staan.
		_doel_y = position.y
		sprite.play(&"idle_right")
		return
	position = nieuw
	sprite.play(&"walk_down" if dy > 0.0 else &"walk_up")


func raakt(p: Vector2, half: Vector2) -> bool:
	if gesproken:
		return false
	return absf(p.x - position.x) < HALF.x + half.x and absf(p.y - position.y) < HALF.y + half.y


## Waar hij straks staat: voor de bot, die er omheen moet.
func straks_y() -> float:
	return _doel_y


## Hij heeft je. Geeft terug wat hij zegt.
func heeft_je() -> String:
	gesproken = true
	var z := zin()
	RushOntsnapBallon.zeg(self, z, 1.6)
	sprite.play(&"talk_right")
	var tw := create_tween()
	tw.tween_interval(1.0)
	tw.tween_property(sprite, ^"modulate:a", 0.5, 0.4)
	return z
