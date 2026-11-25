extends GdUnitTestSuite
## M25 acceptance: Jambumali, archer boss (DESIGN §9 M25, §4.5).

const BossScript: GDScript = preload("res://gameplay/enemies/boss_jambumali.gd")
const DT: float = 1.0 / 60.0


func _boss() -> BossJambumali:
	var b: BossJambumali = BossScript.new() as BossJambumali
	auto_free(b)
	add_child(b)
	b.global_position = Vector3.ZERO
	return b


func _target(pos: Vector3) -> Node3D:
	var t: Node3D = Node3D.new()
	auto_free(t)
	add_child(t)
	t.global_position = pos
	return t


func _run(b: BossJambumali, seconds: float) -> void:
	var n: int = int(seconds / DT)
	for i: int in n:
		b.tick(DT)
		b.global_position += b.velocity * DT


func _clear() -> void:
	for n: Node in get_tree().get_nodes_in_group(BossJambumali.STORM_GROUP):
		n.free()
	for n: Node in get_tree().get_nodes_in_group(GuardArcher.ARROW_GROUP):
		n.free()


func test_stats_and_model_scale() -> void:
	var b: BossJambumali = _boss()
	assert_int(b.health.max_value).is_equal(350)
	assert_float(b.model.scale.x).is_equal_approx(1.3, 0.001)
	assert_bool(b.stagger_heavy_only).is_true()


func test_storm_telegraph_then_hit_after_point_eight() -> void:
	_clear()
	var b: BossJambumali = _boss()
	b.set_target(_target(Vector3(0, 0, -8.0)))
	b.force_state(EnemyBase.State.CHASE)
	b.tick(DT)
	assert_int(b.state).is_equal(EnemyBase.State.ATTACK)
	assert_str(String(b.pattern)).is_equal("storm")
	assert_bool(b.telegraph.visible).is_true()
	assert_float((b.telegraph.mesh as CylinderMesh).top_radius).is_equal_approx(5.0, 0.001)
	_run(b, 0.7)
	assert_array(get_tree().get_nodes_in_group(BossJambumali.STORM_GROUP)).has_size(0)
	_run(b, 0.2)
	assert_array(get_tree().get_nodes_in_group(BossJambumali.STORM_GROUP)).has_size(1)
	var s: Node3D = get_tree().get_nodes_in_group(BossJambumali.STORM_GROUP)[0] as Node3D
	assert_float(s.global_position.z).is_equal_approx(-8.0, 0.01)
	_clear()


func test_second_attack_is_aimed_triple_shot() -> void:
	_clear()
	var b: BossJambumali = _boss()
	b.set_target(_target(Vector3(0, 0, -8.0)))
	b.force_state(EnemyBase.State.CHASE)
	_run(b, 1.5)
	_clear()
	_run(b, 3.5)
	assert_str(String(b.pattern)).is_equal("triple")
	assert_array(get_tree().get_nodes_in_group(GuardArcher.ARROW_GROUP)).has_size(3)
	_clear()


func test_moves_to_next_pillar_every_six_seconds() -> void:
	_clear()
	var b: BossJambumali = _boss()
	b.attack_range = 0.1
	var pts: Array[Vector3] = [Vector3(10, 0, 0), Vector3(-10, 0, 0)]
	b.set_pillars(pts)
	b.set_target(_target(Vector3(0, 0, -30.0)))
	b.force_state(EnemyBase.State.CHASE)
	_run(b, 5.5)
	assert_bool(b.is_relocating()).is_false()
	_run(b, 0.7)
	assert_bool(b.is_relocating()).is_true()
	assert_int(b.pillar_index).is_equal(0)
	_run(b, 3.0)
	assert_float(b.global_position.x).is_equal_approx(10.0, 0.5)
	assert_bool(b.is_relocating()).is_false()


func test_stagger_only_from_heavy_hit() -> void:
	var b: BossJambumali = _boss()
	b.force_state(EnemyBase.State.CHASE)
	b.apply_hit(5, Vector3.ZERO, false)
	assert_int(b.state).is_equal(EnemyBase.State.CHASE)
	b.apply_hit(30, Vector3.ZERO, true)
	assert_int(b.state).is_equal(EnemyBase.State.STAGGER)


func test_dissolves_at_zero_hp() -> void:
	var b: BossJambumali = _boss()
	b.apply_hit(350, Vector3.ZERO, true)
	assert_int(b.state).is_equal(EnemyBase.State.DISSOLVE)
