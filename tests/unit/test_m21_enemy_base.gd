extends GdUnitTestSuite
## M21 acceptance: EnemyBase state machine, vision cone, telegraph, dissolve (DESIGN §9 M21, §4.3, §4.5).

const EnemyScript: GDScript = preload("res://gameplay/enemies/enemy_base.gd")

var _defeated: Array[StringName] = []


func _on_defeated(id: StringName, _pos: Vector3) -> void:
	_defeated.append(id)


func _enemy(id: StringName) -> EnemyBase:
	var e: EnemyBase = EnemyScript.new() as EnemyBase
	e.enemy_id = id
	auto_free(e)
	add_child(e)
	return e


func _target(pos: Vector3, size_state: int) -> Node3D:
	var t: Node3D = Node3D.new()
	t.set_meta("size_state", size_state)
	auto_free(t)
	add_child(t)
	t.global_position = pos
	return t


func _run(e: EnemyBase, seconds: float, delta: float) -> void:
	var steps: int = roundi(seconds / delta)
	for i: int in steps:
		e.tick(delta)


func test_table_has_three_enemies_with_valid_windup() -> void:
	var table: Dictionary = EnemyBase.load_table()
	for id: String in ["guard_spear", "guard_archer", "kinkara"]:
		assert_bool(table.has(id)).is_true()
		var row: Dictionary = table[id] as Dictionary
		assert_bool((row["windup"] as float) >= 0.4).is_true()
	assert_int(((table["guard_spear"] as Dictionary)["hp"] as int)).is_equal(40)
	assert_int(((table["guard_archer"] as Dictionary)["hp"] as int)).is_equal(30)
	assert_int(((table["kinkara"] as Dictionary)["hp"] as int)).is_equal(90)


func test_starts_idle_and_patrols_with_waypoints() -> void:
	var e: EnemyBase = _enemy(&"guard_spear")
	assert_int(e.state).is_equal(EnemyBase.State.IDLE)
	e.waypoints = [Vector3(5, 0, 0), Vector3(-5, 0, 0)]
	e.tick(0.1)
	assert_int(e.state).is_equal(EnemyBase.State.PATROL)


func test_sees_normal_player_in_cone_and_goes_alert_then_chase() -> void:
	var e: EnemyBase = _enemy(&"guard_spear")
	var t: Node3D = _target(Vector3(0, 0, -8), 1)
	e.set_target(t)
	assert_bool(e.can_see(t)).is_true()
	e.tick(0.1)
	assert_int(e.state).is_equal(EnemyBase.State.ALERT)
	_run(e, 1.0, 1.0 / 60.0)
	assert_int(e.state).is_equal(EnemyBase.State.CHASE)


func test_does_not_see_behind() -> void:
	var e: EnemyBase = _enemy(&"guard_spear")
	var t: Node3D = _target(Vector3(0, 0, 5), 1)
	assert_bool(e.can_see(t)).is_false()


func test_small_player_seen_only_within_quarter_range() -> void:
	var e: EnemyBase = _enemy(&"guard_spear")
	var vr: float = e.vision_range
	var far: Node3D = _target(Vector3(0, 0, -vr * 0.5), 0)
	assert_bool(e.can_see(far)).is_false()
	var near: Node3D = _target(Vector3(0, 0, -vr * 0.2), 0)
	assert_bool(e.can_see(near)).is_true()
	var normal: Node3D = _target(Vector3(0, 0, -vr * 0.5), 1)
	assert_bool(e.can_see(normal)).is_true()


func test_telegraph_shown_at_least_windup_before_hitbox() -> void:
	var e: EnemyBase = _enemy(&"guard_spear")
	var t: Node3D = _target(Vector3(0, 0, -1.5), 1)
	e.set_target(t)
	e.force_state(EnemyBase.State.CHASE)
	e.tick(1.0 / 60.0)
	assert_int(e.state).is_equal(EnemyBase.State.ATTACK)
	assert_bool(e.telegraph.visible).is_true()
	var mat: StandardMaterial3D = e.telegraph.material_override as StandardMaterial3D
	assert_float(mat.albedo_color.a).is_equal_approx(0.5, 0.001)
	assert_bool(mat.albedo_color.is_equal_approx(Color(Palette.SINDOOR, 0.5))).is_true()
	assert_bool(e.hitbox.is_active()).is_false()
	var shown: float = 0.0
	var dt: float = 1.0 / 60.0
	while not e.hitbox.is_active() and shown < 5.0:
		e.tick(dt)
		shown += dt
	assert_bool(e.hitbox.is_active()).is_true()
	assert_bool(shown >= 0.4 - 0.02).is_true()
	assert_bool(shown >= e.windup - 0.03).is_true()


func test_attack_outcome_same_at_30_and_60_fps() -> void:
	var results: Array[int] = []
	for dt: float in [1.0 / 30.0, 1.0 / 60.0]:
		var e: EnemyBase = _enemy(&"guard_spear")
		var t: Node3D = _target(Vector3(0, 0, -1.5), 1)
		e.set_target(t)
		e.force_state(EnemyBase.State.CHASE)
		_run(e, 0.6, dt)
		results.append(1 if e.hitbox.is_active() else 0)
	assert_int(results[0]).is_equal(results[1])


func test_stagger_then_resume() -> void:
	var e: EnemyBase = _enemy(&"guard_spear")
	e.apply_hit(5, Vector3.ZERO, false)
	assert_int(e.state).is_equal(EnemyBase.State.STAGGER)
	_run(e, 1.0, 1.0 / 60.0)
	assert_int(e.state).is_not_equal(EnemyBase.State.STAGGER)


func test_kinkara_staggers_only_from_heavy() -> void:
	var e: EnemyBase = _enemy(&"kinkara")
	e.apply_hit(5, Vector3.ZERO, false)
	assert_int(e.state).is_not_equal(EnemyBase.State.STAGGER)
	e.apply_hit(5, Vector3.ZERO, true)
	assert_int(e.state).is_equal(EnemyBase.State.STAGGER)


func test_death_dissolves_emits_and_frees() -> void:
	_defeated.clear()
	var bus: Node = get_node("/root/EventBus")
	bus.connect("enemy_defeated", _on_defeated)
	var e: EnemyBase = _enemy(&"guard_archer")
	e.apply_hit(e.health.max_value, Vector3.ZERO, false)
	assert_int(e.state).is_equal(EnemyBase.State.DISSOLVE)
	assert_int(_defeated.size()).is_equal(0)
	e.tick(0.4)
	assert_float(e.scale.x).is_less(1.0)
	assert_int(_defeated.size()).is_equal(0)
	e.tick(0.41)
	bus.disconnect("enemy_defeated", _on_defeated)
	assert_int(_defeated.size()).is_equal(1)
	assert_str(String(_defeated[0])).is_equal("guard_archer")
	assert_bool(e.is_queued_for_deletion()).is_true()
