extends GdUnitTestSuite
## M14 acceptance: hurtboxes forwarding hits to Health (gameplay/components/hurtbox.gd, DESIGN §9 M14).

const HitboxScript: GDScript = preload("res://gameplay/components/hitbox.gd")
const HurtboxScript: GDScript = preload("res://gameplay/components/hurtbox.gd")
const HealthScript: GDScript = preload("res://gameplay/components/health.gd")


func _make_hitbox(team: StringName, dmg: int) -> Hitbox:
	var hb: Hitbox = HitboxScript.new() as Hitbox
	hb.team = team
	hb.damage = dmg
	auto_free(hb)
	add_child(hb)
	return hb


## Builds a hurtbox of `team` with a Health child that it forwards damage to.
func _make_hurtbox(team: StringName, max_hp: int) -> Hurtbox:
	var root: Node3D = Node3D.new()
	auto_free(root)
	add_child(root)
	var health: Health = HealthScript.new() as Health
	health.name = "Health"
	health.max_value = max_hp
	root.add_child(health)
	var hurt: Hurtbox = HurtboxScript.new() as Hurtbox
	hurt.team = team
	hurt.health_path = NodePath("../Health")
	root.add_child(hurt)
	return hurt


func _health_of(hurt: Hurtbox) -> Health:
	return hurt.get_parent().get_node("Health") as Health


func test_enemy_hit_damages_player_health() -> void:
	var hurt: Hurtbox = _make_hurtbox(&"player", 100)
	var hb: Hitbox = _make_hitbox(&"enemy", 15)
	hb.activate(1.0)
	assert_bool(hurt.try_hit(hb)).is_true()
	assert_int(_health_of(hurt).value).is_equal(85)


func test_friendly_fire_is_ignored() -> void:
	var hurt: Hurtbox = _make_hurtbox(&"enemy", 100)
	var hb: Hitbox = _make_hitbox(&"enemy", 15)
	hb.activate(1.0)
	assert_bool(hurt.try_hit(hb)).is_false()
	assert_int(_health_of(hurt).value).is_equal(100)


func test_each_activation_applies_its_hit_only_once() -> void:
	var hurt: Hurtbox = _make_hurtbox(&"player", 100)
	var hb: Hitbox = _make_hitbox(&"enemy", 10)
	hb.activate(1.0)
	assert_bool(hurt.try_hit(hb)).is_true()
	assert_bool(hurt.try_hit(hb)).is_false()
	assert_bool(hurt.try_hit(hb)).is_false()
	assert_int(_health_of(hurt).value).is_equal(90)


func test_new_activation_can_hit_again() -> void:
	var hurt: Hurtbox = _make_hurtbox(&"player", 100)
	var hb: Hitbox = _make_hitbox(&"enemy", 10)
	hb.activate(1.0)
	hurt.try_hit(hb)
	hb.activate(1.0)
	assert_bool(hurt.try_hit(hb)).is_true()
	assert_int(_health_of(hurt).value).is_equal(80)


func test_inactive_hitbox_does_not_hit() -> void:
	var hurt: Hurtbox = _make_hurtbox(&"player", 100)
	var hb: Hitbox = _make_hitbox(&"enemy", 10)
	assert_bool(hurt.try_hit(hb)).is_false()
	assert_int(_health_of(hurt).value).is_equal(100)


func test_expired_hitbox_does_not_hit() -> void:
	var hurt: Hurtbox = _make_hurtbox(&"player", 100)
	var hb: Hitbox = _make_hitbox(&"enemy", 10)
	hb.activate(0.2)
	hb.advance(0.5)
	assert_bool(hurt.try_hit(hb)).is_false()
	assert_int(_health_of(hurt).value).is_equal(100)


func test_hit_emits_knockback_away_from_hitbox() -> void:
	var hurt: Hurtbox = _make_hurtbox(&"player", 100)
	var hb: Hitbox = _make_hitbox(&"enemy", 10)
	hb.knockback = 3.0
	hb.position = Vector3(-2.0, 0.0, 0.0)
	hurt.position = Vector3.ZERO
	hb.activate(1.0)
	var knocks: Array[Vector3] = []
	hurt.hit_taken.connect(func(_d: int, kv: Vector3, _src: Node) -> void: knocks.append(kv))
	hurt.try_hit(hb)
	assert_int(knocks.size()).is_equal(1)
	var k: Vector3 = knocks[0]
	assert_float(k.x).is_equal_approx(3.0, 0.001)
	assert_float(k.y).is_equal_approx(0.0, 0.001)
	assert_float(k.z).is_equal_approx(0.0, 0.001)


func test_friendly_fire_emits_no_signal() -> void:
	var hurt: Hurtbox = _make_hurtbox(&"player", 100)
	var hb: Hitbox = _make_hitbox(&"player", 10)
	hb.activate(1.0)
	var count: Array[int] = [0]
	hurt.hit_taken.connect(func(_d: int, _k: Vector3, _src: Node) -> void: count[0] += 1)
	hurt.try_hit(hb)
	assert_int(count[0]).is_equal(0)


func test_hurtbox_team_selects_layers() -> void:
	var hurt: Hurtbox = _make_hurtbox(&"player", 100)
	assert_int(hurt.collision_layer).is_equal(Layers.mask([Layers.PLAYER]))
	assert_int(hurt.collision_mask).is_equal(Layers.hurt_mask_for_team(&"player"))
