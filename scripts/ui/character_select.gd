extends Control
## Karakterselectie. Je kiest één collega en speelt de hele dag als hem.
##
## Herbouwd voor het portretcanvas van 192x416. De oude versie was een rij
## kaarten met vijf tekstblokken eronder: die liep aan twee kanten het scherm
## uit, en las als een spec-sheet in plaats van als een keuze.
##
## Nu van boven naar beneden: een podium met de wereldsprite waar je de rest van
## het spel naar kijkt, de tagline, een balk met de tien tickets waarin jouw
## eigen tickets oplichten, één regel over hoe jouw dag speelt, en de lijst.
##
## De ticketbalk is het hart van het scherm. Van collega wisselen laat de
## opgelichte blokjes verspringen, en dat is de kernspanning uit
## docs/GAME_DESIGN.md in één beweging, zonder er een zin over te schrijven.
##
## Mobiel is de randvoorwaarde: op een telefoon van 1080 breed is één logische
## px ongeveer 0,34 mm, dus 48 dp komt uit op 26 px. Vandaar rijen van 26 en een
## knop van 28. Aantikbare dingen kleiner dan dat zijn er niet.

const PODIUM_H := 96
const RIJ_H := 26
const SPRITE_SCHAAL := 2
const WISSEL_TIJD := 0.25
## Na hoeveel rust de bezigheid één keer speelt. Niet doorlussen: dan wordt het
## een tic in plaats van een grap.
const BEZIG_NA := 1.2

var _ids: Array[StringName] = []
var _rijen: Array[PanelContainer] = []
var _balken: Array[ColorRect] = []
var _index: int = 0

var _podium: Control
var _sprite: AnimatedSprite2D
var _schaduw: Sprite2D
var _gloed: Sprite2D
var _tagline: Label
var _stijl: Label
var _blokjes: Array[ColorRect] = []
var _wissel: Tween
var _scroll: ScrollContainer
var _bezig_t: float = 0.0
var _bezig_gedaan: bool = false


func _ready() -> void:
	UiKit.full_rect(self)
	var bg := ColorRect.new()
	bg.color = UiKit.INK.darkened(0.25)
	UiKit.full_rect(bg)
	add_child(bg)

	var root := VBoxContainer.new()
	UiKit.full_rect(root)
	root.offset_left = 4
	root.offset_right = -4
	root.offset_top = 3
	root.offset_bottom = -3
	root.add_theme_constant_override("separation", 2)
	add_child(root)

	var kop := UiKit.label("WIE BEN JIJ VANDAAG", UiKit.FS_BODY, UiKit.BLUEBIRD_BRIGHT)
	kop.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(kop)

	root.add_child(_bouw_podium())

	_tagline = UiKit.label("", UiKit.FS_SMALL, UiKit.WIT)
	_tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tagline.autowrap_mode = TextServer.AUTOWRAP_OFF
	_tagline.clip_text = true
	root.add_child(_tagline)

	# De balk is anders ongelabeld: tien blokjes die niemand als "de tickets van
	# vandaag" herkent zonder een kop erboven.
	var balkkop := UiKit.label("DE TIEN TICKETS VAN VANDAAG", UiKit.FS_SMALL, UiKit.GRIJS)
	balkkop.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	balkkop.autowrap_mode = TextServer.AUTOWRAP_OFF
	balkkop.clip_text = true
	root.add_child(balkkop)

	root.add_child(_bouw_ticketbalk())

	_stijl = UiKit.label("", UiKit.FS_SMALL, UiKit.GRIJS)
	root.add_child(_stijl)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_scroll)
	var scroll := _scroll
	var lijst := VBoxContainer.new()
	lijst.add_theme_constant_override("separation", 2)
	lijst.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(lijst)

	for id: StringName in GameData.character_ids():
		_ids.append(id)
		lijst.add_child(_bouw_rij(GameData.character(id), _ids.size() - 1))

	var go := UiKit.button("Aan het werk", UiKit.FS_BODY)
	go.custom_minimum_size = Vector2(0, 28)
	go.pressed.connect(_start)
	root.add_child(go)

	_kies(0, false)
	go.grab_focus()

	# QA: `--scherm=select --autostart` doorloopt de normale startroute.
	# Ruim na de infade van Shell: die duurt 0.35s en zolang hij loopt weigert
	# `_change_scene` een tweede overgang. Bij 0.3s klikte de QA-start dus in
	# het niets en bleef de testroute op dit scherm hangen.
	if "--autostart" in OS.get_cmdline_user_args():
		await get_tree().create_timer(0.9).timeout
		_start()


# --- podium ---------------------------------------------------------------

