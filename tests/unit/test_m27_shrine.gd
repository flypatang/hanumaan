extends GdUnitTestSuite
## M27 acceptance: shrines (world/shrine.gd, DESIGN §9 M27). Interacting meditates, records last_shrine,
## refills the player's Health and Smarana, announces vitality and saves the game.
## The real save slot 0 is backed up before each test and restored after it, so a developer's save survives.

const ShrineScript: GDScript = preload("res://world/shrine.gd")
const HealthScript: GDScript = preload("res://gameplay/components/health.gd")
const SLOT_ZERO_PATH: String = "user://save_0.json"  # GameState.SAVE_PATH_FORMAT % 0

var _meditated_count: int = 0
var _smarana_seen: Array[float] = []
var _vitality_seen: Array[Vector2i] = []
var _had_save_backup: bool = false
var _save_backup: PackedByteArray = PackedByteArray()


func _state() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("GameState") as Node


func _bus() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("EventBus") as Node


func _on_meditated() -> void:
	_meditated_count += 1


func _on_smarana_changed(value: float) -> void:
	_smarana_seen.append(value)


func _on_vitality_changed(value: int, max_value: int) -> void:
	_vitality_seen.append(Vector2i(value, max_value))


func _make_shrine(shrine_id: String) -> Area3D:
	var shrine: Area3D = ShrineScript.new() as Area3D
	shrine.set("shrine_id", shrine_id)
	shrine.position = Vector3(4.0, 0.0, 6.0)
	auto_free(shrine)
	add_child(shrine)
	return shrine


## A fake player: a Node3D with a Health child.
func _make_player(max_hp: int) -> Node3D:
	var player: Node3D = Node3D.new()
	player.name = "FakePlayer"
	auto_free(player)
	add_child(player)
	var health: Health = HealthScript.new() as Health
	health.name = "Health"
	health.max_value = max_hp
	player.add_child(health)
	return player


## A stand-in devotion component: a Node with a `refill()` method that counts its calls.
func _make_smarana_stub(player: Node3D) -> Node:
	var script: GDScript = GDScript.new()
	script.source_code = "extends Node\nvar refills: int = 0\nfunc refill() -> void:\n\trefills += 1\n"
	script.reload()
	var stub: Node = script.new() as Node
	stub.name = "Devotion"
	auto_free(stub)
	player.add_child(stub)
	return stub


func _player_health(player: Node3D) -> Health:
	return player.get_node("Health") as Health


func _backup_save_slot() -> void:
	_had_save_backup = FileAccess.file_exists(SLOT_ZERO_PATH)
	_save_backup = PackedByteArray()
	if _had_save_backup:
		_save_backup = FileAccess.get_file_as_bytes(SLOT_ZERO_PATH)
	if _had_save_backup:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SLOT_ZERO_PATH))


func _restore_save_slot() -> void:
	if FileAccess.file_exists(SLOT_ZERO_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SLOT_ZERO_PATH))
	if _had_save_backup:
		var file: FileAccess = FileAccess.open(SLOT_ZERO_PATH, FileAccess.WRITE)
		if file != null:
			file.store_buffer(_save_backup)
			file.close()


func before_test() -> void:
	_meditated_count = 0
	_smarana_seen = []
	_vitality_seen = []
	_backup_save_slot()
	var state: Node = _state()
	if state != null:
		state.call("reset")
	var bus: Node = _bus()
	if bus != null:
		bus.connect("smarana_changed", Callable(self, "_on_smarana_changed"))
		bus.connect("vitality_changed", Callable(self, "_on_vitality_changed"))


func after_test() -> void:
	var bus: Node = _bus()
	if bus != null:
		if bus.is_connected("smarana_changed", Callable(self, "_on_smarana_changed")):
			bus.disconnect("smarana_changed", Callable(self, "_on_smarana_changed"))
		if bus.is_connected("vitality_changed", Callable(self, "_on_vitality_changed")):
			bus.disconnect("vitality_changed", Callable(self, "_on_vitality_changed"))
	var state: Node = _state()
	if state != null:
		state.call("reset")
	_restore_save_slot()


func test_shrine_is_an_area_in_group_interactable() -> void:
	var shrine: Area3D = _make_shrine("shrine_1")
	assert_bool(shrine.is_in_group("interactable")).is_true()


func test_interact_refills_player_health_to_max() -> void:
	var shrine: Area3D = _make_shrine("shrine_1")
	var player: Node3D = _make_player(100)
	var health: Health = _player_health(player)
	health.damage(70, null)
	assert_int(health.value).is_equal(30)
	shrine.call("interact", player)
	assert_int(health.value).is_equal(100)


