extends GdUnitTestSuite
## M14 acceptance: hitboxes (gameplay/components/hitbox.gd, DESIGN §9 M14).

const HitboxScript: GDScript = preload("res://gameplay/components/hitbox.gd")


func _make(team: StringName, dmg: int) -> Hitbox:
	var hb: Hitbox = HitboxScript.new() as Hitbox
	hb.team = team
	hb.damage = dmg
	auto_free(hb)
	add_child(hb)
	return hb


func test_starts_inactive() -> void:
	var hb: Hitbox = _make(&"player", 10)
	assert_bool(hb.is_active()).is_false()


func test_activate_makes_active_and_expires_after_duration() -> void:
	var hb: Hitbox = _make(&"player", 10)
	hb.activate(0.5)
	assert_bool(hb.is_active()).is_true()
	hb.advance(0.3)
	assert_bool(hb.is_active()).is_true()
	hb.advance(0.3)
	assert_bool(hb.is_active()).is_false()


func test_expiry_is_frame_rate_independent() -> void:
	var hb: Hitbox = _make(&"player", 10)
	hb.activate(1.0)
	for _i: int in 60:
		hb.advance(1.0 / 60.0)
	assert_bool(hb.is_active()).is_false()
	var slow: Hitbox = _make(&"player", 10)
	slow.activate(1.0)
	for _i: int in 30:
		slow.advance(1.0 / 30.0)
	assert_bool(slow.is_active()).is_false()


func test_deactivate_stops_hitbox() -> void:
	var hb: Hitbox = _make(&"enemy", 5)
	hb.activate(2.0)
	hb.deactivate()
	assert_bool(hb.is_active()).is_false()


func test_each_activation_gets_new_id() -> void:
	var hb: Hitbox = _make(&"player", 10)
	hb.activate(1.0)
	var first: int = hb.get_activation_id()
	hb.activate(1.0)
	assert_int(hb.get_activation_id()).is_not_equal(first)


func test_team_selects_collision_layer() -> void:
	var p: Hitbox = _make(&"player", 1)
	assert_int(p.collision_layer).is_equal(Layers.mask([Layers.PLAYER_HIT]))
	var e: Hitbox = _make(&"enemy", 1)
	assert_int(e.collision_layer).is_equal(Layers.mask([Layers.ENEMY_HIT]))


func test_inactive_hitbox_is_not_detectable() -> void:
	var hb: Hitbox = _make(&"player", 10)
	assert_bool(hb.monitorable).is_false()
	hb.activate(1.0)
	assert_bool(hb.monitorable).is_true()
	hb.deactivate()
	assert_bool(hb.monitorable).is_false()


func test_knockback_and_damage_are_stored() -> void:
	var hb: Hitbox = _make(&"player", 12)
	hb.knockback = 4.5
	assert_int(hb.damage).is_equal(12)
	assert_float(hb.knockback).is_equal_approx(4.5, 0.001)
