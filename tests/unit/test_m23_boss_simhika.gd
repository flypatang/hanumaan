extends GdUnitTestSuite
## M23 acceptance: boss_simhika.gd phase table, shrink window, dissolution (DESIGN §4.5, §9 M23, §2).

const BossScript: GDScript = preload("res://gameplay/enemies/boss_simhika.gd")
const DT: float = 1.0 / 60.0


func _boss() -> BossSimhika:
	var b: BossSimhika = BossScript.new() as BossSimhika
	auto_free(b)
	add_child(b)
	return b


func _player(pos: Vector3, size_state: int) -> Node3D:
	var p: Node3D = Node3D.new()
	auto_free(p)
	add_child(p)
	p.global_position = pos
	p.set_meta("size_state", size_state)
	return p


func _run(b: BossSimhika, seconds: float) -> void:
	var n: int = roundi(seconds / DT)
	for i: int in n:
		b.tick(DT)


func _engaged(size_state: int = 1) -> BossSimhika:
	var b: BossSimhika = _boss()
	var hp: Health = Health.new()
	auto_free(hp)
	b.player_health = hp
	b.engage(_player(Vector3(10, 0, 0), size_state))
	return b


func _to_phase3(b: BossSimhika) -> void:
	b.health.value = BossSimhika.PHASE3_HP
	b.tick(DT)


func test_stats_and_phase_table() -> void:
	var b: BossSimhika = _boss()
	assert_int(b.health.max_value).is_equal(400)
	assert_int(BossSimhika.phase_for_hp(400)).is_equal(1)
	assert_int(BossSimhika.phase_for_hp(281)).is_equal(1)
	assert_int(BossSimhika.phase_for_hp(280)).is_equal(2)
	assert_int(BossSimhika.phase_for_hp(141)).is_equal(2)
	assert_int(BossSimhika.phase_for_hp(140)).is_equal(3)
	assert_int(BossSimhika.phase_for_hp(1)).is_equal(3)
	assert_int(BossSimhika.inner_phase_for_hp(140)).is_equal(1)
	assert_int(BossSimhika.inner_phase_for_hp(93)).is_equal(2)
	assert_int(BossSimhika.inner_phase_for_hp(47)).is_equal(3)


func test_phase_transitions_at_hp_thresholds() -> void:
	var b: BossSimhika = _engaged()
	assert_int(b.phase).is_equal(1)
	b.apply_hit(120, Vector3.ZERO, true)
	assert_int(b.health.value).is_equal(280)
	b.tick(DT)
	assert_int(b.phase).is_equal(2)
	b.apply_hit(140, Vector3.ZERO, true)
	b.tick(DT)
	assert_int(b.health.value).is_equal(140)
	assert_int(b.phase).is_equal(3)


func test_a_big_hit_cannot_skip_a_phase() -> void:
	var b: BossSimhika = _engaged()
	b.apply_hit(390, Vector3.ZERO, true)
	assert_int(b.health.value).is_equal(BossSimhika.PHASE2_HP)


func test_shadow_catches_player_and_stuns() -> void:
	var b: BossSimhika = _engaged()
	b.shadow_start(Vector3(10.5, 0, 0))
	b.tick(DT)
	assert_bool(b.shadow_active).is_false()
	assert_int(b.player_health.value).is_equal(100 - BossSimhika.GRAB_DAMAGE)
	assert_float(b.player_stun_left).is_greater(0.5)


func test_shadow_chases_moving_player() -> void:
	var b: BossSimhika = _engaged()
	b.shadow_start(Vector3(-10, 0, 0))
	var dist0: float = b.shadow_pos.distance_to(Vector3(10, 0, 0))
	_run(b, 0.5)
	assert_float(b.shadow_pos.distance_to(Vector3(10, 0, 0))).is_less(dist0)


func test_wave_telegraph_is_at_least_0_6_seconds() -> void:
	var b: BossSimhika = _engaged()
	b.health.value = BossSimhika.PHASE2_HP
	b.tick(DT)
	b.wave_start()
	assert_bool(b.wave_telegraph_visible()).is_true()
	_run(b, 0.55)
	assert_bool(b.wave_telegraph_visible()).is_true()
	assert_int(b.waves_struck).is_equal(0)
	_run(b, 0.1)
	assert_int(b.waves_struck).is_equal(1)
	assert_float(BossSimhika.WAVE_TELEGRAPH).is_equal_approx(0.6, 0.0001)


func test_wave_hits_player_in_band_but_not_dodging_player() -> void:
	var b: BossSimhika = _engaged()
	b.health.value = BossSimhika.PHASE2_HP
	b.tick(DT)
	b.wave_start()
	_run(b, 0.7)
	assert_int(b.player_health.value).is_equal(100 - BossSimhika.WAVE_DAMAGE)
	b.player_health.invulnerable = true
	b.wave_start()
	_run(b, 0.7)
	assert_int(b.player_health.value).is_equal(100 - BossSimhika.WAVE_DAMAGE)


