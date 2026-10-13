class_name RushOntsnapDirk
extends Node2D
## Dirk, die je uren wil. Ook nu het kantoor in brand staat.
##
## Hij loopt jouw voetstappen na, over je spoor: door dezelfde gaten, dus
## nooit door een bureau heen. Hij blijft vlak achter je hangen, een elastiekje
## dat hem bijtrekt als je uitloopt, en af en toe duikt hij naar voren. Dat
## kondigt hij aan: hij zakt door zijn knieën en er verschijnt een rode streep
## over de vloer, in jouw rij. Stap je opzij, dan grijpt hij mis. Blijf je
## staan, dan heeft hij je: "Uren al geboekt?"
##
## Of hij komt je tegemoet (vrijdag, van voren): dan loopt hij op je af en
## schuift hij mee naar jouw hoogte, en moet je om hem heen. Ben je hem
## voorbij, dan draait hij om en zit hij alsnog achter je aan.
##
## Hij beslist alleen zelf; wat hij vangt, hoe lang je stilstaat en wat dat
## kost, regelt de ontsnapping.

enum Staat {
	WEG,       ## nog niet in beeld
	TEGEMOET,  ## loopt je van voren tegemoet
	LOOPT,     ## over je spoor, achter je aan
	LOERT,     ## zakt door de knieën: zo meteen duikt hij
	DUIKT,     ## schiet naar voren, recht door één rij
	HIJGT,     ## na een duik, even op adem komen
	PRAAT,     ## heeft je, en vraagt naar je uren
	RUST,      ## tevreden; geeft je een stukje voorsprong
	KOFFIE,    ## ziet jou koffie pakken en wil ook
}

## Gelijk aan het raakvlak van de speler.
const HALF := Vector2(5, 4)
## Jouw snelheid. Alles van Dirk is daar een deel van.
const SNEL := 56.0
## Hoe ver hij over je spoor achter je wil blijven. Loop je recht door, dan
## hangt hij zo'n 36 px achter je: twee tegels, goed in beeld.
const DOEL := 30.0
const LOER := 0.55
const DUIK_SNEL := 2.8
const DUIK_DUUR := 0.85
const HIJG := 0.6
const PRAAT := 1.5
const RUST := 1.1
const KOFFIE := 1.2

var staat := Staat.WEG
var sprite: AnimatedSprite2D
## Seconden tussen twee duiken, van en tot.
var duik := Vector2(3.0, 4.5)
## Hoe hard het elastiek hem hooguit trekt, als deel van jouw snelheid.
var max_snel := 1.45
## De rij waar hij doorheen duikt (bij LOERT en DUIKT).
var lijn_y := 0.0
## Hoe ver de aankondiging is, 0..1.
var loer := 0.0
## Hoe lang hij al in beeld is.
var sinds := 0.0

var _t := 0.0
var _i := 0
var _klok := 3.0
var _vrij: Callable
var _vorige := Vector2.ZERO
var _gepakt := 0
## Na een praatje laat hij je even met rust, ook als het vuur hem eerder
## weer aan het lopen zet.
var _genade := 0.0


func setup(vrij: Callable) -> void:
	_vrij = vrij
	visible = false
	sprite = AnimatedSprite2D.new()
	sprite.offset = Vector2(0, -16)
	sprite.position = Vector2(0, 3)
	sprite.sprite_frames = RushOntsnapCollega.frames_voor(&"dirk")
	add_child(sprite)
	sprite.play(&"idle_left")


func actief() -> bool:
	return staat != Staat.WEG


## Achter je, op je spoor, bij punt `i`.
func verschijn_achter(spoor: PackedVector2Array, i: int, roep: String) -> void:
	_i = clampi(i, 0, spoor.size() - 1)
	position = spoor[_i]
	_vorige = position
	visible = true
	_zet(Staat.LOOPT)
	_klok = randf_range(duik.x, duik.y) * 0.7
	sinds = 0.0
	if roep != "":
		RushOntsnapBallon.zeg(self, roep, 1.6)
		AudioDirector.play_sfx(&"rush_dirk", 0.05, -2.0)


## Vóór je, op `p`, en hij komt eraan.
func verschijn_voor(p: Vector2, roep: String) -> void:
	position = p
	_vorige = position
	visible = true
	_zet(Staat.TEGEMOET)
	sinds = 0.0
	RushOntsnapBallon.zeg(self, roep, 1.8)
	AudioDirector.play_sfx(&"rush_dirk", 0.05, -2.0)


func _zet(s: Staat) -> void:
	staat = s
	_t = 0.0
	loer = 0.0


