extends GdUnitTestSuite
## M13 acceptance: the Health component (gameplay/components/health.gd, DESIGN §9 M13).

const HealthScript: GDScript = preload("res://gameplay/components/health.gd")


func _make(max_hp: int) -> Health:
	var h: Health = HealthScript.new() as Health
	h.max_value = max_hp
	auto_free(h)
	add_child(h)
	return h


func test_starts_at_max_value() -> void:
	var h: Health = _make(100)
	assert_int(h.value).is_equal(100)


func test_damage_reduces_value() -> void:
	var h: Health = _make(100)
	h.damage(30, null)
	assert_int(h.value).is_equal(70)


func test_damage_clamps_at_zero() -> void:
	var h: Health = _make(100)
	h.damage(250, null)
	assert_int(h.value).is_equal(0)


func test_heal_clamps_at_max() -> void:
	var h: Health = _make(100)
	h.damage(20, null)
	h.heal(500)
	assert_int(h.value).is_equal(100)


func test_heal_restores_value() -> void:
	var h: Health = _make(100)
	h.damage(40, null)
	h.heal(15)
	assert_int(h.value).is_equal(75)


func test_non_positive_amounts_are_ignored() -> void:
	var h: Health = _make(100)
	h.damage(0, null)
	h.damage(-10, null)
	h.heal(0)
	h.heal(-10)
	assert_int(h.value).is_equal(100)


func test_damage_multiplier_scales_damage() -> void:
	var h: Health = _make(100)
	h.damage_multiplier = 0.5
	h.damage(20, null)
	assert_int(h.value).is_equal(90)


func test_damage_multiplier_defaults_to_one() -> void:
	var h: Health = _make(100)
	assert_float(h.damage_multiplier).is_equal_approx(1.0, 0.001)


func test_changed_is_emitted_with_new_value() -> void:
	var h: Health = _make(100)
	var seen: Array[int] = []
	h.changed.connect(func(v: int, _m: int) -> void: seen.append(v))
	h.damage(10, null)
	h.heal(5)
	assert_array(seen).is_equal([90, 95])


func test_depleted_is_emitted_exactly_once() -> void:
	var h: Health = _make(50)
	var count: Array[int] = [0]
	h.depleted.connect(func(_s: Node) -> void: count[0] += 1)
	h.damage(50, null)
	h.damage(10, null)
	h.damage(10, null)
	assert_int(count[0]).is_equal(1)


func test_depleted_is_not_emitted_while_alive() -> void:
	var h: Health = _make(50)
	var count: Array[int] = [0]
	h.depleted.connect(func(_s: Node) -> void: count[0] += 1)
	h.damage(49, null)
	assert_int(count[0]).is_equal(0)


func test_depleted_passes_source() -> void:
	var h: Health = _make(10)
	var src: Node = auto_free(Node.new())
	var got: Array[Node] = []
	h.depleted.connect(func(s: Node) -> void: got.append(s))
	h.damage(10, src)
	assert_array(got).has_size(1)
	assert_object(got[0]).is_same(src)


func test_damage_ignored_while_invulnerable() -> void:
	var h: Health = _make(100)
	h.invulnerable = true
	h.damage(60, null)
	assert_int(h.value).is_equal(100)


func test_invulnerable_does_not_block_depleted_when_cleared() -> void:
	var h: Health = _make(100)
	h.invulnerable = true
	h.damage(100, null)
	h.invulnerable = false
	h.damage(100, null)
	assert_int(h.value).is_equal(0)


func test_changed_not_emitted_when_damage_ignored() -> void:
	var h: Health = _make(100)
	var count: Array[int] = [0]
	h.changed.connect(func(_v: int, _m: int) -> void: count[0] += 1)
	h.invulnerable = true
	h.damage(10, null)
	assert_int(count[0]).is_equal(0)


func test_depleted_can_fire_again_after_heal() -> void:
	var h: Health = _make(20)
	var count: Array[int] = [0]
	h.depleted.connect(func(_s: Node) -> void: count[0] += 1)
	h.damage(20, null)
	h.heal(20)
	h.damage(20, null)
	assert_int(count[0]).is_equal(2)