## Een strook echte kantoorvloer met de gekozen collega erop. Dit is de sprite
## waar je de komende halfuur naar kijkt; die hoorde op dit scherm te staan.
func _bouw_podium() -> Control:
	_podium = Control.new()
	_podium.custom_minimum_size = Vector2(0, PODIUM_H)
	_podium.clip_contents = true
	_podium.mouse_filter = Control.MOUSE_FILTER_STOP

	var muur := ColorRect.new()
	muur.color = Color("#484e60")
	muur.set_anchors_preset(Control.PRESET_TOP_WIDE)
	muur.offset_bottom = PODIUM_H * 0.62
	_podium.add_child(muur)

	var vloer := TextureRect.new()
	vloer.texture = _tegel(".")
	vloer.stretch_mode = TextureRect.STRETCH_TILE
	vloer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	vloer.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	vloer.offset_top = -PODIUM_H * 0.38
	_podium.add_child(vloer)

	var wand := TextureRect.new()
	wand.texture = load("res://assets/sprites/props/monitorwand_4x1.png")
	wand.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	wand.stretch_mode = TextureRect.STRETCH_KEEP
	wand.scale = Vector2(2, 2)
	wand.position = Vector2(6, PODIUM_H * 0.62 - 34)
	_podium.add_child(wand)

	var bureau := TextureRect.new()
	bureau.texture = load("res://assets/sprites/props/bureau_4x4.png")
	bureau.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bureau.stretch_mode = TextureRect.STRETCH_KEEP
	bureau.scale = Vector2(0.5, 0.5)
	bureau.position = Vector2(136, PODIUM_H * 0.62 - 4)
	_podium.add_child(bureau)

	# de accentgloed ligt onder de schaduw: dat leest als licht op de vloer
	_gloed = Sprite2D.new()
	_gloed.texture = load("res://assets/sprites/props/schaduw_karakter.png")
	_gloed.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_gloed.scale = Vector2(5.0, 3.0)
	_podium.add_child(_gloed)

	_schaduw = Sprite2D.new()
	_schaduw.texture = load("res://assets/sprites/props/schaduw_karakter.png")
	_schaduw.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_schaduw.scale = Vector2(SPRITE_SCHAAL, SPRITE_SCHAAL)
	_podium.add_child(_schaduw)

	_sprite = AnimatedSprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2(SPRITE_SCHAAL, SPRITE_SCHAAL)
	_sprite.centered = true
	_podium.add_child(_sprite)
	return _podium


static func _tegel(teken: String) -> AtlasTexture:
	var meta := JSON.parse_string(
		FileAccess.get_file_as_string("res://assets/tilesets/office_atlas.json")) as Dictionary
	var coord: Array = (meta.get("coords", {}) as Dictionary).get(teken, [0, 0])
	var maat := int(meta.get("tile_size", 16))
	var at := AtlasTexture.new()
	at.atlas = load("res://assets/tilesets/office_atlas.png")
	at.region = Rect2(int(coord[0]) * maat, int(coord[1]) * maat, maat, maat)
	return at


# --- ticketbalk -----------------------------------------------------------

## Tien blokjes, één per ticket. Jouw eigen tickets lichten op in je accentkleur.
## Bewust niet aantikbaar: 15x10 px is op een telefoon niet te raken.
func _bouw_ticketbalk() -> Control:
	var rij := HBoxContainer.new()
	rij.add_theme_constant_override("separation", 2)
	for _i: int in GameData.ticket_ids().size():
		var blok := ColorRect.new()
		blok.custom_minimum_size = Vector2(0, 10)
		blok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rij.add_child(blok)
		_blokjes.append(blok)
	return rij


# --- lijst ----------------------------------------------------------------

func _bouw_rij(c: CharacterDef, index: int) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(0, RIJ_H)
	_rijen.append(p)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 3)
	p.add_child(h)

	var balk := ColorRect.new()
	balk.custom_minimum_size = Vector2(3, 0)
	balk.color = c.accent
	h.add_child(balk)
	_balken.append(balk)

	var portret := TextureRect.new()
	portret.texture = _portrait_for(c)
	portret.custom_minimum_size = Vector2(16, 20)
	portret.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portret.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portret.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	h.add_child(portret)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var naam := UiKit.label(c.name, UiKit.FS_BODY, UiKit.WIT)
	naam.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.add_child(naam)
	var rol := UiKit.label(c.role, UiKit.FS_SMALL, UiKit.GRIJS)
	rol.autowrap_mode = TextServer.AUTOWRAP_OFF
	rol.clip_text = true
	v.add_child(rol)

	var telling := UiKit.label("%d/10" % c.owned_tickets.size(), UiKit.FS_SMALL, c.accent)
	telling.autowrap_mode = TextServer.AUTOWRAP_OFF
	telling.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(telling)

	var knop := Button.new()
	knop.flat = true
	UiKit.full_rect(knop)
	knop.pressed.connect(_kies.bind(index, true))
	p.add_child(knop)
	return p


# --- kiezen ---------------------------------------------------------------