## Eén stap. Geeft true als hij je nu te pakken heeft.
## `stil`: jij staat al stil (iemand anders heeft je). `rechts`: de rechterrand
## van het beeld, want duiken doet hij alleen waar je hem ziet.
func tik(delta: float, speler: Vector2, spoor: PackedVector2Array, stil: bool,
		vuur_x: float, rechts: float) -> bool:
	if staat == Staat.WEG:
		return false
	_t += delta
	sinds += delta
	_genade = maxf(0.0, _genade - delta)
	_vorige = position
	match staat:
		Staat.TEGEMOET:
			_tegemoet(delta, speler, spoor)
		Staat.LOOPT:
			_volg(delta, speler, spoor, stil)
			_klok -= delta
			if _klok <= 0.0 and not stil:
				_probeer_duik(speler, rechts)
		Staat.LOERT:
			loer = clampf(_t / LOER, 0.0, 1.0)
			# Op zijn plek, maar alvast op de hoogte van de rij die hij wil.
			_schuif_y(lijn_y, 50.0 * delta)
			if _t >= LOER:
				_zet(Staat.DUIKT)
				AudioDirector.play_sfx(&"rush_weg", 0.05, -2.0)
		Staat.DUIKT:
			_duik(delta, speler, stil)
		Staat.HIJGT:
			if _t >= HIJG:
				_koppel(spoor)
				_zet(Staat.LOOPT)
		Staat.PRAAT:
			if _t >= PRAAT:
				_zet(Staat.RUST)
		Staat.RUST:
			if _t >= RUST:
				_koppel(spoor)
				_zet(Staat.LOOPT)
		Staat.KOFFIE:
			if _t >= KOFFIE:
				_zet(Staat.LOOPT)
	_voor_vuur(spoor, vuur_x)
	_loopje(speler)
	if stil or _genade > 0.0 or staat in [Staat.PRAAT, Staat.RUST, Staat.HIJGT, Staat.KOFFIE]:
		return false
	return absf(speler.x - position.x) < HALF.x * 2.0 and absf(speler.y - position.y) < HALF.y * 2.0


## Over je spoor, met een elastiekje: hoe verder je uitloopt, hoe harder hij
## trekt. Heeft iemand anders je net, dan wacht hij netjes zijn beurt af.
func _volg(delta: float, speler: Vector2, spoor: PackedVector2Array, stil: bool) -> void:
	var a := afstand(speler, spoor)
	if stil and a < 22.0:
		return
	var v := clampf(SNEL * 0.9 + 0.9 * (a - DOEL), SNEL * 0.5, SNEL * max_snel)
	_loop_spoor(spoor, v * delta)


func _loop_spoor(spoor: PackedVector2Array, stap: float) -> void:
	while stap > 0.0 and _i < spoor.size():
		var naar := spoor[_i] - position
		if naar.length() <= stap:
			position = spoor[_i]
			stap -= naar.length()
			_i += 1
		else:
			position += naar.normalized() * stap
			stap = 0.0


## Hoe ver hij over je spoor achter je zit.
func afstand(speler: Vector2, spoor: PackedVector2Array) -> float:
	var a := 0.0
	var p := position
	for k: int in range(_i, spoor.size()):
		a += p.distance_to(spoor[k])
		p = spoor[k]
		if a > 400.0:
			return a
	return a + p.distance_to(speler)


func _probeer_duik(speler: Vector2, rechts: float) -> void:
	_klok = 0.4
	# Alleen in beeld, achter je, en dichtbij genoeg dat het telt.
	if position.x > rechts - 8.0 or position.x < speler.x + 14.0 or position.x - speler.x > 90.0:
		return
	# En alleen als die rij tot voorbij jou vrij is: duiken in een bureau doet
	# hij niet.
	var y := speler.y
	var x := position.x
	while x > speler.x - 30.0:
		if not _vrij.call(Vector2(x, y)):
			return
		x -= 6.0
	lijn_y = y
	_klok = randf_range(duik.x, duik.y)
	_zet(Staat.LOERT)
	RushOntsnapBallon.zeg(self, "Hé!", 0.8)
	AudioDirector.play_sfx(&"rush_dirk", 0.1, -6.0)


