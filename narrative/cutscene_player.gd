class_name CutscenePlayer
extends Node
## Plays a cutscene step list from data/cutscenes/<id>.json (DESIGN §9 M31, format in data/cutscenes/SCHEMA.md).
## play() loads the steps and binds the actor registry and camera. The caller drives time through tick(delta) (the
## node also ticks itself in _process). Dialogue and shloka steps pause the sequence until continue_after_ui() is
## called. Timed steps run on delta, never on frame count, so the result does not depend on frame rate (DESIGN §8).

signal started(id: StringName)
signal finished(id: StringName)
signal step_started(index: int, type: StringName)
signal dialogue_requested(id: StringName, node: StringName)
signal shloka_requested(id: StringName)
signal fade_requested(color: Color, duration: float, fade_out: bool)
signal flag_set(key: StringName, value: Variant)

const DEFAULT_CUTSCENES_DIR: String = "res://data/cutscenes/"
const EPS: float = 0.0001
const STEP_TYPES: Array[StringName] = [
	&"camera_move", &"actor_move", &"actor_pose", &"dialogue", &"shloka", &"wait", &"fade", &"set_flag",
]
## Colour tokens accepted by the fade step (names from Palette, DESIGN §6.1).
const COLOR_TOKENS: Dictionary = {
	&"SAFFRON": Palette.SAFFRON,
	&"SINDOOR": Palette.SINDOOR,
	&"GOLD": Palette.GOLD,
	&"HANUMAN_FUR": Palette.HANUMAN_FUR,
	&"DEEP_OCEAN": Palette.DEEP_OCEAN,
	&"NIGHT_INDIGO": Palette.NIGHT_INDIGO,
	&"MOON": Palette.MOON,
	&"GROVE_GREEN": Palette.GROVE_GREEN,
	&"ASHOKA_RED": Palette.ASHOKA_RED,
	&"STONE": Palette.STONE,
	&"FIRE_CORE": Palette.FIRE_CORE,
	&"FIRE_EDGE": Palette.FIRE_EDGE,
	&"UI_DARK": Palette.UI_DARK,
	&"BARK": Palette.BARK,
	&"LEAF_DARK": Palette.LEAF_DARK,
	&"SKY_DUSK": Palette.SKY_DUSK,
}

## Folder the cutscene files are read from. Tests point it at user:// to use fixtures.
var cutscenes_dir: String = DEFAULT_CUTSCENES_DIR

var _id: StringName = &""
var _steps: Array[Dictionary] = []
var _index: int = 0
var _playing: bool = false
var _awaiting_ui: bool = false
# True while tick() runs. _generation changes on play() and stop(), so a running loop can detect a restart.
var _ticking: bool = false
var _generation: int = 0
var _actors: Dictionary = {}
var _camera: Camera3D = null

# State of the step currently running.
var _step_active: bool = false
var _step_elapsed: float = 0.0
var _step_duration: float = 0.0
# Only the kind of the running step decides what it moves. Camera and actor keep separate from/to state, and
# each is cleared when its step ends, so a stale move never touches the camera or an actor again.
var _moving_camera: bool = false
var _camera_from: Vector3 = Vector3.ZERO
var _camera_to: Vector3 = Vector3.ZERO
var _look_at: Vector3 = Vector3.ZERO
var _has_look_at: bool = false
var _moving_actor: bool = false
var _actor: Node3D = null
var _actor_from: Vector3 = Vector3.ZERO
var _actor_to: Vector3 = Vector3.ZERO


func _process(delta: float) -> void:
	tick(delta)


## Loads data/cutscenes/<id>.json. Returns OK, ERR_FILE_NOT_FOUND, or ERR_PARSE_ERROR when a step is malformed.
func load_cutscene(id: StringName) -> Error:
	var path: String = "%s%s.json" % [cutscenes_dir, str(id)]
	if not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ERR_FILE_CANT_OPEN
	var json: JSON = JSON.new()
	var parse_err: Error = json.parse(file.get_as_text())
	file.close()
	if parse_err != OK:
		push_warning("CutscenePlayer: %s is not valid JSON (line %d): %s" % [path, json.get_error_line(), json.get_error_message()])
		return ERR_PARSE_ERROR
	var parsed: Variant = json.data
	var raw_steps: Variant = parsed
	if parsed is Dictionary:
		raw_steps = (parsed as Dictionary).get("steps", null)
	if not (raw_steps is Array):
		return ERR_PARSE_ERROR
	var steps: Array[Dictionary] = []
	var raw_array: Array = raw_steps as Array
	for raw: Variant in raw_array:
		if not (raw is Dictionary) or not _is_valid_step(raw as Dictionary):
			return ERR_PARSE_ERROR
		steps.append(raw as Dictionary)
	_id = id
	_steps = steps
	return OK