func _kies(index: int, met_animatie: bool) -> void:
	if index < 0 or index >= _ids.size():
		return
	var vorige := _index
	_index = index
	var c: CharacterDef = GameData.character(_ids[index])

	for i: int in _rijen.size():
		var gekozen := i == index
		var kleur: Color = GameData.character(_ids[i]).accent
		_rijen[i].add_theme_stylebox_override("panel", UiKit.panel_krap(
			UiKit.INK.lightened(0.14) if gekozen else UiKit.INK.lightened(0.05),
			kleur if gekozen else UiKit.LINE))
		_balken[i].color = kleur if gekozen else Color(kleur, 0.25)

	_tagline.text = "\"%s\"" % c.tagline
	_tagline.add_theme_color_override("font_color", c.accent)
	_stijl.text = c.stijl

	var eigen := {}
	for t: StringName in c.owned_tickets:
		eigen[t] = true
	var ids: Array[StringName] = GameData.ticket_ids()
	for i: int in _blokjes.size():
		_blokjes[i].color = c.accent if eigen.has(ids[i]) else Color("#2b3144")

	# Zeven rijen passen niet allemaal tegelijk; de gekozene hoort altijd in
	# beeld te staan, ook als je met het toetsenbord door de lijst loopt.
	if _scroll != null and index < _rijen.size():
		_scroll.ensure_control_visible(_rijen[index])

	_zet_sprite(c, met_animatie, index >= vorige)

	if met_animatie:
		AudioDirector.play_ui(&"klik")
		# Mobiel speelt vaak zonder geluid, dus het onderscheid mag daar niet
		# alleen aan hangen. Via Haptiek, want die kent de duur van een TIK en
		# houdt zijn mond op alles wat geen telefoon is.
		Haptiek.tril(Haptiek.Sterkte.TIK)


func _zet_sprite(c: CharacterDef, met_animatie: bool, van_rechts: bool) -> void:
	var midden := Vector2(_podium.size.x * 0.5, PODIUM_H - 12)
	if _podium.size.x <= 0.0:
		midden.x = 92.0
	_sprite.sprite_frames = CharacterSprites.frames_for(
		c.look, c.color, c.skin, c.hair, c.pants, c.accent)
	_sprite.offset = Vector2(0, -17)
	_gloed.modulate = Color(c.accent, 0.30)

	if _wissel != null and _wissel.is_running():
		_wissel.kill()

	_bezig_t = 0.0
	_bezig_gedaan = false
	if not met_animatie:
		_sprite.position = midden
		_schaduw.position = midden
		_gloed.position = midden
		_sprite.play(&"idle_down")
		return

	# De nieuwe collega loopt binnen vanaf de kant waar je naartoe bewoog, zodat
	# gebaar en animatie dezelfde richting hebben.
	var van := midden + Vector2(70.0 if van_rechts else -70.0, 0.0)
	_sprite.position = van
	_schaduw.position = van
	_gloed.position = van
	_sprite.play(&"walk_left" if van_rechts else &"walk_right")
	_wissel = create_tween()
	_wissel.set_parallel(true)
	_wissel.tween_property(_sprite, "position", midden, WISSEL_TIJD)
	_wissel.tween_property(_schaduw, "position", midden, WISSEL_TIJD)
	_wissel.tween_property(_gloed, "position", midden, WISSEL_TIJD)
	_wissel.chain().tween_callback(func() -> void: _sprite.play(&"idle_down"))


## Swipen over het podium wisselt van collega.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		var d := (event as InputEventScreenDrag).relative.x
		if absf(d) > 6.0:
			_kies(wrapi(_index + (-1 if d > 0.0 else 1), 0, _ids.size()), true)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("move_down"):
		_kies(wrapi(_index + 1, 0, _ids.size()), true)
	elif event.is_action_pressed("move_up"):
		_kies(wrapi(_index - 1, 0, _ids.size()), true)


## Voorkeur voor het pixel-portret dat uit de echte teamfoto is afgeleid;
## anders de sprite zelf.
func _portrait_for(c: CharacterDef) -> Texture2D:
	if c.portrait != "" and ResourceLoader.exists(c.portrait):
		return load(c.portrait)
	return null


func _start() -> void:
	# Zwaarder dan het doorlopen van de lijst: dit is de keuze die de hele
	# speelbeurt vastlegt, en wisselen kan niet.
	Haptiek.tril(Haptiek.Sterkte.STOOT)
	AudioDirector.play_ui(&"klik")
	QuestEngine.start_run(_ids[_index])
	Shell.goto_game()


func _process(delta: float) -> void:
	if _bezig_gedaan or _sprite == null or _sprite.sprite_frames == null:
		return
	if _wissel != null and _wissel.is_running():
		return
	if _sprite.animation == &"bezig_down":
		return
	_bezig_t += delta
	if _bezig_t < BEZIG_NA:
		return
	if not _sprite.sprite_frames.has_animation(&"bezig_down") \
			or _sprite.sprite_frames.get_frame_count(&"bezig_down") == 0:
		_bezig_gedaan = true
		return
	_bezig_gedaan = true
	_sprite.play(&"bezig_down")
	await _sprite.animation_finished
	if is_instance_valid(_sprite):
		_sprite.play(&"idle_down")
