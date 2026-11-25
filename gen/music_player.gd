class_name MusicPlayer
extends Node
## Autoload `Music` (DESIGN §7, §9 M12). Builds the five looping tracks (calm, stealth, combat, boss, dahan)
## from Synth and crossfades between them on two AudioStreamPlayers. Each track is a drone with a fifth,
## a melody in the Raga Bhairav-like scale (S r G m P d N) and tabla-like percussion. Tracks are 8-16 s
## loops, built lazily on first play and cached. Uses bus "Music" when it exists, otherwise "Master".

const SAMPLE_RATE: int = 44100
const FADE_SILENT_DB: float = -80.0
const TRACK_PEAK: float = 0.9
const REST: int = -999
const DEGREE_COUNT: int = 7

var _players: Array[AudioStreamPlayer] = []
var _active: int = 0
var _current: StringName = &""
var _streams: Dictionary = {}
var _tween: Tween = null


## Parameters of one looping track. Melody values are scale steps: degree = posmod(v, 7), octave = floor(v / 7).
class TrackSpec extends RefCounted:
	var root: float = 130.81
	var seconds: float = 12.0
	var bpm: float = 80.0
	var steps_per_beat: int = 2
	var melody: Array[int] = []
	var wave: int = 0
	var melody_gain: float = 0.2
	var drone_gain: float = 0.08
	var perc_interval: int = 0


func _ready() -> void:
	_ensure_players()


## The Bhairav-like ratios S r G m P d N relative to the tonic.
static func scale_degrees() -> Array[float]:
	var degrees: Array[float] = [
		1.0,
		16.0 / 15.0,
		5.0 / 4.0,
		4.0 / 3.0,
		3.0 / 2.0,
		8.0 / 5.0,
		15.0 / 8.0,
	]
	return degrees


## Builds the stereo loop for a track. Returns an empty buffer for an unknown track id.
static func build_samples(track: StringName) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var spec: TrackSpec = _spec_for(track)
	if spec == null:
		return out
	out.resize(roundi(spec.seconds * SAMPLE_RATE))
	_add_drone(out, spec)
	_add_melody(out, spec)
	_add_percussion(out, spec)
	_normalise(out, TRACK_PEAK)
	return out


## Reference buffer-level mix of two tracks: linear weights (1 - t, t) that sum to 1, so full-scale inputs
## cannot exceed full scale. Used by the tests to check the mix; the runtime fade in play() runs on the
## two AudioStreamPlayers' volumes instead. Shorter buffers are treated as silent past their end.
## The result is clamped to [-1, 1] as a final safety net.
static func crossfade(from_buf: PackedVector2Array, to_buf: PackedVector2Array, t: float) -> PackedVector2Array:
	var clamped_t: float = clampf(t, 0.0, 1.0)
	var length: int = maxi(from_buf.size(), to_buf.size())
	var out: PackedVector2Array = PackedVector2Array()
	out.resize(length)
	for i: int in range(length):
		var a: Vector2 = from_buf[i] if i < from_buf.size() else Vector2.ZERO
		var b: Vector2 = to_buf[i] if i < to_buf.size() else Vector2.ZERO
		var mixed: Vector2 = a * (1.0 - clamped_t) + b * clamped_t
		out[i] = Vector2(clampf(mixed.x, -1.0, 1.0), clampf(mixed.y, -1.0, 1.0))
	return out


## Starts a track, crossfading from the current one over `fade` seconds.
func play(track: StringName, fade: float = 1.0) -> void:
	if track == _current and is_playing():
		return
	var stream: AudioStreamWAV = _stream_for(track)
	if stream == null:
		push_warning("Music: unknown track '%s'" % String(track))
		return
	_ensure_players()
	var incoming: AudioStreamPlayer = _players[1 - _active]
	var outgoing: AudioStreamPlayer = _players[_active]
	incoming.stream = stream
	incoming.volume_db = FADE_SILENT_DB
	incoming.play()
	_active = 1 - _active
	_current = track
	_crossfade_players(incoming, outgoing, fade)


## Fades the current track out over `fade` seconds and stops it.
func stop(fade: float = 1.0) -> void:
	_current = &""
	if _players.is_empty():
		return
	_kill_tween()
	var playing: AudioStreamPlayer = _players[_active]
	for player: AudioStreamPlayer in _players:
		if player != playing:
			player.stop()
			player.volume_db = FADE_SILENT_DB
	if fade <= 0.0:
		playing.stop()
		playing.volume_db = FADE_SILENT_DB
		return
	_tween = create_tween()
	_tween.tween_method(_set_amplitude.bind(playing), 1.0, 0.0, fade)
	_tween.tween_callback(playing.stop)