## Loads and starts a cutscene. actors maps step actor names to Node3D nodes. camera is moved by camera_move steps.
func play(id: StringName, actors: Dictionary, camera: Camera3D) -> Error:
	var err: Error = load_cutscene(id)
	if err != OK:
		return err
	_generation += 1
	_actors = actors
	_camera = camera
	_index = 0
	_playing = true
	_awaiting_ui = false
	_step_active = false
	_clear_move_state()
	started.emit(_id)
	tick(0.0)
	return OK


## Advances the sequence by delta seconds. Does nothing while stopped or waiting for continue_after_ui().
func tick(delta: float) -> void:
	# A tick that arrives while another is running (for example from a listener that calls play() or tick() inside
	# a signal) is ignored. The running loop picks up the new state itself.
	if not _playing or _ticking:
		return
	_ticking = true
	_advance(maxf(delta, 0.0))
	_ticking = false


## Resumes after a dialogue or shloka step. Ignored when nothing is waiting. When called from inside the signal that
## requested the pause, the running tick loop continues on its own; otherwise this ticks the rest of the sequence.
func continue_after_ui() -> void:
	if not _awaiting_ui:
		return
	_awaiting_ui = false
	_complete_step()
	if not _ticking:
		tick(0.0)


## Cancels the cutscene without emitting finished.
func stop() -> void:
	_generation += 1
	_playing = false
	_awaiting_ui = false
	_step_active = false
	_clear_move_state()


func is_playing() -> bool:
	return _playing


func is_awaiting_ui() -> bool:
	return _awaiting_ui


func current_index() -> int:
	return _index


func _advance(budget_in: float) -> void:
	var budget: float = budget_in
	while _playing and not _awaiting_ui:
		if not _step_active:
			if _index >= _steps.size():
				_finish()
				return
			var generation: int = _generation
			_begin_step(_steps[_index])
			# A listener may have stopped or restarted the cutscene while the step was being begun.
			if generation != _generation:
				return
			continue
		var remaining: float = _step_duration - _step_elapsed
		if budget < remaining:
			_step_elapsed += budget
			_apply_progress(_step_elapsed / _step_duration)
			return
		budget -= remaining
		_step_elapsed = _step_duration
		_apply_progress(1.0)
		_complete_step()


func _finish() -> void:
	_playing = false
	_step_active = false
	_clear_move_state()
	finished.emit(_id)


func _clear_move_state() -> void:
	_moving_camera = false
	_moving_actor = false
	_has_look_at = false
	_actor = null


func _begin_step(step: Dictionary) -> void:
	_step_active = true
	_step_elapsed = 0.0
	_step_duration = maxf(_as_float(step.get("duration", 0.0)), 0.0)
	_clear_move_state()
	var type: StringName = StringName(str(step.get("type", "")))
	step_started.emit(_index, type)
	match type:
		&"camera_move":
			_begin_camera_move(step)
		&"actor_move":
			_begin_actor_move(step)
		&"actor_pose":
			_apply_pose(step)
			_step_duration = 0.0
		&"set_flag":
			flag_set.emit(StringName(str(step.get("k", ""))), step.get("v", null))
			_step_duration = 0.0
		&"dialogue":
			# Set the pause before emitting, so a listener can answer synchronously with continue_after_ui().
			_step_duration = 0.0
			_awaiting_ui = true
			dialogue_requested.emit(StringName(str(step.get("id", ""))), StringName(str(step.get("node", ""))))
		&"shloka":
			_step_duration = 0.0
			_awaiting_ui = true
			shloka_requested.emit(StringName(str(step.get("id", ""))))
		&"fade":
			var color: Color = _color_for(StringName(str(step.get("color", "UI_DARK"))))
			fade_requested.emit(color, _step_duration, _as_bool(step.get("out", true)))
		_:
			pass


func _complete_step() -> void:
	_step_active = false
	if _moving_actor and _actor != null and is_instance_valid(_actor) and _actor.has_method(&"set_pose"):
		_actor.call(&"set_pose", &"idle")
	_clear_move_state()
	_index += 1


