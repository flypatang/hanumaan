extends GdUnitTestSuite
## M24 acceptance: Lankini combo timing, parry window, yields instead of dying (DESIGN §9 M24, §4.5, §8).

const BossScript: GDScript = preload("res://gameplay/enemies/boss_lankini.gd")
const StateScript: GDScript = preload("res://core/game_state.gd")
const DT: float = 1.0 / 60.0


func _boss() -> BossLankini:
	var e: BossLankini = BossScript.new() as BossLankini
	auto_free(e)
	e.game_state = auto_free(StateScript.new()) as Node
	add_child(e)
	e.global_position = Vector3.ZERO
	var t: Node3D = Node3D.new()
	auto_free(t)
	add_child(t)
	t.global_position = Vector3(0, 0, -2.0)
	e.set_target(t)
	return e


## Ticks until `pred` returns true or `limit` seconds pass; returns elapsed seconds.
func _run_until_strike(e: BossLankini, n: int, limit: float) -> float:
	var t: float = 0.0
	while e.strike_count < n and t < limit:
		e.tick(DT)
		t += DT
	return t


func test_stats() -> void:
	var e: BossLankini = _boss()
	assert_str(String(e.enemy_id)).is_equal("boss_lankini")
	assert_int(e.health.max_value).is_equal(250)


func test_combo_is_three_telegraphed_hits() -> void:
	var e: BossLankini = _boss()
	e.force_state(EnemyBase.State.ATTACK)
	assert_bool(e.telegraph.visible).is_true()
	var first: float = _run_until_strike(e, 1, 2.0)
	assert_float(first).is_greater_equal(0.4)
	var strikes_seen: Array[int] = [e.strike_count]
	var guard: float = 0.0
	while e.state == EnemyBase.State.ATTACK and guard < 5.0:
		e.tick(DT)
		guard += DT
		if e.strike_count != strikes_seen[0]:
			assert_bool(e.telegraph.visible).is_false()
			strikes_seen[0] = e.strike_count
	assert_int(e.strike_count).is_equal(3)
	assert_int(e.state).is_equal(EnemyBase.State.CHASE)


func test_each_later_hit_telegraphs_at_least_point_four() -> void:
	var e: BossLankini = _boss()
	e.force_state(EnemyBase.State.ATTACK)
	_run_until_strike(e, 1, 2.0)
	var t: float = 0.0
	# Wait for the telegraph to reappear for hit 2, then time it to the strike.
	while not e.telegraph.visible and t < 2.0:
		e.tick(DT)
		t += DT
	var wind: float = 0.0
	while e.strike_count < 2 and wind < 2.0:
		e.tick(DT)
		wind += DT
	assert_float(wind).is_greater_equal(0.38)


func test_second_pattern_is_a_wide_sweep() -> void:
	var e: BossLankini = _boss()
	e.force_state(EnemyBase.State.ATTACK)
	var guard: float = 0.0
	while e.state == EnemyBase.State.ATTACK and guard < 5.0:
		e.tick(DT)
		guard += DT
	e.force_state(EnemyBase.State.ATTACK)
	assert_bool(e.is_sweep).is_true()
	var mesh: CylinderMesh = e.telegraph.mesh as CylinderMesh
	assert_float(mesh.top_radius).is_equal_approx(BossLankini.SWEEP_RADIUS, 0.001)
	var prior: int = e.strike_count
	_run_until_strike(e, prior + 1, 2.0)
	assert_int(e.hitbox.damage).is_equal(BossLankini.SWEEP_DAMAGE)
	guard = 0.0
	while e.state == EnemyBase.State.ATTACK and guard < 5.0:
		e.tick(DT)
		guard += DT
	assert_int(e.strike_count).is_equal(prior + 1)


func test_light_hit_inside_window_parries() -> void:
	var e: BossLankini = _boss()
	e.force_state(EnemyBase.State.ATTACK)
	_run_until_strike(e, 1, 2.0)
	assert_bool(e.is_parry_window_open()).is_true()
	e.apply_hit(12, Vector3.ZERO, false)
	assert_int(e.state).is_equal(EnemyBase.State.STAGGER)
	assert_int(e.health.value).is_equal(238)
	var t: float = 0.0
	while e.state == EnemyBase.State.STAGGER and t < 3.0:
		e.tick(DT)
		t += DT
	assert_float(t).is_equal_approx(BossLankini.PARRY_STAGGER, 0.05)


func test_light_hit_early_in_telegraph_does_not_parry() -> void:
	var e: BossLankini = _boss()
	e.force_state(EnemyBase.State.ATTACK)
	e.tick(0.1)
	assert_bool(e.is_parry_window_open()).is_false()
	e.apply_hit(12, Vector3.ZERO, false)
	assert_int(e.state).is_equal(EnemyBase.State.ATTACK)


func test_light_hit_after_window_does_not_parry() -> void:
	var e: BossLankini = _boss()
	e.force_state(EnemyBase.State.ATTACK)
	_run_until_strike(e, 1, 2.0)
	e.tick(0.17)
	assert_bool(e.is_parry_window_open()).is_false()
	e.apply_hit(12, Vector3.ZERO, false)
	assert_int(e.state).is_not_equal(EnemyBase.State.STAGGER)


func test_heavy_hit_does_not_parry() -> void:
	var e: BossLankini = _boss()
	e.force_state(EnemyBase.State.ATTACK)
	_run_until_strike(e, 1, 2.0)
	e.apply_hit(35, Vector3.ZERO, true)
	assert_int(e.state).is_not_equal(EnemyBase.State.STAGGER)


func test_yields_instead_of_dying() -> void:
	var e: BossLankini = _boss()
	var gs: Node = e.game_state
	var fired: Array[int] = [0]
	e.yielded.connect(func() -> void: fired[0] += 1)
	e.force_state(EnemyBase.State.CHASE)
	e.apply_hit(250, Vector3.ZERO, true)
	assert_int(e.health.value).is_equal(0)
	assert_bool(e.has_yielded()).is_true()
	assert_int(fired[0]).is_equal(1)
	assert_bool(gs.call("get_flag", &"lankini_yielded", false) as bool).is_true()
	assert_int(e.state).is_not_equal(EnemyBase.State.DISSOLVE)
	for i: int in range(120):
		e.tick(DT)
	assert_bool(is_instance_valid(e)).is_true()
	assert_float(e.scale.x).is_equal_approx(1.0, 0.001)
	assert_bool(e.hitbox.is_active()).is_false()
	# Further hits do nothing and do not re-emit.
	e.apply_hit(10, Vector3.ZERO, false)
	assert_int(fired[0]).is_equal(1)


func test_combo_timing_same_at_30_fps() -> void:
	var e: BossLankini = _boss()
	e.force_state(EnemyBase.State.ATTACK)
	var t: float = 0.0
	while e.strike_count < 1 and t < 2.0:
		e.tick(1.0 / 30.0)
		t += 1.0 / 30.0
	assert_float(t).is_equal_approx(0.5, 0.05)