func current_track() -> StringName:
	return _current


## True only while a track is set and the active player is actually producing audio.
func is_playing() -> bool:
	if _current == &"" or _players.size() != 2:
		return false
	return _players[_active].playing


static func _spec_for(track: StringName) -> TrackSpec:
	var spec: TrackSpec = TrackSpec.new()
	var melody: Array[int] = []
	match track:
		&"calm":
			spec.root = 130.81
			spec.seconds = 16.0
			spec.bpm = 72.0
			melody = [0, 2, 4, 2, 5, 4, 2, 1, 0, 2, 4, 6, 5, 4, 2, 0]
			spec.wave = 0
			spec.melody_gain = 0.22
			spec.perc_interval = 0
		&"stealth":
			spec.root = 146.83
			spec.seconds = 12.0
			spec.bpm = 84.0
			melody = [0, REST, 3, 2, REST, 1, 0, REST]
			spec.wave = 3
			spec.melody_gain = 0.2
			spec.perc_interval = 2
		&"combat":
			spec.root = 130.81
			spec.seconds = 8.0
			spec.bpm = 132.0
			melody = [0, 2, 4, 7, 4, 2, 0, -2, 0, 2, 4, 5, 4, 2, 1, 0]
			spec.wave = 2
			spec.melody_gain = 0.16
			spec.perc_interval = 1
		&"boss":
			spec.root = 110.0
			spec.seconds = 12.0
			spec.bpm = 100.0
			melody = [-7, -5, -3, -7, -4, -2, 0, -2]
			spec.wave = 2
			spec.melody_gain = 0.18
			spec.perc_interval = 2
		&"dahan":
			spec.root = 164.81
			spec.seconds = 16.0
			spec.bpm = 60.0
			melody = [0, 4, 2, 6, 7, 6, 4, 2, 1, 3, 4, 2, 0, -1, 0, REST]
			spec.wave = 3
			spec.melody_gain = 0.2
			spec.perc_interval = 2
		_:
			return null
	spec.melody = melody
	return spec


static func _add_drone(out: PackedVector2Array, spec: TrackSpec) -> void:
	# Round the drone frequencies to whole cycles per loop so the loop point does not click.
	var root: float = roundf(spec.root * spec.seconds) / spec.seconds
	var fifth: float = roundf(spec.root * 1.5 * spec.seconds) / spec.seconds
	var env_root: Dictionary = {"attack": 0.5, "release": 0.5, "gain": spec.drone_gain}
	var env_fifth: Dictionary = {"attack": 0.5, "release": 0.5, "gain": spec.drone_gain * 0.6}
	_place(out, Synth.tone(root, spec.seconds, 2, env_root), 0)
	_place(out, Synth.tone(fifth, spec.seconds, 0, env_fifth), 0)


static func _add_melody(out: PackedVector2Array, spec: TrackSpec) -> void:
	if spec.melody.is_empty():
		return
	var step_sec: float = 60.0 / spec.bpm / float(spec.steps_per_beat)
	var steps: int = floori(spec.seconds / step_sec)
	var note_len: float = step_sec * 1.5
	var env: Dictionary = {
		"attack": 0.02,
		"decay": 0.15,
		"sustain": 0.6,
		"release": 0.08,
		"gain": spec.melody_gain,
	}
	for step: int in range(steps):
		var value: int = spec.melody[step % spec.melody.size()]
		if value == REST:
			continue
		var freq: float = _note_frequency(spec.root, value)
		var start: int = roundi(float(step) * step_sec * SAMPLE_RATE)
		_place(out, Synth.tone(freq, note_len, spec.wave, env), start)


static func _add_percussion(out: PackedVector2Array, spec: TrackSpec) -> void:
	if spec.perc_interval <= 0:
		return
	var step_sec: float = 60.0 / spec.bpm / float(spec.steps_per_beat)
	var steps: int = floori(spec.seconds / step_sec)
	var hit: PackedVector2Array = Synth.mix([_tabla_noise(), _tabla_pitch_drop()])
	for step: int in range(0, steps, spec.perc_interval):
		var start: int = roundi(float(step) * step_sec * SAMPLE_RATE)
		_place(out, hit, start)


