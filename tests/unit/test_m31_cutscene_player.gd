extends GdUnitTestSuite
## M31 acceptance tests: narrative/cutscene_player.gd plays step lists from data/cutscenes/<id>.json (SCHEMA.md).
## Fixtures are written to user:// with ids prefixed m31_test_ and removed after each test. The player is
## instantiated from its script and driven with fixed deltas through tick(), never through the scene tree.

const PLAYER_PATH: String = "res://narrative/cutscene_player.gd"
const FIXTURE_PREFIX: String = "m31_test_"
const EPS: float = 0.001

var _written: Array[String] = []


func after_test() -> void:
	var dir: DirAccess = DirAccess.open("user://")
	for path: String in _written:
		if dir != null and dir.file_exists(path):
			dir.remove(path)
	_written.clear()


func _make_player(dir: String = "user://") -> Node:
	var player: Node = auto_free((load(PLAYER_PATH) as GDScript).new() as Node) as Node
	player.set("cutscenes_dir", dir)
	return player


func _write_fixture(id: String, body: String) -> void:
	var path: String = "user://%s%s.json" % [FIXTURE_PREFIX, id]
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(body)
	file.close()
	_written.append(path)


func _fixture_id(id: String) -> StringName:
	return StringName(FIXTURE_PREFIX + id)


## A cutscene with every step type, in a fixed order.
const FULL_BODY: String = """{"steps": [
  {"type": "wait", "duration": 0.5},
  {"type": "camera_move", "to": [10, 5, 0], "look_at": [0, 0, 0], "duration": 1.0},
  {"type": "actor_move", "actor": "hanuman", "to": [4, 6], "duration": 1.0},
  {"type": "actor_pose", "actor": "hanuman", "pose": "meditate"},
  {"type": "set_flag", "k": "m31_seen", "v": true},
  {"type": "dialogue", "id": "pro_leap", "node": "start"},
  {"type": "shloka", "id": "leap_39"},
  {"type": "fade", "color": "NIGHT_INDIGO", "duration": 0.5, "out": true}
]}"""


class Recorder:
	var step_types: Array[StringName] = []
	var step_indices: Array[int] = []
	var dialogues: Array[StringName] = []
	var shlokas: Array[StringName] = []
	var fades: Array[bool] = []
	var finished_count: int = 0


func _record(player: Node) -> Recorder:
	var rec: Recorder = Recorder.new()
	player.connect("step_started", func(index: int, type: StringName) -> void:
		rec.step_indices.append(index)
		rec.step_types.append(type))
	player.connect("dialogue_requested", func(id: StringName, _node: StringName) -> void:
		rec.dialogues.append(id))
	player.connect("shloka_requested", func(id: StringName) -> void:
		rec.shlokas.append(id))
	player.connect("fade_requested", func(_color: Color, _duration: float, fade_out: bool) -> void:
		rec.fades.append(fade_out))
	player.connect("finished", func(_id: StringName) -> void:
		rec.finished_count += 1)
	return rec


func _actors(hanuman: Node3D) -> Dictionary:
	return {"hanuman": hanuman}


## Nodes are added to the suite's tree so global transforms and look_at work.
func _camera() -> Camera3D:
	var cam: Camera3D = auto_free(Camera3D.new()) as Camera3D
	add_child(cam)
	return cam


func _node3d(pos: Vector3) -> Node3D:
	var node: Node3D = auto_free(Node3D.new()) as Node3D
	add_child(node)
	node.global_position = pos
	return node


func _run_until_ui(player: Node, dt: float) -> void:
	var guard: int = 0
	while (player.call("is_playing") as bool) and not (player.call("is_awaiting_ui") as bool) and guard < 10000:
		player.call("tick", dt)
		guard += 1


# --- loading --------------------------------------------------------------------------------------

func test_m31_missing_file_returns_error() -> void:
	var player: Node = _make_player()
	var err: int = player.call("load_cutscene", &"m31_test_does_not_exist") as int
	assert_int(err).is_equal(ERR_FILE_NOT_FOUND)


func test_m31_unknown_step_type_is_rejected() -> void:
	_write_fixture("bad_type", """{"steps": [{"type": "teleport", "to": [0, 0]}]}""")
	var player: Node = _make_player()
	var err: int = player.call("load_cutscene", _fixture_id("bad_type")) as int
	assert_int(err).is_equal(ERR_PARSE_ERROR)


func test_m31_play_unknown_id_does_not_start() -> void:
	var player: Node = _make_player()
	var err: int = player.call("play", &"m31_test_nope", {}, null) as int
	assert_int(err).is_not_equal(OK)
	assert_bool(player.call("is_playing") as bool).is_false()


