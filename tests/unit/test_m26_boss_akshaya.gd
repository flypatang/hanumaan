extends GdUnitTestSuite
## M26 acceptance: Akshaya Kumara, chariot pool, phase switch, dissolve into embers (DESIGN §4.5, §9 M26, §2).

const BossScript: GDScript = preload("res://gameplay/enemies/boss_akshaya.gd")
const DT: float = 1.0 / 60.0


func _boss() -> BossAkshaya:
	var b: BossAkshaya = BossScript.new() as BossAkshaya
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


func _run(b: BossAkshaya, seconds: float) -> void:
	var n: int = int(seconds / DT)
	for i: int in n:
		b.tick(DT)


func _clear_group(g: StringName) -> void:
	for n: Node in get_tree().get_nodes_in_group(g):
		n.free()


func test_stats_and_chariot_pool() -> void:
	var b: BossAkshaya = _boss()
	assert_int(b.health.max_value).is_equal(500)
	assert_int(b.chariot_health.max_value).is_equal(150)
	assert_int(b.phase).is_equal(BossAkshaya.Phase.MOUNTED)
	assert_object(b.chariot).is_not_null()


func test_light_hits_do_nothing_while_mounted() -> void:
	var b: BossAkshaya = _boss()
	b.apply_hit(12, Vector3.ZERO, false)
	assert_int(b.chariot_health.value).is_equal(150)
	assert_int(b.health.value).is_equal(500)


func test_heavy_hit_damages_only_chariot() -> void:
	var b: BossAkshaya = _boss()
	b.apply_hit(40, Vector3.ZERO, true)
	assert_int(b.chariot_health.value).is_equal(110)
	assert_int(b.health.value).is_equal(500)
	assert_int(b.phase).is_equal(BossAkshaya.Phase.MOUNTED)


func test_hurtbox_route_matches_apply_hit() -> void:
	var b: BossAkshaya = _boss()
	b.health.invulnerable = true
	b.health.damage(50, null)
	assert_int(b.health.value).is_equal(500)


func test_destroying_chariot_switches_phase() -> void:
	var b: BossAkshaya = _boss()
	var seen: Array[int] = []
	b.phase_changed.connect(func(p: int) -> void: seen.append(p))
	b.apply_hit(100, Vector3.ZERO, true)
	assert_int(b.phase).is_equal(BossAkshaya.Phase.MOUNTED)
	b.apply_hit(60, Vector3.ZERO, true)
	assert_int(b.phase).is_equal(BossAkshaya.Phase.ON_FOOT)
	assert_array(seen).has_size(1)
	assert_int(b.health.value).is_equal(500)
	assert_bool(b.health.invulnerable).is_false()
	assert_float(b.model.scale.x).is_equal_approx(1.1, 0.001)
	assert_object(b.chariot).is_null()


func test_phase_two_takes_normal_damage() -> void:
	var b: BossAkshaya = _boss()
	b.dismount()
	b.apply_hit(15, Vector3.ZERO, false)
	assert_int(b.health.value).is_equal(485)


func test_has_gold_crown() -> void:
	var b: BossAkshaya = _boss()
	assert_object(b.find_child("Crown", true, false)).is_not_null()


func test_charge_is_telegraphed_at_least_0_4s() -> void:
	var b: BossAkshaya = _boss()
	var t: Node3D = _target(Vector3(0, 0, -10))
	b.set_target(t)
	b.force_state(EnemyBase.State.CHASE)
	b.tick(DT)
	assert_int(b.state).is_equal(EnemyBase.State.ATTACK)
	assert_int(b.move).is_equal(BossAkshaya.Move.CHARGE)
	assert_bool(b.telegraph.visible).is_true()
	var elapsed: float = 0.0
	while not b.hitbox.is_active() and elapsed < 3.0:
		b.tick(DT)
		elapsed += DT
	assert_bool(b.hitbox.is_active()).is_true()
	assert_float(elapsed).is_greater_equal(0.4)
	# The charge actually moves him along the lane.
	b.tick(DT)
	assert_float(b.velocity.length()).is_greater(5.0)


func test_volley_fires_arrows() -> void:
	_clear_group(GuardArcher.ARROW_GROUP)
	var b: BossAkshaya = _boss()
	var t: Node3D = _target(Vector3(0, 0, -8))
	b.set_target(t)
	b.move = BossAkshaya.Move.VOLLEY
	b.force_state(EnemyBase.State.ATTACK)
	_run(b, 0.8)
	assert_int(get_tree().get_nodes_in_group(GuardArcher.ARROW_GROUP).size()).is_equal(BossAkshaya.VOLLEY_ARROWS)
	_clear_group(GuardArcher.ARROW_GROUP)


func test_phase_two_combo_has_three_strikes() -> void:
	var b: BossAkshaya = _boss()
	b.dismount()
	var t: Node3D = _target(Vector3(0, 0, -2))
	b.set_target(t)
	b.move = BossAkshaya.Move.COMBO
	b.force_state(EnemyBase.State.ATTACK)
	var strikes: int = 0
	var was_active: bool = false
	for i: int in 180:
		b.tick(DT)
		b.hitbox.advance(DT)
		if b.hitbox.is_active() and not was_active:
			strikes += 1
		was_active = b.hitbox.is_active()
	assert_int(strikes).is_equal(BossAkshaya.COMBO_STEPS)


func test_dissolves_into_golden_embers() -> void:
	_clear_group(BossAkshaya.EMBER_GROUP)
	var b: BossAkshaya = _boss()
	b.dismount()
	b.apply_hit(500, Vector3.ZERO, true)
	assert_int(b.state).is_equal(EnemyBase.State.DISSOLVE)
	var embers: Array[Node] = get_tree().get_nodes_in_group(BossAkshaya.EMBER_GROUP)
	assert_int(embers.size()).is_equal(1)
	var p: CPUParticles3D = embers[0] as CPUParticles3D
	assert_bool(p.color.is_equal_approx(Palette.GOLD)).is_true()
	b.tick(0.4)
	assert_float(b.scale.x).is_less(1.0)
	_clear_group(BossAkshaya.EMBER_GROUP)
