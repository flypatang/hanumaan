extends GdUnitTestSuite
## FX1 acceptance tests: the objective beacon points at the right node for each prologue objective, hides during
## dialogue, and the HUD edge arrow points toward an off-screen goal and hides for an on-screen one.

const GameStateScript: GDScript = preload("res://core/game_state.gd")
const BusScript: GDScript = preload("res://core/event_bus.gd")


func after_test() -> void:
	_reset_objectives()


func _objectives() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("Objectives")


func _reset_objectives() -> void:
	var o: Node = _objectives()
	o.set("_texts", {})
	o.set("_done", {})


func _make(level_id: String) -> LevelRuntime:
	var rt: LevelRuntime = LevelRuntime.new()
	rt.music_enabled = false
	rt.game_state = auto_free(GameStateScript.new()) as Node
	rt.event_bus = auto_free(BusScript.new()) as Node
	add_child(rt)
	auto_free(rt)
	assert_int(rt.load_level(StringName(level_id), {"skip_triggers": ["t_jambavan", "t_training_done", "t_leap"]}) as int).is_equal(OK)
	return rt


func _tick(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


func test_beacon_targets_each_prologue_objective() -> void:
	_reset_objectives()
	var rt: LevelRuntime = _make("mahendra")
	var o: Node = _objectives()
	o.call("add", &"talk_jambavan", "talk")
	o.call("add", &"training", "train")
	o.call("add", &"reach_peak", "peak")
	rt.refresh_beacon()
	assert_object(rt.beacon()).is_not_null()
	assert_object(rt.beacon().target_node()).is_same(rt.actors()["jambavan"])
	o.call("complete", &"talk_jambavan")
	rt.refresh_beacon()
	assert_str(str(rt.beacon().target_node().name)).is_equal("t_training_done")
	o.call("complete", &"training")
	rt.refresh_beacon()
	assert_str(str(rt.beacon().target_node().name)).is_equal("t_leap")
	assert_bool(rt.beacon().visible).is_true()
	o.call("complete", &"reach_peak")
	rt.refresh_beacon()
	assert_object(rt.beacon().target_node()).is_null()
	assert_bool(rt.beacon().visible).is_false()


func test_no_registered_objective_means_no_beacon() -> void:
	_reset_objectives()
	var rt: LevelRuntime = _make("mahendra")
	rt.refresh_beacon()
	assert_object(rt.beacon().target_node()).is_null()


func test_beacon_stands_on_the_ground_under_the_trigger() -> void:
	_reset_objectives()
	var rt: LevelRuntime = _make("mahendra")
	_objectives().call("add", &"reach_peak", "peak")
	rt.refresh_beacon()
	await _tick(2)
	# The peak tiles are step 3 = 1.5 m.
	assert_float(rt.beacon().global_position.y).is_equal_approx(1.5, 0.05)
	assert_float(rt.beacon().global_position.x).is_equal_approx(43.0, 0.01)


func test_beacon_is_hidden_during_dialogue() -> void:
	_reset_objectives()
	var rt: LevelRuntime = _make("mahendra")
	_objectives().call("add", &"talk_jambavan", "talk")
	rt.refresh_beacon()
	assert_bool(rt.beacon().visible).is_true()
	assert_bool(rt.play_dialogue("pro_jambavan")).is_true()
	for i: int in 3:
		await get_tree().process_frame
	assert_bool(rt.input_locked()).is_true()
	assert_bool(rt.beacon().visible).is_false()
	assert_bool(rt.hud().objective_arrow_visible()).is_false()


func test_hud_arrow_points_toward_an_offscreen_goal() -> void:
	var hud: Hud = auto_free(Hud.new()) as Hud
	add_child(hud)
	var screen: Vector2 = Vector2(1280.0, 800.0)
	hud.show_objective_arrow(Vector2(2000.0, 400.0), screen)
	assert_bool(hud.objective_arrow_visible()).is_true()
	assert_float(hud.objective_arrow_position().x).is_less(screen.x)
	assert_float(hud.objective_arrow_position().x).is_greater(screen.x - 100.0)
	assert_float(hud.objective_arrow_angle()).is_equal_approx(0.0, 0.01)
	hud.show_objective_arrow(Vector2(640.0, -900.0), screen)
	assert_float(hud.objective_arrow_position().y).is_less(100.0)
	assert_float(hud.objective_arrow_angle()).is_less(-1.0)  # pointing up
	hud.show_objective_arrow(Vector2(600.0, 380.0), screen)  # on screen
	assert_bool(hud.objective_arrow_visible()).is_false()


func test_pick_follows_the_objective_order_per_level() -> void:
	var open: Callable = func(id: StringName) -> bool: return id == &"vatika" or id == &"search"
	assert_str(str(ObjectiveBeacon.pick(&"lanka_streets", open)["ref"])).is_equal("t_search_")
	var only_vatika: Callable = func(id: StringName) -> bool: return id == &"vatika"
	assert_str(str(ObjectiveBeacon.pick(&"lanka_streets", only_vatika)["ref"])).is_equal("t_vatika")
	assert_bool(ObjectiveBeacon.pick(&"ocean_leap", open).is_empty()).is_true()
