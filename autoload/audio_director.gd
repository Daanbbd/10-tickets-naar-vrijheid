extends Node
## SFX-pool, muziek en ambience. Scene-onafhankelijk, dus autoload.
## Muziek draait door tijdens pause; wereld-SFX niet.
##
## Muziek werkt als een stapel lagen. Het kantoor ligt onderop en speelt de hele
## dag door; een gesprek, een minigame of het einde legt daar zijn eigen variant
## overheen. De hoogste gevulde laag klinkt, en zodra die leeg is valt het terug
## naar wat eronder lag. Zo hoeft geen enkele scene te weten wat er verder in
## het spel speelt: hij vult zijn laag en laat hem daarna weer los.
##
## Twee dingen houden het weg bij "hetzelfde deuntje, de hele dag":
##
## - Elk stuk hervat op de plek waar het verlaten werd. Kom je uit een minigame,
##   dan gaat het kantoor verder waar het gebleven was in plaats van opnieuw bij
##   maat een te beginnen. Zonder dit hoor je die openingsmaat twintig keer.
## - Stukken met een eigen kop (de intro, de overwinning) loopen pas ná die kop,
##   via loop_offset. De aanloop hoor je één keer, en dat is precies wat hem tot
##   een intro of een winstmoment maakt.

const SFX_DIR := "res://assets/audio/sfx"
const MUSIC_DIR := "res://assets/audio/music"
const VOICES := 12

## Van laag naar hoog. De laatste gevulde laag in deze volgorde wint.
const LAGEN: Array[StringName] = [&"basis", &"gesprek", &"minigame", &"overwinning"]

## Waar de loop begint bij stukken die een kop hebben die maar één keer hoort te
## klinken. De waarden horen bij de arrangementen in tools/generators/gen_audio.py.
const LOOP_START: Dictionary = {
	&"intro": 2.88,          # na de opgaande greep
	&"overwinning": 5.44,    # na de cadens, in de vamp
}

var _actief: AudioStreamPlayer      # speelt nu
var _vorige: AudioStreamPlayer      # klinkt uit
var _tw_in: Tween
var _tw_out: Tween

var _sfx: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _cache: Dictionary = {}

var _lagen: Dictionary = {}         # laag -> track
var _posities: Dictionary = {}      # track -> seconden
var _huidig: StringName = &""

var master_volume: float = 1.0
var music_volume: float = 0.6
var sfx_volume: float = 0.9


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_actief = _make_player(true)
	_vorige = _make_player(true)
	for i: int in VOICES:
		_sfx.append(_make_player(false))

	Bus.audio_cue_requested.connect(play_sfx)

	# De muziekstand volgt de spelstand. Scenes hoeven hier niets voor te doen.
	Bus.dialogue_started.connect(_op_gesprek_start)
	Bus.dialogue_finished.connect(_op_gesprek_eind)
	Bus.minigame_started.connect(_op_minigame_start)
	Bus.minigame_finished.connect(_op_minigame_eind)
	Bus.all_tickets_done.connect(_op_gewonnen)
	Bus.game_started.connect(_op_nieuw_spel)


func _make_player(always: bool) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.process_mode = Node.PROCESS_MODE_ALWAYS if always else Node.PROCESS_MODE_PAUSABLE
	add_child(p)
	return p


# --- SFX ------------------------------------------------------------------

func play_sfx(cue: StringName, pitch_jitter: float = 0.06, volume_db: float = 0.0) -> void:
	if cue == &"":
		return
	var stream := _load_audio("%s/%s" % [SFX_DIR, cue])
	if stream == null:
		return
	var p := _sfx[_next_voice]
	_next_voice = (_next_voice + 1) % VOICES
	p.stream = stream
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.volume_db = volume_db + linear_to_db(maxf(0.001, sfx_volume * master_volume))
	p.play()


## SFX die tijdens een gepauzeerde wereld hoorbaar moet blijven (UI, minigames).
func play_ui(cue: StringName) -> void:
	var stream := _load_audio("%s/%s" % [SFX_DIR, cue])
	if stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	p.stream = stream
	p.volume_db = linear_to_db(maxf(0.001, sfx_volume * master_volume))
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


# --- Muzieklagen ----------------------------------------------------------

## De muziek waar alles op terugvalt: het kantoor, of het titelscherm.
func set_base(track: StringName, fade: float = 1.2) -> void:
	set_layer(&"basis", track, fade)


func set_layer(laag: StringName, track: StringName, fade: float = 0.8) -> void:
	if not laag in LAGEN:
		push_error("AudioDirector: onbekende muzieklaag '%s'" % laag)
		return
	if _lagen.get(laag, &"") == track:
		return
	# Meteen controleren, niet pas wanneer deze laag bovenaan komt te liggen.
	# Een typefout in set_ambience zou anders pas opvallen als het gesprek
	# afgelopen is, of helemaal niet meer als de dag daarvoor eindigt.
	if track != &"" and not has_music(track):
		push_error("AudioDirector: laag '%s' vraagt muziekstuk '%s' dat niet bestaat" % [laag, track])
		return
	_lagen[laag] = track
	_kies(fade)