func _duik(delta: float, speler: Vector2, stil: bool) -> void:
	var stap := SNEL * DUIK_SNEL * delta
	_schuif_y(lijn_y, 60.0 * delta)
	# Heeft iemand anders je al, dan remt hij af achter je in plaats van
	# erdoorheen te schieten: hij wacht zijn beurt wel af.
	if stil and absf(speler.y - position.y) < HALF.y * 3.0 and position.x - stap < speler.x + 14.0:
		_zet(Staat.HIJGT)
		return
	var p := position + Vector2(-stap, 0)
	if _vrij.call(p):
		position = p
	else:
		# Tegen een bureau. Au.
		RushOntsnapBallon.zeg(self, "Au!", 0.8)
		_zet(Staat.HIJGT)
		_t = -0.3
		return
	if _t >= DUIK_DUUR:
		_zet(Staat.HIJGT)


func _schuif_y(y: float, max_stap: float) -> void:
	var dy := clampf(y - position.y, -max_stap, max_stap)
	if absf(dy) > 0.01 and _vrij.call(position + Vector2(0, dy)):
		position.y += dy


func _tegemoet(delta: float, speler: Vector2, spoor: PackedVector2Array) -> void:
	if speler.x < position.x - 16.0:
		# Voorbij. Omdraaien en erachteraan.
		RushOntsnapBallon.zeg(self, "Hé, wacht!", 1.2)
		_koppel(spoor)
		_zet(Staat.HIJGT)
		_t = HIJG - 0.35
		_klok = duik.x
		return
	var p := position + Vector2(SNEL * 0.5 * delta, 0)
	if _vrij.call(p):
		position = p
	_schuif_y(speler.y, 24.0 * delta)


## Weer op je spoor: het dichtstbijzijnde punt dat nog voor hem ligt.
func _koppel(spoor: PackedVector2Array) -> void:
	if spoor.is_empty():
		return
	var beste := clampi(_i, 0, spoor.size() - 1)
	var d := INF
	for k: int in range(maxi(0, _i - 20), spoor.size()):
		var e := position.distance_squared_to(spoor[k])
		if e < d:
			d = e
			beste = k
	_i = beste


## Dirk verbrandt niet. Komt het vuur te dichtbij, dan rent hij vooruit over
## je spoor, wat hij ook aan het doen was.
func _voor_vuur(spoor: PackedVector2Array, vuur_x: float) -> void:
	if position.x <= vuur_x - 30.0:
		return
	if staat in [Staat.DUIKT, Staat.TEGEMOET]:
		return
	if staat != Staat.LOOPT and staat != Staat.LOERT:
		_koppel(spoor)
		_zet(Staat.LOOPT)
	# Maar niet voorbij jou: haalt het vuur jullie allebei in, dan staat hij
	# er maar even in.
	while _i < spoor.size() - 8 and position.x > vuur_x - 30.0:
		position = spoor[_i]
		_i += 1


## Hij heeft je. `zin` is wat hij vraagt.
func praat(zin: String) -> void:
	_gepakt += 1
	_genade = PRAAT + RUST
	_zet(Staat.PRAAT)
	RushOntsnapBallon.zeg(self, zin, 1.8)


## Jij pakt koffie. Hij ook, even.
func koffie() -> void:
	if staat in [Staat.LOOPT, Staat.LOERT, Staat.RUST]:
		_zet(Staat.KOFFIE)
		RushOntsnapBallon.zeg(self, "Koffie? Wacht!", 1.3)


func _loopje(speler: Vector2) -> void:
	var v := position - _vorige
	var anim := &"idle_left"
	match staat:
		Staat.PRAAT:
			anim = &"talk_left" if speler.x < position.x else &"talk_right"
		Staat.LOERT:
			anim = &"idle_left"
		Staat.KOFFIE:
			anim = &"idle_up"
		_:
			if v.length() > 0.01:
				if absf(v.x) > absf(v.y):
					anim = &"walk_left" if v.x < 0.0 else &"walk_right"
				else:
					anim = &"walk_down" if v.y > 0.0 else &"walk_up"
	if sprite.animation != anim:
		sprite.play(anim)
	sprite.speed_scale = 2.4 if staat == Staat.DUIKT else 1.2
	# Door de knieën: platter en breder naarmate de duik nadert.
	if staat == Staat.LOERT:
		sprite.scale = Vector2(1.0 + 0.12 * loer, 1.0 - 0.14 * loer)
		sprite.position = Vector2(roundf(sin(_t * 50.0) * loer), 3)
	elif staat == Staat.DUIKT:
		sprite.scale = Vector2(1.12, 0.92)
		sprite.position = Vector2(0, 3)
	else:
		sprite.scale = Vector2.ONE
		sprite.position = Vector2(0, 3)


func duikt_of_loert() -> bool:
	return staat == Staat.LOERT or staat == Staat.DUIKT
