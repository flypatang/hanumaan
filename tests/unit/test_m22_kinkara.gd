extends GdUnitTestSuite
## M22 acceptance: kinkara ground slam with a 3 m area telegraph, staggers only from heavy hits (DESIGN §4.3, §4.5, §8).

const KinkaraScript: GDScript = preload("res://gameplay/enemies/kinkara.gd")
const DT_60: float = 1.0 / 60.0
const DT_30: float = 1.0 / 30.0


func _kinkara() -> Kinkara:
	var e: Kinkara = KinkaraScript.new() as Kinkara
	auto_free(e)
	add_child(e)
	e.global_position = Vector3.ZERO
	return e


func _target(pos: Vector3) -> Node3D:
	var t: Node3D = Node3D.new()
	auto_free(t)
	add_child(t)
	t.global_position = pos
	return t


func test_identity_and_table_stats() -> void:
	var e: Kinkara = _kinkara()
	assert_str(String(e.enemy_id)).is_equal("kinkara")
	assert_int(e.health.max_value).is_equal(90)
	assert_bool(e.stagger_heavy_only).is_true()


func test_light_hits_do_not_stagger() -> void:
	var e: Kinkara = _kinkara()
	e.force_state(EnemyBase.State.CHASE)
	e.apply_hit(12, Vector3.ZERO, false)
	assert_int(e.state).is_not_equal(EnemyBase.State.STAGGER)
	assert_int(e.health.value).is_equal(78)


func test_heavy_hits_stagger() -> void:
	var e: Kinkara = _kinkara()
	e.force_state(EnemyBase.State.CHASE)
	e.apply_hit(35, Vector3.ZERO, true)
	assert_int(e.state).is_equal(EnemyBase.State.STAGGER)


func test_slam_telegraph_is_a_three_metre_disc() -> void:
	var e: Kinkara = _kinkara()
	e.set_target(_target(Vector3(0, 0, -1.5)))
	e.force_state(EnemyBase.State.ATTACK)
	assert_bool(e.telegraph.visible).is_true()
	var disc: CylinderMesh = e.telegraph.mesh as CylinderMesh
	assert_object(disc).is_not_null()
	assert_float(disc.top_radius).is_equal_approx(3.0, 0.001)
	assert_float(disc.bottom_radius).is_equal_approx(3.0, 0.001)


func test_slam_hitbox_radius_matches_the_telegraph() -> void:
	var e: Kinkara = _kinkara()
	var shape: CollisionShape3D = e.hitbox.get_child(0) as CollisionShape3D
	assert_object(shape).is_not_null()
	var sphere: SphereShape3D = shape.shape as SphereShape3D
	assert_object(sphere).is_not_null()
	assert_float(sphere.radius).is_equal_approx(3.0, 0.001)


func test_telegraph_shows_at_least_point_four_seconds_before_the_hit() -> void:
	for dt: float in [DT_30, DT_60]:
		var e: Kinkara = _kinkara()
		e.set_target(_target(Vector3(0, 0, -1.5)))
		e.force_state(EnemyBase.State.ATTACK)
		var elapsed: float = 0.0
		while elapsed < 0.39:
			e.tick(dt)
			elapsed += dt
		assert_bool(e.telegraph.visible).is_true()
		assert_bool(e.hitbox.is_active()).is_false()
		while elapsed < 0.9:
			e.tick(dt)
			elapsed += dt
		assert_bool(e.hitbox.is_active()).is_true()
		assert_int(e.hitbox.damage).is_equal(25)
		assert_bool(e.telegraph.visible).is_false()


func test_stagger_rule_does_not_depend_on_frame_rate() -> void:
	var e30: Kinkara = _kinkara()
	e30.force_state(EnemyBase.State.CHASE)
	e30.apply_hit(20, Vector3.ZERO, false)
	e30.tick(DT_30)
	e30.apply_hit(35, Vector3.ZERO, true)
	var e60: Kinkara = _kinkara()
	e60.force_state(EnemyBase.State.CHASE)
	e60.apply_hit(20, Vector3.ZERO, false)
	e60.tick(DT_60)
	e60.apply_hit(35, Vector3.ZERO, true)
	assert_int(e30.state).is_equal(e60.state)
	assert_int(e30.state).is_equal(EnemyBase.State.STAGGER)
