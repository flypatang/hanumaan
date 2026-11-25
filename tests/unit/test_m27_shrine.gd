extends GdUnitTestSuite
## M27 acceptance: shrines (world/shrine.gd, DESIGN §9 M27). Interacting meditates, records last_shrine,
## refills the player's Health and saves the game.

const ShrineScript: GDScript = preload("res://world/shrine.gd")
const HealthScript: GDScript = preload("res://gameplay/components/health.gd")

var _meditated_count: int = 0


func _state() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("GameState") as Node


func _on_meditated() -> void:
	_meditated_count += 1


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


func _player_health(player: Node3D) -> Health:
	return player.get_node("Health") as Health


func before_test() -> void:
	_meditated_count = 0
	var state: Node = _state()
	if state != null:
		state.call("reset")


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