# --- ordering and completion ----------------------------------------------------------------------

func test_m31_steps_run_in_order_and_complete() -> void:
	_write_fixture("full", FULL_BODY)
	var player: Node = _make_player()
	var rec: Recorder = _record(player)
	var hanuman: Node3D = _node3d(Vector3(0, 3, 0))
	assert_int(player.call("play", _fixture_id("full"), _actors(hanuman), _camera()) as int).is_equal(OK)
	assert_bool(player.call("is_playing") as bool).is_true()

	# Run with fixed 0.1 s deltas, answering each UI prompt as the player would.
	var guard: int = 0
	while (player.call("is_playing") as bool) and guard < 1000:
		if player.call("is_awaiting_ui") as bool:
			player.call("continue_after_ui")
		else:
			player.call("tick", 0.1)
		guard += 1

	assert_bool(player.call("is_playing") as bool).is_false()
	assert_int(rec.finished_count).is_equal(1)
	assert_array(rec.step_indices).is_equal([0, 1, 2, 3, 4, 5, 6, 7])
	assert_array(rec.step_types).is_equal([
		&"wait", &"camera_move", &"actor_move", &"actor_pose",
		&"set_flag", &"dialogue", &"shloka", &"fade",
	])
	assert_array(rec.dialogues).is_equal([&"pro_leap"])
	assert_array(rec.shlokas).is_equal([&"leap_39"])
	assert_array(rec.fades).is_equal([true])


func test_m31_set_flag_is_applied_in_order() -> void:
	_write_fixture("flags", """{"steps": [
	  {"type": "set_flag", "k": "m31_a", "v": 1},
	  {"type": "wait", "duration": 1.0},
	  {"type": "set_flag", "k": "m31_b", "v": 2}
	]}""")
	var player: Node = _make_player()
	var seen: Array[String] = []
	player.connect("flag_set", func(key: StringName, _value: Variant) -> void:
		seen.append(str(key)))
	assert_int(player.call("play", _fixture_id("flags"), {}, null) as int).is_equal(OK)
	player.call("tick", 0.5)
	assert_array(seen).is_equal(["m31_a"])
	player.call("tick", 1.0)
	assert_array(seen).is_equal(["m31_a", "m31_b"])


# --- timing ---------------------------------------------------------------------------------------

func test_m31_wait_holds_until_duration_elapsed() -> void:
	_write_fixture("wait", """{"steps": [{"type": "wait", "duration": 1.0}, {"type": "wait", "duration": 1.0}]}""")
	var player: Node = _make_player()
	assert_int(player.call("play", _fixture_id("wait"), {}, null) as int).is_equal(OK)
	player.call("tick", 0.5)
	assert_int(player.call("current_index") as int).is_equal(0)
	player.call("tick", 0.5)
	assert_int(player.call("current_index") as int).is_equal(1)
	player.call("tick", 1.0)
	assert_bool(player.call("is_playing") as bool).is_false()


func test_m31_leftover_time_carries_into_next_step() -> void:
	_write_fixture("carry", """{"steps": [{"type": "wait", "duration": 0.3}, {"type": "wait", "duration": 0.3}]}""")
	var player: Node = _make_player()
	assert_int(player.call("play", _fixture_id("carry"), {}, null) as int).is_equal(OK)
	player.call("tick", 0.5)
	assert_int(player.call("current_index") as int).is_equal(1)


func test_m31_dialogue_waits_for_continue_after_ui() -> void:
	_write_fixture("talk", """{"steps": [{"type": "dialogue", "id": "ch1_simhika"}, {"type": "wait", "duration": 0.1}]}""")
	var player: Node = _make_player()
	var rec: Recorder = _record(player)
	assert_int(player.call("play", _fixture_id("talk"), {}, null) as int).is_equal(OK)
	player.call("tick", 5.0)
	player.call("tick", 5.0)
	assert_bool(player.call("is_awaiting_ui") as bool).is_true()
	assert_int(player.call("current_index") as int).is_equal(0)
	assert_array(rec.dialogues).is_equal([&"ch1_simhika"])
	player.call("continue_after_ui")
	player.call("tick", 0.1)
	assert_bool(player.call("is_playing") as bool).is_false()
	assert_int(rec.finished_count).is_equal(1)


# --- movement -------------------------------------------------------------------------------------

