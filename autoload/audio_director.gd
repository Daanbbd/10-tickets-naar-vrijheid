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

	_maak_muziekbus()
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
	if always and _muziekbus >= 0:
		p.bus = MUZIEKBUS
	add_child(p)
	return p


# --- De ruimte waar je in staat ---------------------------------------------
#
# Elke ruimte klonk hetzelfde, en dat is wat een verdieping van acht ruimtes
# vlak maakt: je loopt van de toiletten naar de koffiecorner en er verandert
# niets aan wat je hoort. Er is één kantoorstuk (`kantoor.ogg`) en er komen er
# vanavond geen bij, dus dit doet het met wat er is: een laagdoorlaatfilter en
# een volumeverschil per zone. Dat is precies wat je hoort als je een deur door
# loopt — de hoge tonen blijven achter, de rest wordt zachter.
#
# Alleen de muziekspelers gaan door dit filter. SFX (voetstappen, klikken,
# deuren) blijven op Master: die maak jíj, in de ruimte waar je staat, en die
# horen dus niet gedempt te worden.

const MUZIEKBUS := &"Muziek"

## Cutoff in Hz en volumeverschil in dB per zone-id. 20000 Hz is "geen filter";
## het filter zit altijd in de keten, dus er is geen tak die soms wel en soms
## niet gefilterd is.
##
## De getallen zijn conservatief gekozen: het verschil moet hoorbaar zijn als je
## een deur door loopt, niet opvallen als je stilstaat. Wil je eraan draaien,
## dan is dit de enige plek. `De Werkvloer` en `De Gang` zijn de referentie en
## staan bewust op onbewerkt.
const RUIMTES: Dictionary = {
	&"z1_entree":       {"hz": 8000.0, "db": -1.0},
	&"z2_toilet":       {"hz": 1400.0, "db": -7.0},   # deur dicht, tegels
	&"z3_patchhok":     {"hz": 3200.0, "db": -3.0},   # klein, vol apparatuur
	&"z4_koffiecorner": {"hz": 20000.0, "db": 1.0},   # de luidste ruimte
	&"z5_summit":       {"hz": 4500.0, "db": -3.0},   # glas, vergaderstilte
	&"z6_basecamp":     {"hz": 4500.0, "db": -3.0},
	&"z7_birdhouse":    {"hz": 5000.0, "db": -2.0},   # de grootste zaal
	&"z8_hokje":        {"hz": 2400.0, "db": -5.0},   # een belhokje
	&"z9_vloer":        {"hz": 20000.0, "db": 0.0},   # referentie
	&"z10_weekend":     {"hz": 6000.0, "db": -2.0},   # het bureau hiernaast
	&"z11_gang":        {"hz": 20000.0, "db": 0.0},   # referentie
}

const RUIMTE_FADE := 0.45

var _muziekbus: int = -1
var _filter: AudioEffectLowPassFilter = null
var _ruimte_tween: Tween = null


## Een eigen bus met één filter erop, in code en niet als `.tres`: er is in dit
## project geen buslayout-bestand, en er één introduceren voor één effect maakt
## een asset die je in de editor moet openen om te snappen.
func _maak_muziekbus() -> void:
	_muziekbus = AudioServer.bus_count
	AudioServer.add_bus(_muziekbus)
	AudioServer.set_bus_name(_muziekbus, MUZIEKBUS)
	AudioServer.set_bus_send(_muziekbus, &"Master")
	_filter = AudioEffectLowPassFilter.new()
	_filter.cutoff_hz = 20000.0
	AudioServer.add_bus_effect(_muziekbus, _filter)


## De ruimte waar de speler nu staat. Onbekende zone valt terug op onbewerkt,
## zodat een nieuwe zone in `floor.json` stil niets kapotmaakt.
func set_ruimte(zone_id: StringName, fade: float = RUIMTE_FADE) -> void:
	if _filter == null or _muziekbus < 0:
		return
	var r: Dictionary = RUIMTES.get(zone_id, {"hz": 20000.0, "db": 0.0})
	var hz := float(r["hz"])
	var db := float(r["db"])
	if _ruimte_tween != null and _ruimte_tween.is_running():
		_ruimte_tween.kill()
	# Meteen zetten in plaats van tweenen. Twee aanroepers willen dit: de eerste
	# zone bij het spawnen (een sweep over de infade hoor je als een storing,
	# niet als een ruimte) en de testsuite, die geen frames heeft om op te
	# wachten.
	if fade <= 0.0:
		_filter.cutoff_hz = hz
		AudioServer.set_bus_volume_db(_muziekbus, db)
		return
	# Op de SceneTree en niet op deze node: een autoload leeft langer dan elke
	# scene, maar `create_tween()` op een node die pauzeert loopt niet door
	# tijdens een pauzemenu — en dan blijft de vorige ruimte hangen.
	_ruimte_tween = get_tree().create_tween().set_parallel(true)
	_ruimte_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_ruimte_tween.tween_property(_filter, "cutoff_hz", hz, fade)
	_ruimte_tween.tween_method(
		func(v: float) -> void: AudioServer.set_bus_volume_db(_muziekbus, v),
		AudioServer.get_bus_volume_db(_muziekbus), db, fade)


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


## SFX die hoorbaar moet blijven ongeacht `get_tree().paused` — een klik in het
## pauzemenu dat de tree zelf net pauzeerde, bijvoorbeeld. Sinds F5-a pauzeert
## een gewone minigame de tree niet meer, dus `storing()` en
## `finish_with_banner()` hebben dit vandaag niet meer nodig om gehoord te
## worden — maar backgrounden pauzeert nog altijd wél, ook tijdens een
## minigame, en blijft dan ook een geldige reden. Ongewijzigd gelaten: geen
## downside om elke `play_ui()`-oproep hetzelfde te behandelen.
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


## Het hoofdvolume, en meteen hoorbaar.
##
## `master_volume` rechtstreeks zetten werkt wel voor SFX — die lezen het bij
## elke cue — maar niet voor de muziek: die hangt aan een `volume_db` die één
## keer door een fade is neergezet en daarna niets meer leest. Een schuif die
## pas bij het volgende muziekstuk iets doet leest als een kapotte schuif.
func set_master_volume(v: float) -> void:
	master_volume = clampf(v, 0.0, 1.0)
	if _tw_in != null and _tw_in.is_valid():
		_tw_in.kill()
	if _actief != null and _actief.playing:
		_actief.volume_db = _muziek_db()


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
