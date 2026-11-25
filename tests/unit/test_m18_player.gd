extends GdUnitTestSuite
## Acceptance tests for M18 (gameplay/player/player.gd), DESIGN §9 and §4.3.
## Every scenario is stepped by calling _physics_process with fixed deltas, at 30 and at 60 fps.

const FPS_LIST: Array[int] = [30, 60]


func _player() -> Player:
	var p: Player = auto_free(Player.new()) as Player
	p.read_input = false
	p.event_bus = auto_free((load("res://core/event_bus.gd") as GDScript).new()) as Node
	add_child(p)
	return p


func _run(p: Player, seconds: float, fps: int) -> void:
	var n: int = roundi(seconds * float(fps))
	for i: int in n:
		p._physics_process(1.0 / float(fps))


func _enemy_hitbox(dmg: int) -> Hitbox:
	var hb: Hitbox = auto_free(Hitbox.new()) as Hitbox
	hb.team = &"enemy"
	hb.damage = dmg
	add_child(hb)
	hb.activate(10.0)
	return hb


func test_moves_at_base_speed() -> void:
	for fps: int in FPS_LIST:
		var p: Player = _player()
		p.move_input = Vector2(1.0, 0.0)
		_run(p, 1.0, fps)
		assert_float(p.position.x).is_equal_approx(5.0, 0.05)
		assert_float(p.position.z).is_equal_approx(0.0, 0.001)


func test_speed_multiplier_and_diagonal_not_faster() -> void:
	var p: Player = _player()
	p.speed_multiplier = 0.8
	p.move_input = Vector2(1.0, 1.0)
	_run(p, 1.0, 60)
	assert_float(Vector2(p.position.x, p.position.z).length()).is_equal_approx(4.0, 0.05)


func test_movement_relative_to_camera() -> void:
	var cam: Node3D = auto_free(Node3D.new()) as Node3D
	cam.name = "Cam"
	add_child(cam)
	cam.rotation.y = PI / 2.0
	var p: Player = _player()
	p.camera_path = p.get_path_to(cam)
	p.move_input = Vector2(0.0, -1.0)  # up = camera forward (-Z of camera)
	_run(p, 1.0, 60)
	# Camera yawed +90 degrees: its forward (-Z) points to world -X.
	assert_float(p.position.x).is_equal_approx(-5.0, 0.05)
	assert_float(p.position.z).is_equal_approx(0.0, 0.05)


func test_light_combo_damage_sequence() -> void:
	for fps: int in FPS_LIST:
		var p: Player = _player()
		var seen: Array[int] = []
		for i: int in 3:
			p.request_light_attack()
			_run(p, 1.0 / 60.0, fps)  # one tick later the hitbox is live
			seen.append(p.get_light_hitbox().damage)
			assert_bool(p.get_light_hitbox().is_active()).is_true()
			_run(p, 0.4, fps)
		assert_array(seen).is_equal([12, 12, 20])
		assert_int(p.combo_count()).is_equal(0)


func test_combo_resets_after_chain_window() -> void:
	for fps: int in FPS_LIST:
		var p: Player = _player()
		p.request_light_attack()
		_run(p, 0.25 + 0.5, fps)  # inside the 0.6 s window
		assert_int(p.combo_count()).is_equal(1)
		_run(p, 0.2, fps)  # window (0.6 s after the swing) has passed
		assert_int(p.combo_count()).is_equal(0)
		p.request_light_attack()
		_run(p, 0.05, fps)
		assert_int(p.get_light_hitbox().damage).is_equal(12)


func test_chain_inside_window_advances() -> void:
	for fps: int in FPS_LIST:
		var p: Player = _player()
		p.request_light_attack()
		_run(p, 0.25 + 0.55, fps)
		p.request_light_attack()
		_run(p, 0.05, fps)
		assert_int(p.get_light_hitbox().damage).is_equal(12)
		_run(p, 0.3 + 0.35, fps)
		p.request_light_attack()
		_run(p, 0.05, fps)
		assert_int(p.get_light_hitbox().damage).is_equal(20)


func test_heavy_windup_and_strike() -> void:
	for fps: int in FPS_LIST:
		var p: Player = _player()
		p.request_heavy_attack()
		_run(p, 0.5, fps)
		assert_bool(p.get_heavy_hitbox().is_active()).is_false()
		_run(p, 0.15, fps)
		assert_bool(p.get_heavy_hitbox().is_active()).is_true()
		assert_int(p.get_heavy_hitbox().damage).is_equal(35)
		assert_float(p.get_heavy_hitbox().knockback).is_greater(0.0)
		_run(p, 0.5, fps)
		assert_bool(p.get_heavy_hitbox().is_active()).is_false()
		assert_bool(p.is_attacking()).is_false()