func test_m31_camera_move_interpolates_and_looks_at() -> void:
	_write_fixture("cam", """{"steps": [{"type": "camera_move", "to": [10, 0, 0], "look_at": [0, 0, 0], "duration": 2.0}]}""")
	var player: Node = _make_player()
	var cam: Camera3D = _camera()
	assert_int(player.call("play", _fixture_id("cam"), {}, cam) as int).is_equal(OK)
	player.call("tick", 1.0)
	assert_float(cam.global_position.x).is_equal_approx(5.0, EPS)
	player.call("tick", 1.0)
	assert_float(cam.global_position.x).is_equal_approx(10.0, EPS)
	assert_float(cam.global_position.z).is_equal_approx(0.0, EPS)
	# Looking at the origin from +X means the forward axis points toward -X.
	var forward: Vector3 = -cam.global_transform.basis.z
	assert_float(forward.x).is_less(-0.9)


func test_m31_actor_move_keeps_height() -> void:
	_write_fixture("actor", """{"steps": [{"type": "actor_move", "actor": "hanuman", "to": [4, 6], "duration": 1.0}]}""")
	var player: Node = _make_player()
	var hanuman: Node3D = _node3d(Vector3(0, 3, 0))
	assert_int(player.call("play", _fixture_id("actor"), _actors(hanuman), null) as int).is_equal(OK)
	player.call("tick", 0.5)
	assert_float(hanuman.global_position.x).is_equal_approx(2.0, EPS)
	player.call("tick", 0.5)
	assert_float(hanuman.global_position.x).is_equal_approx(4.0, EPS)
	assert_float(hanuman.global_position.y).is_equal_approx(3.0, EPS)
	assert_float(hanuman.global_position.z).is_equal_approx(6.0, EPS)


func test_m31_missing_actor_does_not_stall() -> void:
	_write_fixture("ghost", """{"steps": [{"type": "actor_move", "actor": "nobody", "to": [1, 1], "duration": 0.5}, {"type": "wait", "duration": 0.1}]}""")
	var player: Node = _make_player()
	assert_int(player.call("play", _fixture_id("ghost"), {}, null) as int).is_equal(OK)
	player.call("tick", 0.5)
	assert_int(player.call("current_index") as int).is_equal(1)
	player.call("tick", 0.1)
	assert_bool(player.call("is_playing") as bool).is_false()


# --- fades ----------------------------------------------------------------------------------------

func test_m31_fade_emits_palette_color_and_direction() -> void:
	_write_fixture("fade", """{"steps": [{"type": "fade", "color": "SAFFRON", "duration": 0.5, "out": false}]}""")
	var player: Node = _make_player()
	var colors: Array[Color] = []
	var directions: Array[bool] = []
	player.connect("fade_requested", func(color: Color, _duration: float, fade_out: bool) -> void:
		colors.append(color)
		directions.append(fade_out))
	assert_int(player.call("play", _fixture_id("fade"), {}, null) as int).is_equal(OK)
	player.call("tick", 0.25)
	assert_int(colors.size()).is_equal(1)
	assert_bool(colors[0].is_equal_approx(Palette.SAFFRON)).is_true()
	assert_bool(directions[0]).is_false()
	assert_bool(player.call("is_playing") as bool).is_true()
	player.call("tick", 0.25)
	assert_bool(player.call("is_playing") as bool).is_false()


# --- frame-rate independence (DESIGN §8) -----------------------------------------------------------

func test_m31_outcome_is_independent_of_frame_rate() -> void:
	var results: Array[Vector3] = []
	var orders: Array[String] = []
	for dt: float in [1.0 / 30.0, 1.0 / 60.0]:
		_write_fixture("fps", FULL_BODY)
		var player: Node = _make_player()
		var rec: Recorder = _record(player)
		var hanuman: Node3D = _node3d(Vector3(0, 3, 0))
		assert_int(player.call("play", _fixture_id("fps"), _actors(hanuman), _camera()) as int).is_equal(OK)
		var guard: int = 0
		while (player.call("is_playing") as bool) and guard < 100000:
			if player.call("is_awaiting_ui") as bool:
				player.call("continue_after_ui")
			else:
				player.call("tick", dt)
			guard += 1
		results.append(hanuman.global_position)
		orders.append(",".join(PackedStringArray(rec.step_types.map(func(t: StringName) -> String: return str(t)))))
		assert_int(rec.finished_count).is_equal(1)
	assert_array(orders).has_size(2)
	assert_str(orders[0]).is_equal(orders[1])
	assert_float(results[0].distance_to(results[1])).is_less(EPS)


func test_m31_stop_cancels_without_finished() -> void:
	_write_fixture("stop", """{"steps": [{"type": "wait", "duration": 5.0}]}""")
	var player: Node = _make_player()
	var rec: Recorder = _record(player)
	assert_int(player.call("play", _fixture_id("stop"), {}, null) as int).is_equal(OK)
	player.call("stop")
	assert_bool(player.call("is_playing") as bool).is_false()
	assert_int(rec.finished_count).is_equal(0)