func _apply_progress(t: float) -> void:
	var k: float = clampf(t, 0.0, 1.0)
	if _moving_camera and _camera != null and is_instance_valid(_camera):
		_camera.global_position = _camera_from.lerp(_camera_to, k)
		if _has_look_at and _camera.is_inside_tree() and _camera.global_position.distance_to(_look_at) > EPS:
			_camera.look_at(_look_at, Vector3.UP)
	if _moving_actor and _actor != null and is_instance_valid(_actor):
		var pos: Vector3 = _actor_from.lerp(_actor_to, k)
		_actor.global_position = Vector3(pos.x, _actor_from.y, pos.z)


func _begin_camera_move(step: Dictionary) -> void:
	if _camera == null:
		return
	_moving_camera = true
	_camera_from = _camera.global_position
	_camera_to = _vec3(step.get("to", null), _camera_from)
	_has_look_at = step.has("look_at")
	if _has_look_at:
		_look_at = _vec3(step.get("look_at", null), Vector3.ZERO)
	if _step_duration <= 0.0:
		_apply_progress(1.0)


func _begin_actor_move(step: Dictionary) -> void:
	_actor = _actor_named(str(step.get("actor", "")))
	if _actor == null:
		push_warning("CutscenePlayer: unknown actor '%s' in %s" % [str(step.get("actor", "")), str(_id)])
		return
	_moving_actor = true
	var target: Vector2 = _vec2(step.get("to", null), Vector2(_actor.global_position.x, _actor.global_position.z))
	_actor_from = _actor.global_position
	_actor_to = Vector3(target.x, _actor_from.y, target.y)
	# Face the way they walk (owner bug 2026-11-27: Jambavan walked backwards toward Hanuman). Models face -Z.
	var dir: Vector3 = _actor_to - _actor_from
	if Vector2(dir.x, dir.z).length() > 0.01:
		_actor.rotation.y = atan2(-dir.x, -dir.z)
		if _actor.has_method(&"set_pose") and _step_duration > 0.0:
			_actor.call(&"set_pose", &"walk_a")
	if _step_duration <= 0.0:
		_apply_progress(1.0)


func _apply_pose(step: Dictionary) -> void:
	var actor: Node3D = _actor_named(str(step.get("actor", "")))
	if actor == null:
		push_warning("CutscenePlayer: unknown actor '%s' in %s" % [str(step.get("actor", "")), str(_id)])
		return
	var pose: String = str(step.get("pose", ""))
	if (actor as Object).has_method("set_pose"):
		(actor as Object).call("set_pose", StringName(pose))


func _actor_named(actor_name: String) -> Node3D:
	var value: Variant = _actors.get(actor_name, null)
	if value == null:
		value = _actors.get(StringName(actor_name), null)
	return value as Node3D


func _color_for(token: StringName) -> Color:
	var value: Variant = COLOR_TOKENS.get(token, Palette.UI_DARK)
	return value as Color


static func _is_valid_step(step: Dictionary) -> bool:
	var type: StringName = StringName(str(step.get("type", "")))
	if not STEP_TYPES.has(type):
		return false
	match type:
		&"camera_move":
			return _is_vec(step.get("to", null), 3)
		&"actor_move":
			return step.has("actor") and _is_vec(step.get("to", null), 2)
		&"actor_pose":
			return step.has("actor") and step.has("pose")
		&"dialogue":
			return step.has("id")
		&"shloka":
			return step.has("id")
		&"set_flag":
			return step.has("k")
		_:
			return true


static func _is_vec(raw: Variant, size: int) -> bool:
	if not (raw is Array):
		return false
	var arr: Array = raw as Array
	if arr.size() != size:
		return false
	for item: Variant in arr:
		if not (item is float or item is int):
			return false
	return true


static func _as_float(raw: Variant) -> float:
	if raw is float:
		return raw as float
	if raw is int:
		return float(raw as int)
	return 0.0


static func _vec3(raw: Variant, fallback: Vector3) -> Vector3:
	if not _is_vec(raw, 3):
		return fallback
	var arr: Array = raw as Array
	return Vector3(_as_float(arr[0]), _as_float(arr[1]), _as_float(arr[2]))


static func _vec2(raw: Variant, fallback: Vector2) -> Vector2:
	if not _is_vec(raw, 2):
		return fallback
	var arr: Array = raw as Array
	return Vector2(_as_float(arr[0]), _as_float(arr[1]))


static func _as_bool(raw: Variant) -> bool:
	if raw is bool:
		return raw as bool
	return false