static func _note_frequency(root: float, value: int) -> float:
	var degree: int = posmod(value, DEGREE_COUNT)
	var octave: int = floori(float(value) / float(DEGREE_COUNT))
	var ratios: Array[float] = scale_degrees()
	return root * ratios[degree] * pow(2.0, float(octave))


## Adds `src` into `dest` starting at frame `start`, clamping each channel to [-1, 1]. Samples past the end are dropped.
static func _place(dest: PackedVector2Array, src: PackedVector2Array, start: int) -> void:
	if start < 0 or start >= dest.size():
		return
	var count: int = mini(src.size(), dest.size() - start)
	for i: int in range(count):
		var d: Vector2 = dest[start + i]
		var s: Vector2 = src[i]
		dest[start + i] = Vector2(clampf(d.x + s.x, -1.0, 1.0), clampf(d.y + s.y, -1.0, 1.0))


static func _normalise(buf: PackedVector2Array, peak: float) -> void:
	var max_abs: float = 0.0
	for i: int in range(buf.size()):
		var s: Vector2 = buf[i]
		max_abs = maxf(max_abs, maxf(absf(s.x), absf(s.y)))
	if max_abs <= 0.0:
		return
	var gain: float = peak / max_abs
	for i: int in range(buf.size()):
		var s: Vector2 = buf[i]
		buf[i] = Vector2(clampf(s.x * gain, -1.0, 1.0), clampf(s.y * gain, -1.0, 1.0))


## Tabla-like hit: a short sine pitch drop through 220, 180 and 150 Hz (DESIGN §7).
static func _tabla_pitch_drop() -> PackedVector2Array:
	var env: Dictionary = {"attack": 0.002, "decay": 0.02, "sustain": 0.0, "release": 0.01, "gain": 0.35}
	var seg_sec: float = 0.03
	var out: PackedVector2Array = PackedVector2Array()
	out.resize(roundi(seg_sec * 3.0 * SAMPLE_RATE))
	var freqs: Array[float] = [220.0, 180.0, 150.0]
	for i: int in range(freqs.size()):
		var seg: PackedVector2Array = Synth.tone(freqs[i], seg_sec, 0, env)
		_place(out, seg, roundi(float(i) * seg_sec * SAMPLE_RATE))
	return out


## Short noise burst for the tabla attack.
static func _tabla_noise() -> PackedVector2Array:
	return Synth.noise(
		0.12, {"attack": 0.001, "decay": 0.1, "sustain": 0.0, "release": 0.01, "gain": 0.3, "seed": 77}, 1500.0)


## Wraps a track buffer as a stream that loops over its whole length (8-16 s loops, DESIGN §7).
static func make_loop_stream(buf: PackedVector2Array) -> AudioStreamWAV:
	var stream: AudioStreamWAV = Synth.to_stream(buf)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = buf.size()
	return stream


func _stream_for(track: StringName) -> AudioStreamWAV:
	if _streams.has(track):
		return _streams[track] as AudioStreamWAV
	var buf: PackedVector2Array = build_samples(track)
	if buf.is_empty():
		return null
	var stream: AudioStreamWAV = make_loop_stream(buf)
	_streams[track] = stream
	return stream


## Sets a player's level from a linear amplitude (0..1). Linear amplitude in the tween keeps the fade even.
func _set_amplitude(amp: float, player: AudioStreamPlayer) -> void:
	player.volume_db = linear_to_db(maxf(amp, 0.0001))


func _ensure_players() -> void:
	if _players.size() == 2:
		return
	for i: int in range(2):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = _bus_name()
		player.volume_db = FADE_SILENT_DB
		add_child(player)
		_players.append(player)


func _bus_name() -> StringName:
	if AudioServer.get_bus_index(&"Music") >= 0:
		return &"Music"
	return &"Master"


func _crossfade_players(incoming: AudioStreamPlayer, outgoing: AudioStreamPlayer, fade: float) -> void:
	_kill_tween()
	if fade <= 0.0:
		incoming.volume_db = 0.0
		outgoing.stop()
		outgoing.volume_db = FADE_SILENT_DB
		return
	_tween = create_tween().set_parallel(true)
	_tween.tween_method(_set_amplitude.bind(incoming), 0.0, 1.0, fade)
	_tween.tween_method(_set_amplitude.bind(outgoing), 1.0, 0.0, fade)
	_tween.chain().tween_callback(outgoing.stop)


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
