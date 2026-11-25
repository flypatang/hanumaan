extends GdUnitTestSuite
## M22 acceptance: guard_archer keeps its distance and fires a 3-arrow volley (DESIGN §9 M22, §4.5, §8).

const GuardArcherScript: GDScript = preload("res://gameplay/enemies/guard_archer.gd")
const DT_60: float = 1.0 / 60.0
const DT_30: float = 1.0 / 30.0


func _archer() -> GuardArcher:
	var e: GuardArcher = GuardArcherScript.new() as GuardArcher
	auto_free(e)
	add_child(e)
	e.global_position = Vector3.ZERO
	e.rotation.y = 0.0
	return e


func _target(pos: Vector3) -> Node3D:
	var t: Node3D = Node3D.new()
	auto_free(t)
	add_child(t)
	t.global_position = pos
	return t


func _clear_arrows() -> void:
	for n: Node in get_tree().get_nodes_in_group(GuardArcher.ARROW_GROUP):
		n.free()


func _arrows() -> Array[GuardArcher.Arrow]:
	var out: Array[GuardArcher.Arrow] = []
	for n: Node in get_tree().get_nodes_in_group(GuardArcher.ARROW_GROUP):
		var a: GuardArcher.Arrow = n as GuardArcher.Arrow
		if a != null:
			out.append(a)
	return out


func test_identity_and_table_stats() -> void:
	_clear_arrows()
	var e: GuardArcher = _archer()
	assert_str(String(e.enemy_id)).is_equal("guard_archer")
	assert_int(e.health.max_value).is_equal(30)
	assert_float(e.attack_range).is_equal_approx(10.0, 0.001)


func test_backs_away_when_closer_than_five_metres() -> void:
	_clear_arrows()
	var e: GuardArcher = _archer()
	e.set_target(_target(Vector3(0, 0, -3.0)))
	e.force_state(EnemyBase.State.CHASE)
	e.tick(DT_60)
	assert_float(e.velocity.z).is_greater(0.0)
	assert_float(e.velocity.length()).is_equal_approx(e.speed, 0.01)
	assert_float(e.velocity.x).is_equal_approx(0.0, 0.001)


func test_holds_between_five_and_six_metres_without_firing() -> void:
	_clear_arrows()
	var e: GuardArcher = _archer()
	e.set_target(_target(Vector3(0, 0, -5.5)))
	e.force_state(EnemyBase.State.CHASE)
	e.tick(DT_60)
	assert_int(e.state).is_equal(EnemyBase.State.CHASE)
	assert_float(e.velocity.length()).is_equal_approx(0.0, 0.001)


func test_approaches_when_beyond_ten_metres() -> void:
	_clear_arrows()
	var e: GuardArcher = _archer()
	e.set_target(_target(Vector3(0, 0, -14.0)))
	e.force_state(EnemyBase.State.CHASE)
	e.tick(DT_60)
	assert_float(e.velocity.z).is_less(0.0)


func test_fires_from_six_to_ten_metres_when_ready() -> void:
	_clear_arrows()
	var e: GuardArcher = _archer()
	e.set_target(_target(Vector3(0, 0, -8.0)))
	e.force_state(EnemyBase.State.CHASE)
	e.tick(DT_60)
	assert_int(e.state).is_equal(EnemyBase.State.ATTACK)


func test_telegraph_is_a_narrow_line_toward_the_target() -> void:
	_clear_arrows()
	var e: GuardArcher = _archer()
	e.set_target(_target(Vector3(0, 0, -8.0)))
	e.force_state(EnemyBase.State.ATTACK)
	assert_bool(e.telegraph.visible).is_true()
	var line: BoxMesh = e.telegraph.mesh as BoxMesh
	assert_object(line).is_not_null()
	assert_float(line.size.x).is_less(0.5)
	assert_float(line.size.z).is_equal_approx(10.0, 0.01)
	assert_float(e.telegraph.position.z).is_equal_approx(-5.0, 0.01)
	_clear_arrows()


func test_volley_spawns_three_enemy_arrows_with_a_third_of_the_damage() -> void:
	_clear_arrows()
	var e: GuardArcher = _archer()
	e.set_target(_target(Vector3(0, 0, -8.0)))
	e.force_state(EnemyBase.State.ATTACK)
	for i: int in roundi((e.windup + 0.05) / DT_60):
		e.tick(DT_60)
	var arrows: Array[GuardArcher.Arrow] = _arrows()
	assert_int(arrows.size()).is_equal(3)
	var expected_damage: int = (e.damage as int) / 3
	for a: GuardArcher.Arrow in arrows:
		assert_str(String(a.team)).is_equal("enemy")
		assert_int(a.damage).is_equal(expected_damage)
		assert_bool(a.is_active()).is_true()
	_clear_arrows()


func test_volley_does_not_use_the_melee_hitbox() -> void:
	_clear_arrows()
	var e: GuardArcher = _archer()
	e.set_target(_target(Vector3(0, 0, -8.0)))
	e.force_state(EnemyBase.State.ATTACK)
	for i: int in roundi((e.windup + 0.05) / DT_60):
		e.tick(DT_60)
	assert_bool(e.hitbox.is_active()).is_false()
	_clear_arrows()


func test_arrows_fly_along_their_flight_and_expire() -> void:
	_clear_arrows()
	var e: GuardArcher = _archer()
	e.set_target(_target(Vector3(0, 0, -8.0)))
	e.force_state(EnemyBase.State.ATTACK)
	for i: int in roundi((e.windup + 0.05) / DT_60):
		e.tick(DT_60)
	var arrows: Array[GuardArcher.Arrow] = _arrows()
	assert_int(arrows.size()).is_equal(3)
	var arrow: GuardArcher.Arrow = arrows[1]
	assert_float(arrow.flight.z).is_less(0.0)
	var before: Vector3 = arrow.global_position
	arrow.step(0.1)
	assert_float((arrow.global_position - before).length()).is_equal_approx(GuardArcher.ARROW_SPEED * 0.1, 0.01)
	for i: int in 25:
		arrow.step(0.1)
	assert_bool(arrow.is_active()).is_false()
	_clear_arrows()


func test_volley_timing_is_the_same_at_30_and_60_fps() -> void:
	var results: Array[int] = []
	for dt: float in [DT_30, DT_60]:
		_clear_arrows()
		var e: GuardArcher = _archer()
		e.set_target(_target(Vector3(0, 0, -8.0)))
		e.force_state(EnemyBase.State.ATTACK)
		var elapsed: float = 0.0
		while elapsed < 1.0:
			e.tick(dt)
			elapsed += dt
		assert_int(e.state).is_equal(EnemyBase.State.ATTACK)
		results.append(_arrows().size())
		_clear_arrows()
		assert_int(e.state).is_equal(EnemyBase.State.ATTACK)
	assert_int(results[0]).is_equal(results[1])
	assert_int(results[0]).is_equal(3)
