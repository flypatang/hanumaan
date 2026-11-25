extends GdUnitTestSuite
## M22 acceptance: guard_spear forward lunge (DESIGN §9 M22, §4.3, §8 frame-rate rule).

const GuardSpearScript: GDScript = preload("res://gameplay/enemies/guard_spear.gd")
const DT_60: float = 1.0 / 60.0
const DT_30: float = 1.0 / 30.0


func _spear() -> GuardSpear:
	var e: GuardSpear = GuardSpearScript.new() as GuardSpear
	auto_free(e)
	add_child(e)
	return e


func _target(pos: Vector3) -> Node3D:
	var t: Node3D = Node3D.new()
	auto_free(t)
	add_child(t)
	t.global_position = pos
	return t


## Runs one attack from the start of its windup for `seconds`, returning the distance covered by the lunge.
func _lunge_distance(e: GuardSpear, dt: float, seconds: float) -> float:
	var total: float = 0.0
	var steps: int = roundi(seconds / dt)
	for i: int in steps:
		e.tick(dt)
		total += e.velocity.length() * dt
	return total


func test_identity_and_table_stats() -> void:
	var e: GuardSpear = _spear()
	assert_str(String(e.enemy_id)).is_equal("guard_spear")
	assert_int(e.health.max_value).is_equal(40)
	assert_float(e.windup).is_greater_equal(0.4)


func test_lunge_moves_forward_only_during_strike() -> void:
	var e: GuardSpear = _spear()
	e.rotation.y = 0.0
	e.global_position = Vector3.ZERO
	e.set_target(_target(Vector3(0, 0, -2.0)))
	e.force_state(EnemyBase.State.ATTACK)
	var lunge_ticks: int = 0
	var sideways: float = 0.0
	var backwards: bool = false
	for i: int in roundi(0.95 / DT_60):
		e.tick(DT_60)
		if e.velocity.length() > 0.001:
			lunge_ticks += 1
			sideways = maxf(sideways, absf(e.velocity.x))
			if e.velocity.z >= 0.0:
				backwards = true
	assert_int(lunge_ticks).is_between(10, 14)
	assert_bool(backwards).is_false()
	assert_float(sideways).is_less(0.001)
	assert_int(e.state).is_equal(EnemyBase.State.ATTACK)


func test_lunge_covers_a_short_dash_at_lunge_speed() -> void:
	var e: GuardSpear = _spear()
	e.rotation.y = 0.0
	e.set_target(_target(Vector3(0, 0, -2.0)))
	e.force_state(EnemyBase.State.ATTACK)
	var total: float = _lunge_distance(e, DT_60, 0.95)
	# The dash moves in whole physics ticks, so one tick of slack (0.1 m at 60 fps, 0.2 m at 30 fps) is allowed.
	assert_float(total).is_equal_approx(GuardSpear.LUNGE_DISTANCE, 0.25)
	assert_float(GuardSpear.LUNGE_DISTANCE).is_less(2.0)


func test_hitbox_is_active_during_the_strike() -> void:
	var e: GuardSpear = _spear()
	e.set_target(_target(Vector3(0, 0, -2.0)))
	e.force_state(EnemyBase.State.ATTACK)
	_lunge_distance(e, DT_60, e.windup + 0.05)
	assert_bool(e.hitbox.is_active()).is_true()
	assert_bool(e.telegraph.visible).is_false()


func test_same_outcome_at_30_and_60_fps() -> void:
	var e30: GuardSpear = _spear()
	e30.rotation.y = 0.0
	e30.set_target(_target(Vector3(0, 0, -2.0)))
	e30.force_state(EnemyBase.State.ATTACK)
	var d30: float = _lunge_distance(e30, DT_30, 0.95)

	var e60: GuardSpear = _spear()
	e60.rotation.y = 0.0
	e60.set_target(_target(Vector3(0, 0, -2.0)))
	e60.force_state(EnemyBase.State.ATTACK)
	var d60: float = _lunge_distance(e60, DT_60, 0.95)

	assert_float(d30).is_equal_approx(d60, 0.25)
	assert_int(e30.state).is_equal(e60.state)
	assert_int(e30.state).is_equal(EnemyBase.State.ATTACK)
	e30.tick(0.2)
	e60.tick(0.2)
	assert_int(e30.state).is_equal(EnemyBase.State.CHASE)
	assert_int(e60.state).is_equal(EnemyBase.State.CHASE)
