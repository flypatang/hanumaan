extends GdUnitTestSuite
## M30 acceptance: the on-rails leap (gameplay/flight/leap_controller.gd, DESIGN §9 M30).

const LeapScript: GDScript = preload("res://gameplay/flight/leap_controller.gd")
const BusScript: GDScript = preload("res://core/event_bus.gd")
const TICK: float = 1.0 / 60.0

var _gates: Array[StringName] = []


func _on_gate(id: StringName) -> void:
	_gates.append(id)


func _make() -> LeapController:
	var c: LeapController = LeapScript.new() as LeapController
	c.read_input = false
	c.build_scenery = false
	c.event_bus = auto_free((BusScript as GDScript).new() as Node)
	c.load_level("res://levels/ocean_leap.json")
	auto_free(c)
	add_child(c)
	_gates.clear()
	c.gate_reached.connect(_on_gate)
	return c


func _run(c: LeapController, seconds: float) -> void:
	var n: int = roundi(seconds * 60.0)
	for i in n:
		c.step(TICK)


func test_level_data_shape() -> void:
	var c: LeapController = _make()
	assert_float(c.path_length()).is_equal_approx(900.0, 1.0)
	assert_float(c.corridor_half_width).is_equal_approx(12.0, 0.001)
	assert_int(c.gate_defs.size()).is_equal(3)


func test_rail_progress_at_fixed_deltas() -> void:
	var c: LeapController = _make()
	_run(c, 1.0)
	assert_float(c.distance).is_equal_approx(40.0, 0.01)
	_run(c, 2.0)
	assert_float(c.distance).is_equal_approx(120.0, 0.01)


func test_progress_independent_of_frame_rate() -> void:
	var a: LeapController = _make()
	var b: LeapController = _make()
	for i in 30:
		a.step(1.0 / 30.0)
	for i in 120:
		b.step(1.0 / 120.0)
	assert_float(a.distance).is_equal_approx(b.distance, 0.01)


func test_gates_emit_in_order_and_pause() -> void:
	var c: LeapController = _make()
	_run(c, 7.0)
	assert_array(_gates).is_equal([&"mainaka"])
	assert_bool(c.paused_at_gate).is_true()
	assert_float(c.distance).is_equal_approx(220.0, 0.001)
	_run(c, 5.0)
	assert_float(c.distance).is_equal_approx(220.0, 0.001)
	c.resume()
	_run(c, 7.0)
	assert_array(_gates).is_equal([&"mainaka", &"surasa"])
	c.resume()
	_run(c, 10.0)
	assert_array(_gates).is_equal([&"mainaka", &"surasa", &"simhika"])
	c.resume()
	_run(c, 10.0)
	assert_bool(c.finished).is_true()
	assert_float(c.distance).is_equal_approx(900.0, 0.01)


func test_corridor_clamping() -> void:
	var c: LeapController = _make()
	c.steer_input = 1.0
	_run(c, 5.0)
	assert_float(c.lateral).is_equal_approx(12.0, 0.001)
	c.steer_input = -1.0
	_run(c, 5.0)
	assert_float(c.lateral).is_equal_approx(-12.0, 0.001)


func test_mainaka_ring_heals() -> void:
	var c: LeapController = _make()
	c.health.value = 20
	c.smarana = 10.0
	_run(c, 7.0)
	assert_int(c.health.value).is_equal(c.health.max_value)
	assert_float(c.smarana).is_equal_approx(100.0, 0.001)


func test_mainaka_ring_missed_does_not_heal() -> void:
	var c: LeapController = _make()
	c.health.value = 20
	c.smarana = 10.0
	c.steer_input = 1.0
	_run(c, 1.5)
	c.steer_input = 0.0
	_run(c, 6.0)
	assert_int(c.health.value).is_equal(20)


func test_dodge_state_and_cooldown() -> void:
	var c: LeapController = _make()
	c.request_dodge()
	assert_bool(c.is_dodging()).is_true()
	_run(c, 0.5)
	assert_bool(c.is_dodging()).is_false()
	c.request_dodge()
	assert_bool(c.is_dodging()).is_false()


func test_rider_follows_path() -> void:
	var c: LeapController = _make()
	var rider: Node3D = auto_free(Node3D.new()) as Node3D
	c.rider = rider
	c.step(TICK)
	assert_float(rider.position.z).is_greater(0.0)


var _hits: Array[StringName] = []


func _on_hit(kind: StringName) -> void:
	_hits.append(kind)


func _steer_to_rock(c: LeapController) -> void:
	c.steer_input = -1.0
	for i in 26:
		c.step(TICK)
	c.steer_input = 0.0


func test_obstacle_hit_deals_damage() -> void:
	var c: LeapController = _make()
	_hits.clear()
	c.obstacle_hit.connect(_on_hit)
	var before: int = c.health.value
	_steer_to_rock(c)
	_run(c, 1.5)
	assert_int(c.health.value).is_equal(before - LeapController.OBSTACLE_DAMAGE)
	assert_array(_hits).is_equal([&"rock"])


func test_dodge_avoids_damage_and_is_invulnerable() -> void:
	var c: LeapController = _make()
	_hits.clear()
	c.obstacle_hit.connect(_on_hit)
	var before: int = c.health.value
	_steer_to_rock(c)
	_run(c, 1.0)
	c.request_dodge()
	assert_bool(c.health.invulnerable).is_true()
	_run(c, 0.2)
	assert_bool(c.health.invulnerable).is_true()
	_run(c, 0.2)
	assert_bool(c.health.invulnerable).is_false()
	_run(c, 0.1)
	assert_int(c.health.value).is_equal(before)
	assert_array(_hits).is_empty()


func test_dodge_available_again_after_cooldown() -> void:
	var c: LeapController = _make()
	c.request_dodge()
	_run(c, 1.2)
	assert_bool(c.is_dodging()).is_false()
	c.request_dodge()
	assert_bool(c.is_dodging()).is_true()


func test_no_hit_events_at_zero_health() -> void:
	var c: LeapController = _make()
	_hits.clear()
	c.obstacle_hit.connect(_on_hit)
	c.health.damage(c.health.max_value, null)
	assert_int(c.health.value).is_equal(0)
	_steer_to_rock(c)
	_run(c, 1.5)
	assert_array(_hits).is_empty()


func test_ring_heal_emits_health_changed() -> void:
	var c: LeapController = _make()
	var seen: Array[int] = []
	c.health.changed.connect(func(v: int, _m: int) -> void: seen.append(v))
	c.health.value = 20
	_run(c, 7.0)
	assert_array(seen).is_not_empty()
