class_name Juice
extends RefCounted
## Impactframes voor het hele spel.
##
## Vier primitieven die iets tastbaar maken: de camera die even schokt, een
## wolkje post-it-snippers, een knop die indeukt onder je duim en een paneel
## dat vanaf de rand het beeld in glijdt. Ze staan bij elkaar zodat "een tik"
## overal even hard aankomt — dezelfde reden waarom de duurwaarden van
## `Haptiek` op één plek staan.
##
## Alles is `static`: er is geen node om te plaatsen en geen toestand om bij te
## houden. Wie een schok wil, roept `Juice.schok()` aan; de camera meldt zich
## zelf in de groep `game_camera`, dus niemand hoeft hem door te geven.

## Hoe lang de snippers van `confetti()` in beeld blijven, in seconden.
const CONFETTI_LEVEN := 0.9


## De camera even laten schokken.
##
## Klein houden: het canvas is 192x416 met pixel-snapping, dus twee pixels is
## al een duidelijke tik en vijf is een aardbeving. Zonder camera in de boom
## (een test, het titelscherm) gebeurt er stil niets — de aanroeper hoeft niet
## te weten of er een wereld staat.
static func schok(px: float = 2.0, duur: float = 0.25) -> void:
	var boom := Engine.get_main_loop() as SceneTree
	if boom == null:
		return
	var cam := boom.get_first_node_in_group(&"game_camera")
	if cam != null and cam.has_method(&"schok"):
		cam.call(&"schok", px, duur)


## Een wolkje post-it-snippers vanaf `positie` (canvascoördinaten), als kind
## van `ouder`.
##
## Geen texture: dan tekent Godot elk deeltje als een vierkantje van 1x1 dat de
## schaal nog 2 tot 3 keer vergroot — precies de pixel-art die het spel al is.
## De snippers krijgen de vijf papierkleuren van het bord mee
## (`UiKit.POSTIT_KLEUREN`) en doven uit via `color_ramp`, zodat ze niet hard
## uit beeld knippen.
##
## Tijdens een geautomatiseerde speelbeurt (`Autopilot.gevraagd()`) blijft dit
## uit: de deeltjes zijn willekeurig en zouden elk opgenomen frame anders
## maken. De node ruimt zichzelf op zodra het laatste deeltje weg is.
static func confetti(ouder: Node, positie: Vector2, aantal: int = 18) -> void:
	if ouder == null or Autopilot.gevraagd():
		return
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = aantal
	p.lifetime = CONFETTI_LEVEN
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 3.0
	p.direction = Vector2(0.0, -1.0)
	p.spread = 70.0
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 80.0
	p.gravity = Vector2(0.0, 140.0)
	p.angular_velocity_min = -200.0
	p.angular_velocity_max = 200.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 3.0
	p.color_initial_ramp = _postit_ramp()
	p.color_ramp = _uitdoof_ramp()
	ouder.add_child(p)
	p.global_position = positie
	p.emitting = true
	p.finished.connect(p.queue_free)


## De papierkleuren van het bord op gelijke afstanden, in de volgorde waarin
## `UiKit.POSTIT_KLEUREN` ze kent. Elk deeltje trekt bij zijn geboorte één punt
## uit deze ramp.
static func _postit_ramp() -> Gradient:
	var g := Gradient.new()
	var kleuren: Array = UiKit.POSTIT_KLEUREN.values()
	var laatste := maxi(1, kleuren.size() - 1)
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for i: int in kleuren.size():
		offsets.append(float(i) / float(laatste))
		colors.append(kleuren[i] as Color)
	g.offsets = offsets
	g.colors = colors
	return g


## Wit naar doorzichtig. `color_ramp` vermenigvuldigt met de startkleur, dus
## wit laat het papier met rust en alleen de alpha loopt weg. Het eerste stuk
## blijft vol: anders zijn de snippers al vaal op het moment dat ze het meest
## opvallen.
static func _uitdoof_ramp() -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color.WHITE, Color.WHITE, Color(1.0, 1.0, 1.0, 0.0)])
	return g


## Een knop die onder je duim indeukt en terugveert.
##
## Via `scale`, niet via `size`: een Container deelt `size` en `position` elke
## frame opnieuw uit, maar laat `scale` met rust, dus dit werkt ook voor knoppen
## in een VBox of in de knoppenbalk. De pivot gaat naar het midden zodat hij
## ter plekke krimpt en niet naar linksboven wegtrekt. Een tweede druk tijdens
## de eerste breekt die af; het eindpunt is toch `Vector2.ONE`.
static func squash(c: Control, diep: float = 0.08, duur: float = 0.12) -> void:
	if c == null or not c.is_inside_tree():
		return
	var vorige := c.get_meta(&"juice_squash", null) as Tween
	if vorige != null:
		vorige.kill()
	c.pivot_offset = c.size * 0.5
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2.ONE * (1.0 - diep), duur * 0.4) \
		.set_trans(Tween.TRANS_SINE)
	tw.tween_property(c, "scale", Vector2.ONE, duur * 0.6) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	c.set_meta(&"juice_squash", tw)


## Een paneel dat vanuit een verschuiving `van` (bv. `Vector2(0, 40)`: van
## onderen) naar zijn eigen plek glijdt.
##
## Alleen voor Controls die met ankers staan en NIET in een Container hangen.
## Een Container deelt `position` elke frame opnieuw uit en overschrijft de
## tween: je ziet dan niets, of erger, een paneel dat één frame ernaast staat.
## Vergelijk `squash()`, dat via `scale` werkt en daar geen last van heeft.
static func schuif_in(c: Control, van: Vector2, duur: float = 0.18) -> void:
	if c == null or not c.is_inside_tree():
		return
	var doel := c.position
	c.position = doel + van
	c.create_tween().tween_property(c, "position", doel, duur) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