func clear_layer(laag: StringName, fade: float = 0.8) -> void:
	if _lagen.get(laag, &"") == &"":
		return
	_lagen[laag] = &""
	_kies(fade)


func stop_music(fade: float = 0.8) -> void:
	_lagen.clear()
	_kies(fade)


func has_music(track: StringName) -> bool:
	return track != &"" and _load_audio("%s/%s" % [MUSIC_DIR, track]) != null


## Welke laag hoor je nu? Alleen voor QA en debug.
func current_music() -> StringName:
	return _huidig


func _kies(fade: float) -> void:
	var doel: StringName = &""
	for laag: StringName in LAGEN:
		var t: StringName = _lagen.get(laag, &"")
		if t != &"":
			doel = t
	_wissel(doel, fade)


func _wissel(track: StringName, fade: float) -> void:
	if track == _huidig:
		return

	# Onthoud waar we dit stuk verlaten, vóórdat de speler stopt: anders geeft
	# get_playback_position() straks nul terug en begint alles weer bij maat een.
	if _huidig != &"" and _actief.playing:
		_posities[_huidig] = _actief.get_playback_position()

	if _tw_in != null and _tw_in.is_valid():
		_tw_in.kill()
	if _tw_out != null and _tw_out.is_valid():
		_tw_out.kill()

	var uit := _actief
	_actief = _vorige
	_vorige = uit
	_huidig = track

	if uit.playing:
		_tw_out = create_tween()
		_tw_out.tween_property(uit, "volume_db", -60.0, fade)
		_tw_out.tween_callback(uit.stop)

	if track == &"":
		return

	# set_layer heeft het bestaan al afgedwongen, dus hier geen tweede melding.
	var stream := _load_audio("%s/%s" % [MUSIC_DIR, track])
	if stream == null:
		_huidig = &""
		return

	_zet_loop(stream, track)
	_actief.stream = stream
	_actief.volume_db = -60.0
	_actief.play(_startpositie(track))
	_tw_in = create_tween()
	_tw_in.tween_property(_actief, "volume_db", _muziek_db(), fade)


## Stukken met een eigen kop beginnen altijd bij die kop; de rest gaat verder
## waar hij gebleven was.
func _startpositie(track: StringName) -> float:
	if LOOP_START.has(track):
		return 0.0
	return float(_posities.get(track, 0.0))


func _zet_loop(stream: AudioStream, track: StringName) -> void:
	var start := float(LOOP_START.get(track, 0.0))
	if stream is AudioStreamOggVorbis:
		var o := stream as AudioStreamOggVorbis
		o.loop = true
		o.loop_offset = start
	elif stream is AudioStreamWAV:
		var w := stream as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = int(start * float(w.mix_rate))


func _muziek_db() -> float:
	return linear_to_db(maxf(0.001, music_volume * master_volume))


# --- Muziekstand volgt spelstand -----------------------------------------

func _op_gesprek_start(_dialogue_id: StringName, _speaker_id: StringName) -> void:
	set_layer(&"gesprek", &"gesprek", 0.6)


func _op_gesprek_eind(_dialogue_id: StringName, _outcome: StringName) -> void:
	clear_layer(&"gesprek", 0.8)


func _op_minigame_start(minigame_id: StringName) -> void:
	# Elke minigame heeft zijn eigen spanningsvariant, met dezelfde naam als de
	# minigame. Ontbreekt die, dan blijft het kantoor staan: een minigame zonder
	# eigen muziek is een gemis, een minigame in stilte is een bug.
	if has_music(minigame_id):
		set_layer(&"minigame", minigame_id, 0.5)
	play_ui(&"mg_intro")


func _op_minigame_eind(_minigame_id: StringName, _result: MinigameResult) -> void:
	clear_layer(&"minigame", 0.9)


func _op_gewonnen() -> void:
	set_layer(&"overwinning", &"overwinning", 1.0)


## Een nieuwe dag begint bovenaan. Vanuit het eindscherm kun je terug naar de
## titel en opnieuw beginnen; zonder dit hervat het kantoorthema die tweede keer
## midden in een frase en mist die ochtend zijn begin.
func _op_nieuw_spel() -> void:
	_posities.clear()


# --- Laden ----------------------------------------------------------------

func _load_audio(base_path: String) -> AudioStream:
	if _cache.has(base_path):
		return _cache[base_path] as AudioStream
	for ext: String in [".ogg", ".wav"]:
		var p := base_path + ext
		if ResourceLoader.exists(p):
			var s: AudioStream = load(p)
			_cache[base_path] = s
			return s
	_cache[base_path] = null
	return null
