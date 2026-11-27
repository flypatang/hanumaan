class_name VoicePlayer
extends Node
## Autoload `Voice` (VO1). Plays the AI text-to-speech voice-over (assets/vo, rendered by tools/vo/generate_vo.py)
## on the "Voice" bus. play_line(text_key) picks the folder of the current language (en or hi) and plays nothing when
## the clip is missing or the player turned voice-over off in Settings. play_shloka(id) plays the Sanskrit recitation.
## Music is already ducked under dialogue by SoundPlayer (dialogue_started / dialogue_finished), so no second duck.

signal started(clip_id: StringName)
signal stopped

const BUS_VOICE: StringName = &"Voice"
const BUS_MASTER: StringName = &"Master"
const VO_DIR: String = "res://assets/vo/"
const SANSKRIT_DIR: String = "sa"
const OPTION_ENABLED: StringName = &"voice_over"

## Test hook: -1 follows the Settings option, 0 forces voice-over off, 1 forces it on.
var enabled_override: int = -1

var _player: AudioStreamPlayer = null
var _clip_id: StringName = &""
var _streams: Dictionary = {}


func _ready() -> void:
	ensure_bus()
	_make_player()


## Creates the Voice bus (sent to Master) when missing. Safe to call repeatedly.
static func ensure_bus() -> void:
	if AudioServer.get_bus_index(BUS_VOICE) >= 0:
		return
	AudioServer.add_bus()
	var index: int = AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(index, BUS_VOICE)
	AudioServer.set_bus_send(index, BUS_MASTER)


## True when voice-over is switched on in Settings (or forced by enabled_override).
func is_enabled() -> bool:
	if enabled_override >= 0:
		return enabled_override == 1
	return Menus.saved_option(OPTION_ENABLED) as bool


## "hi" when the game language is Hindi, otherwise "en".
static func language_folder() -> String:
	return "hi" if TranslationServer.get_locale().begins_with("hi") else "en"


## Resource path of the clip for a text key in the current language.
static func line_path(text_key: String) -> String:
	return "%s%s/%s.ogg" % [VO_DIR, language_folder(), text_key]


## Resource path of the Sanskrit recitation of a shloka.
static func shloka_path(shloka_id: String) -> String:
	return "%s%s/%s.ogg" % [VO_DIR, SANSKRIT_DIR, shloka_id]


## Plays the voice-over of a dialogue line. Returns false (and stays silent) when off or no clip exists.
func play_line(text_key: String) -> bool:
	return _play_path(line_path(text_key), StringName(text_key))


## Plays the Sanskrit recitation of a shloka. Returns false when off or no clip exists.
func play_shloka(shloka_id: String) -> bool:
	return _play_path(shloka_path(shloka_id), StringName(shloka_id))


func stop() -> void:
	var was: bool = is_playing()
	if _player != null:
		_player.stop()
	_clip_id = &""
	if was:
		stopped.emit()


func is_playing() -> bool:
	return _player != null and _player.playing


## Id (text key or shloka id) of the clip that is playing or was last started, empty after stop().
func current_clip() -> StringName:
	return _clip_id


## Resource path of the clip that is playing or was last started (empty when none).
func current_path() -> String:
	if _player == null or _player.stream == null or _clip_id.is_empty():
		return ""
	return _player.stream.resource_path


## Length in seconds of the clip that is playing (0 when none).
func current_length() -> float:
	if _player == null or _player.stream == null or _clip_id.is_empty():
		return 0.0
	return _player.stream.get_length()


## Length in seconds of the clip for a text key in the current language, 0 when there is none.
func line_length(text_key: String) -> float:
	var stream: AudioStream = _stream(line_path(text_key))
	return stream.get_length() if stream != null else 0.0


func _play_path(path: String, id: StringName) -> bool:
	stop()
	if not is_enabled():
		return false
	var stream: AudioStream = _stream(path)
	if stream == null:
		return false
	_make_player()
	_player.stream = stream
	_clip_id = id
	if is_inside_tree():
		_player.play()
	started.emit(id)
	return true


func _stream(path: String) -> AudioStream:
	if _streams.has(path):
		return _streams[path] as AudioStream
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path) as AudioStream
	_streams[path] = stream
	return stream


func _make_player() -> void:
	if _player != null:
		return
	_player = AudioStreamPlayer.new()
	_player.bus = BUS_VOICE if AudioServer.get_bus_index(BUS_VOICE) >= 0 else BUS_MASTER
	_player.finished.connect(_on_finished)
	add_child(_player)


func _on_finished() -> void:
	_clip_id = &""
	stopped.emit()