func test_hits_outside_are_ignored_while_mouth_closed() -> void:
	var b: BossSimhika = _engaged()
	_to_phase3(b)
	assert_bool(b.is_vulnerable()).is_false()
	b.apply_hit(50, Vector3.ZERO, true)
	assert_int(b.health.value).is_equal(BossSimhika.PHASE3_HP)


func test_mouth_window_is_three_seconds() -> void:
	var b: BossSimhika = _engaged()
	_to_phase3(b)
	_run(b, BossSimhika.CLOSED_TIME + 0.1)
	assert_bool(b.window_open()).is_true()
	assert_float(BossSimhika.WINDOW_TIME).is_equal_approx(3.0, 0.0001)
	assert_float(b.window_left()).is_less(3.0)
	_run(b, 2.8)
	assert_bool(b.window_open()).is_true()
	_run(b, 0.3)
	assert_bool(b.window_open()).is_false()


func test_missing_the_window_bites_and_closes() -> void:
	var b: BossSimhika = _engaged(1)
	_to_phase3(b)
	_run(b, BossSimhika.CLOSED_TIME + BossSimhika.WINDOW_TIME + 0.2)
	assert_int(b.player_health.value).is_equal(100 - BossSimhika.BITE_DAMAGE)
	assert_bool(b.is_inside()).is_false()
	assert_bool(b.window_open()).is_false()


func test_shrinking_in_window_dives_in_and_boss_becomes_vulnerable() -> void:
	var b: BossSimhika = _engaged(1)
	_to_phase3(b)
	_run(b, BossSimhika.CLOSED_TIME + 0.5)
	assert_bool(b.window_open()).is_true()
	b.target.set_meta("size_state", 0)
	b.tick(DT)
	assert_bool(b.is_inside()).is_true()
	assert_bool(b.is_vulnerable()).is_true()
	b.apply_hit(10, Vector3.ZERO, false)
	assert_int(b.health.value).is_equal(BossSimhika.PHASE3_HP - 10)
	assert_int(b.player_health.value).is_equal(100)


func test_three_inner_hit_phases_then_defeat() -> void:
	var b: BossSimhika = _engaged(0)
	_to_phase3(b)
	for expected_inner: int in [1, 2, 3]:
		_run(b, BossSimhika.CLOSED_TIME + 0.2)
		b.tick(DT)
		assert_bool(b.is_inside()).is_true()
		assert_int(b.inner_phase).is_equal(expected_inner)
		b.apply_hit(500, Vector3.ZERO, true)
		b.tick(DT)
	assert_bool(b.is_defeated()).is_true()
	assert_int(b.health.value).is_equal(0)


func test_defeat_kneels_then_dissolves_and_emits_enemy_defeated() -> void:
	var bus: Node = (load("res://core/event_bus.gd") as GDScript).new() as Node
	auto_free(bus)
	var b: BossSimhika = _boss()
	b.event_bus = bus
	var got: Array[StringName] = []
	bus.connect("enemy_defeated", func(id: StringName, _pos: Vector3) -> void: got.append(id))
	b.engage(_player(Vector3(10, 0, 0), 0))
	b.health.value = 1
	b.force_inside()
	b.apply_hit(5, Vector3.ZERO, true)
	assert_bool(b.is_defeated()).is_true()
	assert_bool(b.is_kneeling()).is_true()
	assert_array(got).has_size(0)
	_run(b, BossSimhika.KNEEL_TIME + 0.1)
	assert_bool(b.is_kneeling()).is_false()
	assert_array(got).has_size(0)
	_run(b, BossSimhika.DISSOLVE_TIME + 0.2)
	assert_array(got).has_size(1)
	assert_str(String(got[0])).is_equal("boss_simhika")


func test_leap_gate_pauses_then_resumes_after_defeat() -> void:
	var leap: LeapController = LeapController.new()
	leap.read_input = false
	leap.build_scenery = false
	auto_free(leap)
	add_child(leap)
	var bus: Node = (load("res://core/event_bus.gd") as GDScript).new() as Node
	auto_free(bus)
	var b: BossSimhika = _boss()
	b.event_bus = bus
	b.player_health = Health.new()
	auto_free(b.player_health)
	b.attach_leap(leap, _player(Vector3(10, 0, 0), 0))
	leap.paused_at_gate = true
	leap.gate_reached.emit(&"simhika")
	assert_bool(b.active).is_true()
	b.health.value = 1
	b.force_inside()
	b.apply_hit(1000, Vector3.ZERO, true)
	_run(b, BossSimhika.KNEEL_TIME + BossSimhika.DISSOLVE_TIME + 0.3)
	assert_bool(leap.paused_at_gate).is_false()


func test_other_gates_are_ignored() -> void:
	var leap: LeapController = LeapController.new()
	leap.read_input = false
	leap.build_scenery = false
	auto_free(leap)
	add_child(leap)
	var b: BossSimhika = _boss()
	b.attach_leap(leap, _player(Vector3.ZERO, 1))
	leap.gate_reached.emit(&"mainaka")
	assert_bool(b.active).is_false()
