extends Node
## SFX-pool, muziek-crossfade en ambience. Scene-onafhankelijk, dus autoload.
## Muziek draait door tijdens pause; wereld-SFX niet.

const SFX_DIR := "res://assets/audio/sfx"
const MUSIC_DIR := "res://assets/audio/music"
const VOICES := 12

var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_on_a: bool = true
var _sfx: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _cache: Dictionary = {}
var _current_music: StringName = &""

var master_volume: float = 1.0
var music_volume: float = 0.6
var sfx_volume: float = 0.9


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_music_a = _make_player(true)
	_music_b = _make_player(true)
	for i: int in VOICES:
		_sfx.append(_make_player(false))

	Bus.audio_cue_requested.connect(play_sfx)


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


# --- Muziek ---------------------------------------------------------------

func play_music(track: StringName, fade: float = 1.2) -> void:
	if track == _current_music:
		return
	_current_music = track

	var stream := _load_audio("%s/%s" % [MUSIC_DIR, track])
	var incoming := _music_b if _music_on_a else _music_a
	var outgoing := _music_a if _music_on_a else _music_b
	_music_on_a = not _music_on_a

	if stream != null:
		if stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
		elif stream is AudioStreamWAV:
			(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		incoming.stream = stream
		incoming.volume_db = -60.0
		incoming.play()
		var tw_in := create_tween()
		tw_in.tween_property(incoming, "volume_db", linear_to_db(maxf(0.001, music_volume * master_volume)), fade)

	if outgoing.playing:
		var tw_out := create_tween()
		tw_out.tween_property(outgoing, "volume_db", -60.0, fade)
		tw_out.tween_callback(outgoing.stop)


func stop_music(fade: float = 0.8) -> void:
	_current_music = &""
	for p: AudioStreamPlayer in [_music_a, _music_b]:
		if p.playing:
			var tw := create_tween()
			tw.tween_property(p, "volume_db", -60.0, fade)
			tw.tween_callback(p.stop)


## Duckt de muziek tijdens dialoog.
func duck(amount_db: float = -8.0, time: float = 0.25) -> void:
	var p := _music_a if _music_on_a == false else _music_b
	if p.playing:
		create_tween().tween_property(p, "volume_db",
			linear_to_db(maxf(0.001, music_volume * master_volume)) + amount_db, time)


func unduck(time: float = 0.4) -> void:
	var p := _music_a if _music_on_a == false else _music_b
	if p.playing:
		create_tween().tween_property(p, "volume_db",
			linear_to_db(maxf(0.001, music_volume * master_volume)), time)


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