func test_damage_multiplier_scales_hits() -> void:
	var p: Player = _player()
	p.damage_multiplier = 2.0
	p.request_light_attack()
	_run(p, 0.05, 60)
	assert_int(p.get_light_hitbox().damage).is_equal(24)


func test_no_damage_during_dodge() -> void:
	for fps: int in FPS_LIST:
		var p: Player = _player()
		p.request_leap()
		_run(p, 0.2, fps)
		assert_bool(p.is_dodging()).is_true()
		p.take_damage(30, null)
		assert_int(p.get_health().value).is_equal(100)
		var hb: Hitbox = _enemy_hitbox(25)
		assert_bool(p.get_hurtbox().try_hit(hb)).is_true()
		assert_int(p.get_health().value).is_equal(100)
		_run(p, 0.2, fps)
		assert_bool(p.is_dodging()).is_false()
		p.take_damage(30, null)
		assert_int(p.get_health().value).is_equal(70)


func test_dodge_cooldown() -> void:
	for fps: int in FPS_LIST:
		var p: Player = _player()
		p.request_leap()
		_run(p, 0.4, fps)
		p.request_leap()  # on cooldown
		assert_bool(p.is_dodging()).is_false()
		_run(p, 0.7, fps)  # 1.1 s since start
		assert_bool(p.can_dodge()).is_false()
		_run(p, 0.15, fps)  # 1.25 s
		assert_bool(p.can_dodge()).is_true()
		p.request_leap()
		assert_bool(p.is_dodging()).is_true()


func test_dodge_moves_player() -> void:
	var p: Player = _player()
	p.move_input = Vector2(1.0, 0.0)
	p.request_leap()
	_run(p, 0.5, 60)
	assert_float(p.position.x).is_greater(3.0)


func test_same_outcome_at_30_and_60_fps() -> void:
	var results: Array[Vector3] = []
	for fps: int in FPS_LIST:
		var p: Player = _player()
		p.move_input = Vector2(1.0, -0.5)
		_run(p, 0.7, fps)
		p.request_leap()
		_run(p, 0.5, fps)
		p.move_input = Vector2.ZERO
		_run(p, 0.5, fps)
		results.append(p.position)
	assert_float(results[0].x).is_equal_approx(results[1].x, 0.001)
	assert_float(results[0].z).is_equal_approx(results[1].z, 0.001)


func test_interact_picks_nearest_within_range() -> void:
	var p: Player = _player()
	var near: Area3D = auto_free(Area3D.new()) as Area3D
	near.add_to_group(&"interactable")
	add_child(near)
	near.global_position = Vector3(1.5, 0.0, 0.0)
	var nearer: Area3D = auto_free(Area3D.new()) as Area3D
	nearer.add_to_group(&"interactable")
	add_child(nearer)
	nearer.global_position = Vector3(0.0, 0.0, 1.0)
	var far: Area3D = auto_free(Area3D.new()) as Area3D
	far.add_to_group(&"interactable")
	add_child(far)
	far.global_position = Vector3(5.0, 0.0, 0.0)
	var got: Array[Area3D] = []
	p.interact_requested.connect(func(t: Area3D) -> void: got.append(t))
	p.request_interact()
	assert_array(got).has_size(1)
	assert_object(got[0]).is_same(nearer)
	nearer.remove_from_group(&"interactable")
	near.remove_from_group(&"interactable")
	got.clear()
	p.request_interact()
	assert_array(got).has_size(0)


func test_events_and_taken_multiplier() -> void:
	var p: Player = _player()
	var bus: Node = p.event_bus
	var damaged: Array[int] = []
	var vit: Array[int] = []
	bus.connect(&"player_damaged", func(a: int, _s: Node) -> void: damaged.append(a))
	bus.connect(&"vitality_changed", func(v: int, _m: int) -> void: vit.append(v))
	p.damage_taken_multiplier = 0.6
	p.take_damage(10, null)
	assert_array(damaged).is_equal([6])
	assert_int(vit[vit.size() - 1]).is_equal(94)
	assert_int(p.get_health().max_value).is_equal(100)


func test_hurtbox_hit_emits_and_knocks_back() -> void:
	var p: Player = _player()
	var damaged: Array[int] = []
	p.event_bus.connect(&"player_damaged", func(a: int, _s: Node) -> void: damaged.append(a))
	var hb: Hitbox = _enemy_hitbox(15)
	hb.knockback = 6.0
	hb.global_position = Vector3(-1.0, 0.0, 0.0)
	p.get_hurtbox().try_hit(hb)
	assert_array(damaged).is_equal([15])
	assert_int(p.get_health().value).is_equal(85)