func test_interact_emits_meditated() -> void:
	var shrine: Area3D = _make_shrine("shrine_1")
	var player: Node3D = _make_player(100)
	shrine.connect("meditated", Callable(self, "_on_meditated"))
	shrine.call("interact", player)
	assert_int(_meditated_count).is_equal(1)


func test_interact_records_last_shrine_with_id_and_position() -> void:
	var shrine: Area3D = _make_shrine("shrine_7")
	var player: Node3D = _make_player(100)
	shrine.call("interact", player)
	var state: Node = _state()
	assert_object(state).is_not_null()
	var record: Dictionary = state.get("last_shrine") as Dictionary
	assert_str(str(record["id"])).is_equal("shrine_7")
	var pos: Vector3 = record["pos"] as Vector3
	assert_float(pos.x).is_equal_approx(shrine.global_position.x, 0.001)
	assert_float(pos.z).is_equal_approx(shrine.global_position.z, 0.001)


func test_last_shrine_level_comes_from_ancestor_level_id_meta() -> void:
	var level: Node3D = Node3D.new()
	level.name = "tiny"
	level.set_meta("level_id", "tiny")
	auto_free(level)
	add_child(level)
	var shrine: Area3D = ShrineScript.new() as Area3D
	shrine.set("shrine_id", "shrine_2")
	level.add_child(shrine)
	var player: Node3D = _make_player(100)
	shrine.call("interact", player)
	var record: Dictionary = _state().get("last_shrine") as Dictionary
	assert_str(str(record["level"])).is_equal("tiny")


func test_last_shrine_level_is_empty_without_level_meta() -> void:
	var shrine: Area3D = _make_shrine("shrine_3")
	var player: Node3D = _make_player(100)
	shrine.call("interact", player)
	var record: Dictionary = _state().get("last_shrine") as Dictionary
	assert_str(str(record["level"])).is_equal("")


func test_interact_saves_the_game_to_slot_zero() -> void:
	var shrine: Area3D = _make_shrine("shrine_saved")
	var player: Node3D = _make_player(100)
	shrine.call("interact", player)
	var state: Node = _state()
	state.call("reset")
	assert_int(state.call("load_game", 0) as int).is_equal(OK)
	var record: Dictionary = state.get("last_shrine") as Dictionary
	assert_str(str(record["id"])).is_equal("shrine_saved")


func test_interact_without_health_child_still_records_and_does_not_crash() -> void:
	var shrine: Area3D = _make_shrine("shrine_bare")
	var player: Node3D = Node3D.new()
	auto_free(player)
	add_child(player)
	shrine.call("interact", player)
	var record: Dictionary = _state().get("last_shrine") as Dictionary
	assert_str(str(record["id"])).is_equal("shrine_bare")


func test_interacting_twice_keeps_health_full() -> void:
	var shrine: Area3D = _make_shrine("shrine_1")
	var player: Node3D = _make_player(100)
	shrine.call("interact", player)
	_player_health(player).damage(40, null)
	shrine.call("interact", player)
	assert_int(_player_health(player).value).is_equal(100)


func test_interact_calls_refill_on_a_devotion_component() -> void:
	var shrine: Area3D = _make_shrine("shrine_devotion")
	var player: Node3D = _make_player(100)
	var stub: Node = _make_smarana_stub(player)
	shrine.call("interact", player)
	assert_int(stub.get("refills") as int).is_equal(1)


func test_interact_emits_smarana_changed_with_full_value() -> void:
	var shrine: Area3D = _make_shrine("shrine_smarana")
	var player: Node3D = _make_player(100)
	shrine.call("interact", player)
	assert_int(_smarana_seen.size()).is_equal(1)
	assert_float(_smarana_seen[0]).is_equal_approx(100.0, 0.001)


func test_interact_without_refill_component_still_emits_smarana_changed() -> void:
	var shrine: Area3D = _make_shrine("shrine_no_devotion")
	var player: Node3D = _make_player(100)
	shrine.call("interact", player)
	assert_int(_smarana_seen.size()).is_equal(1)


func test_interact_emits_vitality_changed_with_new_values() -> void:
	var shrine: Area3D = _make_shrine("shrine_vitality")
	var player: Node3D = _make_player(100)
	_player_health(player).damage(70, null)
	shrine.call("interact", player)
	assert_int(_vitality_seen.size()).is_equal(1)
	assert_int(_vitality_seen[0].x).is_equal(100)
	assert_int(_vitality_seen[0].y).is_equal(100)


func test_interact_without_health_child_emits_no_vitality() -> void:
	var shrine: Area3D = _make_shrine("shrine_no_health")
	var player: Node3D = Node3D.new()
	auto_free(player)
	add_child(player)
	shrine.call("interact", player)
	assert_int(_vitality_seen.size()).is_equal(0)
