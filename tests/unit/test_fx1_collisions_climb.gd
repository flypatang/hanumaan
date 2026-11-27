extends GdUnitTestSuite
## FX1 acceptance tests: solid props and NPCs block Hanuman (also while dodging), ledges up to 0.55 m are stepped up
## (so the Mahendra terraces and the peak are reachable on foot), all with real movement through the Player.

const GameStateScript: GDScript = preload("res://core/game_state.gd")
const BusScript: GDScript = preload("res://core/event_bus.gd")
const SKIP: Array[String] = ["t_jambavan", "t_training_done", "t_leap"]


func _make(level_id: String, skip: Array[String] = SKIP) -> LevelRuntime:
	var rt: LevelRuntime = LevelRuntime.new()
	rt.music_enabled = false
	rt.game_state = auto_free(GameStateScript.new()) as Node
	rt.event_bus = auto_free(BusScript.new()) as Node
	add_child(rt)
	auto_free(rt)
	assert_int(rt.load_level(StringName(level_id), {"skip_triggers": skip}) as int).is_equal(OK)
	return rt


func _tick(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


## A player whose input maps straight to world axes (no camera), standing at (x, z) on the floor.
func _place(rt: LevelRuntime, x: float, z: float) -> Player:
	var p: Player = rt.player()
	p.read_input = false
	p.camera_path = NodePath("")
	p.global_position = Vector3(x, _floor_at(rt, x, z) + 0.1, z)
	p.velocity = Vector3.ZERO
	return p


func _floor_at(rt: LevelRuntime, x: float, z: float) -> float:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
			Vector3(x, 40.0, z), Vector3(x, -5.0, z), Layers.mask([Layers.WORLD]))
	var hit: Dictionary = rt.get_world_3d().direct_space_state.intersect_ray(query)
	return (hit["position"] as Vector3).y if not hit.is_empty() else 0.0


func _walk(p: Player, dir: Vector2, seconds: float) -> void:
	for i: int in roundi(seconds * 60.0):
		p.move_input = dir
		await get_tree().physics_frame
	p.move_input = Vector2.ZERO


func test_player_cannot_walk_through_a_rock() -> void:
	var rt: LevelRuntime = _make("mahendra")
	await _tick(5)
	var p: Player = _place(rt, 9.0, 14.0)  # the rock stands at (9, 17), size 1.5
	await _tick(5)
	await _walk(p, Vector2(0.0, 1.0), 2.0)
	assert_float(p.global_position.z).is_less(16.25)
	assert_float(p.global_position.z).is_greater(14.5)  # it did walk up to the rock


func test_player_cannot_walk_through_a_tree() -> void:
	var rt: LevelRuntime = _make("mahendra")
	await _tick(5)
	var p: Player = _place(rt, 25.0, 22.0)  # a shimshapa tree at (25, 25)
	await _tick(5)
	await _walk(p, Vector2(0.0, 1.0), 2.0)
	assert_float(p.global_position.z).is_less(24.7)
	assert_float(p.global_position.z).is_greater(22.5)


func test_player_cannot_walk_through_jambavan() -> void:
	var rt: LevelRuntime = _make("mahendra")
	await _tick(5)
	var jambavan: Node3D = rt.actors()["jambavan"] as Node3D
	var p: Player = _place(rt, 14.0, 13.0)
	await _tick(5)
	await _walk(p, Vector2(1.0, 0.0), 2.0)
	var flat: Vector2 = Vector2(p.global_position.x - jambavan.global_position.x, p.global_position.z - jambavan.global_position.z)
	assert_float(flat.length()).is_greater(0.7)
	assert_float(p.global_position.x).is_greater(16.0)


func test_dodging_into_a_rock_does_not_pass_through() -> void:
	var rt: LevelRuntime = _make("mahendra")
	await _tick(5)
	var p: Player = _place(rt, 9.0, 15.0)
	await _tick(5)
	p.move_input = Vector2(0.0, 1.0)
	p.request_leap()
	await _walk(p, Vector2(0.0, 1.0), 1.0)
	assert_float(p.global_position.z).is_less(16.25)
	assert_bool(p.collision_mask & Layers.mask([Layers.WORLD]) != 0).is_true()


func test_player_steps_up_a_terrace_but_not_a_wall() -> void:
	var rt: LevelRuntime = _make("mahendra")
	await _tick(5)
	# Tile (14..16, 14..16) is step 1 (0.5 m) next to step 0 ground at x < 28; tile row z = 23 and column 0 are walls.
	var p: Player = _place(rt, 25.0, 31.0)
	await _tick(5)
	var y0: float = p.global_position.y
	await _walk(p, Vector2(1.0, 0.0), 1.5)
	assert_float(p.global_position.x).is_greater(30.0)
	assert_float(p.global_position.y).is_greater(y0 + 0.4)
	var wall: Player = _place(rt, 30.0, 40.0)
	await _tick(5)
	await _walk(wall, Vector2(0.0, 1.0), 2.0)
	assert_float(wall.global_position.z).is_less(46.0)  # the south wall tiles begin at z = 46


func test_walking_from_the_spawn_to_the_peak_trigger_succeeds() -> void:
	var rt: LevelRuntime = _make("mahendra", ["t_jambavan", "t_training_done"])
	await _tick(5)
	var p: Player = rt.player()
	p.read_input = false
	p.camera_path = NodePath("")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://levels/mahendra.json")) as Dictionary
	var route: Array[Vector2] = PlaythroughBot.plan_route(data, Vector2(p.global_position.x, p.global_position.z), Vector2(43.0, 43.0))
	assert_bool(route.is_empty()).is_false()
	var fired: Array[bool] = [false]
	rt.trigger_fired.connect(func(tid: StringName, _on: String) -> void:
		if tid == &"t_leap":
			fired[0] = true)
	var seconds: float = 0.0
	var wp: int = 0
	while seconds < 30.0 and not fired[0] and wp < route.size():
		var here: Vector2 = Vector2(p.global_position.x, p.global_position.z)
		if here.distance_to(route[wp]) < 0.6:
			wp += 1
			continue
		p.move_input = (route[wp] - here).normalized()
		await get_tree().physics_frame
		seconds += 1.0 / 60.0
	p.move_input = Vector2.ZERO
	assert_bool(fired[0]).is_true()
	assert_float(p.global_position.y).is_greater(1.2)  # up on the step-3 peak (1.5 m)
	assert_float(seconds).is_less(30.0)


func test_every_solid_prop_in_every_level_has_a_collider() -> void:
	for level: String in ["mahendra", "lanka_gate", "lanka_streets", "lanka_rooftops", "ashoka_vatika", "ravana_court"]:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://levels/%s.json" % level)) as Dictionary
		var root: Node3D = LevelBuilder.build(data)
		var props: Node = root.get_node(^"Props")
		for prop: Node in props.get_children():
			var kind: String = str(prop.get_meta("kind", ""))
			if kind == "grass_patch":
				continue
			assert_bool(_has_body(prop)).override_failure_message("%s: %s has no collider" % [level, prop.name]).is_true()
		root.free()


func _has_body(node: Node) -> bool:
	if node is StaticBody3D:
		return true
	for child: Node in node.get_children():
		if _has_body(child):
			return true
	return false
